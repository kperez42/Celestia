//
//  MessagesScreen.swift
//  CelestiaUITests
//
//  Page Object for Messages/Chat Screen
//

import XCTest

class MessagesScreen: BaseScreen {

    // MARK: - Elements

    private var messagesList: XCUIElement {
        app.tables["MessagesList"]
    }

    private var messageTextField: XCUIElement {
        app.textFields["MessageInput"]
    }

    private var sendButton: XCUIElement {
        app.buttons["SendButton"]
    }

    private var backButton: XCUIElement {
        app.navigationBars.buttons.element(boundBy: 0)
    }

    private var unmatchButton: XCUIElement {
        app.buttons["UnmatchButton"]
    }

    private var reportButton: XCUIElement {
        app.buttons["ReportButton"]
    }

    // MARK: - Actions

    @discardableResult
    func typeMessage(_ message: String) -> Self {
        type(text: message, into: messageTextField)
        return self
    }

    @discardableResult
    func tapSend() -> Self {
        tap(sendButton)
        return self
    }

    func sendMessage(_ message: String) {
        typeMessage(message)
        tapSend()
    }

    @discardableResult
    func tapBack() -> Self {
        tap(backButton)
        return self
    }

    @discardableResult
    func tapUnmatch() -> Self {
        tap(unmatchButton)
        return self
    }

    @discardableResult
    func confirmUnmatch() -> Self {
        app.alerts.buttons["Unmatch"].tap()
        return self
    }

    // MARK: - Verifications

    func verifyMessagesScreen() {
        verify(exists: messageTextField)
        verify(exists: sendButton)
    }

    func verifyMessageSent(_ message: String) {
        let messageCell = messagesList.cells.staticTexts[message]
        verify(exists: messageCell, timeout: 5)
    }

    func verifyMessageReceived(_ message: String) {
        let messageCell = messagesList.cells.staticTexts[message]
        verify(exists: messageCell, timeout: 10)
    }

    func verifyConversationWith(name: String) {
        let navigationTitle = app.navigationBars.staticTexts[name]
        verify(exists: navigationTitle)
    }
}
