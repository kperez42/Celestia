//
//  AnalyticsManager.swift
//  Celestia
//
//  Manages analytics tracking and insights data
//

import Foundation
import FirebaseFirestore
import FirebaseAnalytics

@MainActor
class AnalyticsManager: ObservableObject {
    static let shared = AnalyticsManager()

    private let db = Firestore.firestore()
    private let authService = AuthService.shared

    @Published var isLoading = false

    private init() {}

    // MARK: - Profile View Tracking

    func trackProfileView(viewedUserId: String, viewerUserId: String) async throws {
        // Check privacy settings first
        guard let viewedUser = try? await fetchUser(userId: viewedUserId) else { return }

        // Don't track if user has disabled profile view tracking (future feature)
        // For now, always track

        // Use retry logic for Firestore operations
        try await RetryManager.shared.retryDatabaseOperation {
            let profileView: [String: Any] = [
                "viewedUserId": viewedUserId,
                "viewerUserId": viewerUserId,
                "timestamp": Timestamp(date: Date()),
                "deviceType": "iOS"
            ]

            try await self.db.collection("profileViews").addDocument(data: profileView)

            // Update user's view count
            try await self.db.collection("users").document(viewedUserId).updateData([
                "profileViews": FieldValue.increment(Int64(1))
            ])
        }

        // Log to Firebase Analytics (non-critical, don't retry)
        Analytics.logEvent("profile_view", parameters: [
            "viewed_user_id": viewedUserId,
            "viewer_user_id": viewerUserId
        ])
    }

    // MARK: - Swipe Tracking

    func trackSwipe(swipedUserId: String, swiperUserId: String, direction: SwipeDirection) async throws {
        // Use retry logic for Firestore operations
        try await RetryManager.shared.retryDatabaseOperation {
            let swipeAction: [String: Any] = [
                "swipedUserId": swipedUserId,
                "swiperUserId": swiperUserId,
                "direction": direction.rawValue,
                "timestamp": Timestamp(date: Date())
            ]

            try await self.db.collection("swipeActions").addDocument(data: swipeAction)

            // Update swiper stats
            try await self.db.collection("users").document(swiperUserId).updateData([
                "likesGiven": direction == .right ? FieldValue.increment(Int64(1)) : FieldValue.increment(Int64(0))
            ])

            // Update swiped user stats
            if direction == .right {
                try await self.db.collection("users").document(swipedUserId).updateData([
                    "likesReceived": FieldValue.increment(Int64(1))
                ])
            }
        }

        // Log to Firebase Analytics (non-critical, don't retry)
        Analytics.logEvent("swipe_action", parameters: [
            "swiped_user_id": swipedUserId,
            "swiper_user_id": swiperUserId,
            "direction": direction.rawValue
        ])
    }

    // MARK: - Match Tracking

    func trackMatch(user1Id: String, user2Id: String) async throws {
        let match: [String: Any] = [
            "user1Id": user1Id,
            "user2Id": user2Id,
            "timestamp": Timestamp(date: Date()),
            "status": "active"
        ]

        try await db.collection("matches").addDocument(data: match)

        // Update both users' match counts
        try await db.collection("users").document(user1Id).updateData([
            "matchCount": FieldValue.increment(Int64(1))
        ])

        try await db.collection("users").document(user2Id).updateData([
            "matchCount": FieldValue.increment(Int64(1))
        ])

        // Log to Firebase Analytics
        Analytics.logEvent("match_created", parameters: [
            "user1_id": user1Id,
            "user2_id": user2Id
        ])
    }

    // MARK: - Photo Performance Tracking

    func trackPhotoInteraction(userId: String, photoIndex: Int, interactionType: PhotoInteractionType) async throws {
        let photoInteraction: [String: Any] = [
            "userId": userId,
            "photoIndex": photoIndex,
            "interactionType": interactionType.rawValue,
            "timestamp": Timestamp(date: Date())
        ]

        try await db.collection("photoInteractions").addDocument(data: photoInteraction)

        // Log to Firebase Analytics
        Analytics.logEvent("photo_interaction", parameters: [
            "user_id": userId,
            "photo_index": photoIndex,
            "interaction_type": interactionType.rawValue
        ])
    }

    // MARK: - Fetch Profile Insights

