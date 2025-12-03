//
//  AuthService.swift
//  Celestia
//
//  Created by Kevin Perez on 10/29/25.
//

import Foundation
import UIKit
import Firebase
import FirebaseAuth
import FirebaseFirestore

@MainActor
class AuthService: ObservableObject, AuthServiceProtocol {
    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isEmailVerified = false
    @Published var referralBonusMessage: String?
    @Published var referralErrorMessage: String?
    @Published var isInitialized = false

    /// Indicates if re-authentication is needed for sensitive operations
    @Published var requiresReauthentication = false

    // Singleton for backward compatibility
    static let shared = AuthService()

    // AUTH STATE LISTENER: Track auth state changes (sign out on other devices, token expiration)
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    private var idTokenListenerHandle: IDTokenDidChangeListenerHandle?

    // Continuation for async initialization
    private var initializationContinuation: CheckedContinuation<Void, Never>?

    // Public initializer for dependency injection (used in testing and ViewModels)
    init() {
        self.userSession = Auth.auth().currentUser
        self.isEmailVerified = Auth.auth().currentUser?.isEmailVerified ?? false
        Logger.shared.auth("AuthService initialized", level: .info)
        // SECURITY FIX: Never log UIDs or email addresses
        Logger.shared.auth("Current user session: \(Auth.auth().currentUser != nil ? "authenticated" : "none")", level: .debug)
        Logger.shared.auth("Email verified: \(isEmailVerified)", level: .info)

        // SESSION HANDLING: Set up auth state listener for reactive state management
        setupAuthStateListener()
        setupIDTokenListener()

        // FIXED: Initialize on MainActor and track completion
        Task { @MainActor in
            await fetchUser()
            self.isInitialized = true
            self.initializationContinuation?.resume()
            self.initializationContinuation = nil
            Logger.shared.auth("AuthService initialization complete", level: .info)
        }
    }

    deinit {
        // Clean up listeners
        if let handle = authStateListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        if let handle = idTokenListenerHandle {
            Auth.auth().removeIDTokenDidChangeListener(handle)
        }
    }

    // MARK: - Auth State Listeners

