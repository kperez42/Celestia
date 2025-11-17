# Backend API Deployment Guide

**Status**: 🔴 CRITICAL - Must Deploy Before Production
**Risk**: Purchase fraud, content moderation bypass, rate limit bypass
**Estimated Revenue at Risk**: $5,000-10,000+ monthly
**Deployment Time**: 2-4 hours

---

## Overview

Your Celestia app has a fully implemented **Backend API client** (`BackendAPIService.swift`) but the **backend endpoints are NOT deployed**. This means:

- ❌ No receipt validation → Purchase fraud risk
- ❌ No server-side content moderation → Spam/abuse risk
- ❌ No server-side rate limiting → API abuse risk
- ❌ No server-side report handling → Safety issues

**The code exists in `CloudFunctions/` but needs deployment.**

---

## Prerequisites

### 1. Firebase CLI Installed

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Verify installation
firebase --version
```

### 2. Node.js & Dependencies

```bash
cd CloudFunctions

# Install dependencies
npm install

# Verify package.json
cat package.json
```

**Expected dependencies**:
- `firebase-functions`
- `firebase-admin`
- `express`
- `cors`
- `stripe` (for payment processing)

---

## Step 1: Configure Firebase Project

```bash
# Initialize Firebase (if not already done)
firebase init

# Select:
# - Functions: Configure Cloud Functions
# - Use existing project: <your-project-id>
# - Language: JavaScript or TypeScript
# - Install dependencies: Yes

# Link to your Firebase project
firebase use <your-project-id>

# Example:
firebase use celestia-dating-app
```

---

## Step 2: Review Cloud Functions Code

### Check Implemented Endpoints

**Location**: `CloudFunctions/index.js` or `CloudFunctions/modules/`

**Expected Endpoints**:

1. **Receipt Validation** (CRITICAL)
   ```javascript
   // POST /api/validate-receipt
   exports.validateReceipt = functions.https.onRequest(async (req, res) => {
       // Validate App Store receipt
       // Prevent purchase fraud
   })
   ```

2. **Content Moderation**
   ```javascript
   // POST /api/moderate-content
   exports.moderateContent = functions.https.onRequest(async (req, res) => {
       // Check for profanity, spam, personal info
   })
   ```

3. **Rate Limiting**
   ```javascript
   // POST /api/check-rate-limit
   exports.checkRateLimit = functions.https.onRequest(async (req, res) => {
       // Enforce server-side rate limits
   })
   ```

4. **Report Handling**
   ```javascript
   // POST /api/handle-report
   exports.handleReport = functions.https.onRequest(async (req, res) => {
       // Process user reports
       // Flag for moderation
   })
   ```

### Verify Functions Exist

```bash
# List all functions in code
grep -r "exports\." CloudFunctions/

# Expected output:
# exports.validateReceipt = ...
# exports.moderateContent = ...
# exports.checkRateLimit = ...
# exports.handleReport = ...
```

---

## Step 3: Environment Configuration

### Set Environment Variables

```bash
# Navigate to Cloud Functions directory
cd CloudFunctions

# Set environment variables
firebase functions:config:set \
  stripe.secret_key="sk_live_..." \
  app_store.shared_secret="..." \
  openai.api_key="sk-..." \
  app.jwt_secret="your-secret-key"

# View current config
firebase functions:config:get

# Output:
# {
#   "stripe": {
#     "secret_key": "sk_live_..."
#   },
#   "app_store": {
#     "shared_secret": "..."
#   }
# }
```

### Create .env File (for local testing)

```bash
# Create .env file
cat > CloudFunctions/.env << EOF
STRIPE_SECRET_KEY=sk_test_...
APP_STORE_SHARED_SECRET=...
FIREBASE_DATABASE_URL=https://your-project.firebaseio.com
JWT_SECRET=your-jwt-secret
EOF

# Add to .gitignore
echo "CloudFunctions/.env" >> .gitignore
```

---

## Step 4: Local Testing (IMPORTANT)

**Before deploying to production, test locally:**

```bash
# Install Firebase emulator
firebase init emulators

# Start emulator suite
firebase emulators:start

