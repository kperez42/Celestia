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

class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    
    let auth: Auth
    let firestore: Firestore
    let storage: Storage
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    private init() {
        FirebaseApp.configure()
        
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
        firestore.collection("users").document(uid).getDocument { snapshot, error in
            if let data = snapshot?.data() {
                self.currentUser = User(dictionary: data)
            }
        }
    }
}
