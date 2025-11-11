# Tier 2 Improvements Guide

This guide covers all Tier 2 improvements implemented in Celestia: Memory Leak Detection, Feature Flags, Advanced Analytics, and Offline Mode Support.

## 📋 Table of Contents

1. [Memory Leak Detection & Profiling](#memory-leak-detection--profiling)
2. [Feature Flags System](#feature-flags-system)
3. [Advanced Analytics](#advanced-analytics)
4. [Offline Mode Support](#offline-mode-support)

---

## 1. Memory Leak Detection & Profiling

### Overview

Comprehensive memory management system that detects leaks, profiles memory usage, and identifies performance bottlenecks.

### Components

#### MemoryLeakDetector

Automatically tracks object lifecycles and reports potential memory leaks.

**Usage:**

```swift
// Track an object
MemoryLeakDetector.shared.track(self, name: "MyViewController")

// Expect deallocation
MemoryLeakDetector.shared.expectDeallocation(of: viewController, within: 5.0)

// Check for leaks manually
MemoryLeakDetector.shared.checkForLeaks()

// Track SwiftUI views
MyView()
    .trackMemoryLeaks(name: "MyView")
```

**Configuration:**

```swift
// Set warning/error thresholds
MemoryLeakDetector.shared.warningThreshold = 10.0 // seconds
MemoryLeakDetector.shared.errorThreshold = 30.0
```

**UIViewController Automatic Tracking:**

```swift
// In AppDelegate
UIViewController.enableMemoryLeakTracking()
```

#### MemoryProfiler

Profiles memory usage and performance metrics.

**Usage:**

```swift
// Take snapshot
MemoryProfiler.shared.takeSnapshot(label: "After Login")

// Get current usage
let usage = MemoryProfiler.shared.currentMemoryUsage()
print("Memory used: \(usage.usedMB) MB")

// Profile a code block
let result = MemoryProfiler.shared.profile(label: "Data Processing") {
    // Your code here
    return processData()
}

// Profile async code
let result = await MemoryProfiler.shared.profileAsync(label: "API Call") {
    return try await fetchData()
}

// Generate report
let report = MemoryProfiler.shared.generateReport()
print("Average: \(report.averageMemoryMB) MB")
print("Peak: \(report.peakMemoryMB) MB")
```

**SwiftUI Integration:**

```swift
struct SettingsView: View {
    var body: some View {
        NavigationLink("Memory Profiler") {
            MemoryProfileView()
        }
    }
}
```

### Instruments Integration

The profiler uses `os_signpost` for Instruments integration:

```swift
// Profiled blocks appear in Instruments under:
// Profile → Instruments → Points of Interest
```

### Best Practices

1. **Enable in DEBUG only** - Performance tracking has overhead
2. **Track long-lived objects** - ViewControllers, Managers, Services
3. **Expect deallocation** - When dismissing views or leaving screens
4. **Monitor warnings** - Address any leak warnings immediately
5. **Review reports** - Periodically check memory reports for trends

### Common Memory Leak Patterns

#### Retain Cycles in Closures

❌ **Bad:**
```swift
service.fetchData { data in
    self.processData(data) // Strong reference to self
}
```

✅ **Good:**
```swift
service.fetchData { [weak self] data in
    self?.processData(data)
}
```

#### Delegate Retain Cycles

❌ **Bad:**
```swift
protocol MyDelegate {
    func didUpdate()
}

class MyClass {
    var delegate: MyDelegate? // Strong reference
}
```

✅ **Good:**
```swift
class MyClass {
    weak var delegate: MyDelegate?
}
```

---

## 2. Feature Flags System

### Overview

Remote configuration system for A/B testing, gradual rollouts, and feature toggling using Firebase Remote Config.

### Setup

```swift
// Initialize in AppDelegate
Task {
    await FeatureFlagManager.shared.initialize()
}
```

### Available Flags

See `FeatureFlag` enum for all flags. Key flags include:

- **User Features:** `enablePremiumFeatures`, `enableSuperLike`, `enableRewind`
- **Discovery:** `maxDailyLikes`, `discoveryRadius`
- **Social:** `enableVideoChat`, `enableVoiceNotes`
- **Safety:** `enableContentModeration`, `enablePhotoVerification`
- **Monetization:** `premiumMonthlyPrice`, `premiumYearlyPrice`
- **Experimental:** `enableNewMatchAlgorithm`, `enableDarkMode`

### Usage

#### Check Boolean Flags

```swift
if FeatureFlagManager.shared.isEnabled(.enableSuperLike) {
    showSuperLikeButton()
}
```

#### Get Numeric Values

```swift
let maxLikes = FeatureFlagManager.shared.intValue(.maxDailyLikes)
let price = FeatureFlagManager.shared.doubleValue(.premiumMonthlyPrice)
```

#### SwiftUI Integration

```swift
// Show view conditionally
SuperLikeButton()
    .featureFlag(.enableSuperLike)

// Show different views
VStack {
    Text("Match Algorithm")
}
.featureFlag(.enableNewMatchAlgorithm,
    if: {
        NewMatchAlgorithmView()
    },
    else: {
        ClassicMatchAlgorithmView()
    }
)
```

#### Property Wrapper

```swift
struct MyView: View {
    @FeatureFlagged(flag: .enableSuperLike)
    var isSuperLikeEnabled: Bool

    var body: some View {
        if isSuperLikeEnabled {
            SuperLikeButton()
        }
    }
}
```

### Testing with Local Overrides

```swift
// Set override for testing
FeatureFlagManager.shared.setOverride(.enableSuperLike, value: true)

// Clear override
FeatureFlagManager.shared.clearOverride(.enableSuperLike)

// Clear all overrides
FeatureFlagManager.shared.clearAllOverrides()
```

### Debug UI

```swift
#if DEBUG
NavigationLink("Feature Flags") {
    FeatureFlagDebugView()
}
#endif
```

### Firebase Remote Config Setup

1. **Add parameters in Firebase Console:**
   ```
   enable_super_like: true
   max_daily_likes: 100
   premium_monthly_price: 9.99
   ```

2. **Set conditions for A/B testing:**
   - 50% of users: `enable_new_match_algorithm = true`
   - 50% of users: `enable_new_match_algorithm = false`

3. **Configure fetch intervals:**
   - Development: Instant (0 seconds)
   - Production: 1 hour (3600 seconds)

### Best Practices

1. **Always provide defaults** - Flags work without remote config
2. **Use meaningful names** - Clear, descriptive flag names
3. **Document flags** - Add description for each flag
4. **Test both states** - Test feature enabled AND disabled
5. **Track usage** - Analytics automatically track flag checks
6. **Gradual rollout** - Start with small percentage, increase gradually
7. **Monitor metrics** - Watch conversion rates during rollout

---

## 3. Advanced Analytics

### Overview

Comprehensive analytics system integrating Firebase Analytics, Crashlytics, and custom tracking.

### Setup

```swift
// Analytics automatically starts with app
// Set user ID after authentication
AnalyticsManager.shared.setUserId(user.id)
```

### Event Tracking

#### Standard Events

```swift
// Authentication
AnalyticsManager.shared.logEvent(.signUpCompleted)
AnalyticsManager.shared.logEvent(.signInCompleted)

// Discovery
AnalyticsManager.shared.trackSwipe(action: .like, userId: profileId)
AnalyticsManager.shared.trackMatch(matchId: matchId, userId: userId)

// Messaging
AnalyticsManager.shared.trackMessageSent(
    matchId: matchId,
    messageLength: text.count,
    hasMedia: false
)

// E-commerce
AnalyticsManager.shared.trackPurchase(
    transactionId: "txn_123",
    productId: "premium_monthly",
    productName: "Premium Monthly",
    price: 9.99
)
```

#### Custom Events

```swift
AnalyticsManager.shared.logEvent(.featureUsed, parameters: [
    "feature": "photo_upload",
    "success": true
])
```

### User Properties

```swift
// Set single property
AnalyticsManager.shared.setUserProperty("premium", forName: "user_tier")

// Set multiple properties
AnalyticsManager.shared.setUserProperties([
    "gender": "male",
    "age_group": "25-34",
    "location": "San Francisco"
])

// Track user progress
AnalyticsManager.shared.trackUserProgress(
    matchCount: 10,
    messageCount: 50,
    swipeCount: 200
)
```

### Funnel Tracking

```swift
// Track funnel steps
AnalyticsManager.shared.trackFunnelStep(
    .signup,
    step: 1,
    stepName: "Email Entry"
)

AnalyticsManager.shared.trackFunnelStep(
    .signup,
    step: 2,
    stepName: "Profile Creation"
)

// Track completion
AnalyticsManager.shared.trackFunnelCompletion(.signup, duration: 120.0)

// Track abandonment
AnalyticsManager.shared.trackFunnelAbandonment(
    .signup,
    step: 2,
    reason: "Validation Error"
)
```

### Screen Tracking

```swift
AnalyticsManager.shared.logScreenView("Home", screenClass: "SwipeView")
```

### Performance Tracking

```swift
AnalyticsManager.shared.trackPerformance(
    operation: "image_upload",
    duration: 2.5,
    success: true
)
```

### A/B Testing

```swift
AnalyticsManager.shared.trackExperimentExposure(
    experimentName: "new_match_algorithm",
    variant: "variant_a"
)
```

### Error Tracking

```swift
AnalyticsManager.shared.trackError(
    error,
    context: "profile_update"
)
```

### Available Funnels

- `signup` - User registration flow
- `onboarding` - Initial app onboarding
- `matching` - Discovery to match flow
- `messaging` - First message flow
- `premiumPurchase` - Premium upgrade flow
- `referral` - Referral completion flow

### Key Metrics to Track

1. **User Acquisition**
   - Sign ups
   - Referral conversions
   - Install source

2. **Engagement**
   - Daily/Weekly active users
   - Session duration
   - Swipes per session
   - Messages sent

3. **Retention**
   - Day 1, 7, 30 retention
   - Churn rate
   - Return visits

4. **Monetization**
   - Premium conversion rate
   - Revenue per user
   - Refund rate

5. **Social**
   - Match rate
   - Message response rate
   - Conversation depth

### Best Practices

1. **Track key moments** - Sign up, first match, first message, purchase
2. **Use consistent naming** - Follow snake_case convention
3. **Limit parameters** - Max 25 parameters per event
4. **Set user properties** - Helps segment users
5. **Track funnels** - Understand drop-off points
6. **Monitor performance** - Track slow operations
7. **Respect privacy** - Never track PII without consent

---

## 4. Offline Mode Support

### Overview

Comprehensive offline functionality with automatic sync when online. Queues operations and caches data for seamless offline experience.

### Components

#### OfflineManager

Manages network state and operation queue.

**Usage:**

```swift
// Check network status
if OfflineManager.shared.isOnline {
    // Perform online operation
} else {
    // Queue for later
}

// Queue operation
let operation = OfflineOperation(
    type: .sendMessage,
    data: messageData
)
OfflineManager.shared.queueOperation(operation)

// Force sync
await OfflineManager.shared.syncNow()
```

#### Data Caching

```swift
// Cache data
OfflineManager.shared.cacheData(
    user,
    key: "user_\(userId)",
    expiration: 3600 // 1 hour
)

// Get cached data
if let user = OfflineManager.shared.getCachedData(
    key: "user_\(userId)",
    type: User.self
) {
    // Use cached user
}

// Check if available
if OfflineManager.shared.isDataAvailableOffline(
    key: "user_\(userId)",
    type: User.self
) {
    // Data is cached
}
```

#### Cache Management

```swift
// Get cache size
let size = OfflineCache.shared.getCacheSize()
print("Cache size: \(size / 1024 / 1024) MB")

// Clear cache
OfflineManager.shared.clearCache()
```

### Supported Offline Operations

- **sendMessage** - Queue messages to be sent when online
- **updateProfile** - Profile updates
- **swipeAction** - Like/dislike actions
- **uploadPhoto** - Photo uploads
- **deletePhoto** - Photo deletions
- **unmatch** - Unmatch actions
- **reportUser** - User reports
- **blockUser** - Block actions

### SwiftUI Integration

```swift
struct ContentView: View {
    var body: some View {
        ZStack {
            MainContent()

            VStack {
                OfflineIndicator()
                Spacer()
            }
        }
    }
}
```

### Automatic Sync

Operations are automatically synced when:
1. Network connection is restored
2. App returns to foreground
3. User manually triggers sync
4. New operation is queued while online

### Sync Strategy

1. **Retry Logic**
   - Max 3 retry attempts per operation
   - Exponential backoff between retries
   - Failed operations remain in queue

2. **Priority**
   - Operations executed in FIFO order
   - Can implement priority queue for critical operations

3. **Conflict Resolution**
   - Last write wins for profile updates
   - Messages deduplicated by ID
   - Swipes resolved by timestamp

### Implementation Example

#### Queue Message When Offline

```swift
func sendMessage(_ text: String, to matchId: String) {
    if OfflineManager.shared.isOnline {
        // Send immediately
        Task {
            try await messageService.send(text, to: matchId)
        }
    } else {
        // Queue for later
        struct MessageData: Codable {
            let matchId: String
            let text: String
        }

        let messageData = MessageData(matchId: matchId, text: text)
        let data = try! JSONEncoder().encode(messageData)

        let operation = OfflineOperation(
            type: .sendMessage,
            data: data
        )

        OfflineManager.shared.queueOperation(operation)

        // Optimistically update UI
        addMessageToUI(text, matchId: matchId, isPending: true)
    }
}
```

#### Cache User Profiles

```swift
func fetchUserProfile(_ userId: String) async throws -> User {
    // Try cache first
    if let cached = OfflineManager.shared.getCachedData(
        key: "user_\(userId)",
        type: User.self
    ) {
        Logger.shared.debug("Using cached user profile", category: .general)
        return cached
    }

    // Fetch from network
    let user = try await userService.fetchProfile(userId)

    // Cache for offline access
    OfflineManager.shared.cacheData(
        user,
        key: "user_\(userId)",
        expiration: 3600
    )

    return user
}
```

### Best Practices

1. **Cache strategically** - Cache frequently accessed data
2. **Set appropriate expiration** - Balance freshness vs availability
3. **Handle conflicts** - Implement conflict resolution for critical data
4. **Show pending state** - Indicate queued operations in UI
5. **Limit queue size** - Prevent unbounded queue growth
6. **Clear old cache** - Remove expired cached data
7. **Test offline scenarios** - Simulate airplane mode
8. **Graceful degradation** - Disable features that require network

### Testing Offline Mode

#### Simulator

```swift
// In Settings app:
// Developer → Network Link Conditioner → Enable
// Select "100% Loss" profile
```

#### Programmatically

```swift
#if DEBUG
// Force offline mode for testing
extension OfflineManager {
    func forceOffline() {
        isOnline = false
    }

    func forceOnline() {
        isOnline = true
    }
}
#endif
```

### Monitoring

```swift
// Monitor pending operations
print("Pending operations: \(OfflineManager.shared.pendingOperations.count)")

// Monitor cache size
let cacheSize = OfflineCache.shared.getCacheSize()
print("Cache size: \(cacheSize.formattedBytes())")
```

---

## Integration Checklist

### Memory Leak Detection
- [ ] Enable UIViewController tracking in AppDelegate
- [ ] Track long-lived objects
- [ ] Add `.trackMemoryLeaks()` to critical views
- [ ] Review leak warnings in logs
- [ ] Add Memory Profiler to debug menu

### Feature Flags
- [ ] Initialize in AppDelegate
- [ ] Add flags to Firebase Remote Config
- [ ] Replace hardcoded toggles with flags
- [ ] Add debug UI for testing
- [ ] Document all flags

### Analytics
- [ ] Set user ID after authentication
- [ ] Track key events (signup, match, message, purchase)
- [ ] Set user properties
- [ ] Implement funnel tracking
- [ ] Monitor in Firebase Console

### Offline Mode
- [ ] Initialize network monitoring
- [ ] Implement operation queuing
- [ ] Add data caching
- [ ] Show offline indicator in UI
- [ ] Test offline scenarios

---

## Performance Considerations

### Memory Leak Detection
- **Impact:** Minimal in production (disabled)
- **Development:** Small overhead from tracking
- **Recommendation:** Keep enabled in DEBUG only

### Feature Flags
- **Impact:** Negligible (cached after first fetch)
- **Network:** Fetches on app start, then cached
- **Recommendation:** Use appropriate fetch intervals

### Analytics
- **Impact:** Low (events batched and sent async)
- **Network:** Minimal data usage
- **Recommendation:** Limit event parameters, batch events

### Offline Mode
- **Impact:** Depends on cache size
- **Storage:** Monitor cache size
- **Recommendation:** Set cache limits, clear old data

---

## Troubleshooting

### Memory Leaks Not Detected
- Check if `MemoryLeakDetector` is enabled (#if DEBUG)
- Verify object is being tracked
- Check threshold values
- Review logs for tracking messages

### Feature Flags Not Updating
- Check Firebase Remote Config console
- Verify fetch interval
- Check network connectivity
- Clear local overrides

### Analytics Events Not Appearing
- Wait 24 hours for processing
- Check Firebase Console debug view
- Verify event name follows convention
- Check parameter count (max 25)

### Offline Sync Failing
- Check operation data encoding
- Verify sync engine implementation
- Review error logs
- Check retry count

---

## Resources

- [Firebase Remote Config Documentation](https://firebase.google.com/docs/remote-config)
- [Firebase Analytics Documentation](https://firebase.google.com/docs/analytics)
- [Apple Memory Management Guide](https://developer.apple.com/documentation/swift/memory_management)
- [Network Framework Documentation](https://developer.apple.com/documentation/network)

---

## Support

For issues or questions:
1. Check this guide first
2. Review code comments in implementation files
3. Enable debug logging: `Logger.shared.minimumLogLevel = .debug`
4. Check Firebase Console for remote config and analytics
5. Monitor Crashlytics for errors
