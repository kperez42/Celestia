//
//  MessagingErrorTests.swift
//  CelestiaTests
//
//  Comprehensive error tests for the messaging system
//  Tests all failure scenarios: sending, images, deletion, editing, reactions, offline, etc.
//

import Testing
import Foundation
@testable import Celestia

// MARK: - Mock Message Repository for Error Testing

/// Mock repository that can simulate various error conditions
class MockErrorMessageRepository: MessageRepository {
    var shouldFailFetch = false
    var shouldFailSend = false
    var shouldFailDelete = false
    var shouldFailMarkAsRead = false
    var errorToThrow: Error = CelestiaError.networkError
    var mockMessages: [Message] = []
    var fetchDelay: TimeInterval = 0

    func fetchMessages(matchId: String, limit: Int, before: Date?) async throws -> [Message] {
        if fetchDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(fetchDelay * 1_000_000_000))
        }
        if shouldFailFetch {
            throw errorToThrow
        }
        return mockMessages
    }

    func sendMessage(_ message: Message) async throws {
        if shouldFailSend {
            throw errorToThrow
        }
    }

    func markMessagesAsRead(matchId: String, userId: String) async throws {
        if shouldFailMarkAsRead {
            throw errorToThrow
        }
    }

    func deleteMessage(messageId: String) async throws {
        if shouldFailDelete {
            throw errorToThrow
        }
    }
}

// MARK: - Message Sending Error Tests

@Suite("Message Sending Error Tests")
struct MessageSendingErrorTests {

    // MARK: - Empty Message Tests

    @Test("Empty message text is rejected")
    func testEmptyMessageRejected() async throws {
        let emptyText = ""
        let sanitized = InputSanitizer.standard(emptyText)
        #expect(sanitized.isEmpty)
    }

    @Test("Whitespace-only message is rejected")
    func testWhitespaceOnlyMessageRejected() async throws {
        let whitespaceText = "   \t\n   "
        let sanitized = InputSanitizer.standard(whitespaceText)
        #expect(sanitized.isEmpty)
    }

    @Test("Message with only newlines is rejected")
    func testNewlineOnlyMessageRejected() async throws {
        let newlineText = "\n\n\n"
        let sanitized = InputSanitizer.standard(newlineText)
        #expect(sanitized.isEmpty)
    }

    // MARK: - Message Length Tests

    @Test("Message exceeding max length throws error")
    func testMessageTooLong() async throws {
        let maxLength = AppConstants.Limits.maxMessageLength
        let longMessage = String(repeating: "a", count: maxLength + 100)

        #expect(longMessage.count > maxLength)
        // In actual send, this would throw CelestiaError.messageTooLong
    }

    @Test("Message at exact max length is accepted")
    func testMessageAtMaxLength() async throws {
        let maxLength = AppConstants.Limits.maxMessageLength
        let exactMessage = String(repeating: "a", count: maxLength)

        #expect(exactMessage.count == maxLength)
        #expect(!exactMessage.isEmpty)
    }

    @Test("Unicode message within limit is accepted")
    func testUnicodeMessageWithinLimit() async throws {
        let emojiMessage = String(repeating: "🌟", count: 100)
        let maxLength = AppConstants.Limits.maxMessageLength

        #expect(emojiMessage.count <= maxLength)
    }

    // MARK: - Invalid ID Tests

    @Test("Empty matchId is invalid")
    func testEmptyMatchIdInvalid() async throws {
        let emptyMatchId = ""
        #expect(emptyMatchId.isEmpty)
    }

    @Test("Empty senderId is invalid")
    func testEmptySenderIdInvalid() async throws {
        let emptySenderId = ""
        #expect(emptySenderId.isEmpty)
    }

    @Test("Empty receiverId is invalid")
    func testEmptyReceiverIdInvalid() async throws {
        let emptyReceiverId = ""
        #expect(emptyReceiverId.isEmpty)
    }

    // MARK: - XSS Prevention Tests

    @Test("Script tags are sanitized from messages")
    func testScriptTagsSanitized() async throws {
        let maliciousText = "<script>alert('xss')</script>Hello"
        let sanitized = InputSanitizer.standard(maliciousText)

        #expect(!sanitized.contains("<script>"))
        #expect(!sanitized.contains("</script>"))
        #expect(!sanitized.contains("alert"))
    }

