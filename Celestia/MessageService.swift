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

    // MARK: - Input Sanitization

    /// Sanitize user input to prevent injection attacks and malformed data
    private func sanitizeInput(_ text: String) -> String {
        var sanitized = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove potentially dangerous HTML/script tags
        let dangerousPatterns = [
            "<script>", "</script>",
            "<iframe>", "</iframe>",
            "javascript:",
            "onerror=", "onclick=", "onload="
        ]

        for pattern in dangerousPatterns {
            sanitized = sanitized.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
        }

        // Remove null bytes and control characters
        sanitized = sanitized.components(separatedBy: .controlCharacters).joined()
        sanitized = sanitized.replacingOccurrences(of: "\0", with: "")

        return sanitized
    }

    /// Listen to messages in real-time for a specific match
    func listenToMessages(matchId: String) {
        listener?.remove()
        
        listener = db.collection("messages")
            .whereField("matchId", isEqualTo: matchId)
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error listening to messages: \(error)")
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

        // Sanitize and validate input
        let sanitizedText = sanitizeInput(text)

        guard !sanitizedText.isEmpty else {
            throw CelestiaError.messageNotSent
        }

        guard sanitizedText.count <= AppConstants.Limits.maxMessageLength else {
            throw CelestiaError.messageTooLong
        }

        // Content moderation
        guard ContentModerator.shared.isAppropriate(sanitizedText) else {
            let violations = ContentModerator.shared.getViolations(sanitizedText)
            throw CelestiaError.inappropriateContentWithReasons(violations)
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

        print("✅ Message sent successfully")
    }
    
    /// Send an image message
    func sendImageMessage(
        matchId: String,
        senderId: String,
        receiverId: String,
        imageURL: String
    ) async throws {
        let message = Message(
            matchId: matchId,
            senderId: senderId,
            receiverId: receiverId,
            text: "📷 Photo",
            imageURL: imageURL
        )

        _ = try db.collection("messages").addDocument(from: message)

        try await db.collection("matches").document(matchId).updateData([
            "lastMessage": "📷 Photo",
            "lastMessageTimestamp": FieldValue.serverTimestamp(),
            "unreadCount.\(receiverId)": FieldValue.increment(Int64(1))
        ])
    }
    
    /// Mark messages as read
    func markMessagesAsRead(matchId: String, userId: String) async {
        do {
            let snapshot = try await db.collection("messages")
                .whereField("matchId", isEqualTo: matchId)
                .whereField("receiverId", isEqualTo: userId)
                .whereField("isRead", isEqualTo: false)
                .getDocuments()
            
            guard !snapshot.documents.isEmpty else { return }
            
            // Batch update
            let batch = db.batch()
            for doc in snapshot.documents {
                batch.updateData(["isRead": true, "isDelivered": true], forDocument: doc.reference)
            }
            try await batch.commit()
            
            // Reset unread count in match
            try await db.collection("matches").document(matchId).updateData([
                "unreadCount.\(userId)": 0
            ])
            
            print("✅ Messages marked as read")
        } catch {
            print("❌ Error marking messages as read: \(error)")
        }
    }
    
    /// Mark messages as delivered
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
            print("❌ Error marking messages as delivered: \(error)")
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
            print("Error getting unread count: \(error)")
            return 0
        }
    }
    
    /// Delete all messages in a match
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
    
    deinit {
        listener?.remove()
    }
}
