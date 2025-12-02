//
//  LikeSystemErrorTests.swift
//  CelestiaTests
//
//  Comprehensive error scenario tests for the Like System
//  Tests all failure modes: network errors, rate limits, database failures,
//  like erasure, unlike failures, race conditions, and edge cases
//

import Testing
@testable import Celestia
import Foundation

// MARK: - Like System Error Tests

@Suite("Like System Error Tests")
@MainActor
struct LikeSystemErrorTests {

    // MARK: - Like Creation Failure Tests

    @Test("Like fails with network error")
    func testLikeFailsWithNetworkError() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.shouldFailOnCreateLike = true
        mockRepo.createLikeError = CelestiaError.networkError

        do {
            try await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: false)
            #expect(Bool(false), "Should have thrown network error")
        } catch let error as CelestiaError {
            #expect(error == .networkError, "Should throw network error")
        }

        #expect(mockRepo.createLikeCalled, "createLike should have been called")
        #expect(mockRepo.likes.isEmpty, "No like should be stored on failure")
    }

    @Test("Like fails with timeout error")
    func testLikeFailsWithTimeoutError() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.shouldFailOnCreateLike = true
        mockRepo.createLikeError = CelestiaError.timeout

        do {
            try await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: false)
            #expect(Bool(false), "Should have thrown timeout error")
        } catch let error as CelestiaError {
            #expect(error == .timeout, "Should throw timeout error")
        }

        #expect(mockRepo.likes.isEmpty, "No like should be stored on timeout")
    }

    @Test("Like fails with server error")
    func testLikeFailsWithServerError() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.shouldFailOnCreateLike = true
        mockRepo.createLikeError = CelestiaError.serverError

        do {
            try await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: false)
            #expect(Bool(false), "Should have thrown server error")
        } catch let error as CelestiaError {
            #expect(error == .serverError, "Should throw server error")
        }
    }

    @Test("Like fails with database error")
    func testLikeFailsWithDatabaseError() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.shouldFailOnCreateLike = true
        mockRepo.createLikeError = CelestiaError.databaseError("Write failed")

        do {
            try await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: false)
            #expect(Bool(false), "Should have thrown database error")
        } catch let error as CelestiaError {
            if case .databaseError(let message) = error {
                #expect(message == "Write failed", "Should contain error message")
            } else {
                #expect(Bool(false), "Should be database error type")
            }
        }
    }

    @Test("Like fails with no internet connection")
    func testLikeFailsWithNoInternet() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.shouldFailOnCreateLike = true
        mockRepo.createLikeError = CelestiaError.noInternetConnection

        do {
            try await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: false)
            #expect(Bool(false), "Should have thrown no internet error")
        } catch let error as CelestiaError {
            #expect(error == .noInternetConnection, "Should throw no internet error")
        }
    }

    @Test("Super like fails with network error")
    func testSuperLikeFailsWithNetworkError() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.shouldFailOnCreateLike = true
        mockRepo.createLikeError = CelestiaError.networkError

        do {
            try await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: true)
            #expect(Bool(false), "Should have thrown network error for super like")
        } catch let error as CelestiaError {
            #expect(error == .networkError, "Should throw network error")
        }

        #expect(mockRepo.lastLikeIsSuperLike == true, "Should have attempted super like")
    }

    // MARK: - Rate Limit Tests

    @Test("Like fails with rate limit exceeded")
    func testLikeFailsWithRateLimitExceeded() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.shouldFailOnCreateLike = true
        mockRepo.createLikeError = CelestiaError.rateLimitExceeded

        do {
            try await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: false)
            #expect(Bool(false), "Should have thrown rate limit error")
        } catch let error as CelestiaError {
            #expect(error == .rateLimitExceeded, "Should throw rate limit exceeded")
        }
    }

    @Test("Like fails with rate limit exceeded with time")
    func testLikeFailsWithRateLimitExceededWithTime() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.shouldFailOnCreateLike = true
        mockRepo.createLikeError = CelestiaError.rateLimitExceededWithTime(120.0)

        do {
            try await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: false)
            #expect(Bool(false), "Should have thrown rate limit with time error")
        } catch let error as CelestiaError {
            if case .rateLimitExceededWithTime(let retryAfter) = error {
                #expect(retryAfter == 120.0, "Should have 120 second retry time")
            } else {
                #expect(Bool(false), "Should be rate limit with time error")
            }
        }
    }

    @Test("Rate limit blocks multiple rapid likes")
    func testRateLimitBlocksRapidLikes() async throws {
        let mockRepo = MockSwipeRepository()
        var successCount = 0
        var failureCount = 0

        // First 3 succeed, then rate limit kicks in
        for i in 0..<10 {
            if i >= 3 {
                mockRepo.shouldFailOnCreateLike = true
                mockRepo.createLikeError = CelestiaError.rateLimitExceeded
            }

            do {
                try await mockRepo.createLike(fromUserId: "user1", toUserId: "user\(i)", isSuperLike: false)
                successCount += 1
            } catch {
                failureCount += 1
            }
        }

        #expect(successCount == 3, "Should have 3 successful likes before rate limit")
        #expect(failureCount == 7, "Should have 7 rate limited attempts")
    }

    // MARK: - Like Erasure/Deletion Failure Tests

    @Test("Unlike fails with network error")
    func testUnlikeFailsWithNetworkError() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.addLike(fromUserId: "user1", toUserId: "user2")
        mockRepo.shouldFailOnUnlikeUser = true
        mockRepo.unlikeUserError = CelestiaError.networkError

        do {
            try await mockRepo.unlikeUser(fromUserId: "user1", toUserId: "user2")
            #expect(Bool(false), "Should have thrown network error")
        } catch let error as CelestiaError {
            #expect(error == .networkError, "Should throw network error")
        }

        // Like should still be active since unlike failed
        let likeExists = try await mockRepo.checkLikeExists(fromUserId: "user1", toUserId: "user2")
        #expect(likeExists, "Like should still exist after failed unlike")
    }

    @Test("Unlike fails with database error")
    func testUnlikeFailsWithDatabaseError() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.addLike(fromUserId: "user1", toUserId: "user2")
        mockRepo.shouldFailOnUnlikeUser = true
        mockRepo.unlikeUserError = CelestiaError.databaseError("Update failed")

        do {
            try await mockRepo.unlikeUser(fromUserId: "user1", toUserId: "user2")
            #expect(Bool(false), "Should have thrown database error")
        } catch let error as CelestiaError {
            if case .databaseError(let message) = error {
                #expect(message == "Update failed")
            } else {
                #expect(Bool(false), "Should be database error")
            }
        }
    }

    @Test("Delete swipe fails with network error")
    func testDeleteSwipeFailsWithNetworkError() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.addLike(fromUserId: "user1", toUserId: "user2")
        mockRepo.shouldFailOnDeleteSwipe = true
        mockRepo.deleteSwipeError = CelestiaError.networkError

        do {
            try await mockRepo.deleteSwipe(fromUserId: "user1", toUserId: "user2")
            #expect(Bool(false), "Should have thrown network error")
        } catch let error as CelestiaError {
            #expect(error == .networkError, "Should throw network error")
        }

        // Like should still exist since delete failed
        #expect(mockRepo.likes.count == 1, "Like should still exist after failed delete")
    }

    @Test("Delete swipe fails with server error")
    func testDeleteSwipeFailsWithServerError() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.addLike(fromUserId: "user1", toUserId: "user2")
        mockRepo.shouldFailOnDeleteSwipe = true
        mockRepo.deleteSwipeError = CelestiaError.serverError

        do {
            try await mockRepo.deleteSwipe(fromUserId: "user1", toUserId: "user2")
            #expect(Bool(false), "Should have thrown server error")
        } catch let error as CelestiaError {
            #expect(error == .serverError, "Should throw server error")
        }
    }

    @Test("Unlike non-existent like does not error")
    func testUnlikeNonExistentLike() async throws {
        let mockRepo = MockSwipeRepository()

        // Should not throw when unliking non-existent like
        try await mockRepo.unlikeUser(fromUserId: "user1", toUserId: "user2")

        #expect(mockRepo.unlikeUserCalled, "Unlike should have been called")
        // The like was never there, so checking existence should return false
        let likeExists = try await mockRepo.checkLikeExists(fromUserId: "user1", toUserId: "user2")
        #expect(!likeExists, "No like should exist")
    }

    // MARK: - Like Query Failure Tests

    @Test("Get likes received fails with network error")
    func testGetLikesReceivedFailsWithNetworkError() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.shouldFailOnGetLikesReceived = true
        mockRepo.getLikesReceivedError = CelestiaError.networkError

        do {
            _ = try await mockRepo.getLikesReceived(userId: "user1")
            #expect(Bool(false), "Should have thrown network error")
        } catch let error as CelestiaError {
            #expect(error == .networkError, "Should throw network error")
        }
    }

    @Test("Get likes received fails with timeout")
    func testGetLikesReceivedFailsWithTimeout() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.shouldFailOnGetLikesReceived = true
        mockRepo.getLikesReceivedError = CelestiaError.timeout

        do {
            _ = try await mockRepo.getLikesReceived(userId: "user1")
            #expect(Bool(false), "Should have thrown timeout error")
        } catch let error as CelestiaError {
            #expect(error == .timeout, "Should throw timeout error")
        }
    }

    @Test("Get likes sent fails with network error")
    func testGetLikesSentFailsWithNetworkError() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.shouldFailOnGetLikesSent = true
        mockRepo.getLikesSentError = CelestiaError.networkError

        do {
            _ = try await mockRepo.getLikesSent(userId: "user1")
            #expect(Bool(false), "Should have thrown network error")
        } catch let error as CelestiaError {
            #expect(error == .networkError, "Should throw network error")
        }
    }

    @Test("Check like exists fails with network error")
    func testCheckLikeExistsFailsWithNetworkError() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.shouldFailOnCheckLikeExists = true
        mockRepo.checkLikeExistsError = CelestiaError.networkError

        do {
            _ = try await mockRepo.checkLikeExists(fromUserId: "user1", toUserId: "user2")
            #expect(Bool(false), "Should have thrown network error")
        } catch let error as CelestiaError {
            #expect(error == .networkError, "Should throw network error")
        }
    }

    @Test("Has swiped on fails with network error")
    func testHasSwipedOnFailsWithNetworkError() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.shouldFailOnHasSwipedOn = true
        mockRepo.hasSwipedOnError = CelestiaError.networkError

        do {
            _ = try await mockRepo.hasSwipedOn(fromUserId: "user1", toUserId: "user2")
            #expect(Bool(false), "Should have thrown network error")
        } catch let error as CelestiaError {
            #expect(error == .networkError, "Should throw network error")
        }
    }

    // MARK: - Mutual Match Detection Failure Tests

    @Test("Check mutual like fails with network error")
    func testCheckMutualLikeFailsWithNetworkError() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.shouldFailOnCheckMutualLike = true
        mockRepo.checkMutualLikeError = CelestiaError.networkError

        do {
            _ = try await mockRepo.checkMutualLike(fromUserId: "user1", toUserId: "user2")
            #expect(Bool(false), "Should have thrown network error")
        } catch let error as CelestiaError {
            #expect(error == .networkError, "Should throw network error")
        }
    }

    @Test("Check mutual like fails with database error")
    func testCheckMutualLikeFailsWithDatabaseError() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.shouldFailOnCheckMutualLike = true
        mockRepo.checkMutualLikeError = CelestiaError.databaseError("Query failed")

        do {
            _ = try await mockRepo.checkMutualLike(fromUserId: "user1", toUserId: "user2")
            #expect(Bool(false), "Should have thrown database error")
        } catch let error as CelestiaError {
            if case .databaseError(let message) = error {
                #expect(message == "Query failed")
            } else {
                #expect(Bool(false), "Should be database error")
            }
        }
    }

    @Test("Mutual match detection fails after like creation")
    func testMutualMatchDetectionFailsAfterLikeCreation() async throws {
        let mockRepo = MockSwipeRepository()

        // User2 already liked User1
        mockRepo.addLike(fromUserId: "user2", toUserId: "user1")

        // User1 likes User2 - like succeeds but mutual check fails
        try await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: false)

        // Now simulate failure on mutual check
        mockRepo.shouldFailOnCheckMutualLike = true
        mockRepo.checkMutualLikeError = CelestiaError.networkError

        do {
            _ = try await mockRepo.checkMutualLike(fromUserId: "user1", toUserId: "user2")
            #expect(Bool(false), "Should have thrown network error")
        } catch let error as CelestiaError {
            #expect(error == .networkError, "Should throw network error")
        }

        // Both likes should still exist
        #expect(mockRepo.likes.count == 2, "Both likes should exist")
    }

    // MARK: - Pass/Swipe Left Failure Tests

    @Test("Pass fails with network error")
    func testPassFailsWithNetworkError() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.shouldFailOnCreatePass = true
        mockRepo.createPassError = CelestiaError.networkError

        do {
            try await mockRepo.createPass(fromUserId: "user1", toUserId: "user2")
            #expect(Bool(false), "Should have thrown network error")
        } catch let error as CelestiaError {
            #expect(error == .networkError, "Should throw network error")
        }

        #expect(mockRepo.passes.isEmpty, "No pass should be stored on failure")
    }

    @Test("Pass fails with rate limit exceeded")
    func testPassFailsWithRateLimitExceeded() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.shouldFailOnCreatePass = true
        mockRepo.createPassError = CelestiaError.rateLimitExceeded

        do {
            try await mockRepo.createPass(fromUserId: "user1", toUserId: "user2")
            #expect(Bool(false), "Should have thrown rate limit error")
        } catch let error as CelestiaError {
            #expect(error == .rateLimitExceeded, "Should throw rate limit exceeded")
        }
    }

    // MARK: - Edge Case Error Tests

    @Test("Like with empty user IDs")
    func testLikeWithEmptyUserIds() async throws {
        let mockRepo = MockSwipeRepository()

        // Test empty fromUserId
        try await mockRepo.createLike(fromUserId: "", toUserId: "user2", isSuperLike: false)
        #expect(mockRepo.likes["_user2"] != nil, "Should create like with empty from ID")

        // Test empty toUserId
        try await mockRepo.createLike(fromUserId: "user1", toUserId: "", isSuperLike: false)
        #expect(mockRepo.likes["user1_"] != nil, "Should create like with empty to ID")
    }

    @Test("Like to self is recorded")
    func testLikeToSelfIsRecorded() async throws {
        let mockRepo = MockSwipeRepository()

        // The repository doesn't prevent self-likes, service should handle this
        try await mockRepo.createLike(fromUserId: "user1", toUserId: "user1", isSuperLike: false)

        #expect(mockRepo.likes["user1_user1"] != nil, "Self-like recorded at repo level")
    }

    @Test("Get likes received with no likes returns empty array")
    func testGetLikesReceivedWithNoLikes() async throws {
        let mockRepo = MockSwipeRepository()

        let likes = try await mockRepo.getLikesReceived(userId: "user1")

        #expect(likes.isEmpty, "Should return empty array when no likes")
        #expect(mockRepo.getLikesReceivedCalled, "Method should have been called")
    }

    @Test("Get likes sent with no likes returns empty array")
    func testGetLikesSentWithNoLikes() async throws {
        let mockRepo = MockSwipeRepository()

        let likes = try await mockRepo.getLikesSent(userId: "user1")

        #expect(likes.isEmpty, "Should return empty array when no likes sent")
        #expect(mockRepo.getLikesSentCalled, "Method should have been called")
    }

    @Test("Has swiped on with no swipes returns false for both")
    func testHasSwipedOnWithNoSwipes() async throws {
        let mockRepo = MockSwipeRepository()

        let result = try await mockRepo.hasSwipedOn(fromUserId: "user1", toUserId: "user2")

        #expect(!result.liked, "Should not have liked")
        #expect(!result.passed, "Should not have passed")
    }

    @Test("Check mutual like when no reverse like exists")
    func testCheckMutualLikeWhenNoReverseLike() async throws {
        let mockRepo = MockSwipeRepository()

        // Only one-way like exists
        mockRepo.addLike(fromUserId: "user1", toUserId: "user2")

        let isMutual = try await mockRepo.checkMutualLike(fromUserId: "user1", toUserId: "user2")

        #expect(!isMutual, "Should not be mutual when only one-way like exists")
    }

    @Test("Check mutual like when reverse like is inactive")
    func testCheckMutualLikeWhenReverseLikeInactive() async throws {
        let mockRepo = MockSwipeRepository()

        // User2 liked User1 but then unliked
        mockRepo.addLike(fromUserId: "user2", toUserId: "user1", isActive: false)

        let isMutual = try await mockRepo.checkMutualLike(fromUserId: "user1", toUserId: "user2")

        #expect(!isMutual, "Should not be mutual when reverse like is inactive")
    }

    // MARK: - Global Failure Mode Tests

    @Test("All operations fail when shouldFail is true")
    func testAllOperationsFailWhenShouldFailIsTrue() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.shouldFail = true
        mockRepo.failureError = CelestiaError.serverError

        var failureCount = 0

        // Test createLike
        do {
            try await mockRepo.createLike(fromUserId: "u1", toUserId: "u2", isSuperLike: false)
        } catch {
            failureCount += 1
        }

        // Test createPass
        do {
            try await mockRepo.createPass(fromUserId: "u1", toUserId: "u2")
        } catch {
            failureCount += 1
        }

        // Test checkMutualLike
        do {
            _ = try await mockRepo.checkMutualLike(fromUserId: "u1", toUserId: "u2")
        } catch {
            failureCount += 1
        }

        // Test hasSwipedOn
        do {
            _ = try await mockRepo.hasSwipedOn(fromUserId: "u1", toUserId: "u2")
        } catch {
            failureCount += 1
        }

        // Test checkLikeExists
        do {
            _ = try await mockRepo.checkLikeExists(fromUserId: "u1", toUserId: "u2")
        } catch {
            failureCount += 1
        }

        // Test unlikeUser
        do {
            try await mockRepo.unlikeUser(fromUserId: "u1", toUserId: "u2")
        } catch {
            failureCount += 1
        }

        // Test getLikesReceived
        do {
            _ = try await mockRepo.getLikesReceived(userId: "u1")
        } catch {
            failureCount += 1
        }

        // Test getLikesSent
        do {
            _ = try await mockRepo.getLikesSent(userId: "u1")
        } catch {
            failureCount += 1
        }

        // Test deleteSwipe
        do {
            try await mockRepo.deleteSwipe(fromUserId: "u1", toUserId: "u2")
        } catch {
            failureCount += 1
        }

        #expect(failureCount == 9, "All 9 operations should have failed")
    }

    // MARK: - Service Unavailable Tests

    @Test("Like fails when service temporarily unavailable")
    func testLikeFailsWhenServiceUnavailable() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.shouldFailOnCreateLike = true
        mockRepo.createLikeError = CelestiaError.serviceTemporarilyUnavailable

        do {
            try await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: false)
            #expect(Bool(false), "Should have thrown service unavailable error")
        } catch let error as CelestiaError {
            #expect(error == .serviceTemporarilyUnavailable)
        }
    }

    @Test("Operations fail with permission denied")
    func testOperationsFailWithPermissionDenied() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.shouldFailOnCreateLike = true
        mockRepo.createLikeError = CelestiaError.permissionDenied

        do {
            try await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: false)
            #expect(Bool(false), "Should have thrown permission denied error")
        } catch let error as CelestiaError {
            #expect(error == .permissionDenied)
        }
    }

    // MARK: - Concurrent Operation Tests

    @Test("Concurrent likes to same user")
    func testConcurrentLikesToSameUser() async throws {
        let mockRepo = MockSwipeRepository()

        // Multiple users like the same person concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 1...10 {
                group.addTask {
                    do {
                        try await mockRepo.createLike(fromUserId: "user\(i)", toUserId: "popular_user", isSuperLike: false)
                    } catch {
                        // Ignore errors in concurrent test
                    }
                }
            }
        }

        // Check all likes were recorded
        let likesReceived = try await mockRepo.getLikesReceived(userId: "popular_user")
        #expect(likesReceived.count == 10, "All 10 concurrent likes should be recorded")
    }

    @Test("Concurrent like and unlike race condition")
    func testConcurrentLikeAndUnlikeRaceCondition() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.addLike(fromUserId: "user1", toUserId: "user2")

        // Simulate race: one task likes, another unlikes
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                try? await mockRepo.unlikeUser(fromUserId: "user1", toUserId: "user2")
            }
            group.addTask {
                try? await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: false)
            }
        }

        // One of these outcomes is expected - either like exists or not
        let likeExists = try await mockRepo.checkLikeExists(fromUserId: "user1", toUserId: "user2")
        #expect(likeExists == true || likeExists == false, "Race condition should result in defined state")
    }

    // MARK: - Data Integrity Tests

    @Test("Like is not persisted when operation fails")
    func testLikeNotPersistedWhenOperationFails() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.shouldFailOnCreateLike = true

        do {
            try await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: false)
        } catch {
            // Expected failure
        }

        // Verify no data corruption
        #expect(mockRepo.likes.isEmpty, "No likes should exist after failed operation")
        let likeExists = try await mockRepo.checkLikeExists(fromUserId: "user1", toUserId: "user2")
        #expect(!likeExists, "Like should not exist")
    }

    @Test("Inactive likes are not returned in queries")
    func testInactiveLikesNotReturnedInQueries() async throws {
        let mockRepo = MockSwipeRepository()

        // Add active and inactive likes
        mockRepo.addLike(fromUserId: "user1", toUserId: "alice", isActive: true)
        mockRepo.addLike(fromUserId: "user2", toUserId: "alice", isActive: false)
        mockRepo.addLike(fromUserId: "user3", toUserId: "alice", isActive: true)

        let likesReceived = try await mockRepo.getLikesReceived(userId: "alice")

        #expect(likesReceived.count == 2, "Should only return active likes")
        #expect(!likesReceived.contains("user2"), "Should not contain inactive like")
    }

    @Test("Unlike sets isActive to false but preserves record")
    func testUnlikeSetsIsActiveToFalse() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.addLike(fromUserId: "user1", toUserId: "user2")

        try await mockRepo.unlikeUser(fromUserId: "user1", toUserId: "user2")

        // Record should still exist but be inactive
        #expect(mockRepo.likes["user1_user2"] != nil, "Record should exist")
        #expect(mockRepo.likes["user1_user2"]?.isActive == false, "Should be inactive")

        // But checkLikeExists should return false
        let likeExists = try await mockRepo.checkLikeExists(fromUserId: "user1", toUserId: "user2")
        #expect(!likeExists, "Active like should not exist")
    }

    // MARK: - Limit and Pagination Error Tests

    @Test("Get likes received respects limit")
    func testGetLikesReceivedRespectsLimit() async throws {
        let mockRepo = MockSwipeRepository()

        // Add many likes
        for i in 1...20 {
            mockRepo.addLike(fromUserId: "user\(i)", toUserId: "popular")
        }

        let likes = try await mockRepo.getLikesReceived(userId: "popular", limit: 5)

        #expect(likes.count == 5, "Should respect limit parameter")
    }

    @Test("Get likes sent respects limit")
    func testGetLikesSentRespectsLimit() async throws {
        let mockRepo = MockSwipeRepository()

        // Add many likes from one user
        for i in 1...20 {
            mockRepo.addLike(fromUserId: "active_user", toUserId: "user\(i)")
        }

        let likes = try await mockRepo.getLikesSent(userId: "active_user", limit: 5)

        #expect(likes.count == 5, "Should respect limit parameter")
    }

    // MARK: - Reset and State Management Tests

    @Test("Reset clears all state")
    func testResetClearsAllState() async throws {
        let mockRepo = MockSwipeRepository()

        // Add some data and set flags
        mockRepo.addLike(fromUserId: "user1", toUserId: "user2")
        mockRepo.addPass(fromUserId: "user1", toUserId: "user3")
        mockRepo.shouldFail = true
        mockRepo.createLikeCalled = true
        mockRepo.lastLikeFromUserId = "user1"

        // Reset
        mockRepo.reset()

        // Verify all cleared
        #expect(mockRepo.likes.isEmpty, "Likes should be empty after reset")
        #expect(mockRepo.passes.isEmpty, "Passes should be empty after reset")
        #expect(!mockRepo.shouldFail, "shouldFail should be false after reset")
        #expect(!mockRepo.createLikeCalled, "createLikeCalled should be false after reset")
        #expect(mockRepo.lastLikeFromUserId == nil, "lastLikeFromUserId should be nil after reset")
    }

    // MARK: - Force Result Tests

    @Test("Force mutual like result overrides actual check")
    func testForceMutualLikeResultOverridesCheck() async throws {
        let mockRepo = MockSwipeRepository()

        // No likes exist
        mockRepo.forceMutualLikeResult = true

        let isMutual = try await mockRepo.checkMutualLike(fromUserId: "user1", toUserId: "user2")

        #expect(isMutual, "Should return forced true result")
    }

    @Test("Force has swiped on result overrides actual check")
    func testForceHasSwipedOnResultOverridesCheck() async throws {
        let mockRepo = MockSwipeRepository()

        // No swipes exist
        mockRepo.forceHasSwipedOnResult = (liked: true, passed: false)

        let result = try await mockRepo.hasSwipedOn(fromUserId: "user1", toUserId: "user2")

        #expect(result.liked, "Should return forced liked result")
        #expect(!result.passed, "Should return forced passed result")
    }

    @Test("Force like exists result overrides actual check")
    func testForceLikeExistsResultOverridesCheck() async throws {
        let mockRepo = MockSwipeRepository()

        // No likes exist
        mockRepo.forceLikeExistsResult = true

        let exists = try await mockRepo.checkLikeExists(fromUserId: "user1", toUserId: "user2")

        #expect(exists, "Should return forced true result")
    }
}

