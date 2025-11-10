//
//  AuthenticationFlowTests.swift
//  CelestiaUITests
//
//  Tests for complete authentication flows
//

import XCTest

final class AuthenticationFlowTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment = [
            "UITEST_DISABLE_ANIMATIONS": "1",
            "UITEST_RESET_STATE": "1"
        ]
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - Signup Flow Tests

    func testCompleteSignupFlow() throws {
        app.launch()

        // Given: User is on login screen
        let loginScreen = LoginScreen(app: app)
        loginScreen.verifyLoginScreen()
        loginScreen.takeScreenshot(named: "01_Login_Screen")

        // When: User taps Sign Up
        let signupScreen = loginScreen.tapSignUp()
        signupScreen.verifySignupScreen()
        signupScreen.takeScreenshot(named: "02_Signup_Screen")

        // And: User fills in signup form
        let timestamp = Int(Date().timeIntervalSince1970)
        let email = "test\(timestamp)@celestia.app"

        signupScreen.completeSignup(
            name: "Test User",
            email: email,
            password: "Test1234!",
            age: "25",
            gender: "Male",
            lookingFor: "Female"
        )
        signupScreen.takeScreenshot(named: "03_Signup_Completed")

        // Then: User should be navigated to email verification screen
        let verificationScreen = EmailVerificationScreen(app: app)
        verificationScreen.verifyEmailVerificationScreen()
        verificationScreen.takeScreenshot(named: "04_Email_Verification")
    }

    func testSignupWithReferralCode() throws {
        app.launch()

        // Given: User opens app with referral link
        // Simulate deep link by setting launch environment
        app.launchEnvironment["UITEST_REFERRAL_CODE"] = "TEST123"
        app.launch()

        let loginScreen = LoginScreen(app: app)
        let signupScreen = loginScreen.tapSignUp()

        // Then: Referral code should be pre-filled
        signupScreen.verifyReferralCodePrefilled("TEST123")
        signupScreen.takeScreenshot(named: "Signup_With_Referral")
    }

    func testSignupValidation() throws {
        app.launch()

        let loginScreen = LoginScreen(app: app)
        let signupScreen = loginScreen.tapSignUp()

        // When: User submits form with invalid email
        signupScreen
            .enterFullName("Test User")
            .enterEmail("invalid-email")
            .enterPassword("Test1234!")
            .tapSignUp()

        // Then: Error should be displayed
        signupScreen.takeScreenshot(named: "Invalid_Email_Error")
        // Add verification for error message
    }

    // MARK: - Login Flow Tests

    func testSuccessfulLogin() throws {
        app.launch()

        // Given: User has a valid account (assumes test account exists)
        let loginScreen = LoginScreen(app: app)
        loginScreen.verifyLoginScreen()
        loginScreen.takeScreenshot(named: "01_Login_Screen")

        // When: User signs in with valid credentials
        loginScreen.signIn(
            email: "test@celestia.app",
            password: "Test1234!"
        )

        // Then: User should be navigated to swipe screen
        let swipeScreen = SwipeScreen(app: app)
        swipeScreen.verifySwipeScreen()
        swipeScreen.takeScreenshot(named: "02_Swipe_Screen_After_Login")
    }

    func testLoginWithInvalidCredentials() throws {
        app.launch()

        let loginScreen = LoginScreen(app: app)

        // When: User attempts login with invalid credentials
        loginScreen.signIn(
            email: "invalid@celestia.app",
            password: "WrongPassword"
        )

        // Then: Error should be displayed
        loginScreen.verifyErrorDisplayed(containing: "Invalid")
        loginScreen.takeScreenshot(named: "Invalid_Credentials_Error")
    }

    func testForgotPasswordFlow() throws {
        app.launch()

        let loginScreen = LoginScreen(app: app)

        // When: User taps Forgot Password
        loginScreen.tapForgotPassword()

        // Then: Password reset screen should appear
        let resetScreen = ForgotPasswordScreen(app: app)
        resetScreen.verifyForgotPasswordScreen()
        resetScreen.takeScreenshot(named: "Forgot_Password_Screen")

        // When: User enters email and requests reset
        resetScreen.enterEmail("test@celestia.app")
        resetScreen.tapSendResetLink()

        // Then: Confirmation should be shown
        resetScreen.verifyResetLinkSent()
        resetScreen.takeScreenshot(named: "Reset_Link_Sent")
    }

    // MARK: - Email Verification Tests

    func testEmailVerificationFlow() throws {
        app.launch()

        // Given: User has signed up but not verified email
        // (This assumes test user exists in unverified state)
        let loginScreen = LoginScreen(app: app)
        loginScreen.signIn(email: "unverified@celestia.app", password: "Test1234!")

        let verificationScreen = EmailVerificationScreen(app: app)
        verificationScreen.verifyEmailVerificationScreen()
        verificationScreen.takeScreenshot(named: "01_Verification_Required")

        // When: User taps resend verification email
        verificationScreen.tapResendEmail()

        // Then: Confirmation should be shown
        verificationScreen.verifyEmailSent()
        verificationScreen.takeScreenshot(named: "02_Verification_Email_Sent")
    }

    func testEmailVerificationViaDeepLink() throws {
        app.launch()

        // Given: User receives verification email with deep link
        let verificationToken = "test_verification_token_123"
        let url = URL(string: "https://celestia.app/verify-email?token=\(verificationToken)")!

        // When: User opens verification link
        XCUIDevice.shared.system.open(url)

        // Then: Email should be verified and user navigated to onboarding
        let onboardingScreen = OnboardingScreen(app: app)
        onboardingScreen.verifyOnboardingScreen()
        onboardingScreen.takeScreenshot(named: "Email_Verified_Onboarding")
    }

    // MARK: - Sign Out Tests

    func testSignOut() throws {
        app.launch()

        // Given: User is signed in
        let loginScreen = LoginScreen(app: app)
        loginScreen.signIn(email: "test@celestia.app", password: "Test1234!")

        let swipeScreen = SwipeScreen(app: app)
        swipeScreen.verifySwipeScreen()

        // When: User navigates to profile and signs out
        let profileScreen = swipeScreen.tapSettings()
        profileScreen.verifyProfileScreen()
        profileScreen.takeScreenshot(named: "01_Profile_Before_Signout")

        let returnedLoginScreen = profileScreen.tapSignOut()

        // Then: User should be returned to login screen
        returnedLoginScreen.verifyLoginScreen()
        returnedLoginScreen.takeScreenshot(named: "02_Login_After_Signout")
    }
}

