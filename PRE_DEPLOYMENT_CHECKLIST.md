# Pre-Deployment Verification Checklist

## Purpose

This checklist ensures all new functional features are properly configured, tested, and ready for production deployment before going live.

**Features Being Deployed:**
- Phone Verification System (SMS OTP)
- Photo Verification (Selfie Matching)
- Fake Profile Detection & Filtering
- User Reporting System
- Admin Moderation Dashboard

---

## Phase 1: Code Verification ✅

### Build & Compilation
- [x] All Swift files compile without errors
- [x] No warnings in critical code paths
- [x] All duplicate code removed (chunked(), StatBox)
- [x] Placeholder views cleaned up
- [x] All @MainActor annotations correct
- [x] No force unwraps in production code

**Status:** ✅ COMPLETE (All compilation errors fixed)

---

## Phase 2: Firebase Configuration ⚙️

### Firebase Console Setup

#### 2.1 Authentication Providers
Navigate to: Firebase Console → Authentication → Sign-in method

- [ ] **Email/Password Provider:** Enabled
- [ ] **Phone Provider:** Enabled (REQUIRED for phone verification)
  - [ ] Test phone numbers added (for development)
  - [ ] SMS quota sufficient (default: 10/day for free tier)
  - [ ] reCAPTCHA configured (automatic)

**Test Phone Numbers (Optional for Development):**
```
+1 650-555-3434 → Code: 123456
+1 650-555-3435 → Code: 654321
```

#### 2.2 Cloud Functions Deployment
- [ ] All 13 Cloud Functions deployed successfully
- [ ] No deployment errors
- [ ] Function logs show no errors

**Deploy Command:**
```bash
cd CloudFunctions
firebase deploy --only functions
```

**Expected Functions (13 total):**

Phone Verification (3):
- [ ] getPhoneVerificationStatus
- [ ] getUsersByPhoneStatus
- [ ] adminUpdatePhoneVerification

Reporting & Moderation (3):
- [ ] getModerationQueue
- [ ] moderateReport
- [ ] onReportCreated (Firestore trigger)

Photo Verification (3):
- [ ] verifyPhoto
- [ ] checkVerificationStatus
- [ ] getVerificationStats

Image Optimization (4):
- [ ] optimizePhoto
- [ ] getOptimizedImageURL
- [ ] migrateImageToCDN
- [ ] deleteOptimizedImage

**Verify Deployment:**
```bash
firebase functions:list
```

#### 2.3 Google Cloud APIs
Navigate to: Google Cloud Console → APIs & Services

- [ ] **Cloud Vision API:** Enabled
- [ ] **Billing:** Enabled (required for Vision API)
- [ ] **API Key:** Restricted to your project
- [ ] **Free tier quota:** Checked (1000 requests/month free)

**Enable Commands:**
```bash
gcloud services enable vision.googleapis.com
gcloud services enable cloudfunctions.googleapis.com
```

#### 2.4 Firestore Database
Navigate to: Firebase Console → Firestore Database

- [ ] Database created (Cloud Firestore, not Realtime)
- [ ] Security rules deployed
- [ ] Indexes created (auto-created by queries)

**Required Collections:**
- [ ] `users` - User profiles
- [ ] `reports` - User reports
- [ ] `moderationQueue` - Suspicious profiles queue
- [ ] `notifications` - User/admin notifications
- [ ] `adminLogs` - Admin action audit trail

**Security Rules Check:**
```bash
firebase deploy --only firestore:rules
```

#### 2.5 Firebase Storage
Navigate to: Firebase Console → Storage

- [ ] Storage bucket created
- [ ] Security rules configured
- [ ] Folders structured:
  - `/profile_photos/{userId}/{photoId}`
  - `/verification/{userId}.jpg`
  - `/optimized/{userId}/{photoId}_{transform}`

**Security Rules Check:**
```bash
firebase deploy --only storage
```