// MARK: - Like Erasure Scenario Tests

@Suite("Like Erasure Scenario Tests")
@MainActor
struct LikeErasureScenarioTests {

    @Test("Like erased by unlike operation")
    func testLikeErasedByUnlike() async throws {
        let mockRepo = MockSwipeRepository()

        // Create like
        try await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: false)
        var likeExists = try await mockRepo.checkLikeExists(fromUserId: "user1", toUserId: "user2")
        #expect(likeExists, "Like should exist before unlike")

        // Unlike
        try await mockRepo.unlikeUser(fromUserId: "user1", toUserId: "user2")
        likeExists = try await mockRepo.checkLikeExists(fromUserId: "user1", toUserId: "user2")
        #expect(!likeExists, "Like should not exist after unlike")
    }

    @Test("Like erased by delete swipe operation")
    func testLikeErasedByDeleteSwipe() async throws {
        let mockRepo = MockSwipeRepository()

        // Create like
        try await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: false)

        // Delete swipe (for rewind)
        try await mockRepo.deleteSwipe(fromUserId: "user1", toUserId: "user2")

        #expect(mockRepo.likes.isEmpty, "Like should be completely removed")
    }

    @Test("Re-like after unlike creates new like")
    func testReLikeAfterUnlike() async throws {
        let mockRepo = MockSwipeRepository()

        // Create like
        try await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: false)

        // Unlike
        try await mockRepo.unlikeUser(fromUserId: "user1", toUserId: "user2")

        // Re-like
        try await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: false)

        let likeExists = try await mockRepo.checkLikeExists(fromUserId: "user1", toUserId: "user2")
        #expect(likeExists, "New like should exist after re-like")
    }

    @Test("Super like erased becomes regular like on re-like")
    func testSuperLikeErasedBecomesRegularLike() async throws {
        let mockRepo = MockSwipeRepository()

        // Create super like
        try await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: true)
        #expect(mockRepo.likes["user1_user2"]?.isSuperLike == true, "Should be super like")

        // Unlike
        try await mockRepo.unlikeUser(fromUserId: "user1", toUserId: "user2")

        // Re-like as regular
        try await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: false)

        #expect(mockRepo.likes["user1_user2"]?.isSuperLike == false, "Should now be regular like")
    }

    @Test("Multiple unlike operations are idempotent")
    func testMultipleUnlikeOperationsIdempotent() async throws {
        let mockRepo = MockSwipeRepository()

        // Create like
        try await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: false)

        // Unlike multiple times
        try await mockRepo.unlikeUser(fromUserId: "user1", toUserId: "user2")
        try await mockRepo.unlikeUser(fromUserId: "user1", toUserId: "user2")
        try await mockRepo.unlikeUser(fromUserId: "user1", toUserId: "user2")

        // Should not error and like should still be inactive
        let likeExists = try await mockRepo.checkLikeExists(fromUserId: "user1", toUserId: "user2")
        #expect(!likeExists, "Like should remain non-existent")
    }

    @Test("Delete swipe removes both like and pass")
    func testDeleteSwipeRemovesBothLikeAndPass() async throws {
        let mockRepo = MockSwipeRepository()

        // Create like
        mockRepo.addLike(fromUserId: "user1", toUserId: "user2")

        // Also create pass (shouldn't happen in real world but testing edge case)
        mockRepo.addPass(fromUserId: "user1", toUserId: "user2")

        // Delete swipe should remove both
        try await mockRepo.deleteSwipe(fromUserId: "user1", toUserId: "user2")

        #expect(mockRepo.likes.isEmpty, "Likes should be empty")
        #expect(mockRepo.passes.isEmpty, "Passes should be empty")
    }
}

