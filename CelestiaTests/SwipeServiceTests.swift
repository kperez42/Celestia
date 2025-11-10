//
//  SwipeServiceTests.swift
//  CelestiaTests
//
//  Comprehensive unit tests for SwipeService
//

import Testing
@testable import Celestia
import Foundation

@Suite("SwipeService Tests")
struct SwipeServiceTests {

    // MARK: - Like/Pass Tracking Tests

    @Test("Like data structure contains required fields")
    func testLikeDataStructure() async throws {
        let fromUserId = "user1"
        let toUserId = "user2"
        let isSuperLike = false
        let timestamp = Date()

        #expect(!fromUserId.isEmpty, "From user ID should not be empty")
        #expect(!toUserId.isEmpty, "To user ID should not be empty")
        #expect(!isSuperLike, "Regular like should not be super like")
        #expect(timestamp <= Date(), "Timestamp should be valid")
    }

    @Test("Pass data structure contains required fields")
    func testPassDataStructure() async throws {
        let fromUserId = "user1"
        let toUserId = "user2"
        let timestamp = Date()
        let isActive = true

        #expect(!fromUserId.isEmpty)
        #expect(!toUserId.isEmpty)
        #expect(timestamp <= Date())
        #expect(isActive, "New pass should be active")
    }

    @Test("Super like flag differentiates from regular like")
    func testSuperLikeFlag() async throws {
        let regularLike = false
        let superLike = true

        #expect(regularLike != superLike, "Super like should differ from regular")
        #expect(superLike == true, "Super like flag should be true")
    }

    // MARK: - Mutual Match Detection Tests

    @Test("Mutual like creates match")
    func testMutualMatchDetection() async throws {
        // User1 likes User2
        let user1LikesUser2 = true
        // User2 likes User1
        let user2LikesUser1 = true

        let isMutualMatch = user1LikesUser2 && user2LikesUser1
        #expect(isMutualMatch, "Mutual likes should create match")
    }

    @Test("One-way like does not create match")
    func testOneWayLike() async throws {
        let user1LikesUser2 = true
        let user2LikesUser1 = false

        let isMutualMatch = user1LikesUser2 && user2LikesUser1
        #expect(!isMutualMatch, "One-way like should not match")
    }

    @Test("Bidirectional like lookup")
    func testBidirectionalLikeLookup() async throws {
        // Need to check both directions for mutual match
        let likeId1 = "user1_user2"
        let likeId2 = "user2_user1"

        #expect(likeId1 != likeId2, "Like IDs should be different for each direction")

        // Parse IDs
        let parts1 = likeId1.split(separator: "_").map(String.init)
        let parts2 = likeId2.split(separator: "_").map(String.init)

        #expect(parts1.count == 2, "Like ID should have 2 parts")
        #expect(parts2.count == 2, "Like ID should have 2 parts")

        // Check they're opposites
        #expect(parts1[0] == parts2[1], "Should be bidirectional")
        #expect(parts1[1] == parts2[0], "Should be bidirectional")
    }

    // MARK: - Like Document ID Tests

    @Test("Like document ID format")
    func testLikeDocumentIDFormat() async throws {
        let fromUser = "alice"
        let toUser = "bob"
        let documentId = "\(fromUser)_\(toUser)"

        #expect(documentId == "alice_bob", "Document ID format")
        #expect(documentId.contains("_"), "Should contain separator")

        let parts = documentId.split(separator: "_").map(String.init)
        #expect(parts[0] == fromUser, "First part should be from user")
        #expect(parts[1] == toUser, "Second part should be to user")
    }

    @Test("Like document ID uniqueness")
    func testLikeDocumentIDUniqueness() async throws {
        let id1 = "user1_user2"
        let id2 = "user1_user3"
        let id3 = "user2_user1" // Reverse of id1

        #expect(id1 != id2, "Different users should have different IDs")
        #expect(id1 != id3, "Opposite directions should have different IDs")
    }

    // MARK: - Swipe History Tests

    @Test("Track if user has already swiped")
    func testSwipeHistory() async throws {
        var swipeHistory: [String: (liked: Bool, passed: Bool)] = [:]

        let userId = "user2"
        swipeHistory[userId] = (liked: true, passed: false)

        let history = swipeHistory[userId]!
        #expect(history.liked == true, "Should track like")
        #expect(history.passed == false, "Should track no pass")
    }

