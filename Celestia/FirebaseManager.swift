//
//  FirebaseManager.swift
//  Celestia
//
//  Dating app for international connections
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

@MainActor
class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    
    let auth: Auth
    let firestore: Firestore
    let storage: Storage
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    private init() {
        // NOTE: Firebase is already configured in AppDelegate.didFinishLaunchingWithOptions
        // Do NOT call FirebaseApp.configure() here to avoid dual initialization

        self.auth = Auth.auth()
        self.firestore = Firestore.firestore()
        self.storage = Storage.storage()

        // Check if user is already logged in
        if let firebaseUser = auth.currentUser {
            self.isAuthenticated = true
            loadCurrentUser(uid: firebaseUser.uid)
        }
    }
    
    func loadCurrentUser(uid: String) {
        firestore.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }

            Task { @MainActor in
                if var data = snapshot?.data() {
                    // Include document ID in data (Firestore doesn't include it automatically)
                    data["id"] = uid
                    self.currentUser = User(dictionary: data)
                }
            }
        }
    }
}
