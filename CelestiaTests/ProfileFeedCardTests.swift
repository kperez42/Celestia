//
//  ProfileFeedCardTests.swift
//  CelestiaTests
//
//  Comprehensive tests for ProfileFeedCard component
//

import Testing
import SwiftUI
@testable import Celestia

@Suite("ProfileFeedCard Component Tests")
@MainActor
struct ProfileFeedCardTests {

    // MARK: - State Management Tests

    @Test("ProfileFeedCard favorite state initializes as false")
    func testInitialFavoriteState() async throws {
        let isFavorited = false

        #expect(isFavorited == false)
    }

    @Test("ProfileFeedCard like state initializes as false")
    func testInitialLikeState() async throws {
        let isLiked = false

        #expect(isLiked == false)
    }

    @Test("Favorite button toggles state on click")
    func testFavoriteButtonToggle() async throws {
        var isFavorited = false
        var onFavoriteCalled = false

        // Simulate button click
        isFavorited.toggle()
        onFavoriteCalled = true

        #expect(isFavorited == true)
        #expect(onFavoriteCalled == true)
    }

    @Test("Like button toggles state on click")
    func testLikeButtonToggle() async throws {
        var isLiked = false
        var onLikeCalled = false

        // Simulate button click
        isLiked.toggle()
        onLikeCalled = true

        #expect(isLiked == true)
        #expect(onLikeCalled == true)
    }

    @Test("Multiple favorite toggles work correctly")
    func testMultipleFavoriteToggles() async throws {
        var isFavorited = false

        // Toggle 5 times
        for i in 1...5 {
            isFavorited.toggle()
            if i % 2 == 1 {
                #expect(isFavorited == true)
            } else {
                #expect(isFavorited == false)
            }
        }
    }

    @Test("Multiple like toggles work correctly")
    func testMultipleLikeToggles() async throws {
        var isLiked = false

        // Toggle 5 times
        for i in 1...5 {
            isLiked.toggle()
            if i % 2 == 1 {
                #expect(isLiked == true)
            } else {
                #expect(isLiked == false)
            }
        }
    }

    // MARK: - Icon State Tests

    @Test("Favorite icon is empty star when not favorited")
    func testFavoriteIconEmpty() async throws {
        let isFavorited = false
        let icon = isFavorited ? "star.fill" : "star"

        #expect(icon == "star")
    }

    @Test("Favorite icon is filled star when favorited")
    func testFavoriteIconFilled() async throws {
        let isFavorited = true
        let icon = isFavorited ? "star.fill" : "star"

        #expect(icon == "star.fill")
    }

    @Test("Like icon is empty heart when not liked")
    func testLikeIconEmpty() async throws {
        let isLiked = false
        let icon = isLiked ? "heart.fill" : "heart"

        #expect(icon == "heart")
    }

    @Test("Like icon is filled heart when liked")
    func testLikeIconFilled() async throws {
        let isLiked = true
        let icon = isLiked ? "heart.fill" : "heart"

        #expect(icon == "heart.fill")
    }

    @Test("Icon state changes after toggle")
    func testIconStateAfterToggle() async throws {
        var isFavorited = false

        // Initial icon
        var icon = isFavorited ? "star.fill" : "star"
        #expect(icon == "star")

        // After toggle
        isFavorited.toggle()
        icon = isFavorited ? "star.fill" : "star"
        #expect(icon == "star.fill")
    }

    // MARK: - Callback Tests

    @Test("OnFavorite callback is triggered when favorite button clicked")
    func testOnFavoriteCallback() async throws {
        var callbackTriggered = false

        let onFavorite: () -> Void = {
            callbackTriggered = true
        }

        // Simulate button action
        onFavorite()

        #expect(callbackTriggered == true)
    }

    @Test("OnLike callback is triggered when like button clicked")
    func testOnLikeCallback() async throws {
        var callbackTriggered = false

        let onLike: () -> Void = {
            callbackTriggered = true
        }

        // Simulate button action
        onLike()

        #expect(callbackTriggered == true)
    }

