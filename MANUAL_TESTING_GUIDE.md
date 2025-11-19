# Manual Testing Guide - New Safety Features

Quick reference guide for manually testing the newly implemented safety and moderation features.

---

## 📱 1. Phone Verification

### Setup Required
- Real phone number or Firebase test number
- Phone Auth enabled in Firebase Console

### Test: Happy Path ✅

**Steps:**
1. Open app → Profile → Safety Center
2. Tap "Phone Verification"
3. Enter phone: `+1234567890` (your real number)
4. Tap "Send Code"
5. Check SMS on phone
6. Enter 6-digit code
7. Code auto-submits when complete

**Expected:**
- ✅ SMS received within 30 seconds
- ✅ Code entry has 6 boxes
- ✅ Auto-submits without tapping button
- ✅ Success animation shows
- ✅ View dismisses
- ✅ Profile shows "Phone Verified" with checkmark

**Firestore Check:**
```javascript
users/{userId}
  phoneVerified: true ✓
  phoneNumber: "+1234567890" ✓
  phoneVerifiedAt: <timestamp> ✓
```

### Test: Error Cases ❌

**Invalid Phone Number:**
- Enter `123` → Should show error "Invalid phone number"
- Enter `abcd` → Should disable Send button

**Wrong Code:**
- Enter incorrect code `000000` → Should show "Invalid code"
- Can retry

**Resend Code:**
- Wait 60 seconds
- Tap "Resend Code"
- New SMS arrives
- Old code no longer works

---

## 📷 2. Photo Verification

### Setup Required
- User must have at least 1 profile photo uploaded
- Google Cloud Vision API enabled

### Test: Happy Path ✅

**Steps:**
1. Ensure profile has 1+ photos
2. Profile → Safety Center → "Get Verified"
3. Allow camera access
4. Take clear selfie (same person as profile)
5. Tap "Use Photo"
6. Wait 10-30 seconds for processing

**Expected:**
- ✅ Camera opens with instructions
- ✅ Can retake photo
- ✅ Processing spinner shows
- ✅ Success: "Photo Verified!"
- ✅ Blue verified badge on profile
- ✅ Badge visible to other users

**Firestore Check:**
```javascript
users/{userId}
  photoVerified: true ✓
  photoVerifiedAt: <timestamp> ✓
  photoVerificationExpiresAt: <timestamp + 90 days> ✓
```

### Test: Failure Cases ❌

**Different Person:**
- Upload photo of Person A
- Take selfie of Person B
- Should fail: "Photo doesn't match profile"

**No Profile Photos:**
- Account with 0 photos
- Attempt verification
- Should show: "Add profile photos first"

**Poor Quality:**
- Very dark/blurry selfie
- May fail or ask to retake

---

## 🛡️ 3. Fake Profile Detection

### Setup Required
- Create test accounts
- Admin account with `isAdmin: true`

### Test: Normal Profile Passes ✅

**Create Test Account:**
```
Email: test1@test.com
Name: Sarah Johnson
Age: 28
Photos: 3 real photos
Bio: "Love hiking and coffee. Always up for an adventure!"
```

**Steps:**
1. Log in with different account
2. Load discovery feed
3. Look for Sarah's profile

**Expected:**
- ✅ Profile appears in discovery
- ✅ Can swipe on profile
- ✅ No filtering applied

### Test: Suspicious Profile Filtered ❌

**Create Suspicious Account:**
```
Email: spam@test.com
Name: xxx
Age: 99
Photos: 0 photos (EMPTY)
Bio: "WhatsApp me +1234567890"
```

**Steps:**
1. Log in with different account
2. Load discovery feed
3. Check if spam account visible

**Expected:**
- ❌ Profile does NOT appear
- ✅ Console shows: "Filtered 1 suspicious profile"
- ✅ Admin receives notification

**Firestore Check:**
```javascript
moderationQueue/{queueId}
  reportedUserId: "spam_user_id" ✓
  suspicionScore: 0.85 ✓
  indicators: ["no_photos", "suspicious_bio"] ✓
  autoDetected: true ✓
```

**Admin Check:**
1. Log in as admin
2. Check notifications → "Suspicious profile detected"
3. Moderation Dashboard → "Suspicious" tab
4. See spam account listed

### Test Cases Matrix

