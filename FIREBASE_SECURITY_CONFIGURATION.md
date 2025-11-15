# Firebase Security Configuration Guide

## Overview

This document provides critical security configuration steps for the Celestia iOS app's Firebase integration. While Firebase API keys in `GoogleService-Info.plist` are unavoidable for iOS apps, proper configuration of Google Cloud restrictions and Firestore security rules is essential to prevent unauthorized access.

---

## ⚠️ CRITICAL SECURITY ISSUE

**Status:** API keys are currently exposed in `GoogleService-Info.plist`

**Risk Level:** CRITICAL

**Impact:** Without proper restrictions, these API keys can be extracted from the app binary and used to:
- Access Firebase services
- Impersonate legitimate app requests
- Perform unauthorized operations
- Incur unexpected costs

---

## 🔒 Required Security Measures

### 1. Google Cloud API Restrictions

#### Step 1: Configure API Key Restrictions in Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project: `celestia-40ce6`
3. Navigate to **APIs & Services** → **Credentials**
4. Find your API key: `AIzaSyDGzRIpwziNjeOcA84plhYqjv1GIUjoIIE`

#### Step 2: Set Application Restrictions

**iOS Apps:**
- Click on the API key
- Under "Application restrictions", select **iOS apps**
- Add your bundle identifier: `com.celestia.app` (or your actual bundle ID)
- Save changes

This ensures the API key only works from your iOS app.

#### Step 3: Set API Restrictions

Restrict which APIs the key can access:

**Enable only the following APIs:**
- Firebase Authentication API
- Cloud Firestore API
- Firebase Cloud Messaging API
- Cloud Storage for Firebase API
- Firebase Dynamic Links API
- Identity Toolkit API

**Disable all other APIs** to follow the principle of least privilege.

---

### 2. Firestore Security Rules

#### Current Security Rules

Review your `firestore.rules` file to ensure proper access controls.

**Recommended Structure:**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper functions
    function isSignedIn() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return request.auth.uid == userId;
    }

    function isVerified() {
      return request.auth.token.email_verified == true;
    }

    // Users collection
    match /users/{userId} {
      // Read: User must be authenticated
      allow read: if isSignedIn();

      // Write: User can only modify their own document
      allow write: if isSignedIn() && isOwner(userId);

      // Delete: Only owner can delete (account deletion)
      allow delete: if isSignedIn() && isOwner(userId);
    }

    // Matches collection
    match /matches/{matchId} {
      // Read: Only participants can read the match
      allow read: if isSignedIn() &&
                    (resource.data.user1Id == request.auth.uid ||
                     resource.data.user2Id == request.auth.uid);

      // Create: Authenticated users can create matches
      allow create: if isSignedIn();

      // Update: Only participants can update
      allow update: if isSignedIn() &&
                      (resource.data.user1Id == request.auth.uid ||
                       resource.data.user2Id == request.auth.uid);

      // Delete: No one can delete matches (or restrict to owner)
      allow delete: if false;
    }

    // Messages collection
    match /messages/{messageId} {
      // Read: Only sender or recipient
      allow read: if isSignedIn() &&
                    (resource.data.senderId == request.auth.uid ||
                     resource.data.recipientId == request.auth.uid);

      // Create: Only authenticated senders
      allow create: if isSignedIn() &&
                      request.resource.data.senderId == request.auth.uid;

      // Update/Delete: No one can modify messages once sent
      allow update, delete: if false;
    }

    // Interests collection
    match /interests/{interestId} {
      // Read: User must be authenticated
      allow read: if isSignedIn();

      // Create: User can only create interests they're sending
      allow create: if isSignedIn() &&
                      request.resource.data.fromUserId == request.auth.uid;

      // Update: Only recipient can accept/reject
      allow update: if isSignedIn() &&
                      resource.data.toUserId == request.auth.uid;

      // Delete: Sender or recipient can delete
      allow delete: if isSignedIn() &&
                      (resource.data.fromUserId == request.auth.uid ||
                       resource.data.toUserId == request.auth.uid);
    }

    // Referrals collection
    match /referrals/{referralId} {
      // Read: Owner can read their referral data
      allow read: if isSignedIn() &&
                    resource.data.userId == request.auth.uid;

      // Create: System creates referral codes
      allow create: if isSignedIn();

      // Update: Owner can update their referral stats
      allow update: if isSignedIn() &&
                      resource.data.userId == request.auth.uid;
    }

    // Reports collection
    match /reports/{reportId} {
      // Read: Only admins (handled in backend)
      allow read: if false;

      // Create: Authenticated users can report
      allow create: if isSignedIn() &&
                      request.resource.data.reportedBy == request.auth.uid;

      // No updates or deletes
      allow update, delete: if false;
    }

    // Check-ins collection (for safety features)
    match /checkIns/{checkInId} {
      // Read: Only the user who created the check-in
      allow read: if isSignedIn() &&
                    resource.data.userId == request.auth.uid;

      // Create: Authenticated users can create check-ins
      allow create: if isSignedIn() &&
                      request.resource.data.userId == request.auth.uid;

      // Update: Only owner can update status
      allow update: if isSignedIn() &&
                      resource.data.userId == request.auth.uid;

      // Delete: Only owner can delete
      allow delete: if isSignedIn() &&
                      resource.data.userId == request.auth.uid;
    }

    // Default: Deny all access to other collections
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

