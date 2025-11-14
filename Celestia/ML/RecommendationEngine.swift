//
//  RecommendationEngine.swift
//  Celestia
//
//  ML-powered recommendation engine for intelligent user matching
//  Combines profile compatibility, collaborative filtering, and user behavior learning
//

import Foundation
import FirebaseFirestore

@MainActor
class RecommendationEngine: ObservableObject {
    static let shared = RecommendationEngine()

    @Published var isEnabled = true // Feature flag for A/B testing
    @Published var algorithmVariant: AlgorithmVariant = .standard

    private let db = Firestore.firestore()
    private let matchingAlgorithm = MatchingAlgorithm.shared

    // Performance monitoring
    private var scoringStartTime: Date?

    private init() {
        // Load algorithm variant from user defaults (for A/B testing)
        if let savedVariant = UserDefaults.standard.string(forKey: "algorithmVariant"),
           let variant = AlgorithmVariant(rawValue: savedVariant) {
            self.algorithmVariant = variant
        }
    }

    /// Algorithm variants for A/B testing
    enum AlgorithmVariant: String, CaseIterable {
        case standard = "standard"           // Profile compatibility + collaborative filtering
        case aggressive = "aggressive"       // Higher weight on user behavior
        case conservative = "conservative"   // Higher weight on profile match
        case experimental = "experimental"   // New ML features
    }

    // MARK: - Main Recommendation API

