//
//  TestFixtures.swift
//  CelestiaTests
//
//  Test fixtures and utilities for comprehensive ViewModel testing
//

import Foundation
@testable import Celestia

// MARK: - Test User Fixtures

struct TestFixtures {

    // MARK: - User Fixtures

    static func createTestUser(
        id: String = "test_user_\(UUID().uuidString)",
        email: String = "test@example.com",
        fullName: String = "Test User",
        age: Int = 28,
        gender: String = "Female",
        lookingFor: String = "Male",
        bio: String = "Test bio",
        location: String = "New York",
        country: String = "USA",
        languages: [String] = ["English"],
        interests: [String] = ["Travel", "Music"],
        photos: [String] = [],
        profileImageURL: String = "https://example.com/profile.jpg",
        isPremium: Bool = false,
        isVerified: Bool = false,
        ageRangeMin: Int = 25,
        ageRangeMax: Int = 35,
        maxDistance: Int = 50,
        likesRemainingToday: Int = 50,
        superLikesRemaining: Int = 0,
        boostsRemaining: Int = 0,
        latitude: Double? = 40.7128,
        longitude: Double? = -74.0060
    ) -> User {
        return User(
            id: id,
            email: email,
            fullName: fullName,
            age: age,
            gender: gender,
            lookingFor: lookingFor,
            bio: bio,
            location: location,
            country: country,
            latitude: latitude,
            longitude: longitude,
            languages: languages,
            interests: interests,
            photos: photos,
            profileImageURL: profileImageURL,
            timestamp: Date(),
            lastActive: Date(),
            isPremium: isPremium,
            isVerified: isVerified,
            ageRangeMin: ageRangeMin,
            ageRangeMax: ageRangeMax,
            maxDistance: maxDistance,
            likesRemainingToday: likesRemainingToday,
            superLikesRemaining: superLikesRemaining,
            boostsRemaining: boostsRemaining
        )
    }

    static func createPremiumUser(
        id: String = "premium_user_\(UUID().uuidString)",
        fullName: String = "Premium User"
    ) -> User {
        var user = createTestUser(id: id, fullName: fullName)
        user.isPremium = true
        user.superLikesRemaining = 5
        user.boostsRemaining = 3
        user.premiumTier = "gold"
        user.subscriptionExpiryDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())
        return user
    }

    static func createVerifiedUser(
        id: String = "verified_user_\(UUID().uuidString)",
        fullName: String = "Verified User"
    ) -> User {
        var user = createTestUser(id: id, fullName: fullName)
        user.isVerified = true
        return user
    }

    static func createBatchUsers(count: Int, startAge: Int = 25) -> [User] {
        return (0..<count).map { index in
            createTestUser(
                id: "batch_user_\(index)",
                fullName: "User \(index + 1)",
                age: startAge + (index % 10),
                gender: index % 2 == 0 ? "Female" : "Male",
                location: ["New York", "Los Angeles", "Chicago", "Miami", "Seattle"][index % 5],
                interests: [
                    ["Travel", "Music"],
                    ["Sports", "Gaming"],
                    ["Art", "Reading"],
                    ["Food", "Yoga"],
                    ["Movies", "Hiking"]
                ][index % 5]
            )
        }
    }

    // MARK: - Match Fixtures

    static func createTestMatch(
        id: String = "match_\(UUID().uuidString)",
        user1Id: String = "user1",
        user2Id: String = "user2",
        isActive: Bool = true,
        timestamp: Date = Date(),
        lastMessage: String? = nil,
        lastMessageTimestamp: Date? = nil
    ) -> Match {
        return Match(
            id: id,
            user1Id: user1Id,
            user2Id: user2Id,
            timestamp: timestamp,
            isActive: isActive,
            lastMessage: lastMessage,
            lastMessageTimestamp: lastMessageTimestamp
        )
    }

    static func createBatchMatches(count: Int, currentUserId: String) -> [Match] {
        return (0..<count).map { index in
            createTestMatch(
                id: "match_\(index)",
                user1Id: currentUserId,
                user2Id: "other_user_\(index)",
                timestamp: Date().addingTimeInterval(TimeInterval(-index * 3600)),
                lastMessage: "Hey! How are you?",
                lastMessageTimestamp: Date().addingTimeInterval(TimeInterval(-index * 1800))
            )
        }
    }

    // MARK: - Message Fixtures

    static func createTestMessage(
        id: String = "message_\(UUID().uuidString)",
        matchId: String = "test_match",
        senderId: String = "sender_id",
        receiverId: String = "receiver_id",
        text: String = "Test message",
        timestamp: Date = Date(),
        isRead: Bool = false
    ) -> Message {
        return Message(
            id: id,
            matchId: matchId,
            senderId: senderId,
            receiverId: receiverId,
            text: text,
            timestamp: timestamp,
            isRead: isRead
        )
    }

    static func createConversation(
        matchId: String,
        user1Id: String,
        user2Id: String,
        messageCount: Int = 10
    ) -> [Message] {
        return (0..<messageCount).map { index in
            let isFromUser1 = index % 2 == 0
            return createTestMessage(
                id: "msg_\(index)",
                matchId: matchId,
                senderId: isFromUser1 ? user1Id : user2Id,
                receiverId: isFromUser1 ? user2Id : user1Id,
                text: "Message \(index + 1)",
                timestamp: Date().addingTimeInterval(TimeInterval(index * 60)),
                isRead: index < messageCount - 2
            )
        }
    }

    // MARK: - Interest Fixtures

    static func createTestInterest(
        id: String = "interest_\(UUID().uuidString)",
        fromUserId: String = "sender",
        toUserId: String = "receiver",
        message: String? = nil,
        status: String = "pending",
        timestamp: Date = Date()
    ) -> Interest {
        return Interest(
            id: id,
            fromUserId: fromUserId,
            toUserId: toUserId,
            message: message,
            status: status,
            timestamp: timestamp
        )
    }
}

