//
//  FirestoreSwipeRepository.swift
//  Celestia
//
//  Concrete implementation of SwipeRepository using Firestore
//  Separates data access logic from business logic
//

import Foundation
import FirebaseFirestore

class FirestoreSwipeRepository: SwipeRepository {
    private let db = Firestore.firestore()

    // MARK: - SwipeRepository Protocol Implementation

    func createLike(fromUserId: String, toUserId: String, isSuperLike: Bool) async throws {
        let likeData: [String: Any] = [
            "fromUserId": fromUserId,
            "toUserId": toUserId,
            "isSuperLike": isSuperLike,
            "timestamp": Timestamp(date: Date()),
            "isActive": true
        ]

        try await db.collection("likes")
            .document("\(fromUserId)_\(toUserId)")
            .setData(likeData)

        Logger.shared.debug("Like created: \(fromUserId) -> \(toUserId)", category: .matching)
    }

    func createPass(fromUserId: String, toUserId: String) async throws {
        let passData: [String: Any] = [
            "fromUserId": fromUserId,
            "toUserId": toUserId,
            "timestamp": Timestamp(date: Date()),
            "isActive": true
        ]

        try await db.collection("passes")
            .document("\(fromUserId)_\(toUserId)")
            .setData(passData)

        Logger.shared.debug("Pass created: \(fromUserId) -> \(toUserId)", category: .matching)
    }

    func checkMutualLike(fromUserId: String, toUserId: String) async throws -> Bool {
        let mutualLikeDoc = try await db.collection("likes")
            .document("\(toUserId)_\(fromUserId)")
            .getDocument()

        if mutualLikeDoc.exists,
           let data = mutualLikeDoc.data(),
           data["isActive"] as? Bool == true {
            Logger.shared.info("Mutual like detected: \(fromUserId) <-> \(toUserId)", category: .matching)
            return true
        }

        return false
    }

    func hasSwipedOn(fromUserId: String, toUserId: String) async throws -> (liked: Bool, passed: Bool) {
        // QUERY OPTIMIZATION: Batch both document reads in parallel
        let swipeId = "\(fromUserId)_\(toUserId)"

        async let likeDoc = db.collection("likes").document(swipeId).getDocument()
        async let passDoc = db.collection("passes").document(swipeId).getDocument()

        let (like, pass) = try await (likeDoc, passDoc)

        let hasLiked = like.exists && (like.data()?["isActive"] as? Bool == true)
        let hasPassed = pass.exists && (pass.data()?["isActive"] as? Bool == true)

        return (hasLiked, hasPassed)
    }

    /// Get user IDs who have liked this user
    /// - Parameters:
    ///   - userId: The user receiving likes
    ///   - limit: Maximum number of results (default 500 for performance)
    /// - Returns: Array of user IDs who liked this user
    func getLikesReceived(userId: String, limit: Int = 500) async throws -> [String] {
        Logger.shared.debug("Querying likes received for userId: \(userId)", category: .matching)

        // QUERY OPTIMIZATION: Added limit to prevent unbounded queries
        // For users with many likes, this prevents timeout and excessive bandwidth
        let snapshot = try await db.collection("likes")
            .whereField("toUserId", isEqualTo: userId)
            .whereField("isActive", isEqualTo: true)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()

        Logger.shared.debug("Found \(snapshot.documents.count) likes received", category: .matching)

        return snapshot.documents.compactMap { $0.data()["fromUserId"] as? String }
    }

    /// Get user IDs this user has liked
    /// - Parameters:
    ///   - userId: The user who sent likes
    ///   - limit: Maximum number of results (default 500 for performance)
    /// - Returns: Array of user IDs this user has liked
    func getLikesSent(userId: String, limit: Int = 500) async throws -> [String] {
        Logger.shared.debug("Querying likes sent for userId: \(userId)", category: .matching)

        // QUERY OPTIMIZATION: Added limit to prevent unbounded queries
        let snapshot = try await db.collection("likes")
            .whereField("fromUserId", isEqualTo: userId)
            .whereField("isActive", isEqualTo: true)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()

        Logger.shared.debug("Found \(snapshot.documents.count) likes sent", category: .matching)

        return snapshot.documents.compactMap { $0.data()["toUserId"] as? String }
    }

    /// Delete a swipe (like or pass) for rewind functionality
    func deleteSwipe(fromUserId: String, toUserId: String) async throws {
        let swipeId = "\(fromUserId)_\(toUserId)"

        // Delete from both likes and passes collections
        try await db.collection("likes").document(swipeId).delete()
        try await db.collection("passes").document(swipeId).delete()

        Logger.shared.info("Deleted swipe documents for rewind: \(swipeId)", category: .matching)
    }
}
