# Celestia App - Comprehensive Codebase Analysis
## UI/UX Consistency, Code Quality, and Performance Issues

---

## 1. UI/UX CONSISTENCY ISSUES

### 1.1 Inconsistent Header Gradients and Colors
**Severity:** MEDIUM | **Impact:** Visual Inconsistency

**Issue:** Each screen (Matches, Messages, Saved, Discover) implements its own custom header with different gradient colors and styling.

**Files:**
- `/home/user/Celestia/Celestia/MatchesView.swift` (lines 172-180)
  - Colors: Purple → Purple → Blue
  - LinearGradient(colors: [Color.purple.opacity(0.9), Color.purple.opacity(0.7), Color.blue.opacity(0.5)])

- `/home/user/Celestia/Celestia/MessagesView.swift` (lines 120-128)
  - Colors: Purple → Pink → Blue
  - LinearGradient(colors: [Color.purple.opacity(0.9), Color.pink.opacity(0.7), Color.blue.opacity(0.6)])

- `/home/user/Celestia/Celestia/SavedProfilesView.swift` (lines 82-90)
  - Colors: Orange → Pink → Purple
  - LinearGradient(colors: [Color.orange.opacity(0.9), Color.pink.opacity(0.7), Color.purple.opacity(0.6)])

**Problem:** No consistent header design system despite DesignSystem.swift existing. Each view reinvents the wheel.

**Recommendation:** Create a reusable HeaderView component in DesignSystem that accepts title, icon, and optional gradient override.

---

### 1.2 Hardcoded Spacing Values Throughout Codebase
**Severity:** MEDIUM | **Impact:** Maintenance Issues

**Files with hardcoded spacing:**
- `/home/user/Celestia/Celestia/EditProfileView.swift`: Uses `.padding(20)`, `.padding(.horizontal, 20)`, `.padding(.vertical, 20)` inconsistently
- `/home/user/Celestia/Celestia/MatchesView.swift` (lines 242-243): Uses `.padding(.top, 50)` and `.padding(.horizontal, 20)`
- `/home/user/Celestia/Celestia/SavedProfilesView.swift` (line 162): Uses `.padding(.horizontal, 20)` inconsistently

**Problem:** DesignSystem.swift defines spacing constants (xs: 8, sm: 12, md: 16, lg: 20, xl: 24), but views don't consistently use them.

**Recommendation:** Replace all hardcoded padding/spacing with DesignSystem constants. Example: `.padding(.horizontal, DesignSystem.Spacing.lg)` instead of `.padding(.horizontal, 20)`

---

### 1.3 Inconsistent Corner Radii
**Severity:** LOW | **Impact:** Visual Inconsistency

Views use hardcoded corner radius values:
- EditProfileView.swift (line 1731): `.cornerRadius(12)`
- Multiple views use `.cornerRadius(25)` for pills
- Should use `DesignSystem.CornerRadius` constants

---

### 1.4 Tab Bar Button Badge Style Inconsistency
**Severity:** LOW | **Impact:** Minor Visual Issue

**File:** `/home/user/Celestia/Celestia/MainTabView.swift` (lines 222-230)

Badge uses hardcoded:
```swift
LinearGradient(
    colors: [Color.red, Color.pink],
    startPoint: .leading,
    endPoint: .trailing
)
```

Different from the gradient definitions in other parts of the app.

---

## 2. COMPONENT QUALITY & CODE DUPLICATION

### 2.1 Massive View Files (Monolithic Components)
**Severity:** HIGH | **Impact:** Maintainability, Testing

**Files:**
- `EditProfileView.swift`: 1,951 lines (too large)
- `ProfileView.swift`: 1,657 lines (too large)
- `OnboardingView.swift`: 1,305 lines (too large)
- `ChatView.swift`: 1,094 lines (too large)
- `ProfileInsightsView.swift`: 1,029 lines (too large)
- `MatchesView.swift`: 965 lines (too large)
- `SavedProfilesView.swift`: 935 lines (too large)

