//
//  UserDisplayNameCache.swift
//  Celestia
//
//  In-memory cache for user display names with TTL
//  Prevents unnecessary Firestore fetches for frequently accessed user data
//

import Foundation
import FirebaseFirestore

/// Cached user display information
struct CachedUserInfo {
    let userId: String
    let fullName: String
    let cachedAt: Date

    /// Check if cache entry is still valid based on TTL
    func isValid(ttl: TimeInterval) -> Bool {
        return Date().timeIntervalSince(cachedAt) < ttl
    }
}

@MainActor
class UserDisplayNameCache {
    static let shared = UserDisplayNameCache()

    private var cache: [String: CachedUserInfo] = [:]
    private let db = Firestore.firestore()

    // Cache settings
    private let defaultTTL: TimeInterval = 5 * 60 // 5 minutes
    private let maxCacheSize = 500 // Maximum number of cached entries

    private init() {
        // Schedule periodic cleanup
        schedulePeriodicCleanup()
    }

    // MARK: - Public Methods

    /// Get user's full name, using cache or fetching from Firestore
    func getUserName(userId: String, ttl: TimeInterval? = nil) async throws -> String {
        let effectiveTTL = ttl ?? defaultTTL

        // Check cache first
        if let cached = cache[userId], cached.isValid(ttl: effectiveTTL) {
            Logger.shared.debug("UserDisplayNameCache HIT for userId: \(userId)", category: .general)
            return cached.fullName
        }

        // Cache miss - fetch from Firestore
        Logger.shared.debug("UserDisplayNameCache MISS for userId: \(userId)", category: .general)
        let fullName = try await fetchUserNameFromFirestore(userId: userId)

        // Update cache
        cache[userId] = CachedUserInfo(
            userId: userId,
            fullName: fullName,
            cachedAt: Date()
        )

        // Clean cache if needed
        if cache.count > maxCacheSize {
            cleanOldestEntries()
        }

        return fullName
    }

    /// Prefetch multiple user names in a single batch query (optimal)
    func prefetchUserNames(userIds: [String]) async throws {
        // Filter out already cached users
        let uncachedUserIds = userIds.filter { userId in
            guard let cached = cache[userId] else { return true }
            return !cached.isValid(ttl: defaultTTL)
        }

        guard !uncachedUserIds.isEmpty else {
            Logger.shared.debug("All user names already cached", category: .general)
            return
        }

        Logger.shared.debug("Prefetching \(uncachedUserIds.count) user names", category: .general)

        // Batch fetch from Firestore (max 30 at a time due to Firestore 'in' query limit)
        for chunk in uncachedUserIds.chunked(into: 30) {
            let snapshot = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()

            for doc in snapshot.documents {
                let userId = doc.documentID
                if let fullName = doc.data()["fullName"] as? String {
                    cache[userId] = CachedUserInfo(
                        userId: userId,
                        fullName: fullName,
                        cachedAt: Date()
                    )
                }
            }
        }
    }

    /// Invalidate cache for a specific user
    func invalidate(userId: String) {
        cache.removeValue(forKey: userId)
        Logger.shared.debug("Invalidated cache for userId: \(userId)", category: .general)
    }

    /// Invalidate all cached entries
    func invalidateAll() {
        cache.removeAll()
        Logger.shared.debug("Invalidated all cached user names", category: .general)
    }

    /// Get current cache size
    func getCacheSize() -> Int {
        return cache.count
    }

    /// Get cache statistics
    func getCacheStats() -> (size: Int, oldestEntry: Date?, newestEntry: Date?) {
        let oldestEntry = cache.values.map(\.cachedAt).min()
        let newestEntry = cache.values.map(\.cachedAt).max()
        return (cache.count, oldestEntry, newestEntry)
    }

    // MARK: - Private Methods

    private func fetchUserNameFromFirestore(userId: String) async throws -> String {
        let snapshot = try await db.collection("users").document(userId).getDocument()

        guard let fullName = snapshot.data()?["fullName"] as? String else {
            throw CelestiaError.userNotFound
        }

        return fullName
    }

    private func cleanOldestEntries() {
        // Remove oldest 20% of entries when cache is full
        let targetSize = Int(Double(maxCacheSize) * 0.8)
        let entriesToRemove = cache.count - targetSize

        guard entriesToRemove > 0 else { return }

        let sortedEntries = cache.sorted { $0.value.cachedAt < $1.value.cachedAt }
        let keysToRemove = sortedEntries.prefix(entriesToRemove).map(\.key)

        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }

        Logger.shared.debug("Cleaned \(keysToRemove.count) oldest cache entries", category: .general)
    }

    private func cleanExpiredEntries() {
        let beforeCount = cache.count

        cache = cache.filter { _, info in
            info.isValid(ttl: defaultTTL)
        }

        let removedCount = beforeCount - cache.count
        if removedCount > 0 {
            Logger.shared.debug("Cleaned \(removedCount) expired cache entries", category: .general)
        }
    }

    private func schedulePeriodicCleanup() {
        Task {
            while true {
                // Clean expired entries every 10 minutes
                try? await Task.sleep(nanoseconds: 10 * 60 * 1_000_000_000)
                await cleanExpiredEntries()
            }
        }
    }
}

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
