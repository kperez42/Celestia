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
    // Dependency injection: Repository for data access
    private let repository: SwipeRepository
    private let matchService: MatchService

    // Singleton for backward compatibility (uses default repository)
    static let shared = SwipeService(
        repository: FirestoreSwipeRepository(),
        matchService: MatchService.shared
    )

    // Dependency injection initializer
    init(repository: SwipeRepository, matchService: MatchService) {
        self.repository = repository
        self.matchService = matchService
    }

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

        // Save the like via repository
        try await repository.createLike(fromUserId: fromUserId, toUserId: toUserId, isSuperLike: isSuperLike)

        // Check if the other user has also liked this user (mutual like)
        let isMutualLike = try await repository.checkMutualLike(fromUserId: fromUserId, toUserId: toUserId)

        if isMutualLike {
            // It's a match! Create the match
            Logger.shared.info("Mutual like detected! Creating match", category: .matching)
            await matchService.createMatch(user1Id: fromUserId, user2Id: toUserId)
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

        // Save the pass via repository
        try await repository.createPass(fromUserId: fromUserId, toUserId: toUserId)
    }

    /// Check if user1 has already liked/passed user2
    func hasSwipedOn(fromUserId: String, toUserId: String) async throws -> (liked: Bool, passed: Bool) {
        return try await repository.hasSwipedOn(fromUserId: fromUserId, toUserId: toUserId)
    }

    /// Get all users who have liked the current user
    func getLikesReceived(userId: String) async throws -> [String] {
        return try await repository.getLikesReceived(userId: userId)
    }
}