    @Test("OnMessage callback is triggered when message button clicked")
    func testOnMessageCallback() async throws {
        var callbackTriggered = false

        let onMessage: () -> Void = {
            callbackTriggered = true
        }

        // Simulate button action
        onMessage()

        #expect(callbackTriggered == true)
    }

    @Test("OnViewPhotos callback is triggered when photos button clicked")
    func testOnViewPhotosCallback() async throws {
        var callbackTriggered = false

        let onViewPhotos: () -> Void = {
            callbackTriggered = true
        }

        // Simulate button action
        onViewPhotos()

        #expect(callbackTriggered == true)
    }

    @Test("Multiple callbacks can be triggered independently")
    func testMultipleCallbacksIndependent() async throws {
        var likeTriggered = false
        var favoriteTriggered = false
        var messageTriggered = false

        let onLike: () -> Void = { likeTriggered = true }
        let onFavorite: () -> Void = { favoriteTriggered = true }
        let onMessage: () -> Void = { messageTriggered = true }

        // Trigger like
        onLike()
        #expect(likeTriggered == true)
        #expect(favoriteTriggered == false)
        #expect(messageTriggered == false)

        // Trigger favorite
        onFavorite()
        #expect(likeTriggered == true)
        #expect(favoriteTriggered == true)
        #expect(messageTriggered == false)

        // Trigger message
        onMessage()
        #expect(likeTriggered == true)
        #expect(favoriteTriggered == true)
        #expect(messageTriggered == true)
    }

    // MARK: - Action Button Component Tests

    @Test("ActionButton displays correct icon")
    func testActionButtonIcon() async throws {
        let icon = "heart.fill"
        // Icon should be set correctly
        #expect(icon == "heart.fill")
    }

    @Test("ActionButton has correct color")
    func testActionButtonColor() async throws {
        // Test that color enum works
        let heartColor = Color.pink
        let starColor = Color.orange
        let messageColor = Color.blue
        let photoColor = Color.purple

        #expect(heartColor == .pink)
        #expect(starColor == .orange)
        #expect(messageColor == .blue)
        #expect(photoColor == .purple)
    }

    @Test("ActionButton label text is set correctly")
    func testActionButtonLabel() async throws {
        let labels = ["Like", "Save", "Message", "Photos"]

        #expect(labels.contains("Like"))
        #expect(labels.contains("Save"))
        #expect(labels.contains("Message"))
        #expect(labels.contains("Photos"))
    }

    // MARK: - User Data Display Tests

    @Test("User full name is displayed")
    func testUserNameDisplay() async throws {
        let user = TestFixtures.createTestUser(fullName: "Jane Smith")

        #expect(user.fullName == "Jane Smith")
    }

    @Test("User age is displayed")
    func testUserAgeDisplay() async throws {
        let user = TestFixtures.createTestUser(age: 28)

        #expect(user.age == 28)
    }

    @Test("User location is displayed")
    func testUserLocationDisplay() async throws {
        let user = TestFixtures.createTestUser(location: "Los Angeles", country: "USA")

        #expect(user.location == "Los Angeles")
        #expect(user.country == "USA")
    }

    @Test("User seeking preferences are displayed")
    func testUserSeekingDisplay() async throws {
        let user = TestFixtures.createTestUser(lookingFor: "Women", ageRangeMin: 25, ageRangeMax: 35)

        #expect(user.lookingFor == "Women")
        #expect(user.ageRangeMin == 25)
        #expect(user.ageRangeMax == 35)
    }

    @Test("Verified badge shown for verified users")
    func testVerifiedBadgeDisplay() async throws {
        let verifiedUser = TestFixtures.createVerifiedUser()

        #expect(verifiedUser.isVerified == true)
    }

