//
//  MockRepositories.swift
//  CelestiaTests
//
//  Mock implementations of repository protocols for comprehensive testing
//  Enables full control over data layer behavior in unit and integration tests
//

import Foundation
import FirebaseFirestore
@testable import Celestia

// MARK: - Mock User Repository

@MainActor
class MockUserRepository: UserRepository {

    // State tracking
    var users: [String: User] = [:]
    var fetchUserCalled = false
    var updateUserCalled = false
    var updateUserFieldsCalled = false
    var searchUsersCalled = false
    var incrementProfileViewsCalled = false
    var updateLastActiveCalled = false

    var lastSearchQuery: String?
    var lastUpdatedFields: [String: Any]?
    var shouldFail = false
    var failureError: Error = CelestiaError.networkError

    func fetchUser(id: String) async throws -> User? {
        fetchUserCalled = true

        if shouldFail {
            throw failureError
        }

        return users[id]
    }

    func updateUser(_ user: User) async throws {
        updateUserCalled = true

        if shouldFail {
            throw failureError
        }

        if let userId = user.id {
            users[userId] = user
        }
    }

    func updateUserFields(userId: String, fields: [String : Any]) async throws {
        updateUserFieldsCalled = true
        lastUpdatedFields = fields

        if shouldFail {
            throw failureError
        }

        // Update user with fields
        if var user = users[userId] {
            // Apply field updates (simplified for testing)
            if let fullName = fields["fullName"] as? String {
                user.fullName = fullName
            }
            if let bio = fields["bio"] as? String {
                user.bio = bio
            }
            users[userId] = user
        }
    }

    func searchUsers(query: String, currentUserId: String, limit: Int, offset: DocumentSnapshot?) async throws -> [User] {
        searchUsersCalled = true
        lastSearchQuery = query

        if shouldFail {
            throw failureError
        }

        // Simple search implementation - filter by name
        let results = users.values.filter { user in
            guard user.id != currentUserId else { return false }
            return user.fullName.localizedCaseInsensitiveContains(query)
        }

        return Array(results.prefix(limit))
    }

    func incrementProfileViews(userId: String) async {
        incrementProfileViewsCalled = true

        if var user = users[userId] {
            user.profileViews = (user.profileViews ?? 0) + 1
            users[userId] = user
        }
    }

    func updateLastActive(userId: String) async {
        updateLastActiveCalled = true

        if var user = users[userId] {
            user.lastActive = Date()
            users[userId] = user
        }
    }

    // Helper methods for testing
    func addUser(_ user: User) {
        if let userId = user.id {
            users[userId] = user
        }
    }

    func reset() {
        users.removeAll()
        fetchUserCalled = false
        updateUserCalled = false
        updateUserFieldsCalled = false
        searchUsersCalled = false
        incrementProfileViewsCalled = false
        updateLastActiveCalled = false
        lastSearchQuery = nil
        lastUpdatedFields = nil
        shouldFail = false
    }
}

// MARK: - Mock Match Repository

@MainActor
class MockMatchRepository: MatchRepository {

    var matches: [String: Match] = [:]
    var fetchMatchesCalled = false
    var fetchMatchCalled = false
    var createMatchCalled = false
    var updateMatchLastMessageCalled = false
    var deactivateMatchCalled = false

    var lastCreatedMatch: Match?
    var shouldFail = false
    var failureError: Error = CelestiaError.networkError

    func fetchMatches(userId: String) async throws -> [Match] {
        fetchMatchesCalled = true

        if shouldFail {
            throw failureError
        }

        return matches.values.filter { match in
            match.user1Id == userId || match.user2Id == userId
        }
    }

    func fetchMatch(user1Id: String, user2Id: String) async throws -> Match? {
        fetchMatchCalled = true

        if shouldFail {
            throw failureError
        }

        return matches.values.first { match in
            (match.user1Id == user1Id && match.user2Id == user2Id) ||
            (match.user1Id == user2Id && match.user2Id == user1Id)
        }
    }

    func createMatch(match: Match) async throws -> String {
        createMatchCalled = true
        lastCreatedMatch = match

        if shouldFail {
            throw failureError
        }

        let matchId = match.id ?? "match_\(UUID().uuidString)"
        var matchWithId = match
        matchWithId.id = matchId
        matches[matchId] = matchWithId

        return matchId
    }

    func updateMatchLastMessage(matchId: String, message: String, timestamp: Date) async throws {
        updateMatchLastMessageCalled = true

        if shouldFail {
            throw failureError
        }

        if var match = matches[matchId] {
            match.lastMessage = message
            match.lastMessageTimestamp = timestamp
            matches[matchId] = match
        }
    }

    func deactivateMatch(matchId: String) async throws {
        deactivateMatchCalled = true

        if shouldFail {
            throw failureError
        }

        if var match = matches[matchId] {
            match.isActive = false
            matches[matchId] = match
        }
    }

    // Helper methods
    func addMatch(_ match: Match) {
        if let matchId = match.id {
            matches[matchId] = match
        }
    }

