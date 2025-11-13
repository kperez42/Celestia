# Compilation Errors - Fix Plan

## Summary
The project has compilation errors that need to be resolved. Most are related to missing protocol definitions and duplicate type declarations.

## Errors by Category

### 1. Missing Protocol Definitions (DependencyContainer.swift)
**Issue:** Code references protocols that don't exist in the codebase.

**Missing Protocols:**
- `AuthServiceProtocol`
- `UserServiceProtocol`
- `MatchServiceProtocol`
- `MessageServiceProtocol`
- `SwipeServiceProtocol`
- `ReferralManagerProtocol`
- `StoreManagerProtocol`
- `NotificationServiceProtocol`
- `ImageUploadServiceProtocol`
- `ContentModeratorProtocol`
- `AnalyticsManagerProtocol`
- `BlockReportServiceProtocol`
- `NetworkManagerProtocol`

**Fix:** Either:
1. Remove DependencyContainer.swift if it's not being used (likely a dependency injection pattern that was started but not completed)
2. OR create all the missing protocols

**Recommendation:** Remove DependencyContainer.swift - the app already uses singletons directly (`.shared` pattern) which works fine.

---

### 2. Duplicate Type Definitions

**EmergencyContact ambiguity:**
- Defined in: `EmergencyContactManager.swift`
- Used in: `DateCheckInManager.swift`, `SafetyManager.swift`, `EmergencyContactsView.swift`, `ShareDateView.swift`
- **Issue:** Might have duplicate import or namespace collision

**SafetyTip ambiguity:**
- Defined in: `SafetyManager.swift`
- Used in: `SafeDatingTipsView.swift`
- Has duplicate declaration error

**Fix:** Need to check if these types are defined multiple times or if there's a module/import issue.

---

### 3. Invalid Redeclarations

**EditProfileView - SectionHeader:**
- Multiple `SectionHeader` view definitions in the same file

**ImageCache - sha256():**
- String extension `sha256()` might be defined elsewhere in project

**SafetyCenter - SafetyCenterView:**
- Duplicate `SafetyCenterView` struct definitions

**Fix:** Search for duplicate declarations and remove one.

---

### 4. Protocol Conformance Issues

**DateCheckIn Type:**
- Does not conform to `Decodable`
- Does not conform to `Encodable`

**Fix:** Add `Codable` conformance or fix the implementation.

---

### 5. Method Signature Mismatches (OfflineManager)

**Issues:**
- Wrong parameters for image upload
- Wrong parameters for report user
- Wrong parameters for block user

**Fix:** Update method calls to match the actual service signatures.

---

### 6. StoreManager Infinite Recursion

**Issue:** Compiler detecting infinite recursion in purchase/restore methods.

**Possible Cause:** Might be a false positive, or there's a circular call somewhere.

**Fix:** Review the purchase flow for any circular calls.

---

### 7. Swift 6 Concurrency Warnings (SubscriptionManager)

**Issue:** Passing non-sendable types across actor boundaries.

**Fix:** Mark types as `@unchecked Sendable` or refactor to use actor-safe patterns.

---

## Quick Fix Priority

### P0 - Critical (Blocks Compilation)
1. ✅ Remove or fix `DependencyContainer.swift` (easiest: delete it)
2. ✅ Fix duplicate `SectionHeader` in EditProfileView
3. ✅ Fix duplicate `SafetyCenterView` declarations
4. ✅ Fix duplicate `EmergencyContact` / `SafetyTip` definitions
5. ✅ Fix `DateCheckIn` Codable conformance

### P1 - High (Causes Warnings)
6. ✅ Fix OfflineManager method signature mismatches
7. ✅ Fix StoreManager infinite recursion
8. ⚠️ Fix Swift 6 concurrency warnings (can suppress for now)

### P2 - Nice to Have
9. Review and fix all ambiguous type lookups
10. Add proper error handling where missing

---

## Recommended Actions

1. **Delete DependencyContainer.swift** - Unused dependency injection pattern
2. **Search and fix duplicate declarations** - Use grep to find all duplicates
3. **Fix protocol conformances** - Add Codable where needed
4. **Update OfflineManager** - Match service method signatures
5. **Review StoreManager** - Check for circular calls

Would you like me to proceed with fixing these errors?
