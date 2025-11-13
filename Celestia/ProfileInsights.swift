//
//  ProfileInsights.swift
//  Celestia
//
//  Profile analytics and insights data model
//

import Foundation

struct ProfileInsights: Codable {
    // View Analytics
    var profileViews: Int = 0
    var viewsThisWeek: Int = 0
    var viewsLastWeek: Int = 0
    var profileViewers: [ProfileViewer] = []

    // Swipe Statistics
    var swipesReceived: Int = 0
    var likesReceived: Int = 0
    var passesReceived: Int = 0
    var likeRate: Double = 0.0

    // Engagement Metrics
    var matchCount: Int = 0
    var matchRate: Double = 0.0
    var responseRate: Double = 0.0
    var averageResponseTime: TimeInterval = 0

    // Photo Performance
    var photoPerformance: [PhotoPerformance] = []
    var bestPerformingPhoto: String?

    // Activity Insights
    var peakActivityHours: [Int] = []
    var lastActiveDate: Date = Date()
    var daysActive: Int = 0

    // Suggestions
    var profileScore: Int = 0
    var suggestions: [ProfileSuggestion] = []
}

struct ProfileViewer: Codable, Identifiable {
    var id: String
    var userId: String
    var userName: String
    var userPhoto: String
    var viewedAt: Date
    var isVerified: Bool
    var isPremium: Bool
}

struct PhotoPerformance: Codable, Identifiable {
    var id: String
    var photoURL: String
    var views: Int
    var likes: Int
    var swipeRightRate: Double
    var position: Int
}

struct ProfileSuggestion: Codable, Identifiable {
    var id: String
    var title: String
    var description: String
    var priority: SuggestionPriority
    var category: SuggestionCategory
    var actionType: SuggestionAction
}

enum SuggestionPriority: String, Codable {
    case high = "high"
    case medium = "medium"
    case low = "low"
}

enum SuggestionCategory: String, Codable {
    case photos = "photos"
    case bio = "bio"
    case interests = "interests"
    case verification = "verification"
    case activity = "activity"
}

enum SuggestionAction: String, Codable {
    case addPhotos = "addPhotos"
    case improveBio = "improveBio"
    case addInterests = "addInterests"
    case getVerified = "getVerified"
    case updateProfilePicture = "updateProfilePicture"
    case beMoreActive = "beMoreActive"
}
