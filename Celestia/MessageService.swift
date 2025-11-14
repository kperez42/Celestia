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
class MessageService: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMoreMessages = true
    @Published var error: Error?

    static let shared = MessageService()
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var oldestMessageTimestamp: Date?
    private let messagesPerPage = 50

    // Performance optimization: Message prefetching
    private var prefetchedMessages: [Message] = []
    private var isPrefetching = false
    private let prefetchThreshold = 10 // Prefetch when user is 10 messages from top

    // Performance monitoring
    private var messageLoadStartTime: Date?
    private var totalMessagesLoaded = 0

    private init() {}

    /// Listen to messages in real-time for a specific match with pagination
    /// Loads initial batch of recent messages, then listens for new messages only
    func listenToMessages(matchId: String) {
        listener?.remove()
        messages = []
        prefetchedMessages = []
        oldestMessageTimestamp = nil
        hasMoreMessages = true
        isLoading = true
        totalMessagesLoaded = 0

        // Performance monitoring: Track load start time
        messageLoadStartTime = Date()

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
                    self.totalMessagesLoaded = initialMessages.count

                    // Performance monitoring: Log load time
                    if let startTime = self.messageLoadStartTime {
                        let loadTime = Date().timeIntervalSince(startTime)
                        Logger.shared.info("Loaded \(initialMessages.count) initial messages in \(String(format: "%.3f", loadTime))s", category: .messaging)

                        // Track performance metric
                        AnalyticsManager.shared.logEvent(.performanceMetric, parameters: [
                            "metric_type": "chat_initial_load",
                            "load_time_ms": Int(loadTime * 1000),
                            "message_count": initialMessages.count,
                            "match_id": matchId
                        ])
                    }

                    Logger.shared.info("Loaded \(initialMessages.count) initial messages", category: .messaging)
                }

                // Prefetch next batch for smooth scrolling
                if initialMessages.count >= messagesPerPage {
                    await prefetchOlderMessages(matchId: matchId)
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
        let snapshot = try await db.collection("messages")
            .whereField("matchId", isEqualTo: matchId)
            .order(by: "timestamp", descending: true)
            .limit(to: messagesPerPage)
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: Message.self) }
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
                    Task { @MainActor in
                        self.error = error
                    }
                    return
                }

                guard let documents = snapshot?.documents else { return }

                Task { @MainActor in
                    let newMessages = documents.compactMap { try? $0.data(as: Message.self) }

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
        let loadStartTime = Date()
        Logger.shared.info("Loading older messages before \(oldestTimestamp)", category: .messaging)

        // Check if we have prefetched messages available
        if !prefetchedMessages.isEmpty {
            Logger.shared.debug("Using prefetched messages for instant load", category: .messaging)

            await MainActor.run {
                // Use prefetched messages for instant load
                self.messages.insert(contentsOf: prefetchedMessages, at: 0)
                self.oldestMessageTimestamp = prefetchedMessages.first?.timestamp
                self.totalMessagesLoaded += prefetchedMessages.count

                let loadTime = Date().timeIntervalSince(loadStartTime)
                Logger.shared.info("Loaded \(prefetchedMessages.count) prefetched messages in \(String(format: "%.3f", loadTime))s", category: .messaging)

                self.prefetchedMessages = []
                self.isLoadingMore = false
            }

            // Prefetch next batch
            await prefetchOlderMessages(matchId: matchId)
            return
        }

        do {
            let snapshot = try await db.collection("messages")
                .whereField("matchId", isEqualTo: matchId)
                .whereField("timestamp", isLessThan: Timestamp(date: oldestTimestamp))
                .order(by: "timestamp", descending: true)
                .limit(to: messagesPerPage)
                .getDocuments()

            let olderMessages = snapshot.documents.compactMap { try? $0.data(as: Message.self) }

            await MainActor.run {
                if !olderMessages.isEmpty {
                    // Prepend older messages to the beginning
                    self.messages.insert(contentsOf: olderMessages.sorted { $0.timestamp < $1.timestamp }, at: 0)
                    self.oldestMessageTimestamp = olderMessages.first?.timestamp
                    self.totalMessagesLoaded += olderMessages.count

                    let loadTime = Date().timeIntervalSince(loadStartTime)
                    Logger.shared.info("Loaded \(olderMessages.count) older messages in \(String(format: "%.3f", loadTime))s", category: .messaging)

                    // Track performance metric
                    AnalyticsManager.shared.logEvent(.performanceMetric, parameters: [
                        "metric_type": "chat_pagination",
                        "load_time_ms": Int(loadTime * 1000),
                        "message_count": olderMessages.count,
                        "total_loaded": self.totalMessagesLoaded,
                        "match_id": matchId
                    ])
                }

                // Check if there are more messages to load
                self.hasMoreMessages = olderMessages.count >= messagesPerPage
                self.isLoadingMore = false

                if !hasMoreMessages {
                    Logger.shared.info("Reached the beginning of conversation", category: .messaging)
                }
            }

            // Prefetch next batch for smooth scrolling
            if olderMessages.count >= messagesPerPage {
                await prefetchOlderMessages(matchId: matchId)
            }

        } catch {
            await MainActor.run {
                self.error = error
                self.isLoadingMore = false
                Logger.shared.error("Failed to load older messages", category: .messaging, error: error)
            }
        }
    }

    /// Prefetch older messages in background for smooth scrolling
    private func prefetchOlderMessages(matchId: String) async {
        guard !isPrefetching, hasMoreMessages else { return }
        guard let oldestTimestamp = oldestMessageTimestamp else { return }

        isPrefetching = true
        Logger.shared.debug("Prefetching next batch of messages", category: .messaging)

        do {
            let snapshot = try await db.collection("messages")
                .whereField("matchId", isEqualTo: matchId)
                .whereField("timestamp", isLessThan: Timestamp(date: oldestTimestamp))
                .order(by: "timestamp", descending: true)
                .limit(to: messagesPerPage)
                .getDocuments()

            let nextBatch = snapshot.documents.compactMap { try? $0.data(as: Message.self) }
                .sorted { $0.timestamp < $1.timestamp }

            await MainActor.run {
                self.prefetchedMessages = nextBatch
                self.isPrefetching = false
                Logger.shared.debug("Prefetched \(nextBatch.count) messages", category: .messaging)
            }
        } catch {
            await MainActor.run {
                self.isPrefetching = false
                Logger.shared.debug("Failed to prefetch messages", category: .messaging)
            }
        }
    }
    
    /// Stop listening to messages and reset pagination state
    func stopListening() {
        listener?.remove()
        listener = nil
        messages = []
        prefetchedMessages = []
        oldestMessageTimestamp = nil
        hasMoreMessages = true
        isLoading = false
        isLoadingMore = false
        isPrefetching = false
        totalMessagesLoaded = 0
        messageLoadStartTime = nil
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
            // SECURITY FIX: Do NOT fallback to client-side validation (can be bypassed)
            // Block sending when backend is unavailable to prevent abuse
            Logger.shared.error("Server-side validation unavailable - blocking message send", category: .moderation)

            // Log for monitoring and alerting
            AnalyticsManager.shared.logEvent(.validationError, parameters: [
                "type": "validation_service_unavailable",
                "error": error.localizedDescription,
                "action": "blocked_message_send"
            ])

            // Return user-friendly error
            throw CelestiaError.serviceTemporarilyUnavailable

            // TODO: Future enhancement - implement message queue for delayed validation:
            // 1. Store message in local queue with "pending_validation" status
            // 2. Show user that message is queued for validation
            // 3. Background task periodically retries validation
            // 4. Send message once validated, or reject if inappropriate
            // This provides better UX while maintaining security
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
        let senderSnapshot = try? await db.collection("users").document(senderId).getDocument()
        if let senderName = senderSnapshot?.data()?["fullName"] as? String {
            await NotificationService.shared.sendMessageNotification(
                message: message,
                senderName: senderName,
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
            let snapshot = try await db.collection("messages")
                .whereField("matchId", isEqualTo: matchId)
                .whereField("receiverId", isEqualTo: userId)
                .whereField("isRead", isEqualTo: false)
                .getDocuments()

            guard !snapshot.documents.isEmpty else { return }

            // Use BatchOperationManager for robust execution with retry and idempotency
            try await BatchOperationManager.shared.markMessagesAsRead(
                matchId: matchId,
                userId: userId,
                messageDocuments: snapshot.documents
            )

            Logger.shared.info("Messages marked as read successfully", category: .messaging)
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
        var query = db.collection("messages")
            .whereField("matchId", isEqualTo: matchId)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
        
        if let beforeDate = before {
            query = query.whereField("timestamp", isLessThan: beforeDate)
        }
        
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Message.self) }.reversed()
    }
    
    /// Delete a message
    func deleteMessage(messageId: String) async throws {
        try await db.collection("messages").document(messageId).delete()
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
