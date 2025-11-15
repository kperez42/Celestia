# Architecture Refactoring Roadmap
## Eliminating Singleton Dependency Hell

**Date:** November 15, 2025
**Status:** Phase 1 Complete
**Target Completion:** 14-16 weeks

---

## Executive Summary

The Celestia iOS app currently has **76 singleton classes** creating untestable global state and tight coupling. This document provides a comprehensive roadmap to refactor the architecture towards proper dependency injection, enabling:

- ✅ Unit testing (currently 0% coverage → target 80%)
- ✅ Reduced coupling
- ✅ Better scalability
- ✅ Easier maintenance
- ✅ Flexibility to swap implementations

---

## Current State Assessment

### The Singleton Problem

**Issue:** 76 classes use the singleton pattern with `.shared` access

```swift
// CURRENT (PROBLEMATIC):
class MyService {
    static let shared = MyService()  // ❌ Singleton
    private init() {}
}

// Usage everywhere:
let data = MyService.shared.getData()  // ❌ Global state, untestable
```

**Problems:**
1. **Untestable:** Cannot inject mocks for testing
2. **Global State:** All instances share same state
3. **Hidden Dependencies:** Hard to see what a class depends on
4. **Tight Coupling:** Classes directly depend on concrete implementations
5. **Initialization Order:** No control over when singletons are created
6. **Memory Management:** Singletons live for entire app lifetime

### Dependency Injection Violations Found

**Critical Violations:**
1. **ChatViewModel.swift:66, 105, 108, 122** - Bypassed injected services
2. **DiscoverViewModel.swift** - 21 .shared calls despite DI defined
3. **ProfileEditViewModel.swift** - Similar violations

**Impact:**
- Even when services are injected for testing, code uses `.shared` singletons
- Mock services are completely ignored
- Unit tests would still hit real Firebase

---

## What We've Fixed (Phase 1)

### ✅ 1. Fixed ChatViewModel Dependency Injection

**Files:** `Celestia/ChatViewModel.swift`

**Changes:**
- Line 67: Uses `matchService` instead of `MatchService.shared`
- Line 107: Uses `matchService` instead of `MatchService.shared`
- Line 111: Uses `messageService` instead of `MessageService.shared`
- Line 126: Uses `messageService` instead of `MessageService.shared`

**Before:**
```swift
if let match = try? await MatchService.shared.fetchMatch(...) {
    try await MessageService.shared.sendMessage(...)
}
```

**After:**
```swift
if let match = try? await matchService.fetchMatch(...) {
    try await messageService.sendMessage(...)
}
```

**Benefit:** ChatViewModel can now be tested with mock services ✅

---

### ✅ 2. Fixed DiscoverViewModel Dependency Injection

**Files:** `Celestia/DiscoverViewModel.swift`

**Changes:**
- Updated initializer to inject 3 services (was only injecting 1)
- Replaced 21 `.shared` calls with injected services:
  - `AuthService.shared` → `authService` (10 occurrences)
  - `SwipeService.shared` → `swipeService` (6 occurrences)
  - `UserService.shared` → `userService` (5 occurrences)

**Before:**
```swift
init(userService: UserServiceProtocol? = nil) {
    self.userService = userService ?? UserService.shared
    // Only userService was injected!
}

func likeUser() {
    AuthService.shared.currentUser  // ❌ Bypasses DI
    SwipeService.shared.likeUser()  // ❌ Bypasses DI
}
```

**After:**
```swift
init(
    userService: UserServiceProtocol? = nil,
    swipeService: SwipeServiceProtocol? = nil,
    authService: AuthServiceProtocol? = nil
) {
    self.userService = userService ?? UserService.shared
    self.swipeService = swipeService ?? SwipeService.shared
    self.authService = authService ?? AuthService.shared
}

func likeUser() {
    authService.currentUser  // ✅ Uses injected service
    swipeService.likeUser()  // ✅ Uses injected service
}
```

**Benefit:** DiscoverViewModel can now be tested with mock services ✅

---

### ✅ 3. Created Dependency Injection Container

**Files:** `Celestia/DependencyContainer.swift` (new)

**Purpose:** Centralized service management and dependency resolution

**Features:**
- Singleton container for app-wide access
- Factory methods for ViewModels with proper DI
- SwiftUI Environment integration
- Test initializer for mock injection
- Comprehensive documentation

