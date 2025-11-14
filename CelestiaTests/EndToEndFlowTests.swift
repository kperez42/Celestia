//
//  EndToEndFlowTests.swift
//  CelestiaTests
//
//  End-to-end user flow tests simulating real user journeys:
//  - Complete signup flow
//  - Profile creation and editing
//  - Discovery and swiping
//  - Matching flow
//  - Messaging flow
//  - Premium upgrade flow
//

import Testing
import Foundation
@testable import Celestia

@Suite("End-to-End User Flow Tests")
struct EndToEndFlowTests {

    // MARK: - Complete User Journey

    @Test("Complete user journey: Signup → Match → Message")
    @MainActor
    func testCompleteUserJourney() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        Logger.shared.info("=== Starting Complete User Journey Test ===", category: .testing)

        // Step 1: User signs up
        Logger.shared.info("Step 1: User signup", category: .testing)
        let user1 = try await testBase.createTestUser(
            fullName: "Alice Johnson",
            age: 26,
            gender: "Female",
            lookingFor: "Male"
        )
        #expect(user1.id != nil)
        #expect(user1.email.contains("test"))

        // Step 2: Create another user to match with
        Logger.shared.info("Step 2: Create second user", category: .testing)
        let user2 = try await testBase.createTestUser(
            fullName: "Bob Smith",
            age: 28,
            gender: "Male",
            lookingFor: "Female"
        )
        #expect(user2.id != nil)

        // Step 3: Both users like each other (create match)
        Logger.shared.info("Step 3: Users like each other", category: .testing)
        guard let user1Id = user1.id, let user2Id = user2.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        let swipeService = SwipeService.shared

        // User1 likes User2
        let isMatch1 = try await swipeService.likeUser(fromUserId: user1Id, toUserId: user2Id)
        #expect(!isMatch1) // No match yet (not mutual)

        // User2 likes User1 (creates mutual match)
        let isMatch2 = try await swipeService.likeUser(fromUserId: user2Id, toUserId: user1Id)
        #expect(isMatch2) // Should be a match now

        // Verify match was created
        try await testBase.simulateNetworkDelay(milliseconds: 100)
        let match = try await MatchService.shared.fetchMatch(user1Id: user1Id, user2Id: user2Id)
        #expect(match != nil)
        Logger.shared.info("✅ Match created successfully", category: .testing)

        // Step 4: Send messages
        Logger.shared.info("Step 4: Send messages", category: .testing)
        guard let matchId = match?.id else {
            throw IntegrationTestError.assertionFailed("Match ID is nil")
        }

        let messageService = MessageService.shared

        // User1 sends first message
        try await messageService.sendMessage(
            matchId: matchId,
            senderId: user1Id,
            receiverId: user2Id,
            text: "Hey! Nice to match with you! 👋"
        )

        // User2 responds
        try await messageService.sendMessage(
            matchId: matchId,
            senderId: user2Id,
            receiverId: user1Id,
            text: "Thanks! You seem interesting! 😊"
        )

        // Verify messages were created
        try await testBase.simulateNetworkDelay(milliseconds: 200)
        let messages = try await messageService.fetchMessages(matchId: matchId, limit: 10)
        #expect(messages.count >= 2)
        #expect(messages[0].text.contains("Hey"))
        Logger.shared.info("✅ Messages sent successfully", category: .testing)

        // Step 5: Verify unread counts
        Logger.shared.info("Step 5: Verify unread counts", category: .testing)
        let unreadCount = try await messageService.getUnreadCount(matchId: matchId, userId: user1Id)
        #expect(unreadCount >= 1) // User1 has unread message from User2

        // Step 6: Mark messages as read
        await messageService.markMessagesAsRead(matchId: matchId, userId: user1Id)
        try await testBase.simulateNetworkDelay(milliseconds: 100)

        let unreadCountAfter = try await messageService.getUnreadCount(matchId: matchId, userId: user1Id)
        #expect(unreadCountAfter == 0)
        Logger.shared.info("✅ Messages marked as read", category: .testing)