# Output:
# ✔  functions: Functions Emulator running on http://localhost:5001
# ✔  firestore: Firestore Emulator running on http://localhost:8080

# Test endpoint
curl -X POST http://localhost:5001/<project-id>/us-central1/validateReceipt \
  -H "Content-Type: application/json" \
  -d '{
    "receipt": "test_receipt_data",
    "userId": "test_user_123"
  }'

# Expected response:
# {
#   "valid": true,
#   "productId": "celestia_premium_monthly",
#   "expirationDate": "2025-02-17T..."
# }
```

### Test All Critical Endpoints

```bash
# 1. Receipt Validation
curl -X POST http://localhost:5001/<project-id>/us-central1/validateReceipt \
  -d '{"receipt":"...","userId":"test123"}'

# 2. Content Moderation
curl -X POST http://localhost:5001/<project-id>/us-central1/moderateContent \
  -d '{"text":"Test message","userId":"test123"}'

# 3. Rate Limiting
curl -X POST http://localhost:5001/<project-id>/us-central1/checkRateLimit \
  -d '{"userId":"test123","action":"send_message"}'

# 4. Report Handling
curl -X POST http://localhost:5001/<project-id>/us-central1/handleReport \
  -d '{"reporterId":"test123","reportedUserId":"test456","reason":"spam"}'
```

**Verify**: All endpoints return expected responses without errors

---

## Step 5: Deploy to Production

### Deploy All Functions

```bash
# Deploy all functions
firebase deploy --only functions

# Output:
# ✔  functions: Finished running predeploy script.
# i  functions: ensuring required API cloudfunctions.googleapis.com is enabled...
# ✔  functions: required API cloudfunctions.googleapis.com is enabled
# i  functions: preparing functions directory for uploading...
# i  functions: packaged functions (50.23 KB) for uploading
# ✔  functions: functions folder uploaded successfully
# i  functions: creating function validateReceipt...
# i  functions: creating function moderateContent...
# i  functions: creating function checkRateLimit...
# i  functions: creating function handleReport...
# ✔  functions[validateReceipt(us-central1)]: Successful create operation.
# ✔  functions[moderateContent(us-central1)]: Successful create operation.
# ✔  functions[checkRateLimit(us-central1)]: Successful create operation.
# ✔  functions[handleReport(us-central1)]: Successful create operation.
#
# Function URL (validateReceipt): https://us-central1-<project-id>.cloudfunctions.net/validateReceipt
```

### Deploy Specific Function (if needed)

```bash
# Deploy only receipt validation
firebase deploy --only functions:validateReceipt

# Deploy multiple specific functions
firebase deploy --only functions:validateReceipt,functions:moderateContent
```

---

## Step 6: Update iOS App Configuration

### Update Base URL in Constants.swift

**File**: `Celestia/Constants.swift:14`

**Before**:
```swift
static let baseURL = "https://api.celestia.app"  // NOT DEPLOYED
```

**After**:
```swift
static let baseURL = "https://us-central1-<your-project-id>.cloudfunctions.net/api"

// Example:
// static let baseURL = "https://us-central1-celestia-prod-abc123.cloudfunctions.net/api"
```

**Find your project ID**:
```bash
firebase projects:list

# Output:
# ┌──────────────────────┬────────────────────┬──────────────┐
# │ Project Display Name │ Project ID         │ Resource ID  │
# ├──────────────────────┼────────────────────┼──────────────┤
# │ Celestia Dating      │ celestia-prod-a1b2 │ ...          │
# └──────────────────────┴────────────────────┴──────────────┘
```

### Rebuild and Test iOS App

```bash
# Build iOS app
xcodebuild -project Celestia.xcodeproj \
  -scheme Celestia \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build

# Run app and test:
# 1. Make a test purchase → Verify receipt validation works
# 2. Send a message with profanity → Verify moderation works
# 3. Send multiple messages quickly → Verify rate limiting works
# 4. Report a user → Verify report handling works
```

---

## Step 7: Verify Deployment

### Check Function Status

```bash
# List deployed functions
firebase functions:list

