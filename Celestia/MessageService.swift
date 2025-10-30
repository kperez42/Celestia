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
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "MessageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Message text cannot be empty"])
        }
        
        guard text.count <= 1000 else {
            throw NSError(domain: "MessageService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Message is too long"])
        }
        
        let message = Message(
            matchId: matchId,
            senderId: senderId,
            receiverId: receiverId,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        do {
            // Add message to Firestore
            _ = try db.collection("messages").addDocument(from: message)
            
            // Update match with last message info
            try await db.collection("matches").document(matchId).updateData([
                "lastMessage": text.trimmingCharacters(in: .whitespacesAndNewlines),
                "lastMessageTimestamp": FieldValue.serverTimestamp(),
                "unreadCount.\(receiverId)": FieldValue.increment(Int64(1))
            ])
            
            print("✅ Message sent successfully")
        } catch {
            print("❌ Error sending message: \(error)")
            self.error = error
            throw error
        }
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
        
        do {
            _ = try db.collection("messages").addDocument(from: message)
            
            try await db.collection("matches").document(matchId).updateData([
                "lastMessage": "📷 Photo",
                "lastMessageTimestamp": FieldValue.serverTimestamp(),
                "unreadCount.\(receiverId)": FieldValue.increment(Int64(1))
            ])
        } catch {
            self.error = error
            throw error
        }
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
