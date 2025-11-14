//
//  ChatViewModelTests.swift
//  CelestiaTests
//
//  Comprehensive tests for ChatViewModel
//

import Testing
import FirebaseFirestore
@testable import Celestia

@Suite("ChatViewModel Tests")
@MainActor
struct ChatViewModelTests {

    // MARK: - Initialization Tests

    @Test("ViewModel initializes with correct default state")
    func testInitialState() async throws {
        let viewModel = ChatViewModel()

        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.matches.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.currentUserId.isEmpty)
        #expect(viewModel.otherUserId.isEmpty)
    }

    @Test("ViewModel initializes with provided user IDs")
    func testInitializationWithUserIds() async throws {
        let viewModel = ChatViewModel(
            currentUserId: "user123",
            otherUserId: "user456"
        )

        #expect(viewModel.currentUserId == "user123")
        #expect(viewModel.otherUserId == "user456")
    }

    @Test("UpdateCurrentUserId updates the user ID correctly")
    func testUpdateCurrentUserId() async throws {
        let viewModel = ChatViewModel()

        #expect(viewModel.currentUserId.isEmpty)

        viewModel.updateCurrentUserId("newUser123")

        #expect(viewModel.currentUserId == "newUser123")
    }

    // MARK: - Message State Tests

    @Test("Messages array can be populated")
    func testMessagesPopulation() async throws {
        let viewModel = ChatViewModel()

        let messages = TestFixtures.createConversation(
            matchId: "match123",
            user1Id: "user1",
            user2Id: "user2",
            messageCount: 5
        )

        viewModel.messages = messages

        #expect(viewModel.messages.count == 5)
        #expect(viewModel.messages[0].matchId == "match123")
    }

    @Test("Empty messages array")
    func testEmptyMessages() async throws {
        let viewModel = ChatViewModel()

        #expect(viewModel.messages.isEmpty)

        viewModel.messages = []

        #expect(viewModel.messages.isEmpty)
    }

    @Test("Single message in array")
    func testSingleMessage() async throws {
        let viewModel = ChatViewModel()

        let message = TestFixtures.createTestMessage(
            matchId: "match1",
            senderId: "sender",
            receiverId: "receiver",
            text: "Hello!"
        )

        viewModel.messages = [message]

        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages[0].text == "Hello!")
    }

    @Test("Multiple messages maintain order")
    func testMessageOrder() async throws {
        let viewModel = ChatViewModel()

        let messages = [
            TestFixtures.createTestMessage(text: "First", timestamp: Date.minutesAgo(10)),
            TestFixtures.createTestMessage(text: "Second", timestamp: Date.minutesAgo(5)),
            TestFixtures.createTestMessage(text: "Third", timestamp: Date.minutesAgo(1))
        ]

        viewModel.messages = messages

        #expect(viewModel.messages.count == 3)
        #expect(viewModel.messages[0].text == "First")
        #expect(viewModel.messages[1].text == "Second")
        #expect(viewModel.messages[2].text == "Third")
    }

    @Test("Large conversation with many messages")
    func testLargeConversation() async throws {
        let viewModel = ChatViewModel()

        let messages = TestFixtures.createConversation(
            matchId: "match",
            user1Id: "user1",
            user2Id: "user2",
            messageCount: 100
        )

        viewModel.messages = messages

        #expect(viewModel.messages.count == 100)
    }

    // MARK: - Match State Tests

    @Test("Matches array can be populated")
    func testMatchesPopulation() async throws {
        let viewModel = ChatViewModel()

        let matches = TestFixtures.createBatchMatches(count: 5, currentUserId: "currentUser")

        viewModel.matches = matches

        #expect(viewModel.matches.count == 5)
        #expect(viewModel.matches[0].user1Id == "currentUser")
    }

    @Test("Empty matches array")
    func testEmptyMatches() async throws {
        let viewModel = ChatViewModel()

        #expect(viewModel.matches.isEmpty)

        viewModel.matches = []

        #expect(viewModel.matches.isEmpty)
    }

    @Test("Single match in array")
    func testSingleMatch() async throws {
        let viewModel = ChatViewModel()

        let match = TestFixtures.createTestMatch(
            user1Id: "user1",
            user2Id: "user2"
        )

        viewModel.matches = [match]

        #expect(viewModel.matches.count == 1)
        #expect(viewModel.matches[0].user1Id == "user1")
        #expect(viewModel.matches[0].user2Id == "user2")
    }

    @Test("Multiple matches are maintained")
    func testMultipleMatches() async throws {
        let viewModel = ChatViewModel()

        let matches = [
            TestFixtures.createTestMatch(user1Id: "user1", user2Id: "userA"),
            TestFixtures.createTestMatch(user1Id: "user1", user2Id: "userB"),
            TestFixtures.createTestMatch(user1Id: "user1", user2Id: "userC")
        ]

        viewModel.matches = matches

        #expect(viewModel.matches.count == 3)
    }

    // MARK: - Loading State Tests

    @Test("IsLoading state toggles correctly")
    func testLoadingState() async throws {
        let viewModel = ChatViewModel()

        #expect(viewModel.isLoading == false)

        viewModel.isLoading = true
        #expect(viewModel.isLoading == true)

        viewModel.isLoading = false
        #expect(viewModel.isLoading == false)
    }

    // MARK: - Message Content Tests

    @Test("Messages with different content types")
    func testMessageContentVariety() async throws {
        let viewModel = ChatViewModel()

        let messages = [
            TestFixtures.createTestMessage(text: "Hello!"),
            TestFixtures.createTestMessage(text: "How are you?"),
            TestFixtures.createTestMessage(text: "😊👋"),
            TestFixtures.createTestMessage(text: "https://example.com")
        ]

        viewModel.messages = messages

        #expect(viewModel.messages.count == 4)
        #expect(viewModel.messages[0].text == "Hello!")
        #expect(viewModel.messages[2].text.contains("😊"))
    }

    @Test("Message with emoji")
    func testMessageWithEmoji() async throws {
        let viewModel = ChatViewModel()

        let message = TestFixtures.createTestMessage(
            text: "Hey! 👋 How's it going? 😊🎉"
        )

        viewModel.messages = [message]

        #expect(viewModel.messages[0].text.contains("👋"))
        #expect(viewModel.messages[0].text.contains("😊"))
        #expect(viewModel.messages[0].text.contains("🎉"))
    }

    @Test("Long message text")
    func testLongMessage() async throws {
        let viewModel = ChatViewModel()

        let longText = String(repeating: "This is a long message. ", count: 20)
        let message = TestFixtures.createTestMessage(text: longText)

        viewModel.messages = [message]

        #expect(viewModel.messages[0].text.count > 100)
    }

    @Test("Message with special characters")
    func testMessageWithSpecialCharacters() async throws {
        let viewModel = ChatViewModel()

        let message = TestFixtures.createTestMessage(
            text: "¿Cómo estás? Très bien! 你好"
        )

        viewModel.messages = [message]

        #expect(viewModel.messages[0].text.contains("¿"))
        #expect(viewModel.messages[0].text.contains("è"))
        #expect(viewModel.messages[0].text.contains("好"))
    }

    @Test("Empty message text")
    func testEmptyMessageText() async throws {
        let viewModel = ChatViewModel()

        let message = TestFixtures.createTestMessage(text: "")

        viewModel.messages = [message]

        #expect(viewModel.messages[0].text.isEmpty)
    }

    // MARK: - Read Status Tests

    @Test("Message read status updates")
    func testMessageReadStatus() async throws {
        let viewModel = ChatViewModel()

        let unreadMessage = TestFixtures.createTestMessage(
            text: "Unread",
            isRead: false
        )
        let readMessage = TestFixtures.createTestMessage(
            text: "Read",
            isRead: true
        )

        viewModel.messages = [unreadMessage, readMessage]

        #expect(viewModel.messages[0].isRead == false)
        #expect(viewModel.messages[1].isRead == true)
    }

    @Test("All messages read")
    func testAllMessagesRead() async throws {
        let viewModel = ChatViewModel()

        let messages = (0..<5).map { index in
            TestFixtures.createTestMessage(
                text: "Message \(index)",
                isRead: true
            )
        }

        viewModel.messages = messages

        let allRead = viewModel.messages.allSatisfy { $0.isRead }
        #expect(allRead == true)
    }

    @Test("All messages unread")
    func testAllMessagesUnread() async throws {
        let viewModel = ChatViewModel()

        let messages = (0..<5).map { index in
            TestFixtures.createTestMessage(
                text: "Message \(index)",
                isRead: false
            )
        }

        viewModel.messages = messages

        let allUnread = viewModel.messages.allSatisfy { !$0.isRead }
        #expect(allUnread == true)
    }

    @Test("Mixed read and unread messages")
    func testMixedReadStatus() async throws {
        let viewModel = ChatViewModel()

        let messages = [
            TestFixtures.createTestMessage(text: "1", isRead: true),
            TestFixtures.createTestMessage(text: "2", isRead: true),
            TestFixtures.createTestMessage(text: "3", isRead: false),
            TestFixtures.createTestMessage(text: "4", isRead: false)
        ]

        viewModel.messages = messages

        let readCount = viewModel.messages.filter { $0.isRead }.count
        let unreadCount = viewModel.messages.filter { !$0.isRead }.count

        #expect(readCount == 2)
        #expect(unreadCount == 2)
    }

    // MARK: - Cleanup Tests

    @Test("Cleanup clears messages")
    func testCleanupMessages() async throws {
        let viewModel = ChatViewModel()

        viewModel.messages = TestFixtures.createConversation(
            matchId: "match",
            user1Id: "user1",
            user2Id: "user2",
            messageCount: 10
        )

        #expect(!viewModel.messages.isEmpty)

        viewModel.cleanup()

        #expect(viewModel.messages.isEmpty)
    }

    @Test("Cleanup can be called multiple times")
    func testMultipleCleanups() async throws {
        let viewModel = ChatViewModel()

        viewModel.messages = TestFixtures.createConversation(
            matchId: "match",
            user1Id: "user1",
            user2Id: "user2"
        )

        viewModel.cleanup()
        #expect(viewModel.messages.isEmpty)

        viewModel.cleanup()
        #expect(viewModel.messages.isEmpty)
    }

    // MARK: - Match Properties Tests

    @Test("Active and inactive matches")
    func testActiveInactiveMatches() async throws {
        let viewModel = ChatViewModel()

        let activeMatch = TestFixtures.createTestMatch(isActive: true)
        let inactiveMatch = TestFixtures.createTestMatch(isActive: false)

        viewModel.matches = [activeMatch, inactiveMatch]

        #expect(viewModel.matches[0].isActive == true)
        #expect(viewModel.matches[1].isActive == false)
    }

    @Test("Match with last message")
    func testMatchWithLastMessage() async throws {
        let viewModel = ChatViewModel()

        let match = TestFixtures.createTestMatch(
            lastMessage: "Hey, how are you?",
            lastMessageTimestamp: Date()
        )

        viewModel.matches = [match]

        #expect(viewModel.matches[0].lastMessage == "Hey, how are you?")
        #expect(viewModel.matches[0].lastMessageTimestamp != nil)
    }

    @Test("Match without last message")
    func testMatchWithoutLastMessage() async throws {
        let viewModel = ChatViewModel()

        let match = TestFixtures.createTestMatch(
            lastMessage: nil,
            lastMessageTimestamp: nil
        )

        viewModel.matches = [match]

        #expect(viewModel.matches[0].lastMessage == nil)
        #expect(viewModel.matches[0].lastMessageTimestamp == nil)
    }

    // MARK: - Conversation Flow Tests

    @Test("Conversation between two users")
    func testConversationFlow() async throws {
        let viewModel = ChatViewModel(
            currentUserId: "user1",
            otherUserId: "user2"
        )

        let messages = TestFixtures.createConversation(
            matchId: "match123",
            user1Id: "user1",
            user2Id: "user2",
            messageCount: 6
        )

        viewModel.messages = messages

        // Verify alternating senders
        #expect(viewModel.messages[0].senderId == "user1")
        #expect(viewModel.messages[1].senderId == "user2")
        #expect(viewModel.messages[2].senderId == "user1")
        #expect(viewModel.messages[3].senderId == "user2")
    }

    @Test("Timestamps are in order")
    func testMessageTimestamps() async throws {
        let viewModel = ChatViewModel()

        let messages = [
            TestFixtures.createTestMessage(timestamp: Date.hoursAgo(3)),
            TestFixtures.createTestMessage(timestamp: Date.hoursAgo(2)),
            TestFixtures.createTestMessage(timestamp: Date.hoursAgo(1)),
            TestFixtures.createTestMessage(timestamp: Date())
        ]

        viewModel.messages = messages

        // Verify timestamps are in ascending order
        for i in 0..<(messages.count - 1) {
            let current = viewModel.messages[i].timestamp
            let next = viewModel.messages[i + 1].timestamp
            #expect(current <= next)
        }
    }

    // MARK: - Edge Cases

    @Test("UserIDs with special characters")
    func testUserIdsWithSpecialCharacters() async throws {
        let viewModel = ChatViewModel(
            currentUserId: "user-123_abc",
            otherUserId: "user-456_def"
        )

        #expect(viewModel.currentUserId == "user-123_abc")
        #expect(viewModel.otherUserId == "user-456_def")
    }

    @Test("Very long user IDs")
    func testLongUserIds() async throws {
        let longId1 = String(repeating: "a", count: 100)
        let longId2 = String(repeating: "b", count: 100)

        let viewModel = ChatViewModel(
            currentUserId: longId1,
            otherUserId: longId2
        )

        #expect(viewModel.currentUserId.count == 100)
        #expect(viewModel.otherUserId.count == 100)
    }

    @Test("MatchId consistency across messages")
    func testMatchIdConsistency() async throws {
        let viewModel = ChatViewModel()

        let messages = TestFixtures.createConversation(
            matchId: "consistent_match",
            user1Id: "user1",
            user2Id: "user2",
            messageCount: 10
        )

        viewModel.messages = messages

        let allSameMatchId = viewModel.messages.allSatisfy { $0.matchId == "consistent_match" }
        #expect(allSameMatchId == true)
    }
}