#### Deploy Security Rules

```bash
firebase deploy --only firestore:rules
```

---

### 3. Firebase Authentication Configuration

#### Email Enumeration Protection

**Important:** Firebase Authentication has email enumeration protection enabled by default.

**Verify in Firebase Console:**
1. Go to **Firebase Console** → **Authentication** → **Settings**
2. Under **User account management**, ensure:
   - ✅ **Email enumeration protection** is **ENABLED**
   - This prevents attackers from discovering valid email addresses

---

### 4. App Attest (Recommended)

Implement Apple's App Attest to verify that API requests are coming from your legitimate app.

#### Implementation Steps:

1. **Enable App Attest in Xcode:**
   - Add `DeviceCheck` framework
   - Implement attestation challenge-response

2. **Verify attestations server-side:**
   - Use Firebase Cloud Functions to validate attestations
   - Reject requests without valid attestations

**Code Example:**

```swift
import DeviceCheck

class AppAttestManager {
    static let shared = AppAttestManager()

    func generateAttestation() async throws -> Data {
        let service = DCAppAttestService.shared

        guard service.isSupported else {
            throw AppAttestError.notSupported
        }

        let keyId = try await service.generateKey()
        let challenge = // Get challenge from server
        let attestation = try await service.attestKey(keyId, clientDataHash: challenge)

        return attestation
    }
}
```

---

### 5. Rate Limiting

Implement rate limiting to prevent abuse of API keys.

**Firebase Security Rules Rate Limiting:**

```javascript
// Add rate limiting to write operations
match /users/{userId} {
  allow write: if isSignedIn() &&
                 isOwner(userId) &&
                 request.time > resource.data.lastUpdated + duration.value(5, 's');
}
```

**Server-side Rate Limiting (Cloud Functions):**

```javascript
const rateLimit = require('express-rate-limit');

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per window
  message: 'Too many requests from this IP'
});

exports.api = functions.https.onRequest((req, res) => {
  limiter(req, res, () => {
    // Your API logic
  });
});
```

---

### 6. Monitor API Usage

Set up monitoring to detect unusual API usage patterns.

#### Firebase Console Monitoring:

1. **Usage and Billing** → **Usage** tab
2. Monitor:
   - Authentication requests
   - Firestore reads/writes
   - Storage downloads

#### Set Up Alerts:

1. **Google Cloud Console** → **Monitoring** → **Alerting**
2. Create alerts for:
   - Unusual spike in API calls
   - Requests from unexpected regions
   - High error rates

#### Budget Alerts:

1. **Google Cloud Console** → **Billing** → **Budgets**
2. Set monthly budget alerts:
   - 50% of budget
   - 90% of budget
   - 100% of budget

---

### 7. Certificate Pinning (Implemented)

