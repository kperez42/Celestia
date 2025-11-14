# Architecture Improvements & Technical Debt

This document outlines completed improvements and remaining recommendations for the Celestia iOS app.

## ✅ Completed Improvements

### 1. Performance: N+1 Query Optimization
**Status:** ✅ FIXED

**Problem:** Sequential Firestore queries in ReferralManager causing unnecessary latency.

**Solution Implemented:**
- Parallelized queries using `async let` in `processReferralSignup()`
- Parallelized queries in `getReferralStats()`

**Impact:**
- Reduced latency by ~50-66% during referral signup
- Better user experience during registration flow

**Files Modified:**
- `Celestia/ReferralManager.swift:78-121` - Parallelized 3 sequential queries
- `Celestia/ReferralManager.swift:293-323` - Parallelized 2 sequential queries

---

### 2. Architecture: Database Logic Moved from ViewModels
**Status:** ✅ FIXED

**Problem:** ViewModels directly accessing Firestore violates MVVM pattern and makes testing difficult.

**Solution Implemented:**
- Added daily like limit management methods to `UserService`
- Added super likes management methods to `UserService`
- Updated `DiscoverViewModel` to delegate to `UserService` instead of direct Firestore access

**Impact:**
- Better separation of concerns (MVVM compliance)
- Easier to test ViewModels with mock services
- Business logic centralized in service layer

**Files Modified:**
- `Celestia/UserService.swift:258-356` - Added like/super-like management methods
- `Celestia/DiscoverViewModel.swift:198-217` - Refactored to use UserService

**Methods Added to UserService:**
- `checkDailyLikeLimit(userId:)` - Check if user has likes remaining
- `resetDailyLikes(userId:)` - Reset daily like count
- `decrementDailyLikes(userId:)` - Decrement like count
- `getRemainingDailyLikes(userId:)` - Get remaining likes
- `decrementSuperLikes(userId:)` - Decrement super like count
- `getRemainingSuperLikes(userId:)` - Get remaining super likes

---

### 3. Code Quality: User Factory Pattern
**Status:** ✅ FIXED

**Problem:** User object creation duplicated across codebase with inconsistent validation and unsafe defaults.

**Solution Implemented:**
- Created `User.createMinimal()` factory method with validation
- Created `User.fromFirestore()` factory method
- Created `UserCreationError` enum for type-safe errors
- Updated `MatchService` to use factory method

**Impact:**
- Centralized validation logic
- Prevents creation of invalid User objects (age: 0, empty email, etc.)
- More maintainable and consistent code
- Type-safe error handling

**Files Modified:**
- `Celestia/User.swift:300-387` - Added factory methods and error types
- `Celestia/MatchService.swift:125-135` - Refactored to use factory

---

## 📋 Remaining Recommendations

### 1. Testing: ViewModel Unit Tests
**Priority:** HIGH
**Status:** ⏸️ TODO

**Current State:**
- Service layer has good test coverage
- ViewModels have NO tests

**Recommendation:**
Create test files for:
- `DiscoverViewModelTests.swift`
- `ChatViewModelTests.swift`
- `ProfileEditViewModelTests.swift`

**Test Structure Example:**
```swift
import Testing
@testable import Celestia

@Suite("DiscoverViewModel Tests")
@MainActor
struct DiscoverViewModelTests {

    @Test("Load users successfully")
    func testLoadUsersSuccess() async throws {
        let mockUserService = MockUserService()
        let viewModel = DiscoverViewModel(userService: mockUserService)

        await viewModel.loadUsers()

        #expect(viewModel.users.count > 0)
        #expect(viewModel.isLoading == false)
    }

    @Test("Handle like with limit check")
    func testHandleLikeWithLimitCheck() async throws {
        // Test daily like limit logic
    }
}
```

**Dependencies Needed:**
- Mock services (MockUserService, MockAuthService, MockSwipeService)
- Test user data fixtures

**Estimated Effort:** 2-3 days

---

### 2. Security: Server-Side Rate Limiting
**Priority:** HIGH
**Status:** ⏸️ TODO

**Current State:**
- Rate limiting is CLIENT-SIDE ONLY (in-memory)
- Can be bypassed by reinstalling app or modifying code

