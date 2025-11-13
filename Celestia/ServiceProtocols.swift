//
//  ServiceProtocols.swift
//  Celestia
//
//  Protocol-based dependency injection for services
//  Reduces tight coupling and improves testability
//

import Foundation

// MARK: - Match Service Protocol

protocol MatchCreating {
    func createMatch(user1Id: String, user2Id: String) async
    func fetchMatch(user1Id: String, user2Id: String) async throws -> Match?
    func hasMatched(user1Id: String, user2Id: String) async throws -> Bool
}

// MARK: - Notification Service Protocol

protocol NotificationSending {
    func sendNewMatchNotification(match: Match, otherUser: User) async
    func sendMessageNotification(message: Message, senderName: String, matchId: String) async
    func sendLikeNotification(likerName: String?, userId: String, isSuperLike: Bool) async
}

// MARK: - Message Service Protocol

protocol MessageSending {
    func sendMessage(matchId: String, senderId: String, receiverId: String, text: String) async throws
    func sendImageMessage(matchId: String, senderId: String, receiverId: String, imageURL: String, caption: String?) async throws
}

// MARK: - User Service Protocol

protocol UserFetching {
    func fetchUser(userId: String) async throws -> User?
    func fetchUsers(excludingUserId: String, lookingFor: String?, ageRange: ClosedRange<Int>?, country: String?, limit: Int, reset: Bool) async throws
}

// MARK: - Default Implementations

extension MatchService: MatchCreating {}
// NotificationService conformance declared in NotificationService.swift
extension MessageService: MessageSending {}
extension UserService: UserFetching {}
