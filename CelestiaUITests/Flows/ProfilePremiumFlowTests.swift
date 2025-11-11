//
//  ProfilePremiumFlowTests.swift
//  CelestiaUITests
//
//  Tests for Profile Editing and Premium Upgrade flows
//

import XCTest

final class ProfilePremiumFlowTests: XCTestCase {

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

    // MARK: - Profile Viewing Tests

    func testViewProfile() throws {
        // Given: User is on swipe screen
        let swipeScreen = SwipeScreen(app: app)
        swipeScreen.verifySwipeScreen()

        // When: User navigates to profile
        let profileScreen = swipeScreen.tapSettings()

        // Then: Profile screen should be displayed
        profileScreen.verifyProfileScreen()
        profileScreen.takeScreenshot(named: "Profile_Screen")
    }

    func testProfileDisplaysUserInfo() throws {
        // Given: User navigates to profile
        let swipeScreen = SwipeScreen(app: app)
        let profileScreen = swipeScreen.tapSettings()

        // Then: User's information should be displayed
        profileScreen.verifyProfileName("Test User")
        profileScreen.takeScreenshot(named: "Profile_User_Info")
    }

    // MARK: - Profile Editing Tests

    func testEditBio() throws {
        // Given: User is on profile screen
        let swipeScreen = SwipeScreen(app: app)
        let profileScreen = swipeScreen.tapSettings()
        profileScreen.verifyProfileScreen()
        profileScreen.takeScreenshot(named: "01_Profile_Before_Edit")

        // When: User taps edit profile
        profileScreen.tapEditProfile()
        profileScreen.takeScreenshot(named: "02_Edit_Profile_Mode")

        // And: User updates bio
        let newBio = "Love traveling, coffee, and good conversations! ☕✈️"
        profileScreen.updateBio(newBio)
        profileScreen.takeScreenshot(named: "03_Bio_Updated")

        // And: User saves changes
        profileScreen.tapSave()

        // Then: Bio should be updated
        profileScreen.verifyBio(newBio)
        profileScreen.takeScreenshot(named: "04_Bio_Saved")
    }

    func testAddPhoto() throws {
        // Given: User is editing profile
        let swipeScreen = SwipeScreen(app: app)
        let profileScreen = swipeScreen.tapSettings()
        profileScreen.tapEditProfile()
        profileScreen.takeScreenshot(named: "01_Before_Adding_Photo")

        // When: User taps add photo
        profileScreen.tapAddPhoto()

        // And: User selects photo from library
        profileScreen.selectPhotoFromLibrary()

        // Then: Photo should be added to profile
        profileScreen.takeScreenshot(named: "02_Photo_Added")

        // And: User saves changes
        profileScreen.tapSave()
        profileScreen.takeScreenshot(named: "03_Profile_With_New_Photo")
    }

    func testCancelProfileEdit() throws {
        // Given: User is editing profile
        let swipeScreen = SwipeScreen(app: app)
        let profileScreen = swipeScreen.tapSettings()
        profileScreen.tapEditProfile()

        let originalBio = "Original bio"
        profileScreen.verifyBio(originalBio)

        // When: User makes changes but doesn't save
        profileScreen.updateBio("Changed bio")

        // And: User navigates away
        let returnedSwipeScreen = profileScreen.tapBack()

        // Then: Changes should not be saved
        let checkProfileScreen = returnedSwipeScreen.tapSettings()
        checkProfileScreen.verifyBio(originalBio)
        checkProfileScreen.takeScreenshot(named: "Bio_Not_Saved")
    }

    // MARK: - Premium Upgrade Tests

    func testViewPremiumScreen() throws {
        // Given: User is on profile screen
        let swipeScreen = SwipeScreen(app: app)
        let profileScreen = swipeScreen.tapSettings()

        // When: User taps upgrade to premium
        let premiumScreen = profileScreen.tapUpgrade()

        // Then: Premium screen should be displayed
        premiumScreen.verifyPremiumScreen()
        premiumScreen.takeScreenshot(named: "Premium_Screen")
    }

    func testSelectMonthlyPlan() throws {
        // Given: User is on premium screen
        let swipeScreen = SwipeScreen(app: app)
        let profileScreen = swipeScreen.tapSettings()
        let premiumScreen = profileScreen.tapUpgrade()
        premiumScreen.verifyPremiumScreen()
        premiumScreen.takeScreenshot(named: "01_Premium_Plans")

        // When: User selects monthly plan
        premiumScreen.selectMonthlyPlan()
        premiumScreen.takeScreenshot(named: "02_Monthly_Plan_Selected")

        // And: User taps subscribe
        premiumScreen.tapSubscribe()

        // Then: Subscription flow should begin
        // (In real app, this would trigger StoreKit)
        premiumScreen.takeScreenshot(named: "03_Subscription_Initiated")
    }

