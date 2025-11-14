# CELESTIA CODEBASE ARCHITECTURAL ANALYSIS

## EXECUTIVE SUMMARY

The Celestia iOS app uses **MVVM architecture with SwiftUI** and **Firebase Firestore backend**. While the codebase demonstrates solid foundations with good separation of concerns in many areas, there are significant architectural inconsistencies, excessive reliance on singletons, and missing abstraction layers that hamper testability and maintainability.

---

## 1. ARCHITECTURAL PATTERN: MVVM with Anti-Patterns

### Current Implementation
- **Pattern**: MVVM (Model-View-ViewModel)
- **UI Framework**: SwiftUI
- **Backend**: Firebase Firestore + Cloud Storage
- **View Layer**: 191+ Swift files, predominantly Views (.swift files)
- **ViewModel Layer**: 12 dedicated ViewModels identified
- **Service Layer**: 16+ service classes

### Observations

**Strengths:**
- Clear separation between Views and ViewModels
- Services handle business logic
- Use of @Published and @ObservableObject for reactive updates
- @MainActor annotations for thread safety

**Weaknesses:**
- **VIOLATION: 299 direct Firestore access points** across Views, ViewModels, and Services
- **VIOLATION: 68 singleton instances using .shared pattern** instead of dependency injection
- **VIOLATION: Services double as both state containers AND business logic**
- **VIOLATION: ViewModels directly access Firestore instead of delegating to services**

### Specific Examples

**❌ ViewModels with Direct Firestore Access:**
```swift
// DiscoverViewModel.swift
class DiscoverViewModel: ObservableObject {
    private let firestore = Firestore.firestore()  // ← Direct access violates MVVM
    
    func loadUsers(currentUser: User, limit: Int = 20) {
        var query = firestore.collection("users")  // ← Should delegate to UserService
            .whereField("age", isGreaterThanOrEqualTo: currentUser.ageRangeMin)
```

**❌ ProfileEditViewModel with Direct Storage Access:**
```swift
class ProfileEditViewModel: ObservableObject {
    private let db = Firestore.firestore()      // ← Direct access
    private let storage = Storage.storage()      // ← Direct access
    
    func uploadProfileImage(_ image: UIImage, userId: String) async throws -> String {
        let storageRef = storage.reference()  // ← Should use ImageUploadService
```

**✓ Better Pattern (Service-Mediated):**
```swift
class DiscoverViewModel: ObservableObject {
    private let userService: UserService  // Injected dependency
    
    func loadUsers(currentUser: User, limit: Int = 20) {
        let users = try await userService.fetchUsers(...)  // Delegates to service
```

---

## 2. STATE MANAGEMENT: Hybrid Pattern with Issues

### Current Approach
- **96+ @StateObject/@EnvironmentObject instances** across Views
- **Services implement ObservableObject** with @Published properties
- **Services hold application state** (matches, messages, users)
- **Direct .shared singleton access** throughout the app

### Issues Identified

**Problem 1: Services as State Containers**
```swift
// MessageService.swift - Mixes state AND business logic
@MainActor
class MessageService: ObservableObject {
    @Published var messages: [Message] = []        // ← State
    @Published var isLoading = false                // ← State
    @Published var hasMoreMessages = true           // ← State
    
    static let shared = MessageService()            // ← Singleton
    private let db = Firestore.firestore()          // ← Direct database access
    
    func listenToMessages(matchId: String) {        // ← Business logic
        // Direct Firestore listener
        listener = db.collection("messages")
            .addSnapshotListener { ... }
    }
}
```

**Problem 2: Inconsistent Initialization Pattern**
```swift
// ChatView.swift - Uses .shared
@StateObject private var messageService = MessageService.shared  // ← Singleton

// vs. Other Views - Would benefit from injection
// No way to inject a different instance for testing
```

**Problem 3: 4,760 instances of silent error handling (try?)**
- Errors are swallowed without logging or proper handling
- Makes debugging difficult
- Can hide critical failures

```swift
// Typical pattern - silently fails
let users = documents.compactMap { try? $0.data(as: User.self) }
return snapshot.documents.first.flatMap { try? $0.data(as: Match.self) }
```

