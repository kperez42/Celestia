# Firebase Crashlytics & Performance Monitoring Setup

Complete guide for integrating Firebase Crashlytics and Performance Monitoring into Celestia.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Firebase Console Setup](#firebase-console-setup)
- [Xcode Configuration](#xcode-configuration)
- [Code Integration](#code-integration)
- [Testing](#testing)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Prerequisites

- Firebase project created
- `GoogleService-Info.plist` added to project
- Firebase SDK installed (via CocoaPods or SPM)

## Firebase Console Setup

### 1. Enable Crashlytics

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your Celestia project
3. Navigate to **Crashlytics** in the left sidebar
4. Click **"Enable Crashlytics"**
5. Follow the setup wizard

### 2. Enable Performance Monitoring

1. In Firebase Console, navigate to **Performance**
2. Click **"Get Started"**
3. Performance Monitoring will be automatically enabled

## Xcode Configuration

### Option 1: CocoaPods

Add to your `Podfile`:

```ruby
# Crashlytics and Performance
pod 'Firebase/Crashlytics'
pod 'Firebase/Performance'
```

Then run:
```bash
pod install
```

### Option 2: Swift Package Manager

1. In Xcode, go to **File > Add Packages...**
2. Enter: `https://github.com/firebase/firebase-ios-sdk`
3. Select packages:
   - FirebaseCrashlytics
   - FirebasePerformance
4. Click **Add Package**

### Build Phase Scripts

#### 1. Add Crashlytics Run Script

1. In Xcode, select your project
2. Select the Celestia target
3. Go to **Build Phases**
4. Click **+** > **New Run Script Phase**
5. Name it: "Run Firebase Crashlytics"
6. Add this script:

```bash
"${PODS_ROOT}/FirebaseCrashlytics/run"
```

Or if using SPM:

```bash
"${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
```

7. Add input files:
```
$(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)
```

8. Move this script **after** "Compile Sources" but **before** "Copy Bundle Resources"

#### 2. Add dSYM Upload Script (Optional, for better crash symbolication)

Add another Run Script Phase:

```bash
"${PODS_ROOT}/FirebaseCrashlytics/upload-symbols" \
  -gsp "${PROJECT_DIR}/Celestia/GoogleService-Info.plist" \
  -p ios "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}"
```

### Debug Symbols Configuration

Ensure debug symbols are generated:

1. Select your target > **Build Settings**
2. Search for "Debug Information Format"
3. Set to **"DWARF with dSYM File"** for both Debug and Release

## Code Integration

### 1. Initialize in AppDelegate/App

**SwiftUI App:**

```swift
import SwiftUI
import FirebaseCore
import FirebaseCrashlytics
import FirebasePerformance

@main
struct CelestiaApp: App {
    init() {
        // Configure Firebase
        FirebaseApp.configure()

        // Setup Crashlytics
        CrashlyticsManager.shared.setupAutomaticContext()

        // Log app launch
        CrashlyticsManager.shared.logEvent("app_launched")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**UIKit AppDelegate:**

```swift
import UIKit
import FirebaseCore
import FirebaseCrashlytics

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Configure Firebase
        FirebaseApp.configure()

        // Setup Crashlytics
        CrashlyticsManager.shared.setupAutomaticContext()

        return true
    }
}
```

### 2. Set User Identifier

When user signs in:

```swift
// After successful sign in
CrashlyticsManager.shared.setUserId(userId)
CrashlyticsManager.shared.setUserAttributes([
    "email": user.email,
    "premium": user.isPremium ? "yes" : "no",
    "accountAge": "\(user.accountAgeDays) days"
])
```

When user signs out:

```swift
// Before sign out
CrashlyticsManager.shared.clearUserId()
```

### 3. Log Events

```swift
// Log screen views
CrashlyticsManager.shared.logScreenView("ProfileView")

// Log user actions
CrashlyticsManager.shared.logUserAction("swipe_right", details: "userId: 12345")

// Log breadcrumbs
CrashlyticsManager.shared.logBreadcrumb("Started match creation", category: "matching")
```

### 4. Record Errors

**Non-fatal errors:**

```swift
do {
    try await someOperation()
} catch {
    // Record to Crashlytics
    CrashlyticsManager.shared.recordError(error, userInfo: [
        "operation": "someOperation",
        "userId": currentUserId
    ])

    // Also log to Logger
    Logger.shared.error("Operation failed", category: .general, error: error)

    // Show user-friendly error
    showError(error)
}
```

**Celestia-specific errors:**

```swift
CrashlyticsManager.shared.recordCelestiaError(.matchNotFound, context: [
    "matchId": matchId,
    "userId": userId
])
```

**Custom errors:**

```swift
CrashlyticsManager.shared.recordError(
    domain: "com.celestia.matching",
    code: 1001,
    message: "Failed to create match",
    userInfo: [
        "user1": user1Id,
        "user2": user2Id,
        "reason": "Already matched"
    ]
)
```

### 5. Performance Monitoring

**Trace network requests:**

```swift
// Start trace
CrashlyticsManager.shared.startTrace(name: "load_profile")

// Perform operation
let profile = try await loadProfile(userId: userId)

// Add metrics
CrashlyticsManager.shared.incrementMetric(
    traceName: "load_profile",
    metric: "items_loaded",
    by: 1
)

// Add attributes
CrashlyticsManager.shared.setTraceAttribute(
    traceName: "load_profile",
    key: "user_type",
    value: isPremium ? "premium" : "free"
)

// Stop trace
CrashlyticsManager.shared.stopTrace(name: "load_profile")
```

**Trace specific operations:**

```swift
func createMatch(user1Id: String, user2Id: String) async throws {
    CrashlyticsManager.shared.startTrace(name: "create_match")
    defer {
        CrashlyticsManager.shared.stopTrace(name: "create_match")
    }

    // Your matching logic here
    try await MatchService.shared.createMatch(user1Id: user1Id, user2Id: user2Id)

    CrashlyticsManager.shared.incrementMetric(
        traceName: "create_match",
        metric: "matches_created"
    )
}
```

**Automatic network tracking:**

Performance SDK automatically tracks URLSession requests, but you can add custom tracking:

```swift
let startTime = Date()
let response = try await URLSession.shared.data(from: url)
let endTime = Date()

CrashlyticsManager.shared.trackNetworkRequest(
    url: url,
    httpMethod: "GET",
    startTime: startTime,
    endTime: endTime,
    responseCode: 200,
    requestSize: 0,
    responseSize: Int64(response.0.count)
)
```

## Testing

### Test Crash Reporting (DEBUG Only)

```swift
#if DEBUG
// Add a test button in settings or debug menu
Button("Test Crash") {
    CrashlyticsManager.shared.testCrash()
}

Button("Test Non-Fatal Error") {
    CrashlyticsManager.shared.testNonFatalError()
}
#endif
```

### Verify Crashlytics is Working

1. **Force a test crash:**
   - Run the app in debug mode
   - Trigger the test crash
   - Restart the app
   - Check Firebase Console > Crashlytics after a few minutes

2. **Check Console Logs:**
   Look for these messages:
   ```
   [Firebase/Crashlytics] Preparing to submit crash reports
   [Firebase/Crashlytics] Successfully submitted crash report
   ```

3. **Verify in Firebase Console:**
   - Go to Firebase Console > Crashlytics
   - Should see your test crash within 5-10 minutes

### Test Performance Monitoring

1. Run the app
2. Navigate through different screens
3. Perform actions (swipes, matches, messages)
4. Wait 12-24 hours
5. Check Firebase Console > Performance
6. Should see traces and metrics

## Best Practices

### 1. Error Recording Strategy

**DO Record:**
- Network failures
- Database errors
- Authentication failures
- Payment processing errors
- Unexpected app states
- Critical user flow failures

**DON'T Record:**
- Expected validation errors (invalid email, etc.)
- User-initiated cancellations
- Temporary network issues (if retrying)
- Debug/development errors

### 2. Logging Best Practices

```swift
// Good: Informative context
CrashlyticsManager.shared.logEvent("match_created", parameters: [
    "user1_id": user1Id,
    "user2_id": user2Id,
    "match_type": "mutual_like"
])

// Bad: No context
CrashlyticsManager.shared.log("match created")
```

### 3. Performance Monitoring

**Trace important user flows:**
- App startup
- Sign in/sign up
- Profile loading
- Match creation
- Message sending
- Image uploads
- In-app purchases

**Add meaningful metrics:**

```swift
CrashlyticsManager.shared.startTrace(name: "upload_profile_photo")

// ... upload code ...

CrashlyticsManager.shared.incrementMetric(
    traceName: "upload_profile_photo",
    metric: "bytes_uploaded",
    by: imageSize
)

CrashlyticsManager.shared.setTraceAttribute(
    traceName: "upload_profile_photo",
    key: "image_resolution",
    value: "\(width)x\(height)"
)

CrashlyticsManager.shared.stopTrace(name: "upload_profile_photo")
```

### 4. User Privacy

**Never log:**
- Passwords
- API keys
- Auth tokens
- Full email addresses (hash or redact)
- Phone numbers
- Payment information
- Personal messages

**Do log:**
- User IDs
- Action types
- Error types
- App state
- Device information

### 5. Production vs Debug

```swift
#if DEBUG
CrashlyticsManager.shared.setUserAttribute(key: "environment", value: "debug")
// More verbose logging in debug
#else
CrashlyticsManager.shared.setUserAttribute(key: "environment", value: "production")
// Less logging in production
#endif
```

## Monitoring & Alerts

### Setup Crashlytics Alerts

1. Go to Firebase Console > Crashlytics
2. Click **Settings** (gear icon)
3. Click **"New alert"**
4. Configure:
   - Alert name: "Critical Crashes"
   - Condition: "Crash-free users falls below 99%"
   - Notification: Your email
5. Save

### Setup Performance Alerts

1. Go to Firebase Console > Performance
2. Click on a trace
3. Click **"Create alert"**
4. Configure threshold and notification
5. Save

## Troubleshooting

### Crashes Not Appearing

**Check:**
1. Firebase is initialized before any crashes
2. Run script phase is added and executed
3. App was restarted after crash
4. dSYMs are uploaded (for symbolication)
5. Wait 5-10 minutes for crashes to appear

**Console Logs:**
```bash
# Check if Crashlytics is initialized
[Firebase/Crashlytics] Version 10.x.x

# Check if crash is being sent
[Firebase/Crashlytics] Preparing to submit crash reports
```

### Missing dSYMs

Download and upload manually:

```bash
# Download from Xcode
# Window > Organizer > Archives > Download dSYMs

# Upload to Firebase
./Pods/FirebaseCrashlytics/upload-symbols \
  -gsp ./Celestia/GoogleService-Info.plist \
  -p ios path/to/dSYMs
```

### Performance Data Not Showing

**Check:**
1. Performance SDK is imported
2. Traces are started and stopped
3. App is run in release mode (debug has limitations)
4. Wait 12-24 hours for data aggregation
5. Sufficient data collected (min 50 traces)

### Network Traces Not Auto-Tracking

Performance SDK auto-tracks URLSession, but ensure:
1. Using URLSession (not third-party networking)
2. Not in debug mode
3. Not blocking auto-instrumentation

## Integration Checklist

- [ ] Firebase SDK installed (Crashlytics + Performance)
- [ ] Run script phase added for Crashlytics
- [ ] Debug symbols enabled (DWARF with dSYM)
- [ ] CrashlyticsManager integrated in app launch
- [ ] User identification added on sign in
- [ ] Error recording added to critical paths
- [ ] Performance traces added to key flows
- [ ] Test crash verified in Firebase Console
- [ ] Alerts configured
- [ ] Team notified of new monitoring

## Resources

- [Firebase Crashlytics Documentation](https://firebase.google.com/docs/crashlytics)
- [Firebase Performance Documentation](https://firebase.google.com/docs/perf-mon)
- [Crashlytics API Reference](https://firebase.google.com/docs/reference/swift/firebasecrashlytics/api/reference/Classes/Crashlytics)
- [Best Practices](https://firebase.google.com/docs/crashlytics/best-practices)

## Support

For issues with Crashlytics integration, check:
1. Firebase Console status
2. Xcode console logs
3. `CrashlyticsManager.swift` implementation
4. Firebase Support

---

**Updated:** January 2025
