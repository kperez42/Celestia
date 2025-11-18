# Celestia End-to-End Tests

Comprehensive end-to-end testing suite for the Celestia iOS app using XCUITest framework.

## Overview

The E2E test suite validates critical user journeys from start to finish, ensuring all features work correctly in a production-like environment. Tests cover user flows, payment processing, and safety features.

## Test Suites

### 1. UserJourneyTests.swift

**Purpose**: Test complete user journeys from signup to core feature usage

**Test Cases**:
- `testCompleteNewUserJourney()` - Full onboarding flow (signup → onboarding → discover → matches → messages → profile)
- `testDiscoverSwipeActions()` - Swipe gestures (left/right), like/pass/super like buttons
- `testDiscoverFilters()` - Age range and distance filter adjustments
- `testMatchAndChatFlow()` - Match selection and messaging
- `testProfileEdit()` - Profile editing and bio updates
- `testSettingsConfiguration()` - Settings toggles and privacy options

**Coverage**:
- Authentication & Signup
- Onboarding (name, photos, interests, location)
- Discovery UI (swipes, filters, likes)
- Matching system
- Messaging functionality
- Profile management
- Settings & preferences

---

### 2. PaymentFlowTests.swift

**Purpose**: Test in-app purchases, subscriptions, and premium features

**Test Cases**:
- `testPremiumUpgradeFlow()` - Complete premium purchase flow
- `testSubscriptionManagement()` - View and manage active subscriptions
- `testPremiumFeatureAccess()` - Verify premium-only features work (unlimited likes, "see who likes you", boost)
- `testFreeUserLimitations()` - Verify free tier limits (like limits, upgrade prompts)
- `testReceiptValidation()` - Purchase receipt validation with backend
- `testPurchaseRestoration()` - Restore purchases after reinstall
- `testPaymentErrorHandling()` - Handle failed payments gracefully
- `testProductsLoading()` - In-app purchase products load correctly

**Coverage**:
- StoreKit integration
- Subscription tiers (monthly, yearly)
- Premium feature gating
- Receipt validation
- Purchase restoration
- Error handling
- Free vs. Premium comparison

**Setup Requirements**:
- StoreKit Configuration file enabled in scheme
- Test products configured in App Store Connect Sandbox
- Launch environment: `ENABLE_TEST_PAYMENTS=1`

---

### 3. SafetyFeatureTests.swift

**Purpose**: Test safety, moderation, and privacy features

**Test Cases**:

**Blocking & Reporting**:
- `testBlockUserFlow()` - Block users from discover/profile
- `testUnblockUser()` - Unblock from blocked users list
- `testReportUserProfile()` - Report inappropriate profiles
- `testReportMessage()` - Report inappropriate messages

**Photo Verification**:
- `testPhotoVerificationFlow()` - Complete selfie verification process
- `testVerificationBadgeDisplay()` - Verified badge display

**Safety Center**:
- `testSafetyCenterAccess()` - Access safety resources
- `testSafetyTips()` - View safety tips and guidelines

**Privacy**:
- `testPrivacySettings()` - Toggle privacy settings (online status, read receipts, distance)
- `testHideProfile()` - Pause/hide profile visibility
- `testAccountDeletionFlow()` - Account deletion warning and flow

**Content Moderation**:
- `testInappropriateMessageWarning()` - Inappropriate content detection

**Coverage**:
- User blocking/unblocking
- Content reporting (profiles, messages)
- AI photo verification
- Safety resources
- Privacy controls
- Profile visibility
- Account deletion
- Content filtering

---

## Running Tests

### From Xcode

1. Open `Celestia.xcodeproj` in Xcode
2. Select the `CelestiaUITests` scheme
3. Choose a simulator or device
4. Run tests:
   - All E2E tests: `Cmd+U`
   - Specific suite: Right-click on test class → Run
   - Single test: Click diamond icon next to test method

### From Command Line

