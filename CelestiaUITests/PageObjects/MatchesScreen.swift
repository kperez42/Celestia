//
//  MatchesScreen.swift
//  CelestiaUITests
//
//  Page Object for Matches Screen
//

import XCTest

class MatchesScreen: BaseScreen {

    // MARK: - Elements

    private var matchesList: XCUIElement {
        app.collectionViews["MatchesList"]
    }

    private var backButton: XCUIElement {
        app.navigationBars.buttons.element(boundBy: 0)
    }

    private var emptyStateMessage: XCUIElement {
        app.staticTexts["No matches yet"]
    }

    // MARK: - Actions

    func tapMatch(at index: Int) -> MessagesScreen {
        let match = matchesList.cells.element(boundBy: index)
        tap(match)
        return MessagesScreen(app: app)
    }

    func tapMatchWithName(_ name: String) -> MessagesScreen {
        let match = matchesList.cells.staticTexts[name]
        tap(match)
        return MessagesScreen(app: app)
    }

    @discardableResult
    func tapBack() -> SwipeScreen {
        tap(backButton)
        return SwipeScreen(app: app)
    }

    // MARK: - Verifications

    func verifyMatchesScreen() {
        verify(exists: matchesList)
    }

    func verifyMatchExists(name: String) {
        let match = matchesList.cells.staticTexts[name]
        verify(exists: match)
    }

    func verifyEmptyState() {
        verify(exists: emptyStateMessage)
    }

    func verifyMatchCount(_ expectedCount: Int) {
        let actualCount = matchesList.cells.count
        XCTAssertEqual(
            actualCount,
            expectedCount,
            "Expected \(expectedCount) matches but found \(actualCount)"
        )
    }
}
