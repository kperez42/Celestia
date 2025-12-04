//
//  ActivationMetrics.swift
//  Celestia
//
//  Tracks user activation and engagement metrics
//  Measures onboarding completion, time to first match, and D1 retention
//

import Foundation
import SwiftUI

/// Activation metrics tracker for measuring user engagement
@MainActor
class ActivationMetrics: ObservableObject {

    static let shared = ActivationMetrics()

    @Published var currentMetrics: UserActivationMetrics?
    @Published var milestones: [ActivationMilestone] = []

    private let metricsKey = "user_activation_metrics"
    private let milestonesKey = "activation_milestones"

    //MARK: - Models

    struct UserActivationMetrics: Codable {
        var userId: String
        var signupDate: Date
        var profileCompletedDate: Date?
        var firstSwipeDate: Date?
        var firstLikeDate: Date?
        var firstMatchDate: Date?
        var firstMessageDate: Date?
        var firstReplyDate: Date?

        // Profile completion tracking
        var hasProfilePhoto: Bool = false
        var profilePhotoCount: Int = 0
        var hasBio: Bool = false
        var bioLength: Int = 0
        var hasInterests: Bool = false
        var interestCount: Int = 0
        var hasLocation: Bool = false
        var hasVerifiedProfile: Bool = false

        // Engagement tracking
        var totalSwipes: Int = 0
        var totalLikes: Int = 0
        var totalMatches: Int = 0
        var totalMessages: Int = 0
        var totalConversations: Int = 0

        // Session tracking
        var sessionCount: Int = 0
        var lastSessionDate: Date?
        var totalTimeSpentMinutes: Int = 0

        // Computed metrics
        var profileCompletionPercentage: Double {
            var completed = 0.0
            let total = 7.0

            if hasProfilePhoto { completed += 1 }
            if profilePhotoCount >= 3 { completed += 1 }
            if hasBio { completed += 1 }
            if bioLength >= 100 { completed += 1 }
            if hasInterests { completed += 1 }
            if hasLocation { completed += 1 }
            if hasVerifiedProfile { completed += 1 }

            return (completed / total) * 100
        }

        var timeToFirstMatch: TimeInterval? {
            guard let firstMatch = firstMatchDate else { return nil }
            return firstMatch.timeIntervalSince(signupDate)
        }

        var timeToProfileCompletion: TimeInterval? {
            guard let completed = profileCompletedDate else { return nil }
            return completed.timeIntervalSince(signupDate)
        }

        var daysSinceSignup: Int {
            Calendar.current.dateComponents([.day], from: signupDate, to: Date()).day ?? 0
        }

        var isD1Retained: Bool {
            guard let lastSession = lastSessionDate else { return false }
            let daysSinceSignup = Calendar.current.dateComponents([.day], from: signupDate, to: Date()).day ?? 0
            let daysSinceLastSession = Calendar.current.dateComponents([.day], from: lastSession, to: Date()).day ?? 0

            return daysSinceSignup >= 1 && daysSinceLastSession == 0
        }

        var isD7Retained: Bool {
            guard let lastSession = lastSessionDate else { return false }
            let daysSinceSignup = Calendar.current.dateComponents([.day], from: signupDate, to: Date()).day ?? 0
            let daysSinceLastSession = Calendar.current.dateComponents([.day], from: lastSession, to: Date()).day ?? 0

            return daysSinceSignup >= 7 && daysSinceLastSession <= 1
        }

        var activationScore: Double {
            var score = 0.0

            // Profile completion (40 points)
            score += profileCompletionPercentage * 0.4

            // Engagement actions (30 points)
            if firstSwipeDate != nil { score += 5 }
            if firstLikeDate != nil { score += 5 }
            if firstMatchDate != nil { score += 10 }
            if firstMessageDate != nil { score += 5 }
            if firstReplyDate != nil { score += 5 }

            // Activity levels (30 points)
            if totalMatches > 0 { score += 10 }
            if totalMessages > 5 { score += 10 }
            if sessionCount > 3 { score += 10 }

            return min(score, 100)
        }

        var activationLevel: ActivationLevel {
            switch activationScore {
            case 0..<20:
                return .new
            case 20..<40:
                return .exploring
            case 40..<60:
                return .engaged
            case 60..<80:
                return .active
            default:
                return .powerUser
            }
        }
    }

