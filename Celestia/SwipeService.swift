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
        // SECURITY: Backend rate limit validation for swipes
        do {
            let action: RateLimitAction = isSuperLike ? .sendSuperLike : .swipe
            let rateLimitResponse = try await BackendAPIService.shared.checkRateLimit(
                userId: fromUserId,
                action: action
            )

            if !rateLimitResponse.allowed {
                Logger.shared.warning("Backend rate limit exceeded for swipes", category: .matching)

                if let retryAfter = rateLimitResponse.retryAfter {
                    throw CelestiaError.rateLimitExceededWithTime(retryAfter)
                }

                throw CelestiaError.rateLimitExceeded
            }

            Logger.shared.debug("✅ Backend rate limit check passed for swipe (remaining: \(rateLimitResponse.remaining))", category: .matching)

        } catch let error as BackendAPIError {
            // Backend rate limit service unavailable - use client-side fallback
            Logger.shared.error("Backend rate limit check failed for swipe - using client-side fallback", category: .matching)

            // Client-side rate limiting fallback
            if !isSuperLike {
                guard RateLimiter.shared.canSendLike() else {
                    throw CelestiaError.rateLimitExceeded
                }
            }
        } catch {
            // Re-throw rate limit errors
            throw error
        }

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
        // SECURITY: Backend rate limit validation for passes/swipes
        do {
            let rateLimitResponse = try await BackendAPIService.shared.checkRateLimit(
                userId: fromUserId,
                action: .swipe
            )

            if !rateLimitResponse.allowed {
                Logger.shared.warning("Backend rate limit exceeded for passes", category: .matching)

                if let retryAfter = rateLimitResponse.retryAfter {
                    throw CelestiaError.rateLimitExceededWithTime(retryAfter)
                }

                throw CelestiaError.rateLimitExceeded
            }

            Logger.shared.debug("✅ Backend rate limit check passed for pass (remaining: \(rateLimitResponse.remaining))", category: .matching)

        } catch let error as BackendAPIError {
            // Backend rate limit service unavailable - use client-side fallback
            Logger.shared.error("Backend rate limit check failed for pass - using client-side fallback", category: .matching)

            // Client-side rate limiting fallback
            guard RateLimiter.shared.canSendLike() else {
                throw CelestiaError.rateLimitExceeded
            }
        } catch {
            // Re-throw rate limit errors
            throw error
        }

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
