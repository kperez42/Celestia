# Firestore Security Rules Guide for Celestia

This document explains advanced Firestore security rules including server-side rate limiting, which prevents client-side bypass of rate limits.

## Current Security Rules

The app already has basic security rules in `firestore.rules`. This guide extends those with additional security measures.

---

## Server-Side Rate Limiting with Firestore

**CRITICAL**: Client-side rate limiting (in `RateLimiter.swift`) can be bypassed by malicious users. Server-side rate limiting in Firestore Security Rules cannot be bypassed.

### How It Works

Firestore Security Rules can enforce rate limits using a separate `rate_limits` collection that tracks user actions.

### Implementation

#### 1. Add Rate Limits Collection

Add this to your `firestore.rules`:

```javascript
// Rate Limits Collection (for tracking user actions)
match /rate_limits/{userId} {
  // Users can read their own rate limit data
  allow read: if isOwner(userId);

  // Users can update their own rate limit counters
  // Rules below enforce limits
  allow create, update: if isOwner(userId)
    && enforceLikeRateLimit(userId)
    && enforceMessageRateLimit(userId)
    && enforceSwipeRateLimit(userId);

  // Don't allow deleting rate limits
  allow delete: if false;
}

// Helper function: Check like rate limit
function enforceLikeRateLimit(userId) {
  let rateLimitData = get(/databases/$(database)/documents/rate_limits/$(userId)).data;
  let lastReset = rateLimitData.get('likesResetAt', timestamp.value(0));
  let count = rateLimitData.get('likesCount', 0);
  let isPremium = get(/databases/$(database)/documents/users/$(userId)).data.isPremium;

  // Reset counter if 24 hours have passed
  let shouldReset = request.time > lastReset + duration.value(24, 'h');

  // Check limits
  let freeLimit = 50;
  let underLimit = isPremium || shouldReset || count < freeLimit;

  return underLimit;
}

// Helper function: Check message rate limit
function enforceMessageRateLimit(userId) {
  let rateLimitData = get(/databases/$(database)/documents/rate_limits/$(userId)).data;
  let lastReset = rateLimitData.get('messagesResetAt', timestamp.value(0));
  let count = rateLimitData.get('messagesCount', 0);

  // Reset counter if 1 hour has passed
  let shouldReset = request.time > lastReset + duration.value(1, 'h');

  // Limit: 100 messages per hour
  let underLimit = shouldReset || count < 100;

  return underLimit;
}

// Helper function: Check swipe rate limit
function enforceSwipeRateLimit(userId) {
  let rateLimitData = get(/databases/$(database)/documents/rate_limits/$(userId)).data;
  let lastReset = rateLimitData.get('swipesResetAt', timestamp.value(0));
  let count = rateLimitData.get('swipesCount', 0);
  let isPremium = get(/databases/$(database)/documents/users/$(userId)).data.isPremium;

  // Reset counter if 24 hours have passed
  let shouldReset = request.time > lastReset + duration.value(24, 'h');

  // Check limits
  let freeLimit = 50;
  let underLimit = isPremium || shouldReset || count < freeLimit;

  return underLimit;
}
```

#### 2. Update Messages Collection Rule

Add rate limit enforcement to message creation:

```javascript
// Messages Collection (with rate limiting)
match /messages/{messageId} {
  // ... existing read rules ...

  // Enforce rate limit on message creation
  allow create: if isAuthenticated()
    && isEmailVerified()
    && request.resource.data.senderId == request.auth.uid
    && isValidString(request.resource.data.text, 1, 1000)
    && request.resource.data.timestamp == request.time
    && checkAndIncrementMessageRateLimit();

  // ... existing update/delete rules ...
}

// Helper to check and increment message rate limit
function checkAndIncrementMessageRateLimit() {
  let userId = request.auth.uid;
  let rateLimitPath = /databases/$(database)/documents/rate_limits/$(userId);

  // Check if rate limit document exists
  let exists = exists(rateLimitPath);

  // If doesn't exist, allow (will be created)
  // If exists, check limit
  return !exists || enforceMessageRateLimit(userId);
}
```

#### 3. Rate Limit Document Structure

```javascript
{
  "rate_limits/user_id_123": {
    "likesCount": 45,
    "likesResetAt": Timestamp,
    "messagesCount": 23,
    "messagesResetAt": Timestamp,
    "swipesCount": 30,
    "swipesResetAt": Timestamp,
    "reportsCount": 2,
    "reportsResetAt": Timestamp
  }
}
```

