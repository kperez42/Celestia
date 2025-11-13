//
//  ServiceProtocolsComplete.swift
//  Celestia
//
//  Comprehensive protocol definitions for all services
//  Enables dependency injection and improves testability
//

import Foundation
import SwiftUI
import UIKit
import FirebaseAuth
import StoreKit

// MARK: - Auth Service Protocol

@MainActor
protocol AuthServiceProtocol: ObservableObject {
    var userSession: FirebaseAuth.User? { get }
    var currentUser: User? { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    var isEmailVerified: Bool { get }

    func signIn(withEmail email: String, password: String) async throws
    func createUser(withEmail email: String, password: String, fullName: String, age: Int, gender: String, lookingFor: String, location: String, country: String, referralCode: String) async throws
    func signOut()
    func fetchUser() async
    func updateUser(_ user: User) async throws
    func deleteAccount() async throws
    func resetPassword(email: String) async throws
    func sendEmailVerification() async throws
    func verifyEmail(withToken token: String) async throws
    func reloadUser() async throws
}

// MARK: - User Service Protocol

@MainActor
protocol UserServiceProtocol: ObservableObject {
    var users: [User] { get }
    var isLoading: Bool { get }
    var error: Error? { get }
    var hasMoreUsers: Bool { get }

    func fetchUser(userId: String) async throws -> User?
    func fetchUsers(excludingUserId: String, lookingFor: String?, ageRange: ClosedRange<Int>?, country: String?, limit: Int, reset: Bool) async throws
    func incrementProfileViews(userId: String) async
}

// MARK: - Match Service Protocol

@MainActor
protocol MatchServiceProtocol: ObservableObject {
    var matches: [Match] { get }
    var isLoading: Bool { get }
    var error: Error? { get }

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
    var messages: [Message] { get }
    var isLoading: Bool { get }
    var error: Error? { get }

    func fetchMessages(matchId: String, limit: Int, before: Date?) async throws -> [Message]
    func listenToMessages(matchId: String)
    func stopListening()
    func sendMessage(matchId: String, senderId: String, receiverId: String, text: String) async throws
    func sendImageMessage(matchId: String, senderId: String, receiverId: String, imageURL: String, caption: String?) async throws
    func deleteMessage(messageId: String) async throws
}

// MARK: - Swipe Service Protocol

@MainActor
protocol SwipeServiceProtocol {
    func likeUser(fromUserId: String, toUserId: String, isSuperLike: Bool) async throws -> Bool
    func passUser(fromUserId: String, toUserId: String) async throws
    func hasSwipedOn(fromUserId: String, toUserId: String) async throws -> (liked: Bool, passed: Bool)
    func getLikesReceived(userId: String) async throws -> [String]
}

// MARK: - Referral Manager Protocol

@MainActor
protocol ReferralManagerProtocol: ObservableObject {
    var userReferrals: [Referral] { get }
    var leaderboard: [ReferralLeaderboardEntry] { get }
    var isLoading: Bool { get }

    func generateReferralCode(for userId: String) async throws -> String
    func initializeReferralCode(for user: inout User) async throws
    func processReferralSignup(newUser: User, referralCode: String) async throws
    func awardPremiumDays(userId: String, days: Int, reason: String) async throws
    func fetchUserReferrals(userId: String) async throws
    func fetchLeaderboard(limit: Int) async throws
    func validateReferralCode(_ code: String) async -> Bool
    func getReferralStats(for user: User) async throws -> ReferralStats
    func getReferralShareMessage(code: String, userName: String) -> String
    func getReferralURL(code: String) -> URL?
}

// MARK: - Store Manager Protocol

@MainActor
protocol StoreManagerProtocol: ObservableObject {
    var products: [Product] { get }
    var subscriptionProducts: [Product] { get }
    var purchasedProductIDs: Set<String> { get }

    func loadProducts() async
    func purchase(_ product: Product) async throws -> PurchaseResult
    func restorePurchases() async throws
}

// MARK: - Notification Service Protocol

@MainActor
protocol NotificationServiceProtocol: ObservableObject {
    func requestPermission() async -> Bool
    func saveFCMToken(userId: String, token: String) async
    func sendNewMatchNotification(match: Match, otherUser: User) async
    func sendMessageNotification(message: Message, senderName: String, matchId: String) async
    func sendLikeNotification(likerName: String?, userId: String, isSuperLike: Bool) async
    func sendReferralSuccessNotification(userId: String, referredName: String) async
}

// MARK: - Image Upload Service Protocol

protocol ImageUploadServiceProtocol {
    func uploadProfileImage(_ image: UIImage, userId: String) async throws -> String
    func uploadChatImage(_ image: UIImage, matchId: String) async throws -> String
    func deleteImage(url: String) async throws
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

// MARK: - Analytics Manager Protocol

protocol AnalyticsManagerProtocol {
    func log(event: String, parameters: [String: Any])
    func setUserId(_ userId: String)
    func setUserProperty(_ value: String, forName: String)
    func logScreen(name: String, screenClass: String)
}

// MARK: - Block Report Service Protocol

@MainActor
protocol BlockReportServiceProtocol {
    func blockUser(userId: String, currentUserId: String) async throws
    func unblockUser(blockerId: String, blockedId: String) async throws
    func isUserBlocked(_ userId: String) -> Bool
    func getBlockedUsers() async throws -> [User]
    func reportUser(userId: String, currentUserId: String, reason: ReportReason, additionalDetails: String?) async throws
}

// MARK: - Network Manager Protocol

protocol NetworkManagerProtocol {
    func isConnected() -> Bool
    func startMonitoring()
    func stopMonitoring()
    func performRequest<T>(_ request: NetworkRequest, retryCount: Int) async throws -> T where T: Decodable
}

// MARK: - Default Implementations

// Conform existing services to protocols
extension AuthService: AuthServiceProtocol {}
extension UserService: UserServiceProtocol {}
extension MatchService: MatchServiceProtocol {}
extension MessageService: MessageServiceProtocol {}
extension SwipeService: SwipeServiceProtocol {}
extension ReferralManager: ReferralManagerProtocol {}
extension StoreManager: StoreManagerProtocol {}
// NotificationService conformance declared in NotificationService.swift
extension ImageUploadService: ImageUploadServiceProtocol {}
extension ContentModerator: ContentModeratorProtocol {}
// AnalyticsManager conformance declared in AnalyticsManager.swift
extension BlockReportService: BlockReportServiceProtocol {}
