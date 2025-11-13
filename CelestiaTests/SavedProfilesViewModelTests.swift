//
//  SavedProfilesViewModelTests.swift
//  CelestiaTests
//
//  Comprehensive tests for SavedProfilesViewModel and SavedProfile functionality
//

import Testing
import FirebaseFirestore
@testable import Celestia

@Suite("SavedProfilesViewModel Tests")
struct SavedProfilesViewModelTests {

    // MARK: - Model Tests

    @Test("SavedProfile model initialization")
    func testSavedProfileInitialization() async throws {
        let testUser = User(
            id: "user123",
            email: "test@example.com",
            fullName: "John Doe",
            age: 28,
            gender: "Male",
            lookingFor: "Women",
            bio: "Test bio",
            location: "New York",
            country: "USA",
            languages: ["English"],
            interests: ["Travel"],
            photos: [],
            profileImageURL: "",
            timestamp: Date(),
            isPremium: false,
            lastActive: Date(),
            ageRangeMin: 25,
            ageRangeMax: 35,
            maxDistance: 50
        )

        let savedProfile = SavedProfile(
            id: "saved123",
            user: testUser,
            savedAt: Date(),
            note: "Test note"
        )

        #expect(savedProfile.id == "saved123")
        #expect(savedProfile.user.fullName == "John Doe")
        #expect(savedProfile.note == "Test note")
        #expect(savedProfile.user.age == 28)
    }

    @Test("SavedProfile model without note")
    func testSavedProfileWithoutNote() async throws {
        let testUser = User(
            id: "user456",
            email: "jane@example.com",
            fullName: "Jane Smith",
            age: 26,
            gender: "Female",
            lookingFor: "Men",
            bio: "Another test bio",
            location: "Los Angeles",
            country: "USA",
            languages: ["English", "Spanish"],
            interests: ["Music", "Art"],
            photos: [],
            profileImageURL: "",
            timestamp: Date(),
            isPremium: true,
            lastActive: Date(),
            ageRangeMin: 24,
            ageRangeMax: 32,
            maxDistance: 100
        )

        let savedProfile = SavedProfile(
            id: "saved456",
            user: testUser,
            savedAt: Date(),
            note: nil
        )

        #expect(savedProfile.note == nil)
        #expect(savedProfile.user.isPremium == true)
    }

    // MARK: - ViewModel State Tests

    @Test("ViewModel initial state")
    func testViewModelInitialState() async throws {
        let viewModel = SavedProfilesViewModel()

        #expect(viewModel.savedProfiles.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage.isEmpty)
        #expect(viewModel.savedThisWeek == 0)
    }

    @Test("ViewModel savedThisWeek calculation with profiles from this week")
    func testSavedThisWeekWithRecentProfiles() async throws {
        let viewModel = SavedProfilesViewModel()

        // Create test users
        let user1 = createTestUser(name: "User 1")
        let user2 = createTestUser(name: "User 2")
        let user3 = createTestUser(name: "User 3")

        // Create saved profiles: 2 from this week, 1 from 2 weeks ago
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date())!

        let saved1 = SavedProfile(id: "1", user: user1, savedAt: twoDaysAgo, note: nil)
        let saved2 = SavedProfile(id: "2", user: user2, savedAt: fiveDaysAgo, note: nil)
        let saved3 = SavedProfile(id: "3", user: user3, savedAt: twoWeeksAgo, note: nil)

        viewModel.savedProfiles = [saved1, saved2, saved3]