**Architecture:**

```swift
@MainActor
class DependencyContainer: ObservableObject {
    static let shared = DependencyContainer()

    // Core Services
    let authService: any AuthServiceProtocol
    let userService: any UserServiceProtocol
    let matchService: any MatchServiceProtocol
    let messageService: any MessageServiceProtocol
    let swipeService: any SwipeServiceProtocol

    // + 11 more supporting services

    // Factory methods
    func makeChatViewModel(...) -> ChatViewModel
    func makeDiscoverViewModel() -> DiscoverViewModel
    // ...
}
```

**Usage in Views:**

```swift
struct DiscoverView: View {
    @Environment(\.dependencies) var deps
    @StateObject private var viewModel: DiscoverViewModel

    init() {
        _viewModel = StateObject(
            wrappedValue: DependencyContainer.shared.makeDiscoverViewModel()
        )
    }
}
```

**Usage in Tests:**

```swift
func testDiscoverViewModel() {
    let mockAuth = MockAuthService()
    let mockSwipe = MockSwipeService()

    let testContainer = DependencyContainer(
        authService: mockAuth,
        swipeService: mockSwipe
    )

    let viewModel = testContainer.makeDiscoverViewModel()

    // Test with mocks ✅
}
```

**Benefit:** Enables unit testing and reduces singleton coupling ✅

---

## Refactoring Roadmap

### Phase 1: Foundation (✅ COMPLETE - 1 week)

**Status:** ✅ Done

**Completed:**
- [x] Fix ChatViewModel DI violations
- [x] Fix DiscoverViewModel DI violations
- [x] Create DependencyContainer
- [x] Document usage patterns
- [x] Create refactoring roadmap

**Results:**
- 2 ViewModels now properly use DI
- 25 .shared calls eliminated
- DI Container ready for app-wide adoption

---

### Phase 2: Core ViewModels (2-3 weeks)

**Goal:** Fix remaining ViewModels that define DI but bypass it

**Tasks:**

1. **Fix ProfileEditViewModel** (2 days)
   - Audit for .shared calls
   - Inject missing services
   - Update DependencyContainer factory method

2. **Fix OnboardingViewModel** (2 days)
   - Currently uses 4+ singletons directly
   - Add DI for all services
   - Create factory method

3. **Fix SearchViewModel** (1 day)
   - Inject UserService properly
   - Remove .shared calls

4. **Update All View Instantiations** (1 week)
   - Replace direct ViewModel() calls with DependencyContainer factories
   - Update SwiftUI previews to use test container
   - Verify no .shared calls remain in ViewModels

**Deliverables:**
- All ViewModels use proper DI
- No .shared calls in ViewModel code
- Factory methods for all ViewModels

**Testing:**
- Write unit tests for each ViewModel
- Verify mocks are used (not real services)
- Target: 60% test coverage for ViewModels

---

### Phase 3: Service Layer Refactoring (3-4 weeks)

**Goal:** Reduce service-to-service singleton dependencies

**Current Problem:**
```swift
class NotificationService {
    static let shared = NotificationService()

    // Creates more singletons internally! ❌
    private let manager = PushNotificationManager.shared
    private let badgeManager = BadgeManager.shared
    private let messageService = MessageService.shared
}
```

**Tasks:**

1. **Identify Service Dependencies** (3 days)
   - Map all service-to-service dependencies
   - Create dependency graph
   - Identify circular dependencies

2. **Refactor Service Constructors** (2 weeks)
   - Add DI to service initializers
   - Break circular dependencies
   - Update DependencyContainer to inject services

   **Example:**
   ```swift
   // Before:
   class NotificationService {
       static let shared = NotificationService()

       private let manager = PushNotificationManager.shared  // ❌
   }

   // After:
   class NotificationService {
       static let shared = NotificationService()

       private let manager: PushNotificationManager

       init(pushManager: PushNotificationManager? = nil) {
           self.manager = pushManager ?? PushNotificationManager.shared
       }
   }

   // In DependencyContainer:
   let notificationService = NotificationService(
       pushManager: pushNotificationManager
   )
   ```

3. **Update DependencyContainer** (3 days)
   - Initialize services in correct order
   - Pass dependencies between services
   - Remove .shared calls from services