# Output:
# ┌─────────────────────┬──────────────────┬────────────┐
# │ Name                │ Region           │ Status     │
# ├─────────────────────┼──────────────────┼────────────┤
# │ validateReceipt     │ us-central1      │ ACTIVE     │
# │ moderateContent     │ us-central1      │ ACTIVE     │
# │ checkRateLimit      │ us-central1      │ ACTIVE     │
# │ handleReport        │ us-central1      │ ACTIVE     │
# └─────────────────────┴──────────────────┴────────────┘
```

### Test Production Endpoints

```bash
# Get function URLs
firebase functions:config:get

# Test receipt validation (production)
curl -X POST https://us-central1-<project-id>.cloudfunctions.net/validateReceipt \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <firebase-id-token>" \
  -d '{
    "receipt": "test_receipt",
    "userId": "actual_user_id"
  }'

# Expected: 200 OK with validation result
```

### Monitor Function Logs

```bash
# View real-time logs
firebase functions:log

# Filter by function
firebase functions:log --only validateReceipt

# View last 100 lines
firebase functions:log --lines 100
```

---

## Step 8: Enable CORS (if needed)

**Problem**: iOS app might get CORS errors

**Solution**: Update Cloud Functions to allow CORS

```javascript
// CloudFunctions/index.js
const cors = require('cors')({
    origin: true  // Allow all origins (or specify your domain)
})

exports.validateReceipt = functions.https.onRequest((req, res) => {
    return cors(req, res, async () => {
        // Your function logic
    })
})
```

**Redeploy after changes**:
```bash
firebase deploy --only functions
```

---

## Step 9: Set Up Monitoring

### Enable Cloud Functions Metrics

**Firebase Console** → **Functions** → **Dashboard**

Monitor:
- Invocations per minute
- Execution time (p50, p95, p99)
- Error rate
- Memory usage

### Set Up Alerts

```bash
# Create alert for high error rate
gcloud alpha monitoring policies create \
  --notification-channels=<channel-id> \
  --display-name="Cloud Functions Error Rate" \
  --condition-display-name="Error rate > 5%" \
  --condition-threshold-value=0.05 \
  --condition-threshold-duration=60s
```

### Add Crashlytics Integration

```swift
// Celestia/BackendAPIService.swift
func validateReceipt(...) async throws {
    do {
        let response = try await performRequest(...)
        return response
    } catch {
        // Log to Crashlytics
        Crashlytics.crashlytics().record(error: error)

        // Log backend errors specifically
        AnalyticsManager.shared.logEvent(.backendError, parameters: [
            "endpoint": "validateReceipt",
            "error": error.localizedDescription
        ])

        throw error
    }
}
```

---

## Cost Estimation

### Firebase Cloud Functions Pricing

**Free Tier** (per month):
- 2 million invocations
- 400,000 GB-seconds compute time
- 200,000 CPU-seconds
- 5 GB network egress

**Paid Tier** (after free tier):
- $0.40 per million invocations
- $0.0000025 per GB-second compute time
- $0.10 per GB network egress

### Estimated Costs for Celestia

**Assumptions**:
- 10,000 daily active users
- 5 API calls per user per day
- Average execution time: 200ms
- Average memory: 256MB

**Monthly Costs**:
- Invocations: 10K × 5 × 30 = 1.5M (within free tier)
- Compute: 1.5M × 0.2s × 0.256GB = 76,800 GB-seconds ($192/month)
- Network: Negligible for JSON responses

**Total Estimated Cost**: ~$200-300/month

**ROI**: Prevents $5,000-10,000+ fraud → 20-50x ROI

---

## Troubleshooting

### Function Not Found (404)

**Problem**: `https://...cloudfunction.net/validateReceipt` returns 404

**Solutions**:
```bash
# 1. Check function is deployed
firebase functions:list

# 2. Check function name matches
grep "exports.validateReceipt" CloudFunctions/index.js

# 3. Redeploy
firebase deploy --only functions:validateReceipt

# 4. Check region (default: us-central1)
# Update iOS app baseURL if different region
```

### CORS Errors

**Problem**: iOS app gets "No 'Access-Control-Allow-Origin' header"

**Solution**: Add CORS middleware (see Step 8)

### Timeout Errors

**Problem**: Function times out (default: 60s)

