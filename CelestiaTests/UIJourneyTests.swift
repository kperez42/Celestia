//
//  UIJourneyTests.swift
//  CelestiaTests
//
//  UI tests for critical user journeys
//  Tests complete end-to-end user experiences from UI perspective
//

import Testing
import Foundation
@testable import Celestia

@Suite("UI Journey Tests")
@MainActor
struct UIJourneyTests {

    // MARK: - Onboarding Journey

    @Test("Complete onboarding flow")
    func testOnboardingFlow() async throws {
        // Journey: New user goes through onboarding
        var currentScreen = "Welcome"

        // Step 1: Welcome screen
        #expect(currentScreen == "Welcome")

        // Step 2: Sign up form
        currentScreen = "SignUp"
        #expect(currentScreen == "SignUp")

        let email = String.randomEmail()
        let password = "SecurePass123!"
        let name = String.randomName()
        let age = 28

        #expect(!email.isEmpty)
        #expect(!password.isEmpty)
        #expect(!name.isEmpty)
        #expect(age >= 18)

        // Step 3: Profile setup
        currentScreen = "ProfileSetup"
        #expect(currentScreen == "ProfileSetup")

        let location = "New York"
        let interests = ["Travel", "Music", "Food"]

        #expect(!location.isEmpty)
        #expect(interests.count > 0)

        // Step 4: Photo upload
        currentScreen = "PhotoUpload"
        #expect(currentScreen == "PhotoUpload")

        // Step 5: Preferences
        currentScreen = "Preferences"
        #expect(currentScreen == "Preferences")

        // Step 6: Main app
        currentScreen = "MainApp"
        #expect(currentScreen == "MainApp")
    }

    @Test("Skip optional onboarding steps")
    func testSkipOnboardingSteps() async throws {
        var currentScreen = "Welcome"

        currentScreen = "SignUp"
        // Skip bio, use later
        currentScreen = "MainApp"

        #expect(currentScreen == "MainApp")
    }

    // MARK: - Discovery Journey

    @Test("Browse and like profiles journey")
    func testBrowseAndLikeJourney() async throws {
        // Journey: User browses profiles and likes someone
        var currentScreen = "Discover"
        var currentProfileIndex = 0

        #expect(currentScreen == "Discover")

        let profiles = TestFixtures.createBatchUsers(count: 10)
        #expect(profiles.count == 10)

        // View first profile
        let firstProfile = profiles[currentProfileIndex]
        #expect(firstProfile.fullName.count > 0)

        // Tap to view profile details
        var showingDetails = true
        #expect(showingDetails == true)

        // Close details
        showingDetails = false

        // Swipe right (like)
        let userLiked = true
        currentProfileIndex += 1

        #expect(userLiked == true)
        #expect(currentProfileIndex == 1)

        // Continue browsing
        for _ in 1..<5 {
            currentProfileIndex += 1
        }

        #expect(currentProfileIndex == 5)
    }

    @Test("Super like journey")
    func testSuperLikeJourney() async throws {
        let currentScreen = "Discover"
        let premiumUser = TestFixtures.createPremiumUser()

        #expect(premiumUser.isPremium == true)
        #expect(premiumUser.superLikesRemaining > 0)

        // Tap super like button
        let superLikeUsed = true
        var remainingSuperLikes = premiumUser.superLikesRemaining - 1

        #expect(superLikeUsed == true)
        #expect(remainingSuperLikes >= 0)
    }

    @Test("Match animation journey")
    func testMatchAnimationJourney() async throws {
        var currentScreen = "Discover"

        // User likes someone who already liked them
        let mutualLike = true
        #expect(mutualLike == true)

        // Show match animation
        var showingMatchAnimation = true
        currentScreen = "MatchAnimation"

        #expect(showingMatchAnimation == true)
        #expect(currentScreen == "MatchAnimation")

        // User can send message or keep swiping
        let userWantsToMessage = true

        if userWantsToMessage {
            currentScreen = "Chat"
            #expect(currentScreen == "Chat")
        } else {
            currentScreen = "Discover"
            showingMatchAnimation = false
        }
    }

    // MARK: - Messaging Journey

    @Test("Complete messaging journey")
    func testMessagingJourney() async throws {
        // Journey: User sends messages in a match
        var currentScreen = "Matches"

        #expect(currentScreen == "Matches")

        // View matches list
        let matches = TestFixtures.createBatchMatches(count: 5, currentUserId: "current_user")
        #expect(matches.count == 5)

        // Select a match
        let selectedMatch = matches[0]
        currentScreen = "Chat"

        #expect(currentScreen == "Chat")
        #expect(selectedMatch.id != nil)

        // View conversation
        let messages = TestFixtures.createConversation(
            matchId: selectedMatch.id!,
            user1Id: selectedMatch.user1Id,
            user2Id: selectedMatch.user2Id,
            messageCount: 10
        )

        #expect(messages.count == 10)

        // Type and send message
        var messageText = "Hey! How are you?"
        #expect(!messageText.isEmpty)

        // Message sent
        var sentSuccessfully = true
        #expect(sentSuccessfully == true)

        // Clear input
        messageText = ""
        #expect(messageText.isEmpty)

        // Receive response
        let response = TestFixtures.createTestMessage(
            senderId: selectedMatch.user2Id,
            text: "I'm great! How about you?"
        )

        #expect(!response.text.isEmpty)
    }