// MARK: - Test Utilities

extension TestFixtures {

    /// Wait for async condition with timeout
    static func waitFor(
        timeout: TimeInterval = 2.0,
        condition: @escaping () async -> Bool
    ) async -> Bool {
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            if await condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        return false
    }

    /// Wait for published property to change
    @MainActor
    static func waitForChange<T: Equatable>(
        timeout: TimeInterval = 2.0,
        getCurrentValue: () -> T,
        expectedValue: T
    ) async -> Bool {
        return await waitFor(timeout: timeout) {
            getCurrentValue() == expectedValue
        }
    }
}

// MARK: - String Extensions for Testing

extension String {
    static func randomEmail() -> String {
        return "test_\(UUID().uuidString.prefix(8))@example.com"
    }

    static func randomName() -> String {
        let firstNames = ["Alex", "Jordan", "Sam", "Taylor", "Morgan", "Casey", "Riley", "Avery"]
        let lastNames = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis"]
        return "\(firstNames.randomElement()!) \(lastNames.randomElement()!)"
    }
}

// MARK: - Date Extensions for Testing

extension Date {
    static func daysAgo(_ days: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: -days, to: Date())!
    }

    static func hoursAgo(_ hours: Int) -> Date {
        return Calendar.current.date(byAdding: .hour, value: -hours, to: Date())!
    }

    static func minutesAgo(_ minutes: Int) -> Date {
        return Calendar.current.date(byAdding: .minute, value: -minutes, to: Date())!
    }
}

// MARK: - Swipe & Like Fixtures

extension TestFixtures {

    static func createTestSwipe(
        fromUserId: String = "user1",
        toUserId: String = "user2",
        isSuperLike: Bool = false,
        timestamp: Date = Date()
    ) -> (fromUserId: String, toUserId: String, isSuperLike: Bool, timestamp: Date) {
        return (fromUserId, toUserId, isSuperLike, timestamp)
    }

    static func createBatchSwipes(count: Int, fromUserId: String) -> [(fromUserId: String, toUserId: String, isSuperLike: Bool)] {
        return (0..<count).map { index in
            (fromUserId, "target_user_\(index)", index % 5 == 0) // Every 5th is super like
        }
    }
}

// MARK: - Referral Fixtures

extension TestFixtures {

    static func createTestReferral(
        referrerId: String = "referrer_id",
        referredId: String = "referred_id",
        code: String = "REF123",
        timestamp: Date = Date()
    ) -> (referrerId: String, referredId: String, code: String, timestamp: Date) {
        return (referrerId, referredId, code, timestamp)
    }

