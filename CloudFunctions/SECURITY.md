# Celestia Security & Fraud Prevention Documentation

## Overview

This document outlines the comprehensive security and fraud prevention measures implemented in Celestia's payment system. These systems protect against revenue theft, refund abuse, jailbroken devices, and fraudulent transactions.

**Estimated Monthly Savings:** $1,000 - $5,000 in fraud prevention

---

## Table of Contents

1. [Webhook Security](#webhook-security)
2. [Receipt Validation](#receipt-validation)
3. [Fraud Detection System](#fraud-detection-system)
4. [Jailbreak Detection](#jailbreak-detection)
5. [Refund Abuse Prevention](#refund-abuse-prevention)
6. [Admin Dashboard](#admin-dashboard)
7. [Configuration](#configuration)
8. [Monitoring & Alerts](#monitoring--alerts)

---

## Webhook Security

### Overview

Apple's App Store Server Notifications V2 use cryptographic signatures to verify authenticity. Our implementation validates every webhook to prevent spoofing attacks.

### Implementation

**Location:** `CloudFunctions/modules/webhooks.js`

```javascript
// Webhook signature verification using Apple's public keys
await webhooks.verifyWebhookSignature(request);
```

### How It Works

1. **JWT Verification:**
   - Apple sends webhooks as signed JWTs (JSON Web Tokens)
   - We fetch Apple's public keys from their JWKS endpoint
   - Verify the signature using ES256 algorithm
   - Validate issuer is 'appstorenotifications'

2. **Security Events Logged:**
   - `webhook_verified` - Successful verification
   - `webhook_verification_failed` - Failed verification (potential attack)
   - `webhook_missing_payload` - Missing signed payload
   - `webhook_invalid_jwt` - Invalid JWT structure

3. **Attack Prevention:**
   - Forged webhooks are rejected with 401 status
   - All failed verifications are logged for security review
   - IP addresses of suspicious requests are recorded

### Configuration Required

```bash
# Firebase Functions Config
firebase functions:config:set apple.shared_secret="YOUR_SHARED_SECRET"
```

### Testing

```bash
# Test webhook endpoint (development only)
curl -X POST https://your-domain.com/appleWebhook \
  -H "Content-Type: application/json" \
  -d '{"signedPayload": "..."}'
```

---

## Receipt Validation

### Overview

Every in-app purchase is validated server-side with Apple's servers to ensure authenticity before granting premium access.

### Implementation

**Location:** `CloudFunctions/modules/receiptValidation.js`

```javascript
const validationResult = await receiptValidation.validateAppleReceipt(
  receiptData,
  userId
);
```

### Validation Flow

1. **Client-Side Purchase:**
   ```swift
   let result = try await product.purchase()
   // Send receipt to server for validation
   ```

2. **Server-Side Validation:**
   - Submit receipt to Apple's production server
   - Fallback to sandbox if receipt is from test environment
   - Verify receipt status code
   - Extract transaction details
   - Run fraud detection checks
   - Store validated purchase in database

3. **Security Checks:**
   - ✅ Receipt duplicate detection
   - ✅ Promotional code abuse prevention
   - ✅ Jailbreak indicators
   - ✅ Fraud score calculation
   - ✅ High-risk transaction flagging

### Response Handling

```javascript
{
  "isValid": true,
  "transactionId": "1000000123456789",
  "productId": "com.celestia.premium.monthly",
  "fraudScore": 15,  // 0-100, higher is more suspicious
  "jailbreakRisk": 0.2,  // 0-1, higher is more suspicious
  "expiryDate": "2025-02-14T..."
}
```

### Error Codes

| Code | Description | Action |
|------|-------------|--------|
| 21000 | Invalid JSON | Retry with correct format |
| 21002 | Malformed receipt data | Request new receipt |
| 21003 | Receipt could not be authenticated | Reject transaction |
| 21004 | Shared secret mismatch | Check configuration |
| 21005 | Receipt server unavailable | Retry with exponential backoff |
| 21006 | Subscription expired | Normal flow |
| 21007 | Sandbox receipt in production | Use sandbox endpoint |
| 21010 | Receipt could not be authorized | Reject transaction |

---

## Fraud Detection System

### Overview

Comprehensive fraud scoring system that analyzes user behavior, transaction patterns, and device indicators to identify fraudulent activity.

### Implementation

**Location:** `CloudFunctions/modules/fraudDetection.js`

### Fraud Score Components

The fraud score (0-100) is calculated from multiple factors:

| Factor | Max Points | Triggers |
|--------|-----------|----------|
| Refund History | 30 | >3 refunds = 30 pts, >2 = 20 pts |
| Validation Failures | 20 | >5 failures = 20 pts, >3 = 10 pts |
| Account Age | 15 | <1 day = 15 pts, <7 days = 10 pts |
| Jailbreak Risk | 25 | >0.7 = 25 pts, >0.4 = 15 pts |
| Promo Abuse | 20 | >3 promos = 20 pts |
| Purchase/Refund Cycles | 30 | Detected pattern = 30 pts |
| Previous Fraud Attempts | 75 | 25 pts per attempt (max 3) |
| Velocity Anomalies | 20 | Too many purchases |
| Device Fingerprint | 15 | Multiple users per device |
| Behavioral Anomalies | 15 | Suspicious patterns |

### Fraud Thresholds

```javascript
FRAUD_THRESHOLDS = {
  FRAUD_SCORE_LOW: 30,       // Monitor
  FRAUD_SCORE_MEDIUM: 50,    // Flag for review
  FRAUD_SCORE_HIGH: 70,      // Reject transaction
  FRAUD_SCORE_CRITICAL: 85,  // Auto-suspend
}
```

### Actions by Score

- **0-29 (Low):** Transaction approved, no action
- **30-49 (Low-Medium):** Transaction approved, logged for monitoring
- **50-69 (Medium):** Transaction approved, flagged for admin review
- **70-84 (High):** Transaction rejected, admin alert created
- **85-100 (Critical):** Transaction rejected, user auto-suspended

### Velocity Checks

Prevents rapid-fire purchase attempts:

- **Max 3 purchases per hour**
- **Max 10 purchases per day**

### Device Fingerprinting

```javascript
const fingerprint = generateDeviceFingerprint({
  deviceModel: "iPhone15,2",
  osVersion: "17.2",
  appVersion: "1.0.0",
  locale: "en_US",
  timezone: "America/New_York",
  vendorId: "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
});
```

Flags devices with:
- More than 3 users per device
- Suspicious patterns across accounts

---

## Jailbreak Detection

### Overview

Detects modified/jailbroken devices that may bypass payment validation or use cracked receipts.

### Detection Methods

**Location:** `CloudFunctions/modules/fraudDetection.js` → `detectJailbreakIndicators()`

### Server-Side Indicators

1. **Suspicious Bundle IDs:**
   - Keywords: cracked, hacked, pirate, modded, jailbreak
   - Cydia-related: cydia, sileo, unc0ver, checkra1n

2. **Environment Mismatches:**
   - Sandbox receipts in production environment
   - Production receipts in sandbox environment

3. **Receipt Anomalies:**
   - Missing receipt creation date
   - Abnormally large in_app arrays (>50 items)
   - Very old receipts (>365 days) being reused

4. **Receipt Age:**
   - Receipts older than 1 year flagged for review

### Client-Side Detection (iOS)

**Location:** `Celestia/StoreManager.swift`

The iOS app can optionally send device information for enhanced detection:

```swift
struct DeviceInfo {
    let isJailbroken: Bool
    let suspiciousPaths: [String]
    let canOpenCydia: Bool
}
```

### Risk Scoring

- **0.0-0.3:** Low risk
- **0.4-0.6:** Medium risk (monitor)
- **0.7-1.0:** High risk (flag/reject)

### Example Detection

```javascript
{
  "riskScore": 0.8,
  "indicators": [
    "Can open Cydia URL scheme",
    "Jailbreak files detected",
    "Suspicious bundle ID: jailbreak"
  ]
}
```

---

## Refund Abuse Prevention

### Overview

Automatically detects and prevents refund abuse where users purchase premium, refund, and keep access.

### Implementation

**Location:** `CloudFunctions/modules/webhooks.js` → `handleRefundEnhanced()`

### How It Works

1. **Immediate Access Revocation:**
   - When Apple sends REFUND or REVOKE webhook
   - Premium access is **immediately** revoked
   - User downgraded to free tier
   - All premium features disabled

2. **Refund Pattern Detection:**
   ```javascript
   // Multiple refunds (>2)
   if (refundCount > 2) {
     // Create fraud alert
     // Flag user for review
   }

   // Critical threshold (>3)
   if (refundCount > 3) {
     // Auto-suspend user
     // Permanent account restriction
   }
   ```

3. **Rapid Refund Detection:**
   - Tracks purchase-to-refund time
   - Flags refunds within 24 hours
   - 2+ rapid refunds = fraud alert

4. **Refund Rate Analysis:**
   - Calculates: `refunds / total_purchases`
   - >50% refund rate = suspicious pattern
   - Requires minimum 3 purchases

### Automatic Actions

| Refund Count | Action |
|--------------|--------|
| 1 | Log event, monitor user |
| 2 | Create fraud log, admin alert |
| 3 | High-priority admin review |
| 4+ | **Automatic account suspension** |

### Admin Notifications

```javascript
{
  "alertType": "refund_abuse_detected",
  "priority": "critical",
  "details": {
    "userId": "...",
    "refundCount": 4,
    "transactionId": "..."
  }
}
```

---

## Admin Dashboard

### Overview

Real-time fraud monitoring and analytics dashboard for administrators.

### API Endpoints

**Base URL:** `https://your-domain.com/adminApi`

#### 1. Fraud Dashboard

```bash
GET /admin/fraud-dashboard
Authorization: Bearer <admin_token>
```

**Response:**
```json
{
  "fraudLogs": [...],           // Latest fraud attempts
  "flaggedTransactions": [...], // High-risk transactions
  "refundAbusers": [...],       // Users with >2 refunds
  "adminAlerts": [...],         // Pending alerts
  "statistics": {
    "totalFraudAttempts": 42,
    "totalFlaggedTransactions": 15,
    "totalRefundAbusers": 8,
    "pendingAlerts": 3,
    "fraudAttemptsByType": {
      "duplicate_receipt": 12,
      "promo_code_abuse": 8,
      "multiple_refunds": 22
    }
  }
}
```

#### 2. Subscription Analytics

```bash
GET /admin/subscription-analytics?period=30
Authorization: Bearer <admin_token>
```

**Response:**
```json
{
  "period": 30,
  "totalPurchases": 1250,
  "subscriptions": {
    "total": 980,
    "new": 145,
    "promotional": 65,
    "refunded": 23
  },
  "metrics": {
    "churnRate": 2.3,
    "refundRate": 2.35,
    "fraudRate": 1.2
  },
  "revenue": {
    "total": 29450.00,
    "refunded": 690.00,
    "net": 28760.00
  },
  "risk": {
    "highRiskPurchases": 18,
    "flaggedPurchases": 12,
    "averageFraudScore": 12.5
  }
}
```

#### 3. Refund Tracking

```bash
GET /admin/refund-tracking?limit=50&period=30
Authorization: Bearer <admin_token>
```

#### 4. Review Flagged Transaction

```bash
POST /admin/review-transaction
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "transactionId": "doc_id",
  "decision": "approve|reject",
  "adminNote": "Legitimate purchase after investigation"
}
```

### Admin Dashboard Features

- ✅ Real-time fraud attempt monitoring
- ✅ High-risk transaction review queue
- ✅ Refund abuse detection
- ✅ User suspension management
- ✅ Revenue impact analysis
- ✅ Fraud pattern visualization
- ✅ Automated alert system

---

## Configuration

### Firebase Functions Config

```bash
# Apple App Store
firebase functions:config:set apple.shared_secret="YOUR_SHARED_SECRET"

# Fraud Detection Thresholds (optional)
firebase functions:config:set fraud.max_refunds="3"
firebase functions:config:set fraud.max_promos="3"
firebase functions:config:set fraud.critical_score="85"
```

### Environment Variables

```javascript
// In CloudFunctions/index.js
process.env.NODE_ENV = 'production|development'
```

### Database Collections

Required Firestore collections:

- `purchases` - All purchase records
- `fraud_logs` - Fraud attempt logs
- `security_logs` - Security event logs
- `flagged_transactions` - High-risk transactions
- `admin_alerts` - Admin notifications
- `refund_history` - Refund tracking
- `users` - User profiles

### Indexes Required

```javascript
// fraud_logs
- userId + eventType + timestamp
- timestamp (descending)

// purchases
- userId + refunded
- userId + purchaseDate
- transactionId
- originalTransactionId

// flagged_transactions
- reviewed + fraudScore (descending)
- userId + timestamp
```

---

## Monitoring & Alerts

### Critical Security Events

All critical events are logged and trigger admin alerts:

1. **Webhook Verification Failures**
   - Potential spoofing attack
   - Logged with IP address
   - Requires immediate investigation

2. **Fraud Attempts**
   - Duplicate receipt usage
   - Promotional code abuse
   - Multiple refund patterns

3. **High-Risk Transactions**
   - Fraud score >70
   - Auto-rejected
   - Admin review required

4. **Automatic Suspensions**
   - >3 refunds
   - >5 fraud attempts
   - Jailbreak detection with high risk

### Log Analysis

```javascript
// Query fraud logs
db.collection('fraud_logs')
  .where('eventType', '==', 'fraud_attempt')
  .where('timestamp', '>', thirtyDaysAgo)
  .orderBy('timestamp', 'desc')
  .get()

// Query security events
db.collection('security_logs')
  .where('eventType', '==', 'webhook_verification_failed')
  .get()
```

### Metrics to Monitor

1. **Fraud Rate:** `(fraud_attempts / total_purchases) * 100`
2. **Refund Rate:** `(refunds / total_purchases) * 100`
3. **Churn Rate:** `(cancelled / total_subscriptions) * 100`
4. **Average Fraud Score:** Track trends over time
5. **Webhook Verification Failures:** Should be near zero
6. **Validation Failure Rate:** Monitor for Apple API issues

---

## Best Practices

### 1. Regular Monitoring

- Review fraud dashboard daily
- Check flagged transactions weekly
- Analyze trends monthly
- Update thresholds based on data

### 2. Incident Response

When fraud is detected:

1. Review transaction details
2. Check user history
3. Verify legitimacy
4. Take action (approve/suspend)
5. Document decision
6. Update fraud detection rules if needed

### 3. Testing

```bash
# Test receipt validation
npm run test:receipts

# Test webhook signature
npm run test:webhooks

# Test fraud detection
npm run test:fraud
```

### 4. Security Updates

- Keep dependencies updated
- Monitor Apple documentation for API changes
- Review and update fraud thresholds quarterly
- Test webhook signature verification regularly

---

## Troubleshooting

### Webhook Signature Failures

**Symptom:** All webhooks rejected with 401

**Solutions:**
1. Verify Apple JWKS endpoint is accessible
2. Check system time is synchronized
3. Review Firebase Functions logs
4. Test with Apple's test notification

### Receipt Validation Failures

**Symptom:** Valid receipts rejected

**Solutions:**
1. Check shared secret configuration
2. Verify environment (sandbox vs production)
3. Review Apple API status
4. Check network connectivity

### False Positive Fraud Detection

**Symptom:** Legitimate users flagged

**Solutions:**
1. Review fraud score thresholds
2. Analyze specific indicators triggering false positives
3. Adjust weights in fraud score calculation
4. Whitelist specific cases if necessary

---

## Support & Resources

### Documentation

- [Apple Server Notifications V2](https://developer.apple.com/documentation/appstoreservernotifications)
- [StoreKit 2 Documentation](https://developer.apple.com/documentation/storekit)
- [Receipt Validation](https://developer.apple.com/documentation/appstorereceipts)

### Internal Resources

- Admin Dashboard: `https://your-domain.com/admin`
- Firebase Console: `https://console.firebase.google.com`
- Logs: Firebase Functions Logs

### Contact

For security incidents or questions:
- Security Team: security@celestia.app
- DevOps: devops@celestia.app

---

## Change Log

### 2025-01-14
- ✅ Implemented webhook signature verification
- ✅ Added comprehensive fraud detection system
- ✅ Created jailbreak detection
- ✅ Implemented refund abuse prevention
- ✅ Created admin fraud dashboard
- ✅ Added automatic access revocation
- ✅ Implemented velocity checks
- ✅ Added device fingerprinting

---

## Compliance

This implementation follows industry best practices for:

- PCI DSS (Payment Card Industry Data Security Standard)
- GDPR (fraud detection as legitimate interest)
- App Store Review Guidelines
- Apple Developer Program License Agreement

**Note:** This system detects and prevents fraud but does not process payment information directly. All payments are handled by Apple's secure infrastructure.