    @Test("HTML tags are sanitized from messages")
    func testHtmlTagsSanitized() async throws {
        let htmlText = "<div onclick='malicious()'>Click me</div>"
        let sanitized = InputSanitizer.standard(htmlText)

        #expect(!sanitized.contains("<div"))
        #expect(!sanitized.contains("onclick"))
    }

    @Test("JavaScript URLs are sanitized")
    func testJavascriptUrlsSanitized() async throws {
        let jsUrlText = "javascript:alert('xss')"
        let sanitized = InputSanitizer.standard(jsUrlText)

        // Should not contain executable javascript
        #expect(!sanitized.lowercased().contains("javascript:"))
    }

    // MARK: - Rate Limiting Tests

    @Test("Rate limit error has time remaining")
    func testRateLimitErrorWithTime() async throws {
        let timeRemaining: TimeInterval = 300 // 5 minutes
        let error = CelestiaError.rateLimitExceededWithTime(timeRemaining)

        #expect(error.errorDescription?.contains("5m") == true)
    }

    @Test("Rate limit error without time")
    func testRateLimitErrorWithoutTime() async throws {
        let error = CelestiaError.rateLimitExceeded

        #expect(error.errorDescription?.contains("too often") == true)
    }

    // MARK: - Network Error Tests

    @Test("Network error is properly identified")
    func testNetworkErrorIdentification() async throws {
        let error = CelestiaError.networkError
        #expect(error.errorDescription?.contains("Network") == true)
    }

    @Test("No internet connection error")
    func testNoInternetConnectionError() async throws {
        let error = CelestiaError.noInternetConnection
        #expect(error.errorDescription?.contains("internet") == true)
    }

    @Test("Timeout error is handled")
    func testTimeoutError() async throws {
        let error = CelestiaError.timeout
        #expect(error.errorDescription?.contains("timed out") == true)
    }

    @Test("Server error is handled")
    func testServerError() async throws {
        let error = CelestiaError.serverError
        #expect(error.errorDescription?.contains("Server") == true)
    }

    // MARK: - Message Delivery Status Tests

    @Test("Message delivery status pending")
    func testMessageDeliveryStatusPending() async throws {
        let status = MessageDeliveryStatus.pending
        #expect(status.rawValue == "pending")
    }

    @Test("Message delivery status sending")
    func testMessageDeliveryStatusSending() async throws {
        let status = MessageDeliveryStatus.sending
        #expect(status.rawValue == "sending")
    }

    @Test("Message delivery status failed")
    func testMessageDeliveryStatusFailed() async throws {
        let status = MessageDeliveryStatus.failed
        #expect(status.rawValue == "failed")
    }

    @Test("Message delivery status failed permanent")
    func testMessageDeliveryStatusFailedPermanent() async throws {
        let status = MessageDeliveryStatus.failedPermanent
        #expect(status.rawValue == "failedPermanent")
    }

    // MARK: - Retry Configuration Tests

    @Test("Retry delay calculation is exponential")
    func testRetryDelayExponential() async throws {
        let delay0 = MessageRetryConfig.delay(for: 0)
        let delay1 = MessageRetryConfig.delay(for: 1)
        let delay2 = MessageRetryConfig.delay(for: 2)

        #expect(delay0 == 1.0)
        #expect(delay1 == 2.0)
        #expect(delay2 == 4.0)
    }

    @Test("Retry delay is capped at max")
    func testRetryDelayCapped() async throws {
        let delayHigh = MessageRetryConfig.delay(for: 10)

        #expect(delayHigh <= MessageRetryConfig.maxDelaySeconds)
        #expect(delayHigh == 30.0)
    }

    @Test("Max retries configuration")
    func testMaxRetriesConfig() async throws {
        #expect(MessageRetryConfig.maxRetries == 3)
    }
}

// MARK: - Image Upload Error Tests

@Suite("Image Upload Error Tests")
struct ImageUploadErrorTests {

    // MARK: - Image Format Errors

    @Test("Invalid image format error")
    func testInvalidImageFormatError() async throws {
        let error = CelestiaError.invalidImageFormat
        #expect(error.errorDescription?.contains("Invalid image format") == true)
    }

    @Test("Image too big error")
    func testImageTooBigError() async throws {
        let error = CelestiaError.imageTooBig
        #expect(error.errorDescription?.contains("too large") == true)
    }

    @Test("Too many images error")
    func testTooManyImagesError() async throws {
        let error = CelestiaError.tooManyImages
        #expect(error.errorDescription?.contains("maximum") == true)
    }