```bash
# Run all UI tests
xcodebuild test \
  -project Celestia.xcodeproj \
  -scheme Celestia \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0' \
  -only-testing:CelestiaUITests

# Run specific test suite
xcodebuild test \
  -project Celestia.xcodeproj \
  -scheme Celestia \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0' \
  -only-testing:CelestiaUITests/UserJourneyTests

# Run specific test
xcodebuild test \
  -project Celestia.xcodeproj \
  -scheme Celestia \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0' \
  -only-testing:CelestiaUITests/UserJourneyTests/testCompleteNewUserJourney
```

### Using Fastlane

```bash
# Run all UI tests
fastlane test ui:true

# Run specific suite
fastlane test ui:true suite:UserJourneyTests
```

---

## Test Configuration

### Launch Arguments

All E2E tests use launch arguments to configure the app for testing:

```swift
app.launchArguments = ["UI_TESTING"]
```

This enables:
- Faster animations (reduced to 0.1x speed)
- Disabled analytics/tracking
- Deterministic behavior
- Mock data when needed

### Launch Environment Variables

Tests use environment variables to control app behavior:

| Variable | Purpose | Values |
|----------|---------|--------|
| `RESET_DATA` | Clear all user data before test | `"1"` |
| `AUTO_LOGIN` | Skip authentication with test user | `"test@example.com"` |
| `USER_PREMIUM_STATUS` | Set premium status | `"true"` / `"false"` |
| `CREATE_TEST_MATCH` | Create test match for messaging | `"1"` |
| `CREATE_TEST_USERS` | Populate with test users | `"1"` |
| `ENABLE_TEST_PAYMENTS` | Enable StoreKit testing | `"1"` |
| `SIMULATE_PAYMENT_FAILURE` | Test payment error handling | `"1"` |
| `HAS_BLOCKED_USERS` | Pre-populate blocked users | `"1"` |
| `IS_VERIFIED` | Set verification status | `"1"` |
| `CLEAR_PURCHASE_CACHE` | Simulate fresh install | `"1"` |

### Example Test Setup

```swift
app.launchEnvironment = [
    "RESET_DATA": "1",
    "AUTO_LOGIN": "premium@example.com",
    "USER_PREMIUM_STATUS": "true"
]
app.launch()
```

---

## App Configuration for Testing

### AppDelegate.swift

Add test mode detection:

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    // Detect UI testing mode
    if ProcessInfo.processInfo.arguments.contains("UI_TESTING") {
        setupTestMode()
    }

    return true
}

private func setupTestMode() {
    // Speed up animations
    UIView.setAnimationsEnabled(false)
    UIApplication.shared.windows.first?.layer.speed = 100

    // Disable analytics
    Analytics.setAnalyticsCollectionEnabled(false)

    // Handle launch environment
    let env = ProcessInfo.processInfo.environment

    if env["RESET_DATA"] == "1" {
        clearAllUserData()
    }

    if let email = env["AUTO_LOGIN"] {
        autoLogin(email: email)
    }

    if env["USER_PREMIUM_STATUS"] == "true" {
        UserDefaults.standard.set(true, forKey: "isPremium")
    }

    if env["CREATE_TEST_MATCH"] == "1" {
        createTestMatch()
    }

    if env["ENABLE_TEST_PAYMENTS"] == "1" {
        // StoreKit testing is automatic when scheme has configuration file
    }
}
```

### Accessibility Identifiers

For reliable element selection, add accessibility identifiers to UI elements:

```swift
// Buttons
button.accessibilityIdentifier = "GetStartedButton"
button.accessibilityIdentifier = "LikeButton"
button.accessibilityIdentifier = "SendButton"

// Text Fields
textField.accessibilityIdentifier = "PhoneNumberField"
textField.accessibilityIdentifier = "MessageInputField"

// Views
view.accessibilityIdentifier = "ProfileCard"
collectionView.accessibilityIdentifier = "LikesList"
```

---

## Best Practices

### 1. Test Isolation

Each test should be independent:
- Use `RESET_DATA` to clear state between tests
- Don't rely on data from previous tests
- Use `setUp()` and `tearDown()` consistently

### 2. Wait Strategies

Always wait for elements instead of using `sleep()`:

```swift
// Good - explicit wait
XCTAssertTrue(waitForElement(app.buttons["LikeButton"], timeout: 5))

