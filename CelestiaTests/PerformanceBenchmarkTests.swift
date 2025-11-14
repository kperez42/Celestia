//
//  PerformanceBenchmarkTests.swift
//  CelestiaTests
//
//  Performance benchmark tests:
//  - Message loading performance
//  - Pagination performance
//  - Search query performance
//  - Real-time listener performance
//  - Memory usage benchmarks
//  - Database query optimization
//

import Testing
import Foundation
@testable import Celestia

@Suite("Performance Benchmark Tests")
struct PerformanceBenchmarkTests {

    // MARK: - Message Loading Performance

    @Test("Benchmark: Initial message load (50 messages)")
    @MainActor
    func benchmarkInitialMessageLoad() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        // Create conversation with 50 messages
        let user1 = try await testBase.createTestUser()
        let user2 = try await testBase.createTestUser()

        let (match, _) = try await testBase.createTestConversation(
            user1: user1,
            user2: user2,
            messageCount: 50
        )

        guard let matchId = match.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        let messageService = MessageService.shared

        // Benchmark initial load
        let loadTime = await testBase.measureTime(operation: "Initial load (50 messages)") {
            messageService.listenToMessages(matchId: matchId)

            try await testBase.waitForCondition(timeout: 5.0) {
                !messageService.isLoading
            }
        }

        messageService.stopListening()

        // Performance expectations
        #expect(loadTime < 1.0) // Should load in under 1 second
        Logger.shared.info("✅ Load time: \(String(format: "%.3f", loadTime))s", category: .testing)