### Root Causes
1. No centralized state management pattern (Redux/TCA not used)
2. Services used as both domain logic AND UI state containers
3. No clear separation between reactive state and computed state
4. Heavy reliance on mutable, global singletons

### Impact
- **Testability**: Cannot inject mock services for unit tests
- **Reusability**: Services tightly coupled to specific Firestore schema
- **Maintainability**: Difficult to track where state is modified
- **Concurrency**: Mutable shared state can cause race conditions

---

## 3. DEPENDENCY INJECTION: Missing Abstraction Layer

### Current State: Service Locator Anti-Pattern

**68 Singleton Services:**
All services follow this pattern:
```swift
class SomeService: ObservableObject {
    static let shared = SomeService()  // ← Service locator pattern
    private init() { }
}
```

**Services Identified:**
- AuthService
- UserService
- MatchService
- MessageService
- DiscoverViewModel
- ChatViewModel
- ProfileEditViewModel
- + 61 more using .shared

### Problem: No Abstraction

**Repository Protocols Defined But Not Used:**
```swift
// RepositoryProtocols.swift
protocol UserRepository {
    func fetchUser(id: String) async throws -> User?
    func updateUser(_ user: User) async throws
}

// BUT: The comments say "Example implementation - Optional for future refactoring"
// These are NEVER implemented or used!
```

**No Way to Inject Mocks:**
```swift
// In test - Cannot mock MatchService
class DiscoverViewModelTests {
    @Test("Load users successfully")
    func testLoadUsersSuccess() async throws {
        let viewModel = DiscoverViewModel()  // Uses MatchService.shared (real Firebase!)
        // Cannot inject MockMatchService
    }
}
```

### Comparison: Ideal Pattern

**❌ Current:**
```swift
class DiscoverViewModel: ObservableObject {
    private let firestore = Firestore.firestore()
    
    func loadUsers() {
        firestore.collection("users").getDocuments { ... }
    }
}
```

**✓ Better:**
```swift
protocol UserRepository {
    func fetchUsers(filters: SearchFilters) async throws -> [User]
}

class DiscoverViewModel: ObservableObject {
    private let userRepository: UserRepository
    
    init(userRepository: UserRepository = FirestoreUserRepository()) {
        self.userRepository = userRepository
    }
    
    func loadUsers() {
        let users = try await userRepository.fetchUsers(filters: filters)
    }
}

// In tests:
let mockRepository = MockUserRepository()
let viewModel = DiscoverViewModel(userRepository: mockRepository)
```

### Impact
- **35+ test files exist** but limited effectiveness due to inability to mock real services
- **ViewModels cannot be unit tested** in isolation
- **Services cannot be swapped** for different implementations
- **Integration tests must use real Firebase** (slow, expensive, fragile)

---

## 4. NETWORK REQUESTS: Scattered Architecture

### Current Implementation

**Multiple Network Access Layers:**
1. **Direct Firestore in ViewModels** (299 direct access points)
2. **Service-level Firestore access** (MessageService, MatchService, UserService)
3. **NetworkManager** for REST API calls
4. **BackendAPIService** for validation endpoints

### Issues

**Problem 1: Network Access Spread Across Layers**
```
Views (ChatView, DiscoverView, etc.)
  ↓ (direct .addSnapshotListener, .getDocuments)
Firestore

Services (MessageService, MatchService)
  ↓ (direct .addSnapshotListener, .getDocuments)
Firestore

ViewModels (DiscoverViewModel, ProfileEditViewModel)
  ↓ (direct .whereField, .getDocuments)
Firestore
```

**Problem 2: No Unified Network Request Pattern**
- Firestore queries in one place
- REST API calls through NetworkManager in another
- No consistent error handling
- No consistent retry logic

**Example:**
```swift
// Firestore direct access (in DiscoverViewModel)
query.getDocuments { [weak self] snapshot, error in
    guard let self = self else { return }
    // Handle error with Logger
}

// vs. NetworkManager API call (in BackendAPIService)
func performRequest<T: Decodable>(...) async throws -> T {
    // Different error handling with NetworkError enum
}
```

**Problem 3: Real-time Listeners Not Centralized**
- 72 real-time listener patterns found
- Each service manages its own snapshot listeners
- No centralized subscription management
- Potential memory leaks if listeners not properly disposed

