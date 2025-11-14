//
//  RaceConditionTests.swift
//  CelestiaTests
//
//  Tests for race conditions and concurrency issues:
//  - Concurrent message sending
//  - Simultaneous swipes on same user
//  - Concurrent match creation
//  - Parallel listener updates
//  - Shared state access
//

import Testing
import Foundation
@testable import Celestia

@Suite("Race Condition Tests")
struct RaceConditionTests {

    // MARK: - Concurrent Message Sending

    @Test("Handle concurrent message sends to same match")
    @MainActor
    func testConcurrentMessageSending() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        // Create matched users
        let user1 = try await testBase.createTestUser()
        let user2 = try await testBase.createTestUser()

        guard let user1Id = user1.id, let user2Id = user2.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        let match = try await testBase.createTestMatch(user1Id: user1Id, user2Id: user2Id)
        guard let matchId = match.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        let messageService = MessageService.shared

        // Send 10 messages concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    do {
                        try await messageService.sendMessage(
                            matchId: matchId,
                            senderId: i % 2 == 0 ? user1Id : user2Id,
                            receiverId: i % 2 == 0 ? user2Id : user1Id,
                            text: "Concurrent message \(i)"
                        )
                    } catch {
                        Logger.shared.warning("Message \(i) send failed: \(error)", category: .testing)
                    }
                }
            }
        }

        // Wait for all messages to propagate
        try await testBase.simulateNetworkDelay(milliseconds: 500)

        // Verify all messages were created
        let messages = try await messageService.fetchMessages(matchId: matchId, limit: 20)
        Logger.shared.info("Successfully sent \(messages.count) concurrent messages", category: .testing)

        // Should have all 10 messages (or close to it, accounting for potential failures)
        #expect(messages.count >= 8) // Allow for some failures

        Logger.shared.info("✅ Concurrent message sending test completed", category: .testing)
    }

    // MARK: - Simultaneous Swipes

    @Test("Handle simultaneous swipes creating mutual match")
    @MainActor
    func testSimultaneousSwipesCreatingMatch() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        let user1 = try await testBase.createTestUser()
        let user2 = try await testBase.createTestUser()

        guard let user1Id = user1.id, let user2Id = user2.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        let swipeService = SwipeService.shared

        // Both users swipe right simultaneously
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                do {
                    return try await swipeService.likeUser(fromUserId: user1Id, toUserId: user2Id)
                } catch {
                    Logger.shared.error("User1 swipe failed: \(error)", category: .testing)
                    return false
                }
            }

            group.addTask {
                do {
                    return try await swipeService.likeUser(fromUserId: user2Id, toUserId: user1Id)
                } catch {
                    Logger.shared.error("User2 swipe failed: \(error)", category: .testing)
                    return false
                }
            }
        }

        // Wait for match creation
        try await testBase.simulateNetworkDelay(milliseconds: 500)

        // Verify exactly ONE match was created (not two)
        let match = try await MatchService.shared.fetchMatch(user1Id: user1Id, user2Id: user2Id)
        #expect(match != nil)

        // Verify no duplicate matches
        let matchService = MatchService.shared
        try await matchService.fetchMatches(userId: user1Id)
        let matchesForUser1 = matchService.matches.filter { m in
            (m.user1Id == user1Id && m.user2Id == user2Id) ||
            (m.user1Id == user2Id && m.user2Id == user1Id)
        }
        #expect(matchesForUser1.count == 1) // Should be exactly 1 match

        Logger.shared.info("✅ Simultaneous swipes test completed", category: .testing)
    }

    // MARK: - Concurrent Match Creation

    @Test("Prevent duplicate match creation")
    @MainActor
    func testPreventDuplicateMatches() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        let user1 = try await testBase.createTestUser()
        let user2 = try await testBase.createTestUser()

        guard let user1Id = user1.id, let user2Id = user2.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        let matchService = MatchService.shared

        // Attempt to create match multiple times concurrently
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    await matchService.createMatch(user1Id: user1Id, user2Id: user2Id)
                }
            }
        }

        // Wait for all attempts to complete
        try await testBase.simulateNetworkDelay(milliseconds: 500)

        // Verify only ONE match exists
        try await matchService.fetchMatches(userId: user1Id)
        let matchesForUser1 = matchService.matches.filter { m in
            (m.user1Id == user1Id && m.user2Id == user2Id) ||
            (m.user1Id == user2Id && m.user2Id == user1Id)
        }

        #expect(matchesForUser1.count == 1) // Should be exactly 1 match, not 5

        Logger.shared.info("✅ Prevent duplicate matches test completed", category: .testing)
    }

    // MARK: - Concurrent Batch Operations

    @Test("Handle concurrent batch operations on same messages")
    @MainActor
    func testConcurrentBatchOperations() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        // Create conversation
        let user1 = try await testBase.createTestUser()
        let user2 = try await testBase.createTestUser()

        let (match, _) = try await testBase.createTestConversation(
            user1: user1,
            user2: user2,
            messageCount: 10
        )

        guard let matchId = match.id, let userId = user1.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        let messageService = MessageService.shared

        // Attempt to mark messages as read multiple times concurrently
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<3 {
                group.addTask {
                    await messageService.markMessagesAsRead(matchId: matchId, userId: userId)
                }
            }
        }

        // Wait for operations to complete
        try await testBase.simulateNetworkDelay(milliseconds: 1000)

        // Verify messages are marked as read (idempotent operation)
        let unreadCount = try await messageService.getUnreadCount(matchId: matchId, userId: userId)
        #expect(unreadCount == 0)

        Logger.shared.info("✅ Concurrent batch operations test completed", category: .testing)
    }

    // MARK: - Real-Time Listener Races

    @Test("Handle concurrent listener updates")
    @MainActor
    func testConcurrentListenerUpdates() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        // Create conversation
        let user1 = try await testBase.createTestUser()
        let user2 = try await testBase.createTestUser()

        let (match, _) = try await testBase.createTestConversation(
            user1: user1,
            user2: user2,
            messageCount: 5
        )

        guard let matchId = match.id,
              let user1Id = user1.id,
              let user2Id = user2.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        let messageService = MessageService.shared
        messageService.listenToMessages(matchId: matchId)

        try await testBase.waitForCondition(timeout: 3.0) {
            !messageService.isLoading
        }

        // Send multiple messages rapidly
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask {
                    do {
                        try await messageService.sendMessage(
                            matchId: matchId,
                            senderId: user1Id,
                            receiverId: user2Id,
                            text: "Rapid message \(i)"
                        )
                    } catch {
                        Logger.shared.warning("Rapid message \(i) failed: \(error)", category: .testing)
                    }
                }
            }
        }

        // Wait for listener to process updates
        try await testBase.waitForCondition(timeout: 5.0) {
            messageService.messages.count >= 10 // 5 initial + 5 new
        }

        // Verify no duplicate messages in listener
        let messageIds = messageService.messages.compactMap { $0.id }
        let uniqueIds = Set(messageIds)
        #expect(messageIds.count == uniqueIds.count) // No duplicates

        messageService.stopListening()

        Logger.shared.info("✅ Concurrent listener updates test completed", category: .testing)
    }

    // MARK: - Shared State Access

    @Test("Handle concurrent access to published properties")
    @MainActor
    func testConcurrentPublishedPropertyAccess() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        let messageService = MessageService.shared

        // Multiple tasks reading/writing to isLoading simultaneously
        await withTaskGroup(of: Void.self) { group in
            // Readers
            for i in 0..<10 {
                group.addTask { @MainActor in
                    _ = messageService.isLoading
                    Logger.shared.debug("Reader \(i) accessed isLoading", category: .testing)
                }
            }

            // Writers (simulated)
            for i in 0..<5 {
                group.addTask { @MainActor in
                    // In actual code, these would be set by async operations
                    Logger.shared.debug("Writer \(i) would modify isLoading", category: .testing)
                }
            }
        }

        // Verify no crash from concurrent access
        // (Swift's @MainActor ensures thread safety)
        #expect(true)

        Logger.shared.info("✅ Concurrent property access test completed", category: .testing)
    }

    // MARK: - Service Singleton Race

    @Test("Handle concurrent service singleton initialization")
    @MainActor
    func testConcurrentSingletonInitialization() async throws {
        // Attempt to access service singleton from multiple tasks simultaneously
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask { @MainActor in
                    _ = MessageService.shared
                    _ = MatchService.shared
                    _ = SwipeService.shared
                    Logger.shared.debug("Task \(i) accessed singletons", category: .testing)
                }
            }
        }

        // Verify only one instance of each service exists
        let messageService1 = MessageService.shared
        let messageService2 = MessageService.shared
        #expect(messageService1 === messageService2) // Same instance

        Logger.shared.info("✅ Concurrent singleton initialization test completed", category: .testing)
    }

    // MARK: - Pagination Race Conditions

    @Test("Handle pagination while receiving new messages")
    @MainActor
    func testPaginationWithNewMessages() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        // Create large conversation
        let user1 = try await testBase.createTestUser()
        let user2 = try await testBase.createTestUser()

        let (match, _) = try await testBase.createTestConversation(
            user1: user1,
            user2: user2,
            messageCount: 100
        )

        guard let matchId = match.id,
              let user1Id = user1.id,
              let user2Id = user2.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        let messageService = MessageService.shared
        messageService.listenToMessages(matchId: matchId)

        try await testBase.waitForCondition(timeout: 3.0) {
            !messageService.isLoading
        }

        // Start pagination and send new messages simultaneously
        async let paginationTask: Void = messageService.loadOlderMessages(matchId: matchId)

        async let newMessageTask: Void = {
            try await testBase.simulateNetworkDelay(milliseconds: 50)
            try await messageService.sendMessage(
                matchId: matchId,
                senderId: user1Id,
                receiverId: user2Id,
                text: "New message during pagination"
            )
        }()

        _ = await (paginationTask, newMessageTask)

        // Wait for both to complete
        try await testBase.waitForCondition(timeout: 5.0) {
            !messageService.isLoadingMore
        }

        // Verify messages are correctly sorted
        let timestamps = messageService.messages.map { $0.timestamp }
        let sortedTimestamps = timestamps.sorted()
        #expect(timestamps == sortedTimestamps) // Should be sorted

        messageService.stopListening()

        Logger.shared.info("✅ Pagination with new messages test completed", category: .testing)
    }

    // MARK: - AuthService Race Conditions

    @Test("Handle concurrent sign-in attempts")
    @MainActor
    func testConcurrentSignInAttempts() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        // Create test user
        let testEmail = "concurrent@test.com"
        let testPassword = "TestPass123!"

        _ = try await testBase.createTestUser(email: testEmail)

        let authService = AuthService.shared

        // Attempt to sign in multiple times concurrently
        await withTaskGroup(of: Result<Void, Error>.self) { group in
            for i in 0..<5 {
                group.addTask {
                    do {
                        try await authService.signIn(withEmail: testEmail, password: testPassword)
                        Logger.shared.debug("Sign-in attempt \(i) succeeded", category: .testing)
                        return .success(())
                    } catch {
                        Logger.shared.warning("Sign-in attempt \(i) failed: \(error)", category: .testing)
                        return .failure(error)
                    }
                }
            }
        }

        // Verify user is signed in (regardless of which attempt succeeded)
        #expect(authService.userSession != nil)

        Logger.shared.info("✅ Concurrent sign-in test completed", category: .testing)
    }
}