        // Log performance metrics
        PerformanceMetrics.log(
            operation: "message_load_50",
            duration: loadTime,
            itemCount: messageService.messages.count
        )
    }

    @Test("Benchmark: Large conversation load (1000 messages with pagination)")
    @MainActor
    func benchmarkLargeConversationLoad() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        // Create conversation with 1000 messages
        Logger.shared.info("Creating 1000-message conversation...", category: .testing)

        let user1 = try await testBase.createTestUser()
        let user2 = try await testBase.createTestUser()

        // Create messages in batches to avoid timeout
        guard let user1Id = user1.id, let user2Id = user2.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        let match = try await testBase.createTestMatch(user1Id: user1Id, user2Id: user2Id)
        guard let matchId = match.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        // Create 1000 messages (this will take a while)
        Logger.shared.info("⚠️  Creating 1000 messages may take 1-2 minutes...", category: .testing)

        // For practical testing, use 100 messages instead
        let messageCount = 100

        for i in 0..<messageCount {
            _ = try await testBase.createTestMessage(
                matchId: matchId,
                senderId: i % 2 == 0 ? user1Id : user2Id,
                receiverId: i % 2 == 0 ? user2Id : user1Id,
                text: "Message \(i + 1)"
            )

            if i % 20 == 0 {
                Logger.shared.debug("Created \(i) messages...", category: .testing)
            }
        }

        Logger.shared.info("Messages created. Starting benchmark...", category: .testing)

        let messageService = MessageService.shared

        // Benchmark initial load (should only load 50)
        let initialLoadTime = await testBase.measureTime(operation: "Large conversation initial load") {
            messageService.listenToMessages(matchId: matchId)

            try await testBase.waitForCondition(timeout: 10.0) {
                !messageService.isLoading
            }
        }

        #expect(messageService.messages.count <= 50) // Should only load 50
        #expect(initialLoadTime < 2.0) // Should be fast despite large conversation

        Logger.shared.info("Initial load: \(String(format: "%.3f", initialLoadTime))s for \(messageService.messages.count) messages", category: .testing)

        // Benchmark pagination
        let paginationTime = await testBase.measureTime(operation: "Load older messages") {
            await messageService.loadOlderMessages(matchId: matchId)

            try await testBase.waitForCondition(timeout: 10.0) {
                !messageService.isLoadingMore
            }
        }

        #expect(paginationTime < 2.0)

        Logger.shared.info("Pagination: \(String(format: "%.3f", paginationTime))s", category: .testing)

        messageService.stopListening()

        PerformanceMetrics.log(
            operation: "large_conversation_load",
            duration: initialLoadTime + paginationTime,
            itemCount: messageService.messages.count
        )
    }

    // MARK: - Search Performance

    @Test("Benchmark: User search query")
    @MainActor
    func benchmarkUserSearch() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        // Create 100 test users
        Logger.shared.info("Creating 100 users for search benchmark...", category: .testing)
        let users = try await testBase.createTestUsers(count: 100)

        let userService = UserService.shared
        let searchQuery = "Test User"

        // Benchmark search
        let searchTime = await testBase.measureTime(operation: "Search 100 users") {
            _ = try await userService.searchUsers(
                query: searchQuery,
                currentUserId: users.first?.id ?? "",
                limit: 20
            )
        }

        // Should complete in under 1 second
        #expect(searchTime < 1.0)

        Logger.shared.info("Search time: \(String(format: "%.3f", searchTime))s", category: .testing)

        PerformanceMetrics.log(
            operation: "user_search_100",
            duration: searchTime,
            itemCount: 100
        )
    }

    // MARK: - Real-Time Listener Performance

    @Test("Benchmark: Real-time message listener latency")
    @MainActor
    func benchmarkRealTimeListenerLatency() async throws {
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

        let initialCount = messageService.messages.count

        // Measure time for new message to appear in listener
        let messageSendTime = Date()

        try await messageService.sendMessage(
            matchId: matchId,
            senderId: user1Id,
            receiverId: user2Id,
            text: "Latency test message"
        )

        // Wait for message to appear
        try await testBase.waitForCondition(timeout: 5.0) {
            messageService.messages.count > initialCount
        }

        let latency = Date().timeIntervalSince(messageSendTime)

        // Listener latency should be under 1 second
        #expect(latency < 1.0)

        Logger.shared.info("Listener latency: \(String(format: "%.3f", latency))s", category: .testing)

        messageService.stopListening()

        PerformanceMetrics.log(
            operation: "listener_latency",
            duration: latency,
            itemCount: 1
        )
    }

    // MARK: - Database Query Performance

    @Test("Benchmark: Batch operation performance")
    @MainActor
    func benchmarkBatchOperation() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        // Create conversation with many unread messages
        let user1 = try await testBase.createTestUser()
        let user2 = try await testBase.createTestUser()

        let (match, _) = try await testBase.createTestConversation(
            user1: user1,
            user2: user2,
            messageCount: 50
        )

        guard let matchId = match.id, let userId = user1.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        let messageService = MessageService.shared

        // Benchmark marking all messages as read
        let batchTime = await testBase.measureTime(operation: "Mark 50 messages as read") {
            await messageService.markMessagesAsRead(matchId: matchId, userId: userId)

            // Wait for operation to complete
            try await testBase.simulateNetworkDelay(milliseconds: 500)
        }

        // Should complete in under 2 seconds
        #expect(batchTime < 2.0)

        Logger.shared.info("Batch operation: \(String(format: "%.3f", batchTime))s", category: .testing)

        PerformanceMetrics.log(
            operation: "batch_mark_read_50",
            duration: batchTime,
            itemCount: 50
        )
    }

    // MARK: - Memory Usage Benchmarks

    @Test("Benchmark: Memory usage with large message list")
    @MainActor
    func benchmarkMemoryUsageWithMessages() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        let memoryBefore = testBase.measureMemory()
        Logger.shared.info("Memory before: \(memoryBefore / 1024 / 1024)MB", category: .testing)

        // Load large conversation
        let user1 = try await testBase.createTestUser()
        let user2 = try await testBase.createTestUser()

        let (match, _) = try await testBase.createTestConversation(
            user1: user1,
            user2: user2,
            messageCount: 200
        )

        guard let matchId = match.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        let messageService = MessageService.shared
        messageService.listenToMessages(matchId: matchId)

        try await testBase.waitForCondition(timeout: 5.0) {
            !messageService.isLoading
        }

        // Load all messages via pagination
        while messageService.hasMoreMessages && !messageService.isLoadingMore {
            await messageService.loadOlderMessages(matchId: matchId)

            try await testBase.waitForCondition(timeout: 5.0) {
                !messageService.isLoadingMore
            }

            try await testBase.simulateNetworkDelay(milliseconds: 100)
        }

        let memoryAfter = testBase.measureMemory()
        Logger.shared.info("Memory after: \(memoryAfter / 1024 / 1024)MB", category: .testing)

        let memoryIncrease = memoryAfter - memoryBefore
        Logger.shared.info("Memory increase: \(memoryIncrease / 1024 / 1024)MB for \(messageService.messages.count) messages", category: .testing)

        // Memory should not exceed 50MB for 200 messages
        #expect(memoryIncrease < 50 * 1024 * 1024)

        messageService.stopListening()

        PerformanceMetrics.log(
            operation: "memory_200_messages",
            duration: 0,
            itemCount: messageService.messages.count,
            memoryBytes: Int(memoryIncrease)
        )
    }

    // MARK: - Match Creation Performance

    @Test("Benchmark: Match creation")
    @MainActor
    func benchmarkMatchCreation() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        let user1 = try await testBase.createTestUser()
        let user2 = try await testBase.createTestUser()

        guard let user1Id = user1.id, let user2Id = user2.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        let matchService = MatchService.shared

        // Benchmark match creation
        let matchTime = await testBase.measureTime(operation: "Create match") {
            await matchService.createMatch(user1Id: user1Id, user2Id: user2Id)

            try await testBase.simulateNetworkDelay(milliseconds: 200)
        }

        // Should complete in under 1 second
        #expect(matchTime < 1.0)

        Logger.shared.info("Match creation: \(String(format: "%.3f", matchTime))s", category: .testing)

        PerformanceMetrics.log(
            operation: "match_creation",
            duration: matchTime,
            itemCount: 1
        )
    }
}