**Solution**: Increase timeout
```javascript
exports.validateReceipt = functions
    .runWith({
        timeoutSeconds: 300,  // 5 minutes
        memory: '512MB'
    })
    .https.onRequest(...)
```

### Authentication Errors

**Problem**: Function returns 401 Unauthorized

**Solution**: Verify Firebase ID token in request
```swift
// Celestia/BackendAPIService.swift
func performRequest(...) async throws {
    guard let idToken = try? await Auth.auth().currentUser?.getIDToken() else {
        throw BackendError.unauthorized
    }

    var request = URLRequest(url: url)
    request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

    // ... continue with request
}
```

**Backend verification**:
```javascript
const admin = require('firebase-admin')

async function verifyAuth(req, res, next) {
    const authHeader = req.headers.authorization
    if (!authHeader?.startsWith('Bearer ')) {
        return res.status(401).send('Unauthorized')
    }

    const idToken = authHeader.split('Bearer ')[1]
    try {
        const decodedToken = await admin.auth().verifyIdToken(idToken)
        req.user = decodedToken
        next()
    } catch (error) {
        return res.status(401).send('Invalid token')
    }
}
```

---

## Security Best Practices

### 1. Rate Limiting on Functions

```javascript
const rateLimit = require('express-rate-limit')

const limiter = rateLimit({
    windowMs: 15 * 60 * 1000,  // 15 minutes
    max: 100  // Limit each user to 100 requests per windowMs
})

app.use('/api/', limiter)
```

### 2. Input Validation

```javascript
const Joi = require('joi')

const receiptSchema = Joi.object({
    receipt: Joi.string().required(),
    userId: Joi.string().required()
})

exports.validateReceipt = functions.https.onRequest(async (req, res) => {
    const { error, value } = receiptSchema.validate(req.body)
    if (error) {
        return res.status(400).send({ error: error.details[0].message })
    }

    // Continue with validated data
})
```

### 3. Secrets Management

```bash
# Store sensitive keys in Secret Manager (not functions config)
echo -n "sk_live_..." | gcloud secrets create stripe-secret-key \
    --data-file=- \
    --replication-policy="automatic"

# Grant access to Cloud Functions
gcloud secrets add-iam-policy-binding stripe-secret-key \
    --member="serviceAccount:<project-id>@appspot.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
```

Access in function:
```javascript
const { SecretManagerServiceClient } = require('@google-cloud/secret-manager')
const client = new SecretManagerServiceClient()

async function getSecret(name) {
    const [version] = await client.accessSecretVersion({
        name: `projects/<project-id>/secrets/${name}/versions/latest`
    })
    return version.payload.data.toString()
}

// Usage
const stripeKey = await getSecret('stripe-secret-key')
```

---

## Post-Deployment Checklist

- [ ] All functions deployed successfully
- [ ] Function URLs obtained
- [ ] iOS app Constants.swift updated
- [ ] iOS app rebuilt and tested
- [ ] Receipt validation working
- [ ] Content moderation working
- [ ] Rate limiting working
- [ ] Report handling working
- [ ] CORS configured (if needed)
- [ ] Monitoring enabled
- [ ] Alerts configured
- [ ] Logs reviewed (no errors)
- [ ] Cost estimation reviewed
- [ ] Documentation updated

---

## Rollback Plan

**If deployment fails or causes issues:**

```bash
# 1. List function versions
firebase functions:list --detailed

# 2. Rollback to previous version
firebase functions:rollback <function-name> <version-number>

# 3. Revert iOS app change
# Change Constants.swift back to old URL (or disable backend calls)

# 4. Debug issue
firebase functions:log --only <function-name>

# 5. Fix and redeploy
# Make code changes
firebase deploy --only functions:<function-name>
```

---

## Support & Resources

- **Firebase Documentation**: https://firebase.google.com/docs/functions
- **Cloud Functions Pricing**: https://firebase.google.com/pricing
- **Firebase Support**: https://firebase.google.com/support
- **Stack Overflow**: Tag `firebase-cloud-functions`

---

**Deployment Owner**: Backend Team
**Last Updated**: 2025-01-17
**Status**: Ready for deployment
**Priority**: 🔴 CRITICAL - Deploy ASAP
