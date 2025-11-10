//
//  BaseScreen.swift
//  CelestiaUITests
//
//  Base class for Page Object Model pattern
//  Provides common functionality for all screen objects
//

import XCTest

class BaseScreen {

    // MARK: - Properties

    let app: XCUIApplication

    // MARK: - Initialization

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - Common Actions

    /// Wait for element to exist
    @discardableResult
    func waitForElement(
        _ element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Bool {
        let exists = element.waitForExistence(timeout: timeout)
        XCTAssertTrue(
            exists,
            "Element '\(element.debugDescription)' does not exist after \(timeout) seconds",
            file: file,
            line: line
        )
        return exists
    }

    /// Wait for element to disappear
    @discardableResult
    func waitForElementToDisappear(
        _ element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(
            result,
            .completed,
            "Element '\(element.debugDescription)' still exists after \(timeout) seconds",
            file: file,
            line: line
        )
        return result == .completed
    }

    /// Tap element with wait
    func tap(
        _ element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        waitForElement(element, timeout: timeout, file: file, line: line)
        element.tap()
    }

    /// Type text into element
    func type(
        text: String,
        into element: XCUIElement,
        clearFirst: Bool = true,
        timeout: TimeInterval = 10,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        waitForElement(element, timeout: timeout, file: file, line: line)
        element.tap()

        if clearFirst, let currentValue = element.value as? String, !currentValue.isEmpty {
            // Delete existing text
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            element.typeText(deleteString)
        }

        element.typeText(text)
    }

    /// Scroll to element
    func scrollTo(
        _ element: XCUIElement,
        in scrollView: XCUIElement? = nil,
        maxSwipes: Int = 10,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let scrollContainer = scrollView ?? app.scrollViews.firstMatch

        var swipeCount = 0
        while !element.isHittable && swipeCount < maxSwipes {
            scrollContainer.swipeUp()
            swipeCount += 1
        }

        XCTAssertTrue(
            element.isHittable,
            "Element '\(element.debugDescription)' not found after \(swipeCount) swipes",
            file: file,
            line: line
        )
    }

    /// Verify element exists
    func verify(
        exists element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        waitForElement(element, timeout: timeout, file: file, line: line)
    }

    /// Verify element does not exist
    func verify(
        notExists element: XCUIElement,
        timeout: TimeInterval = 2,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let exists = element.waitForExistence(timeout: timeout)
        XCTAssertFalse(
            exists,
            "Element '\(element.debugDescription)' exists but should not",
            file: file,
            line: line
        )
    }

    /// Verify text in element
    func verify(
        element: XCUIElement,
        hasText expectedText: String,
        timeout: TimeInterval = 10,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        waitForElement(element, timeout: timeout, file: file, line: line)

        let actualText = element.label.isEmpty ? (element.value as? String ?? "") : element.label
        XCTAssertEqual(
            actualText,
            expectedText,
            "Element text '\(actualText)' does not match expected '\(expectedText)'",
            file: file,
            line: line
        )
    }

    /// Take screenshot
    func takeScreenshot(named name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        XCTContext.runActivity(named: "Screenshot: \(name)") { activity in
            activity.add(attachment)
        }
    }

    /// Dismiss keyboard
    func dismissKeyboard() {
        if app.keyboards.firstMatch.exists {
            if UIDevice.current.userInterfaceIdiom == .phone {
                app.toolbars.buttons["Done"].tap()
            } else {
                app.keyboards.buttons["Hide keyboard"].tap()
            }
        }
    }

    /// Pull to refresh
    func pullToRefresh(in scrollView: XCUIElement? = nil) {
        let scrollContainer = scrollView ?? app.scrollViews.firstMatch
        let start = scrollContainer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        let end = scrollContainer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        start.press(forDuration: 0.1, thenDragTo: end)
    }

    /// Swipe element
    func swipe(
        _ element: XCUIElement,
        direction: SwipeDirection,
        velocity: XCUIGestureVelocity = .default
    ) {
        switch direction {
        case .up:
            element.swipeUp(velocity: velocity)
        case .down:
            element.swipeDown(velocity: velocity)
        case .left:
            element.swipeLeft(velocity: velocity)
        case .right:
            element.swipeRight(velocity: velocity)
        }
    }

    enum SwipeDirection {
        case up, down, left, right
    }
}
