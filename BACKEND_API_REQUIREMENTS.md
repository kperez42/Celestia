# Backend API Requirements for Celestia

**CRITICAL**: This document outlines required backend APIs for security-critical operations. Implementing these endpoints prevents fraud and abuse that cannot be prevented with client-side validation alone.

## Table of Contents

- [Overview](#overview)
- [Authentication](#authentication)
- [API Endpoints](#api-endpoints)
  - [Receipt Validation](#1-receipt-validation)
  - [Content Moderation](#2-content-moderation)
  - [Rate Limiting](#3-rate-limiting)
  - [Reporting](#4-reporting)
- [Database Schema](#database-schema)
- [Security Considerations](#security-considerations)
- [Implementation Guide](#implementation-guide)

---

## Overview

The Celestia iOS app requires a backend API for server-side validation of critical operations. Without these endpoints, the app is vulnerable to:

- **Purchase Fraud** - Users can bypass StoreKit validation
- **Content Abuse** - Client-side moderation can be bypassed
- **Rate Limit Bypass** - Client-side limits can be circumvented
- **Spam & Abuse** - No centralized abuse detection

### Base URL

Configure your backend API base URL in `Constants.swift`:

```swift
enum API {
    static let baseURL = "https://api.celestia.app"  // Your backend URL
}
```

### Technology Stack (Recommended)

- **Runtime**: Node.js / Python / Go
- **Framework**: Express / FastAPI / Gin
- **Database**: PostgreSQL / MySQL
- **Cache**: Redis (for rate limiting)
- **Authentication**: Firebase Admin SDK

---

## Authentication

All API requests must include a Firebase ID token in the Authorization header:

```
Authorization: Bearer <firebase_id_token>
```

### Verify Token (Backend)

```javascript
// Node.js example
const admin = require('firebase-admin');

async function verifyToken(token) {
  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    return { uid: decodedToken.uid, email: decodedToken.email };
  } catch (error) {
    throw new Error('Invalid token');
  }
}
```

---

## API Endpoints

### 1. Receipt Validation

**Endpoint**: `POST /v1/purchases/validate`

**Purpose**: Validate StoreKit transaction server-side to prevent fraud

**Request Body**:
```json
{
  "transaction_id": "1000000123456789",
  "product_id": "com.celestia.subscription.premium.monthly",
  "purchase_date": "2025-01-15T10:30:00Z",
  "user_id": "firebase_user_id_123",
  "original_transaction_id": "1000000987654321",
  "environment": "Production"
}
```

**Response** (200 OK):
```json
{
  "is_valid": true,
  "transaction_id": "1000000123456789",
  "product_id": "com.celestia.subscription.premium.monthly",
  "subscription_tier": "premium",
  "expiration_date": "2025-02-15T10:30:00Z",
  "reason": null
}
```

**Response** (200 OK - Invalid):
```json
{
  "is_valid": false,
  "transaction_id": "1000000123456789",
  "product_id": "com.celestia.subscription.premium.monthly",
  "subscription_tier": null,
  "expiration_date": null,
  "reason": "Receipt verification failed with Apple"
}
```

**Error Responses**:
- `401 Unauthorized` - Invalid or missing authentication token
- `400 Bad Request` - Missing required fields
- `500 Internal Server Error` - Server error

**Implementation Steps**:

1. **Validate Firebase Token** - Verify the user is authenticated
2. **Verify with Apple** - Use App Store Server API to verify transaction
   - Use Apple's `/verifyReceipt` endpoint
   - Check transaction status and expiration
3. **Check Against Database** - Ensure transaction hasn't been used by another user
4. **Update Database** - Record transaction as validated
5. **Update Firestore** - Update user's `isPremium` status

**Apple App Store Server API**:
```javascript
// Node.js example
async function verifyWithApple(transactionId) {
  const endpoint = 'https://buy.itunes.apple.com/verifyReceipt'; // Production
  // const endpoint = 'https://sandbox.itunes.apple.com/verifyReceipt'; // Sandbox

  const response = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      'receipt-data': transactionId,
      'password': process.env.APPLE_SHARED_SECRET,
      'exclude-old-transactions': true
    })
  });

  const data = await response.json();
  return data.status === 0; // 0 = valid
}
```

---

### 2. Content Moderation

**Endpoint**: `POST /v1/moderation/validate`

**Purpose**: Server-side content moderation to prevent abuse

**Request Body**:
```json
{
  "content": "Hey! How are you doing?",
  "type": "message"
}
```

**Types**: `message`, `bio`, `interest_message`, `username`

**Response** (200 OK):
```json
{
  "is_appropriate": true,
  "violations": [],
  "severity": "none",
  "filtered_content": null
}
```

**Response** (200 OK - Flagged):
```json
{
  "is_appropriate": false,
  "violations": ["profanity", "personal_info"],
  "severity": "high",
  "filtered_content": "Hey! How are you doing? [REDACTED]"
}
```

**Implementation Steps**:

1. **Basic Profanity Check** - Check against profanity wordlist
2. **Personal Info Detection** - Detect phone numbers, emails, addresses
3. **Spam Detection** - Check for repeated messages, links, suspicious patterns
4. **ML-Based Detection** (Advanced) - Use services like:
   - **Perspective API** (Google) - Toxicity detection
   - **Amazon Comprehend** - Sentiment analysis
   - **Azure Content Moderator** - Comprehensive moderation

**Example Implementation**:
```javascript
async function moderateContent(content, type) {
  const violations = [];
  let severity = 'none';

  // 1. Check profanity
  if (containsProfanity(content)) {
    violations.push('profanity');
    severity = 'medium';
  }

  // 2. Check personal info
  if (containsPhoneNumber(content) || containsEmail(content)) {
    violations.push('personal_info');
    severity = 'high';
  }

  // 3. Check spam patterns
  if (isSpam(content)) {
    violations.push('spam');
    severity = 'medium';
  }

  // 4. Use ML API (optional)
  const toxicityScore = await checkToxicity(content);
  if (toxicityScore > 0.7) {
    violations.push('toxic_language');
    severity = 'critical';
  }

  return {
    is_appropriate: violations.length === 0,
    violations,
    severity,
    filtered_content: violations.length > 0 ? filterContent(content) : null
  };
}
```

---

### 3. Rate Limiting

**Endpoint**: `POST /v1/rate-limit/check`

**Purpose**: Server-side rate limiting to prevent abuse

**Request Body**:
```json
{
  "user_id": "firebase_user_id_123",
  "action": "send_message",
  "timestamp": "2025-01-15T10:30:00Z"
}
```

**Actions**:
- `send_message` - 100/hour
- `send_like` - 50/day (free), unlimited (premium)
- `send_super_like` - 5/day (free), 25/day (premium)
- `swipe` - 50/day (free), unlimited (premium)
- `update_profile` - 10/hour
- `upload_photo` - 20/day
- `report` - 5/hour

**Response** (200 OK):
```json
{
  "allowed": true,
  "remaining": 95,
  "reset_at": "2025-01-15T11:30:00Z",
  "retry_after": null
}
```

**Response** (200 OK - Rate Limited):
```json
{
  "allowed": false,
  "remaining": 0,
  "reset_at": "2025-01-15T11:30:00Z",
  "retry_after": 3600
}
```

**Implementation** (Redis):
```javascript
async function checkRateLimit(userId, action) {
  const key = `rate_limit:${userId}:${action}`;
  const limit = getRateLimitForAction(action);
  const window = getTimeWindowForAction(action); // seconds

  // Increment counter
  const count = await redis.incr(key);

  // Set expiration on first request
  if (count === 1) {
    await redis.expire(key, window);
  }

  // Get TTL for reset time
  const ttl = await redis.ttl(key);
  const resetAt = new Date(Date.now() + ttl * 1000);

  return {
    allowed: count <= limit,
    remaining: Math.max(0, limit - count),
    reset_at: resetAt,
    retry_after: count > limit ? ttl : null
  };
}
```

---

### 4. Reporting

**Endpoint**: `POST /v1/reports/create`

**Purpose**: Submit user/content reports for review

**Request Body**:
```json
{
  "reporter_id": "firebase_user_id_123",
  "reported_id": "firebase_user_id_456",
  "reason": "inappropriate_content",
  "details": "User sent inappropriate messages",
  "timestamp": "2025-01-15T10:30:00Z"
}
```

**Reasons**:
- `inappropriate_content`
- `spam`
- `harassment`
- `fake_profile`
- `underage`
- `scam`
- `other`

**Response** (200 OK):
```json
{}
```

**Implementation**:
1. Store report in database
2. Increment report count for reported user
3. Auto-ban if reports exceed threshold (e.g., 5 reports)
4. Notify moderation team via email/Slack
5. Track reporter for abuse (to prevent false reporting)

---

## Database Schema

### Validated Transactions Table

```sql
CREATE TABLE validated_transactions (
  id UUID PRIMARY KEY,
  transaction_id VARCHAR(255) UNIQUE NOT NULL,
  user_id VARCHAR(255) NOT NULL,
  product_id VARCHAR(255) NOT NULL,
  subscription_tier VARCHAR(50),
  purchase_date TIMESTAMP NOT NULL,
  expiration_date TIMESTAMP,
  environment VARCHAR(50),
  validated_at TIMESTAMP DEFAULT NOW(),
  is_refunded BOOLEAN DEFAULT FALSE,

  INDEX idx_user_id (user_id),
  INDEX idx_transaction_id (transaction_id)
);
```

### Content Moderation Log

```sql
CREATE TABLE content_moderation_log (
  id UUID PRIMARY KEY,
  user_id VARCHAR(255) NOT NULL,
  content_type VARCHAR(50) NOT NULL,
  content_hash VARCHAR(64) NOT NULL,
  is_appropriate BOOLEAN NOT NULL,
  violations TEXT[],
  severity VARCHAR(50),
  created_at TIMESTAMP DEFAULT NOW(),

  INDEX idx_user_id (user_id),
  INDEX idx_created_at (created_at)
);
```

### Reports Table

```sql
CREATE TABLE reports (
  id UUID PRIMARY KEY,
  reporter_id VARCHAR(255) NOT NULL,
  reported_id VARCHAR(255) NOT NULL,
  reason VARCHAR(100) NOT NULL,
  details TEXT,
  status VARCHAR(50) DEFAULT 'pending',
  reviewed_by VARCHAR(255),
  reviewed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),

  INDEX idx_reported_id (reported_id),
  INDEX idx_status (status)
);
```

---

## Security Considerations

### 1. Always Validate Firebase Tokens

Never trust the `user_id` in request body alone - always verify via Firebase token:

```javascript
// ❌ BAD - Trusts client
app.post('/api/endpoint', (req, res) => {
  const userId = req.body.user_id; // Can be faked!
});

// ✅ GOOD - Verifies token
app.post('/api/endpoint', async (req, res) => {
  const token = req.headers.authorization?.split('Bearer ')[1];
  const { uid } = await admin.auth().verifyIdToken(token);
  // Use uid from verified token
});
```

### 2. Use HTTPS Only

All API endpoints must use HTTPS (TLS 1.2+) to prevent man-in-the-middle attacks.

### 3. Implement Rate Limiting

Protect all endpoints with rate limiting to prevent DoS attacks:

```javascript
const rateLimit = require('express-rate-limit');

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});

app.use('/api/', limiter);
```

### 4. Input Validation

Always validate and sanitize input:

```javascript
const { body, validationResult } = require('express-validator');

app.post('/api/validate',
  body('content').isString().trim().isLength({ max: 1000 }),
  body('type').isIn(['message', 'bio', 'interest_message', 'username']),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    // Process request
  }
);
```

### 5. Log Everything

Log all validation requests for fraud detection and auditing:

```javascript
logger.info('Receipt validation', {
  user_id: uid,
  transaction_id: req.body.transaction_id,
  is_valid: result.is_valid,
  timestamp: new Date()
});
```

---

## Implementation Guide

### Quick Start (Node.js + Express)

1. **Install Dependencies**:
```bash
npm install express firebase-admin ioredis express-validator express-rate-limit
```

2. **Create Server**:
```javascript
const express = require('express');
const admin = require('firebase-admin');
const Redis = require('ioredis');

// Initialize Firebase
admin.initializeApp({
  credential: admin.credential.cert(require('./serviceAccountKey.json'))
});

// Initialize Redis
const redis = new Redis(process.env.REDIS_URL);

const app = express();
app.use(express.json());

// Auth middleware
async function authenticate(req, res, next) {
  try {
    const token = req.headers.authorization?.split('Bearer ')[1];
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.user = decodedToken;
    next();
  } catch (error) {
    res.status(401).json({ error: 'Unauthorized' });
  }
}

// Implement endpoints here
// ... (see examples above)

app.listen(3000, () => console.log('Server running on port 3000'));
```

3. **Deploy to Production**:
   - **Heroku**: `git push heroku main`
   - **AWS**: Use Elastic Beanstalk or ECS
   - **Google Cloud**: Use Cloud Run or App Engine
   - **Digital Ocean**: Use App Platform

### Environment Variables

Create `.env` file:

```bash
PORT=3000
NODE_ENV=production
FIREBASE_PROJECT_ID=your-project-id
REDIS_URL=redis://localhost:6379
APPLE_SHARED_SECRET=your_apple_shared_secret
DATABASE_URL=postgresql://user:pass@localhost/celestia
PERSPECTIVE_API_KEY=your_perspective_api_key  # Optional
```

---

## Testing

### Test Receipt Validation

```bash
curl -X POST https://api.celestia.app/v1/purchases/validate \
  -H "Authorization: Bearer <firebase_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "transaction_id": "1000000123456789",
    "product_id": "com.celestia.subscription.premium.monthly",
    "purchase_date": "2025-01-15T10:30:00Z",
    "user_id": "firebase_user_id_123",
    "original_transaction_id": "1000000987654321",
    "environment": "Sandbox"
  }'
```

### Test Content Moderation

```bash
curl -X POST https://api.celestia.app/v1/moderation/validate \
  -H "Authorization: Bearer <firebase_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Hey! How are you?",
    "type": "message"
  }'
```

---

## Monitoring & Alerts

### Key Metrics to Track

1. **Receipt Validation Rate** - % of receipts that fail validation
2. **Content Moderation Rate** - % of content flagged
3. **Rate Limit Hit Rate** - How often users hit limits
4. **API Response Times** - Latency of endpoints
5. **Error Rates** - 4xx and 5xx response rates

### Recommended Tools

- **Sentry** - Error tracking
- **DataDog** - Performance monitoring
- **LogRocket** - User session replay
- **PagerDuty** - On-call alerting

---

## Next Steps

1. ✅ Set up backend server (Node.js/Python/Go)
2. ✅ Implement authentication middleware
3. ✅ Implement receipt validation endpoint
4. ✅ Implement content moderation endpoint
5. ✅ Implement rate limiting endpoint
6. ✅ Implement reporting endpoint
7. ✅ Set up database and Redis
8. ✅ Deploy to production
9. ✅ Update `AppConstants.API.baseURL` in iOS app
10. ✅ Test all endpoints thoroughly
11. ✅ Monitor for issues

---

## Support

For questions or issues:
- **Email**: dev@celestia.app
- **Documentation**: https://docs.celestia.app
- **GitHub Issues**: https://github.com/celestia/backend/issues

---

**Last Updated**: 2025-01-12