    func fetchProfileInsights(for userId: String) async throws -> ProfileInsights {
        var insights = ProfileInsights()

        // Fetch profile views (last 30 days)
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        // Total views
        let viewsSnapshot = try await db.collection("profileViews")
            .whereField("viewedUserId", isEqualTo: userId)
            .whereField("timestamp", isGreaterThan: Timestamp(date: thirtyDaysAgo))
            .getDocuments()

        insights.profileViews = viewsSnapshot.documents.count

        // This week's views
        let thisWeekViewsSnapshot = try await db.collection("profileViews")
            .whereField("viewedUserId", isEqualTo: userId)
            .whereField("timestamp", isGreaterThan: Timestamp(date: sevenDaysAgo))
            .getDocuments()

        insights.viewsThisWeek = thisWeekViewsSnapshot.documents.count

        // Last week's views
        let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let lastWeekViewsSnapshot = try await db.collection("profileViews")
            .whereField("viewedUserId", isEqualTo: userId)
            .whereField("timestamp", isGreaterThan: Timestamp(date: fourteenDaysAgo))
            .whereField("timestamp", isLessThan: Timestamp(date: sevenDaysAgo))
            .getDocuments()

        insights.viewsLastWeek = lastWeekViewsSnapshot.documents.count

        // Recent viewers (last 20)
        let viewersSnapshot = try await db.collection("profileViews")
            .whereField("viewedUserId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .limit(to: 20)
            .getDocuments()

        insights.profileViewers = try await fetchViewerDetails(from: viewersSnapshot)

        // Swipe statistics
        let swipesSnapshot = try await db.collection("swipeActions")
            .whereField("swipedUserId", isEqualTo: userId)
            .whereField("timestamp", isGreaterThan: Timestamp(date: thirtyDaysAgo))
            .getDocuments()

        insights.swipesReceived = swipesSnapshot.documents.count

        let likesCount = swipesSnapshot.documents.filter { doc in
            (doc.data()["direction"] as? String) == "right"
        }.count

        insights.likesReceived = likesCount

        if insights.swipesReceived > 0 {
            insights.likeRate = Double(likesCount) / Double(insights.swipesReceived)
        }

        // Fetch user data for match rate
        if let user = try? await fetchUser(userId: userId) {
            if user.likesReceived > 0 {
                insights.matchRate = Double(user.matchCount) / Double(user.likesReceived)
            }
        }

        // Photo performance
        insights.photoPerformance = try await fetchPhotoPerformance(for: userId)

        // Calculate profile score
        insights.profileScore = try await calculateProfileScore(for: userId)

        // Generate suggestions
        insights.suggestions = try await generateSuggestions(for: userId, insights: insights)

        return insights
    }

    // MARK: - Helper Methods

    private func fetchViewerDetails(from snapshot: QuerySnapshot) async throws -> [ProfileViewer] {
        var viewers: [ProfileViewer] = []

        for doc in snapshot.documents {
            let data = doc.data()
            guard let viewerUserId = data["viewerUserId"] as? String,
                  let timestamp = data["timestamp"] as? Timestamp else {
                continue
            }

            // Fetch viewer user data
            if let viewerUser = try? await fetchUser(userId: viewerUserId) {
                let viewer = ProfileViewer(
                    userId: viewerUserId,
                    userName: viewerUser.fullName,
                    userPhoto: viewerUser.profileImageURL,
                    viewedAt: timestamp.dateValue(),
                    isVerified: viewerUser.isVerified,
                    isPremium: viewerUser.isPremium
                )
                viewers.append(viewer)
            }
        }

        return viewers
    }

    private func fetchPhotoPerformance(for userId: String) async throws -> [PhotoPerformance] {
        // Get user's photos
        guard let user = try? await fetchUser(userId: userId) else {
            return []
        }

        var photoPerformanceList: [PhotoPerformance] = []

        for (index, photoURL) in user.photos.enumerated() {
            // Count interactions for this photo
            let interactionsSnapshot = try await db.collection("photoInteractions")
                .whereField("userId", isEqualTo: userId)
                .whereField("photoIndex", isEqualTo: index)
                .getDocuments()

            let views = interactionsSnapshot.documents.filter {
                ($0.data()["interactionType"] as? String) == "view"
            }.count

            let likes = interactionsSnapshot.documents.filter {
                ($0.data()["interactionType"] as? String) == "like"
            }.count

            let performance = PhotoPerformance(
                photoURL: photoURL,
                views: views,
                likes: likes,
                position: index
            )
            photoPerformanceList.append(performance)
        }

        return photoPerformanceList.sorted { $0.likes > $1.likes }
    }

    private func calculateProfileScore(for userId: String) async throws -> Int {
        guard let user = try? await fetchUser(userId: userId) else {
            return 0
        }

        var score = 40 // Base score

        // Photos (max 15 points)
        score += min(user.photos.count * 5, 15)

        // Bio (max 8 points)
        score += min(user.bio.count / 10, 8)

        // Prompts (max 15 points)
        score += user.prompts.count * 5

        // Interests (max 10 points)
        score += min(user.interests.count * 2, 10)

        // Verification (5 points)
        if user.isVerified {
            score += 5
        }

        // Languages (max 5 points)
        score += min(user.languages.count * 2, 5)

        // Recent activity (max 2 points)
        let daysSinceActive = Calendar.current.dateComponents([.day], from: user.lastActive, to: Date()).day ?? 999
        if daysSinceActive < 7 {
            score += 2
        }

        return min(score, 100)
    }

    private func generateSuggestions(for userId: String, insights: ProfileInsights) async throws -> [ProfileSuggestion] {
        var suggestions: [ProfileSuggestion] = []

        guard let user = try? await fetchUser(userId: userId) else {
            return suggestions
        }

        // Photos suggestions
        if user.photos.count < 3 {
            suggestions.append(ProfileSuggestion(
                title: "Add More Photos",
                description: "Profiles with 6+ photos get 3x more matches. Add \(6 - user.photos.count) more!",
                priority: .high,
                icon: "photo.fill"
            ))
        }

        // Bio suggestions
        if user.bio.isEmpty || user.bio.count < 50 {
            suggestions.append(ProfileSuggestion(
                title: "Complete Your Bio",
                description: "A detailed bio helps others connect with you better.",
                priority: .high,
                icon: "text.alignleft"
            ))
        }

        // Prompts suggestions
        if user.prompts.count < 3 {
            suggestions.append(ProfileSuggestion(
                title: "Answer Profile Prompts",
                description: "Prompts generate 2x more conversations. Add \(3 - user.prompts.count) more!",
                priority: .medium,
                icon: "bubble.left.and.bubble.right.fill"
            ))
        }

        // Verification
        if !user.isVerified {
            suggestions.append(ProfileSuggestion(
                title: "Get Verified",
                description: "Verified profiles are trusted more and get 40% more matches.",
                priority: .medium,
                icon: "checkmark.seal.fill"
            ))
        }

        // Activity
        let daysSinceActive = Calendar.current.dateComponents([.day], from: user.lastActive, to: Date()).day ?? 0
        if daysSinceActive > 7 {
            suggestions.append(ProfileSuggestion(
                title: "Stay Active",
                description: "Active users are shown more often. Open the app daily for better visibility.",
                priority: .low,
                icon: "chart.line.uptrend.xyaxis"
            ))
        }

        // Low view count
        if insights.viewsThisWeek < 10 {
            suggestions.append(ProfileSuggestion(
                title: "Boost Your Profile",
                description: "Your profile isn't getting many views. Try adjusting your photos or bio.",
                priority: .medium,
                icon: "bolt.fill"
            ))
        }

        return suggestions
    }

    private func fetchUser(userId: String) async throws -> User? {
        let doc = try await db.collection("users").document(userId).getDocument()
        guard let data = doc.data() else { return nil }
        return User(dictionary: data)
    }

    // MARK: - Privacy Controls

    func updateViewerTrackingPreference(userId: String, enabled: Bool) async throws {
        try await db.collection("users").document(userId).updateData([
            "allowViewerTracking": enabled
        ])
    }

    func deleteViewerHistory(userId: String) async throws {
        // Delete all profile views where user is the viewed user
        let snapshot = try await db.collection("profileViews")
            .whereField("viewedUserId", isEqualTo: userId)
            .getDocuments()

        for doc in snapshot.documents {
            try await doc.reference.delete()
        }
    }
}

// MARK: - Enums

enum SwipeDirection: String, Codable {
    case left = "left"
    case right = "right"
}

enum PhotoInteractionType: String, Codable {
    case view = "view"
    case like = "like"
    case skip = "skip"
}