#### 2.6 Firebase Cloud Messaging (FCM)
- [ ] APNs certificates uploaded (iOS push notifications)
- [ ] APNs Authentication Key configured
- [ ] Test notification sent successfully

---

## Phase 3: Admin User Setup 👤

### Create Admin Account

1. Create admin user in Firebase Authentication (or use existing)
2. Update Firestore user document:

```javascript
// Firestore → users → {admin_user_id}
{
  email: "admin@yourdomain.com",
  isAdmin: true,  // CRITICAL: This enables admin access
  fullName: "Admin User",
  role: "admin",  // Optional
  // ... other user fields
}
```

**Verification Steps:**
- [ ] Admin user document has `isAdmin: true`
- [ ] Admin can access Profile → Admin Tools
- [ ] Admin can open Moderation Dashboard
- [ ] Non-admin users cannot access admin features

---

## Phase 4: Environment Variables 🔐

### Required Configuration

Check that these are properly configured in your build environment:

**iOS App (Celestia/Config.swift or Info.plist):**
- [ ] Firebase project ID
- [ ] Firebase API key
- [ ] Google Cloud Vision API key
- [ ] Cloudinary cloud name (for image optimization)
- [ ] Cloudinary API key
- [ ] Cloudinary API secret

**Cloud Functions (CloudFunctions/.env):**
```bash
GOOGLE_CLOUD_PROJECT=your-project-id
GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json
CLOUDINARY_CLOUD_NAME=your-cloud-name
CLOUDINARY_API_KEY=your-api-key
CLOUDINARY_API_SECRET=your-api-secret
```

- [ ] All environment variables set
- [ ] Service account has required permissions
- [ ] API keys are restricted to project domains

---

## Phase 5: Functional Testing 🧪

### 5.1 Phone Verification Testing

**Test Case 1: Successful Verification**
- [ ] Enter valid phone number (+1234567890)
- [ ] Receive SMS within 30 seconds
- [ ] Enter correct 6-digit code
- [ ] See success message
- [ ] Verification status shows in profile
- [ ] Firestore `phoneVerified: true` updated

**Test Case 2: Error Handling**
- [ ] Invalid phone number rejected
- [ ] Wrong code shows error
- [ ] Can resend code after 60 seconds
- [ ] Rate limiting works (3 attempts max)

**Firestore Verification:**
```javascript
// users/{userId}
{
  phoneNumber: "+1234567890",
  phoneVerified: true,
  phoneVerifiedAt: Timestamp(...),
  verificationMethods: ["phone"]
}
```

---

### 5.2 Photo Verification Testing

**Test Case 1: Successful Verification**
- [ ] Profile has at least 1 photo
- [ ] Take clear selfie
- [ ] Verification processes (10-30 seconds)
- [ ] Blue verified badge appears
- [ ] Firestore `photoVerified: true` updated

**Test Case 2: Verification Failure**
- [ ] Different person's selfie rejected
- [ ] Poor lighting/quality handled gracefully
- [ ] No profile photos = error message

**Test Case 3: Expiry**
- [ ] Verification expires after 90 days
- [ ] Re-verification prompt shown

**Firestore Verification:**
```javascript
// users/{userId}
{
  photoVerified: true,
  photoVerifiedAt: Timestamp(...),
  photoVerificationExpiresAt: Timestamp(... + 90 days),
  verificationMethods: ["phone", "photo"]
}
```

---

### 5.3 Fake Profile Detection Testing

**Test Case 1: Normal Profile Passes**
- [ ] Create account with 3+ photos, complete bio
- [ ] Profile appears in discovery
- [ ] No filtering occurs

**Test Case 2: Suspicious Profile Filtered**
- [ ] Create account with 0 photos
- [ ] Profile does NOT appear in discovery
- [ ] Added to moderationQueue
- [ ] Admin receives notification

