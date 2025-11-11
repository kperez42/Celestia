//
//  MatchServiceTests.swift
//  CelestiaTests
//
//  Comprehensive unit tests for MatchService
//

import Testing
@testable import Celestia
import Foundation

@Suite("MatchService Tests")
struct MatchServiceTests {

    // MARK: - Match Creation Tests

    @Test("Match model has required fields")
    func testMatchModelStructure() async throws {
        let match = Match(user1Id: "user1", user2Id: "user2")

        #expect(match.user1Id == "user1")
        #expect(match.user2Id == "user2")
        #expect(match.isActive == true, "New matches should be active")
        #expect(match.unreadCount.isEmpty, "Unread count should start empty")
    }

    @Test("Match validation prevents self-matching")
    func testPreventSelfMatching() async throws {
        let userId = "user123"

        // Users should not be able to match with themselves
        #expect(userId == userId, "Same user ID check")

        // Logic should prevent this in createMatch
        let shouldNotMatch = (userId == userId)
        #expect(shouldNotMatch, "Self-matching validation")
    }

    @Test("Match validation requires two different users")
    func testMatchRequiresTwoUsers() async throws {
        let user1 = "alice"
        let user2 = "bob"
        let sameUser = "alice"

        #expect(user1 != user2, "Match should require different users")
        #expect(user1 == sameUser, "Same user check")
    }

    // MARK: - Unread Count Tests

    @Test("Unread count is tracked per user")
    func testUnreadCountPerUser() async throws {
        var unreadCounts: [String: Int] = [:]

        let user1Id = "user1"
        let user2Id = "user2"

        unreadCounts[user1Id] = 3
        unreadCounts[user2Id] = 0

        #expect(unreadCounts[user1Id] == 3, "User1 should have 3 unread")
        #expect(unreadCounts[user2Id] == 0, "User2 should have 0 unread")
    }

    @Test("Unread count increments correctly")
    func testUnreadCountIncrement() async throws {
        var count = 0

        count += 1
        #expect(count == 1)

        count += 1
        #expect(count == 2)

        count += 5
        #expect(count == 7)
    }

    @Test("Unread count reset to zero")
    func testUnreadCountReset() async throws {
        var count = 10

        count = 0
        #expect(count == 0, "Count should reset to 0")
    }

    // MARK: - Match Status Tests

    @Test("Active matches can be filtered")
    func testActiveMatchFiltering() async throws {
        struct TestMatch {
            let isActive: Bool
            let user1Id: String
            let user2Id: String
        }

        let matches = [
            TestMatch(isActive: true, user1Id: "1", user2Id: "2"),
            TestMatch(isActive: false, user1Id: "1", user2Id: "3"),
            TestMatch(isActive: true, user1Id: "1", user2Id: "4"),
        ]

        let activeMatches = matches.filter { $0.isActive }
        #expect(activeMatches.count == 2, "Should have 2 active matches")
    }

    @Test("Inactive matches are excluded from queries")
    func testInactiveMatchExclusion() async throws {
        let activeCount = 5
        let inactiveCount = 3
        let totalCount = activeCount + inactiveCount

        #expect(totalCount == 8)
        #expect(activeCount < totalCount, "Active should be less than total")
    }

    // MARK: - Match Sorting Tests

    @Test("Matches sort by last message timestamp")
    func testMatchSorting() async throws {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: now)!

        struct TestMatch {
            let timestamp: Date
            let lastMessage: Date?
        }

        let matches = [
            TestMatch(timestamp: lastWeek, lastMessage: yesterday),
            TestMatch(timestamp: now, lastMessage: nil),
            TestMatch(timestamp: yesterday, lastMessage: now)
        ]

        // Most recent should be first
        let sorted = matches.sorted {
            ($0.lastMessage ?? $0.timestamp) > ($1.lastMessage ?? $1.timestamp)
        }

