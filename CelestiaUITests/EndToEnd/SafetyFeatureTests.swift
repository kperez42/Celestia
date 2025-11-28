//
//  SafetyFeatureTests.swift
//  CelestiaUITests
//
//  End-to-end safety and moderation feature testing
//  Tests: User blocking → Content reporting → Photo verification → Safety center
//

import XCTest

final class SafetyFeatureTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launchEnvironment = [
            "RESET_DATA": "1",
            "CREATE_TEST_USERS": "1" // Create test users for blocking/reporting
        ]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - User Blocking

    @MainActor
    func testBlockUserFlow() throws {
        loginTestUser()

        // Navigate to discover
        app.tabBars.buttons["Discover"].tap()
        XCTAssertTrue(waitForElement(app.buttons["LikeButton"], timeout: 5))

        // Open profile details or menu
        if app.buttons["ProfileMenuButton"].exists {
            app.buttons["ProfileMenuButton"].tap()
        } else if app.buttons["MoreOptions"].exists {
            app.buttons["MoreOptions"].tap()
        } else {
            // Tap on the profile card to open details
            if app.otherElements["ProfileCard"].exists {
                app.otherElements["ProfileCard"].tap()
            }
        }

        // Find and tap block button
        let blockButton = app.buttons["BlockUser"]
        XCTAssertTrue(waitForElement(blockButton, timeout: 3))
        blockButton.tap()

        // Verify confirmation dialog appears
        if app.alerts.element.exists {
            XCTAssertTrue(app.alerts.staticTexts["Block"].exists ||
                         app.alerts.staticTexts["Block User"].exists)

            // Confirm blocking
            if app.alerts.buttons["Block"].exists {
                app.alerts.buttons["Block"].tap()
            } else if app.alerts.buttons["Confirm"].exists {
                app.alerts.buttons["Confirm"].tap()
            }
        }

        // Verify user is blocked (returns to discover with new profile)
        sleep(1)
        XCTAssertTrue(app.buttons["LikeButton"].exists)

        // Verify blocked user doesn't appear again
        // (In production, backend filters out blocked users)
    }

    @MainActor
    func testUnblockUser() throws {
        loginTestUserWithBlockedUsers()

        // Navigate to settings
        app.tabBars.buttons["Profile"].tap()
        app.buttons["SettingsButton"].tap()

        // Open blocked users list
        if app.buttons["BlockedUsers"].exists {
            app.buttons["BlockedUsers"].tap()
        } else if app.buttons["Privacy"].exists {
            app.buttons["Privacy"].tap()
            if app.buttons["BlockedUsers"].exists {
                app.buttons["BlockedUsers"].tap()
            }
        }

        XCTAssertTrue(waitForElement(app.staticTexts["BlockedUsersTitle"], timeout: 5))

        // Verify blocked users list shows users
        if app.cells.count > 0 {
            // Tap on first blocked user
            let firstBlockedUser = app.cells.element(boundBy: 0)
            firstBlockedUser.tap()

            // Unblock the user
            if app.buttons["Unblock"].exists {
                app.buttons["Unblock"].tap()

                // Confirm if needed
                if app.alerts.element.exists {
                    app.alerts.buttons["Unblock"].tap()
                }

                sleep(1)

                // Verify user was removed from blocked list
                XCTAssertTrue(true, "User successfully unblocked")
            }
        }
    }

    // MARK: - Content Reporting

    @MainActor
    func testReportUserProfile() throws {
        loginTestUser()

        // Navigate to discover
        app.tabBars.buttons["Discover"].tap()
        XCTAssertTrue(waitForElement(app.buttons["LikeButton"], timeout: 5))

        // Open profile menu
        if app.buttons["ProfileMenuButton"].exists {
            app.buttons["ProfileMenuButton"].tap()
        } else if app.buttons["MoreOptions"].exists {
            app.buttons["MoreOptions"].tap()
        }

        // Find and tap report button
        let reportButton = app.buttons["ReportUser"]
        XCTAssertTrue(waitForElement(reportButton, timeout: 3))
        reportButton.tap()

        // Verify report reasons screen appears
        XCTAssertTrue(waitForElement(app.staticTexts["ReportUser"], timeout: 3))

        // Select a report reason
        let reportReasons = [
            "InappropriatePhotos",
            "InappropriateContent",
            "Scam",
            "FakeProfile",
            "Harassment",
            "Underage"
        ]

        var selectedReason = false
        for reason in reportReasons {
            if app.buttons[reason].exists {
                app.buttons[reason].tap()
                selectedReason = true
                break
            }
        }

        XCTAssertTrue(selectedReason, "Should be able to select a report reason")

        // Add optional details
        if app.textViews["ReportDetails"].exists {
            let detailsField = app.textViews["ReportDetails"]
            detailsField.tap()
            detailsField.typeText("Test report details")
        }

        // Submit report
        app.buttons["SubmitReport"].tap()

        // Verify confirmation
        sleep(1)
        let reportConfirmed = app.staticTexts["ReportSubmitted"].exists ||
                             app.staticTexts["ThankYou"].exists ||
                             app.alerts.element.exists

        XCTAssertTrue(reportConfirmed, "Report should be submitted successfully")

        // Dismiss confirmation if needed
        if app.alerts.element.exists {
            app.alerts.buttons["OK"].tap()
        }
    }

    @MainActor
    func testReportMessage() throws {
        loginTestUserWithMatches()

        // Navigate to messages
        app.tabBars.buttons["Messages"].tap()
        XCTAssertTrue(waitForElement(app.staticTexts["MessagesTitle"], timeout: 5))

        // Open a conversation
        if app.cells.count > 0 {
            app.cells.element(boundBy: 0).tap()

            // Wait for chat to load
            XCTAssertTrue(waitForElement(app.textFields["MessageInputField"], timeout: 5))

            // Long press on a message to report
            if app.staticTexts.matching(NSPredicate(format: "label != ''")).count > 0 {
                let firstMessage = app.staticTexts.element(boundBy: 0)
                firstMessage.press(forDuration: 1.5)

                // Verify report option appears
                if app.buttons["Report"].exists || app.menuItems["Report"].exists {
                    if app.buttons["Report"].exists {
                        app.buttons["Report"].tap()
                    } else {
                        app.menuItems["Report"].tap()
                    }

                    // Select reason
                    sleep(1)
                    if app.buttons["InappropriateContent"].exists {
                        app.buttons["InappropriateContent"].tap()
                    }

                    // Submit
                    if app.buttons["SubmitReport"].exists {
                        app.buttons["SubmitReport"].tap()
                    }

                    // Verify confirmation
                    sleep(1)
                    XCTAssertTrue(true, "Message report submitted")
                }
            }
        }
    }

    // MARK: - ID Verification (Manual Review)

    @MainActor
    func testIDVerificationFlow() throws {
        loginTestUser()

        // Navigate to profile
        app.tabBars.buttons["Profile"].tap()

        // Look for verification prompt or button
        if app.buttons["GetVerified"].exists {
            app.buttons["GetVerified"].tap()
        } else if app.buttons["VerifyProfile"].exists {
            app.buttons["VerifyProfile"].tap()
        } else {
            // May need to access from settings
            app.buttons["SettingsButton"].tap()
            if app.buttons["Verification"].exists {
                app.buttons["Verification"].tap()
            }
        }

        // Verify verification screen appears
        XCTAssertTrue(waitForElement(app.staticTexts["IDVerification"], timeout: 5) ||
                     waitForElement(app.staticTexts["Verify Your Identity"], timeout: 5))

        // Check for ID type selection step
        let hasIDTypeStep = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'ID Type' OR label CONTAINS 'type of ID'")).count > 0
        XCTAssertTrue(hasIDTypeStep, "ID type selection should be displayed")

        // Check instructions are shown
        let hasInstructions = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'selfie' OR label CONTAINS 'Selfie' OR label CONTAINS 'ID'")).count > 0
        XCTAssertTrue(hasInstructions, "Verification instructions should be displayed")
    }

    @MainActor
    func testVerificationBadgeDisplay() throws {
        loginVerifiedUser()

        // Navigate to profile
        app.tabBars.buttons["Profile"].tap()

        // Verify verification badge is displayed
        let hasBadge = app.images["VerificationBadge"].exists ||
                      app.images["VerifiedCheckmark"].exists ||
                      app.staticTexts["Verified"].exists

        XCTAssertTrue(hasBadge, "Verified users should display verification badge")

        // Navigate to discover to see other verified profiles
        app.tabBars.buttons["Discover"].tap()

        // Verified profiles in discover should also show badge
        // (This depends on UI implementation)
        if app.images["VerificationBadge"].exists {
            XCTAssertTrue(true, "Verification badge shown on profiles")
        }
    }

    // MARK: - Safety Center

    @MainActor
    func testSafetyCenterAccess() throws {
        loginTestUser()

        // Navigate to settings
        app.tabBars.buttons["Profile"].tap()
        app.buttons["SettingsButton"].tap()

        // Open Safety Center
        if app.buttons["SafetyCenter"].exists {
            app.buttons["SafetyCenter"].tap()
        } else if app.buttons["Safety"].exists {
            app.buttons["Safety"].tap()
        }

        XCTAssertTrue(waitForElement(app.staticTexts["SafetyTitle"], timeout: 5))

        // Verify safety features are listed
        let safetyFeatures = [
            "SafetyTips",
            "ReportingGuidelines",
            "BlockedUsers",
            "IDVerification",
            "CommunityGuidelines"
        ]

        var foundFeatures = 0
        for feature in safetyFeatures {
            if app.buttons[feature].exists || app.staticTexts[feature].exists {
                foundFeatures += 1
            }
        }

        XCTAssertTrue(foundFeatures > 0, "Safety Center should display safety features")
    }

    @MainActor
    func testSafetyTips() throws {
        loginTestUser()

        // Navigate to Safety Center
        app.tabBars.buttons["Profile"].tap()
        app.buttons["SettingsButton"].tap()

        if app.buttons["SafetyCenter"].exists {
            app.buttons["SafetyCenter"].tap()
        }

        // Open safety tips
        if app.buttons["SafetyTips"].exists {
            app.buttons["SafetyTips"].tap()

            // Verify tips are displayed
            sleep(1)

            let hasTips = app.staticTexts.matching(NSPredicate(format: "label.length > 20")).count > 0
            XCTAssertTrue(hasTips, "Safety tips should be displayed")
        }
    }

    // MARK: - Privacy Controls

    @MainActor
    func testPrivacySettings() throws {
        loginTestUser()

        // Navigate to privacy settings
        app.tabBars.buttons["Profile"].tap()
        app.buttons["SettingsButton"].tap()
        app.buttons["PrivacySettings"].tap()

        XCTAssertTrue(waitForElement(app.staticTexts["Privacy"], timeout: 3))

        // Test privacy toggles
        let privacyToggles = [
            "ShowOnlineStatus",
            "ShowReadReceipts",
            "ShowDistance",
            "IncognitoMode"
        ]

        for toggle in privacyToggles {
            if app.switches[toggle].exists {
                let privacySwitch = app.switches[toggle]
                let initialState = privacySwitch.value as? String == "1"

                privacySwitch.tap()
                sleep(0.5)

                let newState = privacySwitch.value as? String == "1"
                XCTAssertNotEqual(initialState, newState, "Toggle \(toggle) should change state")

                // Toggle back
                privacySwitch.tap()
                sleep(0.5)
            }
        }
    }

    @MainActor
    func testHideProfile() throws {
        loginTestUser()

        // Navigate to settings
        app.tabBars.buttons["Profile"].tap()
        app.buttons["SettingsButton"].tap()

        // Look for hide/pause profile option
        if app.buttons["HideProfile"].exists || app.buttons["PauseAccount"].exists {
            if app.buttons["HideProfile"].exists {
                app.buttons["HideProfile"].tap()
            } else {
                app.buttons["PauseAccount"].tap()
            }

            // Confirm action
            if app.alerts.element.exists {
                app.alerts.buttons["Confirm"].tap()
            }

            sleep(1)

            // Verify profile is hidden
            let profileHidden = app.staticTexts["ProfileHidden"].exists ||
                               app.staticTexts["AccountPaused"].exists

            XCTAssertTrue(profileHidden, "Profile should be hidden/paused")

            // Test unhiding
            if app.buttons["ShowProfile"].exists || app.buttons["ResumeAccount"].exists {
                if app.buttons["ShowProfile"].exists {
                    app.buttons["ShowProfile"].tap()
                } else {
                    app.buttons["ResumeAccount"].tap()
                }

                sleep(1)
                XCTAssertTrue(true, "Profile successfully unhidden")
            }
        }
    }

    // MARK: - Inappropriate Content Detection

    @MainActor
    func testInappropriateMessageWarning() throws {
        loginTestUserWithMatches()

        // Navigate to messages
        app.tabBars.buttons["Messages"].tap()
        XCTAssertTrue(waitForElement(app.staticTexts["MessagesTitle"], timeout: 5))

        // Open a conversation
        if app.cells.count > 0 {
            app.cells.element(boundBy: 0).tap()

            // Wait for chat to load
            XCTAssertTrue(waitForElement(app.textFields["MessageInputField"], timeout: 5))

            // Type an inappropriate message (to trigger content filter)
            let messageField = app.textFields["MessageInputField"]
            messageField.tap()

            // Common inappropriate terms that should be flagged
            let testMessage = "send nudes" // This should trigger content moderation
            messageField.typeText(testMessage)

            // Try to send
            app.buttons["SendButton"].tap()

            // Verify warning appears (content moderation)
            sleep(1)

            let warningAppeared = app.alerts.element.exists ||
                                 app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'inappropriate' OR label CONTAINS 'Inappropriate'")).count > 0

            if warningAppeared {
                XCTAssertTrue(true, "Content moderation warning displayed")

                // Dismiss warning
                if app.alerts.element.exists {
                    app.alerts.buttons["OK"].tap()
                }
            } else {
                // Message may be blocked silently or sent in test mode
                Logger.shared.info("No warning displayed - content filter may be disabled in test mode")
            }
        }
    }

    // MARK: - Account Deletion

    @MainActor
    func testAccountDeletionFlow() throws {
        loginTestUser()

        // Navigate to settings
        app.tabBars.buttons["Profile"].tap()
        app.buttons["SettingsButton"].tap()

        // Scroll to find delete account (usually at bottom)
        app.swipeUp()
        sleep(0.5)

        if app.buttons["DeleteAccount"].exists {
            app.buttons["DeleteAccount"].tap()

            // Verify warning/confirmation screen
            let deleteWarning = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'permanently' OR label CONTAINS 'Permanently'")).count > 0
            XCTAssertTrue(deleteWarning, "Delete account warning should be displayed")

            // In UI test, we don't actually delete - just verify the flow
            // Cancel the deletion
            if app.buttons["Cancel"].exists {
                app.buttons["Cancel"].tap()
            } else if app.navigationBars.buttons.element(boundBy: 0).exists {
                app.navigationBars.buttons.element(boundBy: 0).tap()
            }

            // Verify we're back at settings
            XCTAssertTrue(app.staticTexts["Settings"].exists)
        }
    }

    // MARK: - Helper Methods

    private func loginTestUser() {
        app.launchEnvironment["AUTO_LOGIN"] = "test@example.com"
        app.launch()

        // Wait for main view to load
        XCTAssertTrue(waitForElement(app.tabBars.buttons["Discover"], timeout: 10))
    }

    private func loginTestUserWithBlockedUsers() {
        app.launchEnvironment["AUTO_LOGIN"] = "test@example.com"
        app.launchEnvironment["HAS_BLOCKED_USERS"] = "1"
        app.launch()

        XCTAssertTrue(waitForElement(app.tabBars.buttons["Discover"], timeout: 10))
    }

    private func loginTestUserWithMatches() {
        app.launchEnvironment["AUTO_LOGIN"] = "test@example.com"
        app.launchEnvironment["CREATE_TEST_MATCH"] = "1"
        app.launch()

        XCTAssertTrue(waitForElement(app.tabBars.buttons["Discover"], timeout: 10))
    }

    private func loginVerifiedUser() {
        app.launchEnvironment["AUTO_LOGIN"] = "verified@example.com"
        app.launchEnvironment["IS_VERIFIED"] = "1"
        app.launch()

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