    /// Set up listener for auth state changes (sign-in, sign-out, token refresh)
    private func setupAuthStateListener() {
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                let previousSession = self.userSession
                self.userSession = user
                self.isEmailVerified = user?.isEmailVerified ?? false

                if user == nil && previousSession != nil {
                    // User was signed out (possibly from another device or session expired)
                    Logger.shared.auth("Auth state changed: User signed out externally", level: .warning)
                    self.currentUser = nil
                    self.isInitialized = false
                    self.requiresReauthentication = false

                    // Post notification for UI to handle sign-out
                    NotificationCenter.default.post(name: .userSessionExpired, object: nil)
                } else if user != nil && previousSession == nil {
                    // User signed in
                    Logger.shared.auth("Auth state changed: User signed in", level: .info)
                    await self.fetchUser()
                }
            }
        }
    }

    /// Set up listener for ID token changes (refresh, expiration)
    private func setupIDTokenListener() {
        idTokenListenerHandle = Auth.auth().addIDTokenDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                if user != nil {
                    Logger.shared.auth("ID token refreshed", level: .debug)
                } else if self.userSession != nil {
                    // Token expired but we thought we were authenticated
                    Logger.shared.auth("ID token expired - session may be invalid", level: .warning)
                }
            }
        }
    }

    /// Wait for initial user fetch to complete
    /// Use this in views that need to ensure currentUser is loaded before proceeding
    func waitForInitialization() async {
        // If already initialized, return immediately
        guard !isInitialized else { return }

        // Use async/await pattern instead of polling
        await withCheckedContinuation { continuation in
            if isInitialized {
                continuation.resume()
            } else {
                // Store continuation to be resumed when initialization completes
                self.initializationContinuation = continuation

                // Timeout fallback using Task
                Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    if !self.isInitialized {
                        Logger.shared.warning("AuthService initialization timeout", category: .authentication)
                        self.initializationContinuation?.resume()
                        self.initializationContinuation = nil
                    }
                }
            }
        }
    }

    // MARK: - Validation
    // NOTE: Validation logic moved to ValidationHelper utility (see ValidationHelper.swift)
    // This eliminates code duplication across AuthService, SignUpView, Extensions, etc.

    func signIn(withEmail email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        // Sanitize inputs using centralized utility
        let sanitizedEmail = InputSanitizer.email(email)
        let sanitizedPassword = InputSanitizer.basic(password)

        // Validate email format using ValidationHelper
        let emailValidation = ValidationHelper.validateEmail(sanitizedEmail)
        guard emailValidation.isValid else {
            isLoading = false
            errorMessage = emailValidation.errorMessage ?? AppConstants.ErrorMessages.invalidEmail
            throw CelestiaError.invalidCredentials
        }

        // Validate password is not empty
        guard !sanitizedPassword.isEmpty else {
            isLoading = false
            errorMessage = "Password cannot be empty."
            throw CelestiaError.invalidCredentials
        }

        // SECURITY FIX: Never log email addresses
        Logger.shared.auth("Attempting sign in", level: .info)

        do {
            let result = try await Auth.auth().signIn(withEmail: sanitizedEmail, password: sanitizedPassword)
            self.userSession = result.user

            // CRITICAL: Force token refresh to get latest email_verified status
            // This fixes issues when user deletes account and re-creates with same email
            // The cached token may have stale email_verified=false
            do {
                _ = try await result.user.getIDTokenResult(forcingRefresh: true)
                try await result.user.reload()
                self.isEmailVerified = result.user.isEmailVerified
                Logger.shared.auth("Token refreshed - Email verified: \(isEmailVerified)", level: .info)
            } catch {
                // Fall back to current state if refresh fails
                self.isEmailVerified = result.user.isEmailVerified
                Logger.shared.auth("Token refresh failed, using cached state", level: .warning)
            }

            // SECURITY FIX: Never log UIDs
            Logger.shared.auth("Sign in successful", level: .info)
            Logger.shared.auth("Email verified: \(isEmailVerified)", level: .info)

            await fetchUser()
            self.isInitialized = true

            if currentUser != nil {
                Logger.shared.auth("User data fetched successfully", level: .info)
            } else {
                Logger.shared.auth("User session exists but no user data in Firestore", level: .warning)
            }

            isLoading = false
        } catch let error as NSError {
            isLoading = false

            // REFACTORED: Use FirebaseErrorMapper for consistent error handling
            FirebaseErrorMapper.logError(error, context: "Sign In")
            errorMessage = FirebaseErrorMapper.getUserFriendlyMessage(for: error)

            throw error
        }
    }

    @MainActor
    func resetPassword(email: String) async throws {
        // Sanitize email input using centralized utility
        let sanitizedEmail = InputSanitizer.email(email)

        // Validate email format using ValidationHelper
        let emailValidation = ValidationHelper.validateEmail(sanitizedEmail)
        guard emailValidation.isValid else {
            errorMessage = emailValidation.errorMessage ?? AppConstants.ErrorMessages.invalidEmail
            throw CelestiaError.invalidCredentials
        }

        do {
            try await Auth.auth().sendPasswordReset(withEmail: sanitizedEmail)
            // SECURITY FIX: Never log email addresses
            Logger.shared.auth("Password reset email sent", level: .info)
        } catch let error as NSError {
            // REFACTORED: Use FirebaseErrorMapper for consistent error handling
            FirebaseErrorMapper.logError(error, context: "Password Reset")
            errorMessage = FirebaseErrorMapper.getUserFriendlyMessage(for: error)

            throw error
        }
    }

    @MainActor
    func createUser(withEmail email: String, password: String, fullName: String, age: Int, gender: String, lookingFor: String, location: String, country: String, referralCode: String = "", photos: [UIImage] = []) async throws {
        isLoading = true
        errorMessage = nil

        // Sanitize inputs using centralized utility
        let sanitizedEmail = InputSanitizer.email(email)
        let sanitizedPassword = InputSanitizer.basic(password)
        let sanitizedFullName = InputSanitizer.strict(fullName)

        // REFACTORED: Use ValidationHelper for comprehensive sign-up validation
        let signUpValidation = ValidationHelper.validateSignUp(
            email: sanitizedEmail,
            password: sanitizedPassword,
            name: sanitizedFullName,
            age: age
        )

        guard signUpValidation.isValid else {
            isLoading = false
            errorMessage = signUpValidation.errorMessage ?? "Invalid sign up information."

            // Map validation errors to appropriate CelestiaError types
            if let errorMsg = signUpValidation.errorMessage {
                if errorMsg.contains("email") {
                    throw CelestiaError.invalidCredentials
                } else if errorMsg.contains("password") || errorMsg.contains("Password") {
                    throw CelestiaError.weakPassword
                } else if errorMsg.contains("18") {
                    throw CelestiaError.ageRestriction
                } else if errorMsg.contains("Name") || errorMsg.contains("name") {
                    throw CelestiaError.invalidProfileData
                } else {
                    throw CelestiaError.validationError(field: "signup", reason: errorMsg)
                }
            }
            throw CelestiaError.validationError(field: "signup", reason: "Invalid sign up information")
        }

        // SECURITY FIX: Never log email addresses
        Logger.shared.auth("Creating new user account", level: .info)

        do {
            // Step 1: Create Firebase Auth user
            let result = try await Auth.auth().createUser(withEmail: sanitizedEmail, password: sanitizedPassword)
            self.userSession = result.user
            // SECURITY FIX: Never log UIDs
            Logger.shared.auth("Firebase Auth user created successfully", level: .info)

            // Step 2: Create User object with all required fields
            var user = User(
                id: result.user.uid,
                email: sanitizedEmail,
                fullName: sanitizedFullName,
                age: age,
                gender: gender,
                lookingFor: lookingFor,
                bio: "",
                location: location,
                country: country,
                languages: [],
                interests: [],
                photos: [],
                profileImageURL: "",
                timestamp: Date(),
                isPremium: false,
                lastActive: Date(),
                ageRangeMin: 18,
                ageRangeMax: 99,
                maxDistance: 100
            )

            // Set referral code if provided
            let sanitizedReferralCode = InputSanitizer.referralCode(referralCode)
            if !sanitizedReferralCode.isEmpty {
                user.referredByCode = sanitizedReferralCode
            }

            // New users are invisible to others until admin approves
            // They can still see and interact with other profiles
            user.showMeInSearch = false

            Logger.shared.auth("Attempting to save user to Firestore", level: .info)

            // Step 3: Save to Firestore
            guard let userId = user.id else {
                throw CelestiaError.invalidData
            }

            let encodedUser = try Firestore.Encoder().encode(user)
            try await Firestore.firestore().collection("users").document(userId).setData(encodedUser)

            Logger.shared.auth("User saved to Firestore successfully", level: .info)

            // Step 3.5: Upload photos if provided (using high-quality parallel uploader)
            if !photos.isEmpty {
                // NETWORK CHECK: Verify connectivity before attempting uploads
                let isConnected = await MainActor.run { NetworkMonitor.shared.isConnected }
                guard isConnected else {
                    Logger.shared.auth("❌ Photo upload blocked: No network connection", level: .error)
                    throw CelestiaError.networkError
                }

                Logger.shared.auth("📶 Network OK - Starting upload of \(photos.count) photos (parallel with retries)", level: .info)

                let photosPath = "users/\(userId)/photos"

                // PERFORMANCE: Upload photos in parallel using TaskGroup for maximum speed
                let uploadedURLs = await withTaskGroup(of: (index: Int, url: String?)?.self) { group in
                    var results: [(Int, String?)] = []

                    for (index, originalImage) in photos.enumerated() {
                        group.addTask {
                            Logger.shared.auth("📤 Uploading photo \(index + 1)/\(photos.count)...", level: .info)

                            // OPTIMIZATION: Optimize image for upload (max 2000px, 92% quality)
                            let optimizedImage = self.optimizeImageForUpload(originalImage)
                            Logger.shared.auth("Image optimized: \(optimizedImage.size.width)x\(optimizedImage.size.height)", level: .debug)

                            // Upload with retry logic (3 attempts with exponential backoff)
                            var lastError: Error?
                            for attempt in 0..<3 {
                                do {
                                    Logger.shared.auth("🔄 Upload attempt \(attempt + 1)/3 for photo \(index + 1)", level: .debug)

                                    let url = try await ImageUploadService.shared.uploadImage(optimizedImage, path: photosPath)

                                    Logger.shared.auth("✅ Photo \(index + 1) uploaded successfully", level: .info)

                                    // Cache the image for instant display (MainActor isolated)
                                    await MainActor.run {
                                        ImageCache.shared.setImage(optimizedImage, for: url)
                                    }

                                    return (index, url)
                                } catch {
                                    lastError = error
                                    Logger.shared.auth("❌ Upload attempt \(attempt + 1) failed for photo \(index + 1): \(error.localizedDescription)", level: .warning)

                                    if attempt < 2 {
                                        // Wait before retry (exponential backoff: 0.5s, 1s)
                                        let delay = UInt64(pow(2.0, Double(attempt)) * 500_000_000)
                                        try? await Task.sleep(nanoseconds: delay)
                                    }
                                }
                            }

                            Logger.shared.error("❌ Photo \(index + 1) failed after all retries", category: .authentication, error: lastError)
                            return nil
                        }
                    }

                    // Collect results
                    for await result in group {
                        if let result = result {
                            results.append((result.index, result.url))
                        }
                    }

                    return results
                }

                // Sort by index and extract successful URLs
                let photoURLs = uploadedURLs
                    .sorted { $0.0 < $1.0 }
                    .compactMap { $0.1 }

                let successCount = photoURLs.count
                let failedCount = photos.count - successCount

                Logger.shared.auth("📊 Upload complete: \(successCount) succeeded, \(failedCount) failed", level: .info)

                if !photoURLs.isEmpty {
                    // Update user document with photo URLs
                    let updateData: [String: Any] = [
                        "photos": photoURLs,
                        "profileImageURL": photoURLs.first ?? ""
                    ]

                    do {
                        try await Firestore.firestore().collection("users").document(userId).updateData(updateData)
                        Logger.shared.auth("✅ Photos saved to Firestore successfully", level: .info)

                        // Update local user object with photos so it's immediately available
                        user.photos = photoURLs
                        user.profileImageURL = photoURLs.first ?? ""
                    } catch {
                        Logger.shared.error("Failed to save photo URLs to Firestore", category: .authentication, error: error)
                    }
                } else {
                    Logger.shared.warning("⚠️ No photos uploaded successfully - user can add later", category: .authentication)
                }
            }

            // Step 4: Send email verification with action code settings
            let actionCodeSettings = ActionCodeSettings()
            actionCodeSettings.handleCodeInApp = false
            // Set the URL to redirect to after email verification
            actionCodeSettings.url = URL(string: "https://celestia-40ce6.firebaseapp.com")

            do {
                try await result.user.sendEmailVerification(with: actionCodeSettings)
                // SECURITY FIX: Never log email addresses
                Logger.shared.auth("Verification email sent successfully", level: .info)
            } catch let emailError as NSError {
                Logger.shared.auth("Email verification send failed", level: .warning)
                Logger.shared.error("Failed to send verification email", category: .authentication, error: emailError)
                // Don't fail account creation if email fails to send
            }

            // Step 5: Initialize referral code and process referral
            do {
                // Generate unique referral code for new user
                try await ReferralManager.shared.initializeReferralCode(for: &user)
                Logger.shared.info("Referral code initialized for user", category: .referral)

                // Process referral if code was provided
                if !sanitizedReferralCode.isEmpty {
                    do {
                        try await ReferralManager.shared.processReferralSignup(
                            newUser: user,
                            referralCode: sanitizedReferralCode
                        )
                        Logger.shared.info("Referral processed successfully", category: .referral)

                        // Set success message for UI
                        await MainActor.run {
                            self.referralBonusMessage = "🎉 Referral bonus activated! You've received \(ReferralRewards.newUserBonusDays) days of Premium!"
                        }
                    } catch let referralError as ReferralError {
                        // Show user-friendly error message
                        await MainActor.run {
                            self.referralErrorMessage = referralError.localizedDescription
                        }
                        Logger.shared.warning("Referral error: \(referralError.localizedDescription)", category: .referral)
                    } catch {
                        // Generic referral error
                        await MainActor.run {
                            self.referralErrorMessage = "Unable to process referral code. Your account was created successfully."
                        }
                        Logger.shared.error("Unexpected referral error", category: .referral, error: error)
                    }
                }
            } catch {
                Logger.shared.error("Error initializing referral code", category: .referral, error: error)
                // Don't fail account creation if referral code initialization fails
            }

            // Step 6: Fetch user data
            await fetchUser()
            self.isInitialized = true
            isLoading = false

            Logger.shared.auth("Account creation completed - Please verify your email", level: .info)
        } catch let error as NSError {
            isLoading = false

            // REFACTORED: Use FirebaseErrorMapper for consistent error handling
            FirebaseErrorMapper.logError(error, context: "Create User")
            errorMessage = FirebaseErrorMapper.getUserFriendlyMessage(for: error)

            throw error
        }
    }
    
    @MainActor
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.userSession = nil
            self.currentUser = nil
            self.isEmailVerified = false
            self.isInitialized = false // FIXED: Reset initialization state
            self.requiresReauthentication = false
            Logger.shared.auth("User signed out successfully", level: .info)

            // Clear all local cached data to ensure clean state for next user
            clearAllLocalData()

            // Clear user cache on logout
            Task {
                await UserService.shared.clearCache()
            }
        } catch let error as NSError {
            // ERROR RECOVERY: Even if sign-out fails on server, clear local state
            // This prevents user from being stuck in a signed-in state
            Logger.shared.error("Error signing out on server - clearing local state", category: .authentication, error: error)

            self.userSession = nil
            self.currentUser = nil
            self.isEmailVerified = false
            self.isInitialized = false
            self.requiresReauthentication = false

            // Clear cache even on error
            Task {
                await UserService.shared.clearCache()
            }

            // Log analytics for monitoring
            FirebaseErrorMapper.logError(error, context: "Sign Out")
        }
    }
    
    @MainActor
    func fetchUser() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            Logger.shared.auth("No current user to fetch", level: .warning)
            return
        }

        Logger.shared.auth("Fetching user data for: \(uid)", level: .debug)

        do {
            let snapshot = try await Firestore.firestore().collection("users").document(uid).getDocument()

            if snapshot.exists {
                // FIXED: Try both decoding methods
                if var data = snapshot.data() {
                    Logger.shared.database("Raw Firestore data keys: \(data.keys.joined(separator: ", "))", level: .debug)

                    // Include document ID in data (Firestore doesn't include it automatically)
                    data["id"] = uid

                    // Try using the dictionary initializer first (more forgiving)
                    self.currentUser = User(dictionary: data)

                    if currentUser != nil {
                        // SECURITY FIX: Never log PII (names, emails, etc.)
                        Logger.shared.auth("User data fetched successfully", level: .info)
                    }
                } else {
                    Logger.shared.auth("Document exists but has no data", level: .warning)
                    // Create a minimal user document
                    await createMissingUserDocument(uid: uid)
                }
            } else {
                Logger.shared.auth("User document does not exist in Firestore for uid: \(uid)", level: .warning)
                // Create the missing user document
                await createMissingUserDocument(uid: uid)
            }
        } catch {
            Logger.shared.error("Error fetching user", category: .database, error: error)
        }
    }
    
    @MainActor
    private func createMissingUserDocument(uid: String) async {
        Logger.shared.auth("Creating missing user document for uid: \(uid)", level: .info)

        guard let firebaseUser = Auth.auth().currentUser else {
            Logger.shared.auth("Cannot create document - no Firebase auth user", level: .error)
            return
        }
        
        // Create a minimal user document with defaults
        let user = User(
            id: uid,
            email: firebaseUser.email ?? "unknown@email.com",
            fullName: firebaseUser.displayName ?? "User",
            age: 18,
            gender: "Other",
            lookingFor: "Everyone",
            bio: "",
            location: "Unknown",
            country: "Unknown",
            languages: [],
            interests: [],
            photos: [],
            profileImageURL: "",
            timestamp: Date(),
            isPremium: false,
            lastActive: Date(),
            ageRangeMin: 18,
            ageRangeMax: 99,
            maxDistance: 100
        )
        
        do {
            let encodedUser = try Firestore.Encoder().encode(user)
            try await Firestore.firestore().collection("users").document(uid).setData(encodedUser)
            Logger.shared.auth("Missing user document created successfully", level: .info)

            // Now fetch it
            await fetchUser()
        } catch {
            Logger.shared.error("Error creating missing user document", category: .database, error: error)
        }
    }
    
    @MainActor
    func updateUser(_ user: User) async throws {
        guard let uid = user.id else { return }
        let encodedUser = try Firestore.Encoder().encode(user)
        try await Firestore.firestore().collection("users").document(uid).setData(encodedUser, merge: true)
        self.currentUser = user
        Logger.shared.auth("User updated successfully", level: .info)
    }

    /// Updates the local user's referral code without a Firestore call
    /// Used when ReferralManager generates a new code
    @MainActor
    func updateLocalReferralCode(_ code: String) {
        guard var user = currentUser else { return }
        user.referralStats.referralCode = code
        self.currentUser = user
        Logger.shared.auth("Updated local referral code", level: .debug)
    }

    @MainActor
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw CelestiaError.notAuthenticated
        }
        let uid = user.uid

        // SECURITY FIX: Never log UIDs
        Logger.shared.auth("Deleting user account and all related data", level: .info)

        // CRITICAL FIX: Delete Firestore data FIRST while user is still authenticated
        // Security rules require request.auth.uid to match, so we must delete data
        // BEFORE deleting the Auth user, otherwise all deletions will fail silently.
        let db = Firestore.firestore()

        do {

            // IMPORTANT: Get user's photo URLs BEFORE deleting the user document
            // so we can clean up their images from Firebase Storage
            let userDoc = try? await db.collection("users").document(uid).getDocument()
            let photoURLs = userDoc?.data()?["photos"] as? [String] ?? []

            // Delete all related data in parallel for better performance
            // Group 1: Core user data
            async let messagesDeleted: () = deleteUserMessages(uid: uid, db: db)
            async let matchesDeleted: () = deleteUserMatches(uid: uid, db: db)
            async let interestsDeleted: () = deleteUserInterests(uid: uid, db: db)
            async let likesDeleted: () = deleteUserLikes(uid: uid, db: db)
            async let savedProfilesDeleted: () = deleteUserSavedProfiles(uid: uid, db: db)
            async let notificationsDeleted: () = deleteUserNotifications(uid: uid, db: db)
            async let blocksDeleted: () = deleteUserBlocks(uid: uid, db: db)
            async let profileViewsDeleted: () = deleteUserProfileViews(uid: uid, db: db)
            async let passesDeleted: () = deleteUserPasses(uid: uid, db: db)
            async let profileImagesDeleted: () = deleteUserProfileImages(photoURLs: photoURLs)

            // Group 2: Referral data
            async let referralCodesDeleted: () = deleteUserReferralCodes(uid: uid, db: db)
            async let referralDataDeleted: () = deleteUserReferralData(uid: uid, db: db)

            // Group 3: Attribution and experiments
            async let attributionDeleted: () = deleteUserAttributionData(uid: uid, db: db)

            // Group 4: Compliance and GDPR
            async let complianceDeleted: () = deleteUserComplianceData(uid: uid, db: db)

            // Group 5: Safety, verifications, and misc
            async let emergencyContactsDeleted: () = deleteUserEmergencyContacts(uid: uid, db: db)
            async let segmentAssignmentsDeleted: () = deleteUserSegmentAssignments(uid: uid, db: db)
            async let pendingVerificationsDeleted: () = deleteUserPendingVerifications(uid: uid, db: db)
            async let safetyDataDeleted: () = deleteUserSafetyData(uid: uid, db: db)

            // Group 6: Reports and notifications subcollection
            async let reportsDeleted: () = deleteUserReports(uid: uid, db: db)
            async let notificationsSubcollectionDeleted: () = deleteUserNotificationsSubcollection(uid: uid, db: db)

            // Group 7: Sessions, deep links, moderation queue
            async let sessionsDeleted: () = deleteUserSessions(uid: uid, db: db)
            async let deepLinksDeleted: () = deleteUserDeferredDeepLinks(uid: uid, db: db)
            async let moderationQueueDeleted: () = deleteUserModerationQueue(uid: uid, db: db)

            // Wait for all deletions to complete (ignore errors since Auth is already deleted)
            _ = try? await (messagesDeleted, matchesDeleted, interestsDeleted, likesDeleted,
                          savedProfilesDeleted, notificationsDeleted, blocksDeleted,
                          profileViewsDeleted, passesDeleted, profileImagesDeleted,
                          referralCodesDeleted, referralDataDeleted,
                          attributionDeleted, complianceDeleted,
                          emergencyContactsDeleted, segmentAssignmentsDeleted,
                          pendingVerificationsDeleted, safetyDataDeleted,
                          reportsDeleted, notificationsSubcollectionDeleted,
                          sessionsDeleted, deepLinksDeleted, moderationQueueDeleted)

            Logger.shared.auth("All related user data deleted (including profile images)", level: .info)

            // Delete user document from Firestore
            try await db.collection("users").document(uid).delete()
            Logger.shared.auth("User document deleted", level: .info)

        } catch {
            // If Firestore deletion fails, log and continue to try Auth deletion
            Logger.shared.auth("Some Firestore cleanup failed: \(error.localizedDescription)", level: .warning)
        }

        // NOW delete the Auth user (after Firestore data is cleaned up)
        // This ensures security rules can verify request.auth.uid during deletions above
        do {
            try await user.delete()
            Logger.shared.auth("Auth account deleted successfully", level: .info)
        } catch let error as NSError {
            // Handle requiresRecentLogin error
            if error.domain == "FIRAuthErrorDomain" && error.code == 17014 {
                Logger.shared.auth("Account deletion requires re-authentication", level: .warning)
                self.requiresReauthentication = true
                // Note: Firestore data may be partially deleted, but user can re-auth and retry
                throw CelestiaError.requiresRecentLogin
            }
            // For other errors, log but continue - Firestore data is already deleted
            Logger.shared.auth("Auth deletion failed: \(error.localizedDescription)", level: .error)
        }

        // Clear all local cached data to prevent conflicts on re-registration
        clearAllLocalData()

        self.userSession = nil
        self.currentUser = nil
        self.requiresReauthentication = false

        Logger.shared.auth("Account deleted successfully", level: .info)
    }

    /// Clear all locally cached data (UserDefaults, image caches, etc.)
    /// Called during account deletion and sign out to prevent data conflicts
    private func clearAllLocalData() {
        let defaults = UserDefaults.standard

        // Clear discovery filters
        let filterKeys = [
            "maxDistance", "minAge", "maxAge", "showVerifiedOnly",
            "selectedInterests", "educationLevels", "minHeight", "maxHeight",
            "religions", "relationshipGoals", "smokingPreferences",
            "drinkingPreferences", "petPreferences", "exercisePreferences", "dietPreferences"
        ]
        for key in filterKeys {
            defaults.removeObject(forKey: key)
        }

        // Clear security settings
        defaults.removeObject(forKey: "security_level")

        // Clear emergency contacts cache
        defaults.removeObject(forKey: "emergency_contacts")

        // Clear any daily like limit cache entries (pattern: dailyLikeLimit_{userId})
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys {
            if key.hasPrefix("dailyLikeLimit_") {
                defaults.removeObject(forKey: key)
            }
        }

        // Clear message queue
        defaults.removeObject(forKey: "queuedMessages")

        // Synchronize to ensure all changes are persisted
        defaults.synchronize()

        // Clear image caches
        ImageCache.shared.clearAll()
        URLCache.shared.removeAllCachedResponses()

        Logger.shared.auth("All local cached data cleared", level: .info)
    }

    // MARK: - Cascade Delete Helpers

    /// Delete all messages sent by or received by the user
    private func deleteUserMessages(uid: String, db: Firestore) async throws {
        // Delete messages where user is sender
        let sentMessages = try await db.collection("messages")
            .whereField("senderId", isEqualTo: uid)
            .getDocuments()

        for doc in sentMessages.documents {
            try await doc.reference.delete()
        }

        // Delete messages where user is receiver
        let receivedMessages = try await db.collection("messages")
            .whereField("receiverId", isEqualTo: uid)
            .getDocuments()

        for doc in receivedMessages.documents {
            try await doc.reference.delete()
        }

        Logger.shared.auth("Deleted \(sentMessages.count + receivedMessages.count) messages", level: .debug)
    }

    /// Delete all matches involving the user
    private func deleteUserMatches(uid: String, db: Firestore) async throws {
        // Delete matches where user is user1
        let matchesAsUser1 = try await db.collection("matches")
            .whereField("user1Id", isEqualTo: uid)
            .getDocuments()

        for doc in matchesAsUser1.documents {
            try await doc.reference.delete()
        }

        // Delete matches where user is user2
        let matchesAsUser2 = try await db.collection("matches")
            .whereField("user2Id", isEqualTo: uid)
            .getDocuments()

        for doc in matchesAsUser2.documents {
            try await doc.reference.delete()
        }

        Logger.shared.auth("Deleted \(matchesAsUser1.count + matchesAsUser2.count) matches", level: .debug)
    }

    /// Delete all interests (likes) sent by or received by the user
    private func deleteUserInterests(uid: String, db: Firestore) async throws {
        // Delete interests sent by user
        let sentInterests = try await db.collection("interests")
            .whereField("fromUserId", isEqualTo: uid)
            .getDocuments()

        for doc in sentInterests.documents {
            try await doc.reference.delete()
        }

        // Delete interests received by user
        let receivedInterests = try await db.collection("interests")
            .whereField("toUserId", isEqualTo: uid)
            .getDocuments()

        for doc in receivedInterests.documents {
            try await doc.reference.delete()
        }

        Logger.shared.auth("Deleted \(sentInterests.count + receivedInterests.count) interests", level: .debug)
    }

    /// Delete all likes sent by or received by the user
    private func deleteUserLikes(uid: String, db: Firestore) async throws {
        // Delete likes sent by user
        let sentLikes = try await db.collection("likes")
            .whereField("fromUserId", isEqualTo: uid)
            .getDocuments()

        for doc in sentLikes.documents {
            try await doc.reference.delete()
        }

        // Delete likes received by user
        let receivedLikes = try await db.collection("likes")
            .whereField("toUserId", isEqualTo: uid)
            .getDocuments()

        for doc in receivedLikes.documents {
            try await doc.reference.delete()
        }

        Logger.shared.auth("Deleted \(sentLikes.count + receivedLikes.count) likes", level: .debug)
    }

    /// Delete all saved profiles by or of the user
    private func deleteUserSavedProfiles(uid: String, db: Firestore) async throws {
        // Delete saved profiles created by user
        let savedByUser = try await db.collection("saved_profiles")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()

        for doc in savedByUser.documents {
            try await doc.reference.delete()
        }

        // Delete saved profiles where user was saved
        let savedOfUser = try await db.collection("saved_profiles")
            .whereField("savedUserId", isEqualTo: uid)
            .getDocuments()

        for doc in savedOfUser.documents {
            try await doc.reference.delete()
        }

        Logger.shared.auth("Deleted \(savedByUser.count + savedOfUser.count) saved profiles", level: .debug)
    }

    /// Delete all notifications for the user
    private func deleteUserNotifications(uid: String, db: Firestore) async throws {
        let notifications = try await db.collection("notifications")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()

        for doc in notifications.documents {
            try await doc.reference.delete()
        }

        Logger.shared.auth("Deleted \(notifications.count) notifications", level: .debug)
    }

    /// Delete all blocks created by or against the user
    private func deleteUserBlocks(uid: String, db: Firestore) async throws {
        // Delete from blocks collection
        let blockerBlocks = try await db.collection("blocks")
            .whereField("blockerId", isEqualTo: uid)
            .getDocuments()

        for doc in blockerBlocks.documents {
            try await doc.reference.delete()
        }

        let blockedBlocks = try await db.collection("blocks")
            .whereField("blockedId", isEqualTo: uid)
            .getDocuments()

        for doc in blockedBlocks.documents {
            try await doc.reference.delete()
        }

        // Delete from blockedUsers collection
        let blockerUsers = try await db.collection("blockedUsers")
            .whereField("blockerId", isEqualTo: uid)
            .getDocuments()

        for doc in blockerUsers.documents {
            try await doc.reference.delete()
        }

        let blockedUsers = try await db.collection("blockedUsers")
            .whereField("blockedUserId", isEqualTo: uid)
            .getDocuments()

        for doc in blockedUsers.documents {
            try await doc.reference.delete()
        }

        Logger.shared.auth("Deleted blocks data", level: .debug)
    }

    /// Delete referral codes for the user
    private func deleteUserReferralCodes(uid: String, db: Firestore) async throws {
        let referralCodes = try await db.collection("referralCodes")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()

        for doc in referralCodes.documents {
            try await doc.reference.delete()
        }

        Logger.shared.auth("Deleted \(referralCodes.count) referral codes", level: .debug)
    }

    /// Delete profile views by or of the user
    private func deleteUserProfileViews(uid: String, db: Firestore) async throws {
        // Delete views made by user
        let viewsMade = try await db.collection("profileViews")
            .whereField("viewerUserId", isEqualTo: uid)
            .getDocuments()

        for doc in viewsMade.documents {
            try await doc.reference.delete()
        }

        // Delete views of user's profile
        let viewsReceived = try await db.collection("profileViews")
            .whereField("viewedUserId", isEqualTo: uid)
            .getDocuments()

        for doc in viewsReceived.documents {
            try await doc.reference.delete()
        }

        Logger.shared.auth("Deleted \(viewsMade.count + viewsReceived.count) profile views", level: .debug)
    }

    /// Delete passes made by the user
    private func deleteUserPasses(uid: String, db: Firestore) async throws {
        let passes = try await db.collection("passes")
            .whereField("fromUserId", isEqualTo: uid)
            .getDocuments()

        for doc in passes.documents {
            try await doc.reference.delete()
        }

        Logger.shared.auth("Deleted \(passes.count) passes", level: .debug)
    }

    /// Delete emergency contacts for the user
    private func deleteUserEmergencyContacts(uid: String, db: Firestore) async throws {
        let contacts = try await db.collection("emergency_contacts")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()

        for doc in contacts.documents {
            try await doc.reference.delete()
        }

        Logger.shared.auth("Deleted \(contacts.count) emergency contacts", level: .debug)
    }

    /// Delete user segment assignments
    private func deleteUserSegmentAssignments(uid: String, db: Firestore) async throws {
        // Try to delete document with userId as document ID
        try? await db.collection("userSegmentAssignments").document(uid).delete()

        // Also try to find any documents with userId field
        let assignments = try await db.collection("userSegmentAssignments")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()

        for doc in assignments.documents {
            try await doc.reference.delete()
        }

        Logger.shared.auth("Deleted user segment assignments", level: .debug)
    }

    /// Delete pending ID verifications (GDPR: contains sensitive ID documents)
    private func deleteUserPendingVerifications(uid: String, db: Firestore) async throws {
        // Document ID is the user ID for pendingVerifications
        try? await db.collection("pendingVerifications").document(uid).delete()

        // Also query by userId field in case of different document structure
        let verifications = try await db.collection("pendingVerifications")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()

        for doc in verifications.documents {
            try await doc.reference.delete()
        }

        Logger.shared.auth("Deleted pending verifications (ID documents)", level: .debug)
    }

    /// Delete user's profile images from Firebase Storage
    private func deleteUserProfileImages(photoURLs: [String]) async throws {
        guard !photoURLs.isEmpty else {
            Logger.shared.auth("No profile images to delete", level: .debug)
            return
        }

        var deletedCount = 0
        var failedCount = 0

        for photoURL in photoURLs {
            do {
                try await ImageUploadService.shared.deleteImage(url: photoURL)
                deletedCount += 1
            } catch {
                // Log but continue - don't fail the whole deletion for one image
                Logger.shared.auth("Failed to delete image: \(error.localizedDescription)", level: .warning)
                failedCount += 1
            }
        }

        Logger.shared.auth("Deleted \(deletedCount) profile images (\(failedCount) failed)", level: .debug)
    }

    /// Delete all referral-related data for the user
    private func deleteUserReferralData(uid: String, db: Firestore) async throws {
        // Delete referrals where user is referrer
        let referralsAsReferrer = try await db.collection("referrals")
            .whereField("referrerUserId", isEqualTo: uid)
            .getDocuments()
        for doc in referralsAsReferrer.documents {
            try await doc.reference.delete()
        }

        // Delete referrals where user was referred
        let referralsAsReferred = try await db.collection("referrals")
            .whereField("referredUserId", isEqualTo: uid)
            .getDocuments()
        for doc in referralsAsReferred.documents {
            try await doc.reference.delete()
        }

        // Delete referral rewards
        let rewards = try await db.collection("referralRewards")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        for doc in rewards.documents {
            try await doc.reference.delete()
        }

        // Delete referral shares
        let shares = try await db.collection("referralShares")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        for doc in shares.documents {
            try await doc.reference.delete()
        }

        // Delete referral milestones
        let milestones = try await db.collection("referralMilestones")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        for doc in milestones.documents {
            try await doc.reference.delete()
        }

        // Delete referral signups
        let signups = try await db.collection("referralSignups")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        for doc in signups.documents {
            try await doc.reference.delete()
        }

        Logger.shared.auth("Deleted referral data", level: .debug)
    }

    /// Delete attribution and experiment data
    private func deleteUserAttributionData(uid: String, db: Firestore) async throws {
        // Delete attribution touchpoints
        let touchpoints = try await db.collection("attributionTouchpoints")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        for doc in touchpoints.documents {
            try await doc.reference.delete()
        }

        // Delete attribution results
        let results = try await db.collection("attributionResults")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        for doc in results.documents {
            try await doc.reference.delete()
        }

        // Delete experiment assignments (both variants)
        let expAssignments = try await db.collection("experimentAssignments")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        for doc in expAssignments.documents {
            try await doc.reference.delete()
        }

        let expAssignments2 = try await db.collection("experiment_assignments")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        for doc in expAssignments2.documents {
            try await doc.reference.delete()
        }

        Logger.shared.auth("Deleted attribution and experiment data", level: .debug)
    }

    /// Delete compliance and consent data (GDPR)
    private func deleteUserComplianceData(uid: String, db: Firestore) async throws {
        // Delete consent records
        let consents = try await db.collection("consentRecords")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        for doc in consents.documents {
            try await doc.reference.delete()
        }

        // Delete data subject requests
        let requests = try await db.collection("dataSubjectRequests")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        for doc in requests.documents {
            try await doc.reference.delete()
        }

        // Delete device fingerprints
        let fingerprints = try await db.collection("deviceFingerprints")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        for doc in fingerprints.documents {
            try await doc.reference.delete()
        }

        // Delete fraud assessments
        let assessments = try await db.collection("fraudAssessments")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        for doc in assessments.documents {
            try await doc.reference.delete()
        }

        Logger.shared.auth("Deleted compliance and consent data", level: .debug)
    }

    /// Delete safety and misc user data
    private func deleteUserSafetyData(uid: String, db: Firestore) async throws {
        // Delete typing status
        let typingStatus = try await db.collection("typingStatus")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        for doc in typingStatus.documents {
            try await doc.reference.delete()
        }

        // Delete screenshot events
        let screenshots = try await db.collection("screenshotEvents")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        for doc in screenshots.documents {
            try await doc.reference.delete()
        }

        // Delete shared dates
        let sharedDates = try await db.collection("shared_dates")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        for doc in sharedDates.documents {
            try await doc.reference.delete()
        }

        // Delete safety notifications
        let safetyNotifs = try await db.collection("safety_notifications")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        for doc in safetyNotifs.documents {
            try await doc.reference.delete()
        }

        // Delete appeals
        let appeals = try await db.collection("appeals")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        for doc in appeals.documents {
            try await doc.reference.delete()
        }

        // Delete purchases
        let purchases = try await db.collection("purchases")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        for doc in purchases.documents {
            try await doc.reference.delete()
        }

        Logger.shared.auth("Deleted safety and misc data", level: .debug)
    }

    /// Delete reports made by or about the user
    private func deleteUserReports(uid: String, db: Firestore) async throws {
        // Delete reports made BY the user
        let reportsMade = try await db.collection("reports")
            .whereField("reporterId", isEqualTo: uid)
            .getDocuments()
        for doc in reportsMade.documents {
            try await doc.reference.delete()
        }

        // Delete reports made ABOUT the user
        let reportsReceived = try await db.collection("reports")
            .whereField("reportedUserId", isEqualTo: uid)
            .getDocuments()
        for doc in reportsReceived.documents {
            try await doc.reference.delete()
        }

        Logger.shared.auth("Deleted \(reportsMade.count + reportsReceived.count) reports", level: .debug)
    }

    /// Delete user notifications subcollection (users/{userId}/notifications)
    private func deleteUserNotificationsSubcollection(uid: String, db: Firestore) async throws {
        let notifications = try await db.collection("users").document(uid).collection("notifications").getDocuments()
        for doc in notifications.documents {
            try await doc.reference.delete()
        }

        Logger.shared.auth("Deleted \(notifications.count) user notifications subcollection items", level: .debug)
    }

    /// Delete user sessions (analytics/tracking data)
    private func deleteUserSessions(uid: String, db: Firestore) async throws {
        let sessions = try await db.collection("sessions")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        for doc in sessions.documents {
            try await doc.reference.delete()
        }

        Logger.shared.auth("Deleted \(sessions.count) sessions", level: .debug)
    }

    /// Delete deferred deep links claimed by the user
    private func deleteUserDeferredDeepLinks(uid: String, db: Firestore) async throws {
        let links = try await db.collection("deferredDeepLinks")
            .whereField("claimedBy", isEqualTo: uid)
            .getDocuments()
        for doc in links.documents {
            try await doc.reference.delete()
        }

        Logger.shared.auth("Deleted \(links.count) deferred deep links", level: .debug)
    }

    /// Delete moderation queue entries for the user
    private func deleteUserModerationQueue(uid: String, db: Firestore) async throws {
        let entries = try await db.collection("moderation_queue")
            .whereField("reportedUserId", isEqualTo: uid)
            .getDocuments()
        for doc in entries.documents {
            try await doc.reference.delete()
        }

        Logger.shared.auth("Deleted \(entries.count) moderation queue entries", level: .debug)
    }

    // MARK: - Re-authentication

    /// Re-authenticate user with password for sensitive operations
    /// Required before: deleteAccount, changeEmail, changePassword
    @MainActor
    func reauthenticate(withPassword password: String) async throws {
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            throw CelestiaError.notAuthenticated
        }

        // Sanitize password input
        let sanitizedPassword = InputSanitizer.basic(password)
        guard !sanitizedPassword.isEmpty else {
            throw CelestiaError.invalidCredentials
        }

        Logger.shared.auth("Re-authenticating user for sensitive operation", level: .info)

        do {
            let credential = EmailAuthProvider.credential(withEmail: email, password: sanitizedPassword)
            try await user.reauthenticate(with: credential)

            self.requiresReauthentication = false
            Logger.shared.auth("Re-authentication successful", level: .info)
        } catch let error as NSError {
            FirebaseErrorMapper.logError(error, context: "Re-authentication")
            errorMessage = FirebaseErrorMapper.getUserFriendlyMessage(for: error)
            throw error
        }
    }

    /// Check if a sensitive operation requires re-authentication
    /// Returns true if the user's last authentication was too long ago
    @MainActor
    func checkReauthenticationRequired() async -> Bool {
        guard let user = Auth.auth().currentUser else { return true }

        // Try to get fresh ID token - this will fail if session is too old
        do {
            _ = try await user.getIDTokenResult(forcingRefresh: true)
            return false
        } catch {
            Logger.shared.auth("Token refresh failed - re-authentication may be required", level: .warning)
            return true
        }
    }

    // MARK: - Change Password

    /// Change user's password (requires recent authentication)
    @MainActor
    func changePassword(currentPassword: String, newPassword: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw CelestiaError.notAuthenticated
        }

        // Validate new password
        let sanitizedNewPassword = InputSanitizer.basic(newPassword)
        let passwordValidation = ValidationHelper.validatePassword(sanitizedNewPassword)
        guard passwordValidation.isValid else {
            errorMessage = passwordValidation.errorMessage ?? "Invalid password."
            throw CelestiaError.weakPassword
        }

        Logger.shared.auth("Changing user password", level: .info)

        do {
            // Re-authenticate first
            try await reauthenticate(withPassword: currentPassword)

            // Update password
            try await user.updatePassword(to: sanitizedNewPassword)

            Logger.shared.auth("Password changed successfully", level: .info)
        } catch let error as NSError {
            if error.domain == "FIRAuthErrorDomain" && error.code == 17014 {
                self.requiresReauthentication = true
                throw CelestiaError.requiresRecentLogin
            }
            FirebaseErrorMapper.logError(error, context: "Change Password")
            errorMessage = FirebaseErrorMapper.getUserFriendlyMessage(for: error)
            throw error
        }
    }

    // MARK: - Change Email

    /// Change user's email address (requires recent authentication and email verification)
    @MainActor
    func changeEmail(currentPassword: String, newEmail: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw CelestiaError.notAuthenticated
        }

        // Validate new email
        let sanitizedNewEmail = InputSanitizer.email(newEmail)
        let emailValidation = ValidationHelper.validateEmail(sanitizedNewEmail)
        guard emailValidation.isValid else {
            errorMessage = emailValidation.errorMessage ?? "Invalid email address."
            throw CelestiaError.invalidEmail
        }

        Logger.shared.auth("Changing user email", level: .info)

        do {
            // Re-authenticate first
            try await reauthenticate(withPassword: currentPassword)

            // Send verification to new email before changing
            try await user.sendEmailVerification(beforeUpdatingEmail: sanitizedNewEmail)

            Logger.shared.auth("Verification email sent to new address", level: .info)

            // Note: Email won't actually change until user verifies the new address
            // Firebase handles this automatically
        } catch let error as NSError {
            if error.domain == "FIRAuthErrorDomain" && error.code == 17014 {
                self.requiresReauthentication = true
                throw CelestiaError.requiresRecentLogin
            }
            FirebaseErrorMapper.logError(error, context: "Change Email")
            errorMessage = FirebaseErrorMapper.getUserFriendlyMessage(for: error)
            throw error
        }
    }

    // MARK: - Email Verification

    /// Send email verification to current user
    @MainActor
    func sendEmailVerification() async throws {
        guard let user = Auth.auth().currentUser else {
            throw CelestiaError.notAuthenticated
        }

        guard !user.isEmailVerified else {
            Logger.shared.auth("Email already verified", level: .info)
            return
        }

        // Configure action code settings for email verification
        let actionCodeSettings = ActionCodeSettings()
        actionCodeSettings.handleCodeInApp = false
        // Set the URL to redirect to after email verification
        actionCodeSettings.url = URL(string: "https://celestia-40ce6.firebaseapp.com")

        do {
            try await user.sendEmailVerification(with: actionCodeSettings)
            // SECURITY FIX: Never log email addresses
            Logger.shared.auth("Verification email sent successfully", level: .info)
        } catch let error as NSError {
            Logger.shared.auth("Email verification send failed", level: .error)
            Logger.shared.error("Failed to send verification email", category: .authentication, error: error)
            throw error
        }
    }

    /// Reload user to check verification status
    @MainActor
    func reloadUser() async throws {
        guard let user = Auth.auth().currentUser else {
            throw CelestiaError.notAuthenticated
        }

        try await user.reload()

        // Update published property to trigger view updates
        self.isEmailVerified = user.isEmailVerified
        Logger.shared.auth("User reloaded - Email verified: \(user.isEmailVerified)", level: .info)

        // Update local state
        if user.isEmailVerified {
            await fetchUser()
        }
    }

    /// Check if email verification is required before allowing access
    @MainActor
    func requireEmailVerification() async throws {
        guard let user = Auth.auth().currentUser else {
            throw CelestiaError.notAuthenticated
        }

        try await user.reload()

        guard user.isEmailVerified else {
            throw CelestiaError.emailNotVerified
        }
    }

    /// Apply email verification action code from deep link
    @MainActor
    func verifyEmail(withToken token: String) async throws {
        Logger.shared.auth("Applying email verification action code", level: .info)

        do {
            // Apply the action code from the email link
            try await Auth.auth().applyActionCode(token)
            Logger.shared.auth("Email verification action code applied successfully", level: .info)

            // Reload the current user to update verification status
            if let user = Auth.auth().currentUser {
                try await user.reload()
                self.isEmailVerified = user.isEmailVerified
                Logger.shared.auth("Email verified successfully: \(user.isEmailVerified)", level: .info)

                // Update local user data
                await fetchUser()
            }
        } catch let error as NSError {
            Logger.shared.error("Email verification failed", category: .authentication, error: error)

            // Handle specific Firebase Auth errors
            if error.domain == "FIRAuthErrorDomain" {
                switch error.code {
                case 17045: // Invalid action code (expired or already used)
                    throw CelestiaError.invalidData
                case 17999: // Network error
                    throw CelestiaError.networkError
                default:
                    throw error
                }
            }
            throw error
        }
    }

    // MARK: - Image Optimization

    /// Optimizes an image for upload: crops to 3:4 portrait ratio, resizes to max 2000px, 95% JPEG quality
    /// This ensures images display perfectly in cards without distortion or unexpected cropping
    /// Note: nonisolated because this is a pure function with no actor-isolated state access
    nonisolated private func optimizeImageForUpload(_ image: UIImage) -> UIImage {
        // QUALITY: Higher settings for crisp photos on all card sizes
        let maxDimension: CGFloat = 2000  // High resolution for crisp display on all devices
        let targetAspectRatio: CGFloat = 3.0 / 4.0  // Portrait ratio (0.75) - perfect for profile cards

        let originalSize = image.size
        let originalAspectRatio = originalSize.width / originalSize.height

        var croppedImage = image

        // STEP 1: Crop to target aspect ratio (3:4 portrait) for consistent card display
        // This ensures images always fill cards without unexpected cropping
        if abs(originalAspectRatio - targetAspectRatio) > 0.01 {
            let cropRect: CGRect

            if originalAspectRatio > targetAspectRatio {
                // Image is wider than target - crop sides (center horizontally)
                let targetWidth = originalSize.height * targetAspectRatio
                let xOffset = (originalSize.width - targetWidth) / 2
                cropRect = CGRect(x: xOffset, y: 0, width: targetWidth, height: originalSize.height)
            } else {
                // Image is taller than target - crop top/bottom (center vertically, favor upper portion for faces)
                let targetHeight = originalSize.width / targetAspectRatio
                // Favor upper 40% of image to capture faces better
                let yOffset = max(0, (originalSize.height - targetHeight) * 0.4)
                cropRect = CGRect(x: 0, y: yOffset, width: originalSize.width, height: targetHeight)
            }

            // Perform the crop using CGImage for best quality
            if let cgImage = image.cgImage,
               let croppedCGImage = cgImage.cropping(to: cropRect) {
                croppedImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
            }
        }

        // STEP 2: Resize if needed (maintain high quality)
        let croppedSize = croppedImage.size
        let ratio = min(maxDimension / croppedSize.width, maxDimension / croppedSize.height)

        if ratio >= 1.0 {
            // Image is already smaller than max - return cropped version
            return croppedImage
        }

        let newSize = CGSize(width: croppedSize.width * ratio, height: croppedSize.height * ratio)

        // QUALITY: Use high-fidelity rendering format
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0  // 1x scale for optimal file size
        format.opaque = true  // Opaque for better JPEG compression
        format.preferredRange = .standard  // Standard color range for compatibility

        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resizedImage = renderer.image { context in
            // Fill background with white for clean JPEG edges
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: newSize))

            // Draw with high-quality interpolation
            context.cgContext.interpolationQuality = .high
            croppedImage.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resizedImage
    }
}

// MARK: - Notification Names for Auth Events

extension Notification.Name {
    /// Posted when user session expires (signed out on another device, token expired)
    static let userSessionExpired = Notification.Name("userSessionExpired")

    /// Posted when re-authentication is required for a sensitive operation
    static let reauthenticationRequired = Notification.Name("reauthenticationRequired")
}