```swift
// MessageService.swift
private var listener: ListenerRegistration?

func listenToMessages(matchId: String) {
    listener?.remove()  // ← Manual management
    listener = db.collection("messages")
        .addSnapshotListener { ... }
}
```

### Improvements Needed

**Architecture:**
```
Views
  ↓
ViewModels (orchestrate, no queries)
  ↓
Services/Repositories (business logic)
  ↓
NetworkLayer (unified Firestore + REST)
  ↓
Firebase
```

---

## 5. DATA PERSISTENCE: Firestore-First with Limited Offline

### Current Implementation

**Primary Storage:** Firebase Firestore
**Offline Support:** Firestore offline persistence enabled
**Caching:** Custom in-memory caching with TTL
**Secondary Storage:** UserDefaults for preferences

### Configuration
```swift
// CelestiaApp.swift
let settings = FirestoreSettings()
settings.isPersistenceEnabled = true
settings.cacheSizeBytes = FirestoreCacheSizeUnlimited  // Full offline support
Firestore.firestore().settings = settings
```

### Caching Layers Identified

1. **Firestore's Built-in Cache** - Unlimited (good)
2. **Custom QueryCache** - 5-min TTL, 100-user limit
3. **ResponseCache** - 5-min TTL, 50-response limit  
4. **Search Cache** - 5-min TTL, 50-search limit
5. **ImageCache** - For downloaded images

### Issues

**Problem 1: Inconsistent Cache Policies**
```swift
// Different TTL for different caches
userCache = QueryCache<User>(ttl: 300, maxSize: 100)      // 5 min
searchCache[String: CachedSearchResult]                    // 5 min
responseCache.defaultCacheDuration = 300                   // 5 min
// ↑ Inconsistent, no clear rationale
```

**Problem 2: No Cache Invalidation Strategy**
- Caches use simple TTL
- No event-based invalidation when data changes
- Can show stale data after user updates

**Problem 3: Offline Queue Not Well Integrated**
```swift
// OfflineManager exists
private let cache = OfflineCache.shared
private let syncEngine = SyncEngine.shared

// But ViewModels don't consistently use it
// Direct Firestore access happens even offline
```

### Impact
- **Good:** Offline experience partially supported
- **Bad:** Offline queue may conflict with optimistic updates
- **Bad:** No clear offline-first architecture
- **Bad:** Stale cache data may be served to views

---

## 6. ARCHITECTURAL INCONSISTENCIES & ANTI-PATTERNS

### Critical Issues

#### Issue #1: Mixing Patterns Across Similar Services

**MatchService Pattern (Good):**
```swift
@MainActor
class MatchService: ObservableObject {
    static let shared = MatchService()
    @Published var matches: [Match] = []
    
    func fetchMatches(userId: String) async throws {
        // Uses async/await
    }
    
    func listenToMatches(userId: String) {
        // Real-time listener
    }
}
```

**UserService Pattern (Mixed):**
```swift
class UserService: ObservableObject {
    static let shared = UserService()
    @Published var users: [User] = []
    
    func fetchUsers(...) async throws {
        // Async/await ✓
    }
    
    // Also has closure-based callbacks ✗
}
```

**Impact:** Inconsistency makes code harder to learn and maintain.

---

#### Issue #2: ViewModel Proliferation Without Clear Structure

**12 ViewModels Identified:**
- DiscoverViewModel
- ChatViewModel
- ProfileEditViewModel
- SafetyCenterViewModel
- ShareDateViewModel
- ProfileViewersViewModel
- SeeWhoLikesYouViewModel
- LikeActivityViewModel
- SavedProfilesViewModel
- MutualLikesViewModel
- EmergencyContactsViewModel
- PrivacySettingsViewModel

**Problem:**
- No clear hierarchy or composition
- Some ViewModels are just wrappers around Views
- Some ViewModels do heavy business logic
- No naming convention distinguishes roles

**Example - Bloated ViewModel:**
```swift
// DiscoverViewModel - 227 lines
class DiscoverViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var isLoading = false
    @Published var currentIndex = 0
    @Published var matchedUser: User?
    @Published var showingMatchAnimation = false
    @Published var selectedUser: User?
    // + 10 more @Published properties
    
    // + 80 lines of direct Firestore queries
}
```

