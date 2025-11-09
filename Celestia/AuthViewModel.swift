//
//  AuthViewModel.swift
//  Celestia
//
//  Handles authentication logic
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var errorMessage = ""
    @Published var isLoading = false
    
    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()
    
    init() {
        checkAuthStatus()
    }
    
    func checkAuthStatus() {
        if let firebaseUser = auth.currentUser {
            isAuthenticated = true
            loadUserData(uid: firebaseUser.uid)
        }
    }
    
    func signUp(email: String, password: String, name: String, age: Int, gender: String, lookingFor: String, location: String, country: String, referralCode: String = "") {
        isLoading = true
        errorMessage = ""

        auth.createUser(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                return
            }

            guard let firebaseUser = result?.user else {
                self.errorMessage = "Failed to create user"
                self.isLoading = false
                return
            }

            // Create user document in Firestore
            var user = User(
                id: firebaseUser.uid,
                email: email,
                fullName: name,
                age: age,
                gender: gender,
                lookingFor: lookingFor,
                location: location,
                country: country
            )

            // Store referral code if provided
            if !referralCode.isEmpty {
                user.referredByCode = referralCode.uppercased().trimmingCharacters(in: .whitespaces)
            }

            self.saveUserToFirestore(user: user, referralCode: referralCode)
        }
    }
    
    func signIn(email: String, password: String) {
        isLoading = true
        errorMessage = ""
        
        auth.signIn(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                return
            }
            
            guard let firebaseUser = result?.user else {
                self.errorMessage = "Failed to sign in"
                self.isLoading = false
                return
            }
            
            self.loadUserData(uid: firebaseUser.uid)
        }
    }
    
    func signOut() {
        do {
            try auth.signOut()
            isAuthenticated = false
            currentUser = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func loadCurrentUser() async {
        guard let uid = auth.currentUser?.uid else { return }
        
        await MainActor.run {
            self.loadUserData(uid: uid)
        }
    }
    
    private func saveUserToFirestore(user: User, referralCode: String = "") {
        do {
            try firestore.collection("users").document(user.id!).setData(from: user) { [weak self] error in
                guard let self = self else { return }

                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }

                // Initialize referral code and process referral asynchronously
                Task { @MainActor in
                    var updatedUser = user

                    // Generate unique referral code for new user
                    try? await ReferralManager.shared.initializeReferralCode(for: &updatedUser)

                    // Process referral if code was provided
                    if !referralCode.isEmpty {
                        try? await ReferralManager.shared.processReferralSignup(
                            newUser: updatedUser,
                            referralCode: referralCode.uppercased().trimmingCharacters(in: .whitespaces)
                        )
                    }

                    self.currentUser = updatedUser
                    self.isAuthenticated = true
                    self.isLoading = false
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    private func loadUserData(uid: String) {
        firestore.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                return
            }
            
            guard let data = snapshot?.data() else {
                self.errorMessage = "User data not found"
                self.isLoading = false
                return
            }
            
            self.currentUser = User(dictionary: data)
            self.isAuthenticated = true
            self.isLoading = false
        }
    }
}