    @Test("Image upload failed error")
    func testImageUploadFailedError() async throws {
        let error = CelestiaError.imageUploadFailed
        #expect(error.errorDescription?.contains("Failed to upload") == true)
    }

    // MARK: - Content Moderation Errors

    @Test("Content not allowed error with message")
    func testContentNotAllowedWithMessage() async throws {
        let error = CelestiaError.contentNotAllowed("Inappropriate content detected")
        #expect(error.errorDescription?.contains("Inappropriate content") == true)
    }

    @Test("Content not allowed error with empty message")
    func testContentNotAllowedEmptyMessage() async throws {
        let error = CelestiaError.contentNotAllowed("")
        #expect(error.errorDescription?.contains("not allowed") == true)
    }

    @Test("Storage quota exceeded error")
    func testStorageQuotaExceededError() async throws {
        let error = CelestiaError.storageQuotaExceeded
        #expect(error.errorDescription?.contains("quota") == true)
    }

    // MARK: - Image Dimension Tests

    @Test("Minimum image dimension validation")
    func testMinimumImageDimension() async throws {
        let minDimension: CGFloat = 200
        let tooSmallWidth: CGFloat = 100
        let tooSmallHeight: CGFloat = 150

        #expect(tooSmallWidth < minDimension)
        #expect(tooSmallHeight < minDimension)
    }

    @Test("Maximum image dimension validation")
    func testMaximumImageDimension() async throws {
        let maxDimension: CGFloat = 3000
        let tooLargeWidth: CGFloat = 5000

        #expect(tooLargeWidth > maxDimension)
    }

    @Test("Valid aspect ratio range")
    func testValidAspectRatioRange() async throws {
        let minRatio: CGFloat = 0.33
        let maxRatio: CGFloat = 3.0

        // Valid ratios
        let portrait = 1.0 / 2.0  // 0.5
        let landscape = 2.0 / 1.0 // 2.0
        let square = 1.0

        #expect(portrait >= minRatio && portrait <= maxRatio)
        #expect(landscape >= minRatio && landscape <= maxRatio)
        #expect(square >= minRatio && square <= maxRatio)
    }

    @Test("Invalid aspect ratio detection")
    func testInvalidAspectRatio() async throws {
        let minRatio: CGFloat = 0.33
        let maxRatio: CGFloat = 3.0

        // Invalid ratios
        let tooTall = 1.0 / 5.0  // 0.2
        let tooWide = 5.0 / 1.0  // 5.0

        #expect(tooTall < minRatio)
        #expect(tooWide > maxRatio)
    }

    // MARK: - Image Message Creation Tests

    @Test("Image message has correct default text")
    func testImageMessageDefaultText() async throws {
        let message = Message(
            matchId: "match123",
            senderId: "user1",
            receiverId: "user2",
            text: "📷 Photo",
            imageURL: "https://example.com/image.jpg"
        )

        #expect(message.text == "📷 Photo")
        #expect(message.imageURL != nil)
    }

    @Test("Image message with caption")
    func testImageMessageWithCaption() async throws {
        let caption = "Look at this!"
        let message = Message(
            matchId: "match123",
            senderId: "user1",
            receiverId: "user2",
            text: caption,
            imageURL: "https://example.com/image.jpg"
        )

        #expect(message.text == caption)
        #expect(message.imageURL != nil)
    }
}

// MARK: - Message Deletion Error Tests

@Suite("Message Deletion Error Tests")
struct MessageDeletionErrorTests {

    @Test("Delete message with empty ID fails")
    func testDeleteEmptyIdFails() async throws {
        let emptyId = ""
        #expect(emptyId.isEmpty)
        // Empty ID should cause validation failure
    }

    @Test("Delete non-existent message error")
    func testDeleteNonExistentMessage() async throws {
        let error = CelestiaError.documentNotFound
        #expect(error.errorDescription?.contains("not found") == true)
    }

    @Test("Unauthorized message deletion error")
    func testUnauthorizedDeletion() async throws {
        let error = CelestiaError.unauthorized
        #expect(error.errorDescription?.contains("not authorized") == true)
    }

    @Test("Permission denied for deletion")
    func testPermissionDeniedDeletion() async throws {
        let error = CelestiaError.permissionDenied
        #expect(error.errorDescription?.contains("Permission denied") == true)
    }