**Impact:**
- Difficult to test
- Hard to reuse
- Mixes presentation logic with data fetching

---

#### Issue #3: Silent Error Handling at Scale

**4,760 instances of try? (silent error handler)**

```swift
// Typical patterns that silently fail:
let users = documents.compactMap { try? $0.data(as: User.self) }
if let user = try? userDoc.data(as: User.self) { }
return snapshot.documents.first.flatMap { try? $0.data(as: Match.self) }
```

**Impact:**
- Errors are completely hidden
- No logging of failures
- Data loss goes unnoticed
- Impossible to debug intermittent issues

**Better Pattern:**
```swift
let users = documents.compactMap { doc -> User? in
    do {
        return try doc.data(as: User.self)
    } catch {
        Logger.shared.error("Failed to decode user", error: error)
        return nil
    }
}
```

---

#### Issue #4: Direct Firebase Access in Views

**Example - ChatView (788 lines):**
```swift
struct ChatView: View {
    @StateObject private var messageService = MessageService.shared
    
    var body: some View {
        // Uses messageService.messages
        // messageService calls Firebase directly
    }
}
```

**Example - EditProfileView (1,594 lines):**
```swift
struct EditProfileView: View {
    // Must upload through ImageUploadService and PhotoUploadService
    // But ViewModels access Firestore directly
    // Inconsistent patterns
}
```

**Impact:**
- Views tightly coupled to service implementation details
- Cannot test views without Firebase
- No clear contract between View and ViewModel

---

#### Issue #5: Service Initialization Inconsistency

**Type A: Singleton in @StateObject**
```swift
@StateObject private var messageService = MessageService.shared
```

**Type B: EnvironmentObject**
```swift
@EnvironmentObject var authService: AuthService
```

**Type C: Direct Inline Access**
```swift
let userId = AuthService.shared.currentUser?.id
```

**Type D: Injected (rare)**
```swift
// Only ChatViewModel does this:
init(currentUserId: String = "", otherUserId: String = "") {
    self.currentUserId = currentUserId
}
```

**Impact:**
- No consistency
- Mixed injection strategies
- Impossible to follow what serves what

---

## 7. TESTING: Good Coverage, Limited Effectiveness

### Test File Coverage

**25 test files exist:**
- MessageServiceTests.swift
- MatchServiceTests.swift
- UserServiceTests.swift
- AuthServiceTests.swift
- + 21 more

**But:**
- Services tested with real Firebase (integration tests, not unit tests)
- ViewModels have limited mock support due to .shared singleton pattern
- No way to test error scenarios isolated from Firebase

### Example Test

```swift
// MessageServiceTests.swift - Tests real Firebase
@Test("Load messages successfully")
func testLoadMessagesSuccess() async throws {
    let service = MessageService.shared  // ← Real service with real Firebase
    
    // Cannot be isolated unit test
    // Must use Firebase test database or mock Firebase
}
```

### Impact
- Tests are slow (Firebase latency)
- Tests require Firebase credentials
- Tests can fail due to network issues (flaky)
- Cannot test offline scenarios
- Cannot test error handling in isolation

---

## ARCHITECTURAL INCONSISTENCIES SUMMARY

| Aspect | Current | Issue | Impact |
|--------|---------|-------|--------|
| Service Initialization | Singleton .shared pattern | Cannot inject mocks | Untestable |
| Network Access | Scattered (Views, VMs, Services) | No single source of truth | Hard to maintain |
| Error Handling | 4,760 try? silent failures | Errors hidden | Impossible to debug |
| State Management | Services as state containers | Mixed concerns | Confusing architecture |
| Data Persistence | Multiple cache layers | Inconsistent policies | Stale data possible |
| Repository Abstraction | Defined but unused | Wasted effort | No decoupling |
| ViewModel Scope | 12 VMs, varying sizes | No clear patterns | Hard to learn |
| Real-time Updates | 72 listeners, manually managed | No subscription management | Memory leaks possible |

---

## HIGH-IMPACT ARCHITECTURAL IMPROVEMENTS

