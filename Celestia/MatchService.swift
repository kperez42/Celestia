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

                Task { [weak self] @MainActor in
                    guard let self = self else { return }

                    if let error = error {
                        Logger.shared.error("Error listening to matches: \(error)", category: .general)
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
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    /// Create a new match between two users
    func createMatch(user1Id: String, user2Id: String) async {
        // Check if match already exists
        if let existingMatch = try? await fetchMatch(user1Id: user1Id, user2Id: user2Id) {
            Logger.shared.info("Match already exists: \(existingMatch.id ?? "unknown")", category: .general)
            return
        }

        let match = Match(user1Id: user1Id, user2Id: user2Id)

        do {
            let docRef = try db.collection("matches").addDocument(from: match)
            Logger.shared.info("Match created: \(docRef.documentID)", category: .general)

            // Update match counts for both users
            try await updateMatchCounts(user1Id: user1Id, user2Id: user2Id)

            // PERFORMANCE OPTIMIZATION: Prefetch user names into cache for future use
            try? await UserDisplayNameCache.shared.prefetchUserNames(userIds: [user1Id, user2Id])

            // PERFORMANCE FIX: Batch fetch both users in a single query (prevents N+1 problem)
            let usersSnapshot = try? await db.collection("users")
                .whereField(FieldPath.documentID(), in: [user1Id, user2Id])
                .getDocuments()

            // Create a dictionary for quick lookup
            var userDataMap: [String: [String: Any]] = [:]
            usersSnapshot?.documents.forEach { doc in
                userDataMap[doc.documentID] = doc.data()
            }

            // Get user data from the map
            if let user1Data = userDataMap[user1Id],
               let user2Data = userDataMap[user2Id],
               let user1Name = user1Data["fullName"] as? String,
               let user2Name = user2Data["fullName"] as? String {

                // Create match object with ID for notifications
                var matchWithId = match
                matchWithId.id = docRef.documentID

                // Send notifications to both users
                let notificationService = NotificationService.shared

                // Create temporary user objects for notifications using factory method
                do {
                    let user1 = try User.createMinimal(id: user1Id, fullName: user1Name, from: user1Data)
                    let user2 = try User.createMinimal(id: user2Id, fullName: user2Name, from: user2Data)

                    await notificationService.sendNewMatchNotification(match: matchWithId, otherUser: user2)
                    await notificationService.sendNewMatchNotification(match: matchWithId, otherUser: user1)
                } catch {
                    Logger.shared.error("Failed to create user objects for match notification: \(error.localizedDescription)", category: .matching)
                    return
                }
            }
        } catch {
            Logger.shared.error("Error creating match: \(error)", category: .general)
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

        Logger.shared.info("Unmatched successfully", category: .general)
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
