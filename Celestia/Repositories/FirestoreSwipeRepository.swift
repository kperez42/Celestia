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

    func getLikesReceived(userId: String) async throws -> [String] {
        let snapshot = try await db.collection("likes")
            .whereField("toUserId", isEqualTo: userId)
            .whereField("isActive", isEqualTo: true)
            .getDocuments()

        return snapshot.documents.compactMap { $0.data()["fromUserId"] as? String }
    }
}