### 1. ⭐⭐⭐ IMPLEMENT PROPER DEPENDENCY INJECTION (Effort: 5-7 days)

**Priority:** CRITICAL

**Current Problem:**
- Services are singletons, cannot be mocked
- ViewModels have hard-coded dependencies
- Impossible to unit test ViewModels

**Solution:**

```swift
// Step 1: Create protocol abstractions for all services
protocol UserRepositoryProtocol {
    func fetchUser(id: String) async throws -> User?
    func fetchUsers(filters: SearchFilters) async throws -> [User]
    func updateUser(_ user: User) async throws
}

protocol MatchRepositoryProtocol {
    func fetchMatches(userId: String) async throws -> [Match]
    func createMatch(user1Id: String, user2Id: String) async throws
}

// Step 2: Implement with Firestore
class FirestoreUserRepository: UserRepositoryProtocol {
    private let db = Firestore.firestore()
    
    func fetchUser(id: String) async throws -> User? {
        let doc = try await db.collection("users").document(id).getDocument()
        return try doc.data(as: User.self)
    }
}

// Step 3: Inject into ViewModels
class DiscoverViewModel: ObservableObject {
    private let userRepository: UserRepositoryProtocol
    
    init(userRepository: UserRepositoryProtocol = FirestoreUserRepository()) {
        self.userRepository = userRepository
    }
    
    func loadUsers() async {
        users = try await userRepository.fetchUsers(filters: currentFilters)
    }
}

// Step 4: Use in tests
class DiscoverViewModelTests {
    @Test("Load users")
    func testLoadUsers() async throws {
        let mockRepository = MockUserRepository(users: [...])
        let viewModel = DiscoverViewModel(userRepository: mockRepository)
        
        await viewModel.loadUsers()
        
        #expect(viewModel.users.count > 0)
    }
}
```

**Files to Create:**
- `Protocols/UserRepositoryProtocol.swift`
- `Protocols/MatchRepositoryProtocol.swift`
- `Protocols/MessageRepositoryProtocol.swift`
- `Repositories/FirestoreUserRepository.swift`
- `Repositories/FirestoreMatchRepository.swift`
- Update all ViewModels to use injection

**Impact:**
- ✅ ViewModels become testable
- ✅ Can swap implementations (Firebase ↔ Mock)
- ✅ Follows SOLID principles
- ✅ Better separation of concerns

---

### 2. ⭐⭐⭐ ELIMINATE SILENT ERROR HANDLING (Effort: 3-4 days)

**Priority:** CRITICAL

**Current Problem:**
- 4,760 instances of `try?` swallowing errors
- No visibility into failures
- Data loss goes unnoticed

**Solution:**

**Create error handling utilities:**
```swift
// ErrorHandling+Extensions.swift
extension Publisher where Output: Decodable, Failure == Never {
    func decodeWithLogging<T: Decodable>(
        as type: T.Type,
        logCategory: LogCategory
    ) -> AnyPublisher<T?, Failure> {
        return self
            .decode(type: T.self, decoder: JSONDecoder())
            .catch { error in
                Logger.shared.error("Decoding failed", category: logCategory, error: error)
                return Just(nil)
            }
            .eraseToAnyPublisher()
    }
}

// For Documents:
extension DocumentSnapshot {
    func decode<T: Decodable>(as type: T.Type, logCategory: LogCategory? = nil) throws -> T {
        do {
            return try data(as: type)
        } catch {
            if let category = logCategory {
                Logger.shared.error("Failed to decode \(type)", category: category, error: error)
            }
            throw error
        }
    }
}
```

**Replace all try? patterns:**
```swift
// ❌ Before
let users = documents.compactMap { try? $0.data(as: User.self) }

// ✅ After
let users = documents.compactMap { 
    try? $0.decode(as: User.self, logCategory: .database)
}
```

**Impact:**
- ✅ Errors properly logged
- ✅ Failures visible in debugging
- ✅ Better user experience (can inform users of issues)
- ✅ Easier to identify bugs

---

### 3. ⭐⭐ CONSOLIDATE NETWORK ACCESS LAYER (Effort: 4-5 days)

**Priority:** HIGH

