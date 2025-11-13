# Celestia Cloud Functions

Backend API for the Celestia dating app, providing server-side validation, moderation, and admin features.

## Features

### 1. Receipt Validation
- ✅ Apple App Store receipt validation
- ✅ Fraud prevention through server-side verification
- ✅ Subscription renewal webhooks
- ✅ Automatic user subscription updates
- 🚧 Google Play validation (coming soon)

### 2. Content Moderation
- ✅ AI-powered photo moderation using Google Vision API
- ✅ Text content filtering (profanity, spam, contact info)
- ✅ Automatic flagging and user warnings
- ✅ Auto-suspension for repeat offenders

### 3. Rate Limiting
- ✅ Per-user rate limits for all actions
- ✅ Different limits for free vs. premium users
- ✅ Redis/Firestore-based rate limiting
- ✅ Abuse prevention and penalty system

### 4. Admin Dashboard API
- ✅ Platform statistics and analytics
- ✅ Flagged content review
- ✅ User management and moderation
- ✅ Revenue tracking

## Setup

### Prerequisites
- Node.js 18 or higher
- Firebase CLI installed: `npm install -g firebase-tools`
- Firebase project created

### Installation

1. **Install dependencies:**
   ```bash
   cd CloudFunctions
   npm install
   ```

2. **Set up Firebase config:**
   ```bash
   firebase login
   firebase use celestia-dating-app
   ```

3. **Set environment variables:**
   ```bash
   # Apple shared secret for receipt validation
   firebase functions:config:set apple.shared_secret="YOUR_SHARED_SECRET"

   # (Optional) Other API keys
   firebase functions:config:set sightengine.api_user="YOUR_USER"
   firebase functions:config:set sightengine.api_secret="YOUR_SECRET"
   ```

4. **Enable required APIs in Google Cloud:**
   - Cloud Vision API (for photo moderation)
   - Cloud Firestore
   - Cloud Storage

### Local Development

Run the Firebase emulators for local testing:

```bash
npm run serve
```

This starts:
- Functions emulator on port 5001
- Firestore emulator on port 8080
- Storage emulator on port 9199
- UI dashboard on port 4000

### Deployment

Deploy all functions:
```bash
npm run deploy
```

Deploy specific function:
```bash
firebase deploy --only functions:validateReceipt
```

## API Endpoints

### Receipt Validation

**Function:** `validateReceipt`
- **Type:** Callable
- **Auth:** Required
- **Input:**
  ```json
  {
    "receiptData": "base64_encoded_receipt",
    "productId": "premium_monthly"
  }
  ```
- **Output:**
  ```json
  {
    "success": true,
    "purchaseId": "abc123",
    "expiryDate": "2024-12-31T23:59:59Z"
  }
  ```

**Webhook:** `appleWebhook`
- **Type:** HTTPS endpoint
- **Path:** `/appleWebhook`
- **Method:** POST
- **Handles:** Subscription renewals, cancellations, refunds

### Content Moderation

**Function:** `moderatePhoto`
- **Type:** Callable
- **Auth:** Required
- **Input:**
  ```json
  {
    "photoUrl": "https://storage.googleapis.com/...",
    "userId": "user123"
  }
  ```
- **Output:**
  ```json
  {
    "approved": true,
    "reason": "Content passed moderation",
    "confidence": 0.95
  }
  ```

**Function:** `moderateText`
- **Type:** Callable
- **Auth:** Required
- **Input:**
  ```json
  {
    "text": "User bio or message",
    "contentType": "bio",
    "userId": "user123"
  }
  ```
- **Output:**
  ```json
  {
    "approved": false,
    "reason": "Flagged for: contact_info",
    "suggestions": ["Avoid sharing contact information..."]
  }
  ```

### Rate Limiting

**Function:** `recordAction`
- **Type:** Callable
- **Auth:** Required
- **Input:**
  ```json
  {
    "actionType": "swipe"
  }
  ```
- **Output:**
  ```json
  {
    "success": true,
    "remaining": 45
  }
  ```

**Action Types:**
- `swipe` - Swipe actions (50/day for free users)
- `message` - Messages (100/hour)
- `super_like` - Super likes (1/day for free users)
- `report` - User reports (5/day)
- `profile_update` - Profile updates (10/hour)
- `photo_upload` - Photo uploads (6/hour)

### Admin API

**Endpoint:** `/admin/stats`
- **Method:** GET
- **Auth:** Admin Bearer token required
- **Returns:** Platform statistics

**Endpoint:** `/admin/flagged-content`
- **Method:** GET
- **Auth:** Admin Bearer token required
- **Query params:** `limit`, `offset`, `severity`
- **Returns:** List of flagged content

**Endpoint:** `/admin/moderate-content`
- **Method:** POST
- **Auth:** Admin Bearer token required
- **Body:**
  ```json
  {
    "contentId": "flag123",
    "action": "reject",
    "reason": "Inappropriate content"
  }
  ```

## Security Rules

Update Firestore security rules to allow Cloud Functions access:

```javascript
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow Cloud Functions full access
    match /{document=**} {
      allow read, write: if request.auth.token.admin == true;
    }

    // Allow functions to write to specific collections
    match /purchases/{purchaseId} {
      allow write: if request.auth != null;
    }

    match /moderation_logs/{logId} {
      allow write: if request.auth != null;
    }
  }
}
```

## Monitoring

### Logs
View function logs:
```bash
firebase functions:log
```

### Metrics
Monitor function performance in Firebase Console:
- Invocations
- Execution time
- Error rate
- Memory usage

### Alerts
Set up alerting for:
- High error rates
- Slow function execution
- Failed receipt validations
- Excessive moderation flags

## Cost Optimization

1. **Rate Limiting:** Prevents abuse and reduces unnecessary function calls
2. **Caching:** Use Firestore for caching frequently accessed data
3. **Batch Operations:** Group Firestore writes into batches
4. **Memory Tuning:** Adjust function memory based on actual usage
5. **Cold Starts:** Keep critical functions warm with scheduled invocations

## Testing

Run unit tests:
```bash
npm test
```

Test specific function locally:
```bash
firebase functions:shell
> validateReceipt({receiptData: "...", productId: "..."})
```

## Troubleshooting

### Common Issues

1. **"Permission denied" errors**
   - Check Firestore security rules
   - Verify user authentication
   - Ensure admin claims are set correctly

2. **Receipt validation fails**
   - Verify Apple shared secret is set correctly
   - Check if using sandbox vs. production environment
   - Ensure receipt is base64 encoded

3. **Rate limiting not working**
   - Check if rate limiters are initialized
   - Verify Firestore collection exists
   - Check user premium status

4. **Vision API errors**
   - Enable Cloud Vision API in Google Cloud Console
   - Check billing is enabled
   - Verify image URL is publicly accessible

## Contributing

1. Create a feature branch
2. Make your changes
3. Test locally with emulators
4. Submit a pull request

## License

Proprietary - Celestia Dating App
