# Backend Security & Feature Requirements

## 🚨 CRITICAL SECURITY ISSUES

These security vulnerabilities **MUST** be fixed before launch. They represent serious risks that could lead to financial loss, legal liability, or user safety issues.

---

### 1. Server-Side Receipt Validation (P0 - CRITICAL)

**Current Issue:**
Receipt validation is done client-side only (`StoreManager.swift` lines 194-248). Users can fake premium purchases by manipulating the app.

**Risk Level:** 🔴 **CRITICAL**
- Financial loss from fake premium subscriptions
- Users can access paid features for free
- Violation of App Store guidelines

**Required Fix:**
Create Cloud Function to validate receipts with Apple's servers before granting premium access.

```javascript
// CloudFunctions/modules/receiptValidation.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

exports.validateReceipt = functions.https.onCall(async (data, context) => {
    // Verify user is authenticated
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { receiptData, productId } = data;
    const userId = context.auth.uid;

    // Validate with Apple's servers
    const appleResponse = await axios.post('https://buy.itunes.apple.com/verifyReceipt', {
        'receipt-data': receiptData,
        'password': functions.config().apple.shared_secret,
        'exclude-old-transactions': true
    });

    if (appleResponse.data.status !== 0) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid receipt');
    }

    // Verify product matches
    const transaction = appleResponse.data.latest_receipt_info[0];
    if (transaction.product_id !== productId) {
        throw new functions.https.HttpsError('invalid-argument', 'Product mismatch');
    }

    // Grant premium access in Firestore
    await admin.firestore().collection('users').doc(userId).update({
        isPremium: true,
        premiumExpiresAt: new Date(parseInt(transaction.expires_date_ms)),
        lastReceiptValidation: admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: true, expiresAt: transaction.expires_date_ms };
});
```

**Client-Side Changes:**
```swift
// In StoreManager.swift, replace client validation with:
func validatePurchase(receiptData: String, productId: String) async throws {
    let result = try await Functions.functions().httpsCallable("validateReceipt").call([
        "receiptData": receiptData,
        "productId": productId
    ])

    // Server validated - update local state
    self.isPremium = true
}
```

---

### 2. Photo Content Moderation (P0 - CRITICAL)

**Current Issue:**
Photos upload directly to Firebase Storage with no content moderation (`ImageUploadService.swift`). No checks for NSFW, violence, or inappropriate content.

**Risk Level:** 🔴 **CRITICAL**
- Legal liability for hosting illegal content
- User safety concerns (harassment, explicit content)
- App Store rejection risk
- Brand reputation damage

**Required Fix:**
Integrate ML Kit or Cloudinary AI to scan photos before making them public.

