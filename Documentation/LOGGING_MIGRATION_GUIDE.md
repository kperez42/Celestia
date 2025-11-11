# Logging Migration Guide

This guide explains how to migrate from `print()` statements to the new `Logger` system.

## Quick Reference

### Old vs New

| Old Code | New Code |
|----------|----------|
| `print("✅ Success")` | `Logger.shared.info("Success", category: .general)` |
| `print("❌ Error: \(error)")` | `Logger.shared.error("Error occurred", error: error)` |
| `print("🔵 Info message")` | `Logger.shared.info("Info message")` |
| `print("⚠️ Warning")` | `Logger.shared.warning("Warning")` |
| `print("🔥 Critical")` | `Logger.shared.critical("Critical issue")` |

## Log Levels

```swift
Logger.shared.debug("Debug message")    // 🔍 DEBUG - Development only
Logger.shared.info("Info message")      // ℹ️ INFO - General information
Logger.shared.warning("Warning")        // ⚠️ WARNING - Potential issues
Logger.shared.error("Error", error: e)  // ❌ ERROR - Errors
Logger.shared.critical("Critical")      // 🔥 CRITICAL - Critical failures
```

## Categories

Use categories to organize logs:

```swift
// Authentication
Logger.shared.auth("User signed in", level: .info)
Logger.shared.log("User signed in", level: .info, category: .authentication)

// Networking
Logger.shared.network("API request failed", level: .error)
Logger.shared.log("API request failed", level: .error, category: .networking)

// Database
Logger.shared.database("Firestore query completed", level: .info)
Logger.shared.log("Firestore query completed", level: .info, category: .database)
```

### Available Categories

- `.authentication` - Sign in, sign up, auth flows
- `.networking` - API calls, network requests
- `.database` - Firestore, local DB operations
- `.ui` - UI events, view lifecycle
- `.storage` - File operations, image uploads
- `.messaging` - Chat messages
- `.matching` - Match creation, swipes
- `.payment` - In-app purchases, subscriptions
- `.analytics` - Event tracking
- `.push` - Push notifications
- `.referral` - Referral system
- `.moderation` - Content moderation
- `.general` - Everything else

## Migration Examples

### Example 1: AuthService

**Before:**
```swift
print("🔵 AuthService initialized")
print("🔵 Current user session: \(Auth.auth().currentUser?.uid ?? "none")")
print("✅ Sign in successful: \(result.user.uid)")
print("❌ Sign in error: \(error.localizedDescription)")
```

**After:**
```swift
Logger.shared.auth("AuthService initialized", level: .info)
Logger.shared.auth("Current user session: \(Auth.auth().currentUser?.uid ?? "none")", level: .debug)
Logger.shared.auth("Sign in successful: \(result.user.uid)", level: .info)
Logger.shared.auth("Sign in error", level: .error, error: error)
```

### Example 2: MatchService

**Before:**
```swift
print("Match already exists: \(existingMatch.id ?? "unknown")")
print("✅ Match created: \(docRef.documentID)")
print("❌ Error creating match: \(error)")
```

**After:**
```swift
Logger.shared.log("Match already exists: \(existingMatch.id ?? "unknown")", level: .info, category: .matching)
Logger.shared.log("Match created: \(docRef.documentID)", level: .info, category: .matching)
Logger.shared.log("Error creating match", level: .error, category: .matching, error: error)
```

### Example 3: Network Calls

**Before:**
```swift
print("Failed to load products: \(error)")
print("Loaded \(products.count) products from App Store")
```

**After:**
```swift
Logger.shared.network("Failed to load products", level: .error, error: error)
Logger.shared.network("Loaded \(products.count) products from App Store", level: .info)
```

## Global Convenience Functions

For quick migration, use global functions:

```swift
logDebug("Debug message")
logInfo("Info message")
logWarning("Warning message")
logError("Error message", error: someError)
logCritical("Critical message")

// With categories
logInfo("User signed in", category: .authentication)
logError("Network failed", category: .networking, error: error)
```

## Configuration

### Enable/Disable Categories at Runtime

```swift
// Disable authentication logs
Logger.shared.setCategory(.authentication, enabled: false)

// Disable all logs
Logger.shared.setAllCategories(enabled: false)

// Re-enable specific category
Logger.shared.setCategory(.networking, enabled: true)
```

### Change Minimum Log Level

```swift
// Show only warnings and above
Logger.shared.minimumLogLevel = .warning

// Show all logs (debug mode)
Logger.shared.minimumLogLevel = .debug

// Show only errors
Logger.shared.minimumLogLevel = .error
```

### Disable Console/File Logging