#### 4. Client-Side Integration

Update Swift code to increment rate limit counters:

```swift
// In SwipeService.swift
func sendLike(fromUserId: String, toUserId: String) async throws {
    // ... existing validation ...

    // Increment rate limit counter
    try await updateRateLimitCounter(userId: fromUserId, action: "likes")

    // ... rest of function ...
}

private func updateRateLimitCounter(userId: String, action: String) async throws {
    let now = Date()
    let resetTime = Calendar.current.date(byAdding: .day, value: 1, to: now)!

    let data: [String: Any] = [
        "\(action)Count": FieldValue.increment(Int64(1)),
        "\(action)ResetAt": Timestamp(date: resetTime)
    ]

    try await Firestore.firestore()
        .collection("rate_limits")
        .document(userId)
        .setData(data, merge: true)
}
```

---

## Advanced Security Rules

### 1. Prevent Mass Operations

Limit the number of documents a user can create in a short time:

```javascript
// Add to helper functions
function recentCreationCount(userId, collection) {
  // This requires server-side tracking
  // Consider using Cloud Functions to track creation rates
  return true; // Placeholder
}
```

### 2. Content Length Validation

Already implemented in current rules:

```javascript
function isValidString(text, minLength, maxLength) {
  return text is string && text.size() >= minLength && text.size() <= maxLength;
}
```

Used in messages:

```javascript
&& isValidString(request.resource.data.text, 1, 1000)
```

### 3. Prevent Timestamp Manipulation

Already implemented:

```javascript
&& request.resource.data.timestamp == request.time
```

This ensures clients can't fake timestamps.

### 4. Prevent Premium Status Manipulation

Add validation to prevent users from setting premium status client-side:

```javascript
// In users update rule
allow update: if isOwner(userId)
  && isEmailVerified()
  && request.resource.data.id == resource.data.id
  && request.resource.data.email == resource.data.email
  // Prevent changing premium status client-side
  && request.resource.data.isPremium == resource.data.isPremium;
```

**Note**: Premium status should ONLY be updated by backend API or Cloud Functions after receipt validation.

### 5. Prevent Stat Manipulation

Prevent users from artificially inflating their stats:

```javascript
// In users update rule
allow update: if isOwner(userId)
  && isEmailVerified()
  // Prevent stat manipulation
  && request.resource.data.matchCount == resource.data.matchCount
  && request.resource.data.profileViews == resource.data.profileViews
  && request.resource.data.likes == resource.data.likes;
```

Stats should be updated via Cloud Functions or backend API.

---

## Cloud Functions for Enhanced Security

For maximum security, use Cloud Functions to handle critical operations:

### 1. Match Creation Function

```javascript
exports.createMatch = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated');
  }

  const { user1Id, user2Id } = data;

  // Verify mutual like
  const like1 = await admin.firestore()
    .collection('interests')
    .where('fromUserId', '==', user1Id)
    .where('toUserId', '==', user2Id)
    .get();

  const like2 = await admin.firestore()
    .collection('interests')
    .where('fromUserId', '==', user2Id)
    .where('toUserId', '==', user1Id)
    .get();

  if (like1.empty || like2.empty) {
    throw new functions.https.HttpsError('failed-precondition', 'Not a mutual match');
  }

  // Create match
  const match = await admin.firestore().collection('matches').add({
    user1Id,
    user2Id,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    isActive: true
  });

  // Increment match counts
  await admin.firestore().collection('users').doc(user1Id).update({
    matchCount: admin.firestore.FieldValue.increment(1)
  });

  await admin.firestore().collection('users').doc(user2Id).update({
    matchCount: admin.firestore.FieldValue.increment(1)
  });

  return { matchId: match.id };
});
```

### 2. Premium Status Update Function

```javascript
exports.updatePremiumStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated');
  }

  const { userId, tier, expirationDate } = data;

  // Only allow backend to call this
  // In production, verify this is called from your backend API
  // using admin SDK or service account

  await admin.firestore().collection('users').doc(userId).update({
    isPremium: tier !== 'none',
    subscriptionTier: tier,
    subscriptionExpiresAt: expirationDate
  });

  return { success: true };
});
```

### 3. Content Moderation Function

```javascript
exports.moderateContent = functions.firestore
  .document('messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const content = message.text;

    // Check for profanity
    if (containsProfanity(content)) {
      // Flag message
      await snap.ref.update({
        isFlagged: true,
        flagReason: 'profanity'
      });

      // Notify moderation team
      await sendModerationAlert(message);
    }
  });
```