    enum ActivationLevel: String {
        case new = "New User"
        case exploring = "Exploring"
        case engaged = "Engaged"
        case active = "Active"
        case powerUser = "Power User"

        var color: Color {
            switch self {
            case .new: return .gray
            case .exploring: return .blue
            case .engaged: return .green
            case .active: return .orange
            case .powerUser: return .purple
            }
        }

        var icon: String {
            switch self {
            case .new: return "person.badge.plus"
            case .exploring: return "eye"
            case .engaged: return "hand.thumbsup"
            case .active: return "flame"
            case .powerUser: return "star.fill"
            }
        }
    }

    struct ActivationMilestone: Identifiable, Codable {
        let id: String
        let title: String
        let description: String
        let achievedDate: Date
        let category: MilestoneCategory
        let rewardPoints: Int

        enum MilestoneCategory: String, Codable {
            case profile
            case discovery
            case matching
            case messaging
            case engagement
        }
    }

    // MARK: - Initialization

    init() {
        loadMetrics()
        loadMilestones()
    }

    // MARK: - Event Tracking

    func trackSignup(userId: String) {
        currentMetrics = UserActivationMetrics(userId: userId, signupDate: Date())
        saveMetrics()

        // Track in analytics
        AnalyticsServiceEnhanced.shared.trackEvent(.userSignup, properties: [
            "user_id": userId,
            "signup_date": ISO8601DateFormatter().string(from: Date())
        ])
    }

    func trackProfileUpdate(user: User) {
        guard var metrics = currentMetrics else { return }

        let wasIncomplete = metrics.profileCompletionPercentage < 70

        // Update profile metrics
        metrics.hasProfilePhoto = !user.profileImageURL.isEmpty
        metrics.profilePhotoCount = user.photos.count + (user.profileImageURL.isEmpty ? 0 : 1)
        metrics.hasBio = !user.bio.isEmpty
        metrics.bioLength = user.bio.count
        metrics.hasInterests = !user.interests.isEmpty
        metrics.interestCount = user.interests.count
        metrics.hasLocation = !user.location.isEmpty
        metrics.hasVerifiedProfile = user.isVerified

        // Check if profile just became complete
        if wasIncomplete && metrics.profileCompletionPercentage >= 70 {
            metrics.profileCompletedDate = Date()
            checkMilestone(.profileComplete)

            // Track analytics
            AnalyticsServiceEnhanced.shared.trackEvent(.profileCompleted, properties: [
                "user_id": metrics.userId,
                "completion_percentage": metrics.profileCompletionPercentage,
                "time_to_complete": metrics.timeToProfileCompletion ?? 0
            ])
        }

        currentMetrics = metrics
        saveMetrics()
    }

    func trackFirstSwipe() {
        guard var metrics = currentMetrics else { return }

        if metrics.firstSwipeDate == nil {
            metrics.firstSwipeDate = Date()
            checkMilestone(.firstSwipe)
        }

        metrics.totalSwipes += 1
        currentMetrics = metrics
        saveMetrics()
    }

    func trackLike() {
        guard var metrics = currentMetrics else { return }

        if metrics.firstLikeDate == nil {
            metrics.firstLikeDate = Date()
            checkMilestone(.firstLike)
        }

        metrics.totalLikes += 1
        currentMetrics = metrics
        saveMetrics()
    }

    func trackMatch() {
        guard var metrics = currentMetrics else { return }

        if metrics.firstMatchDate == nil {
            metrics.firstMatchDate = Date()
            checkMilestone(.firstMatch)

            // Track time to first match
            if let timeToMatch = metrics.timeToFirstMatch {
                AnalyticsServiceEnhanced.shared.trackEvent(.firstMatch, properties: [
                    "user_id": metrics.userId,
                    "time_to_match_seconds": timeToMatch,
                    "time_to_match_hours": timeToMatch / 3600
                ])
            }
        }

        metrics.totalMatches += 1

        // Check for milestone matches
        if metrics.totalMatches == 5 {
            checkMilestone(.fiveMatches)
        } else if metrics.totalMatches == 10 {
            checkMilestone(.tenMatches)
        }

        currentMetrics = metrics
        saveMetrics()
    }