**Problem:** Views exceed 800-1000 lines, making them difficult to test, debug, and maintain.

**Recommendation:** Break down into smaller, focused components:
- EditProfileView should be split into: BasicInfoSection, PhotoUploadSection, PreferencesSection, LanguagesSection, etc.
- ProfileView should be split into: HeaderSection, StatsSection, DetailsCard, etc.

---

### 2.2 Duplicated Header Implementation Across Views
**Severity:** MEDIUM | **Impact:** Code Duplication

Same header pattern repeated in:
- MatchesView (lines 169-249)
- MessagesView (lines 117-238)
- SavedProfilesView (lines 79-169)

All three implement nearly identical ZStack with LinearGradient, decorative circles, title, icons, and action buttons.

**Recommendation:** Create reusable `ScreenHeaderView` component:
```swift
struct ScreenHeaderView: View {
    let title: String
    let icon: String
    let gradient: LinearGradient
    let subtitle: String?
    let actionButtons: [HeaderAction]
    // ... rest of implementation
}
```

---

### 2.3 Duplicated Filter/Sort UI Components
**Severity:** MEDIUM | **Impact:** Code Duplication

- MatchesView (lines 480-550): Custom sort menu and filter UI
- SavedProfilesView: Similar filter pattern
- FeedDiscoverView: Similar filtering logic

---

### 2.4 Missing Extracted Subviews
**Severity:** MEDIUM | **Impact:** Code Readability, Maintainability

**EditProfileView.swift** (1,951 lines) - Should have extracted:
- `profilePhotoSection` (not extracted - inline)
- `photoGallerySection` (not extracted - inline)
- Multiple picker and input field combinations

Recommend extracting into separate view files or at least private computed properties.

---

## 3. NAVIGATION & SCREEN FLOW ISSUES

### 3.1 Unused Navigation Binding
**Severity:** LOW | **Impact:** Code Quality

**File:** `/home/user/Celestia/Celestia/MainTabView.swift` (line 59)
```swift
.onChange(of: selectedTab) { oldValue, newValue in
    previousTab = oldValue
    HapticManager.shared.selection()
}
```

`previousTab` is stored but never used. This accumulates unused state.

**Recommendation:** Remove unused `previousTab` property unless it will be used for back navigation.

---

### 3.2 Multiple Navigation Stacks in Nested Views
**Severity:** MEDIUM | **Impact:** Navigation Complexity

**Files:**
- FeedDiscoverView (line 49): `NavigationStack`
- MatchesView (line 111): `NavigationStack`
- MessagesView (line 50): `NavigationStack`
- ProfileView (line 39): `NavigationStack`

Each main tab uses its own NavigationStack, which can cause navigation state issues. Consider using a single NavigationStack at the MainTabView level with proper routing.

---

### 3.3 Sheet vs. NavigationStack Inconsistency
**Severity:** MEDIUM | **Impact:** Navigation UX

- MessagesView opens ChatView in a `.sheet()` (lines 85-92)
- But ChatView internally uses `.navigationBarHidden(true)` and manually manages back button

Should either:
1. Use NavigationStack and NavigationLink everywhere, or
2. Use sheets consistently and ensure proper back button handling

---

## 4. PERFORMANCE ISSUES

### 4.1 Polling-Based Badge Updates
**Severity:** MEDIUM | **Impact:** Battery Drain, Network Usage

**File:** `/home/user/Celestia/Celestia/MainTabView.swift` (lines 143-163)

```swift
private func updateBadgesPeriodically() async {
    guard let userId = authService.currentUser?.id else { return }
    
    while !Task.isCancelled {
        unreadCount = await messageService.getUnreadMessageCount(userId: userId)
        try await matchService.fetchMatches(userId: userId)
        try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
    }
}
```

