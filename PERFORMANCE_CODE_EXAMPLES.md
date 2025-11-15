# Performance Optimization - Code Examples

## Issue #1: ProfileViewersView N+1 Query Fix

### BEFORE (❌ 51 reads)
```swift
// ProfileViewersView.swift lines 336-351
for doc in viewsSnapshot.documents {
    let userDoc = try await db.collection("users").document(viewerId).getDocument()  // ❌ 50 queries
    if let user = try? userDoc.data(as: User.self) {
        viewersList.append(ViewerInfo(
            id: doc.documentID,
            user: user,
            timestamp: timestamp
        ))
    }
}
```

### AFTER (✅ 5 reads)
```swift
// ProfileViewersView.swift
// Extract viewer IDs
let viewerIds = viewsSnapshot.documents.compactMap { doc in
    doc.data()["viewerUserId"] as? String
}

// Batch fetch all viewers
var viewersList: [ViewerInfo] = []
let chunked = viewerIds.chunked(into: 10)

for chunk in chunked {
    let userSnapshot = try await db.collection("users")
        .whereField(FieldPath.documentID(), in: chunk)
        .getDocuments()
    
    let users = userSnapshot.documents.compactMap { doc -> User? in
        try? doc.data(as: User.self)
    }
    
    // Map back to viewer info
    for (idx, viewerId) in chunk.enumerated() {
        if idx < users.count {
            if let originalDoc = viewsSnapshot.documents.first(where: { 
                ($0.data()["viewerUserId"] as? String) == viewerId 
            }) {
                let data = originalDoc.data()
                if let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() {
                    viewersList.append(ViewerInfo(
                        id: originalDoc.documentID,
                        user: users[idx],
                        timestamp: timestamp
                    ))
                }
            }
        }
    }
}
```

---

## Issue #2: ReferralManager Cache Fix

### BEFORE (❌ ~100 reads)
```swift
// ReferralManager.swift lines 260-273
for (index, doc) in snapshot.documents.enumerated() {
    let data = doc.data()
    let referralStatsDict = data["referralStats"] as? [String: Any] ?? [:]
    let stats = ReferralStats(dictionary: referralStatsDict)
    // getReferralStats() calls 2 more queries internally
    
    let entry = ReferralLeaderboardEntry(
        id: doc.documentID,
        userName: data["fullName"] as? String ?? "Anonymous",
        profileImageURL: data["profileImageURL"] as? String ?? "",
        totalReferrals: stats.totalReferrals,
        rank: index + 1,
        premiumDaysEarned: stats.premiumDaysEarned
    )
    entries.append(entry)
}
```

### AFTER (✅ 5 reads + cache)
```swift
// ReferralManager.swift
private let leaderboardCache = QueryCache<[ReferralLeaderboardEntry]>(ttl: 600) // 10 min cache

func loadLeaderboard(limit: Int = 50) async throws {
    // Check cache first
    if let cached = await leaderboardCache.get("leaderboard") {
        leaderboard = cached
        return
    }
    
    isLoading = true
    defer { isLoading = false }
    
    let snapshot = try await db.collection("users")
        .whereField("referralStats.totalReferrals", isGreaterThan: 0)
        .order(by: "referralStats.totalReferrals", descending: true)
        .limit(to: limit)
        .getDocuments()
    
    var entries: [ReferralLeaderboardEntry] = []
    for (index, doc) in snapshot.documents.enumerated() {
        let data = doc.data()
        let referralStatsDict = data["referralStats"] as? [String: Any] ?? [:]
        let stats = ReferralStats(dictionary: referralStatsDict)
        
        let entry = ReferralLeaderboardEntry(
            id: doc.documentID,
            userName: data["fullName"] as? String ?? "Anonymous",
            profileImageURL: data["profileImageURL"] as? String ?? "",
            totalReferrals: stats.totalReferrals,
            rank: index + 1,
            premiumDaysEarned: stats.premiumDaysEarned
        )
        entries.append(entry)
    }
    
    leaderboard = entries
    
    // Store in cache
    await leaderboardCache.set("leaderboard", value: entries)
}
```

---

## Issue #3: LikeActivityView Batch User Fetch

### BEFORE (❌ 130+ reads)
```swift
// LikeActivityView.swift lines 260-343
do {
    var allActivity: [LikeActivity] = []
    
    let receivedSnapshot = try await db.collection("likes")
        .whereField("targetUserId", isEqualTo: currentUserId)
        .order(by: "timestamp", descending: true)
        .limit(to: 50)
        .getDocuments()  // 1 read
    
    for doc in receivedSnapshot.documents {  // 50 iterations
        let data = doc.data()
        if let userId = data["userId"] as? String,
           let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() {
            allActivity.append(LikeActivity(
                id: doc.documentID,
                userId: userId,  // No user details fetched!
                type: .received(isSuperLike: isSuperLike),
                timestamp: timestamp
            ))
        }
    }
    // ... similar for sent and matches
    // User details fetched later = N+1 in view
}
```

