//
//  InterestService.swift
//  Celestia
//
//  Service for managing interests/likes between users
//

import Foundation
import FirebaseFirestore

@MainActor
class InterestService: ObservableObject {
    @Published var receivedInterests: [Interest] = []
    @Published var sentInterests: [Interest] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    static let shared = InterestService()
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    private init() {}
    
    /// Send an interest to another user
    func sendInterest(
        fromUserId: String,
        toUserId: String,
        message: String? = nil
    ) async throws {
        // Check if interest already exists
        let existingInterest = try await fetchInterest(fromUserId: fromUserId, toUserId: toUserId)
        if existingInterest != nil {
            throw NSError(domain: "InterestService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Interest already sent"])
        }
        
        // Check if other user already sent interest (mutual match!)
        if let mutualInterest = try await fetchInterest(fromUserId: toUserId, toUserId: fromUserId) {
            // Create match
            await MatchService.shared.createMatch(user1Id: fromUserId, user2Id: toUserId)
            
            // Delete both interests
            if let mutualInterestId = mutualInterest.id {
                try await db.collection("interests").document(mutualInterestId).delete()
            }
            
            print("✅ Mutual match created!")
            return
        }
        
        // Create new interest
        let interest = Interest(
            fromUserId: fromUserId,
            toUserId: toUserId,
            message: message
        )
        
        do {
            _ = try db.collection("interests").addDocument(from: interest)
            print("✅ Interest sent successfully")
            
            // Increment likes count for sender
            try await db.collection("users").document(fromUserId).updateData([
                "likesGiven": FieldValue.increment(Int64(1))
            ])
            
            // Increment likes received for receiver
            try await db.collection("users").document(toUserId).updateData([
                "likesReceived": FieldValue.increment(Int64(1))
            ])
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// Fetch interests received by a user (pending only)
    func fetchReceivedInterests(userId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Firestore can't query for nil directly, so fetch all for this user and filter client-side
            let snapshot = try await db.collection("interests")
                .whereField("toUserId", isEqualTo: userId)
                .order(by: "timestamp", descending: true)
                .getDocuments()
            
            // Filter for pending interests (isAccepted == nil)
            receivedInterests = snapshot.documents.compactMap { doc -> Interest? in
                guard let interest = try? doc.data(as: Interest.self),
                      interest.isAccepted == nil else {
                    return nil
                }
                return interest
            }
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// Fetch interests sent by a user (pending only)
    func fetchSentInterests(userId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Firestore can't query for nil directly, so fetch all and filter client-side
            let snapshot = try await db.collection("interests")
                .whereField("fromUserId", isEqualTo: userId)
                .order(by: "timestamp", descending: true)
                .getDocuments()
            
            // Filter for pending interests (isAccepted == nil)
            sentInterests = snapshot.documents.compactMap { doc -> Interest? in
                guard let interest = try? doc.data(as: Interest.self),
                      interest.isAccepted == nil else {
                    return nil
                }
                return interest
            }
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// Listen to received interests in real-time
    func listenToReceivedInterests(userId: String) {
        listener?.remove()
        
        listener = db.collection("interests")
            .whereField("toUserId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error listening to interests: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    // Filter for pending interests (isAccepted == nil)
                    self.receivedInterests = documents.compactMap { doc -> Interest? in
                        guard let interest = try? doc.data(as: Interest.self),
                              interest.isAccepted == nil else {
                            return nil
                        }
                        return interest
                    }
                }
            }
    }
    
    /// Stop listening to interests
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    /// Accept an interest (create match)
    func acceptInterest(
        interestId: String,
        fromUserId: String,
        toUserId: String
    ) async throws {
        // Update interest status to accepted
        try await db.collection("interests").document(interestId).updateData([
            "isAccepted": true
        ])
        
        // Create match
        await MatchService.shared.createMatch(user1Id: fromUserId, user2Id: toUserId)
        
        // Delete the interest after match is created
        try await db.collection("interests").document(interestId).delete()
        
        print("✅ Interest accepted, match created!")
    }
    
    /// Reject an interest
    func rejectInterest(interestId: String) async throws {
        // Update interest status to rejected
        try await db.collection("interests").document(interestId).updateData([
            "isAccepted": false
        ])
        
        // Optionally delete rejected interests
        try await db.collection("interests").document(interestId).delete()
        
        print("✅ Interest rejected")
    }
    
    /// Check if user has already sent interest to another user
    func hasInterest(fromUserId: String, toUserId: String) async throws -> Bool {
        let interest = try await fetchInterest(fromUserId: fromUserId, toUserId: toUserId)
        return interest != nil
    }
    
    /// Fetch a specific interest (pending only)
    private func fetchInterest(fromUserId: String, toUserId: String) async throws -> Interest? {
        let snapshot = try await db.collection("interests")
            .whereField("fromUserId", isEqualTo: fromUserId)
            .whereField("toUserId", isEqualTo: toUserId)
            .limit(to: 1)
            .getDocuments()
        
        // Filter for pending interest (isAccepted == nil)
        return snapshot.documents.first(where: { doc in
            guard let interest = try? doc.data(as: Interest.self) else { return false }
            return interest.isAccepted == nil
        }).flatMap { try? $0.data(as: Interest.self) }
    }
    
    /// Get count of pending interests for a user
    func getPendingInterestCount(userId: String) async throws -> Int {
        let snapshot = try await db.collection("interests")
            .whereField("toUserId", isEqualTo: userId)
            .getDocuments()
        
        // Count only pending interests (isAccepted == nil)
        return snapshot.documents.filter { doc in
            guard let interest = try? doc.data(as: Interest.self) else { return false }
            return interest.isAccepted == nil
        }.count
    }
    
    deinit {
        listener?.remove()
    }
    
    /// Check if two users have mutual interest (both liked each other)
    func checkForMutualMatch(userId1: String, userId2: String) async throws -> Bool {
        // Check if user2 has already sent interest to user1 (and it's still pending)
        let snapshot = try await db.collection("interests")
            .whereField("fromUserId", isEqualTo: userId2)
            .whereField("toUserId", isEqualTo: userId1)
            .getDocuments()
        
        // Check if any are pending (isAccepted == nil)
        return snapshot.documents.contains { doc in
            guard let interest = try? doc.data(as: Interest.self) else { return false }
            return interest.isAccepted == nil
        }
    }
}
