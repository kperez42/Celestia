//
//  DiscoverViewModel.swift
//  Celestia
//
//  Handles user discovery and browsing
//

import Foundation
import FirebaseFirestore

class DiscoverViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let firestore = Firestore.firestore()
    private var lastDocument: DocumentSnapshot?
    
    func loadUsers(currentUser: User, limit: Int = 20) {
        isLoading = true
        errorMessage = ""
        
        var query = firestore.collection("users")
            .whereField("age", isGreaterThanOrEqualTo: currentUser.ageRangeMin)
            .whereField("age", isLessThanOrEqualTo: currentUser.ageRangeMax)
            .limit(to: limit)
        
        // Filter by gender preference
        if currentUser.lookingFor != "Everyone" {
            query = query.whereField("gender", isEqualTo: currentUser.lookingFor)
        }
        
        // Start after last document for pagination
        if let lastDoc = lastDocument {
            query = query.start(afterDocument: lastDoc)
        }
        
        query.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                return
            }
            
            guard let documents = snapshot?.documents else {
                self.isLoading = false
                return
            }
            
            self.lastDocument = documents.last
            
            let fetchedUsers = documents.compactMap { doc -> User? in
                let data = doc.data()
                var user = User(dictionary: data)
                user.id = doc.documentID
                
                // Don't show current user
                if user.id == currentUser.id {
                    return nil
                }
                
                return user
            }
            
            self.users.append(contentsOf: fetchedUsers)
            self.isLoading = false
        }
    }
    
    func sendInterest(from currentUserID: String, to targetUserID: String, completion: @escaping (Bool) -> Void) {
        Task {
            do {
                try await InterestService.shared.sendInterest(
                    fromUserId: currentUserID,
                    toUserId: targetUserID
                )
                await MainActor.run {
                    completion(true)
                }
            } catch {
                print("Error sending interest: \(error)")
                await MainActor.run {
                    completion(false)
                }
            }
        }
    }
}
