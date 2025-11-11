//
//  LoginScreen.swift
//  CelestiaUITests
//
//  Page Object for Login Screen
//

import XCTest

class LoginScreen: BaseScreen {

    // MARK: - Elements

    private var emailTextField: XCUIElement {
        app.textFields["Email"]
    }

    private var passwordTextField: XCUIElement {
        app.secureTextFields["Password"]
    }

    private var signInButton: XCUIElement {
        app.buttons["Sign In"]
    }

    private var signUpButton: XCUIElement {
        app.buttons["Don't have an account? Sign Up"]
    }

    private var forgotPasswordButton: XCUIElement {
        app.buttons["Forgot Password?"]
    }

    private var errorAlert: XCUIElement {
        app.alerts.firstMatch
    }

    // MARK: - Actions

    @discardableResult
    func enterEmail(_ email: String) -> Self {
        type(text: email, into: emailTextField)
        return self
    }

    @discardableResult
    func enterPassword(_ password: String) -> Self {
        type(text: password, into: passwordTextField)
        return self
    }

    @discardableResult
    func tapSignIn() -> Self {
        tap(signInButton)
        return self
    }

    @discardableResult
    func tapSignUp() -> SignupScreen {
        tap(signUpButton)
        return SignupScreen(app: app)
    }

    @discardableResult
    func tapForgotPassword() -> Self {
        tap(forgotPasswordButton)
        return self
    }

    func signIn(email: String, password: String) {
        enterEmail(email)
        enterPassword(password)
        dismissKeyboard()
        tapSignIn()
    }

    // MARK: - Verifications

    func verifyLoginScreen() {
        verify(exists: emailTextField)
        verify(exists: passwordTextField)
        verify(exists: signInButton)
        verify(exists: signUpButton)
    }

    func verifyErrorDisplayed(containing text: String) {
        verify(exists: errorAlert)
        XCTAssertTrue(errorAlert.label.contains(text))
    }
}