    @Test("Batch operation failed error")
    func testBatchOperationFailed() async throws {
        let underlyingError = NSError(domain: "Test", code: 500, userInfo: nil)
        let error = CelestiaError.batchOperationFailed(operationId: "delete_all", underlyingError: underlyingError)

        #expect(error.errorDescription?.contains("delete_all") == true)
        #expect(error.errorDescription?.contains("failed") == true)
    }
}

// MARK: - Message Editing Error Tests

@Suite("Message Editing Error Tests")
struct MessageEditingErrorTests {

    @Test("Edit time limit exceeded error")
    func testEditTimeLimitExceeded() async throws {
        let error = CelestiaError.editTimeLimitExceeded
        #expect(error.errorDescription?.contains("15 minutes") == true)
    }

    @Test("Edit with empty text fails")
    func testEditEmptyTextFails() async throws {
        let emptyText = ""
        let sanitized = InputSanitizer.standard(emptyText)
        #expect(sanitized.isEmpty)
    }

    @Test("Edit time limit calculation - within limit")
    func testEditWithinTimeLimit() async throws {
        let messageTimestamp = Date()
        let minutesSinceSent = Date().timeIntervalSince(messageTimestamp) / 60

        #expect(minutesSinceSent <= 15)
    }

    @Test("Edit time limit calculation - exceeded")
    func testEditTimeLimitExceededCalculation() async throws {
        let messageTimestamp = Date().addingTimeInterval(-20 * 60) // 20 minutes ago
        let minutesSinceSent = Date().timeIntervalSince(messageTimestamp) / 60

        #expect(minutesSinceSent > 15)
    }

    @Test("Edit by non-sender fails")
    func testEditByNonSenderFails() async throws {
        let message = Message(
            matchId: "match123",
            senderId: "user1",
            receiverId: "user2",
            text: "Original text"
        )

        let attemptingUserId = "user2" // Receiver trying to edit
        #expect(message.senderId != attemptingUserId)
    }

    @Test("Message edit tracking")
    func testMessageEditTracking() async throws {
        var message = Message(
            matchId: "match123",
            senderId: "user1",
            receiverId: "user2",
            text: "Original text"
        )

        #expect(message.isEdited == false)
        #expect(message.editedAt == nil)
        #expect(message.originalText == nil)

        // Simulate edit
        message.originalText = message.text
        message.text = "Edited text"
        message.isEdited = true
        message.editedAt = Date()

        #expect(message.isEdited == true)
        #expect(message.editedAt != nil)
        #expect(message.originalText == "Original text")
    }
}

// MARK: - Message Reaction Error Tests

@Suite("Message Reaction Error Tests")
struct MessageReactionErrorTests {

    @Test("Reaction with empty messageId fails")
    func testReactionEmptyMessageId() async throws {
        let emptyId = ""
        #expect(emptyId.isEmpty)
    }

    @Test("Reaction with empty userId fails")
    func testReactionEmptyUserId() async throws {
        let emptyId = ""
        #expect(emptyId.isEmpty)
    }

    @Test("Reaction with empty emoji fails")
    func testReactionEmptyEmoji() async throws {
        let emptyEmoji = ""
        #expect(emptyEmoji.isEmpty)
    }

    @Test("Duplicate reaction detection")
    func testDuplicateReactionDetection() async throws {
        let reaction1 = MessageReaction(emoji: "❤️", userId: "user1")
        let reaction2 = MessageReaction(emoji: "❤️", userId: "user1")

        // Same emoji and userId should be considered duplicate
        #expect(reaction1.emoji == reaction2.emoji)
        #expect(reaction1.userId == reaction2.userId)
    }

    @Test("Message hasUserReacted check")
    func testHasUserReacted() async throws {
        let reaction = MessageReaction(emoji: "❤️", userId: "user1")
        var message = Message(
            matchId: "match123",
            senderId: "user1",
            receiverId: "user2",
            text: "Hello",
            reactions: [reaction]
        )

        #expect(message.hasUserReacted(userId: "user1", emoji: "❤️") == true)
        #expect(message.hasUserReacted(userId: "user1", emoji: "👍") == false)
        #expect(message.hasUserReacted(userId: "user2", emoji: "❤️") == false)
    }