**Test Case 3: Spam Detection**
- [ ] Bio with "WhatsApp me +123" filtered
- [ ] External links filtered
- [ ] Suspicious names filtered

**Firestore Verification:**
```javascript
// moderationQueue/{queueId}
{
  reportedUserId: "suspicious_user_id",
  suspicionScore: 0.85,
  indicators: ["no_photos", "suspicious_bio"],
  autoDetected: true,
  timestamp: Timestamp(...)
}
```

---

### 5.4 Reporting System Testing

**Test Case 1: Submit Report**
- [ ] View any user profile
- [ ] Tap Report User
- [ ] Select reason (Inappropriate Content)
- [ ] Add details
- [ ] Submit successfully
- [ ] Reported user blocked

**Test Case 2: Admin Notification**
- [ ] Admin receives notification immediately
- [ ] Notification includes report details
- [ ] Links to moderation dashboard

**Firestore Verification:**
```javascript
// reports/{reportId}
{
  reporterId: "user_abc",
  reportedUserId: "user_xyz",
  reason: "inappropriate_content",
  status: "pending",
  timestamp: Timestamp(...)
}
```

```javascript
// notifications/{notificationId}
{
  userId: "admin_id",
  type: "new_report",
  message: "New report: inappropriate_content",
  reportId: "report123"
}
```

---

### 5.5 Admin Moderation Dashboard Testing

**Test Case 1: Access Dashboard**
- [ ] Log in as admin
- [ ] Profile → Admin Tools visible
- [ ] Tap Moderation Dashboard
- [ ] Dashboard loads successfully

**Test Case 2: View Reports**
- [ ] Pending reports listed
- [ ] Reporter & reported user info shown
- [ ] Reasons formatted correctly
- [ ] Sorted by timestamp (newest first)

**Test Case 3: View Suspicious Profiles**
- [ ] Switch to "Suspicious" tab
- [ ] Auto-detected profiles shown
- [ ] Suspicion scores displayed
- [ ] Indicators shown as chips

**Test Case 4: Moderate - Dismiss**
- [ ] Tap report
- [ ] Select "Dismiss"
- [ ] Add reason
- [ ] Confirm
- [ ] Report moves to resolved
- [ ] No user changes

**Test Case 5: Moderate - Warn**
- [ ] Select "Warn User"
- [ ] Add reason
- [ ] Confirm
- [ ] User's warnings count incremented
- [ ] User receives notification

**Test Case 6: Moderate - Suspend**
- [ ] Select "Suspend (7 days)"
- [ ] Add reason
- [ ] Confirm
- [ ] User's `suspended: true`
- [ ] `suspendedUntil` set to +7 days
- [ ] User cannot log in

**Test Case 7: Moderate - Ban**
- [ ] Select "Ban Permanently"
- [ ] Add reason
- [ ] Confirm (double confirmation)
- [ ] User's `banned: true`
- [ ] Firebase Auth disabled
- [ ] User completely blocked
- [ ] Cannot log in

**Test Case 8: Admin Logs**
- [ ] All actions logged in `adminLogs`
- [ ] Includes adminId, action, targetUserId
- [ ] Timestamp recorded

---

## Phase 6: Security Testing 🔒

### 6.1 Authentication Security
- [ ] Cannot access admin dashboard without `isAdmin: true`
- [ ] Cloud Functions check authentication
- [ ] Cannot moderate reports as non-admin
- [ ] Phone verification requires valid SMS code

### 6.2 Firestore Security Rules
- [ ] Users can only read/write their own data
- [ ] Cannot modify another user's verification status
- [ ] Cannot read other users' phone numbers
- [ ] Admin-only collections protected

**Test Security Rules:**
```bash
firebase emulators:start --only firestore
# Run security rules tests
firebase emulators:exec --only firestore "npm test"
```

### 6.3 Data Privacy
- [ ] Phone numbers encrypted/protected
- [ ] Verification selfies stored securely
- [ ] User reports anonymized in admin view
- [ ] GDPR compliance checked