---

## Testing Security Rules

### 1. Use Firebase Emulator

```bash
firebase emulators:start
```

### 2. Write Unit Tests

Create `firestore.rules.test.js`:

```javascript
const firebase = require('@firebase/testing');

describe('Firestore Security Rules', () => {
  it('should allow user to read their own profile', async () => {
    const db = firebase.initializeTestApp({
      auth: { uid: 'user123' }
    }).firestore();

    const profile = db.collection('users').doc('user123');
    await firebase.assertSucceeds(profile.get());
  });

  it('should deny reading other user premium status', async () => {
    const db = firebase.initializeTestApp({
      auth: { uid: 'user123' }
    }).firestore();

    const otherProfile = db.collection('users').doc('user456');
    await firebase.assertFails(otherProfile.get());
  });

  it('should enforce message rate limit', async () => {
    // Test rate limiting logic
  });
});
```

Run tests:

```bash
npm test
```

---

## Deployment

### 1. Deploy Security Rules

```bash
firebase deploy --only firestore:rules
```

### 2. Deploy Cloud Functions

```bash
firebase deploy --only functions
```

### 3. Monitor Rule Performance

Check Firebase Console > Firestore > Usage tab for:
- Rule evaluations per second
- Failed rule evaluations
- Security rule errors

---

## Best Practices

### 1. Always Verify Email

```javascript
function isEmailVerified() {
  return request.auth != null && request.auth.token.email_verified == true;
}
```

Use in all rules: `&& isEmailVerified()`

### 2. Use Server Timestamps

```javascript
// ❌ BAD - Client can fake
timestamp: Date()

// ✅ GOOD - Server timestamp
timestamp: FieldValue.serverTimestamp()
```

### 3. Validate All Inputs

```javascript
&& isValidString(request.resource.data.text, 1, 1000)
&& isValidAge(request.resource.data.age)
&& isValidEmail(request.resource.data.email)
```

### 4. Prevent Privilege Escalation

```javascript
// Prevent users from making themselves premium
&& request.resource.data.isPremium == resource.data.isPremium
```

### 5. Use Read-Only Fields

```javascript
// Fields that shouldn't change after creation
&& request.resource.data.id == resource.data.id
&& request.resource.data.email == resource.data.email
&& request.resource.data.createdAt == resource.data.createdAt
```

---

## Monitoring & Alerts

### Set Up Alerts

1. **Firebase Console** > **Firestore** > **Usage**
2. Enable alerts for:
   - High rule evaluation counts (possible attack)
   - Failed rule evaluations (buggy rules or attacks)
   - Unusual document creation rates

### Log Security Events

Use Cloud Functions to log security events:

```javascript
exports.logSecurityEvent = functions.firestore
  .document('reports/{reportId}')
  .onCreate(async (snap, context) => {
    const report = snap.data();

    // Log to Cloud Logging
    console.log('SECURITY_EVENT', {
      type: 'report_created',
      reporterId: report.reporterId,
      reportedId: report.reportedId,
      reason: report.reason,
      timestamp: new Date()
    });

    // Check if user has been reported multiple times
    const reportsCount = await admin.firestore()
      .collection('reports')
      .where('reportedId', '==', report.reportedId)
      .count()
      .get();

    if (reportsCount.data().count >= 5) {
      // Auto-ban user
      await admin.firestore().collection('users').doc(report.reportedId).update({
        isBanned: true,
        banReason: 'Multiple reports',
        bannedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
  });
```

---

## Migration Guide

### From Client-Only to Server-Side Rate Limiting

1. **Phase 1**: Deploy rate limiting Cloud Functions
2. **Phase 2**: Update client to use Cloud Functions
3. **Phase 3**: Deploy stricter Firestore rules
4. **Phase 4**: Remove client-side rate limiting (keep as UX optimization)

### Gradual Rollout

1. Start with monitoring only (log violations, don't block)
2. Enable blocking for new users only
3. Gradually enable for all users
4. Monitor error rates and adjust limits

---

## Support

- **Firebase Documentation**: https://firebase.google.com/docs/firestore/security/get-started
- **Security Rules Reference**: https://firebase.google.com/docs/firestore/security/rules-structure
- **Testing Rules**: https://firebase.google.com/docs/rules/unit-tests

---

**Last Updated**: 2025-01-12