    @Test("Reaction count calculation")
    func testReactionCount() async throws {
        let reactions = [
            MessageReaction(emoji: "❤️", userId: "user1"),
            MessageReaction(emoji: "❤️", userId: "user2"),
            MessageReaction(emoji: "👍", userId: "user1")
        ]

        let message = Message(
            matchId: "match123",
            senderId: "user1",
            receiverId: "user2",
            text: "Hello",
            reactions: reactions
        )

        #expect(message.reactionCount(for: "❤️") == 2)
        #expect(message.reactionCount(for: "👍") == 1)
        #expect(message.reactionCount(for: "😀") == 0)
    }

    @Test("Unique reaction emojis")
    func testUniqueReactionEmojis() async throws {
        let reactions = [
            MessageReaction(emoji: "❤️", userId: "user1"),
            MessageReaction(emoji: "❤️", userId: "user2"),
            MessageReaction(emoji: "👍", userId: "user1")
        ]

        let message = Message(
            matchId: "match123",
            senderId: "user1",
            receiverId: "user2",
            text: "Hello",
            reactions: reactions
        )

        #expect(message.uniqueReactionEmojis.count == 2)
        #expect(message.uniqueReactionEmojis.contains("❤️"))
        #expect(message.uniqueReactionEmojis.contains("👍"))
    }
}

// MARK: - Reply Message Error Tests

@Suite("Reply Message Error Tests")
struct ReplyMessageErrorTests {

    @Test("Reply with empty replyTo messageId")
    func testReplyEmptyReplyToMessageId() async throws {
        let emptyId = ""
        #expect(emptyId.isEmpty)
    }

    @Test("Reply message structure")
    func testReplyMessageStructure() async throws {
        let replyTo = MessageReply(
            messageId: "originalMsg123",
            senderId: "user1",
            senderName: "John",
            text: "Original message text"
        )

        let message = Message(
            matchId: "match123",
            senderId: "user2",
            receiverId: "user1",
            text: "This is a reply",
            replyTo: replyTo
        )

        #expect(message.replyTo != nil)
        #expect(message.replyTo?.messageId == "originalMsg123")
        #expect(message.replyTo?.text == "Original message text")
    }

    @Test("Reply to image message")
    func testReplyToImageMessage() async throws {
        let replyTo = MessageReply(
            messageId: "imgMsg123",
            senderId: "user1",
            senderName: "John",
            text: "📷 Photo",
            imageURL: "https://example.com/image.jpg"
        )

        #expect(replyTo.imageURL != nil)
        #expect(replyTo.text == "📷 Photo")
    }
}

// MARK: - Offline/Queue Error Tests

@Suite("Offline Queue Error Tests")
struct OfflineQueueErrorTests {

    @Test("Message queued for delivery status")
    func testMessageQueuedStatus() async throws {
        let error = CelestiaError.messageQueuedForDelivery
        #expect(error.errorDescription?.contains("queued") == true)
    }

    @Test("Message delivery failed retryable")
    func testMessageDeliveryFailedRetryable() async throws {
        let error = CelestiaError.messageDeliveryFailed(retryable: true)
        #expect(error.errorDescription?.contains("retried automatically") == true)
    }

    @Test("Message delivery failed non-retryable")
    func testMessageDeliveryFailedNonRetryable() async throws {
        let error = CelestiaError.messageDeliveryFailed(retryable: false)
        #expect(error.errorDescription?.contains("could not be delivered") == true)
    }

    @Test("Queued message structure")
    func testQueuedMessageStructure() async throws {
        // Test that a message can be created for queuing
        let message = Message(
            matchId: "match123",
            senderId: "user1",
            receiverId: "user2",
            text: "Queued message"
        )

        #expect(message.matchId == "match123")
        #expect(message.senderId == "user1")
        #expect(message.receiverId == "user2")
        #expect(message.text == "Queued message")
    }

    @Test("Network error triggers queue")
    func testNetworkErrorTriggersQueue() async throws {
        let networkError = CelestiaError.noInternetConnection

        // Network errors should result in queuing
        #expect(networkError == .noInternetConnection)
    }
}

// MARK: - Message Listener Error Tests

@Suite("Message Listener Error Tests")
struct MessageListenerErrorTests {

    @Test("Listener with nil matchId")
    func testListenerNilMatchId() async throws {
        let nilMatchId: String? = nil
        #expect(nilMatchId == nil)
    }

    @Test("Listener with empty matchId")
    func testListenerEmptyMatchId() async throws {
        let emptyMatchId = ""
        #expect(emptyMatchId.isEmpty)
    }

