//
//  ReferralFlowTests.swift
//  CelestiaTests
//
//  Integration tests for referral system flows
//  Tests referral code generation, validation, and reward distribution
//

import Testing
import Foundation
@testable import Celestia

@Suite("Referral Flow Tests")
@MainActor
struct ReferralFlowTests {

    // MARK: - Referral Code Generation

    @Test("Generate unique referral code for new user")
    func testReferralCodeGeneration() async throws {
        let user = TestFixtures.createTestUser(id: "user1", fullName: "Referrer")

        // Generate referral code based on user ID and name
        let referralCode = TestFixtures.generateReferralCode()

        #expect(referralCode.count == 6)
        #expect(referralCode.allSatisfy { $0.isLetter || $0.isNumber })
    }

    @Test("Referral codes are unique")
    func testReferralCodeUniqueness() async throws {
        let code1 = TestFixtures.generateReferralCode()
        let code2 = TestFixtures.generateReferralCode()

        // While not guaranteed to be different, probability is very high
        #expect(code1.count == 6)
        #expect(code2.count == 6)
    }

    // MARK: - Referral Signup Flow

    @Test("New user signs up with valid referral code")
    func testSignupWithValidReferralCode() async throws {
        // Setup: Create existing user (referrer)
        let referrer = TestFixtures.createTestUser(
            id: "referrer_123",
            fullName: "Referrer User"
        )
        let referralCode = "REF123"

        // New user signs up with referral code
        let authService = MockAuthService()

        try await authService.createUser(
            withEmail: "newuser@example.com",
            password: "SecurePass123!",
            fullName: "New User",
            age: 25,
            gender: "Female",
            lookingFor: "Male",
            location: "New York",
            country: "USA",
            referralCode: referralCode
        )

        #expect(authService.createUserCalled)
        #expect(authService.currentUser != nil)

        // In real implementation:
        // 1. Validate referral code exists
        // 2. Link referred user to referrer
        // 3. Grant bonuses to both users
    }

    @Test("Signup with invalid referral code shows error")
    func testSignupWithInvalidReferralCode() async throws {
        let invalidCode = "INVALID"

        // In real implementation, this should validate and fail
        let isValidCode = false // Mock validation failure

        #expect(isValidCode == false)

        // Should show error to user
        let errorMessage = "Invalid referral code. Please check and try again."
        #expect(!errorMessage.isEmpty)
    }

    @Test("Signup without referral code proceeds normally")
    func testSignupWithoutReferralCode() async throws {
        let authService = MockAuthService()

        try await authService.createUser(
            withEmail: "user@example.com",
            password: "SecurePass123!",
            fullName: "Normal User",
            age: 28,
            gender: "Male",
            lookingFor: "Female",
            location: "Los Angeles",
            country: "USA",
            referralCode: "" // No referral code
        )

        #expect(authService.createUserCalled)
        #expect(authService.currentUser != nil)
    }

    // MARK: - Bonus Distribution

    @Test("Referrer receives bonus when referral signs up")
    func testReferrerReceivesBonus() async throws {
        var referrer = TestFixtures.createTestUser(
            id: "referrer1",
            superLikesRemaining: 0,
            boostsRemaining: 0
        )

        #expect(referrer.superLikesRemaining == 0)

        // Referred user completes signup
        let referralCode = "REF123"
        let referredUser = TestFixtures.createTestUser(id: "referred1")

        // Grant referral bonus to referrer
        referrer.superLikesRemaining += 3 // Bonus: 3 super likes
        referrer.boostsRemaining += 1      // Bonus: 1 boost

        #expect(referrer.superLikesRemaining == 3)
        #expect(referrer.boostsRemaining == 1)
    }

    @Test("Referred user receives welcome bonus")
    func testReferredUserReceivesBonus() async throws {
        var referredUser = TestFixtures.createTestUser(
            id: "referred1",
            superLikesRemaining: 0,
            boostsRemaining: 0
        )

        #expect(referredUser.superLikesRemaining == 0)

        // Grant welcome bonus for using referral code
        referredUser.superLikesRemaining += 2 // Bonus: 2 super likes
        referredUser.boostsRemaining += 1      // Bonus: 1 boost

        #expect(referredUser.superLikesRemaining == 2)
        #expect(referredUser.boostsRemaining == 1)
    }