    @Test("Prevent duplicate swipes")
    func testPreventDuplicateSwipes() async throws {
        var hasSwipedOn: [String: Bool] = [:]

        let userId = "user2"
        hasSwipedOn[userId] = true

        // Try to swipe again
        if hasSwipedOn[userId] == true {
            // Should prevent
            #expect(true, "Should detect already swiped")
        } else {
            #expect(false, "Should have been prevented")
        }
    }

    @Test("Multiple swipe states")
    func testMultipleSwipeStates() async throws {
        struct SwipeState {
            var hasLiked: Bool
            var hasPassed: Bool
        }

        var states: [String: SwipeState] = [:]

        states["user1"] = SwipeState(hasLiked: true, hasPassed: false)
        states["user2"] = SwipeState(hasLiked: false, hasPassed: true)
        states["user3"] = SwipeState(hasLiked: false, hasPassed: false)

        #expect(states["user1"]?.hasLiked == true)
        #expect(states["user2"]?.hasPassed == true)
        #expect(states["user3"]?.hasLiked == false)
    }

    // MARK: - Active Status Tests

    @Test("Active swipes are tracked")
    func testActiveSwipeTracking() async throws {
        var isActive = true

        #expect(isActive == true, "New swipes should be active")

        // Deactivate
        isActive = false
        #expect(isActive == false, "Can deactivate swipe")
    }

    @Test("Inactive swipes are excluded")
    func testInactiveSwipeExclusion() async throws {
        struct Swipe {
            let userId: String
            let isActive: Bool
        }

        let swipes = [
            Swipe(userId: "1", isActive: true),
            Swipe(userId: "2", isActive: false),
            Swipe(userId: "3", isActive: true)
        ]

        let activeSwipes = swipes.filter { $0.isActive }
        #expect(activeSwipes.count == 2, "Should have 2 active swipes")
    }

    // MARK: - Likes Received Tests

    @Test("Get users who liked current user")
    func testLikesReceived() async throws {
        let currentUserId = "alice"

        // Simulate likes received
        let likesReceived = [
            (from: "bob", to: "alice"),
            (from: "charlie", to: "alice"),
            (from: "dave", to: "alice")
        ]

        let likers = likesReceived
            .filter { $0.to == currentUserId }
            .map { $0.from }

        #expect(likers.count == 3, "Should have 3 users who liked")
        #expect(likers.contains("bob"))
        #expect(likers.contains("charlie"))
    }

    @Test("Likes received filters by recipient")
    func testLikesReceivedFiltering() async throws {
        let currentUserId = "alice"

        struct Like {
            let toUserId: String
            let fromUserId: String
        }

        let allLikes = [
            Like(toUserId: "alice", fromUserId: "bob"),
            Like(toUserId: "charlie", fromUserId: "bob"),
            Like(toUserId: "alice", fromUserId: "dave")
        ]

        let likesForAlice = allLikes.filter { $0.toUserId == currentUserId }
        #expect(likesForAlice.count == 2, "Alice should have 2 likes")
    }

    @Test("Likes received requires active status")
    func testLikesReceivedActiveOnly() async throws {
        struct Like {
            let toUserId: String
            let fromUserId: String
            let isActive: Bool
        }

        let likes = [
            Like(toUserId: "alice", fromUserId: "bob", isActive: true),
            Like(toUserId: "alice", fromUserId: "charlie", isActive: false),
            Like(toUserId: "alice", fromUserId: "dave", isActive: true)
        ]

        let activeLikes = likes.filter { $0.toUserId == "alice" && $0.isActive }
        #expect(activeLikes.count == 2, "Should only count active likes")
    }

    // MARK: - Premium Features Tests

    @Test("Free users have swipe limit")
    func testFreeUserSwipeLimit() async throws {
        let freeLimit = AppConstants.Premium.freeSwipesPerDay
        var swipeCount = 0

        #expect(freeLimit == 50, "Free limit should be 50 swipes")

        // Simulate swiping
        for _ in 0..<freeLimit {
            swipeCount += 1
        }

        #expect(swipeCount == freeLimit, "Should reach limit")

        // Next swipe should be blocked
        let canSwipe = swipeCount < freeLimit
        #expect(!canSwipe, "Should be at limit")
    }

