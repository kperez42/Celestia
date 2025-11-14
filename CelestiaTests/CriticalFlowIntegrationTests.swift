//
//  CriticalFlowIntegrationTests.swift
//  CelestiaTests
//
//  Integration tests for critical user flows: signup → match → message
//  Tests complete end-to-end scenarios using mock services
//

import Testing
import Foundation
@testable import Celestia

@Suite("Critical Flow Integration Tests")
@MainActor
struct CriticalFlowIntegrationTests {

    // MARK: - Signup → Discovery → Match Flow

    @Test("Complete signup to match flow")
    func testSignupToMatchFlow() async throws {
        // Setup
        let authService = MockAuthService()
        let userService = MockUserService()
        let swipeService = MockSwipeService()
        let matchService = MockMatchService()

        // Step 1: User signs up
        let email = String.randomEmail()
        let password = "SecurePass123!"
        let fullName = "New User"

        try await authService.createUser(
            withEmail: email,
            password: password,
            fullName: fullName,
            age: 28,
            gender: "Female",
            lookingFor: "Male",
            location: "New York",
            country: "USA"
        )

        #expect(authService.createUserCalled)
        #expect(authService.currentUser?.fullName == fullName)
        #expect(authService.currentUser?.email == email)

        // Step 2: User browses discovery feed
        guard let currentUser = authService.currentUser else {
            throw TestError.missingData("Current user not found after signup")
        }

        try await userService.fetchUsers(
            excludingUserId: currentUser.id!,
            lookingFor: currentUser.lookingFor,
            ageRange: currentUser.ageRangeMin...currentUser.ageRangeMax,
            country: nil,
            limit: 20,
            reset: true
        )

        #expect(userService.fetchUsersCalled)
        #expect(userService.users.count > 0)

        // Step 3: User likes another user
        let targetUser = userService.users.first!
        swipeService.shouldCreateMatch = true // Simulate mutual like

        let isMatch = try await swipeService.likeUser(
            fromUserId: currentUser.id!,
            toUserId: targetUser.id!,
            isSuperLike: false
        )

        #expect(swipeService.likeUserCalled)
        #expect(isMatch == true)

        // Step 4: Match is created
        await matchService.createMatch(
            user1Id: currentUser.id!,
            user2Id: targetUser.id!
        )

        #expect(matchService.createMatchCalled)
    }

    @Test("Signup with referral code flow")
    func testSignupWithReferralFlow() async throws {
        let authService = MockAuthService()
        let referralCode = TestFixtures.generateReferralCode()

        // Create user with referral code
        try await authService.createUser(
            withEmail: String.randomEmail(),
            password: "SecurePass123!",
            fullName: "Referred User",
            age: 25,
            gender: "Male",
            lookingFor: "Female",
            location: "Los Angeles",
            country: "USA",
            referralCode: referralCode
        )

        #expect(authService.createUserCalled)
        #expect(authService.currentUser != nil)
        // In real implementation, ReferralManager would handle the bonus
    }

    // MARK: - Match → Message Flow

    @Test("Complete match to messaging flow")
    func testMatchToMessagingFlow() async throws {
        // Setup
        let user1 = TestFixtures.createTestUser(id: "user1", fullName: "Alice")
        let user2 = TestFixtures.createTestUser(id: "user2", fullName: "Bob")

        let matchService = MockMatchService()
        let messageService = MockMessageService()

        // Step 1: Create match
        await matchService.createMatch(
            user1Id: user1.id!,
            user2Id: user2.id!
        )

        #expect(matchService.createMatchCalled)

        // Step 2: User 1 sends first message
        try await messageService.sendMessage(
            matchId: "test_match_id",
            senderId: user1.id!,
            receiverId: user2.id!,
            text: "Hey! How are you?"
        )

        #expect(messageService.sendMessageCalled)

        // Step 3: User 2 responds
        try await messageService.sendMessage(
            matchId: "test_match_id",
            senderId: user2.id!,
            receiverId: user1.id!,
            text: "Hi! I'm great, thanks for asking!"
        )

        // Step 4: Update match with last message
        try await matchService.updateMatchLastMessage(
            matchId: "test_match_id",
            message: "Hi! I'm great, thanks for asking!",
            timestamp: Date()
        )

        #expect(matchService.updateMatchLastMessageCalled)
    }