```javascript
// CloudFunctions/modules/photoModeration.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const vision = require('@google-cloud/vision');

exports.moderatePhoto = functions.storage.object().onFinalize(async (object) => {
    const filePath = object.name;

    // Only moderate profile photos
    if (!filePath.includes('/profile_photos/')) {
        return null;
    }

    const client = new vision.ImageAnnotatorClient();
    const imageUri = `gs://${object.bucket}/${filePath}`;

    try {
        // Run safe search detection
        const [result] = await client.safeSearchDetection(imageUri);
        const detections = result.safeSearchAnnotation;

        // Check for inappropriate content
        const isInappropriate =
            detections.adult === 'VERY_LIKELY' || detections.adult === 'LIKELY' ||
            detections.violence === 'VERY_LIKELY' || detections.violence === 'LIKELY';

        if (isInappropriate) {
            // Delete the photo
            const bucket = admin.storage().bucket(object.bucket);
            await bucket.file(filePath).delete();

            // Mark user's photo as rejected
            const userId = filePath.split('/')[1]; // Assuming path: profile_photos/{userId}/...
            await admin.firestore().collection('users').doc(userId).update({
                photoModerationFailed: true,
                lastModerationAttempt: admin.firestore.FieldValue.serverTimestamp()
            });

            // Send notification to user
            await admin.firestore().collection('notifications').add({
                userId: userId,
                type: 'photo_rejected',
                message: 'Your photo was removed as it violated our community guidelines.',
                timestamp: admin.firestore.FieldValue.serverTimestamp()
            });

            console.log(`Rejected inappropriate photo: ${filePath}`);
        } else {
            // Mark photo as approved
            const userId = filePath.split('/')[1];
            await admin.firestore().collection('users').doc(userId).update({
                photoApproved: true,
                lastPhotoApproval: admin.firestore.FieldValue.serverTimestamp()
            });
        }
    } catch (error) {
        console.error('Error moderating photo:', error);
    }

    return null;
});
```

**Alternative:** Use Cloudinary's AI Moderation (easier setup):
```swift
// In ImageUploadService.swift
func uploadWithModeration(_ image: UIImage) async throws -> String {
    // Upload to Cloudinary with moderation
    let cloudinaryURL = "https://api.cloudinary.com/v1_1/\(cloudName)/image/upload"

    var params: [String: Any] = [
        "file": imageData.base64EncodedString(),
        "moderation": "aws_rek:explicit,nudity",
        "upload_preset": "celestia_profiles"
    ]

    // Cloudinary will auto-reject if moderation fails
    let response = try await networkManager.upload(url: cloudinaryURL, params: params)
    return response.secureURL
}
```

---

### 3. Age Validation (P0 - CRITICAL)

**Current Issue:**
User age is calculated client-side based on device date. Users can fake their age by changing device settings.

**Risk Level:** 🔴 **CRITICAL**
- Legal liability (minors accessing adult content)
- Violation of age-restricted app requirements
- App Store rejection risk

**Required Fix:**
Store birthdate on server, calculate age server-side, validate during signup.

```javascript
// CloudFunctions/modules/ageValidation.js
exports.validateAge = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { birthdate } = data; // ISO date string
    const userId = context.auth.uid;

    // Parse birthdate
    const birthDate = new Date(birthdate);
    const today = new Date();

    // Calculate age (account for leap years)
    let age = today.getFullYear() - birthDate.getFullYear();
    const monthDiff = today.getMonth() - birthDate.getMonth();
    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
        age--;
    }

    // Validate minimum age (18+)
    if (age < 18) {
        throw new functions.https.HttpsError(
            'failed-precondition',
            'You must be 18 or older to use Celestia'
        );
    }

    // Store birthdate (encrypted) and calculated age
    await admin.firestore().collection('users').doc(userId).update({
        birthdate: birthdate,
        age: age,
        ageVerifiedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return { age: age, verified: true };
});

// Schedule daily age recalculation for all users
exports.recalculateAges = functions.pubsub.schedule('0 0 * * *').onRun(async () => {
    const usersSnapshot = await admin.firestore().collection('users').get();

    const batch = admin.firestore().batch();
    let count = 0;

    usersSnapshot.forEach(doc => {
        const birthdate = doc.data().birthdate;
        if (!birthdate) return;

        const birthDate = new Date(birthdate);
        const today = new Date();
        let age = today.getFullYear() - birthDate.getFullYear();
        const monthDiff = today.getMonth() - birthDate.getMonth();
        if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
            age--;
        }

        batch.update(doc.ref, { age: age });
        count++;

        if (count === 500) {
            // Firestore batch limit
            batch.commit();
            batch = admin.firestore().batch();
            count = 0;
        }
    });

    if (count > 0) {
        await batch.commit();
    }

    return null;
});
```

---

### 4. Rate Limiting (P0 - CRITICAL)

**Current Issue:**
No rate limiting on sensitive operations. Users can spam likes, messages, reports, or API calls.

**Risk Level:** 🔴 **CRITICAL**
- Abuse potential (spam, harassment)
- Server cost explosion
- Denial of service risk
- Poor user experience for victims

**Required Fix:**
Implement rate limiting in Cloud Functions for all sensitive operations.

```javascript
// CloudFunctions/modules/rateLimiter.js
const admin = require('firebase-admin');

class RateLimiter {
    constructor(maxAttempts, windowSeconds) {
        this.maxAttempts = maxAttempts;
        this.windowSeconds = windowSeconds;
    }

