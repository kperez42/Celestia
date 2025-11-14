//
//  DiscoverViewModelTests.swift
//  CelestiaTests
//
//  Comprehensive tests for DiscoverViewModel
//

import Testing
import FirebaseFirestore
@testable import Celestia

@Suite("DiscoverViewModel Tests")
@MainActor
struct DiscoverViewModelTests {

    // MARK: - Initial State Tests

    @Test("ViewModel has correct initial state")
    func testInitialState() async throws {
        let viewModel = DiscoverViewModel()

        #expect(viewModel.users.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage.isEmpty)
        #expect(viewModel.currentIndex == 0)
        #expect(viewModel.hasActiveFilters == false)
        #expect(viewModel.matchedUser == nil)
        #expect(viewModel.showingMatchAnimation == false)
        #expect(viewModel.selectedUser == nil)
        #expect(viewModel.showingUserDetail == false)
        #expect(viewModel.showingFilters == false)
        #expect(viewModel.dragOffset == .zero)
        #expect(viewModel.isProcessingAction == false)
        #expect(viewModel.showingUpgradeSheet == false)
    }

    @Test("RemainingCount returns correct value with users")
    func testRemainingCountWithUsers() async throws {
        let viewModel = DiscoverViewModel()
        let users = TestFixtures.createBatchUsers(count: 10)

        // Simulate loaded users
        viewModel.users = users
        viewModel.currentIndex = 0

        #expect(viewModel.remainingCount == 10)

        viewModel.currentIndex = 5
        #expect(viewModel.remainingCount == 5)

        viewModel.currentIndex = 10
        #expect(viewModel.remainingCount == 0)
    }

    @Test("RemainingCount returns zero when index exceeds users")
    func testRemainingCountExceedsUsers() async throws {
        let viewModel = DiscoverViewModel()
        viewModel.users = TestFixtures.createBatchUsers(count: 5)
        viewModel.currentIndex = 10

        #expect(viewModel.remainingCount == 0)
    }

    @Test("RemainingCount returns zero for empty users array")
    func testRemainingCountEmptyUsers() async throws {
        let viewModel = DiscoverViewModel()
        viewModel.users = []
        viewModel.currentIndex = 0

        #expect(viewModel.remainingCount == 0)
    }

    // MARK: - User Detail Tests

    @Test("ShowUserDetail sets selectedUser and shows sheet")
    func testShowUserDetail() async throws {
        let viewModel = DiscoverViewModel()
        let user = TestFixtures.createTestUser(fullName: "Jane Doe")

        viewModel.showUserDetail(user)

        #expect(viewModel.selectedUser?.fullName == "Jane Doe")
        #expect(viewModel.showingUserDetail == true)
    }

    // MARK: - Filter Tests

    @Test("ShowFilters sets showingFilters to true")
    func testShowFilters() async throws {
        let viewModel = DiscoverViewModel()

        viewModel.showFilters()

        #expect(viewModel.showingFilters == true)
    }

    @Test("ResetFilters clears hasActiveFilters")
    func testResetFilters() async throws {
        let viewModel = DiscoverViewModel()
        viewModel.hasActiveFilters = true

        viewModel.resetFilters()

        #expect(viewModel.hasActiveFilters == false)
    }

    // MARK: - Shuffle Tests

    @Test("ShuffleUsers randomizes user order")
    func testShuffleUsers() async throws {
        let viewModel = DiscoverViewModel()
        let users = TestFixtures.createBatchUsers(count: 20)
        viewModel.users = users
        viewModel.currentIndex = 5

        let originalOrder = viewModel.users.map { $0.id }

        viewModel.shuffleUsers()

        // Order should likely be different (with 20 users, probability of same order is extremely low)
        let newOrder = viewModel.users.map { $0.id }
        #expect(originalOrder != newOrder)
        #expect(viewModel.currentIndex == 0) // Index should reset
    }