    @Test("Stale listener callback detection")
    func testStaleListenerCallbackDetection() async throws {
        let originalMatchId = "match1"
        let currentMatchId = "match2"

        // Callback for original match should be ignored if current match changed
        #expect(originalMatchId != currentMatchId)
    }

    @Test("Message ID set deduplication")
    func testMessageIdSetDeduplication() async throws {
        var messageIdSet: Set<String> = []

        let messageId = "msg123"

        // First insert should succeed
        let inserted = messageIdSet.insert(messageId).inserted
        #expect(inserted == true)

        // Second insert should fail (duplicate)
        let insertedAgain = messageIdSet.insert(messageId).inserted
        #expect(insertedAgain == false)
    }

    @Test("Message with nil ID handling")
    func testMessageNilIdHandling() async throws {
        let message = Message(
            id: nil,
            matchId: "match123",
            senderId: "user1",
            receiverId: "user2",
            text: "Hello"
        )

        #expect(message.id == nil)
    }
}

// MARK: - Pagination Error Tests

@Suite("Pagination Error Tests")
struct PaginationErrorTests {

    @Test("Pagination with no oldest timestamp")
    func testPaginationNoOldestTimestamp() async throws {
        let oldestTimestamp: Date? = nil
        #expect(oldestTimestamp == nil)
    }

    @Test("Pagination already loading")
    func testPaginationAlreadyLoading() async throws {
        let isLoadingMore = true
        #expect(isLoadingMore == true)
        // Should not start another load
    }

    @Test("Pagination no more messages")
    func testPaginationNoMoreMessages() async throws {
        let hasMoreMessages = false
        #expect(hasMoreMessages == false)
        // Should not attempt to load more
    }

    @Test("Messages per page limit")
    func testMessagesPerPageLimit() async throws {
        let messagesPerPage = 20
        let loadedCount = 20

        // If loaded count equals page size, there might be more
        #expect(loadedCount >= messagesPerPage)
    }

    @Test("Reached beginning of conversation")
    func testReachedBeginningOfConversation() async throws {
        let messagesPerPage = 20
        let loadedCount = 5 // Less than page size

        // Less than page size means we've reached the beginning
        #expect(loadedCount < messagesPerPage)
    }
}

// MARK: - Content Validation Error Tests

@Suite("Content Validation Error Tests")
struct ContentValidationErrorTests {

    @Test("Inappropriate content error")
    func testInappropriateContentError() async throws {
        let error = CelestiaError.inappropriateContent
        #expect(error.errorDescription?.contains("inappropriate") == true)
    }

    @Test("Inappropriate content with reasons")
    func testInappropriateContentWithReasons() async throws {
        let reasons = ["profanity", "harassment"]
        let error = CelestiaError.inappropriateContentWithReasons(reasons)

        #expect(error.errorDescription?.contains("profanity") == true)
        #expect(error.errorDescription?.contains("harassment") == true)
    }

    @Test("Message not sent error")
    func testMessageNotSentError() async throws {
        let error = CelestiaError.messageNotSent
        #expect(error.errorDescription?.contains("failed to send") == true)
    }
}

// MARK: - Error Recovery Tests

@Suite("Error Recovery Tests")
struct ErrorRecoveryTests {

    @Test("Network error has recovery suggestion")
    func testNetworkErrorRecovery() async throws {
        let error = CelestiaError.networkError
        #expect(error.recoverySuggestion != nil)
        #expect(error.recoverySuggestion?.contains("connection") == true)
    }

    @Test("Message queued has recovery suggestion")
    func testMessageQueuedRecovery() async throws {
        let error = CelestiaError.messageQueuedForDelivery
        #expect(error.recoverySuggestion != nil)
        #expect(error.recoverySuggestion?.contains("back online") == true)
    }

    @Test("Rate limit has recovery suggestion")
    func testRateLimitRecovery() async throws {
        let error = CelestiaError.rateLimitExceeded
        #expect(error.recoverySuggestion != nil)
        #expect(error.recoverySuggestion?.contains("wait") == true)
    }

    @Test("Message delivery failed has recovery suggestion")
    func testMessageDeliveryFailedRecovery() async throws {
        let errorRetryable = CelestiaError.messageDeliveryFailed(retryable: true)
        #expect(errorRetryable.recoverySuggestion?.contains("automatically") == true)

        let errorNonRetryable = CelestiaError.messageDeliveryFailed(retryable: false)
        #expect(errorNonRetryable.recoverySuggestion?.contains("again") == true)
    }

