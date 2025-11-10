//
//  SwipeScreen.swift
//  CelestiaUITests
//
//  Page Object for Swipe/Discovery Screen
//

import XCTest

class SwipeScreen: BaseScreen {

    // MARK: - Elements

    private var profileCard: XCUIElement {
        app.otherElements["ProfileCard"]
    }

    private var profileImage: XCUIElement {
        app.images["ProfileImage"]
    }

    private var profileName: XCUIElement {
        app.staticTexts["ProfileName"]
    }

    private var profileAge: XCUIElement {
        app.staticTexts["ProfileAge"]
    }

    private var profileBio: XCUIElement {
        app.staticTexts["ProfileBio"]
    }

    private var likeButton: XCUIElement {
        app.buttons["LikeButton"]
    }

    private var dislikeButton: XCUIElement {
        app.buttons["DislikeButton"]
    }

    private var superLikeButton: XCUIElement {
        app.buttons["SuperLikeButton"]
    }

    private var settingsButton: XCUIElement {
        app.buttons["SettingsButton"]
    }

    private var matchesButton: XCUIElement {
        app.buttons["MatchesButton"]
    }

    private var messagesButton: XCUIElement {
        app.buttons["MessagesButton"]
    }

    private var matchAlert: XCUIElement {
        app.alerts["It's a Match!"]
    }

    private var sendMessageButton: XCUIElement {
        app.buttons["Send Message"]
    }

    private var keepSwipingButton: XCUIElement {
        app.buttons["Keep Swiping"]
    }

    // MARK: - Actions

    @discardableResult
    func swipeRight() -> Self {
        let coordinate1 = profileCard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let coordinate2 = profileCard.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        coordinate1.press(forDuration: 0.1, thenDragTo: coordinate2)
        return self
    }

    @discardableResult
    func swipeLeft() -> Self {
        let coordinate1 = profileCard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let coordinate2 = profileCard.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
        coordinate1.press(forDuration: 0.1, thenDragTo: coordinate2)
        return self
    }

    @discardableResult
    func tapLike() -> Self {
        tap(likeButton)
        return self
    }

    @discardableResult
    func tapDislike() -> Self {
        tap(dislikeButton)
        return self
    }

    @discardableResult
    func tapSuperLike() -> Self {
        tap(superLikeButton)
        return self
    }

    @discardableResult
    func tapMatches() -> MatchesScreen {
        tap(matchesButton)
        return MatchesScreen(app: app)
    }

    @discardableResult
    func tapMessages() -> MessagesScreen {
        tap(messagesButton)
        return MessagesScreen(app: app)
    }

    @discardableResult
    func tapSettings() -> ProfileScreen {
        tap(settingsButton)
        return ProfileScreen(app: app)
    }

    @discardableResult
    func tapSendMessage() -> MessagesScreen {
        waitForElement(matchAlert)
        tap(sendMessageButton)
        return MessagesScreen(app: app)
    }

    @discardableResult
    func tapKeepSwiping() -> Self {
        waitForElement(matchAlert)
        tap(keepSwipingButton)
        return self
    }

    // MARK: - Verifications

    func verifySwipeScreen() {
        verify(exists: profileCard)
        verify(exists: likeButton)
        verify(exists: dislikeButton)
    }

    func verifyMatchAlert() {
        verify(exists: matchAlert, timeout: 5)
    }

    func verifyProfileDisplayed(name: String) {
        verify(exists: profileName)
        verify(element: profileName, hasText: name)
    }
}
