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

class AuthService: ObservableObject {
    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isEmailVerified = false
    @Published var referralBonusMessage: String?
    @Published var referralErrorMessage: String?

    static let shared = AuthService()
    
    private init() {
        self.userSession = Auth.auth().currentUser
        self.isEmailVerified = Auth.auth().currentUser?.isEmailVerified ?? false
        Logger.shared.auth("AuthService initialized", level: .info)
        Logger.shared.auth("Current user session: \(Auth.auth().currentUser?.uid ?? "none")", level: .debug)
        Logger.shared.auth("Email verified: \(isEmailVerified)", level: .info)
        Task {
            await fetchUser()
        }
    }

    // MARK: - Validation

    /// Validate email format
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    /// Validate password strength
    private func isValidPassword(_ password: String) -> Bool {
        // At least 8 characters
        guard password.count >= AppConstants.Limits.minPasswordLength else { return false }

        // Contains at least one letter
        let letterRegex = ".*[A-Za-z]+.*"
        let letterPredicate = NSPredicate(format: "SELF MATCHES %@", letterRegex)
        guard letterPredicate.evaluate(with: password) else { return false }

        // Contains at least one number
        let numberRegex = ".*[0-9]+.*"
        let numberPredicate = NSPredicate(format: "SELF MATCHES %@", numberRegex)
        guard numberPredicate.evaluate(with: password) else { return false }

        return true
    }

    @MainActor
    func signIn(withEmail email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        // Sanitize inputs using centralized utility
        let sanitizedEmail = InputSanitizer.email(email)
        let sanitizedPassword = InputSanitizer.basic(password)

        // Validate email format
        guard isValidEmail(sanitizedEmail) else {
            isLoading = false
            errorMessage = AppConstants.ErrorMessages.invalidEmail
            throw CelestiaError.invalidCredentials
        }

        // Validate password is not empty
        guard !sanitizedPassword.isEmpty else {
            isLoading = false
            errorMessage = "Password cannot be empty."
            throw CelestiaError.invalidCredentials
        }

        Logger.shared.auth("Attempting sign in with email: \(sanitizedEmail)", level: .info)

        do {
            let result = try await Auth.auth().signIn(withEmail: sanitizedEmail, password: sanitizedPassword)
            self.userSession = result.user
            self.isEmailVerified = result.user.isEmailVerified
            Logger.shared.auth("Sign in successful: \(result.user.uid)", level: .info)
            Logger.shared.auth("Email verified: \(isEmailVerified)", level: .info)

            await fetchUser()

            if currentUser != nil {
                Logger.shared.auth("User data fetched successfully", level: .info)
            } else {
                Logger.shared.auth("User session exists but no user data in Firestore", level: .warning)
            }
            
            isLoading = false
        } catch let error as NSError {
            isLoading = false

            Logger.shared.auth("Sign in error - Domain: \(error.domain), Code: \(error.code)", level: .error)

            // User-friendly error messages
            if error.domain == "FIRAuthErrorDomain" {
                switch error.code {
                case 17008: // Invalid email
                    errorMessage = "Please enter a valid email address."
                case 17009: // Wrong password
                    errorMessage = "Incorrect password. Please try again."
                case 17011: // User not found
                    errorMessage = "No account found with this email."
                case 17010: // User disabled
                    errorMessage = "This account has been disabled."
                default:
                    errorMessage = "Login failed: \(error.localizedDescription)"
                }
            } else {
                errorMessage = error.localizedDescription
            }
            
            throw error
        }
    }

    @MainActor
    func resetPassword(email: String) async throws {
        // Sanitize email input using centralized utility
        let sanitizedEmail = InputSanitizer.email(email)

        // Validate email format
        guard isValidEmail(sanitizedEmail) else {
            errorMessage = AppConstants.ErrorMessages.invalidEmail
            throw CelestiaError.invalidCredentials
        }

        do {
            try await Auth.auth().sendPasswordReset(withEmail: sanitizedEmail)
            Logger.shared.auth("Password reset email sent to: \(sanitizedEmail)", level: .info)
        } catch let error as NSError {
            Logger.shared.auth("Password reset error", level: .error)
            Logger.shared.error("Password reset failed", category: .authentication, error: error)

            // User-friendly error messages
            if error.domain == "FIRAuthErrorDomain" {
                switch error.code {
                case 17008: // Invalid email
                    errorMessage = "Please enter a valid email address."
                case 17011: // User not found
                    errorMessage = "No account found with this email."
                default:
                    errorMessage = "Failed to send password reset email: \(error.localizedDescription)"
                }
            } else {
                errorMessage = error.localizedDescription
            }

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

        // Validate email format
        guard isValidEmail(sanitizedEmail) else {
            isLoading = false
            errorMessage = AppConstants.ErrorMessages.invalidEmail
            throw CelestiaError.invalidCredentials
        }

        // Validate password strength
        guard isValidPassword(sanitizedPassword) else {
            isLoading = false
            errorMessage = AppConstants.ErrorMessages.weakPassword
            throw CelestiaError.weakPassword
        }

        // Validate name is not empty
        guard !sanitizedFullName.isEmpty else {
            isLoading = false
            errorMessage = "Name cannot be empty."
            throw CelestiaError.invalidProfileData
        }

        // Validate age restriction
        guard age >= AppConstants.Limits.minAge else {
            isLoading = false
            errorMessage = AppConstants.ErrorMessages.invalidAge
            throw CelestiaError.ageRestriction
        }

        Logger.shared.auth("Creating user with email: \(sanitizedEmail)", level: .info)

        do {
            // Step 1: Create Firebase Auth user
            let result = try await Auth.auth().createUser(withEmail: sanitizedEmail, password: sanitizedPassword)
            self.userSession = result.user
            Logger.shared.auth("Firebase Auth user created: \(result.user.uid)", level: .info)

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
                Logger.shared.auth("Verification email sent to \(sanitizedEmail)", level: .info)
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
            isLoading = false

            Logger.shared.auth("Account creation completed - Please verify your email", level: .info)
        } catch let error as NSError {
            isLoading = false

            // Detailed error logging
            Logger.shared.auth("Error creating user", level: .error)
            Logger.shared.error("User creation failed - Domain: \(error.domain), Code: \(error.code)", category: .authentication, error: error)
            
            // User-friendly error messages
            if error.domain == "FIRAuthErrorDomain" {
                switch error.code {
                case 17007: // Email already in use
                    errorMessage = "This email is already registered. Please sign in instead."
                case 17008: // Invalid email
                    errorMessage = "Please enter a valid email address."
                case 17026: // Weak password
                    errorMessage = "Password should be at least 6 characters."
                default:
                    errorMessage = "Authentication error: \(error.localizedDescription)"
                }
            } else if error.domain == "FIRFirestoreErrorDomain" {
                errorMessage = "Error saving user data. Please check your internet connection."
            } else {
                errorMessage = error.localizedDescription
            }
            
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
            Logger.shared.auth("User signed out successfully", level: .info)
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

                    if let user = currentUser {
                        Logger.shared.auth("User data fetched successfully - Name: \(user.fullName), Email: \(user.email)", level: .info)
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
        guard let uid = user.uid as String? else { return }

        Logger.shared.auth("Deleting account: \(uid)", level: .info)

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
            Logger.shared.auth("Verification email sent to \(user.email ?? "")", level: .info)
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
