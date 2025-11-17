# Production Deployment Security Checklist

**Status**: 🔴 NOT PRODUCTION READY - Critical items must be completed

---

## 🔴 CRITICAL - Must Fix Before Launch

### 1. Firebase API Key Security ⚠️ URGENT
**Status**: ❌ NOT SECURE
**Risk Level**: CRITICAL
**Current Issue**: `GoogleService-Info.plist` contains exposed API key in repository

**Actions Required**:
```bash
# 1. Rotate the API key in Firebase Console
#    - Go to Firebase Console → Project Settings → General
#    - Under "Your apps" → iOS app → Download new GoogleService-Info.plist
#    - Replace the file locally (DO NOT COMMIT)

# 2. Add to .gitignore
echo "Celestia/GoogleService-Info.plist" >> .gitignore
git rm --cached Celestia/GoogleService-Info.plist
git commit -m "security: remove Firebase config from repository"

# 3. Set up environment-specific configuration
# Create template file:
cp Celestia/GoogleService-Info.plist Celestia/GoogleService-Info.plist.template
# Remove sensitive values from template, commit template only

# 4. Enable API Key restrictions in Google Cloud Console
# - Go to Google Cloud Console → APIs & Services → Credentials
# - Click on the API key
# - Under "Application restrictions", select "iOS apps"
# - Add your app's bundle identifier
# - Under "API restrictions", restrict to only required APIs:
#   ✅ Firebase Authentication
#   ✅ Cloud Firestore API
#   ✅ Firebase Cloud Messaging
#   ✅ Firebase Storage
#   ❌ Disable all others

# 5. Enable Firebase App Check
# - Go to Firebase Console → App Check
# - Register your app with DeviceCheck (for iOS)
# - Enforce App Check for all Firebase services
```

**Cost of Inaction**: Unauthorized API usage, quota exhaustion, potential $10,000+ bill

---

### 2. SSL Certificate Pinning ⚠️ REQUIRED
**Status**: ⚠️ CONFIGURED BUT NOT ACTIVE
**Risk Level**: CRITICAL
**File**: `Celestia/NetworkManager.swift:138-141`

**Actions Required**:
```bash
# 1. Get your API server's certificate hash
# Replace api.celestia.app with your actual domain
openssl s_client -servername api.celestia.app -connect api.celestia.app:443 \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform der \
  | openssl dgst -sha256 -binary \
  | openssl enc -base64

# 2. Get backup certificate (for rotation)
# This is typically your root CA or intermediate certificate
# Contact your certificate provider for the backup cert hash

# 3. Update NetworkManager.swift
# Replace lines 138-141 with:
let hashes: Set<String> = [
    "your_primary_hash_from_step_1",    // Primary certificate
    "your_backup_hash_from_step_2"      // Backup for cert rotation
]

# 4. Test in staging environment
# - Build app with certificate pinning enabled
# - Verify all API calls work correctly
# - Test with invalid certificates (should fail)
```

**Verification**:
```swift
// Add this test to verify certificate pinning works:
// Try connecting with invalid certificate - should fail with error
```

---

### 3. Firebase Storage Security Rules ✅ CREATED
**Status**: ✅ RULES CREATED (needs deployment)
**Risk Level**: HIGH
**File**: `storage.rules` (newly created)

**Actions Required**:
```bash
# Deploy storage rules to Firebase
firebase deploy --only storage

# Verify rules are active
# Go to Firebase Console → Storage → Rules
# Confirm rules show updated timestamp
```

---

### 4. Firestore Security Rules Review
**Status**: ⚠️ NEEDS REVIEW
**Risk Level**: HIGH
**File**: `firestore.rules`

**Actions Required**:
1. Review `firestore.rules` for any overly permissive rules
2. Test rules in Firebase Console Rules Playground
3. Add rate limiting via custom claims or Cloud Functions
4. Deploy updated rules: `firebase deploy --only firestore:rules`

**Key Areas to Verify**:
- [ ] All writes require authentication
- [ ] Users can only write to their own data
- [ ] Email verification is enforced for sensitive operations
- [ ] Message rate limiting is enforced
- [ ] Admin operations require admin custom claim

---

## 🟡 HIGH PRIORITY - Fix Before Launch

### 5. Environment Configuration
**Status**: ❌ HARDCODED
**Risk Level**: HIGH
**File**: `Celestia/Constants.swift:14`

**Actions Required**:
```swift
// Create Config/Debug.xcconfig
API_URL = https:/$()/api-dev.celestia.app
FIREBASE_ENABLED = YES
ANALYTICS_ENABLED = NO

// Create Config/Release.xcconfig
API_URL = https:/$()/api.celestia.app
FIREBASE_ENABLED = YES
ANALYTICS_ENABLED = YES

// Update Constants.swift:
static let baseURL: String = {
    guard let urlString = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String else {
        fatalError("API_URL not configured in xcconfig")
    }
    return urlString
}()
```

---

### 6. Code Obfuscation for Release Builds
**Status**: ❌ NOT CONFIGURED
**Risk Level**: MEDIUM

**Actions Required**:
1. Enable Swift optimization in Release build settings
2. Strip debug symbols: Build Settings → Strip Debug Symbols = YES
3. Enable Bitcode if required by distribution platform
4. Validate binary size and upload to App Store Connect

---