### AFTER (✅ 8 reads)
```swift
// LikeActivityView.swift
do {
    var allActivity: [LikeActivity] = []
    var userIds: Set<String> = []
    
    // Fetch activity records
    let receivedSnapshot = try await db.collection("likes")
        .whereField("targetUserId", isEqualTo: currentUserId)
        .order(by: "timestamp", descending: true)
        .limit(to: 50)
        .getDocuments()
    
    for doc in receivedSnapshot.documents {
        let data = doc.data()
        if let userId = data["userId"] as? String,
           let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() {
            userIds.insert(userId)
            allActivity.append(LikeActivity(
                id: doc.documentID,
                userId: userId,
                type: .received(isSuperLike: isSuperLike),
                timestamp: timestamp
            ))
        }
    }
    
    // ... repeat for sent and matches, collect all userIds ...
    
    // NOW: Batch fetch all users
    var users: [String: User] = [:]
    let userIdArray = Array(userIds)
    let chunked = userIdArray.chunked(into: 10)
    
    for chunk in chunked {
        let userSnapshot = try await db.collection("users")
            .whereField(FieldPath.documentID(), in: chunk)
            .getDocuments()
        
        for doc in userSnapshot.documents {
            if let user = try? doc.data(as: User.self), let userId = user.id {
                users[userId] = user
            }
        }
    }
    
    // Store both activity and users in state
    likeActivity = allActivity
    cachedUsers = users
}
```

---

## Issue #4: SearchManager Pagination

### BEFORE (❌ No pagination)
```swift
// SearchManager.swift line 103
let snapshot = try await query
    .limit(to: 100)  // ❌ All loaded upfront
    .getDocuments()
```

### AFTER (✅ Cursor pagination)
```swift
// SearchManager.swift
private var lastSearchDocument: DocumentSnapshot?

func search(query: String, reset: Bool = true) async throws -> [UserProfile] {
    if reset {
        lastSearchDocument = nil
    }
    
    var firestoreQuery = db.collection("users")
        .whereField("showMeInSearch", isEqualTo: true)
        .limit(to: 20)  // Reduce to 20
    
    // Add pagination cursor
    if let lastDoc = lastSearchDocument {
        firestoreQuery = firestoreQuery.start(afterDocument: lastDoc)
    }
    
    let snapshot = try await firestoreQuery.getDocuments()
    lastSearchDocument = snapshot.documents.last  // Save cursor for next page
    
    var profiles: [UserProfile] = []
    for document in snapshot.documents {
        if let profile = UserProfile(document: document) {
            if matchesFilter(profile: profile, filter: filter) {
                profiles.append(profile)
            }
        }
    }
    
    return profiles
}

// To load next page:
// Just call search() again without reset: true
// It will use lastSearchDocument automatically
```

---

## Issue #5: SavedProfiles Caching

### BEFORE (❌ 6 reads every time)
```swift
// SavedProfilesView.swift
func loadSavedProfiles() {
    // Every load = full fetch
    let savedSnapshot = try await db.collection("saved_profiles")...  // 1 read
    for chunk in chunkedUserIds {
        let usersSnapshot = try await db.collection("users")...  // 5 reads
    }
}
```

### AFTER (✅ Cached for 5 minutes)
```swift
// SavedProfilesViewModel.swift
@MainActor
class SavedProfilesViewModel: ObservableObject {
    @Published var savedProfiles: [SavedProfile] = []
    private let cache = QueryCache<[SavedProfile]>(ttl: 300, maxSize: 1)
    
    func loadSavedProfiles() async {
        let cacheKey = "saved_\(currentUserId)"
        
        // Check cache first
        if let cached = await cache.get(cacheKey) {
            savedProfiles = cached
            Logger.shared.info("Loaded saved profiles from cache", category: .database)
            return
        }
        
        // Cache miss - fetch from database
        do {
            let savedSnapshot = try await db.collection("saved_profiles")
                .whereField("userId", isEqualTo: currentUserId)
                .order(by: "savedAt", descending: true)
                .getDocuments()  // 1 read
            
            let userIds = savedSnapshot.documents.compactMap { 
                $0.data()["savedUserId"] as? String 
            }
            var fetchedUsers: [String: User] = [:]
            
            let chunkedUserIds = userIds.chunked(into: 10)
            for chunk in chunkedUserIds {
                let usersSnapshot = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()  // 5 reads
                
                for doc in usersSnapshot.documents {
                    if let user = try? doc.data(as: User.self), let userId = user.id {
                        fetchedUsers[userId] = user
                    }
                }
            }
            
            var profiles: [SavedProfile] = []
            for (idx, doc) in savedSnapshot.documents.enumerated() {
                let data = doc.data()
                if let savedUserId = data["savedUserId"] as? String,
                   let user = fetchedUsers[savedUserId],
                   let savedAt = (data["savedAt"] as? Timestamp)?.dateValue() {
                    profiles.append(SavedProfile(
                        id: doc.documentID,
                        user: user,
                        savedAt: savedAt,
                        note: data["note"] as? String
                    ))
                }
            }
            
            savedProfiles = profiles
            
            // Store in cache!
            await cache.set(cacheKey, value: profiles)
            Logger.shared.info("Saved profiles cached for 5 minutes", category: .database)
        } catch {
            Logger.shared.error("Error loading saved profiles", category: .database, error: error)
        }
    }
}
```