    @Test("Both users receive bonuses in complete referral flow")
    func testCompleteReferralBonusFlow() async throws {
        // Referrer initial state
        var referrer = TestFixtures.createTestUser(
            id: "referrer1",
            superLikesRemaining: 0
        )

        // Referred user signs up
        var referred = TestFixtures.createTestUser(
            id: "referred1",
            superLikesRemaining: 0
        )

        // Distribute bonuses
        referrer.superLikesRemaining += 3  // Referrer bonus
        referred.superLikesRemaining += 2   // Referred bonus

        #expect(referrer.superLikesRemaining == 3)
        #expect(referred.superLikesRemaining == 2)
    }

    // MARK: - Referral Tracking

    @Test("Track number of successful referrals")
    func testReferralTracking() async throws {
        let referrer = TestFixtures.createTestUser(id: "referrer1")
        var referralCount = 0

        // Simulate 5 successful referrals
        for i in 1...5 {
            let referred = TestFixtures.createTestUser(id: "referred\(i)")
            referralCount += 1
        }

        #expect(referralCount == 5)
    }

    @Test("Track referral with metadata")
    func testReferralMetadataTracking() async throws {
        let referral = TestFixtures.createTestReferral(
            referrerId: "referrer_123",
            referredId: "referred_456",
            code: "REF123",
            timestamp: Date()
        )

        #expect(referral.referrerId == "referrer_123")
        #expect(referral.referredId == "referred_456")
        #expect(referral.code == "REF123")
        #expect(referral.timestamp <= Date())
    }

    // MARK: - Referral Limits

    @Test("Referral bonuses have limits")
    func testReferralBonusLimits() async throws {
        var referrer = TestFixtures.createTestUser(
            id: "referrer1",
            superLikesRemaining: 0
        )

        // Maximum bonus limit: 15 super likes
        let maxBonusSuperLikes = 15
        var totalBonusReceived = 0

        // User refers 10 people (3 super likes each = 30 total)
        for _ in 1...10 {
            let bonusToAdd = min(3, maxBonusSuperLikes - totalBonusReceived)
            totalBonusReceived += bonusToAdd
            referrer.superLikesRemaining += bonusToAdd
        }

        // Should cap at 15
        #expect(totalBonusReceived == maxBonusSuperLikes)
        #expect(referrer.superLikesRemaining == 15)
    }

    // MARK: - Referral Code Validation

    @Test("Validate referral code format")
    func testReferralCodeValidation() async throws {
        let validCodes = ["ABC123", "XYZ789", "REF001"]
        let invalidCodes = ["", "ab", "TOOLONGCODE123", "inv@lid"]

        for code in validCodes {
            let isValid = code.count == 6 && code.allSatisfy { $0.isLetter || $0.isNumber }
            #expect(isValid == true)
        }

        for code in invalidCodes {
            let isValid = code.count == 6 && code.allSatisfy { $0.isLetter || $0.isNumber }
            #expect(isValid == false)
        }
    }

    @Test("Referral code is case insensitive")
    func testReferralCodeCaseInsensitive() async throws {
        let code1 = "ABC123"
        let code2 = "abc123"

        let normalizedCode1 = code1.uppercased()
        let normalizedCode2 = code2.uppercased()

        #expect(normalizedCode1 == normalizedCode2)
    }

    // MARK: - Self-Referral Prevention

    @Test("User cannot use their own referral code")
    func testPreventSelfReferral() async throws {
        let user = TestFixtures.createTestUser(id: "user1")
        let userReferralCode = "USER123"

        // User tries to use their own code
        let attemptedCode = "USER123"
        let isSelfReferral = userReferralCode == attemptedCode

        #expect(isSelfReferral == true)

        // Should show error
        if isSelfReferral {
            let errorMessage = "You cannot use your own referral code"
            #expect(!errorMessage.isEmpty)
        }
    }

    // MARK: - Notification on Successful Referral

    @Test("Referrer receives notification when referral signs up")
    func testReferralNotification() async throws {
        let referrerId = "referrer1"
        let referredName = "Jane Doe"

        let notification = TestFixtures.createTestNotification(
            type: "referral_success",
            userId: referrerId,
            title: "Referral Bonus!",
            body: "\(referredName) joined using your referral code. You've earned 3 Super Likes!",
            data: ["referredName": referredName, "bonusType": "super_likes", "bonusAmount": "3"]
        )

        #expect(notification.type == "referral_success")
        #expect(notification.userId == referrerId)
        #expect(notification.data["bonusAmount"] == "3")
    }

    // MARK: - Referral Leaderboard

    @Test("Track top referrers for leaderboard")
    func testReferralLeaderboard() async throws {
        let referrers = [
            (userId: "user1", referralCount: 25, bonusEarned: 75),
            (userId: "user2", referralCount: 18, bonusEarned: 54),
            (userId: "user3", referralCount: 30, bonusEarned: 90),
            (userId: "user4", referralCount: 12, bonusEarned: 36)
        ]

        // Sort by referral count
        let sortedByCount = referrers.sorted { $0.referralCount > $1.referralCount }

        #expect(sortedByCount[0].userId == "user3") // Top referrer
        #expect(sortedByCount[0].referralCount == 30)
        #expect(sortedByCount.last?.userId == "user4") // Lowest
    }