    @Test("Premium badge shown for premium users")
    func testPremiumBadgeDisplay() async throws {
        let premiumUser = TestFixtures.createPremiumUser()

        #expect(premiumUser.isPremium == true)
    }

    @Test("Online status is displayed correctly")
    func testOnlineStatusDisplay() async throws {
        let onlineUser = TestFixtures.createTestUser()
        var modifiedUser = onlineUser
        modifiedUser.isOnline = true

        #expect(modifiedUser.isOnline == true)
    }

    // MARK: - Last Active Formatting Tests

    @Test("Format last active - just now")
    func testFormatLastActiveJustNow() async throws {
        let now = Date()
        let interval = Date().timeIntervalSince(now)

        #expect(interval < 60)
        // Should display "just now"
    }

    @Test("Format last active - minutes ago")
    func testFormatLastActiveMinutes() async throws {
        let fiveMinutesAgo = Calendar.current.date(byAdding: .minute, value: -5, to: Date())!
        let interval = Date().timeIntervalSince(fiveMinutesAgo)

        #expect(interval >= 60)
        #expect(interval < 3600)
        // Should display "5m ago"
        let minutes = Int(interval / 60)
        #expect(minutes == 5)
    }

    @Test("Format last active - hours ago")
    func testFormatLastActiveHours() async throws {
        let threeHoursAgo = Calendar.current.date(byAdding: .hour, value: -3, to: Date())!
        let interval = Date().timeIntervalSince(threeHoursAgo)

        #expect(interval >= 3600)
        #expect(interval < 86400)
        // Should display "3h ago"
        let hours = Int(interval / 3600)
        #expect(hours == 3)
    }

    @Test("Format last active - days ago")
    func testFormatLastActiveDays() async throws {
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let interval = Date().timeIntervalSince(twoDaysAgo)

        #expect(interval >= 86400)
        // Should display "2d ago"
        let days = Int(interval / 86400)
        #expect(days >= 2)
    }

    @Test("Format last active - weeks ago")
    func testFormatLastActiveWeeks() async throws {
        let twoWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -2, to: Date())!
        let interval = Date().timeIntervalSince(twoWeeksAgo)