**Current Problem:**
- 299 direct Firestore accesses scattered across codebase
- No consistent retry logic
- No unified error handling

**Solution - Create Service Abstraction Layer:**

```swift
// NetworkService.swift - Single source of truth
@MainActor
class FirestoreNetworkService {
    static let shared = FirestoreNetworkService()
    
    private let db = Firestore.firestore()
    private let logger = Logger.shared
    
    // Generic collection access with built-in logging and error handling
    func getDocument<T: Decodable>(
        from collection: String,
        id: String,
        as type: T.Type,
        logCategory: LogCategory = .database
    ) async throws -> T? {
        logger.debug("Fetching \(type) from \(collection)/\(id)", category: logCategory)
        
        do {
            let doc = try await db.collection(collection).document(id).getDocument()
            return try doc.decode(as: type, logCategory: logCategory)
        } catch {
            logger.error("Failed to fetch \(type)", category: logCategory, error: error)
            throw error
        }
    }
    
    func queryDocuments<T: Decodable>(
        from collection: String,
        where conditions: [(String, NSObject)],
        as type: T.Type,
        limit: Int = 100,
        logCategory: LogCategory = .database
    ) async throws -> [T] {
        logger.debug("Querying \(collection) for \(type)", category: logCategory)
        
        do {
            var query: Query = db.collection(collection)
            for (field, value) in conditions {
                query = query.whereField(field, isEqualTo: value)
            }
            query = query.limit(to: limit)
            
            let snapshot = try await query.getDocuments()
            return snapshot.documents.compactMap {
                try? $0.decode(as: type, logCategory: logCategory)
            }
        } catch {
            logger.error("Query failed", category: logCategory, error: error)
            throw error
        }
    }
}
```

**Then update repositories:**
```swift
class FirestoreUserRepository: UserRepositoryProtocol {
    private let network = FirestoreNetworkService.shared
    
    func fetchUser(id: String) async throws -> User? {
        return try await network.getDocument(
            from: "users",
            id: id,
            as: User.self,
            logCategory: .users
        )
    }
}
```

**Impact:**
- ✅ Single source of Firestore access
- ✅ Consistent logging across app
- ✅ Easier to add global retry logic
- ✅ Simpler to monitor network performance
- ✅ Easier to add offline queue integration

---

### 4. ⭐⭐ REFACTOR VIEWMODELS FOR TESTABILITY (Effort: 2-3 days)

**Priority:** HIGH

**Current Problem:**
- 12 ViewModels with varying patterns
- Some have direct Firestore access
- Cannot be unit tested

**Solution - ViewModel Template:**

```swift
@MainActor
class DiscoverViewModel: ObservableObject {
    // MARK: - Published State
    @Published var users: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies (injected)
    private let userRepository: UserRepositoryProtocol
    private let swipeService: SwipeServiceProtocol
    private let logger: LoggerProtocol
    
    // MARK: - Initializer
    init(
        userRepository: UserRepositoryProtocol = FirestoreUserRepository(),
        swipeService: SwipeServiceProtocol = SwipeService.shared,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.userRepository = userRepository
        self.swipeService = swipeService
        self.logger = logger
    }
    
    // MARK: - Business Logic (testable, no direct Firebase)
    @MainActor
    func loadUsers(currentUser: User) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            users = try await userRepository.fetchUsers(
                excludingUserId: currentUser.id ?? "",
                ageRange: currentUser.ageRangeMin...currentUser.ageRangeMax
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Failed to load users", category: .discover, error: error)
        }
    }
}
```

**Impact:**
- ✅ ViewModels become testable
- ✅ Clear dependency contract
- ✅ Easier to debug
- ✅ Better code reuse

---

### 5. ⭐⭐ IMPLEMENT CACHE INVALIDATION STRATEGY (Effort: 2-3 days)

**Priority:** HIGH

**Current Problem:**
- Multiple cache layers with inconsistent policies
- No event-based invalidation
- Stale data shown after updates

**Solution - Cache Manager:**

