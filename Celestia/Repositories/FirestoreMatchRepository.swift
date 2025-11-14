//
//  FirestoreMatchRepository.swift
//  Celestia
//
//  Concrete implementation of MatchRepository using Firestore
//  Separates data access logic from business logic
//

import Foundation
import FirebaseFirestore

class FirestoreMatchRepository: MatchRepository {
    private let db = Firestore.firestore()

    // MARK: - MatchRepository Protocol Implementation

    func fetchMatches(userId: String) async throws -> [Match] {
        // Use OR filter for optimized single query
        let snapshot = try await db.collection("matches")
            .whereFilter(Filter.orFilter([
                Filter.whereField("user1Id", isEqualTo: userId),
                Filter.whereField("user2Id", isEqualTo: userId)
            ]))
            .whereField("isActive", isEqualTo: true)
            .getDocuments()

        return snapshot.documents
            .compactMap { try? $0.data(as: Match.self) }
            .sorted { ($0.lastMessageTimestamp ?? $0.timestamp) > ($1.lastMessageTimestamp ?? $1.timestamp) }
    }

    func fetchMatch(user1Id: String, user2Id: String) async throws -> Match? {
        // Use OR filter for optimized single query
        let snapshot = try await db.collection("matches")
            .whereFilter(Filter.orFilter([
                Filter.andFilter([
                    Filter.whereField("user1Id", isEqualTo: user1Id),
                    Filter.whereField("user2Id", isEqualTo: user2Id)
                ]),
                Filter.andFilter([
                    Filter.whereField("user1Id", isEqualTo: user2Id),
                    Filter.whereField("user2Id", isEqualTo: user1Id)
                ])
            ]))
            .whereField("isActive", isEqualTo: true)
            .limit(to: 1)
            .getDocuments()

        return snapshot.documents.first.flatMap { try? $0.data(as: Match.self) }
    }

    func createMatch(match: Match) async throws -> String {
        let docRef = try db.collection("matches").addDocument(from: match)
        Logger.shared.info("Match created: \(docRef.documentID)", category: .matching)
        return docRef.documentID
    }

    func updateMatchLastMessage(matchId: String, message: String, timestamp: Date) async throws {
        try await db.collection("matches").document(matchId).updateData([
            "lastMessage": message,
            "lastMessageTimestamp": timestamp
        ])
    }

    func deactivateMatch(matchId: String) async throws {
        try await db.collection("matches").document(matchId).updateData([
            "isActive": false
        ])
    }

    // MARK: - Additional Helper Methods

    func incrementUnreadCount(matchId: String, userId: String) async throws {
        try await db.collection("matches").document(matchId).updateData([
            "unreadCount.\(userId)": FieldValue.increment(Int64(1))
        ])
    }

    func resetUnreadCount(matchId: String, userId: String) async throws {
        try await db.collection("matches").document(matchId).updateData([
            "unreadCount.\(userId)": 0
        ])
    }

    func unmatch(matchId: String, userId: String) async throws {
        try await db.collection("matches").document(matchId).updateData([
            "isActive": false,
            "unmatchedBy": userId,
            "unmatchedAt": FieldValue.serverTimestamp()
        ])
    }

    func updateMatchCounts(user1Id: String, user2Id: String) async throws {
        try await db.collection("users").document(user1Id).updateData([
            "matchCount": FieldValue.increment(Int64(1))
        ])

        try await db.collection("users").document(user2Id).updateData([
            "matchCount": FieldValue.increment(Int64(1))
        ])
    }
}
