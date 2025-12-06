//
//  SwipeService.swift
//  Celestia
//
//  Service for handling swipes (likes/passes) and creating matches
//

import Foundation
import Firebase
import FirebaseFirestore

// MARK: - Like Retry Configuration

private struct LikeRetryConfig {
    static let maxRetries = 3
    static let baseDelaySeconds: Double = 0.5
    static let maxDelaySeconds: Double = 4.0

    static func delay(for attempt: Int) -> TimeInterval {
        let delay = baseDelaySeconds * pow(2.0, Double(attempt))
        // Add jitter to prevent thundering herd
        let jitter = Double.random(in: 0...0.3)
        return min(delay + jitter, maxDelaySeconds)
    }
}

@MainActor
class SwipeService: ObservableObject, SwipeServiceProtocol {
    // Dependency injection: Repository for data access
    private let repository: SwipeRepository
    private let matchService: MatchService

    // Track pending operations for recovery
    private var pendingLikes: Set<String> = []

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
    /// This method includes retry logic and is designed to be error-proof
    func likeUser(fromUserId: String, toUserId: String, isSuperLike: Bool = false) async throws -> Bool {
        // SECURITY: Validate input parameters
        guard !fromUserId.isEmpty, !toUserId.isEmpty else {
            Logger.shared.error("Invalid user IDs: fromUserId='\(fromUserId)', toUserId='\(toUserId)'", category: .matching)
            throw CelestiaError.invalidInput("User IDs cannot be empty")
        }

        guard fromUserId != toUserId else {
            Logger.shared.warning("Attempted self-like prevented: \(fromUserId)", category: .matching)
            throw CelestiaError.invalidOperation("Cannot like yourself")
        }

        // Create unique operation ID for tracking
        let operationId = "\(fromUserId)_\(toUserId)"

        // Prevent duplicate concurrent operations
        guard !pendingLikes.contains(operationId) else {
            Logger.shared.warning("Like operation already in progress: \(operationId)", category: .matching)
            throw CelestiaError.invalidOperation("Like already in progress")
        }

        pendingLikes.insert(operationId)
        defer { pendingLikes.remove(operationId) }

        // SECURITY: Backend rate limit validation for swipes
        try await validateRateLimit(userId: fromUserId, isSuperLike: isSuperLike)

        // Save the like with retry logic
        try await createLikeWithRetry(
            fromUserId: fromUserId,
            toUserId: toUserId,
            isSuperLike: isSuperLike
        )

        // Check for mutual match with retry logic
        let isMutualLike = await checkMutualLikeWithRetry(fromUserId: fromUserId, toUserId: toUserId)

        if isMutualLike {
            // It's a match! Create the match
            Logger.shared.info("🎉 Mutual like detected! Creating match: \(fromUserId) <-> \(toUserId)", category: .matching)
            await matchService.createMatch(user1Id: fromUserId, user2Id: toUserId)
            return true
        }

        Logger.shared.debug("✅ Like recorded successfully: \(fromUserId) -> \(toUserId)", category: .matching)
        return false
    }

    // MARK: - Private Helper Methods

