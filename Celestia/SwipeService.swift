//
//  SwipeService.swift
//  Celestia
//
//  Service for handling swipes (likes/passes) and creating matches
//

import Foundation
import Firebase
import FirebaseFirestore

@MainActor
class SwipeService: ObservableObject {
    static let shared = SwipeService()
    private let db = Firestore.firestore()

    private init() {}

    /// Record a like from user1 to user2 and check for mutual match
    func likeUser(fromUserId: String, toUserId: String, isSuperLike: Bool = false) async throws -> Bool {
        let likeData: [String: Any] = [
            "fromUserId": fromUserId,
            "toUserId": toUserId,
            "isSuperLike": isSuperLike,
            "timestamp": Timestamp(date: Date()),
            "isActive": true
        ]

        // Save the like
        try await db.collection("likes")
            .document("\(fromUserId)_\(toUserId)")
            .setData(likeData)

        Logger.shared.debug("Like created: \(fromUserId) -> \(toUserId)", category: .matching)

        // Check if the other user has also liked this user (mutual like)
        let mutualLikeDoc = try await db.collection("likes")
            .document("\(toUserId)_\(fromUserId)")
            .getDocument()

        if mutualLikeDoc.exists, let data = mutualLikeDoc.data(), data["isActive"] as? Bool == true {
            // It's a match! Create the match
            Logger.shared.info("Mutual like detected! Creating match", category: .matching)
            await MatchService.shared.createMatch(user1Id: fromUserId, user2Id: toUserId)
            return true
        }

        return false
    }

    /// Record a pass (swipe left)
    func passUser(fromUserId: String, toUserId: String) async throws {
        let passData: [String: Any] = [
            "fromUserId": fromUserId,
            "toUserId": toUserId,
            "timestamp": Timestamp(date: Date()),
            "isActive": true
        ]

        // Save the pass
        try await db.collection("passes")
            .document("\(fromUserId)_\(toUserId)")
            .setData(passData)

        Logger.shared.debug("Pass created: \(fromUserId) -> \(toUserId)", category: .matching)
    }

    /// Check if user1 has already liked/passed user2
    func hasSwipedOn(fromUserId: String, toUserId: String) async throws -> (liked: Bool, passed: Bool) {
        let likeDoc = try await db.collection("likes")
            .document("\(fromUserId)_\(toUserId)")
            .getDocument()

        let passDoc = try await db.collection("passes")
            .document("\(fromUserId)_\(toUserId)")
            .getDocument()

        let hasLiked = likeDoc.exists && (likeDoc.data()?["isActive"] as? Bool == true)
        let hasPassed = passDoc.exists && (passDoc.data()?["isActive"] as? Bool == true)

        return (hasLiked, hasPassed)
    }

    /// Get all users who have liked the current user
    func getLikesReceived(userId: String) async throws -> [String] {
        let snapshot = try await db.collection("likes")
            .whereField("toUserId", isEqualTo: userId)
            .whereField("isActive", isEqualTo: true)
            .getDocuments()

        return snapshot.documents.compactMap { $0.data()["fromUserId"] as? String }
    }
}
