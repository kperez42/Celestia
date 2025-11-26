# Debug: Gender Filtering Not Working

## Step-by-Step Troubleshooting

### 1. Check Firebase Index Status
Go to: https://console.firebase.google.com/project/celestia-40ce6/firestore/indexes

**Expected:**
- You should see an index for `users` collection that's either:
  - ✅ "Enabled" (green) - Ready to use
  - 🔄 "Building" (yellow) - Wait 2-5 more minutes
  - ❌ "Error" (red) - Click the error link from your logs to create it

**Action:** If still building, wait. If not created, click the link from your error logs.

---

### 2. Verify Your Test Accounts

Check your Firebase Console → Firestore → `users` collection

**For each female test account, verify:**
- `gender` = "Female" ✅
- `showMeInSearch` = true ✅
- `isOnline` or `lastActive` is recent ✅
- `lookingFor` allows seeing other females (should be "Women" or "Everyone") ✅

**Common Issues:**
- If `showMeInSearch` = false, that account won't show up in discover
- If `gender` = "Male" instead of "Female", the filter won't match
- If both accounts have `lookingFor` = "Men", they won't see each other

---

### 3. Test the Filter Flow

**On your female account:**

1. Open the app
2. Tap the **Discover tab** (bottom nav)
3. Wait 5 seconds - does anything load?
4. Pull to refresh
5. Check the console logs - do you see any Firebase query errors?

**Expected log:**
```
Fetching users...
Query succeeded, found X users
```

**If you see:**
```
The query requires an index...
```
→ Click the link to create the index

---

### 4. Manually Trigger a Fresh Query

In Xcode, in the app:

1. Go to **Settings** → **Discovery Filters**
2. Change lookingFor to **"Everyone"**
3. Tap **"Save & Apply"**
4. Go back to **Discover tab**
5. Check if you see any accounts now

If "Everyone" works but "Women" doesn't:
- The gender-specific index isn't created yet
- Go back to Firebase Console and create it

---

### 5. Check Current User's lookingFor Value

Your logs show:
```
lookingFor: [value from logs]
```

**It should be:** `"Women"` to see female accounts

**If it's something else:**
1. Go to Settings → Discovery Filters
2. Select "Women"
3. Tap "Save & Apply"
4. Verify in Firebase Console that `lookingFor` = "Women"

---

### 6. Quick Test Query in Firebase Console

Go to Firebase Console → Firestore → `users` collection

Run this query manually:
```
Where: gender == "Female"
Where: showMeInSearch == true
Order by: lastActive descending
Limit: 10
```

**How many results?**
- **0 results** = No female accounts with showMeInSearch=true exist
- **1+ results** = Accounts exist, but app filtering isn't working

---

## Quick Checklist

- [ ] Firebase index created and status = "Enabled"
- [ ] At least 2 female test accounts exist
- [ ] Both accounts have `showMeInSearch = true`
- [ ] Both accounts have `gender = "Female"`
- [ ] Current account has `lookingFor = "Women"`
- [ ] Navigated to Discover tab after saving filters
- [ ] Pulled to refresh in Discover

---

## Still Not Working?

Share:
1. Screenshot of Firebase → Firestore → Indexes page
2. Screenshot of one of your female test accounts in Firestore
3. The lookingFor value from your current account
4. Any new error logs when you navigate to Discover