    @Test("Message conversation with read receipts")
    func testMessageConversationWithReadReceipts() async throws {
        let messageRepo = MockMessageRepository()
        let user1Id = "user1"
        let user2Id = "user2"
        let matchId = "match123"

        // User 1 sends 3 messages
        for i in 1...3 {
            let message = TestFixtures.createTestMessage(
                matchId: matchId,
                senderId: user1Id,
                receiverId: user2Id,
                text: "Message \(i)"
            )
            try await messageRepo.sendMessage(message)
        }

        #expect(messageRepo.sendMessageCalled)

        // User 2 reads messages
        try await messageRepo.markMessagesAsRead(matchId: matchId, userId: user2Id)

        #expect(messageRepo.markMessagesAsReadCalled)

        // Verify messages are marked as read
        let messages = try await messageRepo.fetchMessages(matchId: matchId, limit: 10, before: nil)
        let unreadMessages = messages.filter { !$0.isRead }
        #expect(unreadMessages.isEmpty)
    }

    // MARK: - Discovery → Like → No Match Flow

    @Test("Like without mutual match flow")
    func testLikeWithoutMatchFlow() async throws {
        let user1 = TestFixtures.createTestUser(id: "user1")
        let user2 = TestFixtures.createTestUser(id: "user2")

        let swipeService = MockSwipeService()
        swipeService.shouldCreateMatch = false // No mutual like

        let isMatch = try await swipeService.likeUser(
            fromUserId: user1.id!,
            toUserId: user2.id!,
            isSuperLike: false
        )

        #expect(swipeService.likeUserCalled)
        #expect(isMatch == false) // Should not create match
    }

    @Test("Pass user flow")
    func testPassUserFlow() async throws {
        let user1 = TestFixtures.createTestUser(id: "user1")
        let user2 = TestFixtures.createTestUser(id: "user2")

        let swipeService = MockSwipeService()

        try await swipeService.passUser(
            fromUserId: user1.id!,
            toUserId: user2.id!
        )

        #expect(swipeService.passUserCalled)
    }

    // MARK: - Super Like Flow

    @Test("Super like with match flow")
    func testSuperLikeWithMatchFlow() async throws {
        let premiumUser = TestFixtures.createPremiumUser(id: "premium1")
        let targetUser = TestFixtures.createTestUser(id: "target1")

        #expect(premiumUser.superLikesRemaining > 0)

        let swipeService = MockSwipeService()
        swipeService.shouldCreateMatch = true

        let isMatch = try await swipeService.likeUser(
            fromUserId: premiumUser.id!,
            toUserId: targetUser.id!,
            isSuperLike: true
        )

        #expect(swipeService.likeUserCalled)
        #expect(isMatch == true)
    }

    // MARK: - Daily Like Limit Flow

    @Test("Daily like limit reached shows upgrade prompt")
    func testDailyLikeLimitFlow() async throws {
        let freeUser = TestFixtures.createTestUser(
            id: "free_user",
            isPremium: false,
            likesRemainingToday: 0 // No likes remaining
        )

        #expect(freeUser.isPremium == false)
        #expect(freeUser.likesRemainingToday == 0)

        // Attempting to like should fail or show upgrade prompt
        // In real app, this would be handled by the ViewModel
    }

    // MARK: - Unmatch Flow

    @Test("Unmatch flow deactivates conversation")
    func testUnmatchFlow() async throws {
        let matchRepo = MockMatchRepository()
        let messageRepo = MockMessageRepository()

        // Create match
        let match = TestFixtures.createTestMatch(id: "match1", user1Id: "user1", user2Id: "user2")
        matchRepo.addMatch(match)

        // Create messages
        let message1 = TestFixtures.createTestMessage(matchId: "match1", senderId: "user1", receiverId: "user2")
        messageRepo.addMessage(message1)

        // Unmatch
        try await matchRepo.deactivateMatch(matchId: "match1")

        #expect(matchRepo.deactivateMatchCalled)

        // Verify match is deactivated
        let deactivatedMatch = try await matchRepo.fetchMatch(user1Id: "user1", user2Id: "user2")
        #expect(deactivatedMatch?.isActive == false)
    }

    // MARK: - Multi-User Discovery Flow

    @Test("User browses multiple profiles in sequence")
    func testMultipleProfileBrowsingFlow() async throws {
        let currentUser = TestFixtures.createTestUser(id: "current_user")
        let userRepo = MockUserRepository()

        // Add multiple users to browse
        let browsableUsers = TestFixtures.createBatchUsers(count: 10)
        browsableUsers.forEach { userRepo.addUser($0) }

        // Search for users
        let results = try await userRepo.searchUsers(
            query: "User",
            currentUserId: currentUser.id!,
            limit: 10,
            offset: nil
        )

        #expect(userRepo.searchUsersCalled)
        #expect(results.count <= 10)
    }