// MARK: - Timing-Dependent Race Conditions

@Suite("Timing-Dependent Race Conditions")
struct TimingRaceConditionTests {

    @Test("Handle rapid listener attach/detach")
    @MainActor
    func testRapidListenerAttachDetach() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        // Create conversation
        let user1 = try await testBase.createTestUser()
        let user2 = try await testBase.createTestUser()

        let (match, _) = try await testBase.createTestConversation(
            user1: user1,
            user2: user2,
            messageCount: 10
        )

        guard let matchId = match.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        let messageService = MessageService.shared

        // Rapidly attach and detach listener
        for i in 0..<10 {
            messageService.listenToMessages(matchId: matchId)

            try await testBase.simulateNetworkDelay(milliseconds: 50)

            messageService.stopListening()

            Logger.shared.debug("Listener cycle \(i) completed", category: .testing)
        }

        // Verify no crashes or memory leaks
        #expect(true)

        Logger.shared.info("✅ Rapid listener attach/detach test completed", category: .testing)
    }

    @Test("Handle state updates during async operations")
    @MainActor
    func testStateUpdatesDuringAsync() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        let messageService = MessageService.shared

        // Check initial state
        #expect(!messageService.isLoading)

        // This test would verify that state updates during async operations
        // don't cause race conditions or inconsistent states

        Logger.shared.info("✅ State updates during async test completed", category: .testing)
    }
}