**Problems:**
1. Fetches ALL matches every 10 seconds, not just new ones
2. Inefficient for large match lists
3. Continuous polling drains battery
4. No exponential backoff when app is backgrounded

**Recommendation:**
- Use Firebase listeners instead of polling (`addSnapshotListener`)
- Implement incremental updates
- Pause listeners when app goes to background

---

### 4.2 Unnecessary Re-renders Due to Multiple Binding Updates
**Severity:** MEDIUM | **Impact:** Performance

**File:** `/home/user/Celestia/Celestia/MatchesView.swift` (lines 43-95)

The `filteredAndSortedMatches` computed property recalculates on every view render:
- Recalculates when `searchDebouncer.debouncedText` changes
- Recalculates when `sortOption` changes
- Performs string comparisons on every element
- Complex filtering logic runs frequently

**Recommendation:** Cache the filtered results in `@State` instead of recalculating.

---

### 4.3 Large Gradient Calculations in Headers
**Severity:** LOW | **Impact:** Minor Performance

Each header view creates new LinearGradient instances on every render:
- `/home/user/Celestia/Celestia/MatchesView.swift` (lines 172-180)
- `/home/user/Celestia/Celestia/MessagesView.swift` (lines 120-128)
- `/home/user/Celestia/Celestia/SavedProfilesView.swift` (lines 82-90)

**Recommendation:** Extract these as constants or static properties.

---

### 4.4 State Object Initialization at View Level
**Severity:** MEDIUM | **Impact:** Memory Usage

**File:** `/home/user/Celestia/Celestia/EditProfileView.swift` (lines 15-51)

38 @State properties in a single view:
```swift
@State private var fullName: String
@State private var age: String
@State private var bio: String
// ... 35 more properties
```

This creates significant memory overhead and makes state management complex.

**Recommendation:** Consider grouping related state into a nested view model or use a single state object.

---

## 5. ERROR HANDLING ISSUES

### 5.1 Silent Error Handling (Empty catch blocks)
**Severity:** HIGH | **Impact:** Debugging Difficulty

Error handling pattern found throughout:
```swift
do {
    try await someOperation()
} catch {
    Logger.shared.error("Error message", category: .category, error: error)
}
```

While logging is present, **there's no user-facing error UI** in many places:
- `/home/user/Celestia/Celestia/MainTabView.swift` (lines 155-157)
- `/home/user/Celestia/Celestia/DiscoverViewModel.swift` (error handling)

**Recommendation:** Show error toasts or sheets for user-critical operations.

---

### 5.2 Missing Loading State in Critical Operations
**Severity:** MEDIUM | **Impact:** UX

- Profile editing: No loading indicator during save
- Photo uploads: Limited feedback on upload progress
- Filter application: No state indication during filter load

**Recommendation:** Add `.isLoading` state and display activity indicators during async operations.

---

### 5.3 fatalError in Production Code
**Severity:** HIGH | **Impact:** App Crashes

**File:** `/home/user/Celestia/Celestia/NetworkManager.swift` (lines 144-157)

```swift
if hashes.isEmpty {
    fatalError("""
        ⚠️ CRITICAL SECURITY ERROR ⚠️
        
        Certificate pinning is not configured for PRODUCTION build...
        """)
}
```

**Problem:** `fatalError` crashes the app immediately. This should use a recoverable error handling mechanism or be guarded at build-time.

**Recommendation:** Use runtime error handling instead:
```swift
if hashes.isEmpty {
    Logger.shared.critical("Certificate pinning not configured", category: .security)
    // Return safe error or use fallback
    return defaultHashes()
}
```

---

### 5.4 Unmatched Error State Pattern
**Severity:** MEDIUM | **Impact:** Inconsistency

Some views check `errorMessage`:
- `/home/user/Celestia/Celestia/MatchesView.swift` (line 126)

Others don't have error states:
- SavedProfilesView shows loading/empty, but has no error view for failed loads

**Recommendation:** Create consistent error handling pattern across all views.

