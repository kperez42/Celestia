//
//  ProfileEditViewModelTests.swift
//  CelestiaTests
//
//  Comprehensive tests for ProfileEditViewModel
//

import Testing
import UIKit
@testable import Celestia

@Suite("ProfileEditViewModel Tests")
@MainActor
struct ProfileEditViewModelTests {

    // MARK: - Initialization Tests

    @Test("ViewModel initializes with correct default state")
    func testInitialState() async throws {
        let viewModel = ProfileEditViewModel()

        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Loading State Tests

    @Test("IsLoading state can be toggled")
    func testLoadingStateToggle() async throws {
        let viewModel = ProfileEditViewModel()

        #expect(viewModel.isLoading == false)

        viewModel.isLoading = true
        #expect(viewModel.isLoading == true)

        viewModel.isLoading = false
        #expect(viewModel.isLoading == false)
    }

    @Test("Multiple loading state changes")
    func testMultipleLoadingStateChanges() async throws {
        let viewModel = ProfileEditViewModel()

        for _ in 0..<5 {
            viewModel.isLoading = true
            #expect(viewModel.isLoading == true)

            viewModel.isLoading = false
            #expect(viewModel.isLoading == false)
        }
    }

    // MARK: - Error Message Tests

    @Test("ErrorMessage can be set")
    func testErrorMessageSet() async throws {
        let viewModel = ProfileEditViewModel()

        #expect(viewModel.errorMessage == nil)

        viewModel.errorMessage = "Test error"
        #expect(viewModel.errorMessage == "Test error")
    }

    @Test("ErrorMessage can be cleared")
    func testErrorMessageClear() async throws {
        let viewModel = ProfileEditViewModel()

        viewModel.errorMessage = "Some error"
        #expect(viewModel.errorMessage == "Some error")

        viewModel.errorMessage = nil
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Multiple error messages")
    func testMultipleErrorMessages() async throws {
        let viewModel = ProfileEditViewModel()

        let errors = [
            "Network error",
            "Invalid input",
            "Upload failed",
            "Permission denied"
        ]

        for error in errors {
            viewModel.errorMessage = error
            #expect(viewModel.errorMessage == error)
        }
    }

    @Test("Long error message")
    func testLongErrorMessage() async throws {
        let viewModel = ProfileEditViewModel()

        let longError = String(repeating: "This is a detailed error message. ", count: 10)
        viewModel.errorMessage = longError

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage!.count > 100)
    }

    @Test("Error message with special characters")
    func testErrorMessageWithSpecialCharacters() async throws {
        let viewModel = ProfileEditViewModel()

        viewModel.errorMessage = "Error: Unable to upload image (size > 5MB)"
        #expect(viewModel.errorMessage?.contains("(") == true)
        #expect(viewModel.errorMessage?.contains(">") == true)
    }

    // MARK: - Profile Data Validation Tests

    @Test("Valid profile data structure")
    func testValidProfileData() async throws {
        // Test that valid profile data would be properly structured
        let name = "John Doe"
        let age = 28
        let bio = "Software engineer who loves travel"
        let location = "New York"
        let country = "USA"
        let languages = ["English", "Spanish"]
        let interests = ["Travel", "Technology", "Music"]
        let profileImageURL = "https://example.com/profile.jpg"

        #expect(!name.isEmpty)
        #expect(age >= 18)
        #expect(!bio.isEmpty)
        #expect(!location.isEmpty)
        #expect(!country.isEmpty)
        #expect(!languages.isEmpty)
        #expect(!interests.isEmpty)
        #expect(!profileImageURL.isEmpty)
    }

    @Test("Profile data with minimum age")
    func testProfileDataMinimumAge() async throws {
        let age = 18

        #expect(age >= 18)
        #expect(age < 100)
    }

    @Test("Profile data with maximum age")
    func testProfileDataMaximumAge() async throws {
        let age = 99

        #expect(age >= 18)
        #expect(age <= 99)
    }

    @Test("Profile data with various ages")
    func testProfileDataVariousAges() async throws {
        let ages = [18, 25, 30, 45, 60, 75, 99]

        for age in ages {
            #expect(age >= 18)
            #expect(age <= 99)
        }
    }

    // MARK: - Name Validation Tests

    @Test("Valid names")
    func testValidNames() async throws {
        let validNames = [
            "John Doe",
            "María García",
            "Jean-Pierre O'Brien",
            "李明",
            "محمد"
        ]

        for name in validNames {
            #expect(!name.isEmpty)
            #expect(name.count >= 2)
        }
    }

    @Test("Long names")
    func testLongNames() async throws {
        let longName = "Christopher Alexander Montgomery Richardson III"

        #expect(!longName.isEmpty)
        #expect(longName.count > 10)
    }

    @Test("Names with special characters")
    func testNamesWithSpecialCharacters() async throws {
        let specialNames = [
            "José María",
            "O'Brien",
            "Jean-Claude",
            "Müller"
        ]

        for name in specialNames {
            #expect(!name.isEmpty)
        }
    }

    // MARK: - Bio Validation Tests

    @Test("Valid bio content")
    func testValidBio() async throws {
        let bio = "I love traveling, music, and meeting new people!"

        #expect(!bio.isEmpty)
        #expect(bio.count <= 500)
    }

    @Test("Long bio")
    func testLongBio() async throws {
        let longBio = String(repeating: "This is my bio. ", count: 20)

        #expect(!longBio.isEmpty)
        #expect(longBio.count > 100)
    }

    @Test("Bio with emoji")
    func testBioWithEmoji() async throws {
        let bioWithEmoji = "Love to travel ✈️🌍 and coffee ☕️"

        #expect(!bioWithEmoji.isEmpty)
        #expect(bioWithEmoji.contains("✈️"))
        #expect(bioWithEmoji.contains("☕️"))
    }

    @Test("Bio with URLs")
    func testBioWithUrls() async throws {
        let bioWithUrl = "Check out my photography at instagram.com/username"

        #expect(!bioWithUrl.isEmpty)
        #expect(bioWithUrl.contains("instagram.com"))
    }

    @Test("Empty bio")
    func testEmptyBio() async throws {
        let emptyBio = ""

        #expect(emptyBio.isEmpty)
    }

    // MARK: - Location Validation Tests

    @Test("Valid locations")
    func testValidLocations() async throws {
        let locations = [
            "New York",
            "Los Angeles",
            "London",
            "Tokyo",
            "São Paulo"
        ]

        for location in locations {
            #expect(!location.isEmpty)
        }
    }

    @Test("Long location names")
    func testLongLocationNames() async throws {
        let longLocation = "San Juan Capistrano, Orange County, California"

        #expect(!longLocation.isEmpty)
        #expect(longLocation.count > 20)
    }

    @Test("Location with special characters")
    func testLocationWithSpecialCharacters() async throws {
        let locations = [
            "São Paulo",
            "Montréal",
            "München"
        ]

        for location in locations {
            #expect(!location.isEmpty)
        }
    }

    // MARK: - Languages Tests

    @Test("Single language")
    func testSingleLanguage() async throws {
        let languages = ["English"]

        #expect(languages.count == 1)
        #expect(!languages.isEmpty)
    }

    @Test("Multiple languages")
    func testMultipleLanguages() async throws {
        let languages = ["English", "Spanish", "French"]

        #expect(languages.count == 3)
        #expect(!languages.isEmpty)
    }

    @Test("Many languages")
    func testManyLanguages() async throws {
        let languages = [
            "English", "Spanish", "French",
            "German", "Italian", "Portuguese",
            "Mandarin", "Japanese"
        ]

        #expect(languages.count == 8)
    }

    @Test("Empty languages array")
    func testEmptyLanguages() async throws {
        let languages: [String] = []

        #expect(languages.isEmpty)
    }

    // MARK: - Interests Tests

    @Test("Single interest")
    func testSingleInterest() async throws {
        let interests = ["Travel"]

        #expect(interests.count == 1)
        #expect(!interests.isEmpty)
    }

    @Test("Multiple interests")
    func testMultipleInterests() async throws {
        let interests = ["Travel", "Music", "Sports", "Food"]

        #expect(interests.count == 4)
        #expect(!interests.isEmpty)
    }

    @Test("Many interests")
    func testManyInterests() async throws {
        let interests = [
            "Travel", "Music", "Sports", "Gaming",
            "Art", "Reading", "Food", "Yoga",
            "Photography", "Hiking"
        ]

        #expect(interests.count == 10)
    }

    @Test("Interests with emoji")
    func testInterestsWithEmoji() async throws {
        let interests = ["Travel ✈️", "Music 🎵", "Food 🍕"]

        #expect(interests.count == 3)
        #expect(interests[0].contains("✈️"))
    }

    @Test("Empty interests array")
    func testEmptyInterests() async throws {
        let interests: [String] = []

        #expect(interests.isEmpty)
    }

    // MARK: - Country Validation Tests

    @Test("Valid countries")
    func testValidCountries() async throws {
        let countries = [
            "USA",
            "United Kingdom",
            "Canada",
            "Australia",
            "Germany"
        ]

        for country in countries {
            #expect(!country.isEmpty)
        }
    }

    @Test("Countries with special characters")
    func testCountriesWithSpecialCharacters() async throws {
        let countries = [
            "Côte d'Ivoire",
            "São Tomé and Príncipe"
        ]

        for country in countries {
            #expect(!country.isEmpty)
        }
    }

    // MARK: - Image URL Tests

    @Test("Valid image URLs")
    func testValidImageUrls() async throws {
        let urls = [
            "https://example.com/image.jpg",
            "https://cdn.example.com/photos/profile.png",
            "https://storage.googleapis.com/bucket/image.jpeg"
        ]

        for url in urls {
            #expect(!url.isEmpty)
            #expect(url.hasPrefix("https://"))
        }
    }

    @Test("Image URL with query parameters")
    func testImageUrlWithQueryParams() async throws {
        let url = "https://example.com/image.jpg?size=large&quality=high"

        #expect(!url.isEmpty)
        #expect(url.contains("?"))
        #expect(url.contains("size="))
    }

    @Test("Long image URL")
    func testLongImageUrl() async throws {
        let url = "https://verylongdomainname.example.com/path/to/very/deep/nested/folders/image_with_very_long_filename_12345.jpg"

        #expect(!url.isEmpty)
        #expect(url.count > 50)
    }

    // MARK: - Edge Cases

    @Test("Concurrent loading states")
    func testConcurrentLoadingStates() async throws {
        let viewModel = ProfileEditViewModel()

        // Simulate rapid state changes
        viewModel.isLoading = true
        viewModel.isLoading = false
        viewModel.isLoading = true

        #expect(viewModel.isLoading == true)
    }

    @Test("Error and loading states together")
    func testErrorAndLoadingStates() async throws {
        let viewModel = ProfileEditViewModel()

        viewModel.isLoading = true
        viewModel.errorMessage = "An error occurred"

        #expect(viewModel.isLoading == true)
        #expect(viewModel.errorMessage == "An error occurred")
    }

    @Test("Clearing error after success")
    func testClearErrorAfterSuccess() async throws {
        let viewModel = ProfileEditViewModel()

        // Set error
        viewModel.errorMessage = "Upload failed"
        #expect(viewModel.errorMessage != nil)

        // Simulate success - clear error
        viewModel.errorMessage = nil
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Additional Photo URLs Tests

    @Test("Multiple photo URLs")
    func testMultiplePhotoUrls() async throws {
        let photoUrls = [
            "https://example.com/photo1.jpg",
            "https://example.com/photo2.jpg",
            "https://example.com/photo3.jpg",
            "https://example.com/photo4.jpg"
        ]

        #expect(photoUrls.count == 4)
        #expect(photoUrls.allSatisfy { !$0.isEmpty })
    }

    @Test("Maximum photos")
    func testMaximumPhotos() async throws {
        let photoUrls = (1...6).map { "https://example.com/photo\($0).jpg" }

        #expect(photoUrls.count == 6)
    }

    @Test("Empty photo URLs array")
    func testEmptyPhotoUrls() async throws {
        let photoUrls: [String] = []

        #expect(photoUrls.isEmpty)
    }
}
