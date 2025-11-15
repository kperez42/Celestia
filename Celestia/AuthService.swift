//
//  AuthService.swift
//  Celestia
//
//  Created by Kevin Perez on 10/29/25.
//

import Foundation
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

    // Singleton for backward compatibility
    static let shared = AuthService()

    // Public initializer for dependency injection (used in testing and ViewModels)
    init() {
        self.userSession = Auth.auth().currentUser
        self.isEmailVerified = Auth.auth().currentUser?.isEmailVerified ?? false
        Logger.shared.auth("AuthService initialized", level: .info)
        // SECURITY FIX: Never log UIDs or email addresses
        Logger.shared.auth("Current user session: \(Auth.auth().currentUser != nil ? "authenticated" : "none")", level: .debug)
        Logger.shared.auth("Email verified: \(isEmailVerified)", level: .info)

        // FIXED: Initialize on MainActor and track completion
        Task { @MainActor in
            await fetchUser()
            self.isInitialized = true
            Logger.shared.auth("AuthService initialization complete", level: .info)
        }
    }

    /// Wait for initial user fetch to complete
    /// Use this in views that need to ensure currentUser is loaded before proceeding
    func waitForInitialization() async {
        // If already initialized, return immediately
        guard !isInitialized else { return }

        // Poll until initialized (with timeout)
        var attempts = 0
        while !isInitialized && attempts < 50 { // 5 seconds max (50 * 100ms)
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            attempts += 1
        }

        if !isInitialized {
            Logger.shared.warning("AuthService initialization timeout", category: .authentication)
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
            self.isEmailVerified = result.user.isEmailVerified
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
    func createUser(withEmail email: String, password: String, fullName: String, age: Int, gender: String, lookingFor: String, location: String, country: String, referralCode: String = "") async throws {
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

            Logger.shared.auth("Attempting to save user to Firestore", level: .info)

            // Step 3: Save to Firestore
            guard let userId = user.id else {
                throw CelestiaError.invalidData
            }

            let encodedUser = try Firestore.Encoder().encode(user)
            try await Firestore.firestore().collection("users").document(userId).setData(encodedUser)

            Logger.shared.auth("User saved to Firestore successfully", level: .info)

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
            Logger.shared.auth("User signed out successfully", level: .info)

            // Clear user cache on logout
            Task {
                await UserService.shared.clearCache()
            }
        } catch {
            Logger.shared.error("Error signing out", category: .authentication, error: error)
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
                if let data = snapshot.data() {
                    Logger.shared.database("Raw Firestore data keys: \(data.keys.joined(separator: ", "))", level: .debug)

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

    @MainActor
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid

        // SECURITY FIX: Never log UIDs
        Logger.shared.auth("Deleting user account", level: .info)

        // Delete user data from Firestore
        try await Firestore.firestore().collection("users").document(uid).delete()

        // Delete auth account
        try await user.delete()

        self.userSession = nil
        self.currentUser = nil

        Logger.shared.auth("Account deleted successfully", level: .info)
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
}