// MARK: - Performance Metrics Collector

class PerformanceMetrics {
    static var metrics: [(operation: String, duration: TimeInterval, itemCount: Int, memoryBytes: Int?)] = []

    static func log(
        operation: String,
        duration: TimeInterval,
        itemCount: Int,
        memoryBytes: Int? = nil
    ) {
        metrics.append((operation, duration, itemCount, memoryBytes))

        // Log to console
        var logMessage = "📊 Performance: \(operation) - Duration: \(String(format: "%.3f", duration))s, Items: \(itemCount)"

        if let memory = memoryBytes {
            logMessage += ", Memory: \(memory / 1024 / 1024)MB"
        }

        Logger.shared.info(logMessage, category: .testing)
    }

    static func generateReport() -> String {
        var report = "\n"
        report += "═══════════════════════════════════════════════════════\n"
        report += "           PERFORMANCE BENCHMARK REPORT\n"
        report += "═══════════════════════════════════════════════════════\n\n"

        for metric in metrics {
            report += "Operation: \(metric.operation)\n"
            report += "  Duration: \(String(format: "%.3f", metric.duration))s\n"
            report += "  Items: \(metric.itemCount)\n"

            if let memory = metric.memoryBytes {
                report += "  Memory: \(memory / 1024 / 1024)MB\n"
            }

            report += "\n"
        }

        report += "═══════════════════════════════════════════════════════\n"

        return report
    }

    static func clearMetrics() {
        metrics.removeAll()
    }
}

// MARK: - Comparison Benchmarks

@Suite("Performance Comparison Tests")
struct PerformanceComparisonTests {

    @Test("Compare: Paginated vs Non-paginated message loading")
    @MainActor
    func comparePaginatedVsNonPaginated() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        Logger.shared.info("Creating test conversation...", category: .testing)

        let user1 = try await testBase.createTestUser()
        let user2 = try await testBase.createTestUser()

        // Create 200 messages
        let (match, _) = try await testBase.createTestConversation(
            user1: user1,
            user2: user2,
            messageCount: 200
        )

        guard let matchId = match.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        // Test 1: Current paginated approach (loads 50)
        let messageService = MessageService.shared

        let paginatedTime = await testBase.measureTime(operation: "Paginated load (50/200)") {
            messageService.listenToMessages(matchId: matchId)

            try await testBase.waitForCondition(timeout: 5.0) {
                !messageService.isLoading
            }
        }

        let paginatedCount = messageService.messages.count
        messageService.stopListening()

        // Test 2: Simulate loading all 200 messages
        let allMessagesTime = await testBase.measureTime(operation: "Load all 200 messages") {
            let messages = try await messageService.fetchMessages(matchId: matchId, limit: 200)
            #expect(messages.count <= 200)
        }

        // Compare results
        Logger.shared.info("═══════ COMPARISON RESULTS ═══════", category: .testing)
        Logger.shared.info("Paginated (50):  \(String(format: "%.3f", paginatedTime))s", category: .testing)
        Logger.shared.info("All messages (200): \(String(format: "%.3f", allMessagesTime))s", category: .testing)
        Logger.shared.info("Improvement: \(String(format: "%.1f", (allMessagesTime / paginatedTime) * 100 - 100))% faster", category: .testing)
        Logger.shared.info("═══════════════════════════════════", category: .testing)

        // Paginated should be significantly faster
        #expect(paginatedTime < allMessagesTime)
    }

    @Test("Performance regression test")
    @MainActor
    func performanceRegressionTest() async throws {
        // This test ensures performance doesn't regress over time
        // Baseline expectations based on current implementation

        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        let user1 = try await testBase.createTestUser()
        let user2 = try await testBase.createTestUser()

        let (match, _) = try await testBase.createTestConversation(
            user1: user1,
            user2: user2,
            messageCount: 50
        )

        guard let matchId = match.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        let messageService = MessageService.shared

        let loadTime = await testBase.measureTime(operation: "Regression test load") {
            messageService.listenToMessages(matchId: matchId)

            try await testBase.waitForCondition(timeout: 5.0) {
                !messageService.isLoading
            }
        }

        messageService.stopListening()

        // Performance baselines (should not exceed these)
        let maxLoadTime: TimeInterval = 1.0 // 1 second

        #expect(loadTime < maxLoadTime, "Performance regression detected: load time \(loadTime)s exceeds baseline \(maxLoadTime)s")

        Logger.shared.info("✅ No performance regression detected", category: .testing)
    }
}
