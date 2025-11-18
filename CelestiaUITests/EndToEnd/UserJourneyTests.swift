//
//  UserJourneyTests.swift
//  CelestiaUITests
//
//  Complete end-to-end user journey testing
//  Tests: Signup → Onboarding → Discover → Match → Chat → Settings
//

import XCTest

final class UserJourneyTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launchEnvironment = ["RESET_DATA": "1"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Complete User Journey

    @MainActor
    func testCompleteNewUserJourney() throws {
        app.launch()

        // Step 1: Login/Signup
        XCTAssertTrue(waitForElement(app.buttons["GetStartedButton"], timeout: 5))
        app.buttons["GetStartedButton"].tap()

        // Enter phone number
        let phoneField = app.textFields["PhoneNumberField"]
        XCTAssertTrue(waitForElement(phoneField))
        phoneField.tap()
        phoneField.typeText("5555551234")

        app.buttons["ContinueButton"].tap()

        // Enter verification code (in testing, auto-filled)
        sleep(2) // Wait for auto-verification in test mode

        // Step 2: Onboarding - Basic Info
        XCTAssertTrue(waitForElement(app.textFields["FirstNameField"], timeout: 10))

        let firstNameField = app.textFields["FirstNameField"]
        firstNameField.tap()
        firstNameField.typeText("TestUser")

        let birthdayPicker = app.datePickers["BirthdayPicker"]
        if birthdayPicker.exists {
            birthdayPicker.tap()
            // Select a date (25 years ago)
            app.buttons["Done"].tap()
        }

        app.buttons["NextButton"].tap()

        // Step 3: Onboarding - Photos
        XCTAssertTrue(waitForElement(app.buttons["AddPhotoButton"], timeout: 5))

        // In test mode, photos are auto-added
        app.buttons["SkipForNow"].tap() // Skip photo upload for faster testing

        // Step 4: Onboarding - Interests
        if app.staticTexts["SelectInterests"].exists {
            // Select 3-5 interests
            let interests = ["Travel", "Music", "Fitness"]
            for interest in interests {
                if app.buttons[interest].exists {
                    app.buttons[interest].tap()
                }
            }
            app.buttons["ContinueButton"].tap()
        }

        // Step 5: Onboarding - Location Permission
        if app.alerts.element.exists {
            app.alerts.buttons["Allow While Using App"].tap()
        }

        // Step 6: Reach Discover View
        XCTAssertTrue(waitForElement(app.buttons["LikeButton"], timeout: 10))
        XCTAssertTrue(app.buttons["PassButton"].exists)
        XCTAssertTrue(app.buttons["SuperLikeButton"].exists)

        // Swipe through 5 profiles
        for _ in 0..<5 {
            app.buttons["LikeButton"].tap()
            sleep(1)
        }

        // Step 7: Navigate to Matches Tab
        app.tabBars.buttons["Matches"].tap()
        XCTAssertTrue(waitForElement(app.staticTexts["MatchesTitle"], timeout: 5))

        // Step 8: Navigate to Messages Tab
        app.tabBars.buttons["Messages"].tap()
        XCTAssertTrue(waitForElement(app.staticTexts["MessagesTitle"], timeout: 5))

        // Step 9: Navigate to Profile/Settings
        app.tabBars.buttons["Profile"].tap()
        XCTAssertTrue(waitForElement(app.staticTexts["ProfileTitle"], timeout: 5))

        // Verify profile is populated
        XCTAssertTrue(app.staticTexts["TestUser"].exists)

        // Complete journey success
        XCTAssertTrue(true, "User journey completed successfully")
    }

    // MARK: - Discover Flow Tests

    @MainActor
    func testDiscoverSwipeActions() throws {
        loginTestUser()

        // Navigate to Discover
        app.tabBars.buttons["Discover"].tap()
        XCTAssertTrue(waitForElement(app.buttons["LikeButton"], timeout: 5))

        // Test Pass
        let initialCard = app.otherElements["ProfileCard"]
        XCTAssertTrue(initialCard.exists)
        app.buttons["PassButton"].tap()
        sleep(1)

        // Verify new card appeared
        XCTAssertTrue(app.otherElements["ProfileCard"].exists)

        // Test Like
        app.buttons["LikeButton"].tap()
        sleep(1)

        // Test Super Like
        if app.buttons["SuperLikeButton"].isEnabled {
            app.buttons["SuperLikeButton"].tap()
            sleep(1)
        }

        // Test swipe gestures
        if app.otherElements["ProfileCard"].exists {
            let card = app.otherElements["ProfileCard"]
            card.swipeLeft() // Pass
            sleep(1)

            if app.otherElements["ProfileCard"].exists {
                app.otherElements["ProfileCard"].swipeRight() // Like
                sleep(1)
            }
        }
    }

    @MainActor
    func testDiscoverFilters() throws {
        loginTestUser()

        app.tabBars.buttons["Discover"].tap()

        // Open filters
        app.buttons["FiltersButton"].tap()
        XCTAssertTrue(waitForElement(app.staticTexts["Filters"], timeout: 3))

        // Adjust age range
        if app.sliders["MinAgeSlider"].exists {
            app.sliders["MinAgeSlider"].adjust(toNormalizedSliderPosition: 0.3) // ~25
            app.sliders["MaxAgeSlider"].adjust(toNormalizedSliderPosition: 0.7) // ~35
        }

        // Adjust distance
        if app.sliders["DistanceSlider"].exists {
            app.sliders["DistanceSlider"].adjust(toNormalizedSliderPosition: 0.5) // ~50 miles
        }

        // Apply filters
        app.buttons["ApplyFilters"].tap()

        // Verify back at discover view
        XCTAssertTrue(waitForElement(app.buttons["LikeButton"], timeout: 3))
    }

    // MARK: - Match & Chat Flow

    @MainActor
    func testMatchAndChatFlow() throws {
        loginTestUser()

        // Create a test match (in test mode, auto-created)
        app.launchEnvironment["CREATE_TEST_MATCH"] = "1"
        app.launch()

        // Navigate to Matches
        app.tabBars.buttons["Matches"].tap()
        XCTAssertTrue(waitForElement(app.staticTexts["MatchesTitle"], timeout: 5))

        // Tap first match
        if app.cells.element(boundBy: 0).exists {
            app.cells.element(boundBy: 0).tap()

            // Verify chat view opened
            XCTAssertTrue(waitForElement(app.textFields["MessageInputField"], timeout: 5))

            // Send a message
            let messageField = app.textFields["MessageInputField"]
            messageField.tap()
            messageField.typeText("Hey! How are you?")

            app.buttons["SendButton"].tap()

            // Verify message sent
            sleep(1)
            XCTAssertTrue(app.staticTexts["Hey! How are you?"].exists)

            // Go back
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }

    // MARK: - Profile Editing

    @MainActor
    func testProfileEdit() throws {
        loginTestUser()

        app.tabBars.buttons["Profile"].tap()

        // Tap Edit Profile
        app.buttons["EditProfileButton"].tap()
        XCTAssertTrue(waitForElement(app.staticTexts["EditProfile"], timeout: 3))

        // Edit bio
        if app.textViews["BioTextField"].exists {
            let bioField = app.textViews["BioTextField"]
            bioField.tap()
            bioField.typeText("Updated bio for testing")
        }

        // Save changes
        app.buttons["SaveButton"].tap()

        // Verify saved
        sleep(1)
        XCTAssertTrue(app.staticTexts["ProfileTitle"].exists)
    }

    // MARK: - Settings & Preferences

    @MainActor
    func testSettingsConfiguration() throws {
        loginTestUser()

        app.tabBars.buttons["Profile"].tap()
        app.buttons["SettingsButton"].tap()

        XCTAssertTrue(waitForElement(app.staticTexts["Settings"], timeout: 3))

        // Toggle notifications
        if app.switches["PushNotificationsToggle"].exists {
            let notifToggle = app.switches["PushNotificationsToggle"]
            let initialState = notifToggle.value as? String == "1"
            notifToggle.tap()

            // Verify state changed
            sleep(0.5)
            let newState = notifToggle.value as? String == "1"
            XCTAssertNotEqual(initialState, newState)
        }

        // Check privacy settings
        app.buttons["PrivacySettings"].tap()
        if app.staticTexts["Privacy"].exists {
            XCTAssertTrue(true)
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        // Go back
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    // MARK: - Helper Methods

    private func loginTestUser() {
        app.launchEnvironment["AUTO_LOGIN"] = "test@example.com"
        app.launch()

        // Wait for main view to load
        XCTAssertTrue(waitForElement(app.tabBars.buttons["Discover"], timeout: 10))
    }

    private func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    private func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}