    func testSelectYearlyPlan() throws {
        // Given: User is on premium screen
        let swipeScreen = SwipeScreen(app: app)
        let profileScreen = swipeScreen.tapSettings()
        let premiumScreen = profileScreen.tapUpgrade()
        premiumScreen.verifyPremiumScreen()

        // When: User selects yearly plan
        premiumScreen.selectYearlyPlan()
        premiumScreen.takeScreenshot(named: "Yearly_Plan_Selected")

        // And: User taps subscribe
        premiumScreen.tapSubscribe()

        // Then: Subscription flow should begin
        premiumScreen.takeScreenshot(named: "Yearly_Subscription_Initiated")
    }

    func testRestorePurchases() throws {
        // Given: User is on premium screen
        let swipeScreen = SwipeScreen(app: app)
        let profileScreen = swipeScreen.tapSettings()
        let premiumScreen = profileScreen.tapUpgrade()
        premiumScreen.verifyPremiumScreen()

        // When: User taps restore purchases
        premiumScreen.tapRestorePurchases()

        // Then: Restore process should begin
        // (In real app, this would check StoreKit)
        premiumScreen.takeScreenshot(named: "Restore_Purchases")
    }

    func testClosePremiumScreen() throws {
        // Given: User is on premium screen
        let swipeScreen = SwipeScreen(app: app)
        let profileScreen = swipeScreen.tapSettings()
        let premiumScreen = profileScreen.tapUpgrade()
        premiumScreen.verifyPremiumScreen()

        // When: User closes premium screen
        let returnedProfileScreen = premiumScreen.tapClose()

        // Then: User should return to profile screen
        returnedProfileScreen.verifyProfileScreen()
        returnedProfileScreen.takeScreenshot(named: "Back_To_Profile")
    }

    // MARK: - Complete Profile Flow Test

    func testCompleteProfileEditFlow() throws {
        // Given: User is signed in
        let swipeScreen = SwipeScreen(app: app)
        swipeScreen.verifySwipeScreen()
        swipeScreen.takeScreenshot(named: "01_Swipe_Screen")

        // When: User navigates to profile
        let profileScreen = swipeScreen.tapSettings()
        profileScreen.verifyProfileScreen()
        profileScreen.takeScreenshot(named: "02_Profile_Screen")

        // And: User edits profile
        profileScreen.tapEditProfile()
        profileScreen.updateBio("Adventure seeker 🏔️ Coffee enthusiast ☕")
        profileScreen.takeScreenshot(named: "03_Editing_Profile")

        // And: User adds a photo
        profileScreen.tapAddPhoto()
        profileScreen.selectPhotoFromLibrary()
        profileScreen.takeScreenshot(named: "04_Photo_Added")

        // And: User saves changes
        profileScreen.tapSave()
        profileScreen.takeScreenshot(named: "05_Profile_Saved")

        // And: User navigates back to swipe
        let returnedSwipeScreen = profileScreen.tapBack()
        returnedSwipeScreen.verifySwipeScreen()
        returnedSwipeScreen.takeScreenshot(named: "06_Back_To_Swiping")

        // Then: Complete flow should work end-to-end
        // User successfully: viewed profile → edited bio → added photo → saved → returned to swiping
    }

    // MARK: - Settings Tests

    func testViewSettings() throws {
        // Given: User is on profile screen
        let swipeScreen = SwipeScreen(app: app)
        let profileScreen = swipeScreen.tapSettings()

        // When: User scrolls down to see all options
        profileScreen.takeScreenshot(named: "01_Profile_Top")

        // Scroll to bottom
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
        }
        profileScreen.takeScreenshot(named: "02_Profile_Bottom")

        // Then: All profile options should be visible
    }

    // MARK: - Performance Tests

    func testProfileLoadingPerformance() throws {
        // Measure time to load profile screen
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let swipeScreen = SwipeScreen(app: app)
            let profileScreen = swipeScreen.tapSettings()
            profileScreen.verifyProfileScreen()
            _ = profileScreen.tapBack()
        }
    }

    func testPremiumScreenLoadingPerformance() throws {
        // Measure time to load premium screen
        let swipeScreen = SwipeScreen(app: app)
        let profileScreen = swipeScreen.tapSettings()

        measure(metrics: [XCTClockMetric()]) {
            let premiumScreen = profileScreen.tapUpgrade()
            premiumScreen.verifyPremiumScreen()
            _ = premiumScreen.tapClose()
        }
    }
}
