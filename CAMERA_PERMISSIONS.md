# Camera Permissions Setup for Photo Verification

## Issue
The photo verification feature crashes with SIGABRT when trying to access the camera.

## Root Cause
iOS requires explicit privacy permission descriptions in the app's `Info.plist` file before accessing the camera. Without these keys, iOS will terminate the app immediately with SIGABRT.

## Required Fix

### Add Camera Permission to Info.plist

You need to add the following key to your `Info.plist` file in Xcode:

**Via Xcode UI:**
1. Open your Xcode project
2. Select the Celestia target
3. Go to the "Info" tab
4. Click the `+` button to add a new entry
5. Add: `Privacy - Camera Usage Description` (NSCameraUsageDescription)
6. Set the value to: "Celestia needs camera access to verify your identity and help you create an authentic profile."

**Via Info.plist Source Code:**
```xml
<key>NSCameraUsageDescription</key>
<string>Celestia needs camera access to verify your identity and help you create an authentic profile.</string>
```

## Code Fixes Applied

### 1. Removed @MainActor from CameraManager
**Problem:** AVCaptureSession operations must run on a background thread, not the main thread.

**Fix:** Removed `@MainActor` annotation and created a dedicated `sessionQueue` for camera operations.

### 2. Improved Permission Handling
**Problem:** Permission status wasn't checked before requesting access.

**Fix:** Now checks authorization status first:
- `.authorized` → Returns true immediately
- `.notDetermined` → Requests permission
- `.denied` or `.restricted` → Returns false

### 3. Added Error Handling
**Problem:** Camera setup failures weren't properly caught or logged.

**Fix:** Added:
- `CameraError` enum with specific error cases
- Try/catch blocks in `setupCamera()`
- Logger statements for debugging
- Proper error propagation from `startSession()`

### 4. Proper Threading
**Problem:** Session configuration was running on wrong thread.

**Fix:** All AVCaptureSession operations now run on dedicated `sessionQueue`:
```swift
private let sessionQueue = DispatchQueue(label: "com.celestia.camera.session")
```

## Testing

### On Simulator
⚠️ **The camera won't work on iOS Simulator** - it doesn't have camera hardware. Test on a real device.

### On Real Device
1. Ensure `NSCameraUsageDescription` is in Info.plist
2. Build and run on a physical iPhone
3. When opening photo verification:
   - First time: System permission alert appears
   - Grant permission
   - Camera preview should appear
4. If permission denied: Settings alert appears with option to open Settings

## Additional Notes

- Camera access requires a physical device - simulators don't have cameras
- The app must be code-signed and have proper entitlements
- Users can revoke camera permission in Settings → Privacy & Security → Camera
- Face detection using Vision framework works offline and doesn't require network

## Verification Checklist

- [ ] Add `NSCameraUsageDescription` to Info.plist
- [ ] Test on a real iOS device (not simulator)
- [ ] Grant camera permission when prompted
- [ ] Verify camera preview appears
- [ ] Verify face detection works
- [ ] Test permission denial flow