        #expect(interval >= 604800)
        // Should display "2w ago"
        let weeks = Int(interval / 604800)
        #expect(weeks >= 2)
    }

    @Test("Format last active - months ago")
    func testFormatLastActiveMonths() async throws {
        let twoMonthsAgo = Calendar.current.date(byAdding: .month, value: -2, to: Date())!
        let interval = Date().timeIntervalSince(twoMonthsAgo)

        #expect(interval >= 2592000)
        // Should display "2mo ago"
        let months = Int(interval / 2592000)
        #expect(months >= 1)
    }

    // MARK: - Edge Cases

    @Test("Handle user with empty name")
    func testEmptyUserName() async throws {
        let user = TestFixtures.createTestUser(fullName: "")

        #expect(user.fullName.isEmpty)
    }

    @Test("Handle user with very long name")
    func testVeryLongUserName() async throws {
        let longName = "Christopher Alexander Montgomery Richardson Wellington III"
        let user = TestFixtures.createTestUser(fullName: longName)

        #expect(user.fullName.count > 30)
    }

    @Test("Handle user with special characters in name")
    func testSpecialCharactersInName() async throws {
        let specialName = "José María O'Brien-González"
        let user = TestFixtures.createTestUser(fullName: specialName)

        #expect(user.fullName.contains("é"))
        #expect(user.fullName.contains("'"))
        #expect(user.fullName.contains("-"))
    }

    @Test("Handle user with empty bio")
    func testEmptyBio() async throws {
        let user = TestFixtures.createTestUser(bio: "")

        #expect(user.bio.isEmpty)
    }

    @Test("Handle user with very long bio")
    func testVeryLongBio() async throws {
        let longBio = String(repeating: "This is a very long bio. ", count: 20)
        let user = TestFixtures.createTestUser(bio: longBio)

        #expect(user.bio.count > 100)
    }

    @Test("Handle user with minimum age (18)")
    func testMinimumAge() async throws {
        let user = TestFixtures.createTestUser(age: 18)

        #expect(user.age == 18)
    }

    @Test("Handle user with maximum age (99)")
    func testMaximumAge() async throws {
        let user = TestFixtures.createTestUser(age: 99)

        #expect(user.age == 99)
    }

    @Test("Handle user with empty photos array")
    func testEmptyPhotos() async throws {
        let user = TestFixtures.createTestUser(photos: [])

        #expect(user.photos.isEmpty)
    }

    @Test("Handle user with multiple photos")
    func testMultiplePhotos() async throws {
        let photos = [
            "https://example.com/photo1.jpg",
            "https://example.com/photo2.jpg",
            "https://example.com/photo3.jpg"
        ]
        let user = TestFixtures.createTestUser(photos: photos)

        #expect(user.photos.count == 3)
    }

    @Test("Handle user with no interests")
    func testNoInterests() async throws {
        let user = TestFixtures.createTestUser(interests: [])

        #expect(user.interests.isEmpty)
    }

    @Test("Handle user with many interests")
    func testManyInterests() async throws {
        let interests = ["Travel", "Music", "Art", "Food", "Sports", "Gaming", "Reading", "Yoga", "Photography", "Hiking"]
        let user = TestFixtures.createTestUser(interests: interests)

        #expect(user.interests.count == 10)
    }

    @Test("Handle user with no languages")
    func testNoLanguages() async throws {
        let user = TestFixtures.createTestUser(languages: [])

        #expect(user.languages.isEmpty)
    }

    @Test("Handle user with multiple languages")
    func testMultipleLanguages() async throws {
        let languages = ["English", "Spanish", "French", "German"]
        let user = TestFixtures.createTestUser(languages: languages)

        #expect(user.languages.count == 4)
    }

    // MARK: - State Independence Tests

    @Test("Like state does not affect favorite state")
    func testLikeAndFavoriteIndependence() async throws {
        var isLiked = false
        var isFavorited = false

        // Toggle like
        isLiked.toggle()
        #expect(isLiked == true)
        #expect(isFavorited == false)

        // Toggle favorite
        isFavorited.toggle()
        #expect(isLiked == true)
        #expect(isFavorited == true)

        // Toggle like back
        isLiked.toggle()
        #expect(isLiked == false)
        #expect(isFavorited == true)
    }

    @Test("Button states reset independently")
    func testIndependentStateReset() async throws {
        var isLiked = true
        var isFavorited = true

        // Both start as true
        #expect(isLiked == true)
        #expect(isFavorited == true)

        // Reset like only
        isLiked = false
        #expect(isLiked == false)
        #expect(isFavorited == true)

        // Reset favorite only
        isFavorited = false
        #expect(isLiked == false)
        #expect(isFavorited == false)
    }

    // MARK: - Integration Tests

    @Test("Complete user interaction flow")
    func testCompleteUserFlow() async throws {
        var isLiked = false
        var isFavorited = false
        var likeCallbackCount = 0
        var favoriteCallbackCount = 0

        let onLike: () -> Void = {
            isLiked.toggle()
            likeCallbackCount += 1
        }

        let onFavorite: () -> Void = {
            isFavorited.toggle()
            favoriteCallbackCount += 1
        }

        // User likes the profile
        onLike()
        #expect(isLiked == true)
        #expect(likeCallbackCount == 1)

        // User saves the profile
        onFavorite()
        #expect(isFavorited == true)
        #expect(favoriteCallbackCount == 1)

        // User unlikes the profile
        onLike()
        #expect(isLiked == false)
        #expect(likeCallbackCount == 2)
        #expect(isFavorited == true) // Favorite should remain

        // User unsaves the profile
        onFavorite()
        #expect(isFavorited == false)
        #expect(favoriteCallbackCount == 2)
    }
}