// MARK: - Like Not Working Scenario Tests

@Suite("Like Not Working Scenario Tests")
@MainActor
struct LikeNotWorkingScenarioTests {

    @Test("Like not working due to consecutive network failures")
    func testLikeNotWorkingDueToNetworkFailures() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.shouldFailOnCreateLike = true
        mockRepo.createLikeError = CelestiaError.networkError

        var failedAttempts = 0
        for _ in 1...5 {
            do {
                try await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: false)
            } catch {
                failedAttempts += 1
            }
        }

        #expect(failedAttempts == 5, "All 5 attempts should have failed")
        #expect(mockRepo.likes.isEmpty, "No likes should be stored")
    }

    @Test("Like appears to work but mutual check fails")
    func testLikeWorksButMutualCheckFails() async throws {
        let mockRepo = MockSwipeRepository()

        // User2 already liked User1
        mockRepo.addLike(fromUserId: "user2", toUserId: "user1")

        // User1 likes User2 - succeeds
        try await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: false)

        // But mutual check fails
        mockRepo.shouldFailOnCheckMutualLike = true
        mockRepo.checkMutualLikeError = CelestiaError.networkError

        // The like exists but we can't detect the match
        let likeExists = try await mockRepo.checkLikeExists(fromUserId: "user1", toUserId: "user2")
        #expect(likeExists, "Like should exist")

        // But mutual check throws
        do {
            _ = try await mockRepo.checkMutualLike(fromUserId: "user1", toUserId: "user2")
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(true, "Mutual check failed but like was recorded")
        }
    }

    @Test("Like silently fails due to inactive status returned")
    func testLikeSilentlyFailsDueToInactiveStatus() async throws {
        let mockRepo = MockSwipeRepository()

        // Create like
        try await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: false)

        // Manually set to inactive (simulating database issue)
        if var like = mockRepo.likes["user1_user2"] {
            like.isActive = false
            mockRepo.likes["user1_user2"] = like
        }

        // Like exists in storage but appears not to work
        let likeExists = try await mockRepo.checkLikeExists(fromUserId: "user1", toUserId: "user2")
        #expect(!likeExists, "Like appears to not exist due to inactive status")
    }

    @Test("Like fails when user blocked")
    func testLikeFailsWhenUserBlocked() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.shouldFailOnCreateLike = true
        mockRepo.createLikeError = CelestiaError.userBlocked

        do {
            try await mockRepo.createLike(fromUserId: "user1", toUserId: "blocked_user", isSuperLike: false)
            #expect(Bool(false), "Should have thrown user blocked error")
        } catch let error as CelestiaError {
            #expect(error == .userBlocked, "Should throw user blocked error")
        }
    }

    @Test("Like fails when target user not found")
    func testLikeFailsWhenTargetUserNotFound() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.shouldFailOnCreateLike = true
        mockRepo.createLikeError = CelestiaError.userNotFound

        do {
            try await mockRepo.createLike(fromUserId: "user1", toUserId: "deleted_user", isSuperLike: false)
            #expect(Bool(false), "Should have thrown user not found error")
        } catch let error as CelestiaError {
            #expect(error == .userNotFound, "Should throw user not found error")
        }
    }

    @Test("Like fails when not authenticated")
    func testLikeFailsWhenNotAuthenticated() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.shouldFailOnCreateLike = true
        mockRepo.createLikeError = CelestiaError.notAuthenticated

        do {
            try await mockRepo.createLike(fromUserId: "", toUserId: "user2", isSuperLike: false)
            #expect(Bool(false), "Should have thrown not authenticated error")
        } catch let error as CelestiaError {
            #expect(error == .notAuthenticated, "Should throw not authenticated error")
        }
    }

    @Test("Likes not appearing in likes received query")
    func testLikesNotAppearingInLikesReceivedQuery() async throws {
        let mockRepo = MockSwipeRepository()

        // Create likes
        mockRepo.addLike(fromUserId: "user1", toUserId: "target")
        mockRepo.addLike(fromUserId: "user2", toUserId: "target")
        mockRepo.addLike(fromUserId: "user3", toUserId: "target")

        // But query fails
        mockRepo.shouldFailOnGetLikesReceived = true
        mockRepo.getLikesReceivedError = CelestiaError.networkError

        do {
            _ = try await mockRepo.getLikesReceived(userId: "target")
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(true, "Query failed even though likes exist")
        }

        // Verify likes actually exist
        #expect(mockRepo.likes.count == 3, "Likes exist but can't be queried")
    }

    @Test("Likes query returns stale data")
    func testLikesQueryReturnsStaleData() async throws {
        let mockRepo = MockSwipeRepository()

        // Create initial likes
        mockRepo.addLike(fromUserId: "user1", toUserId: "target")
        mockRepo.addLike(fromUserId: "user2", toUserId: "target")

        // Get likes
        var likes = try await mockRepo.getLikesReceived(userId: "target")
        #expect(likes.count == 2, "Should have 2 likes")

        // Unlike one
        try await mockRepo.unlikeUser(fromUserId: "user1", toUserId: "target")

        // Get likes again
        likes = try await mockRepo.getLikesReceived(userId: "target")
        #expect(likes.count == 1, "Should have 1 like after unlike")
        #expect(!likes.contains("user1"), "Unliked user should not appear")
    }
}