    /// Validate rate limit with fallback
    private func validateRateLimit(userId: String, isSuperLike: Bool) async throws {
        do {
            let action: RateLimitAction = isSuperLike ? .sendSuperLike : .swipe
            let rateLimitResponse = try await BackendAPIService.shared.checkRateLimit(
                userId: userId,
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
            Logger.shared.warning("Backend rate limit check failed - using client-side fallback: \(error)", category: .matching)

            // Client-side rate limiting fallback
            if !isSuperLike {
                guard RateLimiter.shared.canSendLike() else {
                    throw CelestiaError.rateLimitExceeded
                }
            }
        } catch let error as CelestiaError {
            // Re-throw rate limit errors
            throw error
        } catch {
            // For other errors, allow the operation (fail open for better UX)
            Logger.shared.warning("Rate limit check failed with unexpected error, proceeding anyway: \(error)", category: .matching)
        }
    }

    /// Create like with automatic retry on transient failures
    private func createLikeWithRetry(fromUserId: String, toUserId: String, isSuperLike: Bool) async throws {
        var lastError: Error?

        for attempt in 0..<LikeRetryConfig.maxRetries {
            do {
                try await repository.createLike(fromUserId: fromUserId, toUserId: toUserId, isSuperLike: isSuperLike)
                return // Success!
            } catch {
                lastError = error

                // Check if error is retryable
                if isRetryableError(error) && attempt < LikeRetryConfig.maxRetries - 1 {
                    let delay = LikeRetryConfig.delay(for: attempt)
                    Logger.shared.warning("Like failed (attempt \(attempt + 1)/\(LikeRetryConfig.maxRetries)), retrying in \(delay)s: \(error.localizedDescription)", category: .matching)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    // Non-retryable error or max retries reached
                    break
                }
            }
        }

        // All retries failed
        Logger.shared.error("Like failed after \(LikeRetryConfig.maxRetries) attempts", category: .matching, error: lastError)
        throw lastError ?? CelestiaError.networkError
    }

    /// Check mutual like with retry logic - never miss a match!
    private func checkMutualLikeWithRetry(fromUserId: String, toUserId: String) async -> Bool {
        var lastError: Error?

        for attempt in 0..<LikeRetryConfig.maxRetries {
            do {
                let isMutual = try await repository.checkMutualLike(fromUserId: fromUserId, toUserId: toUserId)
                return isMutual
            } catch {
                lastError = error

                if attempt < LikeRetryConfig.maxRetries - 1 {
                    let delay = LikeRetryConfig.delay(for: attempt)
                    Logger.shared.warning("Mutual check failed (attempt \(attempt + 1)/\(LikeRetryConfig.maxRetries)), retrying in \(delay)s", category: .matching)
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        // Log error but don't fail the like - match will be detected on next sync
        Logger.shared.error("Mutual check failed after retries, match may be detected later", category: .matching, error: lastError)

        // Schedule a background recheck
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            await self.recheckForMissedMatch(fromUserId: fromUserId, toUserId: toUserId)
        }

        return false
    }

    /// Background recheck for missed matches
    private func recheckForMissedMatch(fromUserId: String, toUserId: String) async {
        do {
            let isMutual = try await repository.checkMutualLike(fromUserId: fromUserId, toUserId: toUserId)
            if isMutual {
                Logger.shared.info("🎉 Delayed mutual match detected: \(fromUserId) <-> \(toUserId)", category: .matching)
                await matchService.createMatch(user1Id: fromUserId, user2Id: toUserId)
            }
        } catch {
            Logger.shared.error("Background mutual check failed", category: .matching, error: error)
        }
    }

    /// Check if an error is retryable (transient network issues)
    private func isRetryableError(_ error: Error) -> Bool {
        let nsError = error as NSError

        // Network errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorTimedOut,
                 NSURLErrorCannotFindHost,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorDNSLookupFailed:
                return true
            default:
                return false
            }
        }

        // Firebase-specific errors (unavailable, deadline exceeded)
        if nsError.domain == "FIRFirestoreErrorDomain" {
            // 14 = UNAVAILABLE, 4 = DEADLINE_EXCEEDED
            return nsError.code == 14 || nsError.code == 4
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

    /// Get all users the current user has liked
    func getLikesSent(userId: String) async throws -> [String] {
        return try await repository.getLikesSent(userId: userId)
    }

    /// Delete a swipe (for rewind functionality)
    func deleteSwipe(fromUserId: String, toUserId: String) async throws {
        do {
            try await repository.deleteSwipe(fromUserId: fromUserId, toUserId: toUserId)
            Logger.shared.info("Swipe deleted for rewind", category: .matching)
        } catch {
            Logger.shared.error("Error deleting swipe", category: .matching, error: error)
            throw error
        }
    }

    /// Check if user has already liked another user
    func checkIfLiked(fromUserId: String, toUserId: String) async throws -> Bool {
        return try await repository.checkLikeExists(fromUserId: fromUserId, toUserId: toUserId)
    }

    /// Unlike a user (remove the like)
    func unlikeUser(fromUserId: String, toUserId: String) async throws {
        try await repository.unlikeUser(fromUserId: fromUserId, toUserId: toUserId)
        Logger.shared.info("User unliked: \(fromUserId) -> \(toUserId)", category: .matching)
    }
}
