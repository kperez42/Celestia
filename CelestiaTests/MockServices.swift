//
//  MockServices.swift
//  CelestiaTests
//
//  Mock implementations of service protocols for testing
//

import Foundation
import UIKit
@testable import Celestia

// MARK: - Mock Auth Service

@MainActor
class MockAuthService: AuthServiceProtocol {
    var userSession: FirebaseAuth.User?
    var currentUser: User?
    var isLoading: Bool = false
    var errorMessage: String?
    var isEmailVerified: Bool = false
    var isInitialized: Bool = true

    var signInCalled = false
    var signInEmail: String?
    var createUserCalled = false
    var signOutCalled = false
    var shouldFail = false
    var signInDelay: TimeInterval = 0

    func signIn(withEmail email: String, password: String) async throws {
        signInCalled = true
        signInEmail = email

        if signInDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(signInDelay * 1_000_000_000))
        }

        if shouldFail {
            throw CelestiaError.invalidCredentials
        }

        isEmailVerified = true
    }

    func createUser(withEmail email: String, password: String, fullName: String, age: Int, gender: String, lookingFor: String, location: String, country: String, referralCode: String = "", photos: [UIImage] = []) async throws {
        createUserCalled = true

        if shouldFail {
            throw CelestiaError.emailAlreadyExists
        }

        currentUser = User(
            id: "mock_user_id",
            email: email,
            fullName: fullName,
            age: age,
            gender: gender,
            lookingFor: lookingFor,
            location: location,
            country: country
        )
    }

    func signOut() {
        signOutCalled = true
        currentUser = nil
        userSession = nil
    }

    func fetchUser() async {}
    func updateUser(_ user: User) async throws {}
    func deleteAccount() async throws {}
    func resetPassword(email: String) async throws {}
    func sendEmailVerification() async throws {}
    func reloadUser() async throws {}
    func waitForInitialization() async {}
}

// MARK: - Mock User Service

@MainActor
class MockUserService: UserServiceProtocol {
    var users: [User] = []
    var isLoading: Bool = false
    var error: Error?
    var hasMoreUsers: Bool = true

    var fetchUserCalled = false
    var fetchUsersCalled = false
    var mockUser: User?

    func fetchUser(userId: String) async throws -> User? {
        fetchUserCalled = true
        return mockUser
    }

    func fetchUsers(excludingUserId: String, lookingFor: String?, ageRange: ClosedRange<Int>?, country: String?, limit: Int, reset: Bool) async throws {
        fetchUsersCalled = true
        // Return mock users
        users = [
            User(id: "1", email: "user1@test.com", fullName: "Test User 1", age: 25, gender: "Female", lookingFor: "Male", location: "New York", country: "USA"),
            User(id: "2", email: "user2@test.com", fullName: "Test User 2", age: 28, gender: "Male", lookingFor: "Female", location: "Los Angeles", country: "USA")
        ]
    }

    func updateUserLocation(userId: String, location: String, latitude: Double, longitude: Double) async throws {}
    func updateUserActivity(userId: String) async throws {}
    func incrementProfileViews(userId: String) async throws {}
}

// MARK: - Mock Match Service

@MainActor
class MockMatchService: MatchServiceProtocol {
    var matches: [Match] = []
    var isLoading: Bool = false
    var error: Error?

    var createMatchCalled = false
    var fetchMatchesCalled = false
    var hasMatchedCalled = false
    var shouldReturnMatch = false

    func fetchMatches(userId: String) async throws {
        fetchMatchesCalled = true
    }

    func listenToMatches(userId: String) {}
    func stopListening() {}

    func createMatch(user1Id: String, user2Id: String) async {
        createMatchCalled = true
    }

    func fetchMatch(user1Id: String, user2Id: String) async throws -> Match? {
        if shouldReturnMatch {
            return Match(user1Id: user1Id, user2Id: user2Id)
        }
        return nil
    }

    func updateMatchLastMessage(matchId: String, message: String, timestamp: Date) async throws {}
    func incrementUnreadCount(matchId: String, userId: String) async throws {}
    func resetUnreadCount(matchId: String, userId: String) async throws {}
    func unmatch(matchId: String, userId: String) async throws {}