| Profile Type | Photos | Bio | Name | Should Appear? |
|-------------|--------|-----|------|----------------|
| Normal | 3+ | Real | Sarah Johnson | ✅ Yes |
| Suspicious | 0 | "Contact me..." | Jessica | ❌ No |
| Suspicious | 1 | Real | asdfghjkl | ❌ No |
| Suspicious | 2 | "bit.ly/..." | John | ❌ No |

---

## 🚨 4. User Reporting

### Test: Submit Report ✅

**Steps:**
1. View any user profile
2. Tap menu (•••) in top right
3. Select "Report User"
4. Select reason: "Inappropriate Content"
5. Add details (optional): "Profile contains explicit photos"
6. Tap "Submit Report"

**Expected:**
- ✅ Success message: "Report submitted"
- ✅ Reported user automatically blocked
- ✅ View dismisses back to discovery
- ✅ Cannot see reported user again

**Firestore Check:**
```javascript
reports/{reportId}
  reporterId: "your_user_id" ✓
  reportedUserId: "reported_user_id" ✓
  reason: "inappropriate_content" ✓
  status: "pending" ✓
  timestamp: <timestamp> ✓
```

**Admin Notification:**
1. Log in as admin
2. Check notifications
3. Should see: "New report: inappropriate_content"

### Test: All Report Reasons

Test each reason works:
- [ ] Inappropriate Content
- [ ] Harassment
- [ ] Spam/Scam
- [ ] Fake Profile
- [ ] Underage User
- [ ] Other

Each should:
- ✅ Create report in Firestore
- ✅ Notify admins
- ✅ Block user for reporter

---

## 👨‍💼 5. Admin Moderation Dashboard

### Setup Required
- User account with `isAdmin: true` in Firestore
- At least 1 pending report (create using steps above)

### Test: Access Dashboard ✅

**Steps:**
1. Log in as admin user
2. Go to Profile
3. Look for "Admin Tools" section

**Expected:**
- ✅ "Admin Tools" section visible (admins only)
- ✅ "Moderation Dashboard" button present
- ✅ Non-admins don't see this section

### Test: View Reports Queue ✅

**Steps:**
1. Tap "Moderation Dashboard"
2. View "Reports" tab (default)

**Expected:**
- ✅ List of pending reports
- ✅ Each shows:
  - Reporter photo/name
  - Reported user photo/name
  - Reason (formatted nicely)
  - Timestamp (e.g., "2 hours ago")
  - Status badge (yellow "Pending")
- ✅ Pull to refresh works
- ✅ Sorted by newest first

### Test: View Suspicious Profiles ✅

**Steps:**
1. Switch to "Suspicious" tab
2. View auto-detected profiles

**Expected:**
- ✅ List of suspicious profiles
- ✅ Each shows:
  - User photo/name
  - Suspicion score (e.g., "0.85")
  - Indicator chips (e.g., "No Photos", "Suspicious Bio")
  - Timestamp
- ✅ Sorted by highest score first

### Test: View Statistics ✅

**Steps:**
1. Switch to "Stats" tab

**Expected:**
- ✅ Total Reports count
- ✅ Pending Reports count
- ✅ Resolved Reports count
- ✅ Suspicious Profiles count
- ✅ Color-coded stat boxes

### Test: Moderate - Dismiss ⚠️

**Steps:**
1. Tap any report from queue
2. View report details
3. Scroll to "Moderation Actions"
4. Select: "Dismiss"
5. Add reason: "False report, no violation"
6. Tap "Confirm Action"

**Expected:**
- ✅ Confirmation dialog
- ✅ Report disappears from pending
- ✅ Reported user unchanged (no penalty)
- ✅ Admin action logged

**Firestore Check:**
```javascript
reports/{reportId}
  status: "resolved" ✓
  action: "dismiss" ✓
  moderatedBy: "admin_id" ✓
  moderationReason: "False report, no violation" ✓

adminLogs/{logId}
  adminId: "admin_id" ✓
  action: "moderate_report_dismiss" ✓
  reportId: "report123" ✓
```

### Test: Moderate - Warn ⚠️

**Steps:**
1. Select report
2. Choose: "Warn User"
3. Add reason: "First offense - community guidelines warning"
4. Confirm

**Expected:**
- ✅ Report resolved
- ✅ User receives warning notification
- ✅ Warning count incremented

