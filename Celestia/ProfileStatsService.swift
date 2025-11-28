//
//  ProfileStatsService.swift
//  Celestia
//
//  Service for calculating accurate profile statistics
//  Ensures counts are based on actual database records, not incremented counters
//

import Foundation
import FirebaseFirestore

@MainActor
class ProfileStatsService: ObservableObject {
    static let shared = ProfileStatsService()

    private let db = Firestore.firestore()

    // Cache to avoid repeated queries
    private var statsCache: [String: ProfileStats] = [:]
    private var cacheTimestamps: [String: Date] = [:]
    private let cacheDuration: TimeInterval = 60 // 1 minute cache

    private init() {}

    /// Get accurate profile stats for a user
    func getAccurateStats(userId: String) async throws -> ProfileStats {
        // Check cache first
        if let cached = statsCache[userId],
           let timestamp = cacheTimestamps[userId],
           Date().timeIntervalSince(timestamp) < cacheDuration {
            Logger.shared.debug("Cache hit for profile stats: \(userId)", category: .database)
            return cached
        }

        Logger.shared.debug("Calculating accurate stats for user: \(userId)", category: .database)

        // Calculate stats concurrently for better performance
        async let matchCount = getUniqueMatchCount(userId: userId)
        async let likesReceived = getUniqueLikesReceived(userId: userId)
        async let profileViews = getUniqueProfileViews(userId: userId)

        let stats = try await ProfileStats(
            matchCount: matchCount,
            likesReceived: likesReceived,
            profileViews: profileViews
        )

        // Update cache
        statsCache[userId] = stats
        cacheTimestamps[userId] = Date()

        Logger.shared.info("Accurate stats calculated - Matches: \(stats.matchCount), Likes: \(stats.likesReceived), Views: \(stats.profileViews)", category: .database)

        return stats
    }

    /// Count unique matches for a user
    private func getUniqueMatchCount(userId: String) async throws -> Int {
        let snapshot = try await db.collection("matches")
            .whereFilter(Filter.orFilter([
                Filter.whereField("user1Id", isEqualTo: userId),
                Filter.whereField("user2Id", isEqualTo: userId)
            ]))
            .whereField("isActive", isEqualTo: true)
            .getDocuments()

        // Use Set to ensure uniqueness (shouldn't have duplicates, but being safe)
        var uniqueMatches = Set<String>()

        for document in snapshot.documents {
            let data = document.data()
            if let user1Id = data["user1Id"] as? String,
               let user2Id = data["user2Id"] as? String {
                // Create a deterministic match ID (sorted user IDs)
                let matchPair = [user1Id, user2Id].sorted().joined(separator: "_")
                uniqueMatches.insert(matchPair)
            }
        }

        return uniqueMatches.count
    }

    /// Count unique likes received by a user
    private func getUniqueLikesReceived(userId: String) async throws -> Int {
        let snapshot = try await db.collection("likes")
            .whereField("toUserId", isEqualTo: userId)
            .whereField("isActive", isEqualTo: true)
            .getDocuments()

        // Use Set to ensure we count each unique user only once
        var uniqueLikers = Set<String>()

        for document in snapshot.documents {
            if let fromUserId = document.data()["fromUserId"] as? String {
                uniqueLikers.insert(fromUserId)
            }
        }

        return uniqueLikers.count
    }

    /// Count unique profile views for a user
    private func getUniqueProfileViews(userId: String) async throws -> Int {
        // Try to get from profileViews collection first
        do {
            let snapshot = try await db.collection("profileViews")
                .whereField("viewedUserId", isEqualTo: userId)
                .getDocuments()

            // Use Set to count unique viewers
            var uniqueViewers = Set<String>()

            for document in snapshot.documents {
                if let viewerId = document.data()["viewerUserId"] as? String {
                    uniqueViewers.insert(viewerId)
                }
            }

            return uniqueViewers.count
        } catch {
            // If profileViews collection doesn't exist or has no data,
            // fall back to the user's profileViews field
            Logger.shared.warning("profileViews collection not available, using user field", category: .database)

            let userDoc = try await db.collection("users").document(userId).getDocument()
            if let profileViews = userDoc.data()?["profileViews"] as? Int {
                return profileViews
            }
            return 0
        }
    }

    /// Record a profile view (with duplicate prevention)
    func recordProfileView(viewerId: String, viewedUserId: String) async throws {
        // Don't record if viewing own profile
        guard viewerId != viewedUserId else {
            return
        }

        // Use deterministic document ID to prevent duplicate views from same user
        let viewId = "\(viewerId)_\(viewedUserId)"

        let viewData: [String: Any] = [
            "viewerUserId": viewerId,
            "viewedUserId": viewedUserId,
            "timestamp": FieldValue.serverTimestamp()
        ]

        // Use setData with merge to update timestamp if view already exists
        // This ensures each viewer is counted only once
        try await db.collection("profileViews")
            .document(viewId)
            .setData(viewData, merge: true)

        // Invalidate cache for this user
        statsCache.removeValue(forKey: viewedUserId)
        cacheTimestamps.removeValue(forKey: viewedUserId)

        Logger.shared.debug("Profile view recorded: \(viewerId) -> \(viewedUserId)", category: .database)
    }

    /// Clear cache for a specific user (useful after updates)
    func clearCache(userId: String) {
        statsCache.removeValue(forKey: userId)
        cacheTimestamps.removeValue(forKey: userId)
    }

    /// Clear all cached stats
    func clearAllCache() {
        statsCache.removeAll()
        cacheTimestamps.removeAll()
    }
}

// MARK: - Profile Stats Model

struct ProfileStats {
    let matchCount: Int
    let likesReceived: Int
    let profileViews: Int
}