---

## Issue #6: AnalyticsServiceEnhanced Single-Pass Iteration

### BEFORE (❌ O(3n))
```swift
// AnalyticsServiceEnhanced.swift lines 83-91
let recentViews = viewsSnapshot.documents.filter {  // Pass 1
    guard let timestamp = ($0.data()["timestamp"] as? Timestamp)?.dateValue() else { return false }
    return timestamp >= last7Days
}.count

let previousViews = viewsSnapshot.documents.filter {  // Pass 2
    guard let timestamp = ($0.data()["timestamp"] as? Timestamp)?.dateValue() else { return false }
    return timestamp >= previous7Days && timestamp < last7Days
}.count
```

### AFTER (✅ O(n))
```swift
// AnalyticsServiceEnhanced.swift
var recentViews = 0
var previousViews = 0
var dailyViews: [String: Int] = [:]

let dateFormatter = DateFormatter()
dateFormatter.dateFormat = "yyyy-MM-dd"

for doc in viewsSnapshot.documents {
    guard let timestamp = (doc.data()["timestamp"] as? Timestamp)?.dateValue() else {
        continue
    }
    
    // Single pass handles all categorizations
    if timestamp >= last7Days {
        recentViews += 1
    } else if timestamp >= previous7Days {
        previousViews += 1
    }
    
    // Also compute daily stats in same pass
    let dateString = dateFormatter.string(from: timestamp)
    dailyViews[dateString, default: 0] += 1
}

// Now recentViews, previousViews, and dailyViews all computed
```

---

## Issue #7: DiscoverView Filter in ViewModel

### BEFORE (❌ Computed every render)
```swift
// DiscoverView.swift line 185
ForEach(Array(viewModel.users.enumerated().filter {  // ❌ Runs every render!
    $0.offset >= viewModel.currentIndex && $0.offset < viewModel.currentIndex + 3
}), id: \.offset) { index, user in
    UserCard(user: user)
}
```

### AFTER (✅ Pre-computed)
```swift
// DiscoverViewModel.swift
@Published var visibleUsers: [User] = []

func updateVisibleRange() {
    let start = max(0, currentIndex)
    let end = min(users.count, currentIndex + 3)
    visibleUsers = Array(users[start..<end])
}

// Call when currentIndex changes:
// In body: .onChange(of: viewModel.currentIndex) { _ in
//     viewModel.updateVisibleRange()
// }

// DiscoverView.swift
ForEach(viewModel.visibleUsers, id: \.id) { user in  // ✅ Simple iteration
    UserCard(user: user)
}
```

---

## Issue #11: Add Database Indexes

### Update firestore.indexes.json
```json
{
  "indexes": [
    {
      "collection": "likes",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "targetUserId", "order": "ASCENDING"},
        {"fieldPath": "timestamp", "order": "DESCENDING"}
      ]
    },
    {
      "collection": "messages", 
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "matchId", "order": "ASCENDING"},
        {"fieldPath": "timestamp", "order": "DESCENDING"}
      ]
    },
    {
      "collection": "saved_profiles",
      "queryScope": "COLLECTION", 
      "fields": [
        {"fieldPath": "userId", "order": "ASCENDING"},
        {"fieldPath": "savedAt", "order": "DESCENDING"}
      ]
    }
  ]
}
```

Then deploy: `firebase deploy --only firestore:indexes`

---

## Testing Performance Improvements

```swift
// Add to PerformanceMonitor
@MainActor
class PerformanceMonitor: ObservableObject {
    @Published var lastQueryDuration: TimeInterval = 0
    @Published var queriesPerSession: Int = 0
    
    func measureQuery<T>(_ operation: () async throws -> T) async throws -> T {
        let start = Date()
        let result = try await operation()
        let duration = Date().timeIntervalSince(start)
        
        await MainActor.run {
            self.lastQueryDuration = duration
            self.queriesPerSession += 1
            Logger.shared.info(
                "Query took \(String(format: "%.0f", duration * 1000))ms",
                category: .database
            )
        }
        
        return result
    }
}

// Usage:
let results = try await performanceMonitor.measureQuery {
    try await loadSavedProfiles()
}
```