**Firestore Check:**
```javascript
users/{reported_user_id}
  warnings: 1 ✓  (incremented)
  lastWarnedAt: <timestamp> ✓
  lastWarningReason: "First offense..." ✓

notifications/{notificationId}
  userId: "reported_user_id" ✓
  type: "warning" ✓
  message: "Community Guidelines Warning" ✓
```

### Test: Moderate - Suspend 🚫

**Steps:**
1. Select report
2. Choose: "Suspend (7 days)"
3. Add reason: "Multiple violations - temporary suspension"
4. Confirm

**Expected:**
- ✅ Report resolved
- ✅ User account suspended
- ✅ User cannot log in

**Firestore Check:**
```javascript
users/{reported_user_id}
  suspended: true ✓
  suspendedUntil: <timestamp + 7 days> ✓
  suspensionReason: "Multiple violations..." ✓
```

**Login Test:**
1. Log out
2. Try to log in as suspended user
3. Should see: "Your account is suspended until [date]"

### Test: Moderate - Ban 🔨

**Steps:**
1. Select report
2. Choose: "Ban Permanently"
3. Add reason: "Repeated harassment, permanent ban"
4. Confirm
5. **Second confirmation** (destructive action)
6. Confirm again

**Expected:**
- ✅ Double confirmation required
- ✅ Report resolved
- ✅ User account banned
- ✅ Firebase Auth disabled
- ✅ User completely blocked

**Firestore Check:**
```javascript
users/{reported_user_id}
  banned: true ✓
  bannedAt: <timestamp> ✓
  bannedReason: "Repeated harassment..." ✓
  bannedBy: "admin_id" ✓
```

**Firebase Auth Check:**
```
Firebase Console → Authentication → Users
Find banned user → Status: Disabled ✓
```

**Login Test:**
1. Try to log in as banned user
2. Should see: "Your account has been banned"
3. Cannot access any app features

---

## 🔄 Integration Tests

### End-to-End Flow 1: Report → Moderation

**Scenario:** User reports inappropriate content, admin bans offender

1. **User A reports User B:**
   - View User B's profile
   - Report for "Inappropriate Content"
   - Add details: "Profile contains explicit photos"
   - Submit

2. **Admin receives notification:**
   - Log in as admin
   - See notification: "New report: inappropriate_content"
   - Badge on Admin Tools icon

3. **Admin reviews report:**
   - Open Moderation Dashboard
   - See User B's report in queue
   - Tap to view details
   - Review evidence

4. **Admin bans User B:**
   - Select "Ban Permanently"
   - Add reason: "Confirmed violation - explicit content"
   - Confirm twice
   - Report resolved

5. **Verify ban effective:**
   - Log out
   - Try to log in as User B
   - Error: "Your account has been banned"
   - ✅ Test passes if cannot log in

### End-to-End Flow 2: Full Verification

**Scenario:** User completes all verifications

1. **Phone Verification:**
   - Profile → Safety Center → Phone Verification
   - Enter phone, receive SMS, verify
   - ✅ Phone verified badge

2. **Photo Verification:**
   - Safety Center → Get Verified
   - Take selfie, wait for processing
   - ✅ Blue verified badge

3. **View Profile:**
   - Profile shows both badges
   - Other users see verified badges
   - Higher trust score in matching

**Firestore Check:**
```javascript
users/{userId}
  phoneVerified: true ✓
  photoVerified: true ✓
  verificationMethods: ["phone", "photo"] ✓
```

### End-to-End Flow 3: Fake Profile Auto-Moderation

**Scenario:** Fake profile auto-detected and banned by admin

1. **Create suspicious profile:**
   - Sign up with email
   - Name: "xyz"
   - No photos
   - Bio: "Contact WhatsApp +123456"

2. **Auto-detection:**
   - Normal user loads discovery
   - Suspicious profile NOT shown
   - Console: "Filtered 1 suspicious profile"

3. **Admin notified:**
   - Admin sees notification
   - "Suspicious profile detected"

4. **Admin reviews:**
   - Open Moderation Dashboard
   - "Suspicious" tab
   - See xyz's profile with score 0.9

5. **Admin bans:**
   - Tap suspicious profile
   - Select "Ban"
   - Confirm
   - ✅ Account banned

---

## 🐛 Common Issues & Solutions

### Issue: SMS not received

**Check:**
- [ ] Phone Auth enabled in Firebase Console?
- [ ] Phone number format correct? (must include +1)
- [ ] SMS quota not exceeded? (default: 10/day free tier)
- [ ] Check spam folder on phone

