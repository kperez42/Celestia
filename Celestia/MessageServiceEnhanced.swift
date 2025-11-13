//
//  MessageServiceEnhanced.swift
//  Celestia
//
//  Enhanced message service with optimistic UI updates and offline support
//  Replaces MessageService.swift with improved offline capabilities
//

import Foundation
import Firebase
import FirebaseFirestore

@MainActor
class MessageServiceEnhanced: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var optimisticMessages: [OptimisticMessage] = []

    static let shared = MessageServiceEnhanced()
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    // Dependencies
    private let networkMonitor = NetworkMonitor.shared
    private let queueManager = MessageQueueManager.shared

    private init() {}

    /// Listen to messages in real-time for a specific match
    func listenToMessages(matchId: String) {
        listener?.remove()

        listener = db.collection("messages")
            .whereField("matchId", isEqualTo: matchId)
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    Logger.shared.error("Error listening to messages", category: .messaging, error: error)
                    Task { @MainActor in
                        self.error = error
                    }
                    return
                }

                guard let documents = snapshot?.documents else { return }

                Task { @MainActor in
                    let firebaseMessages = documents.compactMap { try? $0.data(as: Message.self) }

                    // Merge Firebase messages with optimistic messages
                    self.mergeMessages(firebaseMessages: firebaseMessages)

                    // Remove confirmed optimistic messages
                    self.removeConfirmedOptimisticMessages(firebaseMessages: firebaseMessages)
                }
            }
    }

    /// Stop listening to messages
    func stopListening() {
        listener?.remove()
        listener = nil
        messages = []
        optimisticMessages = []
    }

    /// Send a text message with optimistic UI update
    func sendMessage(
        matchId: String,
        senderId: String,
        receiverId: String,
        text: String
    ) async throws {
        // Check rate limiting
        guard RateLimiter.shared.canSendMessage() else {
            if let timeRemaining = RateLimiter.shared.timeUntilReset(for: .message) {
                throw CelestiaError.rateLimitExceededWithTime(timeRemaining)
            }
            throw CelestiaError.rateLimitExceeded
        }

        // Sanitize and validate input
        let sanitizedText = InputSanitizer.standard(text)

        guard !sanitizedText.isEmpty else {
            throw CelestiaError.messageNotSent
        }

        guard sanitizedText.count <= AppConstants.Limits.maxMessageLength else {
            throw CelestiaError.messageTooLong
        }

        // Content moderation (client-side quick check)
        guard ContentModerator.shared.isAppropriate(sanitizedText) else {
            let violations = ContentModerator.shared.getViolations(sanitizedText)
            throw CelestiaError.inappropriateContentWithReasons(violations)
        }

        // Create optimistic message for immediate UI update
        let optimisticId = UUID().uuidString
        let optimisticMessage = OptimisticMessage(
            id: optimisticId,
            matchId: matchId,
            senderId: senderId,
            receiverId: receiverId,
            text: sanitizedText,
            timestamp: Date(),
            status: .sending
        )

        // Add optimistic message to UI immediately
        optimisticMessages.append(optimisticMessage)
        updateMergedMessages()

        // If offline, queue the message
        if !networkMonitor.isConnected {
            queueManager.queueMessage(
                matchId: matchId,
                senderId: senderId,
                receiverId: receiverId,
                text: sanitizedText
            )

            // Update optimistic message status
            if let index = optimisticMessages.firstIndex(where: { $0.id == optimisticId }) {
                optimisticMessages[index].status = .queued
            }

            Logger.shared.info("Message queued (offline)", category: .messaging)
            return
        }

        // Try to send the message
        do {
            let message = Message(
                matchId: matchId,
                senderId: senderId,
                receiverId: receiverId,
                text: sanitizedText
            )

            // Add message to Firestore
            let docRef = try db.collection("messages").addDocument(from: message)

            // Update optimistic message with real ID
            if let index = optimisticMessages.firstIndex(where: { $0.id == optimisticId }) {
                optimisticMessages[index].firebaseId = docRef.documentID
                optimisticMessages[index].status = .sent
            }

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

        } catch {
            // Update optimistic message to failed
            if let index = optimisticMessages.firstIndex(where: { $0.id == optimisticId }) {
                optimisticMessages[index].status = .failed
                optimisticMessages[index].error = error.localizedDescription
            }

            // Queue for retry
            queueManager.queueMessage(
                matchId: matchId,
                senderId: senderId,
                receiverId: receiverId,
                text: sanitizedText
            )

            Logger.shared.error("Message send failed, queued for retry", category: .messaging, error: error)
            throw error
        }
    }

    /// Send an image message with optimistic UI update
    func sendImageMessage(
        matchId: String,
        senderId: String,
        receiverId: String,
        imageURL: String,
        caption: String? = nil
    ) async throws {
        let messageText = (caption != nil && !caption!.isEmpty) ? caption! : "📷 Photo"
        let lastMessageText = (caption != nil && !caption!.isEmpty) ? "📷 \(caption!)" : "📷 Photo"

        // Create optimistic message
        let optimisticId = UUID().uuidString
        let optimisticMessage = OptimisticMessage(
            id: optimisticId,
            matchId: matchId,
            senderId: senderId,
            receiverId: receiverId,
            text: messageText,
            imageURL: imageURL,
            timestamp: Date(),
            status: .sending
        )

        // Add optimistic message to UI immediately
        optimisticMessages.append(optimisticMessage)
        updateMergedMessages()

        // If offline, queue the message
        if !networkMonitor.isConnected {
            queueManager.queueMessage(
                matchId: matchId,
                senderId: senderId,
                receiverId: receiverId,
                text: messageText,
                imageURL: imageURL
            )

            if let index = optimisticMessages.firstIndex(where: { $0.id == optimisticId }) {
                optimisticMessages[index].status = .queued
            }

            return
        }

        // Try to send
        do {
            let message = Message(
                matchId: matchId,
                senderId: senderId,
                receiverId: receiverId,
                text: messageText,
                imageURL: imageURL
            )

            let docRef = try db.collection("messages").addDocument(from: message)

            if let index = optimisticMessages.firstIndex(where: { $0.id == optimisticId }) {
                optimisticMessages[index].firebaseId = docRef.documentID
                optimisticMessages[index].status = .sent
            }

            try await db.collection("matches").document(matchId).updateData([
                "lastMessage": lastMessageText,
                "lastMessageTimestamp": FieldValue.serverTimestamp(),
                "unreadCount.\(receiverId)": FieldValue.increment(Int64(1))
            ])

        } catch {
            if let index = optimisticMessages.firstIndex(where: { $0.id == optimisticId }) {
                optimisticMessages[index].status = .failed
                optimisticMessages[index].error = error.localizedDescription
            }

            queueManager.queueMessage(
                matchId: matchId,
                senderId: senderId,
                receiverId: receiverId,
                text: messageText,
                imageURL: imageURL
            )

            throw error
        }
    }

    /// Retry a failed optimistic message
    func retryMessage(optimisticId: String) async {
        guard let optimistic = optimisticMessages.first(where: { $0.id == optimisticId }) else {
            return
        }

        do {
            try await sendMessage(
                matchId: optimistic.matchId,
                senderId: optimistic.senderId,
                receiverId: optimistic.receiverId,
                text: optimistic.text
            )

            // Remove the old optimistic message
            optimisticMessages.removeAll { $0.id == optimisticId }

        } catch {
            Logger.shared.error("Retry failed", category: .messaging, error: error)
        }
    }

    /// Delete an optimistic message
    func deleteOptimisticMessage(id: String) {
        optimisticMessages.removeAll { $0.id == id }
        updateMergedMessages()
    }

    // MARK: - Existing Methods (from original MessageService)

    func markMessagesAsRead(matchId: String, userId: String) async {
        do {
            let snapshot = try await db.collection("messages")
                .whereField("matchId", isEqualTo: matchId)
                .whereField("receiverId", isEqualTo: userId)
                .whereField("isRead", isEqualTo: false)
                .getDocuments()

            guard !snapshot.documents.isEmpty else { return }

            let batch = db.batch()
            for doc in snapshot.documents {
                batch.updateData(["isRead": true, "isDelivered": true], forDocument: doc.reference)
            }
            try await batch.commit()

            try await db.collection("matches").document(matchId).updateData([
                "unreadCount.\(userId)": 0
            ])

            Logger.shared.info("Messages marked as read", category: .messaging)
        } catch {
            Logger.shared.error("Error marking messages as read", category: .messaging, error: error)
        }
    }

    func markMessagesAsDelivered(matchId: String, userId: String) async {
        do {
            let snapshot = try await db.collection("messages")
                .whereField("matchId", isEqualTo: matchId)
                .whereField("receiverId", isEqualTo: userId)
                .whereField("isDelivered", isEqualTo: false)
                .getDocuments()

            guard !snapshot.documents.isEmpty else { return }

            let batch = db.batch()
            for doc in snapshot.documents {
                batch.updateData(["isDelivered": true], forDocument: doc.reference)
            }
            try await batch.commit()
        } catch {
            Logger.shared.error("Error marking messages as delivered", category: .messaging, error: error)
        }
    }

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

    func deleteMessage(messageId: String) async throws {
        try await db.collection("messages").document(messageId).delete()
    }

    func getUnreadCount(matchId: String, userId: String) async throws -> Int {
        let snapshot = try await db.collection("messages")
            .whereField("matchId", isEqualTo: matchId)
            .whereField("receiverId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .getDocuments()

        return snapshot.documents.count
    }

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

    func deleteAllMessages(matchId: String) async throws {
        let snapshot = try await db.collection("messages")
            .whereField("matchId", isEqualTo: matchId)
            .getDocuments()

        let batch = db.batch()
        for doc in snapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()
    }

    // MARK: - Private Helpers

    private func mergeMessages(firebaseMessages: [Message]) {
        // Combine Firebase messages with optimistic messages
        var allMessages = firebaseMessages

        // Add optimistic messages that haven't been confirmed yet
        for optimistic in optimisticMessages where optimistic.status != .sent {
            let message = optimistic.toMessage()
            allMessages.append(message)
        }

        // Sort by timestamp
        messages = allMessages.sorted { $0.timestamp < $1.timestamp }
    }

    private func updateMergedMessages() {
        mergeMessages(firebaseMessages: messages.filter { $0.id?.isEmpty == false })
    }

    private func removeConfirmedOptimisticMessages(firebaseMessages: [Message]) {
        // Remove optimistic messages that have been confirmed in Firebase
        let firebaseIds = Set(firebaseMessages.compactMap { $0.id })

        optimisticMessages.removeAll { optimistic in
            if let firebaseId = optimistic.firebaseId, firebaseIds.contains(firebaseId) {
                return true
            }
            return false
        }
    }

    deinit {
        listener?.remove()
    }
}

// MARK: - Optimistic Message Model

struct OptimisticMessage: Identifiable {
    let id: String
    let matchId: String
    let senderId: String
    let receiverId: String
    let text: String
    var imageURL: String?
    let timestamp: Date
    var status: MessageStatus
    var firebaseId: String?
    var error: String?

    enum MessageStatus {
        case sending
        case sent
        case failed
        case queued
    }

    func toMessage() -> Message {
        Message(
            id: firebaseId,
            matchId: matchId,
            senderId: senderId,
            receiverId: receiverId,
            text: text,
            imageURL: imageURL,
            timestamp: timestamp,
            isRead: false,
            isDelivered: status == .sent
        )
    }
}