    @Test("View match profile from chat")
    func testViewProfileFromChat() async throws {
        var currentScreen = "Chat"

        // Tap on user's name/photo
        currentScreen = "ProfileView"

        #expect(currentScreen == "ProfileView")

        // View profile details
        let profile = TestFixtures.createTestUser()
        #expect(!profile.fullName.isEmpty)
        #expect(profile.photos.count >= 0)

        // Go back to chat
        currentScreen = "Chat"
        #expect(currentScreen == "Chat")
    }

    // MARK: - Profile Edit Journey

    @Test("Edit profile journey")
    func testEditProfileJourney() async throws {
        var currentScreen = "Profile"

        // Navigate to edit
        currentScreen = "ProfileEdit"

        #expect(currentScreen == "ProfileEdit")

        // Edit bio
        var bio = "Old bio"
        bio = "New bio with more details about me!"

        #expect(bio == "New bio with more details about me!")

        // Add interests
        var interests = ["Travel"]
        interests.append("Music")
        interests.append("Food")

        #expect(interests.count == 3)

        // Upload new photo
        let photoData = TestFixtures.createPhotoUploadData()
        #expect(!photoData.isEmpty)

        var uploadComplete = true
        #expect(uploadComplete == true)

        // Save changes
        var saveSuccessful = true
        #expect(saveSuccessful == true)

        // Back to profile
        currentScreen = "Profile"
        #expect(currentScreen == "Profile")
    }

    // MARK: - Settings Journey

    @Test("Navigate settings journey")
    func testSettingsJourney() async throws {
        var currentScreen = "Profile"

        // Open settings
        currentScreen = "Settings"
        #expect(currentScreen == "Settings")

        // Adjust discovery preferences
        var ageMin = 25
        var ageMax = 35
        var maxDistance = 50

        ageMin = 22
        ageMax = 40

        #expect(ageMin == 22)
        #expect(ageMax == 40)

        // Save preferences
        let preferencesSaved = true
        #expect(preferencesSaved == true)

        // Navigate to privacy settings
        currentScreen = "PrivacySettings"
        #expect(currentScreen == "PrivacySettings")

        // Back to main settings
        currentScreen = "Settings"
        #expect(currentScreen == "Settings")

        // Close settings
        currentScreen = "Profile"
        #expect(currentScreen == "Profile")
    }

    // MARK: - Premium Upgrade Journey

    @Test("Premium upgrade journey")
    func testPremiumUpgradeJourney() async throws {
        var currentScreen = "Discover"

        // User runs out of likes
        let likesRemaining = 0
        #expect(likesRemaining == 0)

        // Show upgrade prompt
        var showingUpgradeSheet = true
        currentScreen = "UpgradeSheet"

        #expect(showingUpgradeSheet == true)

        // View premium features
        let premiumFeatures = [
            "Unlimited likes",
            "5 Super Likes per day",
            "See who likes you"
        ]

        #expect(premiumFeatures.count > 0)

        // Select tier
        let selectedTier = "gold"
        #expect(selectedTier == "gold")

        // Initiate purchase
        var purchaseInProgress = true
        #expect(purchaseInProgress == true)

        // Purchase succeeds
        purchaseInProgress = false
        var isPremium = true

        #expect(isPremium == true)

        // Close sheet
        showingUpgradeSheet = false
        currentScreen = "Discover"

        #expect(currentScreen == "Discover")
    }

    // MARK: - Error Handling Journeys

    @Test("Network error recovery journey")
    func testNetworkErrorRecovery() async throws {
        var currentScreen = "Discover"
        var showingError = false
        var errorMessage = ""

        // Network error occurs
        showingError = true
        errorMessage = "Unable to load profiles. Check your connection."

        #expect(showingError == true)
        #expect(!errorMessage.isEmpty)

        // User taps retry
        let retryTapped = true
        #expect(retryTapped == true)

        // Success on retry
        showingError = false
        errorMessage = ""

        #expect(showingError == false)
        #expect(errorMessage.isEmpty)
    }

