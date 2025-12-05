//
//  UserService.swift
//  Celestia
//
//  Service for user-related operations
//

import Foundation
import Firebase
import FirebaseFirestore

@MainActor
class UserService: ObservableObject, UserServiceProtocol {
    @Published var users: [User] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var hasMoreUsers = true

    // Dependency injection: Repository for data access
    private let repository: UserRepository

    // Singleton for backward compatibility (uses default repository)
    static let shared = UserService(repository: FirestoreUserRepository())

    private let db = Firestore.firestore()

    // CONCURRENCY FIX: Removed nonisolated(unsafe) - properties are now properly MainActor-isolated
    // Since this class is @MainActor, all properties are automatically isolated to the main actor,
    // providing proper concurrency safety without bypassing Swift's checks.
    private var lastDocument: DocumentSnapshot?
    private var searchTask: Task<Void, Never>?

    // PERFORMANCE: Search result caching to reduce database queries
    private var searchCache: [String: CachedSearchResult] = [:]
    private let searchCacheDuration: TimeInterval = 300 // 5 minutes
    private let maxSearchCacheSize = 50 // Limit cache size to prevent memory bloat

    // Dependency injection initializer
    init(repository: UserRepository) {
        self.repository = repository
    }

    /// Fetch users with filters and pagination support
    func fetchUsers(
        excludingUserId: String,
        lookingFor: String? = nil,
        ageRange: ClosedRange<Int>? = nil,
        country: String? = nil,
        limit: Int = 20,
        reset: Bool = true
    ) async throws {
        if reset {
            users = []
            lastDocument = nil
        }

        isLoading = true
        defer { isLoading = false }

        Logger.shared.debug("UserService.fetchUsers called - lookingFor: \(lookingFor ?? "nil"), ageRange: \(ageRange?.description ?? "nil")", category: .database)

        // NOTE: profileStatus filter moved to client-side to avoid needing new composite index
        // Server-side filter would require index: profileStatus + showMeInSearch + gender + age + lastActive
        // Client-side filter excludes: pending, suspended, flagged profiles
        var query = db.collection("users")
            .whereField("showMeInSearch", isEqualTo: true)
            .order(by: "lastActive", descending: true)
            .limit(to: limit)

        // Apply filters
        // IMPORTANT: Skip gender filter when lookingFor is "Everyone" to show all genders
        if let lookingFor = lookingFor, lookingFor != "Everyone" {
            // Convert lookingFor values to match gender field values
            // lookingFor uses: "Men", "Women", "Everyone"
            // gender uses: "Male", "Female", "Non-binary", "Other"
            let genderToMatch: String
            switch lookingFor {
            case "Women":
                genderToMatch = "Female"
            case "Men":
                genderToMatch = "Male"
            default:
                genderToMatch = lookingFor // Use as-is if already in correct format
            }
            Logger.shared.info("UserService: Filtering by gender = \(genderToMatch) (from lookingFor: \(lookingFor))", category: .database)
            query = query.whereField("gender", isEqualTo: genderToMatch)
        }

        if let ageRange = ageRange {
            Logger.shared.debug("UserService: Filtering by age range \(ageRange.lowerBound)-\(ageRange.upperBound)", category: .database)
            query = query
                .whereField("age", isGreaterThanOrEqualTo: ageRange.lowerBound)
                .whereField("age", isLessThanOrEqualTo: ageRange.upperBound)
        }

        if let country = country {
            Logger.shared.debug("UserService: Filtering by country = \(country)", category: .database)
            query = query.whereField("country", isEqualTo: country)
        }

        // Pagination
        if let lastDoc = lastDocument {
            query = query.start(afterDocument: lastDoc)
        }

        do {
            Logger.shared.info("UserService: Executing Firestore query...", category: .database)
            Logger.shared.info("UserService: Query details - showMeInSearch=true, ageRange=\(ageRange?.description ?? "none"), lookingFor=\(lookingFor ?? "Everyone")", category: .database)

            let snapshot = try await query.getDocuments()
            lastDocument = snapshot.documents.last

            // DEBUG: Log raw document count and any issues
            Logger.shared.info("UserService: Raw Firestore response - \(snapshot.documents.count) documents", category: .database)

            if snapshot.documents.isEmpty {
                // Additional debug: Try a simpler query to check if ANY users exist
                Logger.shared.warning("UserService: No documents returned! Running diagnostic query...", category: .database)

                // Check if there are ANY users with showMeInSearch=true
                let diagnosticSnapshot = try? await db.collection("users")
                    .whereField("showMeInSearch", isEqualTo: true)
                    .limit(to: 5)
                    .getDocuments()

                let diagnosticCount = diagnosticSnapshot?.documents.count ?? 0
                Logger.shared.info("UserService: DIAGNOSTIC - Users with showMeInSearch=true: \(diagnosticCount)", category: .database)

                // Check age distribution of those users
                if let docs = diagnosticSnapshot?.documents {
                    for doc in docs {
                        let age = doc.data()["age"] as? Int ?? -1
                        let gender = doc.data()["gender"] as? String ?? "unknown"
                        Logger.shared.info("UserService: DIAGNOSTIC - Found user age=\(age), gender=\(gender)", category: .database)
                    }
                }
            }

            // Get existing user IDs to prevent duplicates
            // BUGFIX: Use effectiveId for reliable user identification
            let existingIds = Set(users.compactMap { $0.effectiveId })

            let newUsers = snapshot.documents.compactMap { try? $0.data(as: User.self) }
                .filter { user in
                    // Exclude current user
                    guard user.effectiveId != excludingUserId else { return false }
                    // Exclude duplicates already in the array
                    guard let userId = user.effectiveId, !existingIds.contains(userId) else { return false }
                    // SAFETY: Client-side profileStatus filter (avoids complex composite index)
                    // Exclude: pending (unapproved), suspended, flagged, banned profiles
                    // Include: active, or empty/nil (existing users without field set)
                    let status = user.profileStatus.lowercased()
                    if status == "pending" || status == "suspended" || status == "flagged" || status == "banned" {
                        return false
                    }
                    return true
                }

            Logger.shared.info("UserService: Query returned \(snapshot.documents.count) documents, \(newUsers.count) valid users after filtering", category: .database)

            if newUsers.isEmpty {
                Logger.shared.warning("UserService: No users found! Check Firebase indexes and user data.", category: .database)
            } else {
                Logger.shared.info("UserService: Found users - \(newUsers.map { "\($0.fullName) (gender: \($0.gender))" }.joined(separator: ", "))", category: .database)
            }

            users.append(contentsOf: newUsers)
            hasMoreUsers = newUsers.count >= limit
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// Fetch a single user by ID (with caching)
    func fetchUser(userId: String) async throws -> User? {
        do {
            return try await repository.fetchUser(id: userId)
        } catch {
            self.error = error
            throw error
        }
    }

    /// PERFORMANCE: Batch fetch users by IDs (reduces N queries to ceil(N/10) queries)
    /// Uses Firestore's whereIn limitation of 10 items per query
    func fetchUsersBatched(ids: [String]) async throws -> [String: User] {
        guard !ids.isEmpty else { return [:] }

        var users: [String: User] = [:]
        let uniqueIds = Array(Set(ids)) // Remove duplicates
        let chunks = uniqueIds.chunked(into: 10) // Firestore whereIn limit

        // Run batch queries in parallel for better performance
        try await withThrowingTaskGroup(of: [User].self) { group in
            for chunk in chunks {
                group.addTask {
                    let snapshot = try await self.db.collection("users")
                        .whereField(FieldPath.documentID(), in: chunk)
                        .getDocuments()

                    return snapshot.documents.compactMap { try? $0.data(as: User.self) }
                }
            }

            for try await chunkUsers in group {
                for user in chunkUsers {
                    // BUGFIX: Use effectiveId for reliable user identification
                    if let userId = user.effectiveId {
                        users[userId] = user
                    }
                }
            }
        }

        Logger.shared.debug("Batch fetched \(users.count) users from \(uniqueIds.count) IDs", category: .performance)
        return users
    }
    
    /// Update user profile
    func updateUser(_ user: User) async throws {
        do {
            try await repository.updateUser(user)
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// Update specific fields
    func updateUserFields(userId: String, fields: [String: Any]) async throws {
        do {
            try await repository.updateUserFields(userId: userId, fields: fields)
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// Increment profile view count
    func incrementProfileViews(userId: String) async throws {
        await repository.incrementProfileViews(userId: userId)
    }
    
    /// Update user's last active timestamp
    func updateLastActive(userId: String) async {
        await repository.updateLastActive(userId: userId)
    }
    
    /// Set user offline
    func setUserOffline(userId: String) async {
        do {
            try await repository.updateUserFields(userId: userId, fields: [
                "isOnline": false,
                "lastActive": FieldValue.serverTimestamp()
            ])
        } catch {
            Logger.shared.error("Error setting user offline", category: .database, error: error)
        }
    }
    
    /// OPTIMIZED: Search users by name or location with server-side filtering and caching
    ///
    /// PERFORMANCE IMPROVEMENTS:
    /// 1. Uses Firestore prefix matching (limited but server-side)
    /// 2. Implements result caching (5min TTL)
    /// 3. Limits query size server-side
    /// 4. Uses compound queries for better performance
    ///
    /// LIMITATIONS:
    /// - Firestore doesn't support full-text search natively
    /// - Prefix matching only (no mid-word matches)
    /// - For production: Integrate Algolia/Elasticsearch for proper full-text search
    ///
    /// MIGRATION PATH TO PRODUCTION:
    /// 1. Add search index service (Algolia recommended)
    /// 2. Create cloud function to sync user data to search index
    /// 3. Update this method to call Algolia API instead of Firestore
    /// 4. Estimated effort: 2-3 days
    ///
    func searchUsers(query: String, currentUserId: String, limit: Int = 20, offset: DocumentSnapshot? = nil) async throws -> [User] {
        // Sanitize search query using centralized utility
        let sanitizedQuery = InputSanitizer.standard(query)
        guard !sanitizedQuery.isEmpty else { return [] }

        let searchQuery = sanitizedQuery.lowercased()
        let cacheKey = "\(searchQuery)_\(currentUserId)_\(limit)"

        // PERFORMANCE: Check cache first (5-minute TTL)
        if let cached = searchCache[cacheKey] {
            if !cached.isExpired {
                Logger.shared.debug("Search cache HIT for query: '\(searchQuery)'", category: .performance)
                let cacheAge = Date().timeIntervalSince(cached.timestamp)
                Task { @MainActor in
                    AnalyticsManager.shared.logEvent(.performance, parameters: [
                        "type": "search_cache_hit",
                        "query": searchQuery,
                        "cache_age_seconds": cacheAge
                    ])
                }
                return cached.results
            } else {
                // PERFORMANCE FIX: Remove expired entry immediately to prevent memory bloat
                searchCache.removeValue(forKey: cacheKey)
                Logger.shared.debug("Removed expired cache entry for query: '\(searchQuery)'", category: .performance)
            }
        }

        Logger.shared.debug("Search cache MISS for query: '\(searchQuery)' - querying repository", category: .performance)

        // Delegate to repository
        let results = try await repository.searchUsers(
            query: searchQuery,
            currentUserId: currentUserId,
            limit: limit,
            offset: offset
        )

        // Cache results (with TTL)
        cacheSearchResults(cacheKey: cacheKey, results: results)

        // Track search analytics
        let resultsCount = results.count
        Task { @MainActor in
            AnalyticsManager.shared.logEvent(.featureUsed, parameters: [
                "feature": "user_search",
                "query": searchQuery,
                "results_count": resultsCount,
                "cache_used": false
            ])
        }

        return results
    }

    // MARK: - Search Cache Management

    /// Cache search results with TTL
    private func cacheSearchResults(cacheKey: String, results: [User]) {
        // PERFORMANCE FIX: Periodically clean up expired entries (every 10 cache writes)
        if searchCache.count % 10 == 0 {
            cleanupExpiredCache()
        }

        // Evict oldest entries if cache is full
        if searchCache.count >= maxSearchCacheSize {
            let oldestKey = searchCache.min(by: { $0.value.timestamp < $1.value.timestamp })?.key
            if let key = oldestKey {
                searchCache.removeValue(forKey: key)
                Logger.shared.debug("Evicted oldest search cache entry", category: .performance)
            }
        }

        searchCache[cacheKey] = CachedSearchResult(
            results: results,
            timestamp: Date(),
            ttl: searchCacheDuration
        )
    }

    /// Clear search cache (useful for testing or manual cache invalidation)
    func clearSearchCache() {
        searchCache.removeAll()
        Logger.shared.info("Search cache cleared", category: .performance)
    }

    /// Clear expired cache entries (called periodically)
    private func cleanupExpiredCache() {
        let expiredKeys = searchCache.filter { $0.value.isExpired }.map { $0.key }
        expiredKeys.forEach { searchCache.removeValue(forKey: $0) }

        if !expiredKeys.isEmpty {
            Logger.shared.debug("Cleaned up \(expiredKeys.count) expired cache entries", category: .performance)
        }
    }

    /// Debounced search to prevent excessive API calls while typing
    /// - Parameters:
    ///   - query: Search query string
    ///   - currentUserId: Current user's ID to exclude from results
    ///   - debounceInterval: Time to wait before executing search (default: 0.3 seconds)
    ///   - limit: Maximum number of results
    ///   - completion: Callback with search results or error
    func debouncedSearch(
        query: String,
        currentUserId: String,
        debounceInterval: TimeInterval = 0.3,
        limit: Int = 20,
        completion: @escaping ([User]?, Error?) -> Void
    ) {
        // Cancel previous search task
        searchTask?.cancel()

        // Create new debounced search task
        searchTask = Task {
            // Wait for debounce interval
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))

            // Check if task was cancelled
            guard !Task.isCancelled else { return }

            do {
                let results = try await searchUsers(query: query, currentUserId: currentUserId, limit: limit)
                guard !Task.isCancelled else { return }
                completion(results, nil)
            } catch {
                guard !Task.isCancelled else { return }
                completion(nil, error)
            }
        }
    }
    
    /// Load more users (pagination)
    func loadMoreUsers(excludingUserId: String, lookingFor: String? = nil, ageRange: ClosedRange<Int>? = nil) async throws {
        try await fetchUsers(
            excludingUserId: excludingUserId,
            lookingFor: lookingFor,
            ageRange: ageRange,
            reset: false
        )
    }
    
    /// Check if user has completed profile
    func isProfileComplete(_ user: User) -> Bool {
        return !user.fullName.isEmpty &&
               !user.bio.isEmpty &&
               !user.profileImageURL.isEmpty &&
               user.interests.count >= 3 &&
               user.languages.count >= 1
    }
    
    /// Calculate profile completion percentage
    func profileCompletionPercentage(_ user: User) -> Int {
        var completedSteps = 0
        let totalSteps = 7

        if !user.fullName.isEmpty { completedSteps += 1 }
        if !user.bio.isEmpty { completedSteps += 1 }
        if !user.profileImageURL.isEmpty { completedSteps += 1 }
        if user.interests.count >= 3 { completedSteps += 1 }
        if user.languages.count >= 1 { completedSteps += 1 }
        if user.photos.count >= 2 { completedSteps += 1 }
        if user.age >= 18 { completedSteps += 1 }

        return (completedSteps * 100) / totalSteps
    }

    /// Cancel ongoing search task (useful for cleanup or manual cancellation)
    func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
    }

    // MARK: - Daily Like Limit Management

    /// OPTIMIZED: Check if user has daily likes remaining (uses cache to prevent double reads)
    ///
    /// PERFORMANCE IMPROVEMENTS:
    /// - Checks DailyLikeLimitCache first (0ms vs 200ms Firestore read)
    /// - Only reads from Firestore on cache miss
    /// - Eliminates double reads that were costing ~$200-300/month
    /// - Persists across app restarts via UserDefaults
    ///
    func checkDailyLikeLimit(userId: String) async -> Bool {
        // PERFORMANCE: Try cache first to avoid Firestore read
        if let cached = await DailyLikeLimitCache.shared.getRemainingLikes(userId: userId) {
            Logger.shared.debug("Cache HIT for daily like limit", category: .performance)
            return cached.likesRemaining > 0
        }

        // Cache miss - fetch from Firestore
        Logger.shared.debug("Cache MISS for daily like limit - fetching from Firestore", category: .performance)

        do {
            let document = try await db.collection("users").document(userId).getDocument()
            guard let data = document.data() else { return false }

            let lastResetDate = (data["lastLikeResetDate"] as? Timestamp)?.dateValue() ?? Date()
            var likesRemaining = data["likesRemainingToday"] as? Int ?? 50

            // Check if we need to reset (new day)
            if !Calendar.current.isDate(lastResetDate, inSameDayAs: Date()) {
                // Reset to 50 likes for new day
                try await resetDailyLikes(userId: userId)
                likesRemaining = 50
            }

            // Store in cache for future reads
            await DailyLikeLimitCache.shared.setRemainingLikes(
                userId: userId,
                likesRemaining: likesRemaining,
                lastResetDate: lastResetDate
            )

            return likesRemaining > 0
        } catch {
            Logger.shared.error("Error checking daily like limit", category: .database, error: error)
            return true // Allow on error to not block user
        }
    }

    /// Reset daily like count to default (50)
    func resetDailyLikes(userId: String) async throws {
        let now = Date()
        try await db.collection("users").document(userId).updateData([
            "likesRemainingToday": 50,
            "lastLikeResetDate": Timestamp(date: now)
        ])

        // Update cache
        await DailyLikeLimitCache.shared.setRemainingLikes(
            userId: userId,
            likesRemaining: 50,
            lastResetDate: now
        )
    }

    /// OPTIMIZED: Decrement daily like count (uses cache to prevent double reads)
    ///
    /// PERFORMANCE IMPROVEMENTS:
    /// - Uses cache to decrement instantly (was doing extra Firestore read before)
    /// - Updates Firestore asynchronously in background
    /// - Reduces Firestore reads by 50% for like operations
    ///
    func decrementDailyLikes(userId: String) async {
        // PERFORMANCE: Try to decrement in cache first
        if let newCount = await DailyLikeLimitCache.shared.decrementLikes(userId: userId) {
            Logger.shared.debug("Cache HIT - decremented to \(newCount)", category: .performance)

            // Update Firestore in background (fire-and-forget)
            Task {
                do {
                    try await db.collection("users").document(userId).updateData([
                        "likesRemainingToday": newCount
                    ])
                    Logger.shared.info("Likes remaining today: \(newCount)", category: .user)
                } catch {
                    Logger.shared.error("Error updating daily likes in Firestore", category: .database, error: error)
                }
            }
            return
        }

        // Cache miss - fall back to Firestore read + write
        Logger.shared.debug("Cache MISS for decrement - using Firestore", category: .performance)

        do {
            let document = try await db.collection("users").document(userId).getDocument()
            guard let data = document.data() else { return }

            var likesRemaining = data["likesRemainingToday"] as? Int ?? 50

            if likesRemaining > 0 {
                likesRemaining -= 1
                try await db.collection("users").document(userId).updateData([
                    "likesRemainingToday": likesRemaining
                ])

                // Store in cache for next time
                let lastResetDate = (data["lastLikeResetDate"] as? Timestamp)?.dateValue() ?? Date()
                await DailyLikeLimitCache.shared.setRemainingLikes(
                    userId: userId,
                    likesRemaining: likesRemaining,
                    lastResetDate: lastResetDate
                )

                Logger.shared.info("Likes remaining today: \(likesRemaining)", category: .user)
            }
        } catch {
            Logger.shared.error("Error decrementing daily likes", category: .database, error: error)
        }
    }

    /// OPTIMIZED: Get remaining daily likes count (uses cache to prevent Firestore reads)
    ///
    /// PERFORMANCE: Checks cache first, only reads Firestore on cache miss
    ///
    func getRemainingDailyLikes(userId: String) async -> Int {
        // PERFORMANCE: Try cache first
        if let cached = await DailyLikeLimitCache.shared.getRemainingLikes(userId: userId) {
            Logger.shared.debug("Cache HIT for remaining daily likes", category: .performance)
            return cached.likesRemaining
        }

        // Cache miss - fetch from Firestore
        Logger.shared.debug("Cache MISS for remaining daily likes", category: .performance)

        do {
            let document = try await db.collection("users").document(userId).getDocument()
            guard let data = document.data() else { return 50 }

            let lastResetDate = (data["lastLikeResetDate"] as? Timestamp)?.dateValue() ?? Date()
            var likesRemaining = data["likesRemainingToday"] as? Int ?? 50

            // Check if needs reset
            if !Calendar.current.isDate(lastResetDate, inSameDayAs: Date()) {
                likesRemaining = 50 // Will be reset on next check
            }

            // Store in cache
            await DailyLikeLimitCache.shared.setRemainingLikes(
                userId: userId,
                likesRemaining: likesRemaining,
                lastResetDate: lastResetDate
            )

            return likesRemaining
        } catch {
            Logger.shared.error("Error getting remaining daily likes", category: .database, error: error)
            return 50
        }
    }

    // MARK: - Super Likes Management

    /// Decrement super like count
    func decrementSuperLikes(userId: String) async {
        do {
            try await db.collection("users").document(userId).updateData([
                "superLikesRemaining": FieldValue.increment(Int64(-1))
            ])
            Logger.shared.info("Super Like used", category: .user)
        } catch {
            Logger.shared.error("Error decrementing super likes", category: .database, error: error)
        }
    }

    /// Get remaining super likes count
    func getRemainingSuperLikes(userId: String) async -> Int {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            guard let data = document.data() else { return 0 }
            return data["superLikesRemaining"] as? Int ?? 0
        } catch {
            Logger.shared.error("Error getting remaining super likes", category: .database, error: error)
            return 0
        }
    }

    /// Decrement user's rewind count
    func decrementRewinds(userId: String) async throws {
        do {
            try await db.collection("users").document(userId).updateData([
                "rewindsRemaining": FieldValue.increment(Int64(-1))
            ])
            Logger.shared.info("Rewind used", category: .user)
        } catch {
            Logger.shared.error("Error decrementing rewinds", category: .database, error: error)
            throw error
        }
    }

    // MARK: - Cache Management

    /// Clear user cache (useful on logout)
    func clearCache() async {
        if let firestoreRepo = repository as? FirestoreUserRepository {
            await firestoreRepo.clearCache()
        }
        searchCache.removeAll()

        // Clear daily like limit cache
        await DailyLikeLimitCache.shared.clearAll()

        Logger.shared.info("User cache cleared (including daily like limits)", category: .database)
    }

    /// Get cache statistics
    func getCacheSize() async -> Int {
        if let firestoreRepo = repository as? FirestoreUserRepository {
            return await firestoreRepo.getCacheSize()
        }
        return 0
    }

    deinit {
        searchTask?.cancel()
        searchCache.removeAll()
    }
}

// MARK: - Search Cache Model

/// Cached search result with TTL (Time To Live)
private struct CachedSearchResult {
    let results: [User]
    let timestamp: Date
    let ttl: TimeInterval

    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > ttl
    }
}