// MARK: - Helper Screen Objects

class EmailVerificationScreen: BaseScreen {
    private var verificationMessage: XCUIElement {
        app.staticTexts["Please verify your email"]
    }

    private var resendButton: XCUIElement {
        app.buttons["Resend Email"]
    }

    private var emailSentMessage: XCUIElement {
        app.staticTexts["Verification email sent"]
    }

    func verifyEmailVerificationScreen() {
        verify(exists: verificationMessage)
        verify(exists: resendButton)
    }

    func tapResendEmail() {
        tap(resendButton)
    }

    func verifyEmailSent() {
        verify(exists: emailSentMessage, timeout: 5)
    }
}

class ForgotPasswordScreen: BaseScreen {
    private var emailTextField: XCUIElement {
        app.textFields["Email"]
    }

    private var sendButton: XCUIElement {
        app.buttons["Send Reset Link"]
    }

    private var confirmationMessage: XCUIElement {
        app.staticTexts["Reset link sent"]
    }

    func verifyForgotPasswordScreen() {
        verify(exists: emailTextField)
        verify(exists: sendButton)
    }

    func enterEmail(_ email: String) {
        type(text: email, into: emailTextField)
    }

    func tapSendResetLink() {
        tap(sendButton)
    }

    func verifyResetLinkSent() {
        verify(exists: confirmationMessage, timeout: 5)
    }
}

class OnboardingScreen: BaseScreen {
    private var welcomeMessage: XCUIElement {
        app.staticTexts["Welcome to Celestia"]
    }

    private var continueButton: XCUIElement {
        app.buttons["Continue"]
    }

    func verifyOnboardingScreen() {
        verify(exists: welcomeMessage)
        verify(exists: continueButton)
    }
}