    func trackMessage(isFirstInConversation: Bool = false) {
        guard var metrics = currentMetrics else { return }

        if metrics.firstMessageDate == nil {
            metrics.firstMessageDate = Date()
            checkMilestone(.firstMessage)
        }

        metrics.totalMessages += 1

        if isFirstInConversation {
            metrics.totalConversations += 1
        }

        currentMetrics = metrics
        saveMetrics()
    }

    func trackReply() {
        guard var metrics = currentMetrics else { return }

        if metrics.firstReplyDate == nil {
            metrics.firstReplyDate = Date()
            checkMilestone(.firstReply)
        }

        currentMetrics = metrics
        saveMetrics()
    }

    func trackSession(durationMinutes: Int = 0) {
        guard var metrics = currentMetrics else { return }

        metrics.sessionCount += 1
        metrics.lastSessionDate = Date()
        metrics.totalTimeSpentMinutes += durationMinutes

        // Check D1 retention
        if metrics.daysSinceSignup == 1 && metrics.isD1Retained {
            checkMilestone(.d1Retained)
        }

        // Check D7 retention
        if metrics.daysSinceSignup == 7 && metrics.isD7Retained {
            checkMilestone(.d7Retained)
        }

        currentMetrics = metrics
        saveMetrics()
    }

    // MARK: - Milestone System

    private func checkMilestone(_ milestone: PredefinedMilestone) {
        // Check if milestone already achieved
        if milestones.contains(where: { $0.id == milestone.rawValue }) {
            return
        }

        let newMilestone = createMilestone(milestone)
        milestones.append(newMilestone)
        saveMilestones()

        // Track in analytics
        AnalyticsServiceEnhanced.shared.trackEvent(.milestoneAchieved, properties: [
            "milestone_id": milestone.rawValue,
            "milestone_title": newMilestone.title,
            "reward_points": newMilestone.rewardPoints
        ])

        // Notify user
        NotificationCenter.default.post(
            name: .milestoneAchieved,
            object: nil,
            userInfo: ["milestone": newMilestone]
        )
    }

    private func createMilestone(_ milestone: PredefinedMilestone) -> ActivationMilestone {
        switch milestone {
        case .profileComplete:
            return ActivationMilestone(
                id: milestone.rawValue,
                title: "Profile Complete! 🎉",
                description: "You've completed your profile",
                achievedDate: Date(),
                category: .profile,
                rewardPoints: 100
            )

        case .firstSwipe:
            return ActivationMilestone(
                id: milestone.rawValue,
                title: "First Swipe!",
                description: "You've started discovering people",
                achievedDate: Date(),
                category: .discovery,
                rewardPoints: 10
            )

        case .firstLike:
            return ActivationMilestone(
                id: milestone.rawValue,
                title: "First Like! ❤️",
                description: "You liked someone",
                achievedDate: Date(),
                category: .discovery,
                rewardPoints: 20
            )

        case .firstMatch:
            return ActivationMilestone(
                id: milestone.rawValue,
                title: "First Match! 🌟",
                description: "Someone likes you back!",
                achievedDate: Date(),
                category: .matching,
                rewardPoints: 50
            )

        case .firstMessage:
            return ActivationMilestone(
                id: milestone.rawValue,
                title: "First Message! 💬",
                description: "You've started a conversation",
                achievedDate: Date(),
                category: .messaging,
                rewardPoints: 30
            )

        case .firstReply:
            return ActivationMilestone(
                id: milestone.rawValue,
                title: "First Reply! 🎊",
                description: "Someone replied to your message",
                achievedDate: Date(),
                category: .messaging,
                rewardPoints: 40
            )

        case .fiveMatches:
            return ActivationMilestone(
                id: milestone.rawValue,
                title: "5 Matches! 🔥",
                description: "You're on a roll!",
                achievedDate: Date(),
                category: .matching,
                rewardPoints: 75
            )

        case .tenMatches:
            return ActivationMilestone(
                id: milestone.rawValue,
                title: "10 Matches! 🚀",
                description: "You're a matching pro!",
                achievedDate: Date(),
                category: .matching,
                rewardPoints: 150
            )

        case .d1Retained:
            return ActivationMilestone(
                id: milestone.rawValue,
                title: "Day 1 Complete! ✅",
                description: "You came back!",
                achievedDate: Date(),
                category: .engagement,
                rewardPoints: 100
            )

        case .d7Retained:
            return ActivationMilestone(
                id: milestone.rawValue,
                title: "Week 1 Complete! 🎖️",
                description: "You're becoming a regular!",
                achievedDate: Date(),
                category: .engagement,
                rewardPoints: 200
            )
        }
    }