**Services to Refactor (Priority Order):**
1. NotificationService (creates 3 singletons)
2. OnboardingViewModel (creates 4 singletons)
3. OfflineManager (creates 2 singletons)
4. SwipeService (creates 2 singletons)
5. MessageQueueManager
6. AuthService (450+ lines, should be split)

**Deliverables:**
- Services accept dependencies via constructor
- DependencyContainer manages service graph
- Reduced .shared calls in service layer by 60%

---

### Phase 4: Extract Protocols for Testing (2-3 weeks)

**Goal:** Create protocols for all remaining services

**Current State:**
- Only 5 services have protocols (Auth, User, Match, Message, Swipe)
- 71 services have no protocol abstraction

**Tasks:**

1. **Create Service Protocols** (1 week)
   - NotificationServiceProtocol
   - ImageUploadServiceProtocol
   - VerificationServiceProtocol
   - ReferralManagerProtocol
   - ReportingManagerProtocol
   - + 10 more critical services

2. **Update Service Implementations** (1 week)
   - Conform to new protocols
   - Ensure all public methods are in protocol

3. **Update DependencyContainer** (3 days)
   - Use protocols instead of concrete types
   - Update factory methods

**Example:**
```swift
// New Protocol:
protocol NotificationServiceProtocol {
    func sendNotification(_ notification: Notification) async throws
    func registerForPushNotifications() async
}

// Service Implementation:
class NotificationService: NotificationServiceProtocol {
    static let shared = NotificationService()
    // ... implementation
}

// DependencyContainer:
let notificationService: any NotificationServiceProtocol = NotificationService.shared
```

**Deliverables:**
- 15+ new service protocols
- All major services have protocol abstractions
- DependencyContainer uses protocols

---

### Phase 5: View Layer Migration (3-4 weeks)

**Goal:** Migrate all views to use DependencyContainer instead of .shared

**Current Problem:**
```swift
struct SettingsView: View {
    var body: some View {
        Button("Sign Out") {
            AuthService.shared.signOut()  // ❌ Direct singleton access
        }
    }
}
```

**Solution:**
```swift
struct SettingsView: View {
    @Environment(\.dependencies) var deps

    var body: some View {
        Button("Sign Out") {
            deps.authService.signOut()  // ✅ Through container
        }
    }
}
```

**Tasks:**

1. **Audit All Views** (1 week)
   - Find all .shared calls in views (estimate: 200+)
   - Categorize by service type
   - Prioritize by frequency

2. **Batch Migration** (2 weeks)
   - Migrate views by feature area:
     - Authentication views (SignIn, SignUp, etc.)
     - Profile views
     - Messaging views
     - Discovery views
     - Settings views

3. **Update SwiftUI Previews** (3 days)
   - Create test DependencyContainer for previews
   - Update all previews to use test container

4. **Remove .shared Access from Views** (ongoing)
   - Replace with @Environment(\.dependencies)
   - Update factory patterns

**Deliverables:**
- All views use DependencyContainer
- No .shared calls in view layer
- Previews use test container

---

### Phase 6: Reduce Singleton Count (2-3 weeks)

**Goal:** Eliminate unnecessary singletons

**Current:** 76 singletons
**Target:** 10-15 singletons (only truly global services)

**Keep as Singletons:**
1. Logger (application-wide logging)
2. CrashlyticsManager (crash reporting)
3. AnalyticsManager (analytics)
4. NetworkMonitor (network reachability)
5. ImageCache (memory cache)
6. KeychainManager (secure storage)
7. PerformanceMonitor (monitoring)
8. DependencyContainer itself

**Convert to Regular Classes:**
- All ViewModels (should be created per view instance)
- Most services (managed by DependencyContainer)
- Managers that don't need global state

**Tasks:**

1. **Remove Unnecessary Singletons** (1 week)
   - Identify services that don't need to be singletons
   - Remove `static let shared` pattern
   - Update DependencyContainer to create instances

2. **Manage Lifecycle** (1 week)
   - Services created by DependencyContainer
   - ViewModels created per view
   - Shared services only when truly needed

**Example:**
```swift
// Before:
class UserService {
    static let shared = UserService()  // ❌
    private init() {}
}

// After:
class UserService: UserServiceProtocol {
    // No singleton! ✅
    init() {}
}

// DependencyContainer creates and manages:
class DependencyContainer {
    let userService: any UserServiceProtocol = UserService()  // ✅
}
```