    /// Rank and score a list of candidate users for the current user
    /// Returns users sorted by compatibility score (highest first)
    func rankUsers(_ candidates: [User], currentUser: User) async -> [(user: User, score: Double)] {
        guard isEnabled else {
            // If disabled, return users in original order with neutral scores
            return candidates.map { ($0, 0.5) }
        }

        // Track performance
        scoringStartTime = Date()

        // Score all candidates in parallel
        let scoredUsers = await withTaskGroup(of: (User, Double).self) { group in
            for candidate in candidates {
                group.addTask {
                    let score = await self.scoreUser(candidate, for: currentUser)
                    return (candidate, score)
                }
            }

            var results: [(User, Double)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }

        // Sort by score (highest first)
        let rankedUsers = scoredUsers.sorted { $0.1 > $1.1 }

        // Log performance metrics
        if let startTime = scoringStartTime {
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.info("Scored \(candidates.count) users in \(String(format: "%.3f", duration))s", category: .matching)

            AnalyticsManager.shared.logEvent(.performanceMetric, parameters: [
                "metric_type": "recommendation_scoring",
                "duration_ms": Int(duration * 1000),
                "user_count": candidates.count,
                "algorithm_variant": algorithmVariant.rawValue
            ])
        }

        return rankedUsers
    }

    /// Score a single candidate user for compatibility with current user
    /// Returns a score between 0.0 (poor match) and 1.0 (excellent match)
    private func scoreUser(_ candidate: User, for currentUser: User) async -> Double {
        // Get component scores based on algorithm variant
        let weights = getWeights(for: algorithmVariant)

        // 1. Profile Compatibility Score (interests, preferences, demographics)
        let profileScore = matchingAlgorithm.calculateCompatibilityScore(
            currentUser: currentUser,
            candidate: candidate
        )

        // 2. Collaborative Filtering Score (users who liked X also liked Y)
        let collaborativeScore = await calculateCollaborativeScore(
            currentUser: currentUser,
            candidate: candidate
        )

        // 3. Behavioral Score (based on historical swipe patterns)
        let behavioralScore = await calculateBehavioralScore(
            currentUser: currentUser,
            candidate: candidate
        )

        // 4. Freshness Boost (prioritize new users)
        let freshnessBoost = calculateFreshnessBoost(candidate)

        // 5. Activity Score (prioritize active users)
        let activityScore = calculateActivityScore(candidate)

        // 6. Geographic Proximity Score
        let proximityScore = matchingAlgorithm.calculateProximityScore(
            currentUser: currentUser,
            candidate: candidate
        )

        // Weighted combination based on variant
        let finalScore = (
            weights.profile * profileScore +
            weights.collaborative * collaborativeScore +
            weights.behavioral * behavioralScore +
            weights.proximity * proximityScore +
            weights.activity * activityScore
        ) + (weights.freshness * freshnessBoost)

        // Clamp to [0, 1]
        return min(max(finalScore, 0.0), 1.0)
    }

    // MARK: - Scoring Components

    /// Calculate collaborative filtering score
    /// "Users who liked candidate also liked these users, which currentUser also liked"
    private func calculateCollaborativeScore(currentUser: User, candidate: User) async -> Double {
        guard let currentUserId = currentUser.id,
              let candidateId = candidate.id else {
            return 0.5 // Neutral score if IDs missing
        }

        do {
            // Get users who liked the candidate
            let candidateLikers = try await db.collection("likes")
                .whereField("toUserId", isEqualTo: candidateId)
                .whereField("isActive", isEqualTo: true)
                .limit(to: 100)
                .getDocuments()

            let candidateLikerIds = candidateLikers.documents.compactMap { $0.data()["fromUserId"] as? String }

            guard !candidateLikerIds.isEmpty else { return 0.5 }

            // Get users that currentUser has liked
            let currentUserLikes = try await db.collection("likes")
                .whereField("fromUserId", isEqualTo: currentUserId)
                .whereField("isActive", isEqualTo: true)
                .limit(to: 100)
                .getDocuments()

            let currentUserLikedIds = Set(currentUserLikes.documents.compactMap { $0.data()["toUserId"] as? String })

            guard !currentUserLikedIds.isEmpty else { return 0.5 }

            // For each user who liked the candidate, count how many users they liked that currentUser also liked
            var similarityScores: [Double] = []

            for likerId in candidateLikerIds.prefix(20) { // Limit to top 20 for performance
                let likerLikes = try await db.collection("likes")
                    .whereField("fromUserId", isEqualTo: likerId)
                    .whereField("isActive", isEqualTo: true)
                    .limit(to: 50)
                    .getDocuments()

                let likerLikedIds = Set(likerLikes.documents.compactMap { $0.data()["toUserId"] as? String })

                // Calculate Jaccard similarity
                let intersection = currentUserLikedIds.intersection(likerLikedIds)
                let union = currentUserLikedIds.union(likerLikedIds)

                if !union.isEmpty {
                    let similarity = Double(intersection.count) / Double(union.count)
                    similarityScores.append(similarity)
                }
            }

            // Average similarity score
            guard !similarityScores.isEmpty else { return 0.5 }
            let avgSimilarity = similarityScores.reduce(0, +) / Double(similarityScores.count)

            return avgSimilarity

        } catch {
            Logger.shared.error("Error calculating collaborative score", category: .matching, error: error)
            return 0.5
        }
    }

    /// Calculate behavioral score based on user's historical swipe patterns
    /// Learn what types of profiles the user tends to like
    private func calculateBehavioralScore(currentUser: User, candidate: User) async -> Double {
        guard let currentUserId = currentUser.id else { return 0.5 }

        do {
            // Get user's recent likes (last 50)
            let recentLikes = try await db.collection("likes")
                .whereField("fromUserId", isEqualTo: currentUserId)
                .whereField("isActive", isEqualTo: true)
                .order(by: "timestamp", descending: true)
                .limit(to: 50)
                .getDocuments()

            let likedUserIds = recentLikes.documents.compactMap { $0.data()["toUserId"] as? String }

            guard likedUserIds.count >= 5 else {
                // Not enough data, return neutral score
                return 0.5
            }

            // Fetch liked users' profiles to analyze patterns
            let likedUsers = try await fetchUsersById(likedUserIds.prefix(20).map { $0 })

            guard !likedUsers.isEmpty else { return 0.5 }

            // Analyze patterns in liked profiles
            let patterns = analyzeUserPreferencePatterns(likedUsers: likedUsers)

            // Score candidate against learned patterns
            var patternScore = 0.0
            var patternCount = 0.0

            // Interest overlap with liked users
            let candidateInterests = Set(candidate.interests)
            let avgLikedInterests = Set(likedUsers.flatMap { $0.interests })
            if !avgLikedInterests.isEmpty {
                let interestOverlap = Double(candidateInterests.intersection(avgLikedInterests).count) / Double(avgLikedInterests.count)
                patternScore += interestOverlap
                patternCount += 1
            }

            // Age preference pattern
            let avgLikedAge = likedUsers.map { Double($0.age) }.reduce(0, +) / Double(likedUsers.count)
            let ageDifference = abs(Double(candidate.age) - avgLikedAge)
            let ageScore = max(0, 1.0 - (ageDifference / 10.0)) // Score decreases with age difference
            patternScore += ageScore
            patternCount += 1

            // Language overlap pattern
            let candidateLanguages = Set(candidate.languages)
            let avgLikedLanguages = Set(likedUsers.flatMap { $0.languages })
            if !avgLikedLanguages.isEmpty {
                let languageOverlap = Double(candidateLanguages.intersection(avgLikedLanguages).count) / Double(avgLikedLanguages.count)
                patternScore += languageOverlap
                patternCount += 1
            }

            return patternCount > 0 ? patternScore / patternCount : 0.5

        } catch {
            Logger.shared.error("Error calculating behavioral score", category: .matching, error: error)
            return 0.5
        }
    }

    /// Calculate freshness boost for new users (helps them get discovered)
    private func calculateFreshnessBoost(_ user: User) -> Double {
        let daysSinceJoined = Date().timeIntervalSince(user.timestamp) / 86400

        // New users (< 7 days) get a boost
        if daysSinceJoined < 1 {
            return 0.15 // 15% boost for users < 1 day old
        } else if daysSinceJoined < 3 {
            return 0.10 // 10% boost for users < 3 days old
        } else if daysSinceJoined < 7 {
            return 0.05 // 5% boost for users < 7 days old
        }

        return 0.0 // No boost for older users
    }

    /// Calculate activity score (prioritize recently active users)
    private func calculateActivityScore(_ user: User) -> Double {
        let hoursSinceActive = Date().timeIntervalSince(user.lastActive) / 3600

        if user.isOnline {
            return 1.0 // Online now = maximum score
        } else if hoursSinceActive < 1 {
            return 0.9 // Active in last hour
        } else if hoursSinceActive < 6 {
            return 0.7 // Active in last 6 hours
        } else if hoursSinceActive < 24 {
            return 0.5 // Active in last day
        } else if hoursSinceActive < 72 {
            return 0.3 // Active in last 3 days
        }

        return 0.1 // Inactive users get low score
    }

    // MARK: - Helper Methods

    /// Get scoring weights based on algorithm variant
    private func getWeights(for variant: AlgorithmVariant) -> (
        profile: Double,
        collaborative: Double,
        behavioral: Double,
        proximity: Double,
        activity: Double,
        freshness: Double
    ) {
        switch variant {
        case .standard:
            return (
                profile: 0.35,
                collaborative: 0.20,
                behavioral: 0.20,
                proximity: 0.15,
                activity: 0.10,
                freshness: 0.00 // Added as boost
            )
        case .aggressive:
            return (
                profile: 0.20,
                collaborative: 0.30,
                behavioral: 0.30,
                proximity: 0.10,
                activity: 0.10,
                freshness: 0.00
            )
        case .conservative:
            return (
                profile: 0.50,
                collaborative: 0.15,
                behavioral: 0.10,
                proximity: 0.15,
                activity: 0.10,
                freshness: 0.00
            )
        case .experimental:
            return (
                profile: 0.30,
                collaborative: 0.25,
                behavioral: 0.25,
                proximity: 0.10,
                activity: 0.10,
                freshness: 0.00
            )
        }
    }

    /// Fetch users by IDs
    private func fetchUsersById(_ userIds: [String]) async throws -> [User] {
        var users: [User] = []

        // Firestore 'in' queries are limited to 10 items
        let chunks = stride(from: 0, to: userIds.count, by: 10).map {
            Array(userIds[$0..<min($0 + 10, userIds.count)])
        }

        for chunk in chunks {
            let snapshot = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()

            let chunkUsers = snapshot.documents.compactMap { doc -> User? in
                let data = doc.data()
                var user = User(dictionary: data)
                user.id = doc.documentID
                return user
            }

            users.append(contentsOf: chunkUsers)
        }

        return users
    }

    /// Analyze patterns in users that the current user has liked
    private func analyzeUserPreferencePatterns(likedUsers: [User]) -> [String: Any] {
        var patterns: [String: Any] = [:]

        // Common interests
        let allInterests = likedUsers.flatMap { $0.interests }
        let interestCounts = Dictionary(grouping: allInterests) { $0 }.mapValues { $0.count }
        patterns["top_interests"] = interestCounts.sorted { $0.value > $1.value }.prefix(10).map { $0.key }

        // Average age
        let avgAge = likedUsers.map { $0.age }.reduce(0, +) / likedUsers.count
        patterns["avg_age"] = avgAge

        // Common languages
        let allLanguages = likedUsers.flatMap { $0.languages }
        let languageCounts = Dictionary(grouping: allLanguages) { $0 }.mapValues { $0.count }
        patterns["top_languages"] = languageCounts.sorted { $0.value > $1.value }.prefix(5).map { $0.key }

        // Premium preference
        let premiumCount = likedUsers.filter { $0.isPremium }.count
        patterns["premium_preference"] = Double(premiumCount) / Double(likedUsers.count)

        return patterns
    }

    // MARK: - A/B Testing

    /// Set algorithm variant for A/B testing
    func setAlgorithmVariant(_ variant: AlgorithmVariant) {
        self.algorithmVariant = variant
        UserDefaults.standard.set(variant.rawValue, forKey: "algorithmVariant")

        // Log variant change
        AnalyticsManager.shared.logEvent(.customEvent("algorithm_variant_changed"), parameters: [
            "variant": variant.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])

        Logger.shared.info("Algorithm variant set to: \(variant.rawValue)", category: .matching)
    }

    /// Enable/disable recommendation engine
    func setEnabled(_ enabled: Bool) {
        self.isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "recommendationEngineEnabled")

        Logger.shared.info("Recommendation engine \(enabled ? "enabled" : "disabled")", category: .matching)
    }
}
