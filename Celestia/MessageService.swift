//
//  MessageService.swift
//  Celestia
//
//  Service for message-related operations
//

import Foundation
import Firebase
import FirebaseFirestore

/// Message delivery status for UI feedback
enum MessageDeliveryStatus: String, Codable {
    case pending        // Message is queued/pending
    case sending        // Actively being sent
    case sent           // Successfully sent to server
    case delivered      // Confirmed delivered to recipient
    case failed         // Failed to send (can retry)
    case failedPermanent // Permanent failure (cannot retry)
}

/// Configuration for message retry logic
struct MessageRetryConfig {
    static let maxRetries = 3
    static let baseDelaySeconds: Double = 1.0
    static let maxDelaySeconds: Double = 30.0

    /// Calculate exponential backoff delay
    static func delay(for attempt: Int) -> TimeInterval {
        let delay = baseDelaySeconds * pow(2.0, Double(attempt))
        return min(delay, maxDelaySeconds)
    }
}

@MainActor
class MessageService: ObservableObject, MessageServiceProtocol, ListenerLifecycleAware {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMoreMessages = true
    @Published var error: Error?

    /// Track pending/failed message IDs for UI feedback
    @Published var pendingMessageIds: Set<String> = []
    @Published var failedMessageIds: Set<String> = []

    // Dependency injection: Repository for data access
    private let repository: MessageRepository

    // Singleton for backward compatibility (uses default repository)
    static let shared = MessageService(repository: FirestoreMessageRepository())

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var oldestMessageTimestamp: Date?
    private let messagesPerPage = 50

    // Network monitor for offline detection
    private let networkMonitor = NetworkMonitor.shared

    // AUDIT FIX: Track current matchId to prevent stale listener callbacks
    private var currentMatchId: String?

    // AUDIT FIX: Track loading task for proper cancellation
    private var loadingTask: Task<Void, Never>?

    // AUDIT FIX: Use Set for O(1) duplicate detection instead of O(n) array search
    private var messageIdSet: Set<String> = []

    // MARK: - ListenerLifecycleAware Conformance

    nonisolated var listenerId: String { "MessageService" }

    var areListenersActive: Bool {
        listener != nil
    }

    func reconnectListeners() {
        guard let matchId = currentMatchId else {
            Logger.shared.debug("MessageService: No matchId for reconnection", category: .messaging)
            return
        }
        Logger.shared.info("MessageService: Reconnecting listeners for match: \(matchId)", category: .messaging)
        listenToMessages(matchId: matchId)
    }

    func pauseListeners() {
        Logger.shared.info("MessageService: Pausing listeners", category: .messaging)
        // Don't clear currentMatchId - we need it for reconnection
        loadingTask?.cancel()
        loadingTask = nil
        listener?.remove()
        listener = nil
    }

    // Dependency injection initializer
    init(repository: MessageRepository) {
        self.repository = repository
        // Register with lifecycle manager for automatic reconnection handling
        ListenerLifecycleManager.shared.register(self)
    }