✅ **Status:** Certificate pinning has been implemented in `NetworkManager.swift`

**Configuration Required:**

1. **Get your server's SSL certificate public key hash:**

```bash
openssl s_client -connect api.celestia.app:443 | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64
```

2. **Add the hash to NetworkManager.swift:**

```swift
private let pinnedPublicKeyHashes: Set<String> = [
    "YOUR_PUBLIC_KEY_HASH_HERE"
]
```

3. **Update when certificate changes:**
   - Certificates typically expire annually
   - Update the hash before expiration
   - Keep both old and new hashes during transition

---

## 🔐 Additional Security Recommendations

### 1. Enable Two-Factor Authentication

For Firebase Console access:
- Enable 2FA for all team members
- Use hardware security keys when possible

### 2. Regular Security Audits

Schedule quarterly security reviews:
- Review Firestore security rules
- Audit API key restrictions
- Check authentication logs for suspicious activity

### 3. Principle of Least Privilege

- Grant minimum necessary permissions
- Use custom claims for role-based access
- Separate development and production projects

### 4. Backup Strategy

Implement automated backups:
```bash
firebase firestore:export gs://celestia-backups/$(date +%Y%m%d)
```

Schedule daily backups via Cloud Scheduler.

---

## ✅ Security Checklist

Use this checklist to verify all security measures are in place:

- [ ] Google Cloud API key restricted to iOS bundle ID
- [ ] API key restricted to specific Firebase APIs only
- [ ] Firestore security rules deployed and tested
- [ ] Email enumeration protection enabled
- [ ] Certificate pinning configured with valid hashes
- [ ] TLS 1.2+ enforced in NetworkManager
- [ ] App Attest implemented (optional but recommended)
- [ ] Rate limiting configured
- [ ] Usage monitoring and alerts set up
- [ ] Budget alerts configured
- [ ] Team members have 2FA enabled
- [ ] Regular security audit scheduled
- [ ] Backup strategy implemented

---

## 🚨 Incident Response

If you suspect API key compromise:

1. **Immediate Actions:**
   - Generate new API key in Google Cloud Console
   - Update `GoogleService-Info.plist` with new key
   - Deploy new app version
   - Revoke old API key

2. **Investigation:**
   - Review Firestore audit logs
   - Check authentication logs for suspicious sign-ins
   - Review billing for unexpected usage

3. **Prevention:**
   - Strengthen security rules
   - Implement additional monitoring
   - Review and update this security configuration

---

## 📚 References

- [Firebase Security Best Practices](https://firebase.google.com/docs/rules/best-practices)
- [Google Cloud API Security](https://cloud.google.com/docs/authentication)
- [Firestore Security Rules Guide](https://firebase.google.com/docs/firestore/security/get-started)
- [App Attest Documentation](https://developer.apple.com/documentation/devicecheck/establishing_your_app_s_integrity)
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-top-10/)

---

## 🛠️ Implementation Status

| Security Measure | Status | Priority | Notes |
|------------------|--------|----------|-------|
| API Key Restrictions | ⚠️ **Pending** | CRITICAL | Configure in Google Cloud Console |
| Firestore Security Rules | ⚠️ **Review Needed** | CRITICAL | Verify current rules are secure |
| Email Enumeration Protection | ✅ **Enabled** | HIGH | Default Firebase setting |
| Certificate Pinning | ✅ **Implemented** | HIGH | Configure hashes in NetworkManager |
| TLS 1.2+ | ✅ **Enforced** | HIGH | Set in NetworkManager |
| App Attest | ❌ **Not Implemented** | MEDIUM | Recommended for future |
| Rate Limiting | ⚠️ **Partial** | MEDIUM | Add server-side limits |
| Usage Monitoring | ❌ **Not Configured** | MEDIUM | Set up in Google Cloud |
| Backup Strategy | ❌ **Not Configured** | LOW | Implement automated backups |

---

## 📞 Support

For questions or security concerns:
- Review Firebase documentation
- Check Google Cloud Security Command Center
- Consult with security team before making changes

---

**Last Updated:** November 15, 2025
**Next Review Date:** December 15, 2025

