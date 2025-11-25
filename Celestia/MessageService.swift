//
//  MessageService.swift
//  Celestia
//
//  Service for message-related operations
//

import Foundation
import Firebase
import FirebaseFirestore

@MainActor
class MessageService: ObservableObject, MessageServiceProtocol {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMoreMessages = true
    @Published var error: Error?

    // Dependency injection: Repository for data access
    private let repository: MessageRepository

    // Singleton for backward compatibility (uses default repository)
    static let shared = MessageService(repository: FirestoreMessageRepository())

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var oldestMessageTimestamp: Date?
    private let messagesPerPage = 50

    // Dependency injection initializer
    init(repository: MessageRepository) {
        self.repository = repository
    }

    /// Listen to messages in real-time for a specific match with pagination
    /// Loads initial batch of recent messages, then listens for new messages only
    func listenToMessages(matchId: String) {
        listener?.remove()
        messages = []
        oldestMessageTimestamp = nil
        hasMoreMessages = true
        isLoading = true

        Logger.shared.info("Starting paginated message loading for match: \(matchId)", category: .messaging)

        Task {
            do {
                // Step 1: Load initial batch of recent messages (most recent 50)
                let initialMessages = try await loadInitialMessages(matchId: matchId)

                await MainActor.run {
                    self.messages = initialMessages.sorted { $0.timestamp < $1.timestamp }
                    self.oldestMessageTimestamp = initialMessages.first?.timestamp
                    self.hasMoreMessages = initialMessages.count >= messagesPerPage
                    self.isLoading = false

                    Logger.shared.info("Loaded \(initialMessages.count) initial messages", category: .messaging)
                }

                // Step 2: Set up real-time listener for NEW messages only
                // This prevents loading all historical messages
                let cutoffTimestamp = initialMessages.last?.timestamp ?? Date()
                setupNewMessageListener(matchId: matchId, after: cutoffTimestamp)

            } catch {
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
        listener = db.collection("messages")
            .whereField("matchId", isEqualTo: matchId)
            .whereField("timestamp", isGreaterThan: Timestamp(date: cutoffTimestamp))
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    Logger.shared.error("Error listening to new messages", category: .messaging, error: error)
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        self.error = error
                    }
                    return
                }

                guard let documents = snapshot?.documents else { return }

                Task { @MainActor [weak self] in
                    guard let self = self else { return }

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
                    for message in newMessages {
                        // Avoid duplicates
                        if !self.messages.contains(where: { $0.id == message.id }) {
                            self.messages.append(message)
                            Logger.shared.debug("New message received: \(message.id ?? "unknown")", category: .messaging)
                        }
                    }

                    // Keep messages sorted by timestamp
                    self.messages.sort { $0.timestamp < $1.timestamp }
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
                    // Prepend older messages to the beginning
                    self.messages.insert(contentsOf: olderMessages.sorted { $0.timestamp < $1.timestamp }, at: 0)
                    self.oldestMessageTimestamp = olderMessages.first?.timestamp
                    Logger.shared.info("Loaded \(olderMessages.count) older messages", category: .messaging)
                }

                // Check if there are more messages to load
                self.hasMoreMessages = olderMessages.count >= messagesPerPage
                self.isLoadingMore = false

                if !hasMoreMessages {
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
        listener?.remove()
        listener = nil
        messages = []
        oldestMessageTimestamp = nil
        hasMoreMessages = true
        isLoading = false
        isLoadingMore = false
        Logger.shared.info("Stopped listening to messages and reset state", category: .messaging)
    }
    
    /// Send a text message
    func sendMessage(
        matchId: String,
        senderId: String,
        receiverId: String,
        text: String
    ) async throws {
        // SECURITY: Backend rate limit validation (prevents client bypass)
        // This is called BEFORE client-side check to ensure server-side enforcement
        do {
            let rateLimitResponse = try await BackendAPIService.shared.checkRateLimit(
                userId: senderId,
                action: .sendMessage
            )

            if !rateLimitResponse.allowed {
                Logger.shared.warning("Backend rate limit exceeded for messages", category: .moderation)

                if let retryAfter = rateLimitResponse.retryAfter {
                    throw CelestiaError.rateLimitExceededWithTime(retryAfter)
                }

                throw CelestiaError.rateLimitExceeded
            }

            Logger.shared.debug("✅ Backend rate limit check passed (remaining: \(rateLimitResponse.remaining))", category: .moderation)

        } catch let error as BackendAPIError {
            // Backend rate limit service unavailable
            Logger.shared.error("Backend rate limit check failed - using client-side fallback", category: .moderation)

            // Fall back to client-side rate limiting
            guard RateLimiter.shared.canSendMessage() else {
                if let timeRemaining = RateLimiter.shared.timeUntilReset(for: .message) {
                    throw CelestiaError.rateLimitExceededWithTime(timeRemaining)
                }
                throw CelestiaError.rateLimitExceeded
            }
        }

        // Client-side rate limiting (additional layer of protection)
        guard RateLimiter.shared.canSendMessage() else {
            if let timeRemaining = RateLimiter.shared.timeUntilReset(for: .message) {
                throw CelestiaError.rateLimitExceededWithTime(timeRemaining)
            }
            throw CelestiaError.rateLimitExceeded
        }

        // Sanitize and validate input using centralized utility
        let sanitizedText = InputSanitizer.standard(text)

        guard !sanitizedText.isEmpty else {
            throw CelestiaError.messageNotSent
        }

        guard sanitizedText.count <= AppConstants.Limits.maxMessageLength else {
            throw CelestiaError.messageTooLong
        }

        // SECURITY: Server-side validation is mandatory - client-side can be bypassed
        do {
            // Server-side validation is required (client-side validation can be bypassed)
            let validationResponse = try await BackendAPIService.shared.validateContent(
                sanitizedText,
                type: .message
            )

            guard validationResponse.isAppropriate else {
                Logger.shared.warning("Content flagged by server: \(validationResponse.violations.joined(separator: ", "))", category: .moderation)
                throw CelestiaError.inappropriateContentWithReasons(validationResponse.violations)
            }

            Logger.shared.debug("Content validated server-side ✅", category: .moderation)

        } catch let error as BackendAPIError {
            // SECURITY FIX: Queue message for deferred validation instead of blocking
            // This prevents client-side bypass while maintaining good UX
            Logger.shared.warning("Server-side validation unavailable - queueing message for deferred validation", category: .moderation)

            // Log for monitoring and alerting
            AnalyticsManager.shared.logEvent(.validationError, parameters: [
                "type": "validation_service_unavailable",
                "error": error.localizedDescription,
                "action": "queued_for_validation"
            ])

            // Create pending message
            let pendingMessage = PendingMessage(
                matchId: matchId,
                senderId: senderId,
                receiverId: receiverId,
                text: text,
                sanitizedText: sanitizedText
            )

            // Add to queue for background processing
            PendingMessageQueue.shared.enqueue(pendingMessage)

            Logger.shared.info("Message queued for validation: \(pendingMessage.id)", category: .moderation)

            // Inform user that message is queued (don't throw error)
            // The UI should show the message as "pending" or "sending..."
            // It will be sent once validated, or rejected if inappropriate
            return

        } catch {
            // Re-throw other validation errors (content violations, etc.)
            throw error
        }

        let message = Message(
            matchId: matchId,
            senderId: senderId,
            receiverId: receiverId,
            text: sanitizedText
        )

        // Add message to Firestore
        _ = try db.collection("messages").addDocument(from: message)

        // Update match with last message info
        try await db.collection("matches").document(matchId).updateData([
            "lastMessage": sanitizedText,
            "lastMessageTimestamp": FieldValue.serverTimestamp(),
            "unreadCount.\(receiverId)": FieldValue.increment(Int64(1))
        ])

        // Send notification to receiver
        // UX FIX: Properly handle sender fetch errors instead of silent failure
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

        Logger.shared.info("Message sent successfully", category: .messaging)
    }
    
    /// Send an image message
    func sendImageMessage(
        matchId: String,
        senderId: String,
        receiverId: String,
        imageURL: String,
        caption: String? = nil
    ) async throws {
        let messageText = caption.flatMap { !$0.isEmpty ? $0 : nil } ?? "📷 Photo"
        let lastMessageText = caption.flatMap { !$0.isEmpty ? "📷 \($0)" : nil } ?? "📷 Photo"

        let message = Message(
            matchId: matchId,
            senderId: senderId,
            receiverId: receiverId,
            text: messageText,
            imageURL: imageURL
        )

        _ = try db.collection("messages").addDocument(from: message)

        try await db.collection("matches").document(matchId).updateData([
            "lastMessage": lastMessageText,
            "lastMessageTimestamp": FieldValue.serverTimestamp(),
            "unreadCount.\(receiverId)": FieldValue.increment(Int64(1))
        ])
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
        listener?.remove()
    }
}
