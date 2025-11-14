//
//  FirestoreMessageRepository.swift
//  Celestia
//
//  Concrete implementation of MessageRepository using Firestore
//  Separates data access logic from business logic
//

import Foundation
import FirebaseFirestore

class FirestoreMessageRepository: MessageRepository {
    private let db = Firestore.firestore()

    // MARK: - MessageRepository Protocol Implementation

    func fetchMessages(matchId: String, limit: Int, before: Date?) async throws -> [Message] {
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

    func sendMessage(_ message: Message) async throws {
        _ = try db.collection("messages").addDocument(from: message)
        Logger.shared.info("Message sent successfully", category: .messaging)
    }

    func markMessagesAsRead(matchId: String, userId: String) async throws {
        let snapshot = try await db.collection("messages")
            .whereField("matchId", isEqualTo: matchId)
            .whereField("receiverId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .getDocuments()

        guard !snapshot.documents.isEmpty else { return }

        // Use BatchOperationManager for robust execution
        try await BatchOperationManager.shared.markMessagesAsRead(
            matchId: matchId,
            userId: userId,
            messageDocuments: snapshot.documents
        )

        Logger.shared.info("Messages marked as read successfully", category: .messaging)
    }

    func deleteMessage(messageId: String) async throws {
        try await db.collection("messages").document(messageId).delete()
    }

    // MARK: - Additional Helper Methods

    func loadInitialMessages(matchId: String, limit: Int) async throws -> [Message] {
        let snapshot = try await db.collection("messages")
            .whereField("matchId", isEqualTo: matchId)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: Message.self) }
    }

    func loadOlderMessages(matchId: String, beforeTimestamp: Date, limit: Int) async throws -> [Message] {
        let snapshot = try await db.collection("messages")
            .whereField("matchId", isEqualTo: matchId)
            .whereField("timestamp", isLessThan: Timestamp(date: beforeTimestamp))
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: Message.self) }
    }

    func getUnreadCount(matchId: String, userId: String) async throws -> Int {
        let snapshot = try await db.collection("messages")
            .whereField("matchId", isEqualTo: matchId)
            .whereField("receiverId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .getDocuments()

        return snapshot.documents.count
    }

    func deleteAllMessages(matchId: String) async throws {
        let snapshot = try await db.collection("messages")
            .whereField("matchId", isEqualTo: matchId)
            .getDocuments()

        guard !snapshot.documents.isEmpty else { return }

        // Use BatchOperationManager for robust execution
        try await BatchOperationManager.shared.deleteMessages(
            matchId: matchId,
            messageDocuments: snapshot.documents
        )

        Logger.shared.info("All messages deleted successfully for match: \(matchId)", category: .messaging)
    }
}