**Security Risk:**
- Users can spam messages, likes, reports
- Abuse detection is ineffective
- DoS attacks possible

**Recommendation:**

#### Backend Implementation (Firebase Functions):
```javascript
// functions/src/rateLimiter.ts
export const checkRateLimit = functions.https.onCall(async (data, context) => {
    const userId = context.auth?.uid;
    if (!userId) throw new functions.https.HttpsError('unauthenticated', 'User not authenticated');

    const action = data.action; // 'message', 'like', 'report', etc.
    const rateLimitRef = admin.firestore()
        .collection('rateLimits')
        .doc(userId)
        .collection('actions')
        .doc(action);

    const doc = await rateLimitRef.get();
    const now = Date.now();
    const hourAgo = now - (60 * 60 * 1000);

    if (doc.exists) {
        const data = doc.data();
        const recentActions = data.timestamps.filter(t => t > hourAgo);

        // Check limits
        const limits = {
            'message': 100,  // 100 messages per hour
            'like': 50,      // 50 likes per hour
            'report': 5      // 5 reports per hour
        };

        if (recentActions.length >= limits[action]) {
            throw new functions.https.HttpsError('resource-exhausted', 'Rate limit exceeded');
        }

        // Add new timestamp
        recentActions.push(now);
        await rateLimitRef.set({ timestamps: recentActions });
    } else {
        await rateLimitRef.set({ timestamps: [now] });
    }

    return { allowed: true };
});
```

#### Client Changes:
- Keep client-side rate limiting for UX (instant feedback)
- Call server-side validation before actual operation
- Handle rate limit errors gracefully

**Files to Modify:**
- `BackendAPIService.swift` - Add rate limit check calls
- `MessageService.swift` - Call backend before sending
- `SwipeService.swift` - Call backend before recording like
- `BlockReportService.swift` - Call backend before reporting

**Estimated Effort:** 3-4 days (including backend setup)

---

### 3. Performance: Search Indexing
**Priority:** MEDIUM
**Status:** ⏸️ TODO

**Current State:**
- Client-side filtering after fetching ALL users (UserService.swift:154-179)
- Doesn't scale beyond ~1000 users
- High bandwidth usage
- Poor search performance

**Problem:**
```swift
// Current implementation - fetches ALL, then filters
let snapshot = try await firestoreQuery.getDocuments()
return snapshot.documents
    .compactMap { try? $0.data(as: User.self) }
    .filter { user in  // ❌ Client-side filtering
        user.fullName.lowercased().contains(searchQuery)
    }
```

**Recommendation:**

#### Option A: Algolia (Recommended)
Best for full-text search, typo-tolerance, and relevance ranking.

**Setup:**
1. Install Algolia SDK: `pod 'InstantSearchClient'`
2. Set up Firebase Extension: Algolia Search Firestore
3. Configure index:
```json
{
  "searchableAttributes": ["fullName", "location", "country", "bio", "interests"],
  "attributesForFaceting": ["gender", "age", "country", "isPremium"],
  "ranking": ["typo", "geo", "words", "filters", "proximity", "attribute", "exact", "custom"]
}
```

**Client Implementation:**
```swift
import InstantSearchClient

class UserService {
    private let algoliaClient = SearchClient(appID: "APP_ID", apiKey: "API_KEY")

    func searchUsersWithAlgolia(query: String, filters: String) async throws -> [User] {
        let index = algoliaClient.index(withName: "users")

        let searchQuery = Query(query: query)
        searchQuery.filters = filters  // e.g., "age >= 25 AND age <= 35"
        searchQuery.hitsPerPage = 20

        let results = try await index.search(query: searchQuery)
        return results.hits.compactMap { try? JSONDecoder().decode(User.self, from: $0) }
    }
}
```

**Pros:**
- Excellent search quality (typo-tolerance, relevance)
- Real-time sync with Firestore via extension
- Geo-search built-in
- Highly scalable

**Cons:**
- Additional cost (~$1/month for small apps, scales with usage)
- Requires backend setup

**Cost Estimate:** Free up to 10K searches/month, then $1/1000 searches

---

#### Option B: Firestore Composite Indexes
Suitable for exact prefix matching only.