    func reset() {
        matches.removeAll()
        fetchMatchesCalled = false
        fetchMatchCalled = false
        createMatchCalled = false
        updateMatchLastMessageCalled = false
        deactivateMatchCalled = false
        lastCreatedMatch = nil
        shouldFail = false
    }
}

// MARK: - Mock Message Repository

@MainActor
class MockMessageRepository: MessageRepository {

    var messages: [String: Message] = []
    var fetchMessagesCalled = false
    var sendMessageCalled = false
    var markMessagesAsReadCalled = false
    var deleteMessageCalled = false

    var lastSentMessage: Message?
    var shouldFail = false
    var failureError: Error = CelestiaError.networkError

    func fetchMessages(matchId: String, limit: Int, before: Date?) async throws -> [Message] {
        fetchMessagesCalled = true

        if shouldFail {
            throw failureError
        }

        var matchMessages = messages.values.filter { $0.matchId == matchId }

        // Filter by timestamp if provided
        if let beforeDate = before {
            matchMessages = matchMessages.filter { $0.timestamp < beforeDate }
        }

        // Sort by timestamp descending and limit
        return matchMessages
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit)
            .map { $0 }
    }

    func sendMessage(_ message: Message) async throws {
        sendMessageCalled = true
        lastSentMessage = message

        if shouldFail {
            throw failureError
        }

        let messageId = message.id ?? "msg_\(UUID().uuidString)"
        var messageWithId = message
        messageWithId.id = messageId
        messages[messageId] = messageWithId
    }

    func markMessagesAsRead(matchId: String, userId: String) async throws {
        markMessagesAsReadCalled = true

        if shouldFail {
            throw failureError
        }

        for (id, var message) in messages {
            if message.matchId == matchId && message.receiverId == userId {
                message.isRead = true
                messages[id] = message
            }
        }
    }

    func deleteMessage(messageId: String) async throws {
        deleteMessageCalled = true

        if shouldFail {
            throw failureError
        }

        messages.removeValue(forKey: messageId)
    }

    // Helper methods
    func addMessage(_ message: Message) {
        if let messageId = message.id {
            messages[messageId] = message
        }
    }

    func reset() {
        messages.removeAll()
        fetchMessagesCalled = false
        sendMessageCalled = false
        markMessagesAsReadCalled = false
        deleteMessageCalled = false
        lastSentMessage = nil
        shouldFail = false
    }
}

// MARK: - Mock Interest Repository

@MainActor
class MockInterestRepository: InterestRepository {

    var interests: [String: Interest] = [:]
    var fetchInterestCalled = false
    var sendInterestCalled = false
    var acceptInterestCalled = false
    var rejectInterestCalled = false

    var lastSentInterest: Interest?
    var shouldFail = false
    var failureError: Error = CelestiaError.networkError

    func fetchInterest(fromUserId: String, toUserId: String) async throws -> Interest? {
        fetchInterestCalled = true

        if shouldFail {
            throw failureError
        }

        return interests.values.first { interest in
            interest.fromUserId == fromUserId && interest.toUserId == toUserId
        }
    }

    func sendInterest(_ interest: Interest) async throws {
        sendInterestCalled = true
        lastSentInterest = interest

        if shouldFail {
            throw failureError
        }

        let interestId = interest.id ?? "interest_\(UUID().uuidString)"
        var interestWithId = interest
        interestWithId.id = interestId
        interests[interestId] = interestWithId
    }

    func acceptInterest(interestId: String) async throws {
        acceptInterestCalled = true

        if shouldFail {
            throw failureError
        }

        if var interest = interests[interestId] {
            interest.status = "accepted"
            interests[interestId] = interest
        }
    }

    func rejectInterest(interestId: String) async throws {
        rejectInterestCalled = true

        if shouldFail {
            throw failureError
        }

        if var interest = interests[interestId] {
            interest.status = "rejected"
            interests[interestId] = interest
        }
    }

    // Helper methods
    func addInterest(_ interest: Interest) {
        if let interestId = interest.id {
            interests[interestId] = interest
        }
    }

    func reset() {
        interests.removeAll()
        fetchInterestCalled = false
        sendInterestCalled = false
        acceptInterestCalled = false
        rejectInterestCalled = false
        lastSentInterest = nil
        shouldFail = false
    }
}

// MARK: - Test Repository Factory

/// Factory for creating mock repositories in tests
@MainActor
struct TestRepositoryFactory {

    static func createMockUserRepository(withUsers users: [User] = []) -> MockUserRepository {
        let repo = MockUserRepository()
        users.forEach { repo.addUser($0) }
        return repo
    }

    static func createMockMatchRepository(withMatches matches: [Match] = []) -> MockMatchRepository {
        let repo = MockMatchRepository()
        matches.forEach { repo.addMatch($0) }
        return repo
    }

    static func createMockMessageRepository(withMessages messages: [Message] = []) -> MockMessageRepository {
        let repo = MockMessageRepository()
        messages.forEach { repo.addMessage($0) }
        return repo
    }

    static func createMockInterestRepository(withInterests interests: [Interest] = []) -> MockInterestRepository {
        let repo = MockInterestRepository()
        interests.forEach { repo.addInterest($0) }
        return repo
    }
}
