//
//  SignupScreen.swift
//  CelestiaUITests
//
//  Page Object for Signup Screen
//

import XCTest

class SignupScreen: BaseScreen {

    // MARK: - Elements

    private var fullNameTextField: XCUIElement {
        app.textFields["Full Name"]
    }

    private var emailTextField: XCUIElement {
        app.textFields["Email"]
    }

    private var passwordTextField: XCUIElement {
        app.secureTextFields["Password"]
    }

    private var ageTextField: XCUIElement {
        app.textFields["Age"]
    }

    private var genderPicker: XCUIElement {
        app.pickers["Gender"]
    }

    private var lookingForPicker: XCUIElement {
        app.pickers["Looking For"]
    }

    private var referralCodeTextField: XCUIElement {
        app.textFields["Referral Code (Optional)"]
    }

    private var signUpButton: XCUIElement {
        app.buttons["Create Account"]
    }

    private var alreadyHaveAccountButton: XCUIElement {
        app.buttons["Already have an account? Sign In"]
    }

    // MARK: - Actions

    @discardableResult
    func enterFullName(_ name: String) -> Self {
        type(text: name, into: fullNameTextField)
        return self
    }

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
    func enterAge(_ age: String) -> Self {
        type(text: age, into: ageTextField)
        return self
    }

    @discardableResult
    func selectGender(_ gender: String) -> Self {
        tap(genderPicker)
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: gender)
        return self
    }

    @discardableResult
    func selectLookingFor(_ lookingFor: String) -> Self {
        tap(lookingForPicker)
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: lookingFor)
        return self
    }

    @discardableResult
    func enterReferralCode(_ code: String) -> Self {
        scrollTo(referralCodeTextField)
        type(text: code, into: referralCodeTextField)
        return self
    }

    @discardableResult
    func tapSignUp() -> Self {
        scrollTo(signUpButton)
        tap(signUpButton)
        return self
    }

    @discardableResult
    func tapSignIn() -> LoginScreen {
        tap(alreadyHaveAccountButton)
        return LoginScreen(app: app)
    }

    func completeSignup(
        name: String,
        email: String,
        password: String,
        age: String,
        gender: String,
        lookingFor: String,
        referralCode: String? = nil
    ) {
        enterFullName(name)
        enterEmail(email)
        enterPassword(password)
        enterAge(age)
        selectGender(gender)
        selectLookingFor(lookingFor)

        if let code = referralCode {
            enterReferralCode(code)
        }

        dismissKeyboard()
        tapSignUp()
    }

    // MARK: - Verifications

    func verifySignupScreen() {
        verify(exists: fullNameTextField)
        verify(exists: emailTextField)
        verify(exists: passwordTextField)
        verify(exists: signUpButton)
    }

    func verifyReferralCodePrefilled(_ code: String) {
        verify(exists: referralCodeTextField)
        XCTAssertEqual(referralCodeTextField.value as? String, code)
    }
}
