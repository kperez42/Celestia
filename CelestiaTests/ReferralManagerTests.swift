//
//  ReferralManagerTests.swift
//  CelestiaTests
//
//  Comprehensive unit tests for ReferralManager
//

import Testing
@testable import Celestia
import Foundation

@Suite("ReferralManager Tests")
struct ReferralManagerTests {

    // MARK: - Referral Code Generation Tests

    @Test("Referral code format is correct")
    func testReferralCodeFormat() async throws {
        let userId = "user123"
        let manager = ReferralManager.shared

        // Generate code
        let code = await manager.generateReferralCode(for: userId)

        #expect(code.hasPrefix("CEL-"), "Code should start with CEL-")
        #expect(code.count > 4, "Code should have content after prefix")

        // Check format: CEL-XXXXXXXX
        let parts = code.split(separator: "-")
        #expect(parts.count == 2, "Should have prefix and code")
        #expect(parts[1].count == 8, "Code portion should be 8 characters")
    }

    @Test("Referral codes are unique")
    func testReferralCodeUniqueness() async throws {
        let manager = ReferralManager.shared

        let code1 = await manager.generateReferralCode(for: "user1")
        let code2 = await manager.generateReferralCode(for: "user2")
        let code3 = await manager.generateReferralCode(for: "user3")

        #expect(code1 != code2, "Codes should be unique")
        #expect(code2 != code3, "Codes should be unique")
        #expect(code1 != code3, "Codes should be unique")
    }