    func hasMatched(user1Id: String, user2Id: String) async throws -> Bool {
        hasMatchedCalled = true
        return shouldReturnMatch
    }

    func getTotalUnreadCount(userId: String) async throws -> Int {
        return 0
    }
}

// MARK: - Mock Message Service

@MainActor
class MockMessageService: MessageServiceProtocol {
    var messages: [Message] = []
    var isLoading: Bool = false
    var error: Error?

    var sendMessageCalled = false
    var fetchMessagesCalled = false

    func fetchMessages(matchId: String) async throws {
        fetchMessagesCalled = true
    }

    func listenToMessages(matchId: String) {}
    func stopListening() {}

    func sendMessage(matchId: String, senderId: String, receiverId: String, text: String) async throws {
        sendMessageCalled = true
    }

    func sendImageMessage(matchId: String, senderId: String, receiverId: String, imageURL: String) async throws {}
    func deleteMessage(messageId: String, matchId: String) async throws {}
}

// MARK: - Mock Swipe Service

@MainActor
class MockSwipeService: SwipeServiceProtocol {
    var likeUserCalled = false
    var passUserCalled = false
    var shouldCreateMatch = false

    func likeUser(fromUserId: String, toUserId: String, isSuperLike: Bool) async throws -> Bool {
        likeUserCalled = true
        return shouldCreateMatch
    }

    func passUser(fromUserId: String, toUserId: String) async throws {
        passUserCalled = true
    }

    func hasSwipedOn(fromUserId: String, toUserId: String) async throws -> (liked: Bool, passed: Bool) {
        return (false, false)
    }

    func getLikesReceived(userId: String) async throws -> [String] {
        return []
    }
}

// MARK: - Mock Network Manager

class MockNetworkManager: NetworkManagerProtocol {
    var isConnectedValue = true
    var requestCalled = false
    var shouldFail = false

    func isConnected() -> Bool {
        return isConnectedValue
    }

    func startMonitoring() {}
    func stopMonitoring() {}

    func performRequest<T>(_ request: NetworkRequest, retryCount: Int) async throws -> T where T: Decodable {
        requestCalled = true

        if shouldFail {
            throw NetworkError.serverError(500)
        }

        // Return mock data
        guard let mockData = try? JSONEncoder().encode(["success": true]) else {
            throw NetworkError.decodingError
        }

        return try JSONDecoder().decode(T.self, from: mockData)
    }
}

// MARK: - Mock Content Moderator

class MockContentModerator: ContentModeratorProtocol {
    var isAppropriateValue = true
    var containsProfanityValue = false

    func isAppropriate(_ text: String) -> Bool {
        return isAppropriateValue
    }

    func containsProfanity(_ text: String) -> Bool {
        return containsProfanityValue
    }

    func filterProfanity(_ text: String) -> String {
        return text
    }

    func containsSpam(_ text: String) -> Bool {
        return false
    }

    func containsPersonalInfo(_ text: String) -> Bool {
        return false
    }

    func contentScore(_ text: String) -> Int {
        return 100
    }

    func getViolations(_ text: String) -> [String] {
        return []
    }
}

// MARK: - Mock Image Upload Service

class MockImageUploadService: ImageUploadServiceProtocol {
    var uploadCalled = false
    var shouldFail = false

    func uploadProfileImage(image: Data, userId: String) async throws -> String {
        uploadCalled = true

        if shouldFail {
            throw CelestiaError.imageUploadFailed
        }

        return "https://mock-image-url.com/image.jpg"
    }

    func uploadChatImage(image: Data, matchId: String) async throws -> String {
        uploadCalled = true
        return "https://mock-image-url.com/chat-image.jpg"
    }

    func deleteImage(url: String) async throws {}
}

// MARK: - Mock Notification Service

@MainActor
class MockNotificationService: NotificationServiceProtocol {
    var requestPermissionCalled = false
    var sendNotificationCalled = false

    func requestPermission() async -> Bool {
        requestPermissionCalled = true
        return true
    }

    func saveFCMToken(userId: String, token: String) async {}

    func sendNewMatchNotification(match: Match, otherUser: User) async {
        sendNotificationCalled = true
    }

    func sendMessageNotification(message: Message, senderName: String, matchId: String) async {
        sendNotificationCalled = true
    }