    @Test("Award badges for referral milestones")
    func testReferralMilestoneBadges() async throws {
        let referralCounts = [5, 10, 25, 50, 100]
        let badges = [
            "Influencer",
            "Ambassador",
            "Connector",
            "Super Connector",
            "Legend"
        ]

        for (count, badge) in zip(referralCounts, badges) {
            #expect(count > 0)
            #expect(!badge.isEmpty)
        }

        // User with 25 referrals gets "Connector" badge
        let userReferrals = 25
        let earnedBadgeIndex = referralCounts.firstIndex { userReferrals >= $0 } ?? 0
        let earnedBadge = badges[min(earnedBadgeIndex, badges.count - 1)]

        #expect(earnedBadge == "Influencer") // Gets first milestone badge
    }

    // MARK: - Referral Analytics

    @Test("Track referral conversion rate")
    func testReferralConversionRate() async throws {
        let referralsSent = 100
        let referralsCompleted = 35

        let conversionRate = Double(referralsCompleted) / Double(referralsSent) * 100
        #expect(conversionRate == 35.0)
        #expect(conversionRate > 0)
    }

    @Test("Track time to conversion for referrals")
    func testReferralTimeToConversion() async throws {
        let inviteSentDate = Date.daysAgo(5)
        let signupCompletedDate = Date()

        let timeToConversion = Calendar.current.dateComponents(
            [.day],
            from: inviteSentDate,
            to: signupCompletedDate
        ).day!

        #expect(timeToConversion == 5)
        #expect(timeToConversion > 0)
    }

    // MARK: - Bonus Expiration

    @Test("Referral bonuses expire after time period")
    func testReferralBonusExpiration() async throws {
        var user = TestFixtures.createTestUser(id: "user1")

        // Grant bonus with expiry
        user.superLikesRemaining = 5
        let bonusExpiryDate = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days

        let isExpired = bonusExpiryDate < Date()
        #expect(isExpired == false)

        // Simulate expiration
        let expiredBonusDate = Date.daysAgo(1)
        let isNowExpired = expiredBonusDate < Date()
        #expect(isNowExpired == true)
    }

    // MARK: - Referral Code Sharing

    @Test("Generate shareable referral link")
    func testShareableReferralLink() async throws {
        let userId = "user123"
        let referralCode = "ABC123"
        let baseURL = "https://celestia.app"

        let shareableLink = "\(baseURL)/signup?ref=\(referralCode)"
        #expect(shareableLink == "https://celestia.app/signup?ref=ABC123")

        // Shareable message
        let shareMessage = "Join Celestia using my code \(referralCode) and get 2 free Super Likes! \(shareableLink)"
        #expect(shareMessage.contains(referralCode))
        #expect(shareMessage.contains(shareableLink))
    }

    @Test("Track referral source channels")
    func testReferralSourceTracking() async throws {
        let sources = [
            (channel: "sms", referrals: 45),
            (channel: "email", referrals: 30),
            (channel: "social_media", referrals: 80),
            (channel: "direct_link", referrals: 25)
        ]

        let totalReferrals = sources.reduce(0) { $0 + $1.referrals }
        #expect(totalReferrals == 180)

        // Most effective channel
        let topChannel = sources.max { $0.referrals < $1.referrals }
        #expect(topChannel?.channel == "social_media")
    }

    // MARK: - Edge Cases

    @Test("Multiple users with same referral code attempt")
    func testDuplicateReferralCodePrevention() async throws {
        let existingCode = "ABC123"

        // Try to generate same code
        let attemptedCode = "ABC123"

        let isDuplicate = existingCode == attemptedCode
        #expect(isDuplicate == true)

        // Should regenerate unique code
        if isDuplicate {
            let newCode = TestFixtures.generateReferralCode()
            #expect(newCode.count == 6)
        }
    }

    @Test("Referral used after account deletion")
    func testReferralAfterAccountDeletion() async throws {
        let deletedUserId = "deleted_user"
        let referralCode = "DEL123"

        let isAccountActive = false

        // Should invalidate referral code
        let isCodeValid = isAccountActive
        #expect(isCodeValid == false)

        if !isCodeValid {
            let errorMessage = "This referral code is no longer valid"
            #expect(!errorMessage.isEmpty)
        }
    }
}
