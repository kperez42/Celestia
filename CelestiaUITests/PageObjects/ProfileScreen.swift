//
//  ProfileScreen.swift
//  CelestiaUITests
//
//  Page Object for Profile/Settings Screen
//

import XCTest

class ProfileScreen: BaseScreen {

    // MARK: - Elements

    private var profileImage: XCUIElement {
        app.images["ProfileImage"]
    }

    private var nameLabel: XCUIElement {
        app.staticTexts["ProfileName"]
    }

    private var editProfileButton: XCUIElement {
        app.buttons["Edit Profile"]
    }

    private var settingsButton: XCUIElement {
        app.buttons["Settings"]
    }

    private var upgradeButton: XCUIElement {
        app.buttons["Upgrade to Premium"]
    }

    private var signOutButton: XCUIElement {
        app.buttons["Sign Out"]
    }

    private var addPhotoButton: XCUIElement {
        app.buttons["Add Photo"]
    }

    private var bioTextField: XCUIElement {
        app.textViews["Bio"]
    }

    private var saveButton: XCUIElement {
        app.buttons["Save"]
    }

    private var backButton: XCUIElement {
        app.navigationBars.buttons.element(boundBy: 0)
    }

    // MARK: - Actions

    @discardableResult
    func tapEditProfile() -> Self {
        tap(editProfileButton)
        return self
    }

    @discardableResult
    func tapUpgrade() -> PremiumScreen {
        scrollTo(upgradeButton)
        tap(upgradeButton)
        return PremiumScreen(app: app)
    }

    @discardableResult
    func tapSignOut() -> LoginScreen {
        scrollTo(signOutButton)
        tap(signOutButton)
        // Confirm sign out if alert appears
        if app.alerts.buttons["Sign Out"].exists {
            app.alerts.buttons["Sign Out"].tap()
        }
        return LoginScreen(app: app)
    }

    @discardableResult
    func tapAddPhoto() -> Self {
        tap(addPhotoButton)
        return self
    }

    @discardableResult
    func selectPhotoFromLibrary() -> Self {
        // Select photo picker option
        if app.sheets.buttons["Choose Photo"].exists {
            app.sheets.buttons["Choose Photo"].tap()
        }

        // Wait for photo library
        let photosApp = XCUIApplication(bundleIdentifier: "com.apple.mobileslideshow")
        if photosApp.wait(for: .runningForeground, timeout: 5) {
            // Select first photo
            photosApp.cells.element(boundBy: 0).tap()
        }

        return self
    }

    @discardableResult
    func updateBio(_ bio: String) -> Self {
        scrollTo(bioTextField)
        type(text: bio, into: bioTextField)
        return self
    }

    @discardableResult
    func tapSave() -> Self {
        scrollTo(saveButton)
        tap(saveButton)
        return self
    }

    @discardableResult
    func tapBack() -> SwipeScreen {
        tap(backButton)
        return SwipeScreen(app: app)
    }

    // MARK: - Verifications

    func verifyProfileScreen() {
        verify(exists: profileImage)
        verify(exists: editProfileButton)
    }

    func verifyProfileName(_ name: String) {
        verify(exists: nameLabel)
        verify(element: nameLabel, hasText: name)
    }

    func verifyBio(_ bio: String) {
        verify(exists: bioTextField)
        XCTAssertEqual(bioTextField.value as? String, bio)
    }
}

// MARK: - Premium Screen

class PremiumScreen: BaseScreen {

    // MARK: - Elements

    private var monthlyPlanButton: XCUIElement {
        app.buttons["Monthly Plan"]
    }

    private var yearlyPlanButton: XCUIElement {
        app.buttons["Yearly Plan"]
    }

    private var subscribeButton: XCUIElement {
        app.buttons["Subscribe"]
    }

    private var restorePurchasesButton: XCUIElement {
        app.buttons["Restore Purchases"]
    }

    private var closeButton: XCUIElement {
        app.buttons["Close"]
    }

    // MARK: - Actions

    @discardableResult
    func selectMonthlyPlan() -> Self {
        tap(monthlyPlanButton)
        return self
    }

    @discardableResult
    func selectYearlyPlan() -> Self {
        tap(yearlyPlanButton)
        return self
    }

    @discardableResult
    func tapSubscribe() -> Self {
        tap(subscribeButton)
        return self
    }

    @discardableResult
    func tapRestorePurchases() -> Self {
        tap(restorePurchasesButton)
        return self
    }

    @discardableResult
    func tapClose() -> ProfileScreen {
        tap(closeButton)
        return ProfileScreen(app: app)
    }

    // MARK: - Verifications

    func verifyPremiumScreen() {
        verify(exists: monthlyPlanButton)
        verify(exists: yearlyPlanButton)
        verify(exists: subscribeButton)
    }
}