### 6.4 Rate Limiting
- [ ] Phone verification: 3 attempts per day
- [ ] Reporting: Cannot spam reports
- [ ] API endpoints rate limited
- [ ] Cloud Functions have reasonable timeouts

---

## Phase 7: Performance Testing ⚡

### 7.1 Load Times
- [ ] Discovery feed loads < 2 seconds
- [ ] Phone verification UI responsive
- [ ] Admin dashboard loads < 3 seconds
- [ ] Photo verification processes < 30 seconds

### 7.2 Fake Profile Detection Impact
- [ ] Discovery with 100 profiles: < 3 seconds
- [ ] Image analysis doesn't block UI
- [ ] Suspicion score calculation fast (< 100ms per profile)

### 7.3 Cloud Functions Performance
- [ ] `getModerationQueue`: < 2 seconds
- [ ] `moderateReport`: < 1 second
- [ ] `verifyPhoto`: < 30 seconds (Vision API)
- [ ] `onReportCreated` trigger: < 500ms

### 7.4 Memory Usage
- [ ] App doesn't leak memory during verification
- [ ] Image loading optimized
- [ ] Real-time listeners cleaned up properly

---

## Phase 8: Analytics & Monitoring 📊

### 8.1 Firebase Analytics Events
- [ ] `phone_verification_started` tracked
- [ ] `phone_verification_completed` tracked
- [ ] `photo_verification_completed` tracked
- [ ] `report_submitted` tracked
- [ ] `moderation_action_taken` tracked

### 8.2 Error Tracking
- [ ] Crashlytics configured
- [ ] Phone verification errors logged
- [ ] Cloud Function errors monitored
- [ ] Vision API errors tracked

### 8.3 Usage Metrics
- [ ] Track verification completion rate
- [ ] Track fake profile detection rate
- [ ] Track admin response time
- [ ] Track ban/suspend rates

**Setup Monitoring:**
```bash
# Firebase Console → Analytics → Events
# Firebase Console → Functions → Logs
# Firebase Console → Crashlytics
```

---

## Phase 9: User Acceptance Testing (UAT) 👥

### 9.1 Beta Testing
- [ ] Invite 10-20 beta users
- [ ] Test phone verification with real devices
- [ ] Collect feedback on UX
- [ ] Verify SMS delivery across carriers
- [ ] Test on different iOS versions (16.0+)

### 9.2 Device Testing
- [ ] iPhone 14 Pro (iOS 17)
- [ ] iPhone 13 (iOS 16)
- [ ] iPhone SE (iOS 16)
- [ ] iPad Pro (iOS 17)
- [ ] Different carriers (AT&T, Verizon, T-Mobile)

### 9.3 Edge Cases
- [ ] No network during verification
- [ ] App backgrounded during SMS wait
- [ ] Multiple verification attempts
- [ ] Verification expiry edge cases

---

## Phase 10: Documentation 📝

### 10.1 Internal Documentation
- [x] DEPLOYMENT_GUIDE.md created
- [x] FUNCTIONAL_IMPROVEMENTS_SUMMARY.md created
- [x] APP_NOW_FULLY_FUNCTIONAL.md created
- [x] TESTING_GUIDE.md exists
- [x] PRE_DEPLOYMENT_CHECKLIST.md (this file)
- [ ] API documentation for Cloud Functions
- [ ] Admin user manual

### 10.2 User-Facing Documentation
- [ ] Help center articles for phone verification
- [ ] FAQ for photo verification
- [ ] Community guidelines updated
- [ ] Privacy policy updated (mention verification)
- [ ] Terms of service updated

### 10.3 Support Materials
- [ ] Customer support scripts
- [ ] Troubleshooting guides
- [ ] Admin training materials

---

## Phase 11: Backup & Rollback Plan 🔄