### 7. App Transport Security (ATS) Configuration
**Status**: ✅ ENABLED
**Risk Level**: MEDIUM

**Verification Needed**:
- [ ] All network requests use HTTPS
- [ ] No ATS exceptions are configured
- [ ] Test all API endpoints with HTTPS

---

## 🟢 RECOMMENDED - Should Fix Soon

### 8. Implement Firebase App Check
**Status**: ❌ NOT CONFIGURED
**Risk Level**: MEDIUM

**Benefits**:
- Prevents API abuse from unauthorized clients
- Protects against quota exhaustion attacks
- Required for some Firebase features

**Setup**:
```bash
# 1. Enable App Check in Firebase Console
# 2. Add AppCheck to your app:
import FirebaseAppCheck

// In AppDelegate or @main:
let providerFactory = AppCheckDeviceCheckProviderFactory()
AppCheck.setAppCheckProviderFactory(providerFactory)

# 3. Enforce App Check for all services
# Go to Firebase Console → App Check → Enforcement
# Enable for: Authentication, Firestore, Storage, Cloud Messaging
```

---

### 9. Enable Firebase Crashlytics
**Status**: ✅ CONFIGURED
**Action**: Verify Crashlytics is receiving reports in production

---

### 10. Set Up Firebase Performance Monitoring
**Status**: ✅ CONFIGURED
**Action**: Review performance metrics in Firebase Console

---

### 11. Data Encryption at Rest
**Status**: ✅ ENABLED (iOS default)
**Note**: iOS encrypts app data by default when device is locked

---

### 12. Implement Jailbreak Detection
**Status**: ❌ NOT IMPLEMENTED
**Risk Level**: LOW

**Recommendation**:
```swift
// Add jailbreak detection for sensitive operations
func isJailbroken() -> Bool {
    #if targetEnvironment(simulator)
    return false
    #else
    let paths = [
        "/Applications/Cydia.app",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/bin/bash",
        "/usr/sbin/sshd",
        "/etc/apt"
    ]

    for path in paths {
        if FileManager.default.fileExists(atPath: path) {
            return true
        }
    }

    // Try to write to protected directory
    let testPath = "/private/test_jailbreak.txt"
    do {
        try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
        try FileManager.default.removeItem(atPath: testPath)
        return true
    } catch {
        return false
    }
    #endif
}

// Warn user or disable sensitive features if jailbroken
```

---

## 📋 Pre-Launch Verification Checklist

### Security
- [ ] API keys rotated and not in repository
- [ ] Certificate pinning enabled and tested
- [ ] Firebase Storage rules deployed
- [ ] Firestore rules reviewed and deployed
- [ ] App Check enabled and enforced
- [ ] API key restrictions configured in GCP
- [ ] OAuth scopes minimized

### Configuration
- [ ] Environment-specific configs set up
- [ ] Debug logging disabled in Release builds
- [ ] Analytics opt-in prompt implemented (GDPR)
- [ ] Privacy Policy and Terms of Service links added

### Testing
- [ ] Security penetration testing completed
- [ ] Load testing completed
- [ ] All critical paths tested
- [ ] Certificate pinning tested
- [ ] Offline mode tested
- [ ] Error scenarios tested

### Compliance
- [ ] Privacy policy updated and accessible
- [ ] GDPR compliance verified (if serving EU users)
- [ ] COPPA compliance verified (no users under 13)
- [ ] Data retention policies implemented
- [ ] Right to deletion implemented
- [ ] Data export capability implemented

### Performance
- [ ] App launch time < 2 seconds
- [ ] All screens load in < 1 second
- [ ] Database queries optimized (from performance audit)
- [ ] Images optimized and compressed
- [ ] Bundle size optimized (< 50MB recommended)

### Monitoring
- [ ] Crashlytics verified working
- [ ] Performance monitoring verified
- [ ] Analytics tracking key events
- [ ] Error logging configured
- [ ] Alert thresholds configured

---

## 🚨 Emergency Response Plan

### If API Key Is Compromised
1. **Immediately** rotate key in Firebase Console
2. Deploy updated `GoogleService-Info.plist` via emergency build
3. Monitor Firebase usage for abnormal patterns
4. Check billing for unexpected charges
5. Review Firebase security rules
6. Enable App Check if not already enabled

### If Certificate Pinning Fails
1. Check if certificate was rotated
2. Deploy emergency build with updated certificate hashes
3. Monitor for MITM attack attempts
4. Review server certificate configuration

### If Storage Security Is Breached
1. Review and lock down Firebase Storage rules
2. Audit uploaded files for malicious content
3. Check for unusual storage usage patterns
4. Consider enabling Cloud Storage for Firebase virus scanning

---

## 📞 Security Contacts

**Firebase Support**: https://firebase.google.com/support
**Google Cloud Support**: https://cloud.google.com/support
**Apple Security**: product-security@apple.com

---

## 📚 Additional Resources

- [Firebase Security Rules Documentation](https://firebase.google.com/docs/rules)
- [iOS App Security Best Practices](https://developer.apple.com/security/)
- [OWASP Mobile Security Project](https://owasp.org/www-project-mobile-security/)
- [Apple App Store Review Guidelines - Security](https://developer.apple.com/app-store/review/guidelines/#security)

---

**Last Updated**: 2025-11-17
**Next Review**: Before production deployment
**Owner**: Development Team Lead
