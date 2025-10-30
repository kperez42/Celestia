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
            // Query where user is user1
            let snapshot1 = try await db.collection("matches")
                .whereField("user1Id", isEqualTo: userId)
                .whereField("isActive", isEqualTo: true)
                .getDocuments()
            
            // Query where user is user2
            let snapshot2 = try await db.collection("matches")
                .whereField("user2Id", isEqualTo: userId)
                .whereField("isActive", isEqualTo: true)
                .getDocuments()
            
            let matches1 = snapshot1.documents.compactMap { try? $0.data(as: Match.self) }
            let matches2 = snapshot2.documents.compactMap { try? $0.data(as: Match.self) }
            
            matches = (matches1 + matches2).sorted {
                ($0.lastMessageTimestamp ?? $0.timestamp) > ($1.lastMessageTimestamp ?? $1.timestamp)
            }
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// Listen to matches in real-time
    func listenToMatches(userId: String) {
        listener?.remove()
        
        // Create compound listener for both queries
        let dispatchGroup = DispatchGroup()
        var allMatches: [Match] = []
        
        dispatchGroup.enter()
        listener = db.collection("matches")
            .whereField("user1Id", isEqualTo: userId)
            .whereField("isActive", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let documents = snapshot?.documents {
                    let matches1 = documents.compactMap { try? $0.data(as: Match.self) }
                    allMatches.append(contentsOf: matches1)
                }
                dispatchGroup.leave()
            }
        
        dispatchGroup.enter()
        db.collection("matches")
            .whereField("user2Id", isEqualTo: userId)
            .whereField("isActive", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let documents = snapshot?.documents {
                    let matches2 = documents.compactMap { try? $0.data(as: Match.self) }
                    allMatches.append(contentsOf: matches2)
                }
                dispatchGroup.leave()
                
                dispatchGroup.notify(queue: .main) {
                    self?.matches = allMatches.sorted {
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
            print("Match already exists: \(existingMatch.id ?? "unknown")")
            return
        }
        
        let match = Match(user1Id: user1Id, user2Id: user2Id)
        
        do {
            let docRef = try db.collection("matches").addDocument(from: match)
            print("✅ Match created: \(docRef.documentID)")
            
            // Update match counts for both users
            try await updateMatchCounts(user1Id: user1Id, user2Id: user2Id)
        } catch {
            print("❌ Error creating match: \(error)")
            self.error = error
        }
    }
    
    /// Fetch a specific match between two users
    func fetchMatch(user1Id: String, user2Id: String) async throws -> Match? {
        // Try user1Id -> user2Id
        let snapshot1 = try await db.collection("matches")
            .whereField("user1Id", isEqualTo: user1Id)
            .whereField("user2Id", isEqualTo: user2Id)
            .whereField("isActive", isEqualTo: true)
            .limit(to: 1)
            .getDocuments()
        
        if let match = snapshot1.documents.first.flatMap({ try? $0.data(as: Match.self) }) {
            return match
        }
        
        // Try user2Id -> user1Id
        let snapshot2 = try await db.collection("matches")
            .whereField("user1Id", isEqualTo: user2Id)
            .whereField("user2Id", isEqualTo: user1Id)
            .whereField("isActive", isEqualTo: true)
            .limit(to: 1)
            .getDocuments()
        
        return snapshot2.documents.first.flatMap { try? $0.data(as: Match.self) }
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
    
    /// Deactivate a match (soft delete)
    func deactivateMatch(matchId: String) async throws {
        try await db.collection("matches").document(matchId).updateData([
            "isActive": false
        ])
    }
    
    /// Delete a match permanently
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
