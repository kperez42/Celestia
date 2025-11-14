# Error Handling Strategy Guide

## Problem Statement

The codebase currently has **inconsistent error handling patterns** that make it difficult to:
- Predict how errors will be communicated
- Handle errors consistently in UI
- Debug issues effectively
- Test error scenarios

### Current Inconsistencies

**Pattern 1: Published Error Property**
```swift
@Published var error: Error?

func someMethod() async {
    do {
        // ...
    } catch {
        self.error = error  // ❌ Inconsistent
    }
}
```

**Pattern 2: Throws**
```swift
func someMethod() async throws {
    // Throws on error
}
```

**Pattern 3: Optional Returns**
```swift
func someMethod() async -> User? {
    // Returns nil on failure
}
```

**Pattern 4: Published String Error**
```swift
@Published var errorMessage: String?
```

## Standardized Strategy

### Core Principle
**Choose the error handling pattern based on the function's purpose and caller context.**

---

## Pattern 1: Async Functions with `throws` (PREFERRED)

### When to Use
- **Most async operations** (database queries, network calls, file I/O)
- When the operation can fail and the caller needs to handle it
- When you want precise error types
- When the operation is transactional (all-or-nothing)

### How to Use
```swift
func fetchUser(userId: String) async throws -> User {
    do {
        let document = try await db.collection("users").document(userId).getDocument()
        guard let user = try? document.data(as: User.self) else {
            throw CelestiaError.userNotFound
        }
        return user
    } catch {
        Logger.shared.error("Failed to fetch user", category: .database, error: error)
        throw CelestiaError.databaseError(error)
    }
}
```

### Caller Pattern
```swift
Task {
    do {
        let user = try await userService.fetchUser(userId: "123")
        // Success - use user
    } catch let error as CelestiaError {
        // Handle specific error
        showAlert(message: error.localizedMessage)
    } catch {
        // Handle unexpected error
        showAlert(message: "An unexpected error occurred")
    }
}
```

**Benefits:**
- ✅ Clear error propagation
- ✅ Type-safe error handling
- ✅ Caller decides how to handle
- ✅ Easy to test

---

## Pattern 2: Result Type for Published State

### When to Use
- **ViewModel state** that UI observes
- When you want to expose both success and failure states
- When multiple views need to react to the same operation
- When you need to track loading/success/error states

### How to Use

**Step 1: Define Operation State**
```swift
enum OperationState<T> {
    case idle
    case loading
    case success(T)
    case failure(CelestiaError)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var value: T? {
        if case .success(let value) = self { return value }
        return nil
    }

    var error: CelestiaError? {
        if case .failure(let error) = self { return error }
        return nil
    }
}
```

**Step 2: Use in ViewModel**
```swift
@MainActor
class UserViewModel: ObservableObject {
    @Published var userState: OperationState<User> = .idle

    func loadUser(userId: String) async {
        userState = .loading

        do {
            let user = try await userService.fetchUser(userId: userId)
            userState = .success(user)
        } catch let error as CelestiaError {
            userState = .failure(error)
        } catch {
            userState = .failure(.unknown(error))
        }
    }
}
```

**Step 3: Use in View**
```swift
struct UserView: View {
    @StateObject var viewModel = UserViewModel()

    var body: some View {
        Group {
            switch viewModel.userState {
            case .idle:
                Text("Tap to load user")
            case .loading:
                ProgressView()
            case .success(let user):
                UserDetailView(user: user)
            case .failure(let error):
                ErrorView(message: error.localizedMessage)
            }
        }
        .task {
            await viewModel.loadUser(userId: "123")
        }
    }
}
```

**Benefits:**
- ✅ Clear state representation
- ✅ UI reactivity
- ✅ Easy to show loading/error states
- ✅ Type-safe

---

## Pattern 3: Optional Returns for Non-Critical Operations

### When to Use
- **Silent failures** where the operation failing doesn't block the user
- Cache lookups
- Best-effort operations
- When `nil` is a valid result

### How to Use
```swift
func getCachedUser(userId: String) -> User? {
    // Check cache
    if let cached = cache[userId] {
        return cached
    }

    // Not found - this is OK, just return nil
    Logger.shared.debug("Cache miss for user \(userId)", category: .cache)
    return nil
}
```

**Caller Pattern**
```swift
// Try cache first
if let user = getCachedUser(userId: "123") {
    // Use cached user
} else {
    // Fetch from network
    user = try await fetchUser(userId: "123")
}
```