// Bad - arbitrary sleep
sleep(3)
app.buttons["LikeButton"].tap()
```

### 3. Accessibility Over Hierarchy

Prefer accessibility identifiers over view hierarchy:

```swift
// Good - stable
app.buttons["SubmitButton"].tap()

// Bad - fragile
app.windows.element(boundBy: 0).buttons.element(boundBy: 2).tap()
```

### 4. Error Messages

Provide descriptive failure messages:

```swift
XCTAssertTrue(element.exists, "Like button should appear after profile loads")
```

### 5. Test Data

Use dedicated test accounts:
- `test@example.com` - Free user
- `premium@example.com` - Premium subscriber
- `verified@example.com` - Verified user

---

## Troubleshooting

### Tests Fail to Find Elements

1. **Check accessibility identifiers** - Verify they match between app and tests
2. **Increase timeout** - Some screens may load slowly in testing
3. **Check launch environment** - Ensure test data is properly set up

### Tests Are Flaky

1. **Remove sleep() calls** - Replace with explicit waits
2. **Check animations** - Ensure animations are disabled in test mode
3. **Verify test isolation** - Each test should reset state

### StoreKit Tests Fail

1. **Enable StoreKit Configuration** - Edit scheme → Options → StoreKit Configuration
2. **Check product IDs** - Ensure they match your StoreKit config file
3. **Clear purchase history** - Editor → Clear All Purchases in simulator

### App Doesn't Launch

1. **Check scheme** - Ensure UI Testing scheme is selected
2. **Clean build** - `Cmd+Shift+K` then rebuild
3. **Reset simulator** - Device → Erase All Content and Settings

---

## Continuous Integration

### GitHub Actions Example

```yaml
name: UI Tests

on: [push, pull_request]

jobs:
  ui-tests:
    runs-on: macos-13
    steps:
      - uses: actions/checkout@v3

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.0.app

      - name: Run UI Tests
        run: |
          xcodebuild test \
            -project Celestia.xcodeproj \
            -scheme Celestia \
            -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0' \
            -only-testing:CelestiaUITests \
            -resultBundlePath TestResults

      - name: Upload Test Results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: TestResults.xcresult
```

---

## Test Coverage

### Current Coverage

| Feature Area | Test Count | Coverage |
|--------------|------------|----------|
| User Journey | 6 tests | ✅ Full flow |
| Payments | 8 tests | ✅ All scenarios |
| Safety | 12 tests | ✅ Comprehensive |
| **Total** | **26 tests** | **~85% E2E coverage** |

### Not Yet Covered

- [ ] Push notification interactions
- [ ] Background app refresh
- [ ] Deep linking
- [ ] Location permission edge cases
- [ ] Network failure scenarios
- [ ] App update flows

---

## Maintenance

### Adding New Tests

1. Identify the user journey to test
2. Create test method with descriptive name
3. Use appropriate launch environment setup
4. Add accessibility identifiers to new UI elements
5. Implement explicit waits, not sleep()
6. Add to this documentation

### Updating Tests

When UI changes:
1. Update accessibility identifiers if needed
2. Update element queries in tests
3. Run full test suite to ensure no regressions
4. Update documentation if flow changes

---

## Performance

### Test Execution Times

| Test Suite | Time | Tests |
|------------|------|-------|
| UserJourneyTests | ~3 min | 6 |
| PaymentFlowTests | ~4 min | 8 |
| SafetyFeatureTests | ~5 min | 12 |
| **Total** | **~12 min** | **26** |

### Optimization Tips

- Run on faster simulators (iPhone 15 vs older models)
- Reduce network calls with mocked responses
- Disable animations completely
- Use test-specific simplified views where possible

---

## Resources

- [XCUITest Documentation](https://developer.apple.com/documentation/xctest/user_interface_tests)
- [Accessibility Inspector](https://developer.apple.com/library/archive/documentation/Accessibility/Conceptual/AccessibilityMacOSX/OSXAXTestingApps.html)
- [StoreKit Testing](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode)

---

## Questions?

For test-related questions:
- Check existing tests for examples
- Review this documentation
- Ask the QA team or iOS developers

---

**Last Updated**: 2025-11-18
**Maintained By**: iOS Development Team
**Test Framework**: XCUITest (iOS 15.0+)
