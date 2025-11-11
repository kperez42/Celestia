# Push Notifications Setup Guide

Comprehensive guide for implementing and using push notifications in Celestia.

## 📋 Table of Contents

1. [Overview](#overview)
2. [Setup & Configuration](#setup--configuration)
3. [Notification Types](#notification-types)
4. [User Preferences](#user-preferences)
5. [Badge Management](#badge-management)
6. [Testing](#testing)
7. [Backend Integration](#backend-integration)
8. [Best Practices](#best-practices)

---

## Overview

Celestia's push notification system provides:
- **APNs integration** - Native iOS notifications
- **Firebase Cloud Messaging** - Cross-platform support
- **Rich notifications** - Images, actions, custom UI
- **8 notification categories** - Matches, messages, views, etc.
- **Action buttons** - Reply, view profile, open app
- **Quiet hours** - Mute notifications during sleep
- **Badge management** - Track unread counts
- **User preferences** - Granular control

---

## Setup & Configuration

### 1. Firebase Setup

#### Add Firebase to Your Project

1. **Download GoogleService-Info.plist**
   - Go to Firebase Console
   - Select your project
   - Go to Project Settings
   - Download `GoogleService-Info.plist`
   - Add to Xcode project

2. **Enable Cloud Messaging**
   ```bash
   # In Firebase Console:
   # Project Settings → Cloud Messaging → Enable
   ```

3. **Upload APNs Certificates**
   - Generate APNs certificates in Apple Developer Portal
   - Upload to Firebase Console → Cloud Messaging → APNs Certificates

### 2. Xcode Configuration

#### Update Capabilities

1. Open Xcode project
2. Select target → Signing & Capabilities
3. Add capabilities:
   - **Push Notifications**
   - **Background Modes** → Enable "Remote notifications"

#### Update Info.plist

```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>

<key>FirebaseAppDelegateProxyEnabled</key>
<false/>
```

### 3. App Initialization

#### In AppDelegate

```swift
import FirebaseCore
import FirebaseMessaging

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()

        // Initialize push notifications
        Task {
            await PushNotificationManager.shared.initialize()
        }

        return true
    }

    // Handle APNs token
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.didFailToRegisterForRemoteNotifications(withError: error)
        }
    }
}
```

#### In SwiftUI App

```swift
@main
struct CelestiaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    Task {
                        // Request notification permission
                        _ = await PushNotificationManager.shared.requestAuthorization()
                    }
                }
        }
    }
}
```

---

## Notification Types

### Available Categories

| Category | Description | Actions | Priority |
|----------|-------------|---------|----------|
| **New Match** | User got a match | View Match, View Profile | High |
| **New Message** | User received message | Reply, View Profile | High |
| **Profile View** | Someone viewed profile | View Profile | Medium |
| **Super Like** | Someone super liked | View Profile, Open App | High |
| **Premium Offer** | Premium subscription offer | Open App | Low |
| **Match Reminder** | Reminder to message match | View Match | Medium |
| **Message Reminder** | Reminder to reply | Reply | Medium |
| **General Update** | App updates/announcements | Open App | Low |

### Sending Notifications

#### New Match Notification

```swift
await NotificationService.shared.sendNewMatchNotification(
    matchId: "match_123",
    matchName: "Sarah",
    matchImageURL: URL(string: "https://example.com/sarah.jpg")
)
```

#### New Message Notification

```swift
await NotificationService.shared.sendNewMessageNotification(
    matchId: "match_123",
    senderName: "Sarah",
    message: "Hey! How's it going?",
    senderImageURL: URL(string: "https://example.com/sarah.jpg")
)
```

#### Profile View Notification

```swift
await NotificationService.shared.sendProfileViewNotification(
    viewerId: "user_456",
    viewerName: "Emma",
    viewerImageURL: URL(string: "https://example.com/emma.jpg")
)
```

#### Super Like Notification

```swift
await NotificationService.shared.sendSuperLikeNotification(
    likerId: "user_789",
    likerName: "Jessica",
    likerImageURL: URL(string: "https://example.com/jessica.jpg")
)
```

### Rich Notifications with Images

Notifications automatically include images when URL is provided:

```swift
let payload = NotificationPayload.newMatch(
    matchName: "Sarah",
    matchId: "match_123",
    imageURL: URL(string: "https://example.com/sarah.jpg")
)

await NotificationService.shared.sendNotification(payload: payload)
```

### Action Buttons

Each notification category has specific actions:

**New Match:**
- View Match → Opens match details
- View Profile → Opens user profile

**New Message:**
- Reply → Opens keyboard for quick reply
- View Profile → Opens sender's profile

**Super Like:**
- View Profile → Opens liker's profile
- Open App → Opens app to main screen

---

## User Preferences

### Accessing Preferences

```swift
let preferences = NotificationPreferences.shared

// Check if category enabled
if preferences.isEnabled(.newMatch) {
    // Send notification
}

// Check quiet hours
if preferences.isInQuietHours() {
    // Don't send notification
}
```

### SwiftUI Preferences Screen

```swift
NavigationLink("Notification Settings") {
    NotificationPreferencesView()
}
```

### Quiet Hours

Automatically mute notifications during specified hours:

```swift
// Enable quiet hours
preferences.quietHoursEnabled = true
preferences.quietHoursStart = // 22:00 (10 PM)
preferences.quietHoursEnd = // 08:00 (8 AM)

// Check if in quiet hours
if preferences.isInQuietHours() {
    print("Currently in quiet hours")
}
```

Quiet hours support overnight periods (e.g., 22:00 to 08:00).

### User-Facing Settings

Users can control:
- ✅ New Matches
- ✅ New Messages
- ✅ Profile Views
- ✅ Super Likes
- ✅ Premium Offers
- ✅ General Updates
- ✅ Match Reminders
- ✅ Message Reminders
- ✅ Quiet Hours
- ✅ Sound & Vibration
- ✅ Preview in notifications

---

## Badge Management

### Badge Categories

```swift
let badgeManager = BadgeManager.shared

// Update counts
badgeManager.setUnreadMessages(5)
badgeManager.setNewMatches(3)
badgeManager.setProfileViews(2)

// Total badge: 10 (5 + 3 + 2)
print(badgeManager.totalBadgeCount) // 10
```

### Increment Badges

```swift
// When new message arrives
badgeManager.incrementUnreadMessages()

// When new match happens
badgeManager.incrementNewMatches()

// When someone views profile
badgeManager.incrementProfileViews()
```

### Clear Badges

```swift
// Clear all
badgeManager.clearAll()

// Clear specific category
badgeManager.clear(.messages)
badgeManager.clear(.matches)
badgeManager.clear(.profileViews)
```

### SwiftUI Badge View

```swift
TabView {
    MessagesView()
        .tabItem {
            Label("Messages", systemImage: "message.fill")
        }
        .badge(badgeManager.unmatchedMessagesCount)

    MatchesView()
        .tabItem {
            Label("Matches", systemImage: "heart.fill")
        }
        .badge(badgeManager.newMatchesCount)
}
```

---

## Testing

### Local Notifications (Development)

The system automatically sends local notifications in DEBUG mode:

```swift
#if DEBUG
try await manager.scheduleLocalNotification(
    title: "New Match!",
    body: "You and Sarah liked each other!",
    category: .newMatch,
    imageURL: URL(string: "https://example.com/sarah.jpg")
)
#endif
```

### Test All Notification Types

```swift
#if DEBUG
struct NotificationTestView: View {
    var body: some View {
        List {
            Button("Test New Match") {
                Task {
                    await NotificationService.shared.exampleNewMatch()
                }
            }

            Button("Test New Message") {
                Task {
                    await NotificationService.shared.exampleNewMessage()
                }
            }

            Button("Test Profile View") {
                Task {
                    await NotificationService.shared.sendProfileViewNotification(
                        viewerId: "test_123",
                        viewerName: "Emma",
                        viewerImageURL: nil
                    )
                }
            }
        }
        .navigationTitle("Test Notifications")
    }
}
#endif
```

### Simulator Testing

**Note:** Push notifications don't work in Simulator for remote notifications, but local notifications work.

```swift
// Test local notification in simulator
Task {
    try await PushNotificationManager.shared.scheduleLocalNotification(
        title: "Test",
        body: "This works in simulator!",
        category: .newMatch,
        delay: 5 // 5 seconds delay
    )
}
```

### Physical Device Testing

1. **Run on device** (not simulator)
2. **Allow notifications** when prompted
3. **Background the app**
4. **Send test notification** from Firebase Console or backend

---

## Backend Integration

### Sending Remote Notifications

Your backend should send notifications to FCM:

#### Payload Format

```json
{
  "to": "FCM_TOKEN_HERE",
  "notification": {
    "title": "New Match!",
    "body": "You and Sarah liked each other!",
    "image": "https://example.com/sarah.jpg",
    "sound": "default",
    "badge": "1"
  },
  "data": {
    "type": "new_match",
    "match_id": "match_123",
    "category": "NEW_MATCH"
  },
  "apns": {
    "payload": {
      "aps": {
        "category": "NEW_MATCH",
        "thread-id": "match_123"
      }
    }
  }
}
```

#### Node.js Example

```javascript
const admin = require('firebase-admin');

async function sendMatchNotification(userId, matchName, matchId, imageUrl) {
  const message = {
    token: userFCMToken,
    notification: {
      title: "It's a Match! 🎉",
      body: `You and ${matchName} liked each other!`,
      imageUrl: imageUrl
    },
    data: {
      type: 'new_match',
      match_id: matchId,
      category: 'NEW_MATCH'
    },
    apns: {
      payload: {
        aps: {
          category: 'NEW_MATCH',
          sound: 'default',
          badge: 1
        }
      }
    }
  };

  await admin.messaging().send(message);
}
```

#### Python Example

```python
from firebase_admin import messaging

def send_match_notification(user_id, match_name, match_id, image_url):
    message = messaging.Message(
        token=user_fcm_token,
        notification=messaging.Notification(
            title="It's a Match! 🎉",
            body=f"You and {match_name} liked each other!",
            image=image_url
        ),
        data={
            'type': 'new_match',
            'match_id': match_id,
            'category': 'NEW_MATCH'
        },
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(
                    category='NEW_MATCH',
                    sound='default',
                    badge=1
                )
            )
        )
    )

    messaging.send(message)
```

### Token Management

#### Store User Tokens

When user signs in:

```swift
// Get tokens
let fcmToken = PushNotificationManager.shared.fcmToken
let apnsToken = PushNotificationManager.shared.apnsToken

// Send to your backend
await api.updateUserTokens(
    userId: user.id,
    fcmToken: fcmToken,
    apnsToken: apnsToken
)
```

#### Backend Storage

```javascript
// Store in database
await db.collection('users').doc(userId).update({
  fcm_token: fcmToken,
  apns_token: apnsToken,
  updated_at: admin.firestore.FieldValue.serverTimestamp()
});
```

---

## Best Practices

### 1. Timing

**Good Times to Send:**
- ✅ New match: Immediately
- ✅ New message: Immediately (unless in quiet hours)
- ✅ Profile view: Batched (max once per hour)
- ✅ Match reminder: 24 hours after match if no message
- ✅ Message reminder: 24 hours after last message

**Avoid:**
- ❌ Late night (respect quiet hours)
- ❌ Too frequent (causes notification fatigue)
- ❌ Low-value notifications

### 2. Personalization

```swift
// Good: Personalized
"Sarah sent you a message: 'Hey! How's it going?'"

// Bad: Generic
"You have a new message"
```

### 3. Images

Always include profile images when available:

```swift
await NotificationService.shared.sendNewMatchNotification(
    matchId: matchId,
    matchName: name,
    matchImageURL: profileImageURL // ✅ Include image
)
```

### 4. Action Buttons

Provide relevant actions:

```swift
// New message: Quick reply
- Reply (text input)
- View Profile

// New match: Engage
- View Match
- View Profile
```

### 5. Respect Preferences

Always check user preferences:

```swift
if !preferences.isEnabled(.profileView) {
    return // Don't send
}

if preferences.isInQuietHours() {
    return // Wait until morning
}
```

### 6. Badge Management

Keep badges accurate:

```swift
// When user reads messages
badgeManager.clear(.messages)

// When user views matches
badgeManager.clear(.matches)

// On app launch
badgeManager.clearAll() // If showing all content
```

### 7. Analytics

Track notification performance:

```swift
// When sent
AnalyticsManager.shared.logEvent(.notificationSent, parameters: [
    "category": "new_match",
    "match_id": matchId
])

// When opened
AnalyticsManager.shared.logEvent(.notificationOpened, parameters: [
    "category": "new_match",
    "action": "view_match"
])
```

---

## Notification Frequency Guidelines

### High Priority (Immediate)
- New matches
- New messages
- Super likes

### Medium Priority (Batched)
- Profile views (max 1/hour)
- Match reminders (24 hours)
- Message reminders (24 hours)

### Low Priority (Weekly)
- Premium offers
- General updates

---

## Troubleshooting

### Notifications Not Appearing

1. **Check Authorization**
```swift
let status = await UNUserNotificationCenter.current().notificationSettings()
print("Authorization: \(status.authorizationStatus)")
```

2. **Check Preferences**
```swift
if preferences.isEnabled(.newMatch) {
    print("Match notifications enabled")
}
```

3. **Check Quiet Hours**
```swift
if preferences.isInQuietHours() {
    print("Currently in quiet hours")
}
```

4. **Check FCM Token**
```swift
if let token = PushNotificationManager.shared.fcmToken {
    print("FCM Token: \(token)")
} else {
    print("No FCM token available")
}
```

### Images Not Showing

- ✅ Use HTTPS URLs (not HTTP)
- ✅ Ensure images are publicly accessible
- ✅ Keep image size reasonable (< 1MB)
- ✅ Use common formats (JPG, PNG)

### Actions Not Working

- ✅ Verify category identifier matches
- ✅ Check action identifier in handler
- ✅ Ensure foreground option is set

---

## Security Considerations

### Token Security

- ✅ Store tokens securely in backend
- ✅ Use HTTPS for API calls
- ✅ Validate tokens before sending
- ✅ Delete tokens on logout

### Content Privacy

- ✅ Respect `showPreview` setting
- ✅ Don't include sensitive info in notifications
- ✅ Use end-to-end encryption for messages

### Rate Limiting

- ✅ Limit notification frequency per user
- ✅ Prevent spam/abuse
- ✅ Implement server-side throttling

---

## Resources

- [APNs Documentation](https://developer.apple.com/documentation/usernotifications)
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [UNUserNotificationCenter](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter)
- [Rich Notifications Guide](https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension)

---

## Support

For issues:
1. Check this guide
2. Review logs: `Logger.shared.minimumLogLevel = .debug`
3. Test with local notifications first
4. Verify Firebase configuration
5. Check Firebase Console for delivery errors