    static func generateReferralCode() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in letters.randomElement()! })
    }
}

// MARK: - Premium/Subscription Fixtures

extension TestFixtures {

    static func createSubscription(
        userId: String,
        tier: String = "gold",
        startDate: Date = Date(),
        expiryDate: Date? = nil
    ) -> (userId: String, tier: String, startDate: Date, expiryDate: Date?) {
        let expiry = expiryDate ?? Calendar.current.date(byAdding: .month, value: 1, to: startDate)
        return (userId, tier, startDate, expiry)
    }

    static func createExpiredSubscription(userId: String) -> (userId: String, tier: String, startDate: Date, expiryDate: Date?) {
        let startDate = Date.daysAgo(40)
        let expiryDate = Date.daysAgo(10)
        return (userId, "gold", startDate, expiryDate)
    }
}

// MARK: - Notification Fixtures

extension TestFixtures {

    static func createTestNotification(
        type: String = "match",
        userId: String = "user_id",
        title: String = "New Match!",
        body: String = "You have a new match",
        data: [String: String] = [:]
    ) -> (type: String, userId: String, title: String, body: String, data: [String: String]) {
        return (type, userId, title, body, data)
    }
}

// MARK: - Profile Photo Fixtures

extension TestFixtures {

    static func createPhotoURLs(count: Int = 6) -> [String] {
        return (1...count).map { "https://example.com/photo\($0).jpg" }
    }

    static func createPhotoUploadData() -> Data {
        // Create minimal valid image data (1x1 PNG)
        let pngHeader: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        return Data(pngHeader)
    }
}

// MARK: - Assertion Helpers

struct TestAssertions {

    /// Assert two dates are approximately equal (within tolerance)
    static func assertDatesEqual(_ date1: Date, _ date2: Date, tolerance: TimeInterval = 1.0) -> Bool {
        return abs(date1.timeIntervalSince(date2)) <= tolerance
    }

    /// Assert array contains exactly the expected items in any order
    static func assertArrayContainsExactly<T: Equatable>(_ array: [T], _ expected: [T]) -> Bool {
        return array.count == expected.count && Set(array) == Set(expected)
    }

    /// Assert user has expected premium features
    static func assertUserIsPremium(_ user: User) -> Bool {
        return user.isPremium &&
               user.superLikesRemaining > 0 &&
               user.premiumTier != nil
    }

    /// Assert match is valid
    static func assertValidMatch(_ match: Match) -> Bool {
        return match.id != nil &&
               !match.user1Id.isEmpty &&
               !match.user2Id.isEmpty &&
               match.isActive
    }

    /// Assert message is valid
    static func assertValidMessage(_ message: Message) -> Bool {
        return message.id != nil &&
               !message.matchId.isEmpty &&
               !message.senderId.isEmpty &&
               !message.receiverId.isEmpty &&
               !message.text.isEmpty
    }
}

// MARK: - Performance Test Helpers

extension TestFixtures {

    /// Create large dataset for performance testing
    static func createLargeUserDataset(count: Int = 1000) -> [User] {
        return (0..<count).map { index in
            createTestUser(
                id: "perf_user_\(index)",
                fullName: String.randomName(),
                age: Int.random(in: 18...55),
                gender: ["Male", "Female", "Non-binary"].randomElement()!,
                location: ["New York", "Los Angeles", "Chicago", "Miami", "Seattle", "Boston", "Austin", "Portland"].randomElement()!
            )
        }
    }

    /// Create conversation with many messages for pagination testing
    static func createLargeConversation(
        matchId: String,
        user1Id: String,
        user2Id: String,
        messageCount: Int = 100
    ) -> [Message] {
        return (0..<messageCount).map { index in
            let isFromUser1 = index % 2 == 0
            return createTestMessage(
                id: "msg_\(index)",
                matchId: matchId,
                senderId: isFromUser1 ? user1Id : user2Id,
                receiverId: isFromUser1 ? user2Id : user1Id,
                text: "Performance test message \(index + 1)",
                timestamp: Date().addingTimeInterval(TimeInterval(index)),
                isRead: index < messageCount - 10
            )
        }
    }
}