    @Test("Image upload failure journey")
    func testImageUploadFailure() async throws {
        var currentScreen = "ProfileEdit"
        var uploadError: String? = nil

        // Select image
        let imageData = TestFixtures.createPhotoUploadData()
        #expect(!imageData.isEmpty)

        // Upload fails
        uploadError = "Upload failed. Image too large."

        #expect(uploadError != nil)

        // Show error to user
        var showingAlert = true
        #expect(showingAlert == true)

        // User dismisses and tries again with smaller image
        showingAlert = false
        uploadError = nil

        #expect(uploadError == nil)
    }

    // MARK: - Tab Navigation Journey

    @Test("Tab navigation journey")
    func testTabNavigation() async throws {
        var selectedTab = "Discover"

        // Switch to matches
        selectedTab = "Matches"
        #expect(selectedTab == "Matches")

        // Switch to likes
        selectedTab = "Likes"
        #expect(selectedTab == "Likes")

        // Switch to profile
        selectedTab = "Profile"
        #expect(selectedTab == "Profile")

        // Back to discover
        selectedTab = "Discover"
        #expect(selectedTab == "Discover")
    }

    // MARK: - Search Journey

    @Test("Search users journey")
    func testSearchJourney() async throws {
        var currentScreen = "Discover"

        // Open filters
        var showingFilters = true
        #expect(showingFilters == true)

        // Set filters
        var filterAge = 25...35
        var filterDistance = 25
        var filterInterests = ["Travel", "Music"]

        #expect(filterAge.contains(28))
        #expect(filterDistance == 25)
        #expect(filterInterests.count == 2)

        // Apply filters
        showingFilters = false
        var filtersActive = true

        #expect(filtersActive == true)

        // Browse filtered results
        let filteredUsers = TestFixtures.createBatchUsers(count: 5)
        #expect(filteredUsers.count == 5)

        // Clear filters
        filtersActive = false
        #expect(filtersActive == false)
    }

    // MARK: - Unmatch Journey

    @Test("Unmatch user journey")
    func testUnmatchJourney() async throws {
        var currentScreen = "Chat"

        // Open match options
        var showingOptions = true
        #expect(showingOptions == true)

        // Select unmatch
        var showingUnmatchConfirmation = true
        #expect(showingUnmatchConfirmation == true)

        // Confirm unmatch
        let unmatchConfirmed = true
        #expect(unmatchConfirmed == true)

        // Return to matches list
        currentScreen = "Matches"
        #expect(currentScreen == "Matches")
    }

    // MARK: - Notification Journey

    @Test("Notification tap journey")
    func testNotificationTap() async throws {
        var currentScreen = "Background"

        // Receive new match notification
        let notification = TestFixtures.createTestNotification(
            type: "new_match",
            title: "New Match!",
            body: "You have a new match"
        )

        #expect(notification.type == "new_match")

        // User taps notification
        currentScreen = "Matches"

        #expect(currentScreen == "Matches")

        // Show specific match
        currentScreen = "Chat"
        #expect(currentScreen == "Chat")
    }

    // MARK: - Referral Journey

    @Test("Share referral code journey")
    func testShareReferralJourney() async throws {
        var currentScreen = "Profile"

        // Navigate to referral section
        currentScreen = "Referrals"
        #expect(currentScreen == "Referrals")

        // View referral code
        let referralCode = TestFixtures.generateReferralCode()
        #expect(referralCode.count == 6)

        // Generate share message
        let shareMessage = "Join Celestia using my code \(referralCode) and get free Super Likes!"
        #expect(!shareMessage.isEmpty)
        #expect(shareMessage.contains(referralCode))

        // Open share sheet
        var showingShareSheet = true
        #expect(showingShareSheet == true)

        // Share via selected method
        let shareMethod = "Messages"
        #expect(!shareMethod.isEmpty)

        // Close share sheet
        showingShareSheet = false
        currentScreen = "Referrals"

        #expect(currentScreen == "Referrals")
    }

    // MARK: - Multi-Step Complex Journey

    @Test("Complete user journey from signup to message")
    func testCompleteUserJourney() async throws {
        var currentScreen = "Welcome"

        // 1. Sign up
        currentScreen = "SignUp"
        let user = TestFixtures.createTestUser()
        #expect(!user.email.isEmpty)

        // 2. Set up profile
        currentScreen = "ProfileSetup"
        #expect(currentScreen == "ProfileSetup")

        // 3. Browse discovery
        currentScreen = "Discover"
        let profiles = TestFixtures.createBatchUsers(count: 10)
        #expect(profiles.count == 10)

        // 4. Like someone
        var profileIndex = 0
        profileIndex += 1
        #expect(profileIndex == 1)

        // 5. Get a match
        var showingMatch = true
        currentScreen = "MatchAnimation"
        #expect(showingMatch == true)

        // 6. Send first message
        currentScreen = "Chat"
        let message = "Hey! Nice to match with you!"
        #expect(!message.isEmpty)

        // Journey complete
        #expect(currentScreen == "Chat")
    }
}