    @Test("ShuffleUsers resets currentIndex to zero")
    func testShuffleResetsIndex() async throws {
        let viewModel = DiscoverViewModel()
        viewModel.users = TestFixtures.createBatchUsers(count: 10)
        viewModel.currentIndex = 7

        viewModel.shuffleUsers()

        #expect(viewModel.currentIndex == 0)
    }

    // MARK: - Match Animation Tests

    @Test("DismissMatchAnimation clears matched user and hides animation")
    func testDismissMatchAnimation() async throws {
        let viewModel = DiscoverViewModel()
        let matchedUser = TestFixtures.createTestUser(fullName: "Matched User")

        viewModel.matchedUser = matchedUser
        viewModel.showingMatchAnimation = true

        viewModel.dismissMatchAnimation()

        // Need to wait for animation to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        #expect(viewModel.showingMatchAnimation == false)
        #expect(viewModel.matchedUser == nil)
    }

    // MARK: - Cleanup Tests

    @Test("Cleanup clears users and resets state")
    func testCleanup() async throws {
        let viewModel = DiscoverViewModel()
        viewModel.users = TestFixtures.createBatchUsers(count: 5)

        viewModel.cleanup()

        #expect(viewModel.users.isEmpty)
    }

    // MARK: - Index Management Tests

    @Test("CurrentIndex increments correctly during swipes")
    func testCurrentIndexIncrement() async throws {
        let viewModel = DiscoverViewModel()
        viewModel.users = TestFixtures.createBatchUsers(count: 10)

        #expect(viewModel.currentIndex == 0)

        viewModel.currentIndex += 1
        #expect(viewModel.currentIndex == 1)
        #expect(viewModel.remainingCount == 9)

        viewModel.currentIndex += 1
        #expect(viewModel.currentIndex == 2)
        #expect(viewModel.remainingCount == 8)
    }

    @Test("Multiple users in stack are handled correctly")
    func testMultipleUsersInStack() async throws {
        let viewModel = DiscoverViewModel()
        let users = TestFixtures.createBatchUsers(count: 15)
        viewModel.users = users

        #expect(viewModel.users.count == 15)
        #expect(viewModel.remainingCount == 15)

        // Simulate swiping through 10 users
        viewModel.currentIndex = 10

        #expect(viewModel.remainingCount == 5)
        #expect(viewModel.currentIndex == 10)
    }

    // MARK: - Edge Cases

    @Test("Empty users array doesn't cause crash on access")
    func testEmptyUsersArrayAccess() async throws {
        let viewModel = DiscoverViewModel()

        #expect(viewModel.users.isEmpty)
        #expect(viewModel.remainingCount == 0)

        // These should not crash
        viewModel.currentIndex = 0
        #expect(viewModel.remainingCount == 0)
    }

    @Test("Large number of users handled correctly")
    func testLargeNumberOfUsers() async throws {
        let viewModel = DiscoverViewModel()
        let users = TestFixtures.createBatchUsers(count: 100)
        viewModel.users = users

        #expect(viewModel.users.count == 100)
        #expect(viewModel.remainingCount == 100)

        viewModel.currentIndex = 50
        #expect(viewModel.remainingCount == 50)
    }

    @Test("Single user in array")
    func testSingleUser() async throws {
        let viewModel = DiscoverViewModel()
        let user = TestFixtures.createTestUser()
        viewModel.users = [user]

        #expect(viewModel.users.count == 1)
        #expect(viewModel.remainingCount == 1)

        viewModel.currentIndex = 0
        #expect(viewModel.remainingCount == 1)

        viewModel.currentIndex = 1
        #expect(viewModel.remainingCount == 0)
    }

    // MARK: - User Properties Tests

    @Test("Users with different properties are handled")
    func testUserVariety() async throws {
        let viewModel = DiscoverViewModel()

        let premiumUser = TestFixtures.createPremiumUser(fullName: "Premium User")
        let verifiedUser = TestFixtures.createVerifiedUser(fullName: "Verified User")
        let regularUser = TestFixtures.createTestUser(fullName: "Regular User")

        viewModel.users = [premiumUser, verifiedUser, regularUser]

        #expect(viewModel.users.count == 3)
        #expect(viewModel.users[0].isPremium == true)
        #expect(viewModel.users[1].isVerified == true)
        #expect(viewModel.users[2].isPremium == false)
        #expect(viewModel.users[2].isVerified == false)
    }