    enum PredefinedMilestone: String {
        case profileComplete
        case firstSwipe
        case firstLike
        case firstMatch
        case firstMessage
        case firstReply
        case fiveMatches
        case tenMatches
        case d1Retained
        case d7Retained
    }

    // MARK: - Analytics

    func getActivationReport() -> ActivationReport? {
        guard let metrics = currentMetrics else { return nil }

        return ActivationReport(
            userId: metrics.userId,
            signupDate: metrics.signupDate,
            profileCompletion: metrics.profileCompletionPercentage,
            timeToFirstMatch: metrics.timeToFirstMatch,
            timeToProfileCompletion: metrics.timeToProfileCompletion,
            totalMatches: metrics.totalMatches,
            totalMessages: metrics.totalMessages,
            activationScore: metrics.activationScore,
            activationLevel: metrics.activationLevel,
            isD1Retained: metrics.isD1Retained,
            isD7Retained: metrics.isD7Retained,
            milestoneCount: milestones.count
        )
    }

    struct ActivationReport {
        let userId: String
        let signupDate: Date
        let profileCompletion: Double
        let timeToFirstMatch: TimeInterval?
        let timeToProfileCompletion: TimeInterval?
        let totalMatches: Int
        let totalMessages: Int
        let activationScore: Double
        let activationLevel: ActivationLevel
        let isD1Retained: Bool
        let isD7Retained: Bool
        let milestoneCount: Int
    }

    // MARK: - Persistence

    private func loadMetrics() {
        if let data = UserDefaults.standard.data(forKey: metricsKey),
           let decoded = try? JSONDecoder().decode(UserActivationMetrics.self, from: data) {
            currentMetrics = decoded
        }
    }

    private func saveMetrics() {
        if let metrics = currentMetrics,
           let encoded = try? JSONEncoder().encode(metrics) {
            UserDefaults.standard.set(encoded, forKey: metricsKey)
        }
    }

    private func loadMilestones() {
        if let data = UserDefaults.standard.data(forKey: milestonesKey),
           let decoded = try? JSONDecoder().decode([ActivationMilestone].self, from: data) {
            milestones = decoded
        }
    }

    private func saveMilestones() {
        if let encoded = try? JSONEncoder().encode(milestones) {
            UserDefaults.standard.set(encoded, forKey: milestonesKey)
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let milestoneAchieved = Notification.Name("milestoneAchieved")
}

// MARK: - SwiftUI View for Activation Dashboard

struct ActivationDashboardView: View {
    @ObservedObject var activationMetrics = ActivationMetrics.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let metrics = activationMetrics.currentMetrics {
                    // Activation Level Card
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: metrics.activationLevel.icon)
                                .font(.title2)
                                .foregroundColor(metrics.activationLevel.color)

                            VStack(alignment: .leading) {
                                Text(metrics.activationLevel.rawValue)
                                    .font(.headline)

                                Text("Activation Score: \(Int(metrics.activationScore))/100")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        .padding()
                        .background(metrics.activationLevel.color.opacity(0.1))
                        .cornerRadius(12)

                        // Stats Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            StatCard(title: "Matches", value: "\(metrics.totalMatches)", icon: "heart.fill", color: .red)
                            StatCard(title: "Messages", value: "\(metrics.totalMessages)", icon: "message.fill", color: .blue)
                            StatCard(title: "Sessions", value: "\(metrics.sessionCount)", icon: "clock.fill", color: .green)
                            StatCard(title: "Profile", value: "\(Int(metrics.profileCompletionPercentage))%", icon: "person.fill", color: .purple)
                        }
                    }

                    // Recent Milestones
                    if !activationMetrics.milestones.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Milestones")
                                .font(.headline)

                            ForEach(activationMetrics.milestones.prefix(5)) { milestone in
                                HStack {
                                    Text(milestone.title)
                                        .font(.subheadline)

                                    Spacer()

                                    Text("+\(milestone.rewardPoints)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}