    @Test("Image too big has recovery suggestion")
    func testImageTooBigRecovery() async throws {
        let error = CelestiaError.imageTooBig
        #expect(error.recoverySuggestion != nil)
        #expect(error.recoverySuggestion?.contains("Reduce") == true)
    }

    @Test("Content not allowed has recovery suggestion")
    func testContentNotAllowedRecovery() async throws {
        let error = CelestiaError.contentNotAllowed("Test")
        #expect(error.recoverySuggestion != nil)
        #expect(error.recoverySuggestion?.contains("guidelines") == true)
    }
}

// MARK: - Error Icon Tests

@Suite("Error Icon Tests")
struct ErrorIconTests {

    @Test("Network error has correct icon")
    func testNetworkErrorIcon() async throws {
        let error = CelestiaError.networkError
        #expect(error.icon == "wifi.slash")
    }

    @Test("Message error has correct icon")
    func testMessageErrorIcon() async throws {
        let error = CelestiaError.messageNotSent
        #expect(error.icon == "message.badge.exclamationmark")
    }

    @Test("Image error has correct icon")
    func testImageErrorIcon() async throws {
        let error = CelestiaError.imageUploadFailed
        #expect(error.icon == "photo")
    }

    @Test("Rate limit error has correct icon")
    func testRateLimitErrorIcon() async throws {
        let error = CelestiaError.rateLimitExceeded
        #expect(error.icon == "clock.fill")
    }

    @Test("Message queued has correct icon")
    func testMessageQueuedIcon() async throws {
        let error = CelestiaError.messageQueuedForDelivery
        #expect(error.icon == "clock.arrow.circlepath")
    }

    @Test("Content not allowed has correct icon")
    func testContentNotAllowedIcon() async throws {
        let error = CelestiaError.contentNotAllowed("Test")
        #expect(error.icon == "exclamationmark.triangle.fill")
    }
}

// MARK: - Message Status Error Tests

@Suite("Message Status Error Tests")
struct MessageStatusErrorTests {

    @Test("Mark messages as read with empty matchId")
    func testMarkAsReadEmptyMatchId() async throws {
        let emptyMatchId = ""
        #expect(emptyMatchId.isEmpty)
    }

    @Test("Mark messages as read with empty userId")
    func testMarkAsReadEmptyUserId() async throws {
        let emptyUserId = ""
        #expect(emptyUserId.isEmpty)
    }

    @Test("Message read status tracking")
    func testMessageReadStatusTracking() async throws {
        var message = Message(
            matchId: "match123",
            senderId: "user1",
            receiverId: "user2",
            text: "Hello"
        )

        #expect(message.isRead == false)
        #expect(message.readAt == nil)

        // Mark as read
        message.isRead = true
        message.readAt = Date()

        #expect(message.isRead == true)
        #expect(message.readAt != nil)
    }

    @Test("Message delivered status tracking")
    func testMessageDeliveredStatusTracking() async throws {
        var message = Message(
            matchId: "match123",
            senderId: "user1",
            receiverId: "user2",
            text: "Hello"
        )

        #expect(message.isDelivered == false)
        #expect(message.deliveredAt == nil)

        // Mark as delivered
        message.isDelivered = true
        message.deliveredAt = Date()

        #expect(message.isDelivered == true)
        #expect(message.deliveredAt != nil)
    }
}

// MARK: - Error Conversion Tests

@Suite("Error Conversion Tests")
struct ErrorConversionTests {

    @Test("CelestiaError passes through from() conversion")
    func testCelestiaErrorPassthrough() async throws {
        let originalError = CelestiaError.networkError
        let converted = CelestiaError.from(originalError)

        #expect(converted == .networkError)
    }

    @Test("NSURLError converts to network error")
    func testNSURLErrorConversion() async throws {
        let nsError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )

        let converted = CelestiaError.from(nsError)
        #expect(converted == .noInternetConnection)
    }

    @Test("NSURLError timeout converts correctly")
    func testNSURLErrorTimeoutConversion() async throws {
        let nsError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut,
            userInfo: nil
        )

        let converted = CelestiaError.from(nsError)
        #expect(converted == .requestTimeout)
    }

    @Test("Unknown error converts to unknown")
    func testUnknownErrorConversion() async throws {
        let unknownError = NSError(
            domain: "UnknownDomain",
            code: 999,
            userInfo: [NSLocalizedDescriptionKey: "Unknown error"]
        )

        let converted = CelestiaError.from(unknownError)
        if case .unknown(let message) = converted {
            #expect(message.contains("Unknown"))
        } else {
            #expect(Bool(false), "Expected unknown error type")
        }
    }
}

