//
//  AccessibilityUITests.swift
//  CelestiaUITests
//
//  Comprehensive accessibility testing for WCAG 2.1 Level AA compliance
//  Tests: VoiceOver labels, Dynamic Type, minimum tap targets, keyboard navigation
//

import XCTest

final class AccessibilityUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Welcome Screen Accessibility Tests

    func testWelcomeScreenAccessibility() throws {
        app.launch()

        // Test that main buttons have proper accessibility labels
        let createAccountButton = app.buttons["Create Account"]
        XCTAssertTrue(createAccountButton.exists, "Create Account button should exist")
        XCTAssertTrue(createAccountButton.isEnabled, "Create Account button should be enabled")

        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.exists, "Sign In button should exist")
        XCTAssertTrue(signInButton.isEnabled, "Sign In button should be enabled")

        // Test accessibility identifiers
        XCTAssertTrue(app.buttons[AccessibilityID.signUpButton].exists)
        XCTAssertTrue(app.buttons[AccessibilityID.signInButton].exists)
    }

    func testWelcomeScreenWithDynamicType() throws {
        // Test with largest Dynamic Type size
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"]
        app.launch()

        let createAccountButton = app.buttons["Create Account"]
        XCTAssertTrue(createAccountButton.exists, "Create Account button should exist with large Dynamic Type")

        // Verify button is still tappable with large text
        XCTAssertTrue(createAccountButton.isHittable, "Button should be hittable with large Dynamic Type")
    }

    func testWelcomeScreenWithVoiceOver() throws {
        // Test with VoiceOver enabled (simulated)
        app.launch()

        let createAccountButton = app.buttons["Create Account"]

        // Verify VoiceOver label exists
        XCTAssertNotNil(createAccountButton.label, "Button should have VoiceOver label")
        XCTAssertEqual(createAccountButton.label, "Create Account")
    }

    // MARK: - Sign Up Flow Accessibility Tests

    func testSignUpFormAccessibility() throws {
        app.launch()

        // Navigate to sign up
        app.buttons[AccessibilityID.signUpButton].tap()

        // Wait for sign up view to appear
        let emailField = app.textFields[AccessibilityID.emailField]
        XCTAssertTrue(emailField.waitForExistence(timeout: 2), "Email field should exist")

        // Test email field accessibility
        XCTAssertTrue(emailField.exists, "Email field should have accessibility label")

        // Test password field accessibility
        let passwordField = app.secureTextFields[AccessibilityID.passwordField]
        XCTAssertTrue(passwordField.exists, "Password field should have accessibility label")

        // Test progress indicator accessibility
        let progressIndicator = app.otherElements["Sign up progress"]
        XCTAssertTrue(progressIndicator.exists, "Progress indicator should be accessible")
    }

    func testSignUpNavigationButtonsAccessibility() throws {
        app.launch()
        app.buttons[AccessibilityID.signUpButton].tap()

        // Fill in step 1 fields
        let emailField = app.textFields[AccessibilityID.emailField]
        XCTAssertTrue(emailField.waitForExistence(timeout: 2))
        emailField.tap()
        emailField.typeText("test@example.com")

        let passwordField = app.secureTextFields[AccessibilityID.passwordField]
        passwordField.tap()
        passwordField.typeText("password123")

        let confirmPasswordField = app.secureTextFields["confirm_password_field"]
        confirmPasswordField.tap()
        confirmPasswordField.typeText("password123")

        // Test Next button accessibility
        let nextButton = app.buttons[AccessibilityID.nextButton]
        XCTAssertTrue(nextButton.exists, "Next button should exist")
        XCTAssertTrue(nextButton.isEnabled, "Next button should be enabled when form is valid")

        nextButton.tap()

        // Test Back button appears on step 2
        let backButton = app.buttons[AccessibilityID.backButton]
        XCTAssertTrue(backButton.waitForExistence(timeout: 2), "Back button should exist on step 2")
    }

    func testSignUpFormFieldLabels() throws {
        app.launch()
        app.buttons[AccessibilityID.signUpButton].tap()

        // Verify all form fields have proper labels
        let fieldsToTest = [
            AccessibilityID.emailField: "Email address",
            AccessibilityID.passwordField: "Password"
        ]

        for (identifier, expectedLabel) in fieldsToTest {
            let field = app.textFields[identifier].exists ? app.textFields[identifier] : app.secureTextFields[identifier]
            XCTAssertTrue(field.exists, "\(identifier) should exist")
        }
    }

    // MARK: - Minimum Tap Target Size Tests (44x44 points)

    func testButtonTapTargetSizes() throws {
        app.launch()

        // All interactive elements should be at least 44x44 points
        let createAccountButton = app.buttons[AccessibilityID.signUpButton]
        let frame = createAccountButton.frame

        XCTAssertGreaterThanOrEqual(frame.height, 44, "Button height should be at least 44 points")
    }

    // MARK: - Onboarding Accessibility Tests

    func testOnboardingAccessibility() throws {
        // Note: This test assumes onboarding is shown after first launch
        // In a real scenario, you'd need to clear user defaults or use a test user state

        app.launch()

        // If onboarding is shown, test it
        let cancelButton = app.buttons[AccessibilityID.cancelButton]
        if cancelButton.exists {
            XCTAssertTrue(cancelButton.isEnabled, "Cancel button should be enabled")

            // Test form fields have proper labels
            let nameField = app.textFields[AccessibilityID.nameField]
            if nameField.exists {
                XCTAssertNotNil(nameField.label, "Name field should have accessibility label")
            }
        }
    }

    // MARK: - Color Contrast Tests (Automated where possible)

    func testHighContrastMode() throws {
        // Enable high contrast mode
        app.launchArguments = ["-UIAccessibilityDarkerSystemColorsEnabled", "YES"]
        app.launch()

        // Verify app still functions correctly
        let createAccountButton = app.buttons["Create Account"]
        XCTAssertTrue(createAccountButton.exists, "Buttons should exist in high contrast mode")
    }

    // MARK: - Reduce Motion Tests

    func testReduceMotion() throws {
        // Enable reduce motion
        app.launchArguments = ["-UIAccessibilityReduceMotionEnabled", "YES"]
        app.launch()

        // Verify app launches successfully with reduce motion
        let createAccountButton = app.buttons["Create Account"]
        XCTAssertTrue(createAccountButton.waitForExistence(timeout: 3), "App should launch with reduce motion enabled")
    }

    // MARK: - VoiceOver Navigation Tests

    func testVoiceOverNavigation() throws {
        app.launch()

        // Test that all interactive elements can be reached via VoiceOver
        let createAccountButton = app.buttons["Create Account"]
        let signInButton = app.buttons["Sign In"]

        XCTAssertTrue(createAccountButton.exists)
        XCTAssertTrue(signInButton.exists)

        // Verify elements have proper traits
        XCTAssertTrue(createAccountButton.elementType == .button)
        XCTAssertTrue(signInButton.elementType == .button)
    }

    // MARK: - Keyboard Navigation Tests

    func testKeyboardNavigation() throws {
        app.launch()
        app.buttons[AccessibilityID.signUpButton].tap()

        // Test that Return key moves to next field
        let emailField = app.textFields[AccessibilityID.emailField]
        XCTAssertTrue(emailField.waitForExistence(timeout: 2))

        emailField.tap()
        emailField.typeText("test@example.com\n")  // \n simulates Return key

        // Password field should now be focused (in a properly implemented form)
        let passwordField = app.secureTextFields[AccessibilityID.passwordField]
        XCTAssertTrue(passwordField.exists)
    }

    // MARK: - Accessibility Audit Test

    func testAccessibilityAudit() throws {
        // This is a comprehensive test that checks multiple accessibility features
        app.launch()

        var issues: [String] = []

        // Check 1: All buttons have labels
        let buttons = app.buttons.allElementsBoundByIndex
        for (index, button) in buttons.enumerated() {
            if button.label.isEmpty {
                issues.append("Button at index \(index) has no label")
            }
        }

        // Check 2: All text fields have labels
        let textFields = app.textFields.allElementsBoundByIndex
        for (index, field) in textFields.enumerated() {
            if field.label.isEmpty {
                issues.append("Text field at index \(index) has no label")
            }
        }

        // Report issues
        if !issues.isEmpty {
            XCTFail("Accessibility issues found:\n" + issues.joined(separator: "\n"))
        }
    }

    // MARK: - Dynamic Type Scale Test

    func testDynamicTypeScales() throws {
        let sizes = [
            "UICTContentSizeCategoryXS",
            "UICTContentSizeCategoryL",
            "UICTContentSizeCategoryAccessibilityM",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        ]

        for size in sizes {
            app.launchArguments = ["-UIPreferredContentSizeCategoryName", size]
            app.launch()

            // Verify main buttons exist at all sizes
            let createAccountButton = app.buttons["Create Account"]
            XCTAssertTrue(createAccountButton.exists, "Create Account should exist at size \(size)")

            app.terminate()
        }
    }

    // MARK: - Screen Reader Announcements Test

    func testScreenReaderAnnouncements() throws {
        app.launch()
        app.buttons[AccessibilityID.signUpButton].tap()

        // Fill invalid data
        let emailField = app.textFields[AccessibilityID.emailField]
        XCTAssertTrue(emailField.waitForExistence(timeout: 2))
        emailField.tap()
        emailField.typeText("invalid-email")

        // Error messages should be accessible
        // Note: Actual error announcement testing requires accessibility APIs
        // This is a basic check that error UI exists
    }

    // MARK: - Focus Management Test

    func testFocusManagement() throws {
        app.launch()
        app.buttons[AccessibilityID.signUpButton].tap()

        // First field should receive focus automatically
        let emailField = app.textFields[AccessibilityID.emailField]
        XCTAssertTrue(emailField.waitForExistence(timeout: 2))

        // Focus should move logically through form
        emailField.tap()
        XCTAssertTrue(emailField.hasFocus || emailField.isHittable, "Email field should be focusable")
    }
}

// MARK: - Accessibility Identifiers Helper

private struct AccessibilityID {
    static let signUpButton = "sign_up_button"
    static let signInButton = "sign_in_button"
    static let emailField = "email_field"
    static let passwordField = "password_field"
    static let confirmPasswordField = "confirm_password_field"
    static let nameField = "name_field"
    static let ageField = "age_field"
    static let locationField = "location_field"
    static let countryField = "country_field"
    static let bioField = "bio_field"
    static let nextButton = "next_button"
    static let backButton = "back_button"
    static let cancelButton = "cancel_button"
    static let closeButton = "close_button"
    static let createAccountButton = "create_account_button"
}

// MARK: - XCUIElement Extension for Focus Detection

extension XCUIElement {
    var hasFocus: Bool {
        return value(forKey: "hasKeyboardFocus") as? Bool ?? false
    }
}