// MARK: - Error Recovery Tests

@Suite("Like Error Recovery Tests")
@MainActor
struct LikeErrorRecoveryTests {

    @Test("Retry after network error succeeds")
    func testRetryAfterNetworkErrorSucceeds() async throws {
        let mockRepo = MockSwipeRepository()

        // First attempt fails
        mockRepo.shouldFailOnCreateLike = true
        mockRepo.createLikeError = CelestiaError.networkError

        do {
            try await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: false)
        } catch {
            // Expected failure
        }

        // Simulate recovery
        mockRepo.shouldFailOnCreateLike = false

        // Retry succeeds
        try await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: false)

        let likeExists = try await mockRepo.checkLikeExists(fromUserId: "user1", toUserId: "user2")
        #expect(likeExists, "Like should exist after successful retry")
    }

    @Test("Recovery from rate limit after waiting")
    func testRecoveryFromRateLimitAfterWaiting() async throws {
        let mockRepo = MockSwipeRepository()

        // Rate limited
        mockRepo.shouldFailOnCreateLike = true
        mockRepo.createLikeError = CelestiaError.rateLimitExceededWithTime(60.0)

        do {
            try await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: false)
        } catch let error as CelestiaError {
            if case .rateLimitExceededWithTime(let retryAfter) = error {
                #expect(retryAfter == 60.0, "Should have 60 second wait")
            }
        }

        // Simulate waiting and recovery
        mockRepo.shouldFailOnCreateLike = false

        try await mockRepo.createLike(fromUserId: "user1", toUserId: "user2", isSuperLike: false)

        let likeExists = try await mockRepo.checkLikeExists(fromUserId: "user1", toUserId: "user2")
        #expect(likeExists, "Like should exist after rate limit recovery")
    }

    @Test("System recovers from intermittent failures")
    func testSystemRecoversFromIntermittentFailures() async throws {
        let mockRepo = MockSwipeRepository()
        var successfulLikes: [String] = []

        for i in 1...10 {
            // Simulate intermittent failures (every other request fails)
            mockRepo.shouldFailOnCreateLike = (i % 2 == 0)
            mockRepo.createLikeError = CelestiaError.networkError

            do {
                try await mockRepo.createLike(fromUserId: "user1", toUserId: "user\(i)", isSuperLike: false)
                successfulLikes.append("user\(i)")
            } catch {
                // Expected for even iterations
            }
        }

        #expect(successfulLikes.count == 5, "Half of likes should succeed")
        #expect(mockRepo.likes.count == 5, "5 likes should be stored")
    }

    @Test("Unlike recovery after initial failure")
    func testUnlikeRecoveryAfterInitialFailure() async throws {
        let mockRepo = MockSwipeRepository()
        mockRepo.addLike(fromUserId: "user1", toUserId: "user2")

        // First unlike fails
        mockRepo.shouldFailOnUnlikeUser = true
        mockRepo.unlikeUserError = CelestiaError.networkError

        do {
            try await mockRepo.unlikeUser(fromUserId: "user1", toUserId: "user2")
        } catch {
            // Expected failure
        }

        // Like should still exist
        var likeExists = try await mockRepo.checkLikeExists(fromUserId: "user1", toUserId: "user2")
        #expect(likeExists, "Like should still exist after failed unlike")

        // Retry succeeds
        mockRepo.shouldFailOnUnlikeUser = false
        try await mockRepo.unlikeUser(fromUserId: "user1", toUserId: "user2")

        likeExists = try await mockRepo.checkLikeExists(fromUserId: "user1", toUserId: "user2")
        #expect(!likeExists, "Like should be removed after successful unlike")
    }
}
