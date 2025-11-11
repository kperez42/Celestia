//
//  MatchService.swift
//  Celestia
//
//  Service for match-related operations
//

import Foundation
import Firebase
import FirebaseFirestore

@MainActor
class MatchService: ObservableObject {
    @Published var matches: [Match] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    static let shared = MatchService()
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    private init() {}
    
    /// Fetch all matches for a user
    func fetchMatches(userId: String) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            // Use OR filter for optimized single query
            let snapshot = try await db.collection("matches")
                .whereFilter(Filter.orFilter([
                    Filter.whereField("user1Id", isEqualTo: userId),
                    Filter.whereField("user2Id", isEqualTo: userId)
                ]))
                .whereField("isActive", isEqualTo: true)
                .getDocuments()

            matches = snapshot.documents
                .compactMap { try? $0.data(as: Match.self) }
                .sorted { ($0.lastMessageTimestamp ?? $0.timestamp) > ($1.lastMessageTimestamp ?? $1.timestamp) }
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// Listen to matches in real-time
    func listenToMatches(userId: String) {
        listener?.remove()

        // Use OR filter for optimized single listener (fixes race condition)
        listener = db.collection("matches")
            .whereFilter(Filter.orFilter([
                Filter.whereField("user1Id", isEqualTo: userId),
                Filter.whereField("user2Id", isEqualTo: userId)
            ]))
            .whereField("isActive", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                Task { @MainActor in
                    if let error = error {
                        print("❌ Error listening to matches: \(error)")
                        return
                    }

                    guard let documents = snapshot?.documents else { return }

                    let allMatches = documents.compactMap { try? $0.data(as: Match.self) }
                    self.matches = allMatches.sorted {
                        ($0.lastMessageTimestamp ?? $0.timestamp) > ($1.lastMessageTimestamp ?? $1.timestamp)
                    }
                }
            }
    }
    
    /// Stop listening to matches
    nonisolated func stopListening() {
        Task { @MainActor in
            listener?.remove()
            listener = nil
        }
    }
    
    /// Create a new match between two users
    func createMatch(user1Id: String, user2Id: String) async {
        // Check if match already exists
        if let existingMatch = try? await fetchMatch(user1Id: user1Id, user2Id: user2Id) {
            print("Match already exists: \(existingMatch.id ?? "unknown")")
            return
        }

        let match = Match(user1Id: user1Id, user2Id: user2Id)

        do {
            let docRef = try db.collection("matches").addDocument(from: match)
            print("✅ Match created: \(docRef.documentID)")

            // Update match counts for both users
            try await updateMatchCounts(user1Id: user1Id, user2Id: user2Id)

            // Fetch user data for notifications
            let user1Snapshot = try? await db.collection("users").document(user1Id).getDocument()
            let user2Snapshot = try? await db.collection("users").document(user2Id).getDocument()

            if let user1Data = user1Snapshot?.data(),
               let user2Data = user2Snapshot?.data(),
               let user1Name = user1Data["fullName"] as? String,
               let user2Name = user2Data["fullName"] as? String {

                // Create match object with ID for notifications
                var matchWithId = match
                matchWithId.id = docRef.documentID

                // Send notifications to both users
                let notificationService = NotificationService.shared

                // Create temporary user objects for notifications
                let user1 = User(id: user1Id, email: user1Data["email"] as? String ?? "", fullName: user1Name, age: user1Data["age"] as? Int ?? 0, gender: user1Data["gender"] as? String ?? "", lookingFor: user1Data["lookingFor"] as? String ?? "", location: user1Data["location"] as? String ?? "", country: user1Data["country"] as? String ?? "")
                let user2 = User(id: user2Id, email: user2Data["email"] as? String ?? "", fullName: user2Name, age: user2Data["age"] as? Int ?? 0, gender: user2Data["gender"] as? String ?? "", lookingFor: user2Data["lookingFor"] as? String ?? "", location: user2Data["location"] as? String ?? "", country: user2Data["country"] as? String ?? "")

                await notificationService.sendNewMatchNotification(match: matchWithId, otherUser: user2)
                await notificationService.sendNewMatchNotification(match: matchWithId, otherUser: user1)
            }
        } catch {
            print("❌ Error creating match: \(error)")
            self.error = error
        }
    }
    
    /// Fetch a specific match between two users
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
    
    /// Update match with last message info
    func updateMatchLastMessage(matchId: String, message: String, timestamp: Date) async throws {
        try await db.collection("matches").document(matchId).updateData([
            "lastMessage": message,
            "lastMessageTimestamp": timestamp
        ])
    }
    
    /// Increment unread count for a user
    func incrementUnreadCount(matchId: String, userId: String) async throws {
        try await db.collection("matches").document(matchId).updateData([
            "unreadCount.\(userId)": FieldValue.increment(Int64(1))
        ])
    }
    
    /// Reset unread count for a user
    func resetUnreadCount(matchId: String, userId: String) async throws {
        try await db.collection("matches").document(matchId).updateData([
            "unreadCount.\(userId)": 0
        ])
    }
    
    /// Unmatch - Deactivate match and clean up related data
    func unmatch(matchId: String, userId: String) async throws {
        // Deactivate the match
        try await db.collection("matches").document(matchId).updateData([
            "isActive": false,
            "unmatchedBy": userId,
            "unmatchedAt": FieldValue.serverTimestamp()
        ])

        // Optionally delete all messages (for privacy)
        // Uncomment if you want to delete messages on unmatch
        // try await MessageService.shared.deleteAllMessages(matchId: matchId)

        print("✅ Unmatched successfully")
    }

    /// Deactivate a match (soft delete)
    func deactivateMatch(matchId: String) async throws {
        try await db.collection("matches").document(matchId).updateData([
            "isActive": false
        ])
    }

    /// Delete a match permanently (use with caution)
    func deleteMatch(matchId: String) async throws {
        try await db.collection("matches").document(matchId).delete()
    }
    
    /// Get total unread messages count for user
    func getTotalUnreadCount(userId: String) async throws -> Int {
        try await fetchMatches(userId: userId)
        
        return matches.reduce(0) { total, match in
            total + (match.unreadCount[userId] ?? 0)
        }
    }
    
    /// Check if two users have matched
    func hasMatched(user1Id: String, user2Id: String) async throws -> Bool {
        let match = try await fetchMatch(user1Id: user1Id, user2Id: user2Id)
        return match != nil
    }
    
    /// Update match counts for both users
    private func updateMatchCounts(user1Id: String, user2Id: String) async throws {
        try await db.collection("users").document(user1Id).updateData([
            "matchCount": FieldValue.increment(Int64(1))
        ])
        
        try await db.collection("users").document(user2Id).updateData([
            "matchCount": FieldValue.increment(Int64(1))
        ])
    }
    
    deinit {
        listener?.remove()
    }
}