### 11.1 Pre-Deployment Backup
- [ ] Firestore backup created
- [ ] Firebase Auth users exported
- [ ] Storage bucket snapshot
- [ ] Git tag created for current stable version

**Backup Commands:**
```bash
# Firestore backup
gcloud firestore export gs://your-bucket/backup-$(date +%Y%m%d)

# Git tag
git tag -a v2.0.0-pre-deployment -m "Pre-deployment backup"
git push origin v2.0.0-pre-deployment
```

### 11.2 Rollback Procedures
- [ ] Document how to disable phone auth
- [ ] Document how to pause Cloud Functions
- [ ] Document how to restore Firestore backup
- [ ] Keep previous app version for emergency rollback

**Emergency Rollback:**
```bash
# Disable phone auth in console immediately
# Pause Cloud Functions
firebase functions:delete getModerationQueue --force
firebase functions:delete moderateReport --force

# Restore Firestore
gcloud firestore import gs://your-bucket/backup-YYYYMMDD
```

---

## Phase 12: Launch Checklist 🚀

### 12.1 Pre-Launch (T-24 hours)
- [ ] All tests passing
- [ ] Beta testing complete
- [ ] Support team briefed
- [ ] Monitoring dashboards ready
- [ ] Backup completed
- [ ] Rollback plan tested

### 12.2 Launch (T-0)
- [ ] Deploy Cloud Functions
- [ ] Enable Phone Authentication
- [ ] Submit iOS app update to App Store
- [ ] Update status page
- [ ] Monitor error rates
- [ ] Watch Cloud Functions logs

### 12.3 Post-Launch (T+24 hours)
- [ ] Monitor verification completion rates
- [ ] Check error rates (should be < 1%)
- [ ] Review user feedback
- [ ] Check admin dashboard usage
- [ ] Verify no performance regressions
- [ ] Confirm SMS delivery success rate > 95%

### 12.4 Post-Launch (T+7 days)
- [ ] Analyze verification adoption rate
- [ ] Review fake profile detection effectiveness
- [ ] Check admin moderation response times
- [ ] Gather user satisfaction feedback
- [ ] Optimize based on usage patterns

---

## Phase 13: Cost Monitoring 💰

### 13.1 Firebase Costs
- [ ] Monitor Firestore read/write operations
- [ ] Track Cloud Functions invocations
- [ ] Check Storage usage
- [ ] Review Firebase Auth usage

**Expected Costs (10,000 active users):**
- Phone Authentication: Free (included)
- Cloud Functions: ~$5-20/month
- Firestore: ~$10-30/month
- Storage: ~$5-15/month
- **Total: ~$20-65/month**

### 13.2 Google Cloud Vision API
- [ ] Monitor API calls
- [ ] Track costs per verification
- [ ] Optimize image sizes to reduce costs

**Expected Costs:**
- Free tier: 1,000 requests/month
- Beyond: $1.50 per 1,000 requests
- **Estimated: $10-30/month for 10K users**

### 13.3 Cost Alerts
- [ ] Set billing alerts in Firebase Console
- [ ] Budget: $100/month (adjust as needed)
- [ ] Alert threshold: 50%, 80%, 100%

---

## Phase 14: Legal & Compliance ⚖️

### 14.1 Privacy Compliance
- [ ] GDPR compliance verified (if EU users)
- [ ] CCPA compliance verified (if California users)
- [ ] Privacy policy mentions:
  - Phone number collection
  - SMS verification process
  - Selfie verification and storage
  - Data retention policies
  - Right to deletion

### 14.2 Terms of Service
- [ ] Community guidelines updated
- [ ] Verification requirements stated
- [ ] Moderation policies documented
- [ ] Appeal process defined
- [ ] Ban/suspension terms clear

### 14.3 SMS Compliance
- [ ] TCPA compliance (US)
- [ ] Clear opt-in for SMS
- [ ] Unsubscribe mechanism (not applicable for verification)
- [ ] Carrier terms respected