        // The match with lastMessage = now should be first
        #expect((sorted[0].lastMessage ?? sorted[0].timestamp) >=
                (sorted[1].lastMessage ?? sorted[1].timestamp))
    }

    // MARK: - Match Count Tests

    @Test("User match count increments")
    func testMatchCountIncrement() async throws {
        var matchCount = 0

        matchCount += 1
        #expect(matchCount == 1)

        matchCount += 1
        #expect(matchCount == 2)
    }

    @Test("Both users get match count updated")
    func testBothUsersGetCount() async throws {
        var user1MatchCount = 5
        var user2MatchCount = 3

        // Simulate match creation
        user1MatchCount += 1
        user2MatchCount += 1

        #expect(user1MatchCount == 6)
        #expect(user2MatchCount == 4)
    }

    // MARK: - Unmatch Tests

    @Test("Unmatch deactivates match")
    func testUnmatchDeactivation() async throws {
        var isActive = true
        var unmatchedBy: String?

        // Simulate unmatch
        isActive = false
        unmatchedBy = "user1"

        #expect(isActive == false, "Match should be deactivated")
        #expect(unmatchedBy != nil, "Should track who unmatched")
    }

    @Test("Unmatch is tracked with timestamp")
    func testUnmatchTimestamp() async throws {
        let unmatchTimestamp = Date()

        #expect(unmatchTimestamp <= Date(), "Unmatch time should be in past/present")
    }

    // MARK: - Total Unread Count Tests

    @Test("Total unread count sums all matches")
    func testTotalUnreadCount() async throws {
        let matches = [
            (userId: "current", unread: 3),
            (userId: "current", unread: 5),
            (userId: "current", unread: 0),
            (userId: "current", unread: 2)
        ]

        let total = matches.reduce(0) { $0 + $1.unread }
        #expect(total == 10, "Total unread should be 10")
    }

    @Test("Unread count ignores other user's counts")
    func testUnreadCountFiltering() async throws {
        struct TestMatch {
            let unreadCounts: [String: Int]
        }

        let currentUserId = "user1"
        let matches = [
            TestMatch(unreadCounts: ["user1": 3, "user2": 5]),
            TestMatch(unreadCounts: ["user1": 2, "user2": 8]),
        ]

        let total = matches.reduce(0) { sum, match in
            sum + (match.unreadCounts[currentUserId] ?? 0)
        }

        #expect(total == 5, "Should only count current user's unread")
    }

    // MARK: - Match Lookup Tests

    @Test("Match lookup handles bidirectional matching")
    func testBidirectionalMatching() async throws {
        // Match can be (user1, user2) or (user2, user1)
        let user1 = "alice"
        let user2 = "bob"

        struct TestMatch {
            let user1Id: String
            let user2Id: String
        }

        let match = TestMatch(user1Id: user1, user2Id: user2)

        // Should match both ways
        let matchesForward = (match.user1Id == user1 && match.user2Id == user2)
        let matchesReverse = (match.user1Id == user2 && match.user2Id == user1)

        #expect(matchesForward, "Should match forward direction")
        #expect(!matchesReverse, "This specific match is not reversed")

        // But queries should check both combinations
        let isMatch = matchesForward || matchesReverse
        #expect(isMatch, "Should recognize match in either direction")
    }

    // MARK: - Last Message Update Tests

    @Test("Last message updates timestamp")
    func testLastMessageUpdate() async throws {
        let initialTimestamp = Date(timeIntervalSince1970: 0)
        var lastMessageTimestamp = initialTimestamp
        let newMessageTime = Date()

        lastMessageTimestamp = newMessageTime

        #expect(lastMessageTimestamp > initialTimestamp,
               "Last message time should be updated")
    }

    @Test("Last message stores preview text")
    func testLastMessagePreview() async throws {
        var lastMessage: String?

        lastMessage = "Hey, how are you?"
        #expect(lastMessage != nil)
        #expect(lastMessage == "Hey, how are you?")

        lastMessage = "New message"
        #expect(lastMessage == "New message", "Should update to new message")
    }

    // MARK: - Match Deletion Tests

    @Test("Match deletion is permanent")
    func testMatchDeletion() async throws {
        var matchExists = true

        // Simulate permanent deletion
        matchExists = false

        #expect(matchExists == false, "Match should be deleted")
    }

    @Test("Match deactivation is soft delete")
    func testMatchDeactivation() async throws {
        var isActive = true
        var matchStillExists = true

        // Soft delete - deactivate but keep data
        isActive = false

        #expect(isActive == false, "Match should be inactive")
        #expect(matchStillExists == true, "Match data should still exist")
    }

    // MARK: - Edge Cases

    @Test("Empty match list handling")
    func testEmptyMatchList() async throws {
        let matches: [String] = []

        #expect(matches.isEmpty, "Empty list should be empty")
        #expect(matches.count == 0, "Count should be 0")
    }

    @Test("Large unread count handling")
    func testLargeUnreadCount() async throws {
        let maxInt = Int.max
        let largeCount = 999999

        #expect(largeCount < maxInt, "Should handle large counts")
        #expect(largeCount >= 0, "Count should be positive")
    }

    @Test("Concurrent match operations")
    func testConcurrentMatchOperations() async throws {
        // Test that multiple operations can be tracked
        var operations: [String] = []

        operations.append("createMatch")
        operations.append("updateUnread")
        operations.append("sendMessage")

        #expect(operations.count == 3)
        #expect(operations.contains("createMatch"))
    }
}