**Setup:**
```javascript
// firestore.indexes.json
{
  "indexes": [
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "fullName", "order": "ASCENDING" },
        { "fieldPath": "age", "order": "ASCENDING" },
        { "fieldPath": "gender", "order": "ASCENDING" }
      ]
    }
  ]
}
```

**Client Implementation:**
```swift
func searchUsers(prefix: String) async throws -> [User] {
    let query = db.collection("users")
        .whereField("fullName", isGreaterThanOrEqualTo: prefix)
        .whereField("fullName", isLessThan: prefix + "\u{f8ff}")
        .limit(to: 20)

    let snapshot = try await query.getDocuments()
    return snapshot.documents.compactMap { try? $0.data(as: User.self) }
}
```

**Pros:**
- No additional cost
- No external dependencies

**Cons:**
- Only prefix matching (no "contains" search)
- No typo-tolerance
- Limited relevance ranking
- Requires multiple indexed for different search fields

---

**Recommendation:** Use **Algolia** for production. The cost is minimal and search quality is critical for dating apps.

**Estimated Effort:**
- Algolia: 2-3 days
- Firestore only: 1 day (but limited functionality)

---

### 4. Additional ViewModels Needing Refactoring
**Priority:** MEDIUM
**Status:** ⏸️ TODO

The following ViewModels still have direct Firestore access:

#### ChatViewModel.swift
- Direct Firestore access on line 17
- Should delegate to MessageService

#### ProfileEditViewModel.swift
- Direct Firestore access on lines 15, 60
- Should delegate to UserService

**Recommendation:** Refactor similar to DiscoverViewModel pattern.

**Estimated Effort:** 1 day

---

### 5. Additional Performance Optimizations
**Priority:** LOW
**Status:** ⏸️ TODO

#### Batch Firestore Operations
Currently using individual `FieldValue.increment()` calls. Consider batching:

```swift
// Instead of:
await db.collection("users").document(userId).updateData(["likesRemaining": FieldValue.increment(-1)])
await db.collection("users").document(userId).updateData(["profileViews": FieldValue.increment(1)])

// Use batch:
let batch = db.batch()
let userRef = db.collection("users").document(userId)
batch.updateData(["likesRemaining": FieldValue.increment(-1)], forDocument: userRef)
batch.updateData(["profileViews": FieldValue.increment(1)], forDocument: userRef)
try await batch.commit()
```

**Files to Consider:**
- `UserService.swift` - Batch profile updates
- `MessageService.swift` - Batch message + unread count
- `SwipeService.swift` - Batch like + stats update

**Estimated Effort:** 1-2 days

---

## 📊 Priority Matrix

| Task | Priority | Effort | Impact | Status |
|------|----------|--------|--------|--------|
| N+1 Query Fix | HIGH | 1 day | HIGH | ✅ DONE |
| Move DB from ViewModels | HIGH | 2 days | HIGH | ✅ DONE |
| User Factory | MEDIUM | 1 day | MEDIUM | ✅ DONE |
| ViewModel Tests | HIGH | 3 days | HIGH | ⏸️ TODO |
| Server-Side Rate Limiting | HIGH | 4 days | HIGH | ⏸️ TODO |
| Search Indexing (Algolia) | MEDIUM | 3 days | MEDIUM | ⏸️ TODO |
| Refactor Remaining ViewModels | MEDIUM | 1 day | MEDIUM | ⏸️ TODO |
| Batch Firestore Operations | LOW | 2 days | LOW | ⏸️ TODO |

---

## 🎯 Recommended Next Steps

1. **This Sprint:**
   - ✅ N+1 Query fixes (DONE)
   - ✅ ViewModel refactoring (DONE)
   - ✅ User factory pattern (DONE)

2. **Next Sprint:**
   - Add ViewModel unit tests
   - Implement server-side rate limiting

3. **Following Sprint:**
   - Integrate Algolia for search
   - Refactor remaining ViewModels

4. **Technical Debt Backlog:**
   - Batch Firestore operations
   - Additional test coverage

---

**Last Updated:** November 14, 2025
**Author:** Code Review Agent
**Related Files:** See individual sections above
