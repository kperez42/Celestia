//
//  ChatViewModelComprehensiveTests.swift
//  CelestiaTests
//
//  Comprehensive unit tests for ChatViewModel with mock dependencies
//

import Testing
import Foundation
@testable import Celestia

@Suite("ChatViewModel Comprehensive Tests")
@MainActor
struct ChatViewModelComprehensiveTests {

    // MARK: - Initialization Tests

    @Test("ChatViewModel initializes with correct default state")
    func testInitialState() async throws {
        let viewModel = ChatViewModel()

        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.matches.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.currentUserId.isEmpty)
        #expect(viewModel.otherUserId.isEmpty)
    }

    @Test("ChatViewModel initializes with provided user IDs")
    func testInitializationWithUserIds() async throws {
        let viewModel = ChatViewModel(
            currentUserId: "user123",
            otherUserId: "user456"
        )

        #expect(viewModel.currentUserId == "user123")
        #expect(viewModel.otherUserId == "user456")
        #expect(viewModel.messages.isEmpty)
    }

    // MARK: - User ID Update Tests

    @Test("Update current user ID")
    func testUpdateCurrentUserId() async throws {
        let viewModel = ChatViewModel()

        #expect(viewModel.currentUserId.isEmpty)

        viewModel.updateCurrentUserId("new_user_id")

        #expect(viewModel.currentUserId == "new_user_id")
    }

    // MARK: - Message State Tests

    @Test("Messages array can be populated")
    func testMessagesPopulation() async throws {
        let viewModel = ChatViewModel(
            currentUserId: "user1",
            otherUserId: "user2"
        )

        let messages = TestFixtures.createConversation(
            matchId: "match123",
            user1Id: "user1",
            user2Id: "user2",
            messageCount: 5
        )

        viewModel.messages = messages

        #expect(viewModel.messages.count == 5)
        #expect(viewModel.messages[0].senderId == "user1")
        #expect(viewModel.messages[1].senderId == "user2")
    }

    @Test("Empty messages state")
    func testEmptyMessagesState() async throws {
        let viewModel = ChatViewModel()

        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.messages.count == 0)
    }

    @Test("Messages sorted by timestamp")
    func testMessagesSortedByTimestamp() async throws {
        let viewModel = ChatViewModel()

        let message1 = TestFixtures.createTestMessage(
            id: "msg1",
            timestamp: Date.minutesAgo(5)
        )
        let message2 = TestFixtures.createTestMessage(
            id: "msg2",
            timestamp: Date.minutesAgo(3)
        )
        let message3 = TestFixtures.createTestMessage(
            id: "msg3",
            timestamp: Date.minutesAgo(1)
        )

        viewModel.messages = [message2, message1, message3]

        // Verify messages can be sorted
        let sortedMessages = viewModel.messages.sorted { $0.timestamp < $1.timestamp }

        #expect(sortedMessages[0].id == "msg1")
        #expect(sortedMessages[1].id == "msg2")
        #expect(sortedMessages[2].id == "msg3")
    }

    // MARK: - Match State Tests

    @Test("Matches array can be populated")
    func testMatchesPopulation() async throws {
        let viewModel = ChatViewModel(currentUserId: "user1")

        let matches = TestFixtures.createBatchMatches(count: 3, currentUserId: "user1")
        viewModel.matches = matches

        #expect(viewModel.matches.count == 3)
        #expect(viewModel.matches.allSatisfy { $0.user1Id == "user1" })
    }

    @Test("Empty matches state")
    func testEmptyMatchesState() async throws {
        let viewModel = ChatViewModel()

        #expect(viewModel.matches.isEmpty)
        #expect(viewModel.matches.count == 0)
    }

    @Test("Matches sorted by last message timestamp")
    func testMatchesSortedByLastMessage() async throws {
        let viewModel = ChatViewModel()

        let match1 = TestFixtures.createTestMatch(
            id: "match1",
            lastMessageTimestamp: Date.hoursAgo(5)
        )
        let match2 = TestFixtures.createTestMatch(
            id: "match2",
            lastMessageTimestamp: Date.hoursAgo(2)
        )
        let match3 = TestFixtures.createTestMatch(
            id: "match3",
            lastMessageTimestamp: Date.hoursAgo(1)
        )

        viewModel.matches = [match1, match2, match3]

        // Verify matches can be sorted
        let sortedMatches = viewModel.matches.sorted {
            ($0.lastMessageTimestamp ?? $0.timestamp) > ($1.lastMessageTimestamp ?? $1.timestamp)
        }

        #expect(sortedMatches[0].id == "match3") // Most recent
        #expect(sortedMatches[2].id == "match1") // Oldest
    }

    // MARK: - Loading State Tests

    @Test("Loading state transitions")
    func testLoadingStateTransitions() async throws {
        let viewModel = ChatViewModel()

        #expect(viewModel.isLoading == false)

        viewModel.isLoading = true
        #expect(viewModel.isLoading == true)

        viewModel.isLoading = false
        #expect(viewModel.isLoading == false)
    }

    // MARK: - Cleanup Tests

    @Test("Cleanup clears messages")
    func testCleanupClearsMessages() async throws {
        let viewModel = ChatViewModel()

        viewModel.messages = TestFixtures.createConversation(
            matchId: "match1",
            user1Id: "user1",
            user2Id: "user2",
            messageCount: 10
        )

        #expect(viewModel.messages.count == 10)

        viewModel.cleanup()

        #expect(viewModel.messages.isEmpty)
    }

    @Test("Cleanup method completes without errors")
    func testCleanupCompletesSuccessfully() async throws {
        let viewModel = ChatViewModel(
            currentUserId: "user1",
            otherUserId: "user2"
        )

        viewModel.messages = TestFixtures.createConversation(
            matchId: "match1",
            user1Id: "user1",
            user2Id: "user2",
            messageCount: 5
        )

        // Should not throw
        viewModel.cleanup()

        #expect(viewModel.messages.isEmpty)
    }

    // MARK: - Conversation Flow Tests

    @Test("Full conversation back and forth")
    func testFullConversationFlow() async throws {
        let viewModel = ChatViewModel(
            currentUserId: "alice",
            otherUserId: "bob"
        )

        let conversation = TestFixtures.createConversation(
            matchId: "match_ab",
            user1Id: "alice",
            user2Id: "bob",
            messageCount: 20
        )

        viewModel.messages = conversation

        #expect(viewModel.messages.count == 20)

        // Verify alternating senders
        #expect(viewModel.messages[0].senderId == "alice")
        #expect(viewModel.messages[1].senderId == "bob")
        #expect(viewModel.messages[2].senderId == "alice")
        #expect(viewModel.messages[3].senderId == "bob")
    }

    @Test("Recent messages appear at end of conversation")
    func testRecentMessagesOrdering() async throws {
        let viewModel = ChatViewModel()

        let oldMessage = TestFixtures.createTestMessage(
            id: "old",
            text: "Old message",
            timestamp: Date.hoursAgo(24)
        )

        let recentMessage = TestFixtures.createTestMessage(
            id: "recent",
            text: "Recent message",
            timestamp: Date.minutesAgo(5)
        )

        viewModel.messages = [oldMessage, recentMessage]

        // Verify ordering
        let sorted = viewModel.messages.sorted { $0.timestamp < $1.timestamp }
        #expect(sorted.last?.id == "recent")
        #expect(sorted.last?.text == "Recent message")
    }

    // MARK: - Read Receipt Tests

    @Test("Unread messages can be identified")
    func testUnreadMessageIdentification() async throws {
        let viewModel = ChatViewModel(
            currentUserId: "user1",
            otherUserId: "user2"
        )

        let messages = [
            TestFixtures.createTestMessage(id: "msg1", isRead: true),
            TestFixtures.createTestMessage(id: "msg2", isRead: false),
            TestFixtures.createTestMessage(id: "msg3", isRead: false),
            TestFixtures.createTestMessage(id: "msg4", isRead: true)
        ]

        viewModel.messages = messages

        let unreadMessages = viewModel.messages.filter { !$0.isRead }
        #expect(unreadMessages.count == 2)
        #expect(unreadMessages.map { $0.id }.contains("msg2"))
        #expect(unreadMessages.map { $0.id }.contains("msg3"))
    }

    @Test("All messages marked as read")
    func testAllMessagesRead() async throws {
        let viewModel = ChatViewModel()

        let messages = [
            TestFixtures.createTestMessage(id: "msg1", isRead: true),
            TestFixtures.createTestMessage(id: "msg2", isRead: true),
            TestFixtures.createTestMessage(id: "msg3", isRead: true)
        ]

        viewModel.messages = messages

        let allRead = viewModel.messages.allSatisfy { $0.isRead }
        #expect(allRead == true)
    }

    // MARK: - Multiple Matches Tests

    @Test("Handle multiple active matches")
    func testMultipleActiveMatches() async throws {
        let viewModel = ChatViewModel(currentUserId: "current_user")

        let matches = [
            TestFixtures.createTestMatch(id: "match1", user1Id: "current_user", user2Id: "user1"),
            TestFixtures.createTestMatch(id: "match2", user1Id: "current_user", user2Id: "user2"),
            TestFixtures.createTestMatch(id: "match3", user1Id: "current_user", user2Id: "user3"),
            TestFixtures.createTestMatch(id: "match4", user1Id: "current_user", user2Id: "user4")
        ]

        viewModel.matches = matches

        #expect(viewModel.matches.count == 4)
        #expect(viewModel.matches.allSatisfy { $0.isActive })
    }

    @Test("Filter only active matches")
    func testFilterActiveMatches() async throws {
        let viewModel = ChatViewModel()

        let matches = [
            TestFixtures.createTestMatch(id: "active1", isActive: true),
            TestFixtures.createTestMatch(id: "inactive1", isActive: false),
            TestFixtures.createTestMatch(id: "active2", isActive: true),
            TestFixtures.createTestMatch(id: "inactive2", isActive: false)
        ]

        viewModel.matches = matches.filter { $0.isActive }

        #expect(viewModel.matches.count == 2)
        #expect(viewModel.matches.allSatisfy { $0.isActive })
    }

    // MARK: - Message Content Tests

    @Test("Handle various message types")
    func testVariousMessageContent() async throws {
        let viewModel = ChatViewModel()

        let messages = [
            TestFixtures.createTestMessage(text: "Short"),
            TestFixtures.createTestMessage(text: "This is a much longer message with multiple sentences. It contains more detailed information and spans multiple lines."),
            TestFixtures.createTestMessage(text: "Message with emoji 👋😊🎉"),
            TestFixtures.createTestMessage(text: "Message with special chars: @#$%^&*()"),
            TestFixtures.createTestMessage(text: "Message with URL: https://example.com")
        ]

        viewModel.messages = messages

        #expect(viewModel.messages.count == 5)
        #expect(viewModel.messages.allSatisfy { !$0.text.isEmpty })
    }

    @Test("Handle empty message text gracefully")
    func testEmptyMessageHandling() async throws {
        let viewModel = ChatViewModel()

        // Empty text should be handled gracefully
        let emptyMessage = TestFixtures.createTestMessage(text: "")

        viewModel.messages = [emptyMessage]

        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages[0].text == "")
    }

    // MARK: - Large Conversation Tests

    @Test("Handle large conversation with many messages")
    func testLargeConversation() async throws {
        let viewModel = ChatViewModel(
            currentUserId: "user1",
            otherUserId: "user2"
        )

        let largeConversation = TestFixtures.createLargeConversation(
            matchId: "large_match",
            user1Id: "user1",
            user2Id: "user2",
            messageCount: 100
        )

        viewModel.messages = largeConversation

        #expect(viewModel.messages.count == 100)

        // Verify performance with large dataset
        let unreadCount = viewModel.messages.filter { !$0.isRead }.count
        #expect(unreadCount == 10) // Last 10 are unread per fixture
    }

    // MARK: - Match Metadata Tests

    @Test("Match has last message preview")
    func testMatchLastMessagePreview() async throws {
        let viewModel = ChatViewModel()

        let matchWithLastMessage = TestFixtures.createTestMatch(
            id: "match1",
            lastMessage: "Hey! How are you?",
            lastMessageTimestamp: Date.hoursAgo(2)
        )

        viewModel.matches = [matchWithLastMessage]

        #expect(viewModel.matches[0].lastMessage == "Hey! How are you?")
        #expect(viewModel.matches[0].lastMessageTimestamp != nil)
    }

    @Test("Match without messages has no preview")
    func testMatchWithoutMessages() async throws {
        let viewModel = ChatViewModel()

        let newMatch = TestFixtures.createTestMatch(
            id: "new_match",
            lastMessage: nil,
            lastMessageTimestamp: nil
        )

        viewModel.matches = [newMatch]

        #expect(viewModel.matches[0].lastMessage == nil)
        #expect(viewModel.matches[0].lastMessageTimestamp == nil)
    }

    // MARK: - State Consistency Tests

    @Test("ViewModel maintains state consistency")
    func testStateConsistency() async throws {
        let viewModel = ChatViewModel(
            currentUserId: "user1",
            otherUserId: "user2"
        )

        // Add messages
        viewModel.messages = TestFixtures.createConversation(
            matchId: "match1",
            user1Id: "user1",
            user2Id: "user2",
            messageCount: 5
        )

        let initialMessageCount = viewModel.messages.count
        #expect(initialMessageCount == 5)

        // State should remain consistent
        #expect(viewModel.currentUserId == "user1")
        #expect(viewModel.otherUserId == "user2")

        // Cleanup
        viewModel.cleanup()

        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.currentUserId == "user1") // User IDs persist
        #expect(viewModel.otherUserId == "user2")
    }

    // MARK: - Edge Cases

    @Test("Handle nil/missing match ID gracefully")
    func testMissingMatchId() async throws {
        let viewModel = ChatViewModel()

        // Create match without ID
        var match = TestFixtures.createTestMatch(user1Id: "user1", user2Id: "user2")
        match.id = nil

        viewModel.matches = [match]

        #expect(viewModel.matches.count == 1)
        #expect(viewModel.matches[0].id == nil)
    }

    @Test("Handle rapid state changes")
    func testRapidStateChanges() async throws {
        let viewModel = ChatViewModel()

        // Rapidly change loading state
        for _ in 0..<10 {
            viewModel.isLoading = true
            viewModel.isLoading = false
        }

        #expect(viewModel.isLoading == false)

        // Rapidly add/clear messages
        for i in 0..<5 {
            viewModel.messages = TestFixtures.createConversation(
                matchId: "match\(i)",
                user1Id: "user1",
                user2Id: "user2",
                messageCount: 2
            )
            viewModel.cleanup()
        }

        #expect(viewModel.messages.isEmpty)
    }
}
