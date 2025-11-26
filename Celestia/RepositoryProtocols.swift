//
//  RepositoryProtocols.swift
//  Celestia
//
//  Repository pattern interfaces for data access layer
//  Separates business logic from data access concerns
//

import Foundation
import FirebaseFirestore

// MARK: - User Repository Protocol

protocol UserRepository {
    func fetchUser(id: String) async throws -> User?
    func updateUser(_ user: User) async throws
    func updateUserFields(userId: String, fields: [String: Any]) async throws
    func searchUsers(query: String, currentUserId: String, limit: Int, offset: DocumentSnapshot?) async throws -> [User]
    func incrementProfileViews(userId: String) async
    func updateLastActive(userId: String) async

    // Consumables and boosts
    func updateDailySwiperUsage(userId: String) async throws
    func updateRewindUsage(userId: String) async throws
    func updateBoostUsage(userId: String) async throws
    func updateSuperLikeUsage(userId: String) async throws
    func getDailySwiperCount(userId: String) async throws -> Int
}

// MARK: - Match Repository Protocol

protocol MatchRepository {
    func fetchMatches(userId: String) async throws -> [Match]
    func fetchMatch(user1Id: String, user2Id: String) async throws -> Match?
    func createMatch(match: Match) async throws -> String
    func updateMatchLastMessage(matchId: String, message: String, timestamp: Date) async throws
    func deactivateMatch(matchId: String) async throws
    func deleteMatch(matchId: String) async throws
}

// MARK: - Message Repository Protocol

protocol MessageRepository {
    func fetchMessages(matchId: String, limit: Int, before: Date?) async throws -> [Message]
    func sendMessage(_ message: Message) async throws
    func markMessagesAsRead(matchId: String, userId: String) async throws
    func deleteMessage(messageId: String) async throws
}

// MARK: - Swipe Repository Protocol

protocol SwipeRepository {
    func createLike(fromUserId: String, toUserId: String, isSuperLike: Bool) async throws
    func createPass(fromUserId: String, toUserId: String) async throws
    func checkMutualLike(fromUserId: String, toUserId: String) async throws -> Bool
    func hasSwipedOn(fromUserId: String, toUserId: String) async throws -> (liked: Bool, passed: Bool)
    /// Check if a specific like exists
    func checkLikeExists(fromUserId: String, toUserId: String) async throws -> Bool
    /// Remove a like (unlike)
    func unlikeUser(fromUserId: String, toUserId: String) async throws
    /// Get likes received with optional limit for pagination (default 500)
    func getLikesReceived(userId: String, limit: Int) async throws -> [String]
    /// Get likes sent with optional limit for pagination (default 500)
    func getLikesSent(userId: String, limit: Int) async throws -> [String]
    func deleteSwipe(fromUserId: String, toUserId: String) async throws
}

// Default implementation for optional limit parameters
extension SwipeRepository {
    func getLikesReceived(userId: String) async throws -> [String] {
        try await getLikesReceived(userId: userId, limit: 500)
    }

    func getLikesSent(userId: String) async throws -> [String] {
        try await getLikesSent(userId: userId, limit: 500)
    }
}

// MARK: - Interest Repository Protocol

protocol InterestRepository {
    func fetchInterest(fromUserId: String, toUserId: String) async throws -> Interest?
    func sendInterest(_ interest: Interest) async throws
    func acceptInterest(interestId: String) async throws
    func rejectInterest(interestId: String) async throws
}

// MARK: - Firestore Implementations (Optional - for future refactoring)

/*
 Example implementation:

 class FirestoreUserRepository: UserRepository {
     private let db = Firestore.firestore()

     func fetchUser(id: String) async throws -> User? {
         let doc = try await db.collection("users").document(id).getDocument()
         return try? doc.data(as: User.self)
     }

     // ... other methods
 }

 Usage in services:

 class UserService: ObservableObject {
     private let repository: UserRepository

     init(repository: UserRepository = FirestoreUserRepository()) {
         self.repository = repository
     }
 }
*/