    async checkLimit(userId, operation) {
        const now = Date.now();
        const windowStart = now - (this.windowSeconds * 1000);

        const rateLimitRef = admin.firestore()
            .collection('rate_limits')
            .doc(`${userId}_${operation}`);

        const doc = await rateLimitRef.get();

        if (!doc.exists) {
            // First attempt
            await rateLimitRef.set({
                attempts: [now],
                createdAt: admin.firestore.FieldValue.serverTimestamp()
            });
            return true;
        }

        const data = doc.data();
        const recentAttempts = data.attempts.filter(timestamp => timestamp > windowStart);

        if (recentAttempts.length >= this.maxAttempts) {
            throw new functions.https.HttpsError(
                'resource-exhausted',
                `Rate limit exceeded. Try again in ${this.windowSeconds} seconds.`
            );
        }

        // Add this attempt
        recentAttempts.push(now);
        await rateLimitRef.update({ attempts: recentAttempts });

        return true;
    }
}

// Export rate limiters for different operations
exports.sendMessageLimiter = new RateLimiter(20, 60); // 20 messages per minute
exports.sendLikeLimiter = new RateLimiter(100, 3600); // 100 likes per hour
exports.reportUserLimiter = new RateLimiter(5, 86400); // 5 reports per day

// Example usage in Cloud Function
exports.sendMessage = functions.https.onCall(async (data, context) => {
    const userId = context.auth.uid;

    // Check rate limit
    await exports.sendMessageLimiter.checkLimit(userId, 'send_message');

    // Proceed with sending message
    // ...
});
```

---

## 🟡 HIGH PRIORITY FEATURES

These features need backend implementation to work properly.

### 5. Typing Indicators

**Current Issue:**
UI exists but no Firebase listener to detect when other user is typing.

**Required Implementation:**
```javascript
// CloudFunctions/modules/typingStatus.js
exports.updateTypingStatus = functions.https.onCall(async (data, context) => {
    const { matchId, isTyping } = data;
    const userId = context.auth.uid;

    await admin.firestore().collection('typing_status').doc(matchId).set({
        [userId]: isTyping ? admin.firestore.FieldValue.serverTimestamp() : null
    }, { merge: true });

    return { success: true };
});