**Solution:**
- Use Firebase test phone numbers for testing
- Check Firebase Console → Authentication → Phone → Test numbers

### Issue: Photo verification fails

**Check:**
- [ ] Profile has photos uploaded?
- [ ] Google Cloud Vision API enabled?
- [ ] Billing enabled in Google Cloud?
- [ ] Same person in selfie vs profile?

**Solution:**
- Use clear, well-lit selfie
- Ensure profile photos show face clearly
- Check Cloud Functions logs for errors

### Issue: Fake profiles not filtered

**Check:**
- [ ] Is FakeProfileDetector integrated in DiscoverViewModel?
- [ ] Check console logs for analysis results
- [ ] Verify suspicionScore threshold (0.7)

**Solution:**
- Check DiscoverViewModel.swift line ~150
- Look for filterSuspiciousProfiles() call
- Verify indicators array populated

### Issue: Admin dashboard not visible

**Check:**
- [ ] User has `isAdmin: true` in Firestore?
- [ ] Case-sensitive: must be exactly `true`
- [ ] Document ID matches user ID?

**Solution:**
```javascript
// Firestore → users → {your_user_id}
{
  isAdmin: true  // Must be boolean true, not string "true"
}
```

### Issue: Cloud Functions timeout

**Check:**
- [ ] Functions deployed? Run `firebase functions:list`
- [ ] Network connectivity?
- [ ] Firebase project ID correct?

**Solution:**
```bash
cd CloudFunctions
firebase deploy --only functions
```

---

## ✅ Test Completion Checklist

### Phone Verification
- [ ] Can send SMS code
- [ ] Can verify with correct code
- [ ] Rejects invalid codes
- [ ] Can resend code
- [ ] Firestore updated correctly

### Photo Verification
- [ ] Can take and submit selfie
- [ ] Matches against profile photos
- [ ] Rejects non-matching photos
- [ ] Badge appears on profile
- [ ] Expires after 90 days

### Fake Profile Detection
- [ ] Normal profiles pass through
- [ ] No-photo profiles filtered
- [ ] Spam bio profiles filtered
- [ ] Auto-reports to moderationQueue
- [ ] Admins notified

### Reporting
- [ ] Can submit reports for all reasons
- [ ] Reported users auto-blocked
- [ ] Reports appear in admin queue
- [ ] Admins notified immediately

### Admin Moderation
- [ ] Dashboard accessible to admins only
- [ ] Reports queue shows all pending
- [ ] Suspicious profiles tab works
- [ ] Statistics accurate
- [ ] Dismiss action works
- [ ] Warn action works (increments warnings)
- [ ] Suspend action works (prevents login)
- [ ] Ban action works (disables auth)
- [ ] All actions logged in adminLogs

---

## 📊 Testing Metrics

Track these during testing:

| Metric | Target | Actual |
|--------|--------|--------|
| Phone verification success rate | >95% | __% |
| Photo verification success rate | >90% | __% |
| Fake profiles filtered | >80% | __% |
| Report submission success | 100% | __% |
| Admin action success | 100% | __% |
| SMS delivery time | <30s | __s |
| Photo processing time | <30s | __s |
| Dashboard load time | <3s | __s |

---

## 🚀 Quick Start Testing

**Don't have time to read everything? Start here:**

1. **Phone Verification (5 min):**
   - Profile → Safety Center → Phone Verification
   - Enter your number, get SMS, verify
   - ✅ Should show "Verified"

2. **Create Fake Profile (3 min):**
   - Sign up new account
   - Don't add photos
   - Bio: "WhatsApp +123"

3. **Check Filtering (2 min):**
   - Log in with main account
   - Load discovery
   - Fake profile should NOT appear

4. **Submit Report (2 min):**
   - View any profile
   - Report them (test)
   - ✅ Should succeed

5. **Admin Moderation (5 min):**
   - Set `isAdmin: true` in Firestore
   - Profile → Admin Tools → Moderation
   - See your test report
   - Dismiss it

**Total: 17 minutes for basic coverage**

---

**Need Help?**
- Check Firebase Console logs
- Review DEPLOYMENT_GUIDE.md
- Check Firestore data directly
- Review PRE_DEPLOYMENT_CHECKLIST.md

**Last Updated:** November 19, 2025
**Branch:** `claude/code-review-qa-01WQffHnyJCaGsGjCtJY6Tro`
