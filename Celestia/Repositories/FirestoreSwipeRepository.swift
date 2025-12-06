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
        // Validate inputs at repository level as defense-in-depth
        guard !fromUserId.isEmpty, !toUserId.isEmpty else {
            Logger.shared.error("Repository received empty user IDs", category: .matching)
            throw CelestiaError.invalidInput("User IDs cannot be empty")
        }

        guard fromUserId != toUserId else {
            Logger.shared.error("Repository received self-like attempt", category: .matching)
            throw CelestiaError.invalidOperation("Cannot like yourself")
        }

        let likeData: [String: Any] = [
            "fromUserId": fromUserId,
            "toUserId": toUserId,
            "isSuperLike": isSuperLike,
            "timestamp": Timestamp(date: Date()),
            "isActive": true,
            "createdAt": FieldValue.serverTimestamp()
        ]

        let documentId = "\(fromUserId)_\(toUserId)"

        do {
            try await db.collection("likes")
                .document(documentId)
                .setData(likeData, merge: true) // Use merge to handle re-likes gracefully

            Logger.shared.debug("✅ Like persisted to Firestore: \(documentId)", category: .matching)
        } catch {
            Logger.shared.error("❌ Failed to persist like to Firestore: \(documentId)", category: .matching, error: error)
            throw error
        }
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
        // Validate inputs
        guard !fromUserId.isEmpty, !toUserId.isEmpty else {
            Logger.shared.error("checkMutualLike received empty user IDs", category: .matching)
            return false
        }

        let documentId = "\(toUserId)_\(fromUserId)"

        do {
            let mutualLikeDoc = try await db.collection("likes")
                .document(documentId)
                .getDocument()

            if mutualLikeDoc.exists,
               let data = mutualLikeDoc.data(),
               data["isActive"] as? Bool == true {
                Logger.shared.info("🎉 Mutual like detected: \(fromUserId) <-> \(toUserId)", category: .matching)
                return true
            }

            Logger.shared.debug("No mutual like found for: \(documentId)", category: .matching)
            return false
        } catch {
            Logger.shared.error("Error checking mutual like: \(documentId)", category: .matching, error: error)
            throw error
        }
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

    func checkLikeExists(fromUserId: String, toUserId: String) async throws -> Bool {
        let swipeId = "\(fromUserId)_\(toUserId)"
        let likeDoc = try await db.collection("likes").document(swipeId).getDocument()
        return likeDoc.exists && (likeDoc.data()?["isActive"] as? Bool == true)
    }

    func unlikeUser(fromUserId: String, toUserId: String) async throws {
        let swipeId = "\(fromUserId)_\(toUserId)"

        // Set isActive to false instead of deleting to preserve history
        try await db.collection("likes").document(swipeId).updateData([
            "isActive": false,
            "unlikedAt": Timestamp(date: Date())
        ])

        Logger.shared.debug("Unlike recorded: \(fromUserId) -> \(toUserId)", category: .matching)
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