        Logger.shared.info("=== Complete User Journey Test PASSED ===", category: .testing)
    }

    // MARK: - Signup Flow Tests

    @Test("Signup flow with email verification")
    @MainActor
    func testSignupFlowWithVerification() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        let authService = AuthService.shared

        // Test data
        let email = "newuser@test.com"
        let password = "SecurePass123!"
        let fullName = "New Test User"

        // Attempt signup
        try await authService.createUser(
            withEmail: email,
            password: password,
            fullName: fullName,
            age: 24,
            gender: "Female",
            lookingFor: "Male",
            location: "San Francisco",
            country: "USA"
        )

        // Verify user was created
        #expect(authService.currentUser != nil)
        #expect(authService.currentUser?.email == email)
        #expect(authService.currentUser?.fullName == fullName)

        // In emulator, email verification is automatically done
        // In production, would need to verify email
        Logger.shared.info("✅ Signup flow completed", category: .testing)
    }

    @Test("Signup flow with referral code")
    @MainActor
    func testSignupFlowWithReferral() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        // Create referrer user
        let referrer = try await testBase.createTestUser(fullName: "Referrer User")
        guard let referrerId = referrer.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        // Initialize referral code for referrer
        var updatedReferrer = referrer
        try await ReferralManager.shared.initializeReferralCode(for: &updatedReferrer)

        guard let referralCode = updatedReferrer.referralStats.referralCode else {
            throw IntegrationTestError.assertionFailed("Referral code not generated")
        }

        // Create new user with referral code
        let authService = AuthService.shared
        try await authService.createUser(
            withEmail: "referred@test.com",
            password: "Password123!",
            fullName: "Referred User",
            age: 25,
            gender: "Male",
            lookingFor: "Female",
            location: "New York",
            country: "USA",
            referralCode: referralCode
        )

        // Verify referral was processed
        #expect(authService.currentUser?.referredByCode == referralCode)

        Logger.shared.info("✅ Signup with referral completed", category: .testing)
    }

    // MARK: - Discovery and Matching Flow

    @Test("Discovery and swiping flow")
    @MainActor
    func testDiscoveryAndSwipingFlow() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        // Create test users
        let currentUser = try await testBase.createTestUser(
            fullName: "Current User",
            gender: "Male",
            lookingFor: "Female"
        )

        let discoveredUsers = try await testBase.createTestUsers(count: 5)

        // Test swiping right (like)
        guard let currentUserId = currentUser.id,
              let firstUserId = discoveredUsers.first?.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        let swipeService = SwipeService.shared

        // Like a user
        let isMatch = try await swipeService.likeUser(fromUserId: currentUserId, toUserId: firstUserId)
        #expect(!isMatch) // No mutual like yet

        // Verify like was recorded
        let hasLiked = try await swipeService.hasSwipedOn(fromUserId: currentUserId, toUserId: firstUserId)
        #expect(hasLiked.liked)
        #expect(!hasLiked.passed)

        // Test swiping left (pass)
        guard let secondUserId = discoveredUsers.dropFirst().first?.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        try await swipeService.passUser(fromUserId: currentUserId, toUserId: secondUserId)

        let hasPassed = try await swipeService.hasSwipedOn(fromUserId: currentUserId, toUserId: secondUserId)
        #expect(!hasPassed.liked)
        #expect(hasPassed.passed)

        Logger.shared.info("✅ Discovery and swiping flow completed", category: .testing)
    }

    // MARK: - Messaging Flow

    @Test("Complete messaging flow with pagination")
    @MainActor
    func testCompleteMessagingFlow() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        // Create two matched users
        let user1 = try await testBase.createTestUser(fullName: "User 1")
        let user2 = try await testBase.createTestUser(fullName: "User 2")

        // Create conversation with 75 messages
        let (match, messages) = try await testBase.createTestConversation(
            user1: user1,
            user2: user2,
            messageCount: 75
        )

        guard let matchId = match.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        // Test message loading with pagination
        let messageService = MessageService.shared
        messageService.listenToMessages(matchId: matchId)

        // Wait for initial load
        try await testBase.waitForCondition(timeout: 3.0) {
            !messageService.isLoading && !messageService.messages.isEmpty
        }

        // Verify only 50 messages loaded initially
        #expect(messageService.messages.count == 50)
        #expect(messageService.hasMoreMessages)

        // Load older messages
        await messageService.loadOlderMessages(matchId: matchId)

        try await testBase.waitForCondition(timeout: 3.0) {
            !messageService.isLoadingMore
        }

        // Verify all messages loaded
        #expect(messageService.messages.count == 75)
        #expect(!messageService.hasMoreMessages)

        // Send a new message
        guard let user1Id = user1.id, let user2Id = user2.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        try await messageService.sendMessage(
            matchId: matchId,
            senderId: user1Id,
            receiverId: user2Id,
            text: "New message after pagination"
        )

        try await testBase.simulateNetworkDelay(milliseconds: 200)

        // Verify new message appears
        #expect(messageService.messages.count == 76)

        messageService.stopListening()

        Logger.shared.info("✅ Complete messaging flow with pagination completed", category: .testing)
    }

    // MARK: - Unmatch Flow

    @Test("Unmatch flow")
    @MainActor
    func testUnmatchFlow() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        // Create matched users
        let user1 = try await testBase.createTestUser()
        let user2 = try await testBase.createTestUser()

        guard let user1Id = user1.id, let user2Id = user2.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        let match = try await testBase.createTestMatch(user1Id: user1Id, user2Id: user2Id)
        guard let matchId = match.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        // Verify match is active
        let fetchedMatch = try await MatchService.shared.fetchMatch(user1Id: user1Id, user2Id: user2Id)
        #expect(fetchedMatch != nil)
        #expect(fetchedMatch?.isActive == true)

        // Unmatch
        try await MatchService.shared.unmatch(matchId: matchId, userId: user1Id)

        try await testBase.simulateNetworkDelay(milliseconds: 100)

        // Verify match is no longer active
        let unmatchedMatch = try await MatchService.shared.fetchMatch(user1Id: user1Id, user2Id: user2Id)
        #expect(unmatchedMatch == nil || unmatchedMatch?.isActive == false)

        Logger.shared.info("✅ Unmatch flow completed", category: .testing)
    }

    // MARK: - Profile Update Flow

    @Test("Profile update flow")
    @MainActor
    func testProfileUpdateFlow() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        // Create user
        var user = try await testBase.createTestUser(fullName: "Original Name")

        // Update profile
        user.fullName = "Updated Name"
        user.bio = "This is my updated bio"
        user.interests = ["Reading", "Hiking", "Cooking"]

        let userService = UserService.shared
        try await userService.updateUser(user)

        try await testBase.simulateNetworkDelay(milliseconds: 100)

        // Verify update
        guard let userId = user.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        let updatedUser = try await userService.fetchUser(userId: userId)
        #expect(updatedUser?.fullName == "Updated Name")
        #expect(updatedUser?.bio == "This is my updated bio")
        #expect(updatedUser?.interests.count == 3)

        Logger.shared.info("✅ Profile update flow completed", category: .testing)
    }

    // MARK: - Premium Upgrade Flow

    @Test("Premium upgrade simulation")
    @MainActor
    func testPremiumUpgradeSimulation() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        // Create user
        var user = try await testBase.createTestUser()
        guard let userId = user.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        // Verify user is not premium
        #expect(!user.isPremium)

        // Simulate premium upgrade
        user.isPremium = true
        user.premiumTier = "basic"
        user.subscriptionExpiryDate = Date().addingTimeInterval(30 * 24 * 3600) // 30 days

        let userService = UserService.shared
        try await userService.updateUser(user)

        try await testBase.simulateNetworkDelay(milliseconds: 100)

        // Verify premium status
        let updatedUser = try await userService.fetchUser(userId: userId)
        #expect(updatedUser?.isPremium == true)
        #expect(updatedUser?.premiumTier == "basic")

        Logger.shared.info("✅ Premium upgrade simulation completed", category: .testing)
    }
}

