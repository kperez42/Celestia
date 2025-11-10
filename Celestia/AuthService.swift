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
    
    static let shared = AuthService()
    
    private init() {
        self.userSession = Auth.auth().currentUser
        print("🔵 AuthService initialized")
        print("🔵 Current user session: \(Auth.auth().currentUser?.uid ?? "none")")
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

    /// Sanitize user input
    private func sanitizeInput(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    func signIn(withEmail email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        // Sanitize inputs
        let sanitizedEmail = sanitizeInput(email)
        let sanitizedPassword = sanitizeInput(password)

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

        print("🔵 Attempting sign in with email: \(sanitizedEmail)")

        do {
            let result = try await Auth.auth().signIn(withEmail: sanitizedEmail, password: sanitizedPassword)
            self.userSession = result.user
            print("✅ Sign in successful: \(result.user.uid)")
            
            await fetchUser()
            
            if currentUser != nil {
                print("✅ User data fetched successfully")
            } else {
                print("⚠️ User session exists but no user data in Firestore")
            }
            
            isLoading = false
        } catch let error as NSError {
            isLoading = false
            
            print("❌ Sign in error:")
            print("  - Domain: \(error.domain)")
            print("  - Code: \(error.code)")
            print("  - Description: \(error.localizedDescription)")
            
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
        // Sanitize email input
        let sanitizedEmail = sanitizeInput(email)

        // Validate email format
        guard isValidEmail(sanitizedEmail) else {
            errorMessage = AppConstants.ErrorMessages.invalidEmail
            throw CelestiaError.invalidCredentials
        }

        do {
            try await Auth.auth().sendPasswordReset(withEmail: sanitizedEmail)
            print("✅ Password reset email sent to: \(sanitizedEmail)")
        } catch let error as NSError {
            print("❌ Password reset error:")
            print("  - Domain: \(error.domain)")
            print("  - Code: \(error.code)")
            print("  - Description: \(error.localizedDescription)")

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
    func createUser(withEmail email: String, password: String, fullName: String, age: Int, gender: String, lookingFor: String, location: String, country: String) async throws {
        isLoading = true
        errorMessage = nil

        // Sanitize inputs
        let sanitizedEmail = sanitizeInput(email)
        let sanitizedPassword = sanitizeInput(password)
        let sanitizedFullName = sanitizeInput(fullName)

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

        print("🔵 Creating user with email: \(sanitizedEmail)")

        do {
            // Step 1: Create Firebase Auth user
            let result = try await Auth.auth().createUser(withEmail: sanitizedEmail, password: sanitizedPassword)
            self.userSession = result.user
            print("✅ Firebase Auth user created: \(result.user.uid)")
            
            // Step 2: Create User object with all required fields
            let user = User(
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
            
            print("🔵 Attempting to save user to Firestore...")
            
            // Step 3: Save to Firestore
            let encodedUser = try Firestore.Encoder().encode(user)
            try await Firestore.firestore().collection("users").document(user.id!).setData(encodedUser)
            
            print("✅ User saved to Firestore successfully")
            
            // Step 4: Fetch user data
            await fetchUser()
            isLoading = false
            
            print("✅ Account creation completed")
        } catch let error as NSError {
            isLoading = false
            
            // Detailed error logging
            print("❌ Error creating user:")
            print("  - Domain: \(error.domain)")
            print("  - Code: \(error.code)")
            print("  - Description: \(error.localizedDescription)")
            print("  - User Info: \(error.userInfo)")
            
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
            print("✅ User signed out")
        } catch {
            print("❌ Error signing out: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func fetchUser() async {
        guard let uid = Auth.auth().currentUser?.uid else { 
            print("⚠️ No current user to fetch")
            return 
        }
        
        print("🔵 Fetching user data for: \(uid)")
        
        do {
            let snapshot = try await Firestore.firestore().collection("users").document(uid).getDocument()
            
            if snapshot.exists {
                // FIXED: Try both decoding methods
                if let data = snapshot.data() {
                    print("📄 Raw Firestore data keys: \(data.keys.joined(separator: ", "))")
                    
                    // Try using the dictionary initializer first (more forgiving)
                    self.currentUser = User(dictionary: data)
                    
                    if let user = currentUser {
                        print("✅ User data fetched successfully")
                        print("  - Name: \(user.fullName)")
                        print("  - Email: \(user.email)")
                        print("  - Location: \(user.location)")
                    }
                } else {
                    print("⚠️ Document exists but has no data")
                    // Create a minimal user document
                    await createMissingUserDocument(uid: uid)
                }
            } else {
                print("⚠️ User document does not exist in Firestore for uid: \(uid)")
                // Create the missing user document
                await createMissingUserDocument(uid: uid)
            }
        } catch {
            print("❌ Error fetching user: \(error.localizedDescription)")
            print("Full error: \(error)")
        }
    }
    
    @MainActor
    private func createMissingUserDocument(uid: String) async {
        print("🔧 Creating missing user document for uid: \(uid)")
        
        guard let firebaseUser = Auth.auth().currentUser else {
            print("❌ Cannot create document - no Firebase auth user")
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
            print("✅ Missing user document created successfully")
            
            // Now fetch it
            await fetchUser()
        } catch {
            print("❌ Error creating missing user document: \(error)")
        }
    }
    
    @MainActor
    func updateUser(_ user: User) async throws {
        guard let uid = user.id else { return }
        let encodedUser = try Firestore.Encoder().encode(user)
        try await Firestore.firestore().collection("users").document(uid).setData(encodedUser, merge: true)
        self.currentUser = user
        print("✅ User updated successfully")
    }
    
    @MainActor
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { return }
        guard let uid = user.uid as String? else { return }
        
        print("🔵 Deleting account: \(uid)")
        
        // Delete user data from Firestore
        try await Firestore.firestore().collection("users").document(uid).delete()
        
        // Delete auth account
        try await user.delete()
        
        self.userSession = nil
        self.currentUser = nil
        
        print("✅ Account deleted successfully")
    }
}