```swift
// Disable console logging (still logs to file and OS Log)
Logger.shared.consoleLoggingEnabled = false

// Disable file logging
Logger.shared.fileLoggingEnabled = false
```

## Log File Management

### Export Logs

```swift
if let logFileURL = Logger.shared.exportLogs() {
    // Share or upload log file
    let activityVC = UIActivityViewController(
        activityItems: [logFileURL],
        applicationActivities: nil
    )
    present(activityVC, animated: true)
}
```

### Read Log Contents

```swift
if let logs = Logger.shared.getLogFileContents() {
    print(logs)
}
```

### Clear Logs

```swift
Logger.shared.clearLogFile()
```

## Best Practices

### 1. Choose Appropriate Log Levels

- **Debug**: Development/debugging info (never in production logs)
- **Info**: Normal operation events
- **Warning**: Unexpected but handled situations
- **Error**: Errors that impact functionality
- **Critical**: Critical failures requiring immediate attention

### 2. Use Meaningful Messages

**Bad:**
```swift
Logger.shared.info("Done")
Logger.shared.error("Failed")
```

**Good:**
```swift
Logger.shared.info("User profile update completed successfully")
Logger.shared.error("Failed to update user profile", error: error)
```

### 3. Include Context

**Bad:**
```swift
Logger.shared.error("Save failed", error: error)
```

**Good:**
```swift
Logger.shared.database("Failed to save user \(userId) to Firestore", level: .error, error: error)
```

### 4. Don't Log Sensitive Information

**Never log:**
- Passwords
- API keys
- Personal information (email, phone)
- Payment information
- Session tokens

**Bad:**
```swift
Logger.shared.auth("User logged in with password: \(password)")
```

**Good:**
```swift
Logger.shared.auth("User logged in with email: \(email)")
```

### 5. Use Appropriate Categories

Group related logs:

```swift
// Authentication flow
Logger.shared.auth("Starting sign in flow")
Logger.shared.auth("Email validated")
Logger.shared.auth("Sign in successful")

// Match creation
Logger.shared.log("Checking for existing match", level: .debug, category: .matching)
Logger.shared.log("Creating new match", level: .info, category: .matching)
Logger.shared.log("Match created successfully", level: .info, category: .matching)
```

## Migration Checklist

- [ ] Replace `print("✅ ...")` with `Logger.shared.info(...)`
- [ ] Replace `print("❌ ...")` with `Logger.shared.error(...)`
- [ ] Replace `print("⚠️ ...")` with `Logger.shared.warning(...)`
- [ ] Replace `print("🔵 ...")` with `Logger.shared.info(...)` or `Logger.shared.debug(...)`
- [ ] Replace `print("🔥 ...")` with `Logger.shared.critical(...)`
- [ ] Add appropriate categories to all logs
- [ ] Include error objects in error logs
- [ ] Remove sensitive information from logs
- [ ] Test log output in Console.app
- [ ] Verify file logging works
- [ ] Check log file rotation

## Testing Logs

### View in Xcode Console

Logs appear in Xcode console with full formatting:
```
[2025-01-10 14:23:45.123] ℹ️ [INFO] [Auth] AuthService.swift:25 init() - AuthService initialized
```

### View in Console.app

1. Open Console.app
2. Select your device/simulator
3. Filter by subsystem: `com.celestia.app`
4. Filter by category: `Auth`, `Network`, etc.

### View Log File

```swift
// In debug menu or settings
if let logs = Logger.shared.getLogFileContents() {
    // Display in text view or share
}
```

## Performance Considerations

The Logger is optimized for performance:

- **Async logging** - Logs are written on background queue
- **Conditional logging** - Logs below minimum level are skipped
- **File rotation** - Automatic log file rotation at 10MB
- **OS Log integration** - Uses Apple's efficient logging system

## FAQs

### Q: Will this impact app performance?

A: No. Logging is done asynchronously on a background queue, and logs below the minimum level are skipped entirely.

### Q: Can users see these logs?

A: Console logs are only visible during development. File logs are stored in the Documents directory but require access to the device filesystem.

### Q: What about production logs?

A: In production, set `minimumLogLevel = .warning` or higher to reduce log volume. Debug logs are automatically disabled in release builds.

### Q: Can I disable logging for specific features?

A: Yes, use `Logger.shared.setCategory(.authentication, enabled: false)` to disable logs for a specific category.

### Q: How do I debug issues in production?

A: Implement a debug menu that allows enabling file logging and exporting logs. Users can then send you the log file.

## Support

For issues or questions about the logging system, see `Logger.swift` or contact the development team.

---

**Updated:** January 2025
