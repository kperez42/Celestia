# Deep Linking & Universal Links Setup Guide

This guide covers the complete setup for Deep Linking and Universal Links in Celestia.

## 📋 Table of Contents

1. [Overview](#overview)
2. [Universal Links Setup](#universal-links-setup)
3. [URL Scheme Setup](#url-scheme-setup)
4. [Deep Link Routes](#deep-link-routes)
5. [App Integration](#app-integration)
6. [Testing](#testing)
7. [Troubleshooting](#troubleshooting)

---

## Overview

Celestia supports two types of deep linking:

### Universal Links (Recommended)
- Format: `https://celestia.app/...`
- Works seamlessly from web browsers and other apps
- Opens app directly without browser redirect
- Better user experience and SEO

### URL Scheme (Fallback)
- Format: `celestia://...`
- Works when Universal Links are not configured
- Useful for testing and development

---

## Universal Links Setup

### 1. Server Configuration

Upload the `apple-app-site-association` file to your web server:

**File Location:**
```
https://celestia.app/.well-known/apple-app-site-association
https://celestia.app/apple-app-site-association
```

**Important Requirements:**
- Must be served over HTTPS
- Content-Type: `application/json`
- No file extension
- Must be accessible without authentication

**Update TEAM_ID:**
```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "YOUR_TEAM_ID.com.celestia.app",
        "paths": ["/join/*", "/profile/*", ...]
      }
    ]
  }
}
```

Replace `YOUR_TEAM_ID` with your Apple Developer Team ID (found in Apple Developer Portal).

### 2. Xcode Configuration

The entitlements file (`Celestia.entitlements`) has been updated with:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:celestia.app</string>
    <string>applinks:www.celestia.app</string>
</array>
```

**Enable in Xcode:**
1. Select Celestia target
2. Go to "Signing & Capabilities"
3. Verify "Associated Domains" capability is enabled
4. Verify domains are listed:
   - `applinks:celestia.app`
   - `applinks:www.celestia.app`

### 3. Apple Developer Portal

1. Go to [developer.apple.com](https://developer.apple.com)
2. Select your App ID (com.celestia.app)
3. Enable "Associated Domains" capability
4. Save and regenerate provisioning profiles

---

## URL Scheme Setup

### Info.plist Configuration

Add the following to your `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.celestia.app</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>celestia</string>
        </array>
    </dict>
</array>
```

---

## Deep Link Routes

### Universal Links

| Route | URL | Purpose |
|-------|-----|---------|
| Home | `https://celestia.app/` | App home screen |
| Referral | `https://celestia.app/join/CODE` | Referral signup |
| Profile | `https://celestia.app/profile/USER_ID` | View user profile |
| Match | `https://celestia.app/match/MATCH_ID` | View match details |
| Message | `https://celestia.app/message/MATCH_ID` | Open conversation |
| Email Verify | `https://celestia.app/verify-email?token=TOKEN` | Verify email |
| Reset Password | `https://celestia.app/reset-password?token=TOKEN` | Reset password |
| Upgrade | `https://celestia.app/upgrade` | Premium upgrade |
| Settings | `https://celestia.app/settings` | App settings |
| Notifications | `https://celestia.app/notifications` | Notifications |

### URL Scheme (Fallback)

| Route | URL | Purpose |
|-------|-----|---------|
| Home | `celestia://home` | App home screen |
| Referral | `celestia://join?code=CODE` | Referral signup |
| Profile | `celestia://profile?id=USER_ID` | View user profile |
| Match | `celestia://match?id=MATCH_ID` | View match details |
| Message | `celestia://message?id=MATCH_ID` | Open conversation |
| Upgrade | `celestia://upgrade` | Premium upgrade |
| Settings | `celestia://settings` | App settings |
| Notifications | `celestia://notifications` | Notifications |

---

## App Integration

### 1. App Delegate / Scene Delegate

The `DeepLinkRouter` provides integration methods:

**For URL Schemes (AppDelegate):**
```swift
func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any]
) -> Bool {
    return DeepLinkRouter.shared.application(app, open: url, options: options)
}
```

**For Universal Links (SceneDelegate):**
```swift
func scene(
    _ scene: UIScene,
    continue userActivity: NSUserActivity
) {
    _ = DeepLinkRouter.shared.scene(scene, continue: userActivity)
}
```

### 2. SwiftUI Integration

In your main `App` struct:

```swift
@main
struct CelestiaApp: App {
    @StateObject private var router = DeepLinkRouter.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(router)
                .handleDeepLinks() // Handle deep links
                .onChange(of: router.currentDeepLink) { deepLink in
                    // Navigate based on deep link
                    handleNavigation(deepLink)
                }
        }
    }
}
```

### 3. Navigation Handling

Handle navigation in your root view:

```swift
func handleNavigation(_ deepLink: DeepLink?) {
    guard let deepLink = deepLink else { return }

    switch deepLink {
    case .home:
        navigationPath = []

    case .profile(let userId):
        navigationPath = [.profile(userId)]

    case .match(let matchId):
        navigationPath = [.matches, .matchDetail(matchId)]

    case .message(let matchId):
        navigationPath = [.messages, .conversation(matchId)]

    case .referral(let code):
        // Show signup with pre-filled referral code
        showSignup(with: code)

    case .upgrade:
        showPremiumUpgrade()

    case .settings:
        navigationPath = [.settings]

    // ... handle other routes
    }
}
```

### 4. Referral Link Integration

The deep link router automatically stores referral codes:

```swift
// Check for pending referral code during signup
if let code = DeepLinkRouter.shared.pendingReferralCode {
    // Use the referral code
    signUp(withReferralCode: code)

    // Clear it after use
    DeepLinkRouter.shared.clearPendingReferralCode()
}
```

### 5. Email Verification Integration

Update `AuthService` to handle email verification:

```swift
extension AuthService {
    func verifyEmail(withToken token: String) async throws {
        // Call your backend API to verify the token
        // Example:
        let url = URL(string: "https://api.celestia.app/verify-email")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["token": token]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CelestiaError.emailVerificationFailed
        }

        // Reload current user to get updated email verification status
        try await Auth.auth().currentUser?.reload()
        await loadUserData()
    }
}
```

---

## Testing

### Test Universal Links

#### Method 1: Safari (iOS Simulator/Device)
1. Open Notes app
2. Type: `https://celestia.app/join/TESTCODE`
3. Long press the link
4. Tap "Open in Celestia"

#### Method 2: Command Line (Simulator)
```bash
xcrun simctl openurl booted "https://celestia.app/join/TESTCODE"
```

#### Method 3: Terminal (Device)
```bash
# Open URL on connected device
xcrun devicectl device process launch --device <DEVICE_ID> \
  --url "https://celestia.app/join/TESTCODE"
```

### Test URL Scheme

#### Simulator
```bash
xcrun simctl openurl booted "celestia://join?code=TESTCODE"
```

#### Device
```bash
xcrun devicectl device process launch --device <DEVICE_ID> \
  --url "celestia://join?code=TESTCODE"
```

### Verify Server Configuration

Test if your `apple-app-site-association` file is accessible:

```bash
curl -v https://celestia.app/.well-known/apple-app-site-association
```

Should return:
- HTTP 200 status
- Content-Type: application/json
- Valid JSON content

### Apple CDN Validation

Apple caches the association file on their CDN. Check if Apple can access it:

```bash
# This may take up to 24 hours after first upload
curl https://app-site-association.cdn-apple.com/a/v1/celestia.app
```

---

## Generating Deep Links

Use the `DeepLinkRouter` helper methods:

```swift
// Generate referral link
if let url = DeepLinkRouter.shared.generateReferralLink(code: "ABC123") {
    // Share: https://celestia.app/join/ABC123
    shareURL(url)
}

// Generate profile link
if let url = DeepLinkRouter.shared.generateProfileLink(userId: user.id) {
    // Share: https://celestia.app/profile/USER_ID
    shareURL(url)
}

// Generate email verification link (server-side)
if let url = DeepLinkRouter.shared.generateEmailVerificationLink(token: token) {
    // Send via email: https://celestia.app/verify-email?token=TOKEN
    sendEmail(verificationURL: url)
}
```

---

## Authentication-Protected Routes

Some deep links require authentication:

- Profile views
- Match details
- Messages
- Settings
- Upgrade

The router automatically handles this:
- If user is not authenticated, the deep link is stored
- After successful login/signup, the pending deep link is processed
- Call `DeepLinkRouter.shared.processPendingDeepLink()` after authentication

```swift
// After successful login
await authService.signIn(withEmail: email, password: password)

// Process any pending deep link
DeepLinkRouter.shared.processPendingDeepLink()
```

---

## Troubleshooting

### Universal Links Not Working

**1. Verify Server Configuration**
```bash
curl -v https://celestia.app/.well-known/apple-app-site-association
```

**2. Check File Format**
- Must be valid JSON
- Must use HTTPS
- No redirects allowed
- Content-Type must be `application/json` or `application/pkcs7-mime`

**3. Verify Team ID**
- Open Xcode → Signing & Capabilities
- Check your Team ID matches the one in `apple-app-site-association`

**4. Clear iOS Cache**
```swift
// Delete and reinstall the app
// OR
// Reset iOS Simulator: Device → Erase All Content and Settings
```

**5. Wait for CDN Update**
Apple's CDN can take up to 24 hours to update. Be patient!

### URL Scheme Not Working

**1. Verify Info.plist**
Check that `CFBundleURLSchemes` contains `celestia`

**2. Test with Command Line**
```bash
xcrun simctl openurl booted "celestia://home"
```

**3. Check Logs**
Enable logging in `DeepLinkRouter` to see what's happening:
```swift
Logger.shared.minimumLogLevel = .debug
```

### Deep Link Opens Safari Instead of App

This usually means:
1. Universal Links are not properly configured
2. User previously chose "Open in Safari" for your domain
3. Server configuration issue

**Fix:**
- Long press the link and select "Open in Celestia"
- Or use URL scheme as fallback: `celestia://...`

### Referral Code Not Applied

**Debug Steps:**
1. Check if code is being stored:
```swift
print("Pending code:", DeepLinkRouter.shared.pendingReferralCode ?? "none")
```

2. Ensure you're calling `clearPendingReferralCode()` after use

3. Check UserDefaults:
```swift
UserDefaults.standard.string(forKey: "pendingReferralCode")
```

---

## Analytics & Monitoring

All deep link events are automatically tracked:

```swift
// Automatically logged events:
- deep_link_home
- deep_link_profile
- deep_link_match
- deep_link_message
- deep_link_referral
- deep_link_email_verification
- deep_link_upgrade
- deep_link_settings
- deep_link_unknown
- deep_link_parse_failed
- referral_link_opened
- email_verification_link_opened
- password_reset_link_opened
```

View analytics in:
- Firebase Console → Analytics → Events
- Firebase Console → Crashlytics → Custom Logs

---

## Production Checklist

Before launching Universal Links:

- [ ] `apple-app-site-association` uploaded to server
- [ ] File accessible at both:
  - `https://celestia.app/.well-known/apple-app-site-association`
  - `https://celestia.app/apple-app-site-association`
- [ ] Team ID updated in association file
- [ ] HTTPS enabled (no mixed content)
- [ ] Associated Domains capability enabled in Xcode
- [ ] Associated Domains enabled in Apple Developer Portal
- [ ] Provisioning profiles regenerated
- [ ] Tested on physical device
- [ ] Tested from Safari, Notes, Messages
- [ ] Analytics tracking verified
- [ ] Error handling tested
- [ ] Authentication flow tested with protected routes

---

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Enable debug logging: `Logger.shared.minimumLogLevel = .debug`
3. Check Crashlytics logs for deep link events
4. Review Apple's [Universal Links documentation](https://developer.apple.com/ios/universal-links/)

---

## References

- [Apple Universal Links Documentation](https://developer.apple.com/ios/universal-links/)
- [Supporting Universal Links](https://developer.apple.com/library/archive/documentation/General/Conceptual/AppSearch/UniversalLinks.html)
- [Branch.io Deep Linking Guide](https://help.branch.io/developers-hub/docs/ios-universal-links)
