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
class UserService: ObservableObject {
    @Published var users: [User] = []
    @Published var isLoading = false
    @Published var hasMoreUsers = true

    // REMOVED: @Published var error: Error?
    // ERROR HANDLING STRATEGY: This service now uses `throws` for error propagation
    // ViewModels should wrap calls in try/catch and use OperationState<T> for UI reactivity
    // See ERROR_HANDLING_GUIDE.md for details

    static let shared = UserService()
    private let db = Firestore.firestore()
    private var lastDocument: DocumentSnapshot?
    private var searchTask: Task<Void, Never>?

    // PERFORMANCE: Search result caching to reduce database queries
    private var searchCache: [String: CachedSearchResult] = [:]
    private let searchCacheDuration: TimeInterval = 300 // 5 minutes
    private let maxSearchCacheSize = 50 // Limit cache size to prevent memory bloat

    private init() {}

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

            Logger.shared.debug("Fetched \(newUsers.count) users", category: .database)

        } catch {
            Logger.shared.error("Failed to fetch users", category: .database, error: error)
            // Convert to CelestiaError and throw
            throw CelestiaError.from(error)
        }
    }
    
    /// Fetch a single user by ID
    /// - Throws: CelestiaError.userNotFound if user doesn't exist
    /// - Throws: CelestiaError.databaseError on database failure
    func fetchUser(userId: String) async throws -> User {
        Logger.shared.debug("Fetching user: \(userId)", category: .database)

        do {
            let doc = try await db.collection("users").document(userId).getDocument()

            guard doc.exists else {
                Logger.shared.warning("User not found: \(userId)", category: .database)
                throw CelestiaError.userNotFound
            }

            guard let user = try? doc.data(as: User.self) else {
                Logger.shared.error("Failed to decode user: \(userId)", category: .database)
                throw CelestiaError.invalidUserData("Unable to decode user data")
            }

            return user

        } catch let error as CelestiaError {
            // Already a CelestiaError, just rethrow
            throw error
        } catch {
            Logger.shared.error("Failed to fetch user", category: .database, error: error)
            throw CelestiaError.from(error)
        }
    }
    
    /// Update user profile
    /// - Throws: CelestiaError.userNotAuthenticated if user ID is nil
    /// - Throws: CelestiaError.databaseError on database failure
    func updateUser(_ user: User) async throws {
        guard let userId = user.id else {
            Logger.shared.error("Cannot update user: ID is nil", category: .database)
            throw CelestiaError.userNotAuthenticated
        }

        Logger.shared.debug("Updating user: \(userId)", category: .database)

        var updatedUser = user
        updatedUser.updateSearchFields() // Update lowercase search fields

        do {
            try db.collection("users").document(userId).setData(from: updatedUser, merge: true)
            Logger.shared.info("User updated successfully: \(userId)", category: .database)
        } catch {
            Logger.shared.error("Failed to update user", category: .database, error: error)
            throw CelestiaError.from(error)
        }
    }
    
    /// Update specific fields
    /// - Throws: CelestiaError.databaseError on database failure
    func updateUserFields(userId: String, fields: [String: Any]) async throws {
        Logger.shared.debug("Updating user fields: \(userId)", category: .database)

        do {
            try await db.collection("users").document(userId).updateData(fields)
            Logger.shared.debug("User fields updated: \(userId)", category: .database)
        } catch {
            Logger.shared.error("Failed to update user fields", category: .database, error: error)
            throw CelestiaError.from(error)
        }
    }
    
    /// Increment profile view count
    func incrementProfileViews(userId: String) async {
        do {
            try await db.collection("users").document(userId).updateData([
                "profileViews": FieldValue.increment(Int64(1))
            ])
        } catch {
            Logger.shared.error("Error incrementing profile views", category: .database, error: error)
        }
    }
    
    /// Update user's last active timestamp
    func updateLastActive(userId: String) async {
        do {
            try await db.collection("users").document(userId).updateData([
                "lastActive": FieldValue.serverTimestamp(),
                "isOnline": true
            ])
        } catch {
            Logger.shared.error("Error updating last active", category: .database, error: error)
        }
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
            AnalyticsManager.shared.logEvent(.searchCacheHit, parameters: [
                "query": searchQuery,
                "cache_age_seconds": Date().timeIntervalSince(cached.timestamp)
            ])
            return cached.results
        }

        Logger.shared.debug("Search cache MISS for query: '\(searchQuery)' - querying database", category: .performance)

        // CRITICAL OPTIMIZATION: Limit the number of documents fetched from Firestore
        // Previous implementation fetched ALL users - this is catastrophic at scale
        //
        // Strategy: Use prefix matching for name searches (Firestore-supported)
        // For location searches, fetch a limited set and filter client-side as fallback
        //
        // This is a temporary solution - production should use Algolia/Elasticsearch

        var results: [User] = []

        // Approach 1: Try prefix matching on fullName (most common search pattern)
        // Firestore supports: where("field", ">=", prefix) AND where("field", "<", prefixEnd)
        let prefixEnd = searchQuery + "\u{f8ff}" // Unicode max character for range query

        do {
            // Query 1: Search by name prefix (most efficient)
            let nameQuery = db.collection("users")
                .whereField("showMeInSearch", isEqualTo: true)
                .whereField("fullNameLowercase", isGreaterThanOrEqualTo: searchQuery)
                .whereField("fullNameLowercase", isLessThan: prefixEnd)
                .limit(to: limit)

            let nameSnapshot = try await nameQuery.getDocuments()
            let nameResults = nameSnapshot.documents
                .compactMap { try? $0.data(as: User.self) }
                .filter { $0.id != currentUserId }

            results.append(contentsOf: nameResults)

            // If we have enough results from name search, return early
            if results.count >= limit {
                Logger.shared.info("Search completed with \(results.count) name-based results", category: .performance)
                cacheSearchResults(cacheKey: cacheKey, results: Array(results.prefix(limit)))
                return Array(results.prefix(limit))
            }

        } catch {
            // Firestore might not have the index yet - log warning and fallback
            Logger.shared.warning("Name prefix query failed (index may not exist): \(error.localizedDescription)", category: .database)
            Logger.shared.info("To fix: Create Firestore composite index on [showMeInSearch, fullNameLowercase]", category: .database)
        }

        // Approach 2: If name search didn't yield enough results, try country prefix match
        // This handles location-based searches
        do {
            let remainingLimit = limit - results.count
            if remainingLimit > 0 {
                let countryQuery = db.collection("users")
                    .whereField("showMeInSearch", isEqualTo: true)
                    .whereField("countryLowercase", isGreaterThanOrEqualTo: searchQuery)
                    .whereField("countryLowercase", isLessThan: prefixEnd)
                    .limit(to: remainingLimit)

                let countrySnapshot = try await countryQuery.getDocuments()
                let countryResults = countrySnapshot.documents
                    .compactMap { try? $0.data(as: User.self) }
                    .filter { user in
                        user.id != currentUserId &&
                        !results.contains(where: { $0.id == user.id }) // Avoid duplicates
                    }

                results.append(contentsOf: countryResults)
            }

        } catch {
            Logger.shared.warning("Country prefix query failed (index may not exist): \(error.localizedDescription)", category: .database)
            Logger.shared.info("To fix: Create Firestore composite index on [showMeInSearch, countryLowercase]", category: .database)
        }

        // Approach 3: Fallback - fetch limited set and filter client-side (last resort)
        // ONLY if we still don't have enough results
        if results.count < limit / 2 {
            Logger.shared.warning("Insufficient results from indexed queries - falling back to limited client-side filtering", category: .performance)

            // Fetch a SMALL limited set (NOT all users)
            let fallbackLimit = min(100, limit * 5) // Fetch at most 100 users

            var fallbackQuery = db.collection("users")
                .whereField("showMeInSearch", isEqualTo: true)
                .order(by: "lastActive", descending: true) // Get most active users
                .limit(to: fallbackLimit)

            if let offset = offset {
                fallbackQuery = fallbackQuery.start(afterDocument: offset)
            }

            let fallbackSnapshot = try await fallbackQuery.getDocuments()

            let fallbackResults = fallbackSnapshot.documents
                .compactMap { try? $0.data(as: User.self) }
                .filter { user in
                    guard user.id != currentUserId else { return false }
                    guard !results.contains(where: { $0.id == user.id }) else { return false }

                    // Client-side filtering (limited scope)
                    return user.fullName.lowercased().contains(searchQuery) ||
                           user.location.lowercased().contains(searchQuery) ||
                           user.country.lowercased().contains(searchQuery)
                }

            results.append(contentsOf: fallbackResults)

            // Log performance metrics
            AnalyticsManager.shared.logEvent(.searchFallbackUsed, parameters: [
                "query": searchQuery,
                "scanned_documents": fallbackSnapshot.documents.count,
                "matched_results": fallbackResults.count
            ])
        }

        // Limit final results
        let finalResults = Array(results.prefix(limit))

        Logger.shared.info("Search completed: query='\(searchQuery)', results=\(finalResults.count), total_scanned=\(results.count)", category: .performance)

        // Cache results (with TTL)
        cacheSearchResults(cacheKey: cacheKey, results: finalResults)

        // Track search analytics
        AnalyticsManager.shared.logEvent(.userSearch, parameters: [
            "query": searchQuery,
            "results_count": finalResults.count,
            "cache_used": false
        ])

        return finalResults
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