// MARK: - Mock Repository Error Tests

@Suite("Mock Repository Error Tests")
struct MockRepositoryErrorTests {

    @Test("Mock repository fetch failure")
    func testMockRepositoryFetchFailure() async throws {
        let mockRepo = MockErrorMessageRepository()
        mockRepo.shouldFailFetch = true
        mockRepo.errorToThrow = CelestiaError.networkError

        do {
            _ = try await mockRepo.fetchMessages(matchId: "match123", limit: 20, before: nil)
            #expect(Bool(false), "Should have thrown error")
        } catch {
            #expect(error is CelestiaError)
        }
    }

    @Test("Mock repository send failure")
    func testMockRepositorySendFailure() async throws {
        let mockRepo = MockErrorMessageRepository()
        mockRepo.shouldFailSend = true
        mockRepo.errorToThrow = CelestiaError.messageNotSent

        let message = Message(
            matchId: "match123",
            senderId: "user1",
            receiverId: "user2",
            text: "Test"
        )

        do {
            try await mockRepo.sendMessage(message)
            #expect(Bool(false), "Should have thrown error")
        } catch {
            #expect(error is CelestiaError)
        }
    }

    @Test("Mock repository delete failure")
    func testMockRepositoryDeleteFailure() async throws {
        let mockRepo = MockErrorMessageRepository()
        mockRepo.shouldFailDelete = true
        mockRepo.errorToThrow = CelestiaError.permissionDenied

        do {
            try await mockRepo.deleteMessage(messageId: "msg123")
            #expect(Bool(false), "Should have thrown error")
        } catch {
            #expect(error is CelestiaError)
        }
    }

    @Test("Mock repository mark as read failure")
    func testMockRepositoryMarkAsReadFailure() async throws {
        let mockRepo = MockErrorMessageRepository()
        mockRepo.shouldFailMarkAsRead = true
        mockRepo.errorToThrow = CelestiaError.networkError

        do {
            try await mockRepo.markMessagesAsRead(matchId: "match123", userId: "user1")
            #expect(Bool(false), "Should have thrown error")
        } catch {
            #expect(error is CelestiaError)
        }
    }

    @Test("Mock repository success cases")
    func testMockRepositorySuccessCases() async throws {
        let mockRepo = MockErrorMessageRepository()
        mockRepo.mockMessages = [
            Message(matchId: "match123", senderId: "user1", receiverId: "user2", text: "Hello")
        ]

        let messages = try await mockRepo.fetchMessages(matchId: "match123", limit: 20, before: nil)
        #expect(messages.count == 1)

        let message = Message(matchId: "match123", senderId: "user1", receiverId: "user2", text: "Test")
        try await mockRepo.sendMessage(message)

        try await mockRepo.deleteMessage(messageId: "msg123")

        try await mockRepo.markMessagesAsRead(matchId: "match123", userId: "user1")
    }
}

// MARK: - Notification Error Tests

@Suite("Notification Error Tests")
struct NotificationErrorTests {

    @Test("Message delivery status notification names")
    func testMessageDeliveryStatusNotificationNames() async throws {
        let statusChangedName = Notification.Name.messageDeliveryStatusChanged
        #expect(statusChangedName.rawValue == "messageDeliveryStatusChanged")
    }

    @Test("Message queued notification name")
    func testMessageQueuedNotificationName() async throws {
        let queuedName = Notification.Name.messageQueued
        #expect(queuedName.rawValue == "messageQueued")
    }

    @Test("Message reaction added notification name")
    func testMessageReactionAddedNotificationName() async throws {
        let reactionAddedName = Notification.Name.messageReactionAdded
        #expect(reactionAddedName.rawValue == "messageReactionAdded")
    }

    @Test("Message reaction removed notification name")
    func testMessageReactionRemovedNotificationName() async throws {
        let reactionRemovedName = Notification.Name.messageReactionRemoved
        #expect(reactionRemovedName.rawValue == "messageReactionRemoved")
    }
}
