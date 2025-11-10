# Firebase Email Verification Setup Guide

## Overview
This guide will help you configure Firebase to send email verification emails to users when they sign up for Celestia.

## Current Status
✅ **Code is configured** - The app is already calling Firebase's email verification API
❌ **Firebase Console needs configuration** - You need to enable email sending in Firebase Console

---

## Step-by-Step Setup Instructions

### 1. Access Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: **celestia-40ce6**
3. You should see your project dashboard

### 2. Navigate to Authentication Settings
1. Click **"Authentication"** in the left sidebar
2. Click the **"Templates"** tab at the top
3. You should see a list of email templates

### 3. Configure Email Verification Template
1. Find **"Email address verification"** in the template list
2. Click the **pencil/edit icon** on the right
3. Review the template:
   - **From name**: Firebase should use "noreply@celestia-40ce6.firebaseapp.com" by default
   - **Subject**: "Verify your email for %APP_NAME%"
   - **Body**: Contains a link for users to verify their email
4. (Optional) Customize the template text to match your brand
5. Click **"Save"** when done

### 4. Verify Email Settings
1. In Authentication, go to **"Settings"** tab
2. Scroll to **"Authorized domains"**
3. Make sure these domains are listed:
   - `localhost` (for local testing)
   - `celestia-40ce6.firebaseapp.com` (your Firebase app domain)
4. If missing, click **"Add domain"** to add them

### 5. Check Email Enumeration Protection
1. Still in Settings, look for **"Email enumeration protection"**
2. This setting protects against attacks but should NOT block verification emails
3. If enabled, make sure it's configured to allow verification emails

### 6. Test the Email Flow
1. Build and run the Celestia app
2. Create a new account with a **real email address you have access to**
3. Check the Xcode console for these logs:
   ```
   ✅ Firebase Auth user created: [user-id]
   ✅ User saved to Firestore successfully
   ✅ Verification email sent to [your-email]
   ```
4. Check your email inbox (and **spam folder!**)

---

## Troubleshooting

### ❌ Not Receiving Emails

**Check Spam Folder**
- Firebase emails often end up in spam
- Look for sender: `noreply@celestia-40ce6.firebaseapp.com`

**Check Firebase Console Logs**
1. Go to Firebase Console > Authentication > Users
2. Find your test user account
3. Look at the "Email verified" column - should show "No" initially

**Enable Firebase Email Debugging**
1. Go to Firebase Console > Authentication > Templates
2. Click "Email address verification"
3. Check if there's a warning message about email configuration

**Verify Console Logs**
Run the app and check Xcode console for:
- ✅ Success: `Verification email sent to [email]`
- ⚠️ Warning: `Email verification send failed: [error details]`

If you see errors, the logs will show:
- Domain (e.g., FIRAuthErrorDomain)
- Error code
- Description

### Common Firebase Email Issues

**Issue: "Too many requests from this device"**
- Solution: Wait 1 hour and try again
- Firebase rate-limits email sending per device

**Issue: "Email not configured"**
- Solution: Go to Firebase Console > Project Settings > Cloud Messaging
- Make sure sender email is configured

**Issue: Emails go to spam**
- Solution: This is normal for Firebase's default email sender
- Users should check spam folders
- For production, consider using a custom email service

---

## Production Email Setup (Optional)

For production apps with many users, consider:

### Option 1: Custom Email Domain
1. Go to Firebase Console > Authentication > Templates
2. Click "Customize email domain"
3. Configure SMTP settings for your own domain
4. Benefits: Better deliverability, branded emails

### Option 2: SendGrid Integration
1. Create a SendGrid account
2. Use Firebase Cloud Functions to send emails via SendGrid
3. Benefits: Better analytics, higher delivery rates

### Option 3: Firebase Extensions
1. Go to Firebase Console > Extensions
2. Install "Trigger Email" extension
3. Configure with your preferred email provider
4. Benefits: Easy setup, no code changes needed

---

## What Happens When Email Verification Works

1. **User Signs Up**
   - User creates account in app
   - Firebase sends verification email
   - User sees EmailVerificationView screen

2. **User Checks Email**
   - Receives email from Firebase
   - Clicks verification link
   - Link opens in browser

3. **User Returns to App**
   - Clicks "I've Verified My Email" button
   - App calls `authService.reloadUser()`
   - User is redirected to MainTabView

---

## Testing Without Email (Development Only)

If you need to bypass email verification for testing:

1. In Firebase Console > Authentication > Users
2. Find your test user
3. Click the three dots menu
4. Click "Set email as verified"
5. Refresh the app

**Note**: This is ONLY for development testing. Don't do this for real users!

---

## Current Implementation Details

### Code Files
- `AuthService.swift:256-271` - Sends email after signup
- `AuthService.swift:464-490` - Resend email function
- `EmailVerificationView.swift` - UI for verification flow
- `ContentView.swift:42-46` - Routes to verification screen

### Email Settings in Code
```swift
let actionCodeSettings = ActionCodeSettings()
actionCodeSettings.handleCodeInApp = false
actionCodeSettings.url = URL(string: "https://celestia-40ce6.firebaseapp.com")
```

This tells Firebase:
- Don't handle the link in the app (use browser)
- Redirect to the Firebase app URL after verification

---

## Questions?

If emails still aren't working after following these steps:

1. Check Xcode console logs for error details
2. Verify your Firebase project is on a paid plan (free tier may have email limits)
3. Try with a different email provider (Gmail, Yahoo, etc.)
4. Check Firebase Console > Usage for any quota limits

## Success Criteria

You'll know it's working when:
- ✅ Console shows "Verification email sent"
- ✅ Email arrives in inbox (or spam)
- ✅ Clicking link verifies the email
- ✅ App allows user to proceed after verification
