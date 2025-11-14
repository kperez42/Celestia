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
    @Published var error: Error?
    
    static let shared = MessageService()
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
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
                    self.messages = documents.compactMap { try? $0.data(as: Message.self) }
                }
            }
    }
    
    /// Stop listening to messages
    func stopListening() {
        listener?.remove()
        listener = nil
        messages = []
    }
    
    /// Send a text message
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

        // Sanitize and validate input using centralized utility
        let sanitizedText = InputSanitizer.standard(text)

        guard !sanitizedText.isEmpty else {
            throw CelestiaError.messageNotSent
        }

        guard sanitizedText.count <= AppConstants.Limits.maxMessageLength else {
            throw CelestiaError.messageTooLong
        }

        // Content moderation - use server-side validation if available
        do {
            // Try server-side validation first (more secure)
            let validationResponse = try await BackendAPIService.shared.validateContent(
                sanitizedText,
                type: .message
            )

            guard validationResponse.isAppropriate else {
                Logger.shared.warning("Content flagged by server: \(validationResponse.violations.joined(separator: ", "))", category: .moderation)
                throw CelestiaError.inappropriateContentWithReasons(validationResponse.violations)
            }

            Logger.shared.debug("Content validated server-side ✅", category: .moderation)

        } catch is BackendAPIError {
            // Fallback to client-side validation if server unavailable
            Logger.shared.warning("Server-side validation unavailable, using client-side", category: .moderation)

            guard ContentModerator.shared.isAppropriate(sanitizedText) else {
                let violations = ContentModerator.shared.getViolations(sanitizedText)
                throw CelestiaError.inappropriateContentWithReasons(violations)
            }
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