    func sendLikeNotification(likerName: String?, userId: String, isSuperLike: Bool) async {
        sendNotificationCalled = true
    }

    func sendReferralSuccessNotification(userId: String, referredName: String) async {
        sendNotificationCalled = true
    }
}

// MARK: - Mock Interest Service

@MainActor
class MockInterestService {
    var sendInterestCalled = false
    var fetchInterestCalled = false
    var shouldFail = false
    var mockInterest: Interest?
    var sentInterestFromUserId: String?
    var sentInterestToUserId: String?

    func sendInterest(fromUserId: String, toUserId: String, message: String? = nil) async throws {
        sendInterestCalled = true
        sentInterestFromUserId = fromUserId
        sentInterestToUserId = toUserId

        if shouldFail {
            throw CelestiaError.networkError
        }
    }

    func fetchInterest(fromUserId: String, toUserId: String) async throws -> Interest? {
        fetchInterestCalled = true
        return mockInterest
    }

    func hasLiked(fromUserId: String, toUserId: String) async -> Bool {
        return mockInterest != nil
    }
}

// MARK: - Mock Haptic Manager

@MainActor
class MockHapticManager {
    var notificationCalled = false
    var notificationType: UINotificationFeedbackGenerator.FeedbackType?
    var impactCalled = false
    var selectionCalled = false

    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationCalled = true
        notificationType = type
    }

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        impactCalled = true
    }

    func selection() {
        selectionCalled = true
    }

    func success() {
        notification(.success)
    }

    func warning() {
        notification(.warning)
    }

    func error() {
        notification(.error)
    }
}

// MARK: - Mock Logger

class MockLogger {
    var infoCalled = false
    var warningCalled = false
    var errorCalled = false
    var debugCalled = false

    var lastInfoMessage: String?
    var lastWarningMessage: String?
    var lastErrorMessage: String?
    var lastCategory: LogCategory?

    func info(_ message: String, category: LogCategory, metadata: [String: Any]? = nil) {
        infoCalled = true
        lastInfoMessage = message
        lastCategory = category
    }

    func warning(_ message: String, category: LogCategory, metadata: [String: Any]? = nil) {
        warningCalled = true
        lastWarningMessage = message
        lastCategory = category
    }

    func error(_ message: String, category: LogCategory, error: Error? = nil, metadata: [String: Any]? = nil) {
        errorCalled = true
        lastErrorMessage = message
        lastCategory = category
    }

    func debug(_ message: String, category: LogCategory, metadata: [String: Any]? = nil) {
        debugCalled = true
        lastCategory = category
    }
}

// MARK: - Mock Analytics Service

@MainActor
class MockAnalyticsService {
    var trackEventCalled = false
    var setUserPropertyCalled = false
    var lastEventName: String?
    var lastEventParameters: [String: Any]?
    var lastPropertyName: String?
    var lastPropertyValue: String?

    func trackEvent(_ name: String, parameters: [String: Any]? = nil) {
        trackEventCalled = true
        lastEventName = name
        lastEventParameters = parameters
    }

    func setUserProperty(_ name: String, value: String?) {
        setUserPropertyCalled = true
        lastPropertyName = name
        lastPropertyValue = value
    }

    func logScreenView(_ screenName: String, screenClass: String? = nil) {
        trackEvent("screen_view", parameters: ["screen_name": screenName])
    }
}

// MARK: - Mock User Service Extended

extension MockUserService {
    var checkDailyLikeLimitCalled = false
    var decrementDailyLikesCalled = false
    var decrementSuperLikesCalled = false
    var hasLikesRemaining = true

    func checkDailyLikeLimit(userId: String) async -> Bool {
        checkDailyLikeLimitCalled = true
        return hasLikesRemaining
    }

    func decrementDailyLikes(userId: String) async {
        decrementDailyLikesCalled = true
    }

    func decrementSuperLikes(userId: String) async {
        decrementSuperLikesCalled = true
    }
}

// MARK: - Mock Message Service Extended

extension MockMessageService {
    var markMessagesAsReadCalled = false

    func markMessagesAsRead(matchId: String, userId: String) async {
        markMessagesAsReadCalled = true
    }
}