**Deliverables:**
- Singleton count reduced to 10-15
- DependencyContainer manages service instances
- Clear ownership and lifecycle

---

## Testing Strategy

### Unit Testing Roadmap

**Phase 1: ViewModel Tests** (Week 5-6)
- ChatViewModel tests with mocked services
- DiscoverViewModel tests with mocked services
- ProfileEditViewModel tests
- Target: 70% ViewModel coverage

**Phase 2: Service Tests** (Week 7-8)
- UserService tests
- AuthService tests (with Firebase mocks)
- MatchService tests
- MessageService tests
- Target: 60% Service coverage

**Phase 3: Integration Tests** (Week 9-10)
- End-to-end flows with DependencyContainer
- View + ViewModel integration
- Service integration tests
- Target: 40% Integration coverage

**Overall Target:** 80% code coverage by end of Phase 6

---

## Migration Guide for Developers

### For ViewModels

**Old Pattern:**
```swift
class MyViewModel: ObservableObject {
    func doSomething() {
        AuthService.shared.signOut()  // ❌
    }
}
```

**New Pattern:**
```swift
class MyViewModel: ObservableObject {
    private let authService: any AuthServiceProtocol

    init(authService: (any AuthServiceProtocol)? = nil) {
        self.authService = authService ?? AuthService.shared
    }

    func doSomething() {
        authService.signOut()  // ✅
    }
}
```

### For Views

**Old Pattern:**
```swift
struct MyView: View {
    @StateObject private var viewModel = MyViewModel()  // ❌

    var body: some View {
        Button("Sign Out") {
            AuthService.shared.signOut()  // ❌
        }
    }
}
```

**New Pattern:**
```swift
struct MyView: View {
    @Environment(\.dependencies) var deps
    @StateObject private var viewModel: MyViewModel

    init() {
        _viewModel = StateObject(
            wrappedValue: DependencyContainer.shared.makeMyViewModel()  // ✅
        )
    }

    var body: some View {
        Button("Sign Out") {
            deps.authService.signOut()  // ✅
        }
    }
}
```

### For Services

**Old Pattern:**
```swift
class MyService {
    static let shared = MyService()

    private let otherService = OtherService.shared  // ❌

    private init() {}
}
```

**New Pattern:**
```swift
class MyService: MyServiceProtocol {
    static let shared = MyService()  // Keep for backward compatibility

    private let otherService: any OtherServiceProtocol

    init(otherService: (any OtherServiceProtocol)? = nil) {
        self.otherService = otherService ?? OtherService.shared
    }
}
```

---

## Benefits After Completion

### 1. Unit Testing Enabled ✅
- **Before:** 0% test coverage, impossible to test
- **After:** 80% test coverage, comprehensive test suite

### 2. Reduced Coupling ✅
- **Before:** 1,214+ direct .shared calls
- **After:** ~100 .shared calls (only in DependencyContainer)

### 3. Better Maintainability ✅
- **Before:** Hidden dependencies, hard to track
- **After:** Explicit dependencies, clear relationships

### 4. Easier Refactoring ✅
- **Before:** Changes ripple unpredictably
- **After:** Changes localized to specific services

### 5. Flexibility ✅
- **Before:** Locked to Firebase, specific implementations
- **After:** Can swap implementations easily

---

## Progress Tracking

### Completion Metrics

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| ViewModels using DI | 2/15 | 15/15 | 🟡 13% |
| Services with protocols | 5/76 | 15/76 | 🟢 33% (partial) |
| .shared calls | 1,214 | <100 | 🔴 8% |
| Singleton count | 76 | 10-15 | 🔴 0% |
| Unit test coverage | 0% | 80% | 🔴 0% |

### Phase Status

- ✅ **Phase 1:** Foundation - COMPLETE
- 🟡 **Phase 2:** Core ViewModels - NOT STARTED
- ⚪ **Phase 3:** Service Layer - NOT STARTED
- ⚪ **Phase 4:** Extract Protocols - NOT STARTED
- ⚪ **Phase 5:** View Layer - NOT STARTED
- ⚪ **Phase 6:** Reduce Singletons - NOT STARTED

---

## Timeline Summary

