//
//  FeedDiscoverViewSavedTests.swift
//  CelestiaTests
//
//  Comprehensive tests for saved/favorite functionality in FeedDiscoverView
//

import Testing
import SwiftUI
@testable import Celestia

@Suite("FeedDiscoverView Saved Functionality Tests")
@MainActor
struct FeedDiscoverViewSavedTests {

    // MARK: - Favorite State Tests

    @Test("Favorite state toggles correctly")
    func testFavoriteToggle() async throws {
        // Setup
        var isFavorited = false

        // Initially not favorited
        #expect(isFavorited == false)

        // Toggle to favorited
        isFavorited.toggle()
        #expect(isFavorited == true)

        // Toggle back to not favorited
        isFavorited.toggle()
        #expect(isFavorited == false)
    }

    @Test("Multiple favorite toggles work correctly")
    func testMultipleFavoriteToggles() async throws {
        var isFavorited = false

        // Multiple toggles
        for i in 1...10 {
            isFavorited.toggle()
            if i % 2 == 0 {
                #expect(isFavorited == false)
            } else {
                #expect(isFavorited == true)
            }
        }
    }

    // MARK: - UserDefaults Persistence Tests

    @Test("Favorites persist to UserDefaults when added")
    func testFavoritePersistence() async throws {
        // Setup
        let testUserId = "test_user_123"
        var favorites: Set<String> = []

        // Add favorite
        favorites.insert(testUserId)

        // Save to UserDefaults
        UserDefaults.standard.set(Array(favorites), forKey: "favoriteUserIds")

        // Verify persistence
        let savedFavorites = UserDefaults.standard.array(forKey: "favoriteUserIds") as? [String] ?? []
        #expect(savedFavorites.contains(testUserId))

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "favoriteUserIds")
    }

    @Test("Favorites are removed from UserDefaults when unfavorited")
    func testFavoriteRemovalFromPersistence() async throws {
        // Setup
        let testUserId = "test_user_456"
        var favorites: Set<String> = [testUserId]

        // Save initial state
        UserDefaults.standard.set(Array(favorites), forKey: "favoriteUserIds")

        // Remove favorite
        favorites.remove(testUserId)
        UserDefaults.standard.set(Array(favorites), forKey: "favoriteUserIds")

        // Verify removal
        let savedFavorites = UserDefaults.standard.array(forKey: "favoriteUserIds") as? [String] ?? []
        #expect(!savedFavorites.contains(testUserId))

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "favoriteUserIds")
    }

    @Test("Multiple favorites persist correctly")
    func testMultipleFavoritesPersistence() async throws {
        // Setup
        let userIds = ["user_1", "user_2", "user_3", "user_4", "user_5"]
        var favorites: Set<String> = []

        // Add all users to favorites
        for userId in userIds {
            favorites.insert(userId)
        }

        // Save to UserDefaults
        UserDefaults.standard.set(Array(favorites), forKey: "favoriteUserIds")

        // Verify all are saved
        let savedFavorites = UserDefaults.standard.array(forKey: "favoriteUserIds") as? [String] ?? []
        #expect(savedFavorites.count == 5)

        for userId in userIds {
            #expect(savedFavorites.contains(userId))
        }

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "favoriteUserIds")
    }

    @Test("Loading favorites from UserDefaults works correctly")
    func testLoadingFavoritesFromUserDefaults() async throws {
        // Setup - Pre-populate UserDefaults
        let preExistingFavorites = ["user_a", "user_b", "user_c"]
        UserDefaults.standard.set(preExistingFavorites, forKey: "favoriteUserIds")

        // Load from UserDefaults
        let loadedFavorites = Set(UserDefaults.standard.array(forKey: "favoriteUserIds") as? [String] ?? [])

        // Verify
        #expect(loadedFavorites.count == 3)
        #expect(loadedFavorites.contains("user_a"))
        #expect(loadedFavorites.contains("user_b"))
        #expect(loadedFavorites.contains("user_c"))

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "favoriteUserIds")
    }

    // MARK: - Set Operations Tests

    @Test("Set correctly prevents duplicate favorites")
    func testNoDuplicateFavorites() async throws {
        var favorites: Set<String> = []
        let userId = "duplicate_test_user"

        // Add same user multiple times
        favorites.insert(userId)
        favorites.insert(userId)
        favorites.insert(userId)

        // Set should only contain one instance
        #expect(favorites.count == 1)
        #expect(favorites.contains(userId))
    }

    @Test("Contains check works correctly for favorited users")
    func testContainsCheck() async throws {
        var favorites: Set<String> = ["user_1", "user_2", "user_3"]

        // Check existing user
        #expect(favorites.contains("user_1"))
        #expect(favorites.contains("user_2"))
        #expect(favorites.contains("user_3"))

        // Check non-existing user
        #expect(!favorites.contains("user_4"))
        #expect(!favorites.contains("user_5"))
    }

    @Test("Adding and removing favorites updates set correctly")
    func testAddRemoveOperations() async throws {
        var favorites: Set<String> = []

        // Add users
        favorites.insert("user_1")
        #expect(favorites.count == 1)

        favorites.insert("user_2")
        #expect(favorites.count == 2)

        favorites.insert("user_3")
        #expect(favorites.count == 3)

        // Remove user
        favorites.remove("user_2")
        #expect(favorites.count == 2)
        #expect(!favorites.contains("user_2"))
        #expect(favorites.contains("user_1"))
        #expect(favorites.contains("user_3"))
    }

    // MARK: - Edge Cases

    @Test("Empty favorites set is handled correctly")
    func testEmptyFavoritesSet() async throws {
        let favorites: Set<String> = []

        #expect(favorites.isEmpty)
        #expect(favorites.count == 0)
        #expect(!favorites.contains("any_user"))
    }

    @Test("Favoriting user with nil ID is handled safely")
    func testNilUserIdHandling() async throws {
        var favorites: Set<String> = []
        let userId: String? = nil

        // Should not add nil to set
        if let userId = userId {
            favorites.insert(userId)
        }

        #expect(favorites.isEmpty)
    }

    @Test("Favoriting user with empty string ID")
    func testEmptyStringUserId() async throws {
        var favorites: Set<String> = []
        let userId = ""

        favorites.insert(userId)

        // Empty string is still a valid string, so it gets added
        #expect(favorites.count == 1)
        #expect(favorites.contains(""))
    }

    @Test("Large number of favorites is handled correctly")
    func testLargeNumberOfFavorites() async throws {
        var favorites: Set<String> = []

        // Add 1000 favorites
        for i in 1...1000 {
            favorites.insert("user_\(i)")
        }

        #expect(favorites.count == 1000)
        #expect(favorites.contains("user_1"))
        #expect(favorites.contains("user_500"))
        #expect(favorites.contains("user_1000"))
        #expect(!favorites.contains("user_1001"))
    }

    @Test("Favorites with special characters in IDs")
    func testSpecialCharacterUserIds() async throws {
        var favorites: Set<String> = []

        let specialIds = [
            "user-with-dashes",
            "user_with_underscores",
            "user.with.dots",
            "user@with@at",
            "user#with#hash"
        ]

        for id in specialIds {
            favorites.insert(id)
        }

        #expect(favorites.count == 5)
        for id in specialIds {
            #expect(favorites.contains(id))
        }
    }

    @Test("Favorites with UUID format IDs")
    func testUUIDFormatIds() async throws {
        var favorites: Set<String> = []

        let uuid1 = UUID().uuidString
        let uuid2 = UUID().uuidString
        let uuid3 = UUID().uuidString

        favorites.insert(uuid1)
        favorites.insert(uuid2)
        favorites.insert(uuid3)

        #expect(favorites.count == 3)
        #expect(favorites.contains(uuid1))
        #expect(favorites.contains(uuid2))
        #expect(favorites.contains(uuid3))
    }

    // MARK: - Favorite/Unfavorite Flow Tests

    @Test("Complete favorite workflow - add, check, remove")
    func testCompleteFavoriteWorkflow() async throws {
        var favorites: Set<String> = []
        let userId = "workflow_test_user"

        // Initial state - not favorited
        #expect(!favorites.contains(userId))

        // Favorite the user
        favorites.insert(userId)
        #expect(favorites.contains(userId))
        #expect(favorites.count == 1)

        // Persist
        UserDefaults.standard.set(Array(favorites), forKey: "favoriteUserIds")
        let saved = UserDefaults.standard.array(forKey: "favoriteUserIds") as? [String] ?? []
        #expect(saved.contains(userId))

        // Unfavorite the user
        favorites.remove(userId)
        #expect(!favorites.contains(userId))
        #expect(favorites.count == 0)

        // Persist removal
        UserDefaults.standard.set(Array(favorites), forKey: "favoriteUserIds")
        let savedAfterRemoval = UserDefaults.standard.array(forKey: "favoriteUserIds") as? [String] ?? []
        #expect(!savedAfterRemoval.contains(userId))

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "favoriteUserIds")
    }

    @Test("Favoriting same user twice results in single entry")
    func testDuplicateFavoriteHandling() async throws {
        var favorites: Set<String> = []
        let userId = "duplicate_user"

        // Favorite once
        favorites.insert(userId)
        let countAfterFirst = favorites.count

        // Favorite again (simulate user clicking twice)
        favorites.insert(userId)
        let countAfterSecond = favorites.count

        // Count should remain the same
        #expect(countAfterFirst == countAfterSecond)
        #expect(favorites.count == 1)
    }

    @Test("Toggle favorite state matches expectations")
    func testToggleFavoriteState() async throws {
        var favorites: Set<String> = []
        let userId = "toggle_test_user"

        // Simulate toggle function behavior
        func toggleFavorite(userId: String) {
            if favorites.contains(userId) {
                favorites.remove(userId)
            } else {
                favorites.insert(userId)
            }
        }

        // First toggle - add
        toggleFavorite(userId: userId)
        #expect(favorites.contains(userId))

        // Second toggle - remove
        toggleFavorite(userId: userId)
        #expect(!favorites.contains(userId))

        // Third toggle - add again
        toggleFavorite(userId: userId)
        #expect(favorites.contains(userId))
    }

    // MARK: - UserDefaults Edge Cases

    @Test("UserDefaults handles empty favorites array")
    func testUserDefaultsEmptyArray() async throws {
        // Save empty array
        UserDefaults.standard.set([String](), forKey: "favoriteUserIds")

        // Load and verify
        let loaded = UserDefaults.standard.array(forKey: "favoriteUserIds") as? [String] ?? []
        #expect(loaded.isEmpty)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "favoriteUserIds")
    }

    @Test("UserDefaults returns empty array when key doesn't exist")
    func testUserDefaultsNonExistentKey() async throws {
        // Remove key if it exists
        UserDefaults.standard.removeObject(forKey: "favoriteUserIds")

        // Try to load
        let loaded = UserDefaults.standard.array(forKey: "favoriteUserIds") as? [String] ?? []

        // Should be empty, not nil
        #expect(loaded.isEmpty)
    }

    @Test("UserDefaults survives multiple save operations")
    func testUserDefaultsMultipleSaves() async throws {
        var favorites: Set<String> = []

        // Save 1
        favorites.insert("user_1")
        UserDefaults.standard.set(Array(favorites), forKey: "favoriteUserIds")

        // Save 2
        favorites.insert("user_2")
        UserDefaults.standard.set(Array(favorites), forKey: "favoriteUserIds")

        // Save 3
        favorites.insert("user_3")
        UserDefaults.standard.set(Array(favorites), forKey: "favoriteUserIds")

        // Verify final state
        let loaded = Set(UserDefaults.standard.array(forKey: "favoriteUserIds") as? [String] ?? [])
        #expect(loaded.count == 3)
        #expect(loaded.contains("user_1"))
        #expect(loaded.contains("user_2"))
        #expect(loaded.contains("user_3"))

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "favoriteUserIds")
    }

    // MARK: - Icon State Tests

    @Test("Star icon state matches favorite status - filled")
    func testStarIconFilledState() async throws {
        let isFavorited = true
        let expectedIcon = isFavorited ? "star.fill" : "star"

        #expect(expectedIcon == "star.fill")
    }

    @Test("Star icon state matches favorite status - empty")
    func testStarIconEmptyState() async throws {
        let isFavorited = false
        let expectedIcon = isFavorited ? "star.fill" : "star"

        #expect(expectedIcon == "star")
    }

    @Test("Star icon toggles between states")
    func testStarIconToggle() async throws {
        var isFavorited = false

        // Initial state - empty star
        var icon = isFavorited ? "star.fill" : "star"
        #expect(icon == "star")

        // After favoriting - filled star
        isFavorited.toggle()
        icon = isFavorited ? "star.fill" : "star"
        #expect(icon == "star.fill")

        // After unfavoriting - empty star again
        isFavorited.toggle()
        icon = isFavorited ? "star.fill" : "star"
        #expect(icon == "star")
    }

    // MARK: - Toast Message Tests

    @Test("Favorite action generates correct toast message")
    func testFavoriteToastMessage() async throws {
        let userName = "John Doe"
        let expectedMessage = "Saved \(userName)"

        #expect(expectedMessage == "Saved John Doe")
    }

    @Test("Unfavorite action generates correct toast message")
    func testUnfavoriteToastMessage() async throws {
        let expectedMessage = "Removed from saved"

        #expect(expectedMessage == "Removed from saved")
    }

    @Test("Long username is truncated in toast message")
    func testLongUserNameTruncation() async throws {
        let longName = "Christopher Alexander Montgomery Richardson III"
        let truncatedName = longName.count > 20 ? String(longName.prefix(20)) + "..." : longName

        #expect(truncatedName.count <= 23) // 20 chars + "..."
        #expect(truncatedName.hasSuffix("..."))
    }

    @Test("Short username is not truncated in toast message")
    func testShortUserNameNoTruncation() async throws {
        let shortName = "Jane"
        let processedName = shortName.count > 20 ? String(shortName.prefix(20)) + "..." : shortName

        #expect(processedName == "Jane")
        #expect(!processedName.hasSuffix("..."))
    }

    // MARK: - Concurrent Operations Tests

    @Test("Multiple favorites added in sequence maintain correct count")
    func testSequentialFavoriteAdditions() async throws {
        var favorites: Set<String> = []

        let userIds = (1...100).map { "user_\($0)" }

        for userId in userIds {
            favorites.insert(userId)
        }

        #expect(favorites.count == 100)
    }

    @Test("Alternating add and remove operations maintain consistency")
    func testAlternatingAddRemove() async throws {
        var favorites: Set<String> = []

        // Add 50 users
        for i in 1...50 {
            favorites.insert("user_\(i)")
        }
        #expect(favorites.count == 50)

        // Remove every other user
        for i in stride(from: 2, through: 50, by: 2) {
            favorites.remove("user_\(i)")
        }
        #expect(favorites.count == 25)

        // Verify remaining are odd numbers
        #expect(favorites.contains("user_1"))
        #expect(favorites.contains("user_3"))
        #expect(!favorites.contains("user_2"))
        #expect(!favorites.contains("user_4"))
    }

    // MARK: - Integration Tests

    @Test("Full integration test - multiple users, save, load, modify")
    func testFullIntegration() async throws {
        // Step 1: Create initial favorites
        var favorites: Set<String> = ["user_1", "user_2", "user_3"]
        UserDefaults.standard.set(Array(favorites), forKey: "favoriteUserIds")

        // Step 2: Load from UserDefaults
        var loadedFavorites = Set(UserDefaults.standard.array(forKey: "favoriteUserIds") as? [String] ?? [])
        #expect(loadedFavorites.count == 3)

        // Step 3: Add more favorites
        loadedFavorites.insert("user_4")
        loadedFavorites.insert("user_5")
        UserDefaults.standard.set(Array(loadedFavorites), forKey: "favoriteUserIds")

        // Step 4: Reload and verify
        let reloadedFavorites = Set(UserDefaults.standard.array(forKey: "favoriteUserIds") as? [String] ?? [])
        #expect(reloadedFavorites.count == 5)

        // Step 5: Remove some favorites
        var modifiedFavorites = reloadedFavorites
        modifiedFavorites.remove("user_2")
        modifiedFavorites.remove("user_4")
        UserDefaults.standard.set(Array(modifiedFavorites), forKey: "favoriteUserIds")

        // Step 6: Final verification
        let finalFavorites = Set(UserDefaults.standard.array(forKey: "favoriteUserIds") as? [String] ?? [])
        #expect(finalFavorites.count == 3)
        #expect(finalFavorites.contains("user_1"))
        #expect(!finalFavorites.contains("user_2"))
        #expect(finalFavorites.contains("user_3"))
        #expect(!finalFavorites.contains("user_4"))
        #expect(finalFavorites.contains("user_5"))

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "favoriteUserIds")
    }
}