**When NOT to Use:**
- ❌ Critical operations (use `throws`)
- ❌ When you need to distinguish between "not found" and "error"
- ❌ When the caller needs to know why it failed

---

## Pattern 4: Centralized Error Type

### Define App-Wide Error Enum

**File:** `Celestia/CelestiaError.swift`

```swift
enum CelestiaError: LocalizedError, Equatable {
    // Authentication
    case invalidCredentials
    case emailNotVerified
    case accountDisabled
    case weakPassword

    // User Operations
    case userNotFound
    case profileIncomplete
    case invalidUserData(String)

    // Database
    case databaseError(Error)
    case networkError(Error)
    case connectionFailed

    // Validation
    case validationError(String)
    case invalidInput(field: String, reason: String)

    // Business Logic
    case dailyLimitExceeded
    case subscriptionRequired
    case insufficientBalance

    // Unknown
    case unknown(Error)

    // MARK: - LocalizedError

    var errorDescription: String? {
        localizedMessage
    }

    var localizedMessage: String {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .emailNotVerified:
            return "Please verify your email address"
        case .accountDisabled:
            return "Your account has been disabled"
        case .weakPassword:
            return "Password must be at least 8 characters"
        case .userNotFound:
            return "User not found"
        case .profileIncomplete:
            return "Please complete your profile"
        case .invalidUserData(let field):
            return "Invalid data for field: \(field)"
        case .databaseError:
            return "Database error. Please try again."
        case .networkError:
            return "Network error. Check your connection."
        case .connectionFailed:
            return "Connection failed. Please try again."
        case .validationError(let message):
            return message
        case .invalidInput(let field, let reason):
            return "Invalid \(field): \(reason)"
        case .dailyLimitExceeded:
            return "Daily limit exceeded. Upgrade to continue."
        case .subscriptionRequired:
            return "This feature requires a subscription"
        case .insufficientBalance:
            return "Insufficient balance"
        case .unknown:
            return "An unexpected error occurred"
        }
    }

    // MARK: - Equatable

    static func == (lhs: CelestiaError, rhs: CelestiaError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidCredentials, .invalidCredentials),
             (.emailNotVerified, .emailNotVerified),
             (.accountDisabled, .accountDisabled),
             (.weakPassword, .weakPassword),
             (.userNotFound, .userNotFound),
             (.profileIncomplete, .profileIncomplete),
             (.connectionFailed, .connectionFailed),
             (.dailyLimitExceeded, .dailyLimitExceeded),
             (.subscriptionRequired, .subscriptionRequired),
             (.insufficientBalance, .insufficientBalance):
            return true
        case (.invalidUserData(let l), .invalidUserData(let r)):
            return l == r
        case (.validationError(let l), .validationError(let r)):
            return l == r
        case (.invalidInput(let lField, let lReason), .invalidInput(let rField, let rReason)):
            return lField == rField && lReason == rReason
        default:
            return false
        }
    }
}
```

---

## Decision Tree

```
Is this operation critical?
├─ YES → Use `throws`
└─ NO → Is the result observable by UI?
    ├─ YES → Use `OperationState<T>` in @Published
    └─ NO → Return optional or log & ignore
```

### Examples

**Critical Database Write**
```swift
func saveUser(_ user: User) async throws {
    try await db.collection("users").document(user.id).setData(from: user)
}
```

**UI-Observable State**
```swift
@Published var matchesState: OperationState<[Match]> = .idle

func loadMatches() async {
    matchesState = .loading
    do {
        let matches = try await matchService.fetchMatches()
        matchesState = .success(matches)
    } catch let error as CelestiaError {
        matchesState = .failure(error)
    } catch {
        matchesState = .failure(.unknown(error))
    }
}
```

**Non-Critical Cache**
```swift
func getCachedProfile() -> UserProfile? {
    return cache.get("profile")
}
```

---

## Migration Guide

### Step 1: Identify Current Patterns

**Find all error handling:**
```bash
grep -r "@Published var error" --include="*.swift"
grep -r "throws" --include="*.swift"
grep -r "-> .*?" --include="*.swift"
```

### Step 2: Categorize Functions

| Function | Current | New Pattern | Reason |
|----------|---------|-------------|--------|
| `fetchUser()` | `@Published error` | `throws` | Critical operation |
| `loadMatches()` | `throws` | `OperationState` | UI-observable |
| `getCached()` | `throws` | `Optional` | Non-critical |