| Phase | Duration | Effort | Status |
|-------|----------|--------|--------|
| Phase 1: Foundation | 1 week | 40h | ✅ DONE |
| Phase 2: Core ViewModels | 2-3 weeks | 80-120h | 🟡 NEXT |
| Phase 3: Service Layer | 3-4 weeks | 120-160h | ⚪ PENDING |
| Phase 4: Extract Protocols | 2-3 weeks | 80-120h | ⚪ PENDING |
| Phase 5: View Layer | 3-4 weeks | 120-160h | ⚪ PENDING |
| Phase 6: Reduce Singletons | 2-3 weeks | 80-120h | ⚪ PENDING |
| **TOTAL** | **14-18 weeks** | **520-720h** | **6% DONE** |

---

## Risk Assessment

### High Risk
- **Breaking Changes:** Refactoring may introduce regressions
  - **Mitigation:** Comprehensive testing after each phase
  - **Mitigation:** Feature flags for gradual rollout

### Medium Risk
- **Developer Learning Curve:** Team needs to adopt new patterns
  - **Mitigation:** Documentation and code examples
  - **Mitigation:** Code review guidelines

### Low Risk
- **Performance Impact:** DI adds minimal overhead
  - **Mitigation:** Benchmark critical paths

---

## Success Criteria

✅ **Phase 1 Complete When:**
- [x] ChatViewModel uses injected dependencies
- [x] DiscoverViewModel uses injected dependencies
- [x] DependencyContainer created
- [x] Documentation written

✅ **Phase 2 Complete When:**
- [ ] All ViewModels use DI
- [ ] No .shared calls in ViewModel layer
- [ ] 60% ViewModel test coverage

✅ **Final Success When:**
- [ ] 80% code coverage
- [ ] <100 .shared calls app-wide
- [ ] 10-15 singletons (down from 76)
- [ ] All tests passing
- [ ] Production deployment successful

---

## Appendix A: Full Singleton List

**Services (44):**
1. AuthService
2. UserService
3. MatchService
4. MessageService
5. SwipeService
6. InterestService
7. NotificationService
8. VerificationService
9. ImageUploadService
10. ReportingManager
11. ReferralManager
12. BlockReportService
13. OfflineManager
14. PendingMessageQueue
15. MessageQueueManager
16. OnboardingViewModel (should not be singleton!)
17. SearchManager
18. FilterPresetManager
19. DiscoveryFilters
20. ABTestingManager
21. FeatureFlagManager
22. PersonalizedOnboardingManager
23. SubscriptionManager
24. StoreManager
25. ReviewPromptManager
26. ShareDateManager
27. EmergencyContactManager
28. CheckInService
29. SyncConflictResolver
30. BatchOperationManager
31. SmartRetryManager
32. RetryManager
33. CircuitBreaker
34. DateCheckInManager
35-44. (10 more services)

**Managers (15):**
45. NetworkManager
46. Logger
47. CrashlyticsManager
48. AnalyticsManager
49. AnalyticsServiceEnhanced
50. PerformanceMonitor
51. SecurityManager
52. BiometricAuthManager
53. ClipboardSecurityManager
54. ScreenshotDetectionService
55. HapticManager
56. BadgeManager
57. LocalizationManager
58. BackgroundCheckManager
59. FirebaseManager

**Utilities (17):**
60. ImageCache
61. QueryCache
62. DailyLikeLimitCache
63. ImageOptimizer
64. SearchDebouncer
65. ValidationHelper
66. InputSanitizer
67. FirebaseErrorMapper
68. NetworkMonitor
69. OfflineOperationQueue
70. ConversationStarters
71. AccessibilityAuditor
72. KeychainManager (appropriate singleton)
73. PushNotificationManager
74. NetworkInterceptors
75. DeepLinkRouter
76. AppShortcuts

---

## Appendix B: References

- **Code Review Report:** `COMPREHENSIVE_CODE_REVIEW_REPORT.md`
- **Security Fixes:** `SECURITY_FIXES_APPLIED.md`
- **DI Container:** `Celestia/DependencyContainer.swift`
- **Service Protocols:** `Celestia/ServiceProtocols.swift`

---

**Document Version:** 1.0
**Last Updated:** November 15, 2025
**Next Review:** End of Phase 2

---

**Ready to proceed with Phase 2?** See tasks in "Phase 2: Core ViewModels" section above.