```swift
protocol CacheInvalidationDelegate {
    func invalidate(collection: String)
    func invalidate(document: String, in collection: String)
}

@MainActor
class CacheManager: CacheInvalidationDelegate {
    static let shared = CacheManager()
    
    private var caches: [String: TemporalCache<Any>] = [:]
    
    func invalidate(collection: String) {
        caches[collection]?.clear()
        Logger.shared.debug("Cleared cache for \(collection)", category: .cache)
    }
    
    func invalidate(document id: String, in collection: String) {
        let key = "\(collection):\(id)"
        caches[collection]?.remove(key)
        Logger.shared.debug("Invalidated \(key)", category: .cache)
    }
}

// In services - notify cache when data changes
class UserService {
    func updateUser(_ user: User) async throws {
        try await repository.updateUser(user)
        // Invalidate cache after update
        CacheManager.shared.invalidate(document: user.id ?? "", in: "users")
    }
}
```

**Impact:**
- ✅ Guaranteed fresh data after mutations
- ✅ Reduced cache-related bugs
- ✅ Better performance with smart invalidation
- ✅ Clearer cache semantics

---

### 6. ⭐ CONSOLIDATE REAL-TIME LISTENERS (Effort: 3-4 days)

**Priority:** MEDIUM

**Current Problem:**
- 72 separate real-time listeners managed independently
- Manual lifecycle management
- Potential memory leaks
- Difficult to debug listener issues

**Solution - Listener Manager:**

```swift
@MainActor
class FirestoreListenerManager {
    static let shared = FirestoreListenerManager()
    
    private var activeListeners: [String: ListenerRegistration] = [:]
    private let logger = Logger.shared
    
    /// Register a listener with automatic cleanup
    func addListener<T: Decodable>(
        id: String,
        collection: String,
        where conditions: [(String, NSObject)] = [],
        onUpdate: @escaping ([T]) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        // Remove old listener if exists
        activeListeners[id]?.remove()
        
        var query: Query = Firestore.firestore().collection(collection)
        for (field, value) in conditions {
            query = query.whereField(field, isEqualTo: value)
        }
        
        let listener = query.addSnapshotListener { snapshot, error in
            if let error = error {
                self.logger.error("Listener error for \(id)", error: error)
                onError(error)
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            let items = documents.compactMap { try? $0.data(as: T.self) }
            onUpdate(items)
        }
        
        activeListeners[id] = listener
        logger.debug("Listener registered: \(id)", category: .database)
    }
    
    func removeListener(id: String) {
        activeListeners[id]?.remove()
        activeListeners.removeValue(forKey: id)
        logger.debug("Listener removed: \(id)", category: .database)
    }
    
    func removeAllListeners() {
        activeListeners.values.forEach { $0.remove() }
        activeListeners.removeAll()
        logger.info("All listeners removed", category: .database)
    }
}
```

**Impact:**
- ✅ Centralized listener management
- ✅ Reduces memory leaks
- ✅ Easier to debug listener issues
- ✅ Simpler error handling

---

## SUMMARY TABLE: Improvements by Impact

| Improvement | Priority | Effort | Impact | ROI |
|-------------|----------|--------|--------|-----|
| Dependency Injection | CRITICAL | 5-7d | Testability, Maintainability | Very High |
| Error Handling | CRITICAL | 3-4d | Debuggability, Reliability | Very High |
| Network Abstraction | HIGH | 4-5d | Consistency, Maintenance | High |
| ViewModel Refactor | HIGH | 2-3d | Testability | High |
| Cache Strategy | HIGH | 2-3d | Data Freshness | Medium |
| Listener Manager | MEDIUM | 3-4d | Reliability, Leaks | Medium |

---

## RECOMMENDATIONS FOR IMPLEMENTATION ORDER

1. **Week 1: Foundation**
   - Implement Dependency Injection framework
   - Create protocol abstractions (UserRepository, MatchRepository, etc.)
   - Start refactoring one ViewModel as template

2. **Week 2: Error Handling**
   - Replace 4,760 try? patterns with proper error handling
   - Update logging calls for consistency
   - Add error tracking to Crashlytics

3. **Week 3-4: Network Consolidation**
   - Create FirestoreNetworkService
   - Migrate all direct Firestore access through it
   - Implement repository pattern for all data types

4. **Ongoing: Testing**
   - Rewrite tests with proper mocks
   - Add ViewModel tests
   - Improve test coverage metrics