### Step 3: Refactor Incrementally

1. Create `CelestiaError.swift`
2. Create `OperationState.swift`
3. Update one service at a time
4. Update corresponding ViewModels
5. Update Views to handle new patterns
6. Add tests

---

## Testing Error Handling

### Test Throws Pattern
```swift
@Test("Fetch user throws on database error")
func testFetchUserThrows() async throws {
    let service = UserService()

    await #expect(throws: CelestiaError.self) {
        try await service.fetchUser(userId: "invalid")
    }
}
```

### Test OperationState Pattern
```swift
@Test("Load matches updates state correctly")
func testLoadMatchesState() async {
    let viewModel = MatchesViewModel()

    // Initial state
    #expect(viewModel.matchesState == .idle)

    // Load
    await viewModel.loadMatches()

    // Check final state
    switch viewModel.matchesState {
    case .success(let matches):
        #expect(matches.count > 0)
    case .failure(let error):
        // Expected in test environment
        #expect(error != nil)
    default:
        #expect(Bool(false), "Unexpected state")
    }
}
```

---

## Best Practices

### ✅ DO

1. **Use `throws` for critical operations**
2. **Use `OperationState` for UI-observable state**
3. **Log all errors before rethrowing**
4. **Provide user-friendly error messages**
5. **Use specific error types (CelestiaError)**
6. **Test error paths**

### ❌ DON'T

1. **Don't mix `@Published var error` with `throws` in same function**
2. **Don't swallow errors silently (always log)**
3. **Don't use generic `Error` in UI**
4. **Don't return `nil` for critical operations**
5. **Don't expose raw database/network errors to UI**
6. **Don't forget to clear error states**

---

## Common Patterns

### Pattern: Service Function with Throws
```swift
class UserService {
    func fetchUser(userId: String) async throws -> User {
        Logger.shared.debug("Fetching user \(userId)", category: .database)

        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            guard let user = try? doc.data(as: User.self) else {
                throw CelestiaError.userNotFound
            }
            return user
        } catch let error as CelestiaError {
            throw error // Already a CelestiaError
        } catch {
            Logger.shared.error("Failed to fetch user", category: .database, error: error)
            throw CelestiaError.databaseError(error)
        }
    }
}
```

### Pattern: ViewModel with OperationState
```swift
@MainActor
class UserViewModel: ObservableObject {
    @Published var userState: OperationState<User> = .idle
    private let userService = UserService.shared

    func loadUser(userId: String) async {
        userState = .loading

        do {
            let user = try await userService.fetchUser(userId: userId)
            userState = .success(user)
        } catch let error as CelestiaError {
            userState = .failure(error)
            Logger.shared.error("Failed to load user", category: .user, error: error)
        } catch {
            userState = .failure(.unknown(error))
        }
    }

    func retry() async {
        guard case .failure = userState else { return }
        // Retry logic
    }
}
```

### Pattern: View with Error Handling
```swift
struct UserView: View {
    @StateObject var viewModel = UserViewModel()
    @State private var showError = false

    var body: some View {
        ZStack {
            switch viewModel.userState {
            case .idle:
                Button("Load User") {
                    Task { await viewModel.loadUser(userId: "123") }
                }

            case .loading:
                ProgressView("Loading...")

            case .success(let user):
                UserDetailView(user: user)

            case .failure(let error):
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                    Text(error.localizedMessage)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await viewModel.retry() }
                    }
                }
            }
        }
    }
}
```

---

## Summary

| Pattern | Use When | Example |
|---------|----------|---------|
| **throws** | Critical operations | Database writes, network calls |
| **OperationState** | UI-observable state | ViewModel loading data |
| **Optional** | Non-critical, nil is valid | Cache lookups |
| **Log & ignore** | Silent failures | Analytics tracking |

**Golden Rule:** Be consistent within a service/module, and always provide clear error messages to users.

---

## Files to Update

### High Priority
1. ✅ `CelestiaError.swift` (NEW)
2. ✅ `OperationState.swift` (NEW)
3. `UserService.swift` - Standardize on throws
4. `MatchService.swift` - Standardize on throws
5. `MessageService.swift` - Standardize on throws
6. `AuthService.swift` - Use OperationState

### Medium Priority
7. ViewModels - Adopt OperationState
8. InterestService.swift
9. SearchManager.swift

### Low Priority
10. Minor utility functions
11. Caching helpers

---

## Questions?

Contact: Development Team