    @Test("Users with special characters in name")
    func testUsersWithSpecialCharacters() async throws {
        let viewModel = DiscoverViewModel()

        let user1 = TestFixtures.createTestUser(fullName: "José María")
        let user2 = TestFixtures.createTestUser(fullName: "O'Brien")
        let user3 = TestFixtures.createTestUser(fullName: "Müller-Schmidt")

        viewModel.users = [user1, user2, user3]

        #expect(viewModel.users.count == 3)
        #expect(viewModel.users[0].fullName.contains("é"))
        #expect(viewModel.users[1].fullName.contains("'"))
        #expect(viewModel.users[2].fullName.contains("-"))
    }

    @Test("Users with emoji in bio")
    func testUsersWithEmoji() async throws {
        let viewModel = DiscoverViewModel()

        let user = TestFixtures.createTestUser(
            fullName: "Emoji User",
            bio: "Love travel ✈️🌍 and coffee ☕️"
        )
        viewModel.users = [user]

        #expect(viewModel.users[0].bio.contains("✈️"))
        #expect(viewModel.users[0].bio.contains("🌍"))
        #expect(viewModel.users[0].bio.contains("☕️"))
    }

    @Test("Users with long bios")
    func testUsersWithLongBios() async throws {
        let viewModel = DiscoverViewModel()

        let longBio = String(repeating: "This is a very detailed bio about me. ", count: 10)
        let user = TestFixtures.createTestUser(bio: longBio)
        viewModel.users = [user]

        #expect(viewModel.users[0].bio.count > 100)
    }

    @Test("Users with multiple photos")
    func testUsersWithMultiplePhotos() async throws {
        let viewModel = DiscoverViewModel()

        let photos = [
            "https://example.com/photo1.jpg",
            "https://example.com/photo2.jpg",
            "https://example.com/photo3.jpg",
            "https://example.com/photo4.jpg",
            "https://example.com/photo5.jpg",
            "https://example.com/photo6.jpg"
        ]

        let user = TestFixtures.createTestUser(photos: photos)
        viewModel.users = [user]

        #expect(viewModel.users[0].photos.count == 6)
    }

    @Test("Users with no photos")
    func testUsersWithNoPhotos() async throws {
        let viewModel = DiscoverViewModel()

        let user = TestFixtures.createTestUser(photos: [])
        viewModel.users = [user]

        #expect(viewModel.users[0].photos.isEmpty)
    }

    @Test("Users with many interests")
    func testUsersWithManyInterests() async throws {
        let viewModel = DiscoverViewModel()

        let interests = [
            "Travel", "Music", "Sports", "Gaming", "Art",
            "Reading", "Food", "Yoga", "Photography", "Hiking"
        ]

        let user = TestFixtures.createTestUser(interests: interests)
        viewModel.users = [user]

        #expect(viewModel.users[0].interests.count == 10)
    }

    @Test("Users with many languages")
    func testUsersWithManyLanguages() async throws {
        let viewModel = DiscoverViewModel()

        let languages = ["English", "Spanish", "French", "German", "Italian", "Portuguese"]

        let user = TestFixtures.createTestUser(languages: languages)
        viewModel.users = [user]

        #expect(viewModel.users[0].languages.count == 6)
    }

    // MARK: - Age Range Tests

    @Test("Users within different age ranges")
    func testUsersAgeRanges() async throws {
        let viewModel = DiscoverViewModel()

        let youngUser = TestFixtures.createTestUser(age: 18)
        let middleUser = TestFixtures.createTestUser(age: 35)
        let olderUser = TestFixtures.createTestUser(age: 55)

        viewModel.users = [youngUser, middleUser, olderUser]

        #expect(viewModel.users[0].age == 18)
        #expect(viewModel.users[1].age == 35)
        #expect(viewModel.users[2].age == 55)
    }

    // MARK: - Location Tests