---

## 6. ACCESSIBILITY ISSUES

### 6.1 Missing Accessibility Labels on Interactive Elements
**Severity:** MEDIUM | **Impact:** VoiceOver Users

**File:** `/home/user/Celestia/Celestia/SavedProfilesView.swift` (lines 149-159)

Clear All button:
```swift
Button {
    showClearAllConfirmation = true
    HapticManager.shared.impact(.light)
} label: {
    Image(systemName: "trash.circle.fill")
        .font(.title3)
        .foregroundColor(.white)
        // Missing: .accessibilityLabel("Clear all saved profiles")
        // Missing: .accessibilityHint("Deletes all saved profiles permanently")
}
```

**Recommendation:** Add accessibility labels and hints to all interactive elements.

---

### 6.2 Decorative Elements Not Hidden from Accessibility
**Severity:** MEDIUM | **Impact:** VoiceOver Clutter

Decorative gradient circles in headers:
```swift
Circle()
    .fill(Color.white.opacity(0.1))
    .frame(width: 100, height: 100)
    .blur(radius: 20)
    // Missing: .accessibilityHidden(true)
```

These appear in:
- SavedProfilesView (lines 94-105)
- MessagesView (lines 131-143)

**Recommendation:** Hide decorative elements with `.accessibilityHidden(true)`.

---

### 6.3 Dynamic Type Not Fully Supported in Headers
**Severity:** LOW | **Impact:** Readability for Large Text Users

Headers use fixed font sizes:
```swift
.font(.largeTitle.weight(.bold))
.font(.subheadline)
```

Without dynamic type bounds:
```swift
.dynamicTypeSize(min: .medium, max: .accessibility2)
```

The rest of the app has this, but headers don't.

---

## 7. CODE QUALITY ISSUES

### 7.1 Debug Print Statements in Production Code
**Severity:** LOW | **Impact:** Code Hygiene

**File:** `/home/user/Celestia/Celestia/Logger.swift` (line 228)
```swift
print(message)
```

And in Constants.swift (lines 223-224, 229):
```swift
if Debug.loggingEnabled {
    print("[\(category)] \(message)")
}
```

These should use proper logging infrastructure only, not print().

---

### 7.2 Test Crash Code in Production
**Severity:** HIGH | **Impact:** Security, Stability**

**File:** `/home/user/Celestia/Celestia/CrashlyticsManager.swift` (line 269)
```swift
fatalError("Test crash triggered from CrashlyticsManager")
```

This should not exist in production code.

---

### 7.3 Inconsistent Nil Coalescing for DEBUG vs RELEASE
**Severity:** MEDIUM | **Impact:** Code Smell

**File:** `/home/user/Celestia/Celestia/MatchesView.swift` (lines 53-68)

Pattern repeats throughout:
```swift
#if DEBUG
let userId = authService.currentUser?.id ?? "current_user"
#else
guard let userId = authService.currentUser?.id else { return }
#endif
```

This pattern appears in:
- MatchesView (lines 54, 65)
- MessagesView (lines 41-45)

**Problem:** In DEBUG, defaults to "current_user" if nil. In production, returns early. This creates testing blind spots.

**Recommendation:** Ensure consistent behavior in both modes. Unit tests should use proper mocking.

---

### 7.4 Multiple Environment Objects/Observed Objects in Single View
**Severity:** MEDIUM | **Impact:** Coupling, Testing

**File:** `/home/user/Celestia/Celestia/MatchesView.swift` (lines 12-19)

```swift
@EnvironmentObject var authService: AuthService
@ObservedObject private var matchService = MatchService.shared
@ObservedObject private var userService = UserService.shared
@ObservedObject private var messageService = MessageService.shared
@StateObject private var searchDebouncer = SearchDebouncer(delay: 0.3)
```

**Problem:** Tight coupling to multiple services. Difficult to test in isolation.

**Recommendation:** Use dependency injection. Consider creating a view model that wraps these dependencies.