// Cleanup old typing statuses
exports.cleanupTypingStatus = functions.pubsub.schedule('every 5 minutes').onRun(async () => {
    const cutoff = Date.now() - (10 * 1000); // 10 seconds ago
    const snapshot = await admin.firestore().collection('typing_status').get();

    const batch = admin.firestore().batch();
    snapshot.forEach(doc => {
        const data = doc.data();
        let shouldUpdate = false;
        const updates = {};

        for (const [userId, timestamp] of Object.entries(data)) {
            if (timestamp && timestamp.toMillis() < cutoff) {
                updates[userId] = null;
                shouldUpdate = true;
            }
        }

        if (shouldUpdate) {
            batch.update(doc.ref, updates);
        }
    });

    await batch.commit();
});
```

---

### 6. Mark Messages as Read

**Current Issue:**
Read receipts UI exists but no logic to mark messages as read when user views them.

**Required Implementation:**
```javascript
exports.markMessagesAsRead = functions.https.onCall(async (data, context) => {
    const { matchId } = data;
    const userId = context.auth.uid;

    // Mark all messages from other user as read
    const messagesSnapshot = await admin.firestore()
        .collection('messages')
        .where('matchId', '==', matchId)
        .where('receiverId', '==', userId)
        .where('isRead', '==', false)
        .get();

    const batch = admin.firestore().batch();
    const readAt = admin.firestore.FieldValue.serverTimestamp();

    messagesSnapshot.forEach(doc => {
        batch.update(doc.ref, {
            isRead: true,
            readAt: readAt
        });
    });

    await batch.commit();

    return { markedCount: messagesSnapshot.size };
});
```

---

### 7. Profile Boost Feature

**Current Issue:**
Promised in premium but no ranking algorithm implemented.

**Required Implementation:**
```javascript
exports.activateBoost = functions.https.onCall(async (data, context) => {
    const userId = context.auth.uid;
    const { durationHours = 1 } = data;

    // Verify user has premium or boost credits
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (!userDoc.data().isPremium && (userDoc.data().boostCredits || 0) === 0) {
        throw new functions.https.HttpsError('permission-denied', 'No boost credits available');
    }

    const boostExpiresAt = new Date(Date.now() + (durationHours * 60 * 60 * 1000));

    await admin.firestore().collection('users').doc(userId).update({
        isCurrentlyBoosted: true,
        boostExpiresAt: boostExpiresAt,
        boostActivatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Deduct boost credit if not premium
    if (!userDoc.data().isPremium) {
        await admin.firestore().collection('users').doc(userId).update({
            boostCredits: admin.firestore.FieldValue.increment(-1)
        });
    }

    return { expiresAt: boostExpiresAt };
});

// Update discovery algorithm to prioritize boosted profiles
exports.getDiscoveryProfiles = functions.https.onCall(async (data, context) => {
    const userId = context.auth.uid;
    const { limit = 20 } = data;

    // Get boosted profiles first
    const boostedProfiles = await admin.firestore()
        .collection('users')
        .where('isCurrentlyBoosted', '==', true)
        .where('boostExpiresAt', '>', new Date())
        .limit(5)
        .get();

    // Then get regular profiles
    const regularProfiles = await admin.firestore()
        .collection('users')
        .where('isCurrentlyBoosted', '==', false)
        .limit(limit - boostedProfiles.size)
        .get();

    // Combine and return
    return {
        profiles: [
            ...boostedProfiles.docs.map(doc => ({ id: doc.id, ...doc.data(), isBoosted: true })),
            ...regularProfiles.docs.map(doc => ({ id: doc.id, ...doc.data(), isBoosted: false }))
        ]
    };
});
```

---

## 📋 ADDITIONAL SECURITY BEST PRACTICES

### Input Sanitization
```javascript
const sanitizeHtml = require('sanitize-html');

exports.sanitizeInput = (text) => {
    return sanitizeHtml(text, {
        allowedTags: [], // No HTML tags
        allowedAttributes: {},
        disallowedTagsMode: 'discard'
    }).trim();
};
```

### Location Privacy
```swift
// Don't store exact coordinates - use geohash
import Geohash

func storeLocationSecurely(lat: Double, lon: Double) {
    let geohash = Geohash.encode(latitude: lat, longitude: lon, precision: 5)
    // Store geohash (~4.9km precision) instead of exact coordinates
    // This prevents stalking while still enabling distance filters
}
```

### Data Retention Policy
```javascript
// Delete old messages after 90 days (GDPR compliance)
exports.cleanupOldData = functions.pubsub.schedule('every 24 hours').onRun(async () => {
    const cutoff = new Date(Date.now() - (90 * 24 * 60 * 60 * 1000));

    const oldMessages = await admin.firestore()
        .collection('messages')
        .where('timestamp', '<', cutoff)
        .get();

    const batch = admin.firestore().batch();
    oldMessages.forEach(doc => batch.delete(doc.ref));
    await batch.commit();

    console.log(`Deleted ${oldMessages.size} old messages`);
});
```

---

## 🚀 DEPLOYMENT CHECKLIST

Before launching, ensure:

- [ ] All Cloud Functions deployed: `firebase deploy --only functions`
- [ ] Firestore security rules updated
- [ ] Firebase Storage rules configured
- [ ] Apple shared secret configured: `firebase functions:config:set apple.shared_secret="YOUR_SECRET"`
- [ ] Cloudinary/Vision API credentials set up
- [ ] Rate limiting enabled for all sensitive endpoints
- [ ] Age validation enforced on signup
- [ ] Photo moderation active
- [ ] Receipt validation tested with sandbox purchases
- [ ] Data retention policy scheduled
- [ ] Monitoring and alerts configured

---

## 📞 NEXT STEPS

1. **Immediate (This Week):**
   - Implement server-side receipt validation
   - Enable photo content moderation
   - Add age validation on signup

2. **High Priority (Next Sprint):**
   - Rate limiting on all sensitive operations
   - Typing indicators backend
   - Read receipts marking logic
   - Profile boost ranking

3. **Quality of Life (Following Sprint):**
   - Data retention automation
   - Location privacy (geohash)
   - Input sanitization across all endpoints

---

**Questions?** Contact your backend team with this document to prioritize implementation.
