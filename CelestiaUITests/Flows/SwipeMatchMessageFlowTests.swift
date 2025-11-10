//
//  SwipeMatchMessageFlowTests.swift
//  CelestiaUITests
//
//  Tests for Swipe → Match → Message flow
//

import XCTest

final class SwipeMatchMessageFlowTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--authenticated"]
        app.launchEnvironment = [
            "UITEST_DISABLE_ANIMATIONS": "1",
            "UITEST_USER_EMAIL": "test@celestia.app"
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - Swipe Tests

    func testSwipeRightOnProfile() throws {
        // Given: User is on swipe screen
        let swipeScreen = SwipeScreen(app: app)
        swipeScreen.verifySwipeScreen()
        swipeScreen.takeScreenshot(named: "01_Swipe_Screen")

        // When: User swipes right (like)
        swipeScreen.swipeRight()

        // Then: Next profile should be shown
        swipeScreen.verifySwipeScreen()
        swipeScreen.takeScreenshot(named: "02_After_Swipe_Right")
    }

    func testSwipeLeftOnProfile() throws {
        // Given: User is on swipe screen
        let swipeScreen = SwipeScreen(app: app)
        swipeScreen.verifySwipeScreen()

        // When: User swipes left (dislike)
        swipeScreen.swipeLeft()

        // Then: Next profile should be shown
        swipeScreen.verifySwipeScreen()
        swipeScreen.takeScreenshot(named: "After_Swipe_Left")
    }

    func testLikeButtonTap() throws {
        // Given: User is on swipe screen
        let swipeScreen = SwipeScreen(app: app)
        swipeScreen.verifySwipeScreen()

        // When: User taps like button
        swipeScreen.tapLike()

        // Then: Next profile should be shown
        swipeScreen.verifySwipeScreen()
        swipeScreen.takeScreenshot(named: "After_Like_Button")
    }

    func testDislikeButtonTap() throws {
        // Given: User is on swipe screen
        let swipeScreen = SwipeScreen(app: app)
        swipeScreen.verifySwipeScreen()

        // When: User taps dislike button
        swipeScreen.tapDislike()

        // Then: Next profile should be shown
        swipeScreen.verifySwipeScreen()
        swipeScreen.takeScreenshot(named: "After_Dislike_Button")
    }

    func testSuperLike() throws {
        // Given: User is on swipe screen
        let swipeScreen = SwipeScreen(app: app)
        swipeScreen.verifySwipeScreen()

        // When: User taps super like button
        swipeScreen.tapSuperLike()

        // Then: Super like should be sent
        swipeScreen.takeScreenshot(named: "After_Super_Like")
    }

    // MARK: - Match Tests

    func testMatchFlow() throws {
        // Given: User is on swipe screen
        let swipeScreen = SwipeScreen(app: app)
        swipeScreen.verifySwipeScreen()
        swipeScreen.takeScreenshot(named: "01_Before_Match")

        // When: User likes a profile that also liked them
        // (This assumes test environment creates a mutual match)
        swipeScreen.tapLike()

        // Then: Match alert should appear
        swipeScreen.verifyMatchAlert()
        swipeScreen.takeScreenshot(named: "02_Match_Alert")

        // When: User taps "Send Message"
        let messagesScreen = swipeScreen.tapSendMessage()

        // Then: Message screen should open
        messagesScreen.verifyMessagesScreen()
        messagesScreen.takeScreenshot(named: "03_Message_Screen_After_Match")
    }

    func testMatchAndKeepSwiping() throws {
        // Given: User gets a match
        let swipeScreen = SwipeScreen(app: app)
        swipeScreen.tapLike() // Create match

        // When: User taps "Keep Swiping"
        swipeScreen.verifyMatchAlert()
        swipeScreen.takeScreenshot(named: "Match_Alert")

        swipeScreen.tapKeepSwiping()

        // Then: User should return to swipe screen
        swipeScreen.verifySwipeScreen()
        swipeScreen.takeScreenshot(named: "Back_To_Swiping")
    }

    // MARK: - Message Tests

    func testSendFirstMessage() throws {
        // Given: User has a match
        let swipeScreen = SwipeScreen(app: app)
        let matchesScreen = swipeScreen.tapMatches()
        matchesScreen.verifyMatchesScreen()
        matchesScreen.takeScreenshot(named: "01_Matches_List")

        // When: User opens conversation
        let messagesScreen = matchesScreen.tapMatch(at: 0)
        messagesScreen.verifyMessagesScreen()
        messagesScreen.takeScreenshot(named: "02_Empty_Conversation")

        // And: User sends a message
        messagesScreen.sendMessage("Hey! How's it going?")

        // Then: Message should appear in conversation
        messagesScreen.verifyMessageSent("Hey! How's it going?")
        messagesScreen.takeScreenshot(named: "03_Message_Sent")
    }

    func testSendMultipleMessages() throws {
        // Given: User is in a conversation
        let swipeScreen = SwipeScreen(app: app)
        let matchesScreen = swipeScreen.tapMatches()
        let messagesScreen = matchesScreen.tapMatch(at: 0)

        // When: User sends multiple messages
        messagesScreen.sendMessage("Hey!")
        messagesScreen.verifyMessageSent("Hey!")

        messagesScreen.sendMessage("How are you?")
        messagesScreen.verifyMessageSent("How are you?")

        messagesScreen.sendMessage("Nice to match with you!")
        messagesScreen.verifyMessageSent("Nice to match with you!")

        messagesScreen.takeScreenshot(named: "Multiple_Messages_Sent")
    }

    func testReceiveMessage() throws {
        // Given: User is in a conversation
        let swipeScreen = SwipeScreen(app: app)
        let matchesScreen = swipeScreen.tapMatches()
        let messagesScreen = matchesScreen.tapMatch(at: 0)

        // When: Other user sends a message
        // (This assumes test environment simulates incoming message)
        messagesScreen.sendMessage("Hello!")

        // Then: Incoming message should appear
        // In real scenario, this would be triggered by backend
        messagesScreen.verifyMessageReceived("Hi back!")
        messagesScreen.takeScreenshot(named: "Message_Received")
    }

    // MARK: - Complete Flow Test

    func testCompleteSwipeToMessageFlow() throws {
        // Given: User is signed in and on swipe screen
        let swipeScreen = SwipeScreen(app: app)
        swipeScreen.verifySwipeScreen()
        swipeScreen.takeScreenshot(named: "01_Swipe_Screen")

        // When: User swipes through profiles
        swipeScreen.swipeLeft()
        swipeScreen.takeScreenshot(named: "02_After_First_Swipe")

        swipeScreen.swipeRight()
        swipeScreen.takeScreenshot(named: "03_After_Like")

        swipeScreen.swipeLeft()
        swipeScreen.takeScreenshot(named: "04_After_Another_Dislike")

        // And: User gets a match
        swipeScreen.tapLike()
        swipeScreen.verifyMatchAlert()
        swipeScreen.takeScreenshot(named: "05_Match_Alert")

        // And: User opens message screen
        let messagesScreen = swipeScreen.tapSendMessage()
        messagesScreen.verifyMessagesScreen()
        messagesScreen.takeScreenshot(named: "06_Message_Screen")

        // And: User sends a message
        messagesScreen.sendMessage("Hey! Nice to match with you!")
        messagesScreen.verifyMessageSent("Hey! Nice to match with you!")
        messagesScreen.takeScreenshot(named: "07_First_Message_Sent")

        // Then: Complete flow should work end-to-end
        // User successfully: swiped → matched → sent message
    }

    // MARK: - Navigation Tests

    func testNavigateToMatches() throws {
        // Given: User is on swipe screen
        let swipeScreen = SwipeScreen(app: app)
        swipeScreen.verifySwipeScreen()

        // When: User taps matches button
        let matchesScreen = swipeScreen.tapMatches()

        // Then: Matches screen should be displayed
        matchesScreen.verifyMatchesScreen()
        matchesScreen.takeScreenshot(named: "Matches_Screen")
    }

    func testNavigateToMessages() throws {
        // Given: User is on swipe screen
        let swipeScreen = SwipeScreen(app: app)
        swipeScreen.verifySwipeScreen()

        // When: User taps messages button
        let messagesScreen = swipeScreen.tapMessages()

        // Then: Messages screen should be displayed
        messagesScreen.verifyMessagesScreen()
        messagesScreen.takeScreenshot(named: "Messages_Screen")
    }

    func testBackNavigation() throws {
        // Given: User navigates to matches
        let swipeScreen = SwipeScreen(app: app)
        let matchesScreen = swipeScreen.tapMatches()
        matchesScreen.verifyMatchesScreen()

        // When: User taps back
        let returnedSwipeScreen = matchesScreen.tapBack()

        // Then: User should return to swipe screen
        returnedSwipeScreen.verifySwipeScreen()
        returnedSwipeScreen.takeScreenshot(named: "Back_To_Swipe")
    }

    // MARK: - Edge Cases

    func testNoMatchesState() throws {
        // Given: User has no matches
        app.launchEnvironment["UITEST_NO_MATCHES"] = "1"
        app.launch()

        let swipeScreen = SwipeScreen(app: app)
        let matchesScreen = swipeScreen.tapMatches()

        // Then: Empty state should be shown
        matchesScreen.verifyEmptyState()
        matchesScreen.takeScreenshot(named: "No_Matches_Empty_State")
    }

    func testUnmatchUser() throws {
        // Given: User is in a conversation
        let swipeScreen = SwipeScreen(app: app)
        let matchesScreen = swipeScreen.tapMatches()
        let messagesScreen = matchesScreen.tapMatch(at: 0)
        messagesScreen.verifyMessagesScreen()

        // When: User unmatch the other user
        messagesScreen.tapUnmatch()
        messagesScreen.confirmUnmatch()

        // Then: User should be returned to matches screen
        let returnedMatchesScreen = MatchesScreen(app: app)
        returnedMatchesScreen.verifyMatchesScreen()
        returnedMatchesScreen.takeScreenshot(named: "After_Unmatch")
    }
}