---

### 7.5 Unused Property
**Severity:** LOW | **Impact:** Code Quality

**File:** `/home/user/Celestia/Celestia/MainTabView.swift` (line 16)

```swift
@State private var previousTab = 0
```

This is set but never read. It's accumulated in state without purpose.

---

## 8. STATE MANAGEMENT ISSUES

### 8.1 Duplicate State Between View and ViewModel
**Severity:** MEDIUM | **Impact:** Data Consistency

**File:** `/home/user/Celestia/Celestia/FeedDiscoverView.swift** (lines 16-28)

```swift
@State private var users: [User] = []
@State private var displayedUsers: [User] = []
@State private var currentPage = 0
@State private var isLoading = false
```

But also observes:
```swift
@ObservedObject private var savedProfilesViewModel = SavedProfilesViewModel.shared
```

**Problem:** Mixing local state and shared view model state can cause synchronization issues.

---

### 8.2 Shared Singleton Services Without Lifecycle Management
**Severity:** MEDIUM | **Impact:** Memory Leaks, State Persistence

Multiple views access `.shared` singletons:
- `AuthService.shared`
- `MatchService.shared`
- `MessageService.shared`
- `UserService.shared`
- `SavedProfilesViewModel.shared`

**Problem:** No clear lifecycle for when state should be cleared. State persists across app sessions unexpectedly.

**Recommendation:** Implement proper cleanup in deinit or use dependency injection instead of singletons.

---

### 8.3 Conflicting State Updates
**Severity:** MEDIUM | **Impact:** Race Conditions

**File:** `/home/user/Celestia/Celestia/SavedProfilesView.swift` (lines 49-54)

```swift
.task {
    await viewModel.loadSavedProfiles()
    if !viewModel.savedProfiles.isEmpty {
        HapticManager.shared.notification(.success)
    }
}
```

And separately in body:
```swift
if viewModel.isLoading { loadingView }
else if !viewModel.errorMessage.isEmpty { errorStateView }
else if viewModel.savedProfiles.isEmpty { emptyStateView }
```

**Problem:** Multiple view checks depend on view model state that updates asynchronously. Race condition possible if multiple tasks update state simultaneously.

---

## 9. DATA CONSISTENCY ISSUES

### 9.1 Cache Timestamp Update Mentioned but Implementation Unclear
**Severity:** LOW | **Impact:** Data Freshness**

Recent git commit mentions: "fix: update cache timestamp when saving profiles"

But no clear indication of:
- Where cache is stored
- How TTL is enforced
- If invalidation works correctly

**Recommendation:** Document cache strategy clearly.

---

### 9.2 Unread Message Count Synchronization
**Severity:** MEDIUM | **Impact:** Incorrect Unread Badges**

**File:** `/home/user/Celestia/Celestia/MainTabView.swift** (lines 143-163)

Unread count polled every 10 seconds, but:
- What if message arrives between polls?
- What if user reads message in another tab?
- No real-time listener

**Recommendation:** Use Firebase listeners for real-time updates.

---

### 9.3 Favorites Sync Issues
**Severity:** MEDIUM | **Impact:** Stale Data

