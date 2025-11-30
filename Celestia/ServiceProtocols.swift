//
//  ServiceProtocols.swift
//  Celestia
//
//  Protocol definitions for all services to enable dependency injection and testing
//  These protocols make the codebase testable by allowing mock implementations
//

import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore

// MARK: - Auth Service Protocol

@MainActor
protocol AuthServiceProtocol: ObservableObject {
    var userSession: FirebaseAuth.User? { get set }
    var currentUser: User? { get set }
    var isLoading: Bool { get set }
    var errorMessage: String? { get set }
    var isEmailVerified: Bool { get set }
    var isInitialized: Bool { get set }

    func signIn(withEmail email: String, password: String) async throws
    func createUser(withEmail email: String, password: String, fullName: String, age: Int, gender: String, lookingFor: String, location: String, country: String, referralCode: String, photos: [UIImage]) async throws
    func signOut()
    func fetchUser() async
    func updateUser(_ user: User) async throws
    func deleteAccount() async throws
    func resetPassword(email: String) async throws
    func sendEmailVerification() async throws
    func reloadUser() async throws
    func waitForInitialization() async
}

// MARK: - User Service Protocol

@MainActor
protocol UserServiceProtocol: ObservableObject {
    var users: [User] { get set }
    var isLoading: Bool { get set }
    var error: Error? { get set }
    var hasMoreUsers: Bool { get set }

    func fetchUser(userId: String) async throws -> User?
    func fetchUsers(excludingUserId: String, lookingFor: String?, ageRange: ClosedRange<Int>?, country: String?, limit: Int, reset: Bool) async throws
    func updateUser(_ user: User) async throws
    func updateUserFields(userId: String, fields: [String: Any]) async throws
    func incrementProfileViews(userId: String) async throws
    func updateLastActive(userId: String) async
    func searchUsers(query: String, currentUserId: String, limit: Int, offset: DocumentSnapshot?) async throws -> [User]
    func clearCache() async
    func checkDailyLikeLimit(userId: String) async -> Bool
    func decrementDailyLikes(userId: String) async
    func decrementSuperLikes(userId: String) async
}

// MARK: - Match Service Protocol

@MainActor
protocol MatchServiceProtocol: ObservableObject {
    var matches: [Match] { get set }
    var isLoading: Bool { get set }
    var error: Error? { get set }

    func fetchMatches(userId: String) async throws
    func listenToMatches(userId: String)
    func stopListening()
    func createMatch(user1Id: String, user2Id: String) async
    func fetchMatch(user1Id: String, user2Id: String) async throws -> Match?
    func updateMatchLastMessage(matchId: String, message: String, timestamp: Date) async throws
    func incrementUnreadCount(matchId: String, userId: String) async throws
    func resetUnreadCount(matchId: String, userId: String) async throws
    func unmatch(matchId: String, userId: String) async throws
    func hasMatched(user1Id: String, user2Id: String) async throws -> Bool
    func getTotalUnreadCount(userId: String) async throws -> Int
}

// MARK: - Message Service Protocol

@MainActor
protocol MessageServiceProtocol: ObservableObject {
    var messages: [Message] { get set }
    var isLoading: Bool { get set }
    var error: Error? { get set }

    func listenToMessages(matchId: String)
    func stopListening()
    func sendMessage(matchId: String, senderId: String, receiverId: String, text: String) async throws
    func sendImageMessage(matchId: String, senderId: String, receiverId: String, imageURL: String, caption: String?) async throws
    func markMessagesAsRead(matchId: String, userId: String) async
    func fetchMessages(matchId: String, limit: Int, before: Date?) async throws -> [Message]
    func deleteMessage(messageId: String) async throws
}

// MARK: - Swipe Service Protocol

@MainActor
protocol SwipeServiceProtocol {
    func likeUser(fromUserId: String, toUserId: String, isSuperLike: Bool) async throws -> Bool
    func passUser(fromUserId: String, toUserId: String) async throws
    func hasSwipedOn(fromUserId: String, toUserId: String) async throws -> (liked: Bool, passed: Bool)
    func getLikesReceived(userId: String) async throws -> [String]
    func getLikesSent(userId: String) async throws -> [String]
}

// MARK: - Network Manager Protocol

protocol NetworkManagerProtocol {
    func isConnected() -> Bool
    func startMonitoring()
    func stopMonitoring()
    func performRequest<T: Decodable>(_ request: NetworkRequest, retryCount: Int) async throws -> T
}

// MARK: - Content Moderator Protocol

protocol ContentModeratorProtocol {
    func isAppropriate(_ text: String) -> Bool
    func containsProfanity(_ text: String) -> Bool
    func filterProfanity(_ text: String) -> String
    func containsSpam(_ text: String) -> Bool
    func containsPersonalInfo(_ text: String) -> Bool
    func contentScore(_ text: String) -> Int
    func getViolations(_ text: String) -> [String]
}

// MARK: - Image Upload Service Protocol

protocol ImageUploadServiceProtocol {
    func uploadProfileImage(image: Data, userId: String) async throws -> String
    func uploadChatImage(image: Data, matchId: String) async throws -> String
    func deleteImage(url: String) async throws
}

// MARK: - Notification Service Protocol

@MainActor
protocol NotificationServiceProtocol {
    func requestPermission() async -> Bool
    func saveFCMToken(userId: String, token: String) async
    func sendNewMatchNotification(match: Match, otherUser: User) async
    func sendMessageNotification(message: Message, senderName: String, matchId: String) async
    func sendLikeNotification(likerName: String?, userId: String, isSuperLike: Bool) async
    func sendReferralSuccessNotification(userId: String, referredName: String) async
}
