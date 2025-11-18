# Firebase Deployment Guide

## Prerequisites

- Firebase CLI installed: `npm install -g firebase-tools`
- Firebase account with access to `celestia-dating-app` project
- Cloudinary credentials ready

## Step 1: Authenticate with Firebase

Run this command from your local machine:

```bash
firebase login
```

This will open a browser window for authentication. Sign in with your Google account that has access to the Firebase project.

## Step 2: Navigate to CloudFunctions Directory

```bash
cd CloudFunctions
```

## Step 3: Install Dependencies (if not already done)

```bash
npm install
```

This installs:
- `cloudinary` - CDN integration
- `sharp` - Image processing
- `firebase-functions` - Cloud Functions SDK
- `firebase-admin` - Admin SDK

## Step 4: Configure Environment Variables

Set the Cloudinary credentials in Firebase config:

```bash
firebase functions:config:set \
  cloudinary.cloud_name="dquqeovn2" \
  cloudinary.api_key="551344196324785" \
  cloudinary.api_secret="td1HXKjKpubpxf9yIxzqgXoGwes"
```

Verify the configuration:

```bash
firebase functions:config:get
```

Expected output:
```json
{
  "cloudinary": {
    "cloud_name": "dquqeovn2",
    "api_key": "551344196324785",
    "api_secret": "td1HXKjKpubpxf9yIxzqgXoGwes"
  }
}
```

## Step 5: Test Locally (Optional but Recommended)

Before deploying to production, test the functions locally:

```bash
# Start the Firebase emulator
npm run serve

# Or manually:
firebase emulators:start --only functions
```

In another terminal, test the functions:

```bash
# Test Cloudinary connection
node test-cloudinary.js
```

Expected output:
```
✅ Cloudinary connection successful!
Cloud Name: dquqeovn2
Sample URL: https://res.cloudinary.com/dquqeovn2/image/upload/sample
```

## Step 6: Deploy to Production

Deploy all functions:

```bash
firebase deploy --only functions
```

Or deploy specific functions:

```bash
# Deploy only image optimization functions
firebase deploy --only functions:optimizePhoto,functions:getOptimizedImageURL,functions:migrateImageToCDN,functions:deleteOptimizedImage
```

Expected output:
```
✔ functions[optimizePhoto(us-central1)] Successful update operation.
✔ functions[getOptimizedImageURL(us-central1)] Successful update operation.
✔ functions[migrateImageToCDN(us-central1)] Successful update operation.
✔ functions[deleteOptimizedImage(us-central1)] Successful update operation.

✔ Deploy complete!

Project Console: https://console.firebase.google.com/project/celestia-dating-app/overview
```

## Step 7: Verify Deployment

Check the Firebase Console:

1. Go to: https://console.firebase.google.com/project/celestia-dating-app/functions
2. Verify all 4 functions are deployed:
   - `optimizePhoto`
   - `getOptimizedImageURL`
   - `migrateImageToCDN`
   - `deleteOptimizedImage`
3. Check the function logs for any errors

Test from iOS app:

```swift
// In Xcode, run this test
func testOptimizePhoto() async throws {
    let testImage = UIImage(named: "test-photo")!
    let photoData = try await OptimizedImageLoader.shared.uploadOptimizedPhoto(
        testImage,
        folder: "test-photos",
        useCDN: true
    )

    print("✅ Upload successful!")
    print("CDN URL: \(photoData.cdnUrl ?? "N/A")")
    print("Available sizes: \(photoData.urls.keys.joined(separator: ", "))")
}
```

## Step 8: Monitor Deployment

### Check Function Logs

```bash
# View logs for all functions
firebase functions:log

# View logs for specific function
firebase functions:log --only optimizePhoto

# Follow logs in real-time
firebase functions:log --follow
```

### Check Firebase Console

Navigate to: https://console.firebase.google.com/project/celestia-dating-app/functions

Monitor:
- Request count
- Error rate
- Execution time
- Memory usage

## Troubleshooting

### Error: "Failed to authenticate"