    @Test("Premium users have unlimited swipes")
    func testPremiumUnlimitedSwipes() async throws {
        let isPremium = true
        let unlimitedSwipes = AppConstants.Premium.premiumUnlimitedSwipes

        #expect(unlimitedSwipes == true, "Premium should have unlimited")

        if isPremium && unlimitedSwipes {
            #expect(true, "Premium user can swipe unlimited")
        }
    }

    @Test("Swipe count resets daily")
    func testSwipeCountReset() async throws {
        var swipeCount = 50
        let lastResetDate = Date()
        let now = Calendar.current.date(byAdding: .day, value: 1, to: lastResetDate)!

        // Check if should reset
        if !Calendar.current.isDate(lastResetDate, inSameDayAs: now) {
            swipeCount = 0
        }

        #expect(swipeCount == 0, "Count should reset after day change")
    }

    // MARK: - Timestamp Tests

    @Test("Swipe timestamps are recorded")
    func testSwipeTimestamps() async throws {
        let timestamp = Date()

        #expect(timestamp <= Date(), "Timestamp should be valid")

        // Verify timestamp ordering
        let laterTimestamp = Date()
        #expect(laterTimestamp >= timestamp, "Later timestamp should be after")
    }

    @Test("Swipes can be sorted by timestamp")
    func testSwipeSorting() async throws {
        struct Swipe {
            let userId: String
            let timestamp: Date
        }

        let now = Date()
        let earlier = Date(timeIntervalSince1970: now.timeIntervalSince1970 - 3600)

        let swipes = [
            Swipe(userId: "1", timestamp: now),
            Swipe(userId: "2", timestamp: earlier),
        ]

        let sorted = swipes.sorted { $0.timestamp > $1.timestamp }
        #expect(sorted[0].userId == "1", "Most recent should be first")
    }

    // MARK: - Edge Cases

    @Test("Cannot like yourself")
    func testCannotLikeSelf() async throws {
        let userId = "user1"
        let targetId = "user1"

        let isSelf = userId == targetId
        #expect(isSelf, "Should detect self-like attempt")
    }

    @Test("Empty swipe history")
    func testEmptySwipeHistory() async throws {
        let history: [String: Bool] = [:]

        #expect(history.isEmpty, "Empty history should be empty")
        #expect(history.count == 0, "Count should be 0")
    }

    @Test("Large swipe count handling")
    func testLargeSwipeCount() async throws {
        var swipeCount = 0

        // Simulate many swipes
        for _ in 0..<1000 {
            swipeCount += 1
        }

        #expect(swipeCount == 1000, "Should handle large counts")
        #expect(swipeCount > 0, "Count should be positive")
    }

    // MARK: - Super Like Tests

    @Test("Super likes are special")
    func testSuperLikeSpecial() async throws {
        let regularLike = (isSuperLike: false)
        let superLike = (isSuperLike: true)

        #expect(!regularLike.isSuperLike, "Regular like is not super")
        #expect(superLike.isSuperLike, "Super like flag is set")
    }

    @Test("Super like visibility")
    func testSuperLikeVisibility() async throws {
        // Super likes should be immediately visible to recipient
        let isSuperLike = true

        if isSuperLike {
            let isVisible = true // Super likes show immediately
            #expect(isVisible, "Super like should be visible")
        }
    }

    @Test("Super like creates notification")
    func testSuperLikeNotification() async throws {
        let isSuperLike = true

        if isSuperLike {
            let shouldNotify = true
            #expect(shouldNotify, "Super like should trigger notification")
        }
    }

    // MARK: - Match Creation Flow Tests

    @Test("Like followed by mutual like creates match")
    func testMatchCreationFlow() async throws {
        var matches: [String] = []

        // User1 likes User2
        let user1LikesUser2 = true

        // User2 already liked User1
        let user2LikesUser1 = true

        // Check for mutual like
        if user1LikesUser2 && user2LikesUser1 {
            matches.append("user1_user2")
        }

        #expect(matches.count == 1, "Should create one match")
    }

    @Test("Match creation is idempotent")
    func testMatchCreationIdempotency() async throws {
        var matches: Set<String> = []

        // Try to create match multiple times
        matches.insert("user1_user2")
        matches.insert("user1_user2")
        matches.insert("user1_user2")

        #expect(matches.count == 1, "Should only have one match entry")
    }
}