---

## Final Sign-Off ✅

### Development Team
- [ ] All code reviewed and approved
- [ ] Tests passing (200+ unit tests)
- [ ] No critical bugs
- [ ] Documentation complete

**Signed:** _________________ Date: _______

### QA Team
- [ ] Manual testing complete
- [ ] All test cases passed
- [ ] Edge cases tested
- [ ] UAT successful

**Signed:** _________________ Date: _______

### Product Owner
- [ ] Features meet requirements
- [ ] UX acceptable
- [ ] Ready for production
- [ ] Launch approved

**Signed:** _________________ Date: _______

---

## Emergency Contacts 🚨

**If issues arise during/after deployment:**

- Firebase Support: https://firebase.google.com/support
- Google Cloud Support: https://cloud.google.com/support
- Development Team Lead: [Contact]
- On-Call Engineer: [Contact]
- Product Manager: [Contact]

---

## Deployment Timeline 📅

**Recommended Schedule:**

```
Week 1: Configuration & Setup
├── Day 1-2: Firebase Console configuration
├── Day 3: Deploy Cloud Functions
├── Day 4: Create admin users
└── Day 5: Internal testing

Week 2: Testing & Validation
├── Day 1-2: Functional testing (all features)
├── Day 3: Security testing
├── Day 4: Performance testing
└── Day 5: Fix any issues found

Week 3: Beta Testing
├── Day 1: Invite beta users
├── Day 2-4: Monitor beta usage
├── Day 5: Collect and analyze feedback

Week 4: Launch
├── Day 1: Final checks
├── Day 2: Deploy to production
├── Day 3-5: Monitor and support
└── Day 6-7: Post-launch review
```

---

## Success Criteria ✨

The deployment is considered successful when:

1. **Functionality:**
   - ✅ Phone verification works with >95% success rate
   - ✅ Photo verification processes within 30 seconds
   - ✅ Fake profiles filtered effectively (>80% accuracy)
   - ✅ Reporting system processes 100% of submissions
   - ✅ Admin dashboard accessible and functional

2. **Performance:**
   - ✅ App load time < 3 seconds
   - ✅ Discovery feed < 2 seconds with filtering
   - ✅ No crashes or memory leaks
   - ✅ Cloud Functions respond < 2 seconds

3. **Security:**
   - ✅ No unauthorized access to admin features
   - ✅ User data properly protected
   - ✅ Security rules enforced

4. **User Experience:**
   - ✅ Clear error messages
   - ✅ Smooth verification flows
   - ✅ Positive user feedback
   - ✅ < 5% user-reported issues

5. **Business Metrics:**
   - ✅ Verification adoption rate > 60%
   - ✅ Fake profile complaints decreased by 70%
   - ✅ Admin response time < 2 hours
   - ✅ User satisfaction maintained/improved

---

## Post-Deployment Monitoring Dashboard 📈

**Key Metrics to Track:**

### Daily (First Week)
- Phone verifications started vs completed
- Photo verifications started vs completed
- Fake profiles detected and filtered
- Reports submitted
- Admin actions taken (dismiss/warn/suspend/ban)
- Error rates for each feature
- SMS delivery success rate

### Weekly (First Month)
- Overall verification adoption rate
- Fake profile detection accuracy
- User complaints about fake profiles (should decrease)
- Admin workload (should decrease with auto-filtering)
- Feature-related support tickets
- Cloud Function costs
- Vision API costs

### Monthly (Ongoing)
- Verification completion trends
- Fake profile trends
- Moderation effectiveness
- Cost per user
- Feature ROI

---

**Status:** Ready for Phase 2 (Firebase Configuration)

**Last Updated:** November 19, 2025
**Version:** 1.0
**Branch:** `claude/code-review-qa-01WQffHnyJCaGsGjCtJY6Tro`
