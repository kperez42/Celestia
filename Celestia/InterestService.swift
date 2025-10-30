//
//  InterestService.swift
//  Celestia
//
//  Created by Kevin Perez on 10/29/25.
//

import Foundation
import Firebase
import FirebaseFirestore

class InterestService: ObservableObject {
    @Published var sentInterests: [Interest] = []
    @Published var receivedInterests: [Interest] = []
    @Published var isLoading = false
    
    static let shared = InterestService()
    
    private init() {}
    
    @MainActor
    func sendInterest(fromUserId: String, toUserId: String, message: String? = nil) async throws {
        let interest = Interest(
            fromUserId: fromUserId,
            toUserId: toUserId,
            message: message
        )
        
        do {
            let encodedInterest = try Firestore.Encoder().encode(interest)
            let docRef = try await Firestore.firestore().collection("interests").addDocument(data: encodedInterest)
            
            // Check if there's a mutual interest
            await checkForMatch(interestId: docRef.documentID, fromUserId: fromUserId, toUserId: toUserId)
        } catch {
            print("Error sending interest: \(error.localizedDescription)")
            throw error
        }
    }
    
    @MainActor
    func acceptInterest(interestId: String, fromUserId: String, toUserId: String) async throws {
        do {
            // Update interest to accepted
            try await Firestore.firestore().collection("interests").document(interestId).updateData([
                "isAccepted": true
            ])
            
            // Create match
            await MatchService.shared.createMatch(user1Id: fromUserId, user2Id: toUserId)
        } catch {
            print("Error accepting interest: \(error.localizedDescription)")
            throw error
        }
    }
    
    @MainActor
    func rejectInterest(interestId: String) async throws {
        do {
            try await Firestore.firestore().collection("interests").document(interestId).updateData([
                "isAccepted": false
            ])
        } catch {
            print("Error rejecting interest: \(error.localizedDescription)")
            throw error
        }
    }
    
    @MainActor
    func fetchSentInterests(userId: String) async throws {
        isLoading = true
        
        do {
            let snapshot = try await Firestore.firestore()
                .collection("interests")
                .whereField("fromUserId", isEqualTo: userId)
                .order(by: "timestamp", descending: true)
                .getDocuments()
            
            self.sentInterests = snapshot.documents.compactMap { try? $0.data(as: Interest.self) }
            isLoading = false
        } catch {
            isLoading = false
            print("Error fetching sent interests: \(error.localizedDescription)")
            throw error
        }
    }
    
    @MainActor
    func fetchReceivedInterests(userId: String) async throws {
        isLoading = true
        
        do {
            let snapshot = try await Firestore.firestore()
                .collection("interests")
                .whereField("toUserId", isEqualTo: userId)
                .whereField("isAccepted", isEqualTo: NSNull())
                .order(by: "timestamp", descending: true)
                .getDocuments()
            
            self.receivedInterests = snapshot.documents.compactMap { try? $0.data(as: Interest.self) }
            isLoading = false
        } catch {
            isLoading = false
            print("Error fetching received interests: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func checkForMatch(interestId: String, fromUserId: String, toUserId: String) async {
        // Check if the other user has already sent an interest
        do {
            let snapshot = try await Firestore.firestore()
                .collection("interests")
                .whereField("fromUserId", isEqualTo: toUserId)
                .whereField("toUserId", isEqualTo: fromUserId)
                .getDocuments()
            
            if !snapshot.documents.isEmpty {
                // It's a match! Create the match and update both interests
                await MatchService.shared.createMatch(user1Id: fromUserId, user2Id: toUserId)
                
                // Update both interests to accepted
                try await Firestore.firestore().collection("interests").document(interestId).updateData([
                    "isAccepted": true
                ])
                
                if let otherInterestId = snapshot.documents.first?.documentID {
                    try await Firestore.firestore().collection("interests").document(otherInterestId).updateData([
                        "isAccepted": true
                    ])
                }
            }
        } catch {
            print("Error checking for match: \(error.localizedDescription)")
        }
    }
}