**Solution:**
```bash
firebase logout
firebase login
```

### Error: "Insufficient permissions"

**Solution:** Ensure your Google account has "Owner" or "Editor" role in the Firebase project.

Check permissions at: https://console.firebase.google.com/project/celestia-dating-app/settings/iam

### Error: "Configuration not found"

**Solution:** Re-run the config command:
```bash
firebase functions:config:set \
  cloudinary.cloud_name="dquqeovn2" \
  cloudinary.api_key="551344196324785" \
  cloudinary.api_secret="td1HXKjKpubpxf9yIxzqgXoGwes"
```

### Error: "Build failed"

**Solution:** Check for missing dependencies:
```bash
cd CloudFunctions
npm install
npm audit fix
```

### Error: "Deployment quota exceeded"

**Solution:** Wait a few minutes between deployments. Firebase has rate limits.

### Error: "Function timeout"

**Solution:** Increase timeout in `index.js`:
```javascript
exports.optimizePhoto = functions
  .runWith({ timeoutSeconds: 300, memory: '1GB' })
  .https.onCall(async (data, context) => {
    // ...
  });
```

## Post-Deployment Checklist

- [ ] All 4 functions deployed successfully
- [ ] Firebase config contains Cloudinary credentials
- [ ] Function logs show no errors
- [ ] Test upload from iOS app works
- [ ] CDN URLs are generated correctly
- [ ] Images load in app with progressive loading
- [ ] Cloudinary dashboard shows uploaded images
- [ ] Firebase Performance is tracking image loads

## Updating Functions

After making code changes:

```bash
# 1. Test locally
firebase emulators:start --only functions

# 2. Deploy updates
firebase deploy --only functions

# 3. Verify in Firebase Console
firebase functions:log --follow
```

## Rolling Back

If deployment fails or causes issues:

```bash
# List previous deployments
firebase functions:list

# Rollback to previous version (manual via Console)
# Go to: Firebase Console → Functions → Click function → Rollback tab
```

## CI/CD Setup (Optional)

For automated deployments via GitHub Actions:

1. Generate a CI token:
```bash
firebase login:ci
```

2. Add token to GitHub Secrets as `FIREBASE_TOKEN`

3. Use in GitHub Actions:
```yaml
- name: Deploy to Firebase
  run: firebase deploy --only functions --token ${{ secrets.FIREBASE_TOKEN }}
```

## Security Best Practices

1. **Never commit `.env` file** - Already gitignored ✓
2. **Use Firebase config for secrets** - Already set up ✓
3. **Rotate Cloudinary API secret** - Every 90 days
4. **Monitor function logs** - Check for unauthorized access
5. **Set up billing alerts** - Prevent unexpected costs

## Cost Monitoring

After deployment, monitor costs at:
https://console.firebase.google.com/project/celestia-dating-app/usage

**Expected costs:**
- Functions: Free tier covers up to 2M invocations/month
- Cloudinary: Free tier (already discussed)
- Firebase Storage: Existing costs remain the same

## Support Resources

- Firebase Functions Docs: https://firebase.google.com/docs/functions
- Cloudinary API Docs: https://cloudinary.com/documentation/node_integration
- Image Optimization Guide: `CLOUDINARY_SETUP_COMPLETE.md`
- Testing Guide: `TESTING_GUIDE.md`
- Performance Monitoring: `PERFORMANCE_MONITORING_GUIDE.md`

---

## Quick Deploy Command

If you're confident everything is ready:

```bash
cd CloudFunctions && \
npm install && \
firebase login && \
firebase functions:config:set cloudinary.cloud_name="dquqeovn2" cloudinary.api_key="551344196324785" cloudinary.api_secret="td1HXKjKpubpxf9yIxzqgXoGwes" && \
firebase deploy --only functions
```

---

**Project:** celestia-dating-app
**Functions:** 4 new endpoints (optimizePhoto, getOptimizedImageURL, migrateImageToCDN, deleteOptimizedImage)
**Region:** us-central1 (default)
**Runtime:** Node.js 18

Ready to deploy! 🚀