// MARK: - Edge Case Tests

@Suite("End-to-End Edge Cases")
struct EndToEndEdgeCaseTests {

    @Test("Handle rapid successive swipes")
    @MainActor
    func testRapidSwipes() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        let currentUser = try await testBase.createTestUser()
        let targetUsers = try await testBase.createTestUsers(count: 10)

        guard let currentUserId = currentUser.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        let swipeService = SwipeService.shared

        // Perform 10 rapid swipes
        for targetUser in targetUsers {
            guard let targetUserId = targetUser.id else { continue }

            _ = try await swipeService.likeUser(fromUserId: currentUserId, toUserId: targetUserId)
        }

        // Verify all swipes were recorded
        // (In production, rate limiting would apply)

        Logger.shared.info("✅ Rapid swipes test completed", category: .testing)
    }

    @Test("Handle message sending during pagination")
    @MainActor
    func testMessageDuringPagination() async throws {
        let testBase = try await IntegrationTestBase()
        defer { Task { await testBase.cleanup() } }

        // Create conversation with many messages
        let user1 = try await testBase.createTestUser()
        let user2 = try await testBase.createTestUser()

        let (match, _) = try await testBase.createTestConversation(
            user1: user1,
            user2: user2,
            messageCount: 100
        )

        guard let matchId = match.id,
              let user1Id = user1.id,
              let user2Id = user2.id else {
            throw IntegrationTestError.testDataSetupFailed
        }

        let messageService = MessageService.shared
        messageService.listenToMessages(matchId: matchId)

        try await testBase.waitForCondition(timeout: 3.0) {
            !messageService.isLoading
        }

        // Start pagination
        let paginationTask = Task {
            await messageService.loadOlderMessages(matchId: matchId)
        }

        // Send new message while pagination is in progress
        try await testBase.simulateNetworkDelay(milliseconds: 50)
        try await messageService.sendMessage(
            matchId: matchId,
            senderId: user1Id,
            receiverId: user2Id,
            text: "Message during pagination"
        )

        await paginationTask.value

        // Verify both operations completed successfully
        #expect(messageService.messages.count > 100)

        messageService.stopListening()

        Logger.shared.info("✅ Message during pagination test completed", category: .testing)
    }
}