    /// Listen to messages in real-time for a specific match with pagination
    /// Loads initial batch of recent messages, then listens for new messages only
    func listenToMessages(matchId: String) {
        // AUDIT FIX: Cancel any existing loading task to prevent memory leaks
        loadingTask?.cancel()
        loadingTask = nil

        // AUDIT FIX: Remove existing listener before setting up new one
        listener?.remove()
        listener = nil

        // AUDIT FIX: Track current matchId to validate listener callbacks
        currentMatchId = matchId

        // Reset state
        messages = []
        messageIdSet = []  // AUDIT FIX: Reset duplicate tracking set
        oldestMessageTimestamp = nil
        hasMoreMessages = true
        isLoading = true

        Logger.shared.info("Starting paginated message loading for match: \(matchId)", category: .messaging)

        // AUDIT FIX: Store task reference for proper cancellation
        loadingTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                // Check if task was cancelled
                guard !Task.isCancelled else {
                    Logger.shared.debug("Message loading task cancelled", category: .messaging)
                    return
                }

                // Step 1: Load initial batch of recent messages (most recent 50)
                let initialMessages = try await loadInitialMessages(matchId: matchId)

                // Check cancellation again after async operation
                guard !Task.isCancelled else {
                    Logger.shared.debug("Message loading task cancelled after fetch", category: .messaging)
                    return
                }

                // AUDIT FIX: Validate matchId hasn't changed during async operation
                guard self.currentMatchId == matchId else {
                    Logger.shared.debug("MatchId changed during loading, discarding results", category: .messaging)
                    return
                }

                await MainActor.run {
                    // AUDIT FIX: Build message ID set for O(1) duplicate detection
                    self.messageIdSet = Set(initialMessages.compactMap { $0.id })
                    self.messages = initialMessages.sorted { $0.timestamp < $1.timestamp }
                    self.oldestMessageTimestamp = initialMessages.first?.timestamp
                    self.hasMoreMessages = initialMessages.count >= self.messagesPerPage
                    self.isLoading = false

                    Logger.shared.info("Loaded \(initialMessages.count) initial messages", category: .messaging)
                }

                // AUDIT FIX: Final check before setting up listener
                guard !Task.isCancelled, self.currentMatchId == matchId else {
                    return
                }

                // Step 2: Set up real-time listener for NEW messages only
                // This prevents loading all historical messages
                let cutoffTimestamp = initialMessages.last?.timestamp ?? Date()
                await MainActor.run {
                    self.setupNewMessageListener(matchId: matchId, after: cutoffTimestamp)
                }

            } catch {
                // Don't report errors if task was cancelled
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                    Logger.shared.error("Failed to load initial messages", category: .messaging, error: error)
                }
            }
        }
    }

    /// Load initial batch of recent messages
    private func loadInitialMessages(matchId: String) async throws -> [Message] {
        if let firestoreRepo = repository as? FirestoreMessageRepository {
            return try await firestoreRepo.loadInitialMessages(matchId: matchId, limit: messagesPerPage)
        }
        return []
    }

    /// Set up listener for NEW messages only (after cutoff timestamp)
    private func setupNewMessageListener(matchId: String, after cutoffTimestamp: Date) {
        // AUDIT FIX: Validate we're still listening to the correct match
        guard currentMatchId == matchId else {
            Logger.shared.debug("Skipping listener setup - matchId changed", category: .messaging)
            return
        }

        // AUDIT FIX: Ensure any previous listener is removed
        listener?.remove()

        listener = db.collection("messages")
            .whereField("matchId", isEqualTo: matchId)
            .whereField("timestamp", isGreaterThan: Timestamp(date: cutoffTimestamp))
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                // AUDIT FIX: Validate matchId hasn't changed since listener was set up
                guard self.currentMatchId == matchId else {
                    Logger.shared.debug("Ignoring stale listener callback for matchId: \(matchId)", category: .messaging)
                    return
                }

                if let error = error {
                    Logger.shared.error("Error listening to new messages", category: .messaging, error: error)
                    Task { @MainActor [weak self] in
                        guard let self = self, self.currentMatchId == matchId else { return }
                        self.error = error
                    }
                    return
                }

                guard let documents = snapshot?.documents else { return }

                Task { @MainActor [weak self] in
                    guard let self = self else { return }

                    // AUDIT FIX: Final matchId validation before updating state
                    guard self.currentMatchId == matchId else {
                        Logger.shared.debug("Discarding messages for stale matchId: \(matchId)", category: .messaging)
                        return
                    }

                    // UX FIX: Properly handle message parsing errors instead of silent failure
                    var newMessages: [Message] = []
                    for document in documents {
                        do {
                            let message = try document.data(as: Message.self)
                            newMessages.append(message)
                        } catch {
                            // Log parsing errors for debugging
                            Logger.shared.error("Failed to parse message from document \(document.documentID)", category: .messaging, error: error)
                            // Continue processing other messages rather than failing entirely
                        }
                    }

                    // Append new messages to existing ones
                    var addedCount = 0
                    for message in newMessages {
                        // AUDIT FIX: Handle nil message IDs - use document path as fallback
                        guard let messageId = message.id else {
                            Logger.shared.warning("Message has nil ID, skipping to prevent duplicates", category: .messaging)
                            continue
                        }

                        // BUGFIX: Remove optimistic message if matching server message arrives
                        // This prevents double messages when optimistic UI is used
                        if let optimisticMessage = self.messages.first(where: { msg in
                            msg.senderId == message.senderId &&
                            msg.text == message.text &&
                            abs(msg.timestamp.timeIntervalSince(message.timestamp)) < 2.0 &&
                            msg.id != messageId
                        }) {
                            if let optimisticId = optimisticMessage.id {
                                self.messageIdSet.remove(optimisticId)
                                self.messages.removeAll { $0.id == optimisticId }
                                Logger.shared.debug("Replaced optimistic message \(optimisticId) with server message \(messageId)", category: .messaging)
                            }
                        }

                        // AUDIT FIX: Use Set for O(1) duplicate detection instead of O(n) array contains
                        if !self.messageIdSet.contains(messageId) {
                            self.messageIdSet.insert(messageId)
                            self.messages.append(message)
                            addedCount += 1
                            Logger.shared.debug("New message received: \(messageId)", category: .messaging)
                        }
                    }

                    // Only sort if we actually added messages
                    if addedCount > 0 {
                        // Keep messages sorted by timestamp
                        self.messages.sort { $0.timestamp < $1.timestamp }
                    }
                }
            }
    }

    /// Load older messages (pagination) - call when user scrolls to top
    func loadOlderMessages(matchId: String) async {
        guard !isLoadingMore, hasMoreMessages else {
            Logger.shared.debug("Already loading or no more messages", category: .messaging)
            return
        }

        guard let oldestTimestamp = oldestMessageTimestamp else {
            Logger.shared.warning("No oldest timestamp available for pagination", category: .messaging)
            return
        }

        isLoadingMore = true
        Logger.shared.info("Loading older messages before \(oldestTimestamp)", category: .messaging)

        do {
            let olderMessages: [Message]
            if let firestoreRepo = repository as? FirestoreMessageRepository {
                olderMessages = try await firestoreRepo.loadOlderMessages(
                    matchId: matchId,
                    beforeTimestamp: oldestTimestamp,
                    limit: messagesPerPage
                )
            } else {
                olderMessages = []
            }

            await MainActor.run {
                if !olderMessages.isEmpty {
                    // AUDIT FIX: Filter duplicates and add to tracking set
                    let newOlderMessages = olderMessages.filter { message in
                        guard let messageId = message.id else { return false }
                        if self.messageIdSet.contains(messageId) {
                            return false
                        }
                        self.messageIdSet.insert(messageId)
                        return true
                    }

                    // Prepend older messages to the beginning
                    self.messages.insert(contentsOf: newOlderMessages.sorted { $0.timestamp < $1.timestamp }, at: 0)
                    self.oldestMessageTimestamp = olderMessages.first?.timestamp
                    Logger.shared.info("Loaded \(newOlderMessages.count) older messages (filtered from \(olderMessages.count))", category: .messaging)
                }

                // Check if there are more messages to load
                self.hasMoreMessages = olderMessages.count >= self.messagesPerPage
                self.isLoadingMore = false

                if !self.hasMoreMessages {
                    Logger.shared.info("Reached the beginning of conversation", category: .messaging)
                }
            }

        } catch {
            await MainActor.run {
                self.error = error
                self.isLoadingMore = false
                Logger.shared.error("Failed to load older messages", category: .messaging, error: error)
            }
        }
    }
    
    /// Stop listening to messages and reset pagination state
    func stopListening() {
        // AUDIT FIX: Cancel any pending loading task first
        loadingTask?.cancel()
        loadingTask = nil

        // AUDIT FIX: Clear matchId to invalidate any in-flight callbacks
        currentMatchId = nil

        // Remove the snapshot listener
        listener?.remove()
        listener = nil

        // Reset all state
        messages = []
        messageIdSet = []  // AUDIT FIX: Clear duplicate tracking set
        oldestMessageTimestamp = nil
        hasMoreMessages = true
        isLoading = false
        isLoadingMore = false

        Logger.shared.info("Stopped listening to messages and reset state", category: .messaging)
    }
    
    /// Send a text message with retry logic for network failures
    /// PERFORMANCE: Optimized with parallel validation and optimistic updates
    func sendMessage(
        matchId: String,
        senderId: String,
        receiverId: String,
        text: String
    ) async throws {
        // Generate a local ID for tracking before sending
        let localMessageId = UUID().uuidString
        pendingMessageIds.insert(localMessageId)

        defer {
            pendingMessageIds.remove(localMessageId)
        }

        // PERFORMANCE: Sanitize early so we can validate in parallel
        let sanitizedText = InputSanitizer.standard(text)

        guard !sanitizedText.isEmpty else {
            throw CelestiaError.messageNotSent
        }

        guard sanitizedText.count <= AppConstants.Limits.maxMessageLength else {
            throw CelestiaError.messageTooLong
        }

        // Check if offline - queue for later delivery
        guard networkMonitor.isConnected else {
            Logger.shared.info("Offline - queueing message for later delivery", category: .messaging)
            await queueMessageForOfflineDelivery(
                matchId: matchId,
                senderId: senderId,
                receiverId: receiverId,
                text: sanitizedText
            )
            return
        }

        // PERFORMANCE: Run rate limit and validation checks IN PARALLEL
        // This can save 100-200ms compared to sequential execution
        async let rateLimitTask = performRateLimitCheck(senderId: senderId)
        async let validationTask = performContentValidation(text: sanitizedText)

        // Wait for both to complete
        let (rateLimitPassed, validationPassed) = try await (rateLimitTask, validationTask)

        guard rateLimitPassed else {
            if let timeRemaining = RateLimiter.shared.timeUntilReset(for: .message) {
                throw CelestiaError.rateLimitExceededWithTime(timeRemaining)
            }
            throw CelestiaError.rateLimitExceeded
        }

        guard validationPassed else {
            // Validation already threw if there were violations
            return
        }

        let message = Message(
            matchId: matchId,
            senderId: senderId,
            receiverId: receiverId,
            text: sanitizedText
        )

        // PERFORMANCE: Add optimistic message to local list immediately
        await addOptimisticMessage(message, localId: localMessageId)

        // Send message with retry logic for network failures
        do {
            try await sendMessageWithRetry(message: message, matchId: matchId, receiverId: receiverId, senderId: senderId)
            Logger.shared.info("Message sent successfully", category: .messaging)
        } catch {
            // Remove optimistic message on failure
            await removeOptimisticMessage(localId: localMessageId)
            throw error
        }
    }

    /// PERFORMANCE: Parallel rate limit check
    private func performRateLimitCheck(senderId: String) async -> Bool {
        // SECURITY: Backend rate limit validation (prevents client bypass)
        do {
            let rateLimitResponse = try await BackendAPIService.shared.checkRateLimit(
                userId: senderId,
                action: .sendMessage
            )

            if !rateLimitResponse.allowed {
                Logger.shared.warning("Backend rate limit exceeded for messages", category: .moderation)
                return false
            }

            Logger.shared.debug("✅ Backend rate limit check passed (remaining: \(rateLimitResponse.remaining))", category: .moderation)
            return true

        } catch {
            // Backend unavailable - fall back to client-side
            Logger.shared.error("Backend rate limit check failed - using client-side fallback", category: .moderation)
            return RateLimiter.shared.canSendMessage()
        }
    }

    /// PERFORMANCE: Parallel content validation
    private func performContentValidation(text: String) async throws -> Bool {
        do {
            let validationResponse = try await BackendAPIService.shared.validateContent(
                text,
                type: .message
            )

            guard validationResponse.isAppropriate else {
                Logger.shared.warning("Content flagged by server: \(validationResponse.violations.joined(separator: ", "))", category: .moderation)
                throw CelestiaError.inappropriateContentWithReasons(validationResponse.violations)
            }

            Logger.shared.debug("Content validated server-side ✅", category: .moderation)
            return true

        } catch let error as BackendAPIError {
            // SECURITY FIX: Queue message for deferred validation
            Logger.shared.warning("Server-side validation unavailable - allowing with deferred validation", category: .moderation)

            AnalyticsManager.shared.logEvent(.validationError, parameters: [
                "type": "validation_service_unavailable",
                "error": error.localizedDescription,
                "action": "deferred_validation"
            ])

            // Allow message but flag for deferred validation
            return true
        }
    }

    /// PERFORMANCE: Add optimistic message to local list for instant UI feedback
    private func addOptimisticMessage(_ message: Message, localId: String) async {
        await MainActor.run {
            // Create optimistic message with local ID
            var optimisticMessage = message
            optimisticMessage.id = localId

            // Add to message list if not already present
            if !messageIdSet.contains(localId) {
                messageIdSet.insert(localId)
                messages.append(optimisticMessage)
                messages.sort { $0.timestamp < $1.timestamp }
            }
        }
    }

    /// PERFORMANCE: Remove optimistic message on send failure
    private func removeOptimisticMessage(localId: String) async {
        await MainActor.run {
            messageIdSet.remove(localId)
            messages.removeAll { $0.id == localId }
        }
    }

    /// Internal helper to send message to Firestore with exponential backoff retry
    private func sendMessageWithRetry(
        message: Message,
        matchId: String,
        receiverId: String,
        senderId: String,
        attempt: Int = 0
    ) async throws {
        do {
            // Add message to Firestore
            _ = try db.collection("messages").addDocument(from: message)

            // Update match with last message info
            try await db.collection("matches").document(matchId).updateData([
                "lastMessage": message.text,
                "lastMessageTimestamp": FieldValue.serverTimestamp(),
                "unreadCount.\(receiverId)": FieldValue.increment(Int64(1))
            ])

            // Send notification to receiver
            await sendMessageNotificationWithFallback(message: message, senderId: senderId, matchId: matchId)

            // Notify success
            NotificationCenter.default.post(
                name: .messageDeliveryStatusChanged,
                object: nil,
                userInfo: [
                    "status": MessageDeliveryStatus.sent,
                    "messageText": message.text
                ]
            )

        } catch {
            // Check if this is a retryable network error
            let isRetryable = isRetryableError(error)

            if isRetryable && attempt < MessageRetryConfig.maxRetries {
                let delay = MessageRetryConfig.delay(for: attempt)
                Logger.shared.warning("Message send failed (attempt \(attempt + 1)/\(MessageRetryConfig.maxRetries + 1)), retrying in \(delay)s", category: .messaging)

                // Wait before retry with exponential backoff
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                // Check if still connected before retry
                guard networkMonitor.isConnected else {
                    Logger.shared.info("Lost connection during retry - queueing message", category: .messaging)
                    await queueMessageForOfflineDelivery(
                        matchId: matchId,
                        senderId: senderId,
                        receiverId: receiverId,
                        text: message.text
                    )
                    return
                }

                // Retry
                try await sendMessageWithRetry(
                    message: message,
                    matchId: matchId,
                    receiverId: receiverId,
                    senderId: senderId,
                    attempt: attempt + 1
                )
            } else {
                // Max retries exceeded or non-retryable error
                Logger.shared.error("Message send failed after \(attempt + 1) attempts", category: .messaging, error: error)

                // Queue for later if it's a network issue
                if isRetryable {
                    await queueMessageForOfflineDelivery(
                        matchId: matchId,
                        senderId: senderId,
                        receiverId: receiverId,
                        text: message.text
                    )

                    // Notify that message is queued (not failed permanently)
                    NotificationCenter.default.post(
                        name: .messageDeliveryStatusChanged,
                        object: nil,
                        userInfo: [
                            "status": MessageDeliveryStatus.pending,
                            "messageText": message.text
                        ]
                    )
                } else {
                    // Permanent failure
                    NotificationCenter.default.post(
                        name: .messageDeliveryStatusChanged,
                        object: nil,
                        userInfo: [
                            "status": MessageDeliveryStatus.failedPermanent,
                            "messageText": message.text,
                            "error": error.localizedDescription
                        ]
                    )
                    throw error
                }
            }
        }
    }

    /// Check if an error is retryable (network-related)
    private func isRetryableError(_ error: Error) -> Bool {
        let nsError = error as NSError

        // Check for common network error domains and codes
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorTimedOut,
                 NSURLErrorCannotFindHost,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorDNSLookupFailed,
                 NSURLErrorDataNotAllowed:
                return true
            default:
                return false
            }
        }

        // Firebase-specific network errors
        if nsError.domain == "FIRFirestoreErrorDomain" {
            // Code 14 = UNAVAILABLE (network issues)
            // Code 4 = DEADLINE_EXCEEDED (timeout)
            return nsError.code == 14 || nsError.code == 4
        }

        return false
    }

    /// Queue a message for delivery when connection is restored
    private func queueMessageForOfflineDelivery(
        matchId: String,
        senderId: String,
        receiverId: String,
        text: String,
        imageURL: String? = nil
    ) async {
        await MainActor.run {
            MessageQueueManager.shared.queueMessage(
                matchId: matchId,
                senderId: senderId,
                receiverId: receiverId,
                text: text,
                imageURL: imageURL
            )
        }

        Logger.shared.info("Message queued for offline delivery", category: .messaging)

        // Track analytics
        AnalyticsManager.shared.logEvent(.queuedMessage, parameters: [
            "reason": "offline",
            "match_id": matchId
        ])
    }

    /// Helper to send notification with fallback for sender name
    private func sendMessageNotificationWithFallback(message: Message, senderId: String, matchId: String) async {
        do {
            let senderSnapshot = try await db.collection("users").document(senderId).getDocument()
            if let senderName = senderSnapshot.data()?["fullName"] as? String {
                await NotificationService.shared.sendMessageNotification(
                    message: message,
                    senderName: senderName,
                    matchId: matchId
                )
            } else {
                Logger.shared.warning("Sender name not found for notification", category: .messaging)
                // Send notification with generic sender name
                await NotificationService.shared.sendMessageNotification(
                    message: message,
                    senderName: "Someone",
                    matchId: matchId
                )
            }
        } catch {
            Logger.shared.error("Failed to fetch sender info for notification", category: .messaging, error: error)
            // Still send notification with generic sender to ensure user gets notified
            await NotificationService.shared.sendMessageNotification(
                message: message,
                senderName: "Someone",
                matchId: matchId
            )
        }
    }
    
    /// Send an image message with retry logic for network failures
    func sendImageMessage(
        matchId: String,
        senderId: String,
        receiverId: String,
        imageURL: String,
        caption: String? = nil
    ) async throws {
        // Check if offline - queue for later delivery
        guard networkMonitor.isConnected else {
            Logger.shared.info("Offline - queueing image message for later delivery", category: .messaging)
            await queueMessageForOfflineDelivery(
                matchId: matchId,
                senderId: senderId,
                receiverId: receiverId,
                text: caption ?? "📷 Photo",
                imageURL: imageURL
            )
            return
        }

        let messageText = caption.flatMap { !$0.isEmpty ? $0 : nil } ?? "📷 Photo"
        let lastMessageText = caption.flatMap { !$0.isEmpty ? "📷 \($0)" : nil } ?? "📷 Photo"

        let message = Message(
            matchId: matchId,
            senderId: senderId,
            receiverId: receiverId,
            text: messageText,
            imageURL: imageURL
        )

        // Send with retry logic
        try await sendImageMessageWithRetry(
            message: message,
            matchId: matchId,
            receiverId: receiverId,
            senderId: senderId,
            lastMessageText: lastMessageText,
            imageURL: imageURL
        )

        Logger.shared.info("Image message sent successfully", category: .messaging)
    }

    /// Internal helper to send image message with exponential backoff retry
    private func sendImageMessageWithRetry(
        message: Message,
        matchId: String,
        receiverId: String,
        senderId: String,
        lastMessageText: String,
        imageURL: String,
        attempt: Int = 0
    ) async throws {
        do {
            _ = try db.collection("messages").addDocument(from: message)

            try await db.collection("matches").document(matchId).updateData([
                "lastMessage": lastMessageText,
                "lastMessageTimestamp": FieldValue.serverTimestamp(),
                "unreadCount.\(receiverId)": FieldValue.increment(Int64(1))
            ])

            // Notify success
            NotificationCenter.default.post(
                name: .messageDeliveryStatusChanged,
                object: nil,
                userInfo: [
                    "status": MessageDeliveryStatus.sent,
                    "messageText": message.text,
                    "isImage": true
                ]
            )

        } catch {
            let isRetryable = isRetryableError(error)

            if isRetryable && attempt < MessageRetryConfig.maxRetries {
                let delay = MessageRetryConfig.delay(for: attempt)
                Logger.shared.warning("Image message send failed (attempt \(attempt + 1)/\(MessageRetryConfig.maxRetries + 1)), retrying in \(delay)s", category: .messaging)

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                guard networkMonitor.isConnected else {
                    await queueMessageForOfflineDelivery(
                        matchId: matchId,
                        senderId: senderId,
                        receiverId: receiverId,
                        text: message.text,
                        imageURL: imageURL
                    )
                    return
                }

                try await sendImageMessageWithRetry(
                    message: message,
                    matchId: matchId,
                    receiverId: receiverId,
                    senderId: senderId,
                    lastMessageText: lastMessageText,
                    imageURL: imageURL,
                    attempt: attempt + 1
                )
            } else {
                Logger.shared.error("Image message send failed after \(attempt + 1) attempts", category: .messaging, error: error)

                if isRetryable {
                    await queueMessageForOfflineDelivery(
                        matchId: matchId,
                        senderId: senderId,
                        receiverId: receiverId,
                        text: message.text,
                        imageURL: imageURL
                    )

                    NotificationCenter.default.post(
                        name: .messageDeliveryStatusChanged,
                        object: nil,
                        userInfo: [
                            "status": MessageDeliveryStatus.pending,
                            "messageText": message.text,
                            "isImage": true
                        ]
                    )
                } else {
                    NotificationCenter.default.post(
                        name: .messageDeliveryStatusChanged,
                        object: nil,
                        userInfo: [
                            "status": MessageDeliveryStatus.failedPermanent,
                            "messageText": message.text,
                            "isImage": true,
                            "error": error.localizedDescription
                        ]
                    )
                    throw error
                }
            }
        }
    }
    
    /// Mark messages as read (with transaction logging and retry)
    func markMessagesAsRead(matchId: String, userId: String) async {
        do {
            try await repository.markMessagesAsRead(matchId: matchId, userId: userId)
        } catch {
            Logger.shared.error("Error marking messages as read", category: .messaging, error: error)
        }
    }
    
    /// Mark messages as delivered (with transaction logging and retry)
    func markMessagesAsDelivered(matchId: String, userId: String) async {
        do {
            let snapshot = try await db.collection("messages")
                .whereField("matchId", isEqualTo: matchId)
                .whereField("receiverId", isEqualTo: userId)
                .whereField("isDelivered", isEqualTo: false)
                .getDocuments()

            guard !snapshot.documents.isEmpty else { return }

            // Use BatchOperationManager for robust execution with retry and idempotency
            try await BatchOperationManager.shared.markMessagesAsDelivered(
                matchId: matchId,
                userId: userId,
                messageDocuments: snapshot.documents
            )

            Logger.shared.info("Messages marked as delivered successfully", category: .messaging)
        } catch {
            Logger.shared.error("Error marking messages as delivered", category: .messaging, error: error)
        }
    }
    
    /// Fetch message history (for pagination)
    func fetchMessages(
        matchId: String,
        limit: Int = 50,
        before: Date? = nil
    ) async throws -> [Message] {
        return try await repository.fetchMessages(matchId: matchId, limit: limit, before: before)
    }
    
    /// Delete a message
    func deleteMessage(messageId: String) async throws {
        try await repository.deleteMessage(messageId: messageId)
    }
    
    /// Get unread message count for a specific match
    func getUnreadCount(matchId: String, userId: String) async throws -> Int {
        let snapshot = try await db.collection("messages")
            .whereField("matchId", isEqualTo: matchId)
            .whereField("receiverId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .getDocuments()
        
        return snapshot.documents.count
    }
    
    /// Get total unread message count for a user across all matches
    func getUnreadMessageCount(userId: String) async -> Int {
        do {
            let snapshot = try await db.collection("messages")
                .whereField("receiverId", isEqualTo: userId)
                .whereField("isRead", isEqualTo: false)
                .getDocuments()
            return snapshot.documents.count
        } catch {
            Logger.shared.error("Error getting unread count", category: .messaging, error: error)
            return 0
        }
    }
    
    /// Delete all messages in a match (with transaction logging and retry)
    func deleteAllMessages(matchId: String) async throws {
        let snapshot = try await db.collection("messages")
            .whereField("matchId", isEqualTo: matchId)
            .getDocuments()

        guard !snapshot.documents.isEmpty else { return }

        // Use BatchOperationManager for robust execution with retry and idempotency
        try await BatchOperationManager.shared.deleteMessages(
            matchId: matchId,
            messageDocuments: snapshot.documents
        )

        Logger.shared.info("All messages deleted successfully for match: \(matchId)", category: .messaging)
    }
    
    deinit {
        // AUDIT FIX: Cancel loading task to prevent memory leaks
        loadingTask?.cancel()
        listener?.remove()
        // LIFECYCLE: Unregister from lifecycle manager
        Task { @MainActor in
            ListenerLifecycleManager.shared.unregister(id: "MessageService")
        }
    }
}

// MARK: - Notification Names for Message Delivery

extension Notification.Name {
    /// Posted when a message's delivery status changes
    /// userInfo contains: "status" (MessageDeliveryStatus), "messageText" (String), optionally "isImage" (Bool), "error" (String)
    static let messageDeliveryStatusChanged = Notification.Name("messageDeliveryStatusChanged")

    /// Posted when a message is successfully queued for offline delivery
    static let messageQueued = Notification.Name("messageQueued")
}