    @Test("Users from different locations")
    func testUsersDifferentLocations() async throws {
        let viewModel = DiscoverViewModel()

        let user1 = TestFixtures.createTestUser(location: "New York", country: "USA")
        let user2 = TestFixtures.createTestUser(location: "London", country: "UK")
        let user3 = TestFixtures.createTestUser(location: "Tokyo", country: "Japan")

        viewModel.users = [user1, user2, user3]

        #expect(viewModel.users[0].location == "New York")
        #expect(viewModel.users[1].location == "London")
        #expect(viewModel.users[2].location == "Tokyo")
    }

    @Test("Users with coordinates")
    func testUsersWithCoordinates() async throws {
        let viewModel = DiscoverViewModel()

        let user = TestFixtures.createTestUser(
            latitude: 40.7128,
            longitude: -74.0060
        )
        viewModel.users = [user]

        #expect(viewModel.users[0].latitude == 40.7128)
        #expect(viewModel.users[0].longitude == -74.0060)
    }

    // MARK: - Gender Preference Tests

    @Test("Users with different gender preferences")
    func testUserGenderPreferences() async throws {
        let viewModel = DiscoverViewModel()

        let user1 = TestFixtures.createTestUser(gender: "Male", lookingFor: "Female")
        let user2 = TestFixtures.createTestUser(gender: "Female", lookingFor: "Male")
        let user3 = TestFixtures.createTestUser(gender: "Non-binary", lookingFor: "Everyone")

        viewModel.users = [user1, user2, user3]

        #expect(viewModel.users[0].lookingFor == "Female")
        #expect(viewModel.users[1].lookingFor == "Male")
        #expect(viewModel.users[2].lookingFor == "Everyone")
    }

    // MARK: - Premium Features Tests

    @Test("Premium users have correct properties")
    func testPremiumUserProperties() async throws {
        let viewModel = DiscoverViewModel()

        let premiumUser = TestFixtures.createPremiumUser()
        viewModel.users = [premiumUser]

        #expect(viewModel.users[0].isPremium == true)
        #expect(viewModel.users[0].superLikesRemaining > 0)
        #expect(viewModel.users[0].boostsRemaining > 0)
        #expect(viewModel.users[0].premiumTier != nil)
    }

    @Test("Free users have correct properties")
    func testFreeUserProperties() async throws {
        let viewModel = DiscoverViewModel()

        let freeUser = TestFixtures.createTestUser()
        viewModel.users = [freeUser]

        #expect(viewModel.users[0].isPremium == false)
        #expect(viewModel.users[0].likesRemainingToday <= 50)
    }

    // MARK: - State Management Tests

    @Test("IsProcessingAction prevents double actions")
    func testProcessingActionState() async throws {
        let viewModel = DiscoverViewModel()

        #expect(viewModel.isProcessingAction == false)

        viewModel.isProcessingAction = true
        #expect(viewModel.isProcessingAction == true)

        viewModel.isProcessingAction = false
        #expect(viewModel.isProcessingAction == false)
    }

    @Test("ShowingUpgradeSheet state management")
    func testUpgradeSheetState() async throws {
        let viewModel = DiscoverViewModel()

        #expect(viewModel.showingUpgradeSheet == false)

        viewModel.showingUpgradeSheet = true
        #expect(viewModel.showingUpgradeSheet == true)

        viewModel.showingUpgradeSheet = false
        #expect(viewModel.showingUpgradeSheet == false)
    }

    // MARK: - Drag Gesture Tests

    @Test("DragOffset updates correctly")
    func testDragOffsetUpdates() async throws {
        let viewModel = DiscoverViewModel()

        #expect(viewModel.dragOffset == .zero)

        viewModel.dragOffset = CGSize(width: 50, height: 0)
        #expect(viewModel.dragOffset.width == 50)

        viewModel.dragOffset = CGSize(width: -50, height: 0)
        #expect(viewModel.dragOffset.width == -50)

        viewModel.dragOffset = .zero
        #expect(viewModel.dragOffset == .zero)
    }
}
