//
//  ProfileInsights.swift
//  Celestia
//
//  Profile analytics and insights data model
//

import Foundation

struct ProfileInsights: Codable {
    // View Analytics
    var profileViews: Int
    var viewsThisWeek: Int
    var viewsLastWeek: Int
    var profileViewers: [ProfileViewer]

    // Swipe Statistics
    var swipesReceived: Int
    var likesReceived: Int
    var passesReceived: Int
    var likeRate: Double

    // Engagement Metrics
    var matchCount: Int
    var matchRate: Double
    var responseRate: Double
    var averageResponseTime: TimeInterval

    // Photo Performance
    var photoPerformance: [PhotoPerformance]
    var bestPerformingPhoto: String?

    // Activity Insights
    var peakActivityHours: [Int]
    var lastActiveDate: Date
    var daysActive: Int

    // Suggestions
    var profileScore: Int
    var suggestions: [ProfileSuggestion]

    init() {
        self.profileViews = 0
        self.viewsThisWeek = 0
        self.viewsLastWeek = 0
        self.profileViewers = []
        self.swipesReceived = 0
        self.likesReceived = 0
        self.passesReceived = 0
        self.likeRate = 0.0
        self.matchCount = 0
        self.matchRate = 0.0
        self.responseRate = 0.0
        self.averageResponseTime = 0
        self.photoPerformance = []
        self.bestPerformingPhoto = nil
        self.peakActivityHours = []
        self.lastActiveDate = Date()
        self.daysActive = 0
        self.profileScore = 0
        self.suggestions = []
    }
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