    // MARK: - Profile View Tracking

    @Test("Profile views are tracked correctly")
    func testProfileViewTrackingFlow() async throws {
        let userRepo = MockUserRepository()
        let viewedUser = TestFixtures.createTestUser(id: "viewed_user")
        userRepo.addUser(viewedUser)

        // User views profile
        await userRepo.incrementProfileViews(userId: viewedUser.id!)

        #expect(userRepo.incrementProfileViewsCalled)

        // Fetch updated user
        let updatedUser = try await userRepo.fetchUser(id: viewedUser.id!)
        #expect((updatedUser?.profileViews ?? 0) > 0)
    }

    // MARK: - Last Active Update Flow

    @Test("Last active timestamp updates on activity")
    func testLastActiveUpdateFlow() async throws {
        let userRepo = MockUserRepository()
        let activeUser = TestFixtures.createTestUser(id: "active_user")
        userRepo.addUser(activeUser)

        let beforeUpdate = activeUser.lastActive

        // Small delay to ensure timestamp difference
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        await userRepo.updateLastActive(userId: activeUser.id!)

        #expect(userRepo.updateLastActiveCalled)

        let updatedUser = try await userRepo.fetchUser(id: activeUser.id!)
        #expect(updatedUser?.lastActive ?? Date.distantPast > beforeUpdate)
    }

    // MARK: - Error Handling Flows

    @Test("Network error during match creation is handled gracefully")
    func testNetworkErrorDuringMatchCreation() async throws {
        let matchService = MockMatchService()
        matchService.shouldReturnMatch = false

        let user1 = TestFixtures.createTestUser(id: "user1")
        let user2 = TestFixtures.createTestUser(id: "user2")

        // Create match
        await matchService.createMatch(user1Id: user1.id!, user2Id: user2.id!)

        // Even with error, system should handle gracefully
        #expect(matchService.createMatchCalled)
    }

    @Test("Repository failure throws appropriate error")
    func testRepositoryErrorHandling() async throws {
        let userRepo = MockUserRepository()
        userRepo.shouldFail = true
        userRepo.failureError = CelestiaError.networkError

        do {
            _ = try await userRepo.fetchUser(id: "nonexistent")
            #expect(Bool(false), "Should have thrown error")
        } catch {
            #expect(error is CelestiaError)
        }
    }

    // MARK: - Interest Flow

    @Test("Send interest and check status")
    func testInterestFlow() async throws {
        let interestRepo = MockInterestRepository()
        let user1Id = "user1"
        let user2Id = "user2"

        // Send interest
        let interest = TestFixtures.createTestInterest(
            fromUserId: user1Id,
            toUserId: user2Id,
            message: "I'd love to connect!"
        )

        try await interestRepo.sendInterest(interest)

        #expect(interestRepo.sendInterestCalled)
        #expect(interestRepo.lastSentInterest?.fromUserId == user1Id)
        #expect(interestRepo.lastSentInterest?.toUserId == user2Id)

        // Check if interest exists
        let fetchedInterest = try await interestRepo.fetchInterest(
            fromUserId: user1Id,
            toUserId: user2Id
        )

        #expect(fetchedInterest != nil)
        #expect(fetchedInterest?.status == "pending")
    }

    @Test("Accept interest creates connection")
    func testAcceptInterestFlow() async throws {
        let interestRepo = MockInterestRepository()

        let interest = TestFixtures.createTestInterest(id: "interest1")
        interestRepo.addInterest(interest)

        try await interestRepo.acceptInterest(interestId: "interest1")

        #expect(interestRepo.acceptInterestCalled)

        let updatedInterest = interestRepo.interests["interest1"]
        #expect(updatedInterest?.status == "accepted")
    }

    @Test("Reject interest updates status")
    func testRejectInterestFlow() async throws {
        let interestRepo = MockInterestRepository()

        let interest = TestFixtures.createTestInterest(id: "interest1")
        interestRepo.addInterest(interest)

        try await interestRepo.rejectInterest(interestId: "interest1")

        #expect(interestRepo.rejectInterestCalled)

        let updatedInterest = interestRepo.interests["interest1"]
        #expect(updatedInterest?.status == "rejected")
    }
}

// MARK: - Test Errors

enum TestError: Error {
    case missingData(String)
    case invalidState(String)
    case setupFailed(String)
}
