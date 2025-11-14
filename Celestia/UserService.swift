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
        
        var query = db.collection("users")
            .whereField("showMeInSearch", isEqualTo: true)
            .order(by: "lastActive", descending: true)
            .limit(to: limit)
        
        // Apply filters
        if let lookingFor = lookingFor {
            query = query.whereField("gender", isEqualTo: lookingFor)
        }
        
        if let ageRange = ageRange {
            query = query
                .whereField("age", isGreaterThanOrEqualTo: ageRange.lowerBound)
                .whereField("age", isLessThanOrEqualTo: ageRange.upperBound)
        }
        
        if let country = country {
            query = query.whereField("country", isEqualTo: country)
        }
        
        // Pagination
        if let lastDoc = lastDocument {
            query = query.start(afterDocument: lastDoc)
        }
        
        do {
            let snapshot = try await query.getDocuments()
            lastDocument = snapshot.documents.last

            let newUsers = snapshot.documents.compactMap { try? $0.data(as: User.self) }
                .filter { $0.id != excludingUserId }

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
            try await db.collection("users").document(userId).updateData([
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
        if let cached = searchCache[cacheKey], !cached.isExpired {
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

    /// Check if user has daily likes remaining
    func checkDailyLikeLimit(userId: String) async -> Bool {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            guard let data = document.data() else { return false }

            let lastResetDate = (data["lastLikeResetDate"] as? Timestamp)?.dateValue() ?? Date()
            let likesRemaining = data["likesRemainingToday"] as? Int ?? 50

            // Check if we need to reset (new day)
            if !Calendar.current.isDate(lastResetDate, inSameDayAs: Date()) {
                // Reset to 50 likes for new day
                try await resetDailyLikes(userId: userId)
                return true
            }

            return likesRemaining > 0
        } catch {
            Logger.shared.error("Error checking daily like limit", category: .database, error: error)
            return true // Allow on error to not block user
        }
    }

    /// Reset daily like count to default (50)
    func resetDailyLikes(userId: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "likesRemainingToday": 50,
            "lastLikeResetDate": Timestamp(date: Date())
        ])
    }

    /// Decrement daily like count
    func decrementDailyLikes(userId: String) async {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            guard let data = document.data() else { return }

            var likesRemaining = data["likesRemainingToday"] as? Int ?? 50

            if likesRemaining > 0 {
                likesRemaining -= 1
                try await db.collection("users").document(userId).updateData([
                    "likesRemainingToday": likesRemaining
                ])

                Logger.shared.info("Likes remaining today: \(likesRemaining)", category: .user)
            }
        } catch {
            Logger.shared.error("Error decrementing daily likes", category: .database, error: error)
        }
    }

    /// Get remaining daily likes count
    func getRemainingDailyLikes(userId: String) async -> Int {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            guard let data = document.data() else { return 50 }

            let lastResetDate = (data["lastLikeResetDate"] as? Timestamp)?.dateValue() ?? Date()

            // Check if needs reset
            if !Calendar.current.isDate(lastResetDate, inSameDayAs: Date()) {
                return 50 // Will be reset on next check
            }

            return data["likesRemainingToday"] as? Int ?? 50
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

    // MARK: - Cache Management

    /// Clear user cache (useful on logout)
    func clearCache() async {
        if let firestoreRepo = repository as? FirestoreUserRepository {
            await firestoreRepo.clearCache()
        }
        searchCache.removeAll()
        Logger.shared.info("User cache cleared", category: .database)
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