        #expect(viewModel.savedThisWeek == 2)
    }

    @Test("ViewModel savedThisWeek calculation with no recent profiles")
    func testSavedThisWeekWithNoRecentProfiles() async throws {
        let viewModel = SavedProfilesViewModel()

        let user = createTestUser(name: "Old User")
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date())!

        let saved = SavedProfile(id: "1", user: user, savedAt: twoWeeksAgo, note: nil)
        viewModel.savedProfiles = [saved]

        #expect(viewModel.savedThisWeek == 0)
    }

    @Test("ViewModel savedThisWeek calculation with all profiles from this week")
    func testSavedThisWeekWithAllRecentProfiles() async throws {
        let viewModel = SavedProfilesViewModel()

        let user1 = createTestUser(name: "User 1")
        let user2 = createTestUser(name: "User 2")

        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!

        let saved1 = SavedProfile(id: "1", user: user1, savedAt: oneDayAgo, note: nil)
        let saved2 = SavedProfile(id: "2", user: user2, savedAt: threeDaysAgo, note: nil)

        viewModel.savedProfiles = [saved1, saved2]

        #expect(viewModel.savedThisWeek == 2)
    }

    // MARK: - Text Overflow Tests

    @Test("Long user names are handled correctly")
    func testLongUserName() async throws {
        let longName = "Christopher Alexander Montgomery Richardson III"

        let user = User(
            id: "longname123",
            email: "long@example.com",
            fullName: longName,
            age: 30,
            gender: "Male",
            lookingFor: "Women",
            bio: "Test",
            location: "NYC",
            country: "USA",
            languages: ["English"],
            interests: ["Test"],
            photos: [],
            profileImageURL: "",
            timestamp: Date(),
            isPremium: false,
            lastActive: Date(),
            ageRangeMin: 25,
            ageRangeMax: 35,
            maxDistance: 50
        )

        let saved = SavedProfile(id: "1", user: user, savedAt: Date(), note: nil)

        #expect(saved.user.fullName.count > 20)
        #expect(!saved.user.fullName.isEmpty)
    }

    @Test("Long location names are handled correctly")
    func testLongLocationName() async throws {
        let longLocation = "San Juan Capistrano, Orange County, California"

        let user = createTestUser(name: "Test User")
        var modifiedUser = user
        modifiedUser.location = longLocation

        let saved = SavedProfile(id: "1", user: modifiedUser, savedAt: Date(), note: nil)

        #expect(saved.user.location.count > 20)
        #expect(!saved.user.location.isEmpty)
    }

    @Test("Multiple saved profiles maintain order")
    func testProfilesSortOrder() async throws {
        let viewModel = SavedProfilesViewModel()

        let user1 = createTestUser(name: "First")
        let user2 = createTestUser(name: "Second")
        let user3 = createTestUser(name: "Third")

        let date1 = Date()
        let date2 = Calendar.current.date(byAdding: .hour, value: -1, to: Date())!
        let date3 = Calendar.current.date(byAdding: .hour, value: -2, to: Date())!

        let saved1 = SavedProfile(id: "1", user: user1, savedAt: date1, note: nil)
        let saved2 = SavedProfile(id: "2", user: user2, savedAt: date2, note: nil)
        let saved3 = SavedProfile(id: "3", user: user3, savedAt: date3, note: nil)

        viewModel.savedProfiles = [saved1, saved2, saved3]

        #expect(viewModel.savedProfiles.count == 3)
        #expect(viewModel.savedProfiles[0].user.fullName == "First")
        #expect(viewModel.savedProfiles[1].user.fullName == "Second")
        #expect(viewModel.savedProfiles[2].user.fullName == "Third")
    }

    // MARK: - Edge Cases

    @Test("Empty profiles list")
    func testEmptyProfilesList() async throws {
        let viewModel = SavedProfilesViewModel()

        #expect(viewModel.savedProfiles.isEmpty)
        #expect(viewModel.savedThisWeek == 0)
    }

    @Test("Profile with special characters in name")
    func testSpecialCharactersInName() async throws {
        let specialName = "José María O'Brien-González"

        let user = User(
            id: "special123",
            email: "jose@example.com",
            fullName: specialName,
            age: 29,
            gender: "Male",
            lookingFor: "Women",
            bio: "Test",
            location: "Madrid",
            country: "Spain",
            languages: ["Spanish", "English"],
            interests: ["Soccer"],
            photos: [],
            profileImageURL: "",
            timestamp: Date(),
            isPremium: false,
            lastActive: Date(),
            ageRangeMin: 25,
            ageRangeMax: 35,
            maxDistance: 50
        )

        let saved = SavedProfile(id: "1", user: user, savedAt: Date(), note: nil)

        #expect(saved.user.fullName == specialName)
        #expect(saved.user.fullName.contains("é"))
        #expect(saved.user.fullName.contains("'"))
        #expect(saved.user.fullName.contains("-"))
    }

    @Test("Profile with emoji in bio")
    func testEmojiInBio() async throws {
        let bioWithEmoji = "Love to travel ✈️🌍 and meet new people 😊"

        let user = createTestUser(name: "Emoji User")
        var modifiedUser = user
        modifiedUser.bio = bioWithEmoji

        let saved = SavedProfile(id: "1", user: modifiedUser, savedAt: Date(), note: nil)

        #expect(saved.user.bio.contains("✈️"))
        #expect(saved.user.bio.contains("🌍"))
        #expect(saved.user.bio.contains("😊"))
    }

    @Test("Profile with very long bio")
    func testVeryLongBio() async throws {
        let longBio = String(repeating: "This is a very long bio. ", count: 20)

        let user = createTestUser(name: "Long Bio User")
        var modifiedUser = user
        modifiedUser.bio = longBio

        let saved = SavedProfile(id: "1", user: modifiedUser, savedAt: Date(), note: nil)

        #expect(saved.user.bio.count > 100)
    }

    @Test("Profile with maximum age (99)")
    func testMaximumAge() async throws {
        let user = createTestUser(name: "Senior User")
        var modifiedUser = user
        modifiedUser.age = 99

        let saved = SavedProfile(id: "1", user: modifiedUser, savedAt: Date(), note: nil)

        #expect(saved.user.age == 99)
    }

    @Test("Profile with minimum age (18)")
    func testMinimumAge() async throws {
        let user = createTestUser(name: "Young User")
        var modifiedUser = user
        modifiedUser.age = 18

        let saved = SavedProfile(id: "1", user: modifiedUser, savedAt: Date(), note: nil)

        #expect(saved.user.age == 18)
    }

    @Test("Profile with multiple photos")
    func testMultiplePhotos() async throws {
        let photos = [
            "https://example.com/photo1.jpg",
            "https://example.com/photo2.jpg",
            "https://example.com/photo3.jpg",
            "https://example.com/photo4.jpg"
        ]

        let user = createTestUser(name: "Photo User")
        var modifiedUser = user
        modifiedUser.photos = photos

        let saved = SavedProfile(id: "1", user: modifiedUser, savedAt: Date(), note: nil)

        #expect(saved.user.photos.count == 4)
        #expect(saved.user.photos[0].contains("photo1.jpg"))
    }

    @Test("Profile with no photos")
    func testNoPhotos() async throws {
        let user = createTestUser(name: "No Photo User")
        var modifiedUser = user
        modifiedUser.photos = []

        let saved = SavedProfile(id: "1", user: modifiedUser, savedAt: Date(), note: nil)

        #expect(saved.user.photos.isEmpty)
    }

    @Test("Profile with many languages")
    func testManyLanguages() async throws {
        let languages = ["English", "Spanish", "French", "German", "Italian", "Portuguese"]

        let user = createTestUser(name: "Polyglot")
        var modifiedUser = user
        modifiedUser.languages = languages

        let saved = SavedProfile(id: "1", user: modifiedUser, savedAt: Date(), note: nil)

        #expect(saved.user.languages.count == 6)
    }

    @Test("Profile with many interests")
    func testManyInterests() async throws {
        let interests = ["Travel", "Music", "Sports", "Art", "Food", "Gaming", "Reading", "Yoga"]

        let user = createTestUser(name: "Interested User")
        var modifiedUser = user
        modifiedUser.interests = interests

        let saved = SavedProfile(id: "1", user: modifiedUser, savedAt: Date(), note: nil)

        #expect(saved.user.interests.count == 8)
    }

    @Test("Premium user indicator")
    func testPremiumUser() async throws {
        let user = createTestUser(name: "Premium User")
        var modifiedUser = user
        modifiedUser.isPremium = true

        let saved = SavedProfile(id: "1", user: modifiedUser, savedAt: Date(), note: nil)

        #expect(saved.user.isPremium == true)
    }

    @Test("Non-premium user indicator")
    func testNonPremiumUser() async throws {
        let user = createTestUser(name: "Regular User")
        var modifiedUser = user
        modifiedUser.isPremium = false

        let saved = SavedProfile(id: "1", user: modifiedUser, savedAt: Date(), note: nil)

        #expect(saved.user.isPremium == false)
    }

    // MARK: - Note Functionality Tests

    @Test("Profile with short note")
    func testShortNote() async throws {
        let user = createTestUser(name: "Test User")
        let note = "Interesting person"

        let saved = SavedProfile(id: "1", user: user, savedAt: Date(), note: note)

        #expect(saved.note == note)
    }

    @Test("Profile with long note")
    func testLongNote() async throws {
        let user = createTestUser(name: "Test User")
        let note = "This person seems really interesting. We have a lot in common and I'd like to remember to message them later. They mentioned they love hiking and traveling."

        let saved = SavedProfile(id: "1", user: user, savedAt: Date(), note: note)

        #expect(saved.note == note)
        #expect(saved.note!.count > 50)
    }

    // MARK: - Helper Function

    private func createTestUser(name: String) -> User {
        return User(
            id: UUID().uuidString,
            email: "\(name.lowercased().replacingOccurrences(of: " ", with: ""))@example.com",
            fullName: name,
            age: 25,
            gender: "Other",
            lookingFor: "Everyone",
            bio: "Test bio for \(name)",
            location: "Test City",
            country: "Test Country",
            languages: ["English"],
            interests: ["Testing"],
            photos: [],
            profileImageURL: "",
            timestamp: Date(),
            isPremium: false,
            lastActive: Date(),
            ageRangeMin: 18,
            ageRangeMax: 99,
            maxDistance: 100
        )
    }
}
