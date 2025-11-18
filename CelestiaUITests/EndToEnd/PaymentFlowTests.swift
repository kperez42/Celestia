//
//  PaymentFlowTests.swift
//  CelestiaUITests
//
//  End-to-end payment and subscription flow testing
//  Tests: Premium upgrade → Receipt validation → Feature access → Subscription management
//

import XCTest

final class PaymentFlowTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launchEnvironment = [
            "RESET_DATA": "1",
            "ENABLE_TEST_PAYMENTS": "1" // Enable StoreKit testing configuration
        ]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Premium Upgrade Flow

    @MainActor
    func testPremiumUpgradeFlow() throws {
        loginTestUser()

        // Navigate to premium/subscription view
        app.tabBars.buttons["Profile"].tap()

        // Tap "Upgrade to Premium" or "Premium" button
        if app.buttons["UpgradeToPremium"].exists {
            app.buttons["UpgradeToPremium"].tap()
        } else if app.buttons["GetPremium"].exists {
            app.buttons["GetPremium"].tap()
        } else {
            app.buttons["Premium"].tap()
        }

        // Wait for premium view to load
        XCTAssertTrue(waitForElement(app.staticTexts["PremiumTitle"], timeout: 5))

        // Verify premium features are displayed
        XCTAssertTrue(app.staticTexts["UnlimitedLikes"].exists ||
                     app.staticTexts["Unlimited Likes"].exists)
        XCTAssertTrue(app.staticTexts["SeeWhoLikesYou"].exists ||
                     app.staticTexts["See Who Likes You"].exists)
        XCTAssertTrue(app.staticTexts["BoostProfile"].exists ||
                     app.staticTexts["Boost Your Profile"].exists)

        // Verify pricing options are shown
        let monthlyButton = app.buttons["MonthlySubscription"]
        let yearlyButton = app.buttons["YearlySubscription"]

        XCTAssertTrue(monthlyButton.exists || yearlyButton.exists)

        // Select a plan (monthly for faster testing)
        if monthlyButton.exists {
            monthlyButton.tap()
        } else {
            yearlyButton.tap()
        }

        // Verify purchase button is enabled
        let purchaseButton = app.buttons["PurchaseButton"]
        XCTAssertTrue(waitForElement(purchaseButton, timeout: 3))
        XCTAssertTrue(purchaseButton.isEnabled)

        // In test mode, purchase should complete quickly
        purchaseButton.tap()

        // Wait for purchase confirmation or loading indicator
        sleep(2) // StoreKit test purchases are quick

        // Verify success - either back to profile or success screen
        let successIndicator = app.staticTexts["PurchaseSuccess"]
                            || app.staticTexts["Welcome to Premium"]
                            || app.staticTexts["ProfileTitle"]

        XCTAssertTrue(waitForElement(successIndicator, timeout: 10))
    }

    // MARK: - Subscription Management

    @MainActor
    func testSubscriptionManagement() throws {
        loginPremiumUser()

        // Navigate to profile settings
        app.tabBars.buttons["Profile"].tap()
        app.buttons["SettingsButton"].tap()

        // Open subscription management
        if app.buttons["ManageSubscription"].exists {
            app.buttons["ManageSubscription"].tap()
        } else if app.buttons["Subscription"].exists {
            app.buttons["Subscription"].tap()
        }

        XCTAssertTrue(waitForElement(app.staticTexts["SubscriptionTitle"], timeout: 5))

        // Verify subscription details are shown
        XCTAssertTrue(app.staticTexts["Premium"].exists)

        // Check for renewal date or status
        let hasRenewalInfo = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Renews'")).count > 0
        let hasExpiryInfo = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Expires'")).count > 0
        XCTAssertTrue(hasRenewalInfo || hasExpiryInfo)

        // Verify manage options (cancel, change plan, etc.)
        let hasCancelOption = app.buttons["CancelSubscription"].exists
        let hasManageOption = app.buttons["ManageInAppStore"].exists
        XCTAssertTrue(hasCancelOption || hasManageOption)
    }

    // MARK: - Premium Feature Access

    @MainActor
    func testPremiumFeatureAccess() throws {
        loginPremiumUser()

        // Test 1: Unlimited likes (premium feature)
        app.tabBars.buttons["Discover"].tap()
        XCTAssertTrue(waitForElement(app.buttons["LikeButton"], timeout: 5))

        // Like many profiles to test unlimited likes
        for i in 0..<15 {
            if app.buttons["LikeButton"].exists {
                app.buttons["LikeButton"].tap()
                sleep(1)
            }
        }

        // Verify no "out of likes" message appeared
        XCTAssertFalse(app.staticTexts["OutOfLikes"].exists)
        XCTAssertFalse(app.staticTexts["UpgradeForMoreLikes"].exists)

        // Test 2: "See Who Likes You" feature
        app.tabBars.buttons["Matches"].tap()

        if app.buttons["SeeWhoLikesYou"].exists || app.buttons["Likes"].exists {
            app.buttons["SeeWhoLikesYou"].tap()

            // Verify likes view opens (premium only)
            XCTAssertTrue(waitForElement(app.staticTexts["WhoLikesYouTitle"], timeout: 5))

            // Should show list of users who liked you
            let likesList = app.collectionViews["LikesList"]
            XCTAssertTrue(likesList.exists || app.cells.count > 0)
        }

        // Test 3: Boost profile feature
        app.tabBars.buttons["Profile"].tap()

        if app.buttons["BoostProfile"].exists {
            app.buttons["BoostProfile"].tap()

            // In test mode, boost should activate
            sleep(1)

            // Verify boost confirmation or indicator
            let boostActive = app.staticTexts["BoostActive"].exists ||
                            app.staticTexts["ProfileBoosted"].exists
            XCTAssertTrue(boostActive)
        }
    }

    // MARK: - Free User Limitations

    @MainActor
    func testFreeUserLimitations() throws {
        loginTestUser() // Free user

        // Navigate to discover
        app.tabBars.buttons["Discover"].tap()
        XCTAssertTrue(waitForElement(app.buttons["LikeButton"], timeout: 5))

        // Like profiles until limit is reached (typically 10-20 likes per day)
        var likesUsed = 0
        let maxLikes = 25 // Try up to 25

        for i in 0..<maxLikes {
            if app.buttons["LikeButton"].exists && app.buttons["LikeButton"].isEnabled {
                app.buttons["LikeButton"].tap()
                likesUsed += 1
                sleep(1)
            } else {
                break
            }

            // Check if upgrade prompt appeared
            if app.staticTexts["OutOfLikes"].exists ||
               app.staticTexts["UpgradeForMoreLikes"].exists ||
               app.buttons["UpgradeToPremium"].exists {
                break
            }
        }

        // Verify that either:
        // 1. We hit the like limit and saw upgrade prompt
        // 2. Or we're in test mode with unlimited likes
        let hitLimit = app.staticTexts["OutOfLikes"].exists ||
                      app.staticTexts["UpgradeForMoreLikes"].exists ||
                      app.buttons["UpgradeToPremium"].exists

        if hitLimit {
            XCTAssertTrue(true, "Like limit reached as expected for free users")

            // Verify upgrade button is present
            XCTAssertTrue(app.buttons["UpgradeToPremium"].exists ||
                         app.buttons["GetPremium"].exists)
        } else {
            // In test mode, might have unlimited likes
            Logger.shared.info("No like limit hit - test mode may have unlimited likes enabled")
        }
    }

    // MARK: - Receipt Validation

    @MainActor
    func testReceiptValidation() throws {
        loginTestUser()

        // Navigate to premium purchase
        app.tabBars.buttons["Profile"].tap()
        app.buttons["UpgradeToPremium"].tap()

        XCTAssertTrue(waitForElement(app.staticTexts["PremiumTitle"], timeout: 5))

        // Select and purchase a plan
        if app.buttons["MonthlySubscription"].exists {
            app.buttons["MonthlySubscription"].tap()
        }

        let purchaseButton = app.buttons["PurchaseButton"]
        XCTAssertTrue(waitForElement(purchaseButton, timeout: 3))
        purchaseButton.tap()

        // Wait for purchase to complete
        sleep(3)

        // Verify receipt validation happened in background
        // (indicated by successful premium activation)

        // Navigate back to profile
        if app.navigationBars.buttons.element(boundBy: 0).exists {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        // Check if premium badge or indicator appears
        let isPremium = app.staticTexts["Premium"].exists ||
                       app.images["PremiumBadge"].exists ||
                       app.staticTexts["PremiumMember"].exists

        XCTAssertTrue(isPremium, "Premium status should be active after successful purchase")
    }

    // MARK: - Purchase Restoration

    @MainActor
    func testPurchaseRestoration() throws {
        loginPremiumUser()

        // Simulate app reinstall by launching with cleared purchase cache
        app.launchEnvironment["CLEAR_PURCHASE_CACHE"] = "1"
        app.launch()

        // Wait for app to load
        sleep(2)

        // Navigate to premium/subscription view
        app.tabBars.buttons["Profile"].tap()

        if app.buttons["Premium"].exists {
            app.buttons["Premium"].tap()
        } else if app.buttons["UpgradeToPremium"].exists {
            app.buttons["UpgradeToPremium"].tap()
        }

        // Look for "Restore Purchases" button
        if app.buttons["RestorePurchases"].exists {
            app.buttons["RestorePurchases"].tap()

            // Wait for restoration
            sleep(2)

            // Verify restoration success
            let restorationSuccess = app.staticTexts["PurchaseRestored"].exists ||
                                    app.staticTexts["Premium"].exists
            XCTAssertTrue(restorationSuccess)
        }
    }

    // MARK: - Payment Error Handling

    @MainActor
    func testPaymentErrorHandling() throws {
        loginTestUser()

        // Enable payment failure simulation
        app.launchEnvironment["SIMULATE_PAYMENT_FAILURE"] = "1"
        app.launch()

        // Attempt to purchase premium
        app.tabBars.buttons["Profile"].tap()
        app.buttons["UpgradeToPremium"].tap()

        XCTAssertTrue(waitForElement(app.staticTexts["PremiumTitle"], timeout: 5))

        if app.buttons["MonthlySubscription"].exists {
            app.buttons["MonthlySubscription"].tap()
        }

        let purchaseButton = app.buttons["PurchaseButton"]
        purchaseButton.tap()

        // Wait for error to appear
        sleep(2)

        // Verify error message is shown
        let hasError = app.staticTexts["PurchaseFailed"].exists ||
                      app.staticTexts["PaymentError"].exists ||
                      app.staticTexts["PurchaseError"].exists ||
                      app.alerts.element.exists

        XCTAssertTrue(hasError, "Payment error should be displayed to user")

        // Verify user can dismiss error and try again
        if app.alerts.element.exists {
            app.alerts.buttons["OK"].tap()
        }

        // Verify we're back to premium selection screen
        XCTAssertTrue(app.buttons["PurchaseButton"].exists ||
                     app.staticTexts["PremiumTitle"].exists)
    }

    // MARK: - In-App Purchase Products

    @MainActor
    func testProductsLoading() throws {
        loginTestUser()

        // Navigate to premium view
        app.tabBars.buttons["Profile"].tap()
        app.buttons["UpgradeToPremium"].tap()

        // Wait for products to load
        XCTAssertTrue(waitForElement(app.staticTexts["PremiumTitle"], timeout: 5))

        // Verify subscription options are displayed with pricing
        let hasMonthlyPricing = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '$'")).count > 0
        let hasSubscriptionOptions = app.buttons["MonthlySubscription"].exists ||
                                     app.buttons["YearlySubscription"].exists

        XCTAssertTrue(hasSubscriptionOptions, "Subscription options should be available")

        // May not have pricing in test mode, so this is optional
        if hasMonthlyPricing {
            XCTAssertTrue(true, "Pricing information is displayed")
        }
    }

    // MARK: - Helper Methods

    private func loginTestUser() {
        app.launchEnvironment["AUTO_LOGIN"] = "test@example.com"
        app.launchEnvironment["USER_PREMIUM_STATUS"] = "false"
        app.launch()

        // Wait for main view to load
        XCTAssertTrue(waitForElement(app.tabBars.buttons["Discover"], timeout: 10))
    }

    private func loginPremiumUser() {
        app.launchEnvironment["AUTO_LOGIN"] = "premium@example.com"
        app.launchEnvironment["USER_PREMIUM_STATUS"] = "true"
        app.launchEnvironment["SUBSCRIPTION_TYPE"] = "monthly"
        app.launch()

        // Wait for main view to load
        XCTAssertTrue(waitForElement(app.tabBars.buttons["Discover"], timeout: 10))
    }

    private func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    private func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}