**File:** `/home/user/Celestia/Celestia/FeedDiscoverView.swift** (lines 76, 85-86)

```swift
.onAppear {
    if users.isEmpty {
        Task {
            await loadUsers()
            await savedProfilesViewModel.loadSavedProfiles()
            syncFavorites()
        }
    }
}
.onChange(of: savedProfilesViewModel.savedProfiles) { _ in
    syncFavorites()
}
```

**Problem:** `syncFavorites()` implementation not shown. If SavedProfilesView updates saved profiles, this view might not refresh in time.

---

## 10. DESIGN PATTERNS & BEST PRACTICES

### 10.1 Missing View Model for Complex Views
**Severity:** HIGH | **Impact:** Maintainability, Testing

**Files:**
- EditProfileView.swift - No ViewModel (direct state management in view)
- ProfileView.swift - No ViewModel
- SavedProfilesView.swift - Uses ViewModel (good pattern)

**Recommendation:** Implement ViewModels for EditProfileView and ProfileView following SavedProfilesViewModel pattern.

---

### 10.2 Inconsistent Error Handling Pattern
**Severity:** MEDIUM | **Impact:** Code Consistency

Some views have @State var errorMessage, others don't:
- MatchesView: has `@State private var errorMessage: String = ""`
- MessagesView: NO error state
- SavedProfilesView: NO error state (only loading)

**Recommendation:** Standardize error handling across all views.

---

### 10.3 Missing Cancellation of Async Tasks
**Severity:** MEDIUM | **Impact:** Memory Leaks

**File:** `/home/user/Celestia/Celestia/DiscoverViewModel.swift** (lines 49-52)

```swift
private var loadUsersTask: Task<Void, Never>?
private var likeTask: Task<Void, Never>?
private var passTask: Task<Void, Never>?
private var filterTask: Task<Void, Never>?
```

Good! Tasks are stored for cancellation. But need to verify they're cleaned up in deinit:
```swift
deinit {
    loadUsersTask?.cancel()
    likeTask?.cancel()
    // etc.
}
```

**Recommendation:** Verify all stored tasks are cancelled in deinit.

---

### 10.4 DispatchQueue Usage Mixed with async/await
**Severity:** MEDIUM | **Impact:** Code Modernization

**File:** `/home/user/Celestia/Celestia/MainTabView.swift** (line 198)

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
    isPressed = false
}
```

Mixing DispatchQueue with async/await (lines 66, 161 use Task.sleep).

**Recommendation:** Use Task-based scheduling consistently:
```swift
Task {
    try? await Task.sleep(nanoseconds: 150_000_000)
    isPressed = false
}
```

---

### 10.5 Incomplete Feature Flags
**Severity:** LOW | **Impact:** Code Management

**File:** `/home/user/Celestia/Celestia/Constants.swift** (lines 113-120)

```swift
enum Features {
    static let voiceMessagesEnabled = false
    static let videoCallsEnabled = false
    static let storiesEnabled = false
    static let groupChatsEnabled = false
    static let gifSupportEnabled = true
    static let locationTrackingEnabled = true
}
```

These flags exist but need to be actually used throughout the codebase to gate features properly.

---

## SUMMARY OF CRITICAL ISSUES

| Priority | Count | Category | Impact |
|----------|-------|----------|--------|
| **CRITICAL** | 3 | fatalError/crashes, Test code in prod, Missing error UI | App Stability |
| **HIGH** | 5 | Monolithic views, Singleton state mgmt, Missing ViewModels | Maintainability, Testing |
| **MEDIUM** | 18 | Polling instead of listeners, Duplication, Inconsistent patterns | Performance, UX, Consistency |
| **LOW** | 8 | Print statements, Unused vars, Minor UI issues | Code Quality |

---

## RECOMMENDED QUICK WINS (1-3 points each)

1. Extract reusable HeaderView component (remove duplication)
2. Remove `previousTab` unused state
3. Fix DEBUG/RELEASE inconsistency patterns
4. Hide decorative elements from accessibility
5. Replace hardcoded spacing with DesignSystem constants
6. Remove test crash code and print statements
7. Add error states to MessagesView and SavedProfilesView
8. Replace DispatchQueue.main.asyncAfter with Task-based scheduling

---

## RECOMMENDED MAJOR REFACTORS (5+ points each)

1. Break down EditProfileView (1,951 lines) into separate components
2. Break down ProfileView (1,657 lines) into separate sections
3. Replace polling badge updates with Firebase listeners
4. Implement ViewModels for EditProfileView and ProfileView
5. Migrate from singleton pattern to dependency injection
6. Create centralized navigation handling (single NavigationStack vs. multiple)