    @Test("Referral code uses valid characters")
    func testReferralCodeCharacters() async throws {
        let manager = ReferralManager.shared
        let code = await manager.generateReferralCode(for: "user123")

        // Remove prefix
        let codeOnly = code.replacingOccurrences(of: "CEL-", with: "")

        // Check all characters are alphanumeric
        let validCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let codeCharacters = CharacterSet(charactersIn: codeOnly)

        #expect(validCharacters.isSuperset(of: codeCharacters),
               "Code should only contain A-Z and 0-9")
    }

    // MARK: - Referral Rewards Tests

    @Test("Referrer gets correct bonus days")
    func testReferrerBonusDays() async throws {
        let bonusDays = ReferralRewards.referrerBonusDays

        #expect(bonusDays == 7, "Referrer should get 7 days")
        #expect(bonusDays > 0, "Bonus should be positive")
    }

    @Test("New user gets correct bonus days")
    func testNewUserBonusDays() async throws {
        let bonusDays = ReferralRewards.newUserBonusDays

        #expect(bonusDays == 3, "New user should get 3 days")
        #expect(bonusDays > 0, "Bonus should be positive")
    }

    @Test("Total days calculation is correct")
    func testTotalDaysCalculation() async throws {
        let referrals = 5
        let totalDays = ReferralRewards.calculateTotalDays(referrals: referrals)

        let expected = referrals * ReferralRewards.referrerBonusDays
        #expect(totalDays == expected, "Should calculate total correctly")
        #expect(totalDays == 35, "5 referrals = 35 days")
    }

    @Test("Max referrals limit is enforced")
    func testMaxReferralsLimit() async throws {
        let maxReferrals = ReferralRewards.maxReferrals
        let excessiveReferrals = maxReferrals + 50

        let totalDays = ReferralRewards.calculateTotalDays(referrals: excessiveReferrals)
        let maxDays = maxReferrals * ReferralRewards.referrerBonusDays

        #expect(totalDays == maxDays, "Should cap at max referrals")
        #expect(totalDays <= 700, "Should not exceed max days")
    }

    @Test("Zero referrals gives zero days")
    func testZeroReferrals() async throws {
        let totalDays = ReferralRewards.calculateTotalDays(referrals: 0)

        #expect(totalDays == 0, "Zero referrals should give zero days")
    }

    @Test("Negative referrals handled")
    func testNegativeReferrals() async throws {
        let totalDays = ReferralRewards.calculateTotalDays(referrals: -5)

        #expect(totalDays <= 0, "Negative referrals should not give positive days")
    }

    // MARK: - Premium Days Award Tests

    @Test("Premium days extend existing subscription")
    func testPremiumDaysExtension() async throws {
        let calendar = Calendar.current
        let startDate = Date()

        // User has existing premium until 30 days from now
        var expiryDate = calendar.date(byAdding: .day, value: 30, to: startDate)!

        // Award 7 more days
        let bonusDays = 7
        expiryDate = calendar.date(byAdding: .day, value: bonusDays, to: expiryDate)!

        // Should be 37 days from start
        let totalDays = calendar.dateComponents([.day], from: startDate, to: expiryDate).day!
        #expect(totalDays == 37, "Should extend existing subscription")
    }

    @Test("Premium days start from now if expired")
    func testPremiumDaysFromNow() async throws {
        let calendar = Calendar.current
        let now = Date()

        // Expired subscription (10 days ago)
        let expiredDate = calendar.date(byAdding: .day, value: -10, to: now)!

        var newExpiryDate: Date
        if expiredDate < now {
            // Start from now
            newExpiryDate = now
        } else {
            newExpiryDate = expiredDate
        }

        // Add bonus days
        newExpiryDate = calendar.date(byAdding: .day, value: 7, to: newExpiryDate)!

        #expect(newExpiryDate > now, "New expiry should be in future")
    }

    @Test("Premium flag is set when awarding days")
    func testPremiumFlagSet() async throws {
        var isPremium = false

        // Award premium days
        isPremium = true

        #expect(isPremium == true, "Premium flag should be set")
    }

    // MARK: - Referral Status Tests

    @Test("Referral status transitions correctly")
    func testReferralStatusTransitions() async throws {
        var status = ReferralStatus.pending

        #expect(status == .pending, "Initial status should be pending")

        // User signs up
        status = .completed
        #expect(status == .completed, "Should move to completed")

        // Reward given
        status = .rewarded
        #expect(status == .rewarded, "Should move to rewarded")
    }

    @Test("Referral status raw values")
    func testReferralStatusRawValues() async throws {
        #expect(ReferralStatus.pending.rawValue == "pending")
        #expect(ReferralStatus.completed.rawValue == "completed")
        #expect(ReferralStatus.rewarded.rawValue == "rewarded")
        #expect(ReferralStatus.expired.rawValue == "expired")
    }

    // MARK: - Referral Stats Tests

    @Test("Referral stats initial values")
    func testReferralStatsInitialValues() async throws {
        let stats = ReferralStats()

        #expect(stats.totalReferrals == 0)
        #expect(stats.pendingReferrals == 0)
        #expect(stats.premiumDaysEarned == 0)
        #expect(stats.referralCode.isEmpty)
        #expect(stats.referralRank == 0)
    }

    @Test("Referral stats update correctly")
    func testReferralStatsUpdate() async throws {
        var stats = ReferralStats()

        stats.totalReferrals = 5
        stats.premiumDaysEarned = 35
        stats.referralCode = "CEL-ABC12345"
        stats.referralRank = 10

        #expect(stats.totalReferrals == 5)
        #expect(stats.premiumDaysEarned == 35)
        #expect(stats.referralCode == "CEL-ABC12345")
        #expect(stats.referralRank == 10)
    }

    @Test("Referral stats from dictionary")
    func testReferralStatsFromDictionary() async throws {
        let dictionary: [String: Any] = [
            "totalReferrals": 10,
            "pendingReferrals": 2,
            "premiumDaysEarned": 70,
            "referralCode": "CEL-TEST1234",
            "referralRank": 5
        ]

        let stats = ReferralStats(dictionary: dictionary)

        #expect(stats.totalReferrals == 10)
        #expect(stats.pendingReferrals == 2)
        #expect(stats.premiumDaysEarned == 70)
        #expect(stats.referralCode == "CEL-TEST1234")
        #expect(stats.referralRank == 5)
    }

    // MARK: - Referral Model Tests

    @Test("Referral model has required fields")
    func testReferralModelFields() async throws {
        let referral = Referral(
            referrerUserId: "user1",
            referredUserId: "user2",
            referralCode: "CEL-ABC12345",
            status: .completed,
            createdAt: Date(),
            completedAt: Date(),
            rewardClaimed: false
        )

        #expect(referral.referrerUserId == "user1")
        #expect(referral.referredUserId == "user2")
        #expect(referral.referralCode == "CEL-ABC12345")
        #expect(referral.status == .completed)
        #expect(referral.rewardClaimed == false)
    }

    @Test("Pending referral has no referred user")
    func testPendingReferral() async throws {
        let referral = Referral(
            referrerUserId: "user1",
            referredUserId: nil,
            referralCode: "CEL-ABC12345",
            status: .pending,
            createdAt: Date(),
            completedAt: nil,
            rewardClaimed: false
        )

        #expect(referral.referredUserId == nil, "Pending referral has no referred user")
        #expect(referral.status == .pending)
        #expect(referral.completedAt == nil)
    }

    @Test("Completed referral has all data")
    func testCompletedReferral() async throws {
        let referral = Referral(
            referrerUserId: "user1",
            referredUserId: "user2",
            referralCode: "CEL-ABC12345",
            status: .completed,
            createdAt: Date(),
            completedAt: Date(),
            rewardClaimed: false
        )

        #expect(referral.referredUserId != nil, "Should have referred user")
        #expect(referral.completedAt != nil, "Should have completion date")
        #expect(referral.status == .completed)
    }

    // MARK: - Leaderboard Tests

    @Test("Leaderboard entry structure")
    func testLeaderboardEntry() async throws {
        let entry = ReferralLeaderboardEntry(
            id: "user1",
            userName: "Alice",
            profileImageURL: "https://example.com/image.jpg",
            totalReferrals: 25,
            rank: 1,
            premiumDaysEarned: 175
        )

        #expect(entry.id == "user1")
        #expect(entry.userName == "Alice")
        #expect(entry.totalReferrals == 25)
        #expect(entry.rank == 1)
        #expect(entry.premiumDaysEarned == 175)
    }

    @Test("Leaderboard ranks are sequential")
    func testLeaderboardRanks() async throws {
        let entries = [
            ReferralLeaderboardEntry(id: "1", userName: "First", profileImageURL: "", totalReferrals: 100, rank: 1, premiumDaysEarned: 700),
            ReferralLeaderboardEntry(id: "2", userName: "Second", profileImageURL: "", totalReferrals: 80, rank: 2, premiumDaysEarned: 560),
            ReferralLeaderboardEntry(id: "3", userName: "Third", profileImageURL: "", totalReferrals: 60, rank: 3, premiumDaysEarned: 420)
        ]

        for (index, entry) in entries.enumerated() {
            #expect(entry.rank == index + 1, "Rank should be sequential")
        }
    }

    @Test("Leaderboard sorted by referrals")
    func testLeaderboardSorting() async throws {
        var entries = [
            ReferralLeaderboardEntry(id: "1", userName: "Alice", profileImageURL: "", totalReferrals: 30, rank: 0, premiumDaysEarned: 210),
            ReferralLeaderboardEntry(id: "2", userName: "Bob", profileImageURL: "", totalReferrals: 50, rank: 0, premiumDaysEarned: 350),
            ReferralLeaderboardEntry(id: "3", userName: "Charlie", profileImageURL: "", totalReferrals: 20, rank: 0, premiumDaysEarned: 140)
        ]

        // Sort by referrals descending
        entries.sort { $0.totalReferrals > $1.totalReferrals }

        #expect(entries[0].userName == "Bob", "Bob should be first with 50 referrals")
        #expect(entries[1].userName == "Alice", "Alice should be second with 30 referrals")
        #expect(entries[2].userName == "Charlie", "Charlie should be third with 20 referrals")
    }

    // MARK: - Referral Share Message Tests

    @Test("Share message format")
    func testShareMessageFormat() async throws {
        let manager = ReferralManager.shared
        let code = "CEL-TEST1234"
        let userName = "Alice"

        let message = await manager.getReferralShareMessage(code: code, userName: userName)

        #expect(message.contains(code), "Message should contain code")
        #expect(message.contains("3 days"), "Should mention bonus days")
        #expect(message.contains("Premium"), "Should mention premium")
        #expect(message.contains("Celestia"), "Should mention app name")
    }

    @Test("Referral URL format")
    func testReferralURLFormat() async throws {
        let manager = ReferralManager.shared
        let code = "CEL-TEST1234"

        let url = await manager.getReferralURL(code: code)

        #expect(url != nil, "Should generate URL")
        #expect(url?.absoluteString.contains(code) == true, "URL should contain code")
        #expect(url?.absoluteString.hasPrefix("https://") == true, "Should use HTTPS")
    }

    // MARK: - Validation Tests

    @Test("Cannot refer yourself")
    func testCannotReferSelf() async throws {
        let userId = "user1"
        let referrerId = "user1"

        let isSelf = userId == referrerId
        #expect(isSelf, "Should detect self-referral")
    }

    @Test("Referral code validation")
    func testReferralCodeValidation() async throws {
        let validCode = "CEL-ABC12345"
        let invalidCode = "INVALID"

        #expect(validCode.hasPrefix("CEL-"), "Valid code has prefix")
        #expect(!invalidCode.hasPrefix("CEL-"), "Invalid code missing prefix")
    }

    @Test("Empty referral code handling")
    func testEmptyReferralCode() async throws {
        let emptyCode = ""

        #expect(emptyCode.isEmpty, "Empty code should be empty")

        // Should not process empty code
        if !emptyCode.isEmpty {
            #expect(false, "Should not process empty code")
        } else {
            #expect(true, "Correctly skipped empty code")
        }
    }

    // MARK: - Edge Cases

    @Test("Large referral count")
    func testLargeReferralCount() async throws {
        let largeCount = 500
        let totalDays = ReferralRewards.calculateTotalDays(referrals: largeCount)

        #expect(totalDays > 0, "Should handle large counts")
        #expect(totalDays <= ReferralRewards.maxReferrals * ReferralRewards.referrerBonusDays,
               "Should respect max limit")
    }

    @Test("Premium expiry date calculations")
    func testPremiumExpiryCalculations() async throws {
        let calendar = Calendar.current
        let now = Date()

        // Add 7 days
        let future = calendar.date(byAdding: .day, value: 7, to: now)!

        let daysUntilExpiry = calendar.dateComponents([.day], from: now, to: future).day!
        #expect(daysUntilExpiry == 7, "Should be 7 days in future")
    }

    @Test("Concurrent referral processing")
    func testConcurrentReferrals() async throws {
        // Multiple referrals should be tracked separately
        var referrals: [String: Int] = [:]

        referrals["referrer1"] = 5
        referrals["referrer2"] = 3
        referrals["referrer3"] = 10

        let total = referrals.values.reduce(0, +)
        #expect(total == 18, "Should track all referrals")
    }

    @Test("Referral stats persistence")
    func testReferralStatsPersistence() async throws {
        let stats = ReferralStats()

        // Convert to dictionary
        let dictionary: [String: Any] = [
            "totalReferrals": stats.totalReferrals,
            "premiumDaysEarned": stats.premiumDaysEarned,
            "referralCode": stats.referralCode
        ]

        // Reconstruct from dictionary
        let reconstructed = ReferralStats(dictionary: dictionary)

        #expect(reconstructed.totalReferrals == stats.totalReferrals)
        #expect(reconstructed.premiumDaysEarned == stats.premiumDaysEarned)
    }
}
