//
//  ReviewPromptManager.swift
//  Celestia
//
//  Smart app review prompt manager that shows review prompts at optimal times
//  Uses iOS StoreKit to request reviews when users have positive experiences
//

import Foundation
import StoreKit
import SwiftUI

// MARK: - Review Prompt Manager

@MainActor
class ReviewPromptManager: ObservableObject {

    // MARK: - Singleton

    static let shared = ReviewPromptManager()

    // MARK: - Published Properties

    @Published var canShowReviewPrompt: Bool = false

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let firstLaunchDate = "review_first_launch_date"
        static let lastReviewPromptDate = "review_last_prompt_date"
        static let reviewPromptCount = "review_prompt_count"
        static let hasRatedApp = "review_has_rated_app"
        static let significantEventCount = "review_significant_events"
        static let matchCount = "review_match_count"
        static let messagesSent = "review_messages_sent"
        static let sessionsCount = "review_sessions_count"
        static let premiumPurchased = "review_premium_purchased"
    }

    // MARK: - Configuration

    private let minimumDaysSinceFirstLaunch = 7 // Wait at least 7 days after first launch
    private let minimumDaysBetweenPrompts = 90 // Wait at least 90 days between prompts
    private let maximumPromptsPerYear = 3 // Maximum 3 prompts per year
    private let minimumSignificantEvents = 5 // Require at least 5 significant events
    private let minimumMatches = 3 // At least 3 matches
    private let minimumMessagesSent = 10 // At least 10 messages sent
    private let minimumSessions = 15 // At least 15 app sessions

    // MARK: - Initialization

    private init() {
        setupFirstLaunchDateIfNeeded()
        updateCanShowPrompt()
    }

    // MARK: - Public Methods

    /// Request app review if conditions are met
    func requestReviewIfAppropriate() {
        guard canShowReviewPrompt else {
            Logger.shared.debug("Review prompt conditions not met", category: .general)
            return
        }

        // Request review using StoreKit
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)

            // Update tracking
            recordReviewPromptShown()

            // Track analytics
            AnalyticsManager.shared.logEvent(.reviewPromptShown, parameters: [
                "days_since_first_launch": daysSinceFirstLaunch(),
                "matches": getMatchCount(),
                "messages_sent": getMessagesSent(),
                "sessions": getSessionsCount()
            ])

            Logger.shared.info("Review prompt shown to user", category: .general)
        }
    }

    /// Manually request review (for settings/feedback section)
    func requestReviewManually() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)

            AnalyticsManager.shared.logEvent(.reviewPromptManual, parameters: [:])
        }
    }

    /// Record that user has rated the app externally
    func markAppAsRated() {
        UserDefaults.standard.set(true, forKey: Keys.hasRatedApp)
        updateCanShowPrompt()

        Logger.shared.info("User marked as having rated the app", category: .general)
    }

    /// Increment session count (call on app launch)
    func incrementSessionCount() {
        let currentCount = getSessionsCount()
        UserDefaults.standard.set(currentCount + 1, forKey: Keys.sessionsCount)
        updateCanShowPrompt()
    }

    /// Record significant positive event
    func recordSignificantEvent(_ event: SignificantEvent) {
        let currentCount = getSignificantEventCount()
        UserDefaults.standard.set(currentCount + 1, forKey: Keys.significantEventCount)

        // Update specific counters based on event type
        switch event {
        case .newMatch:
            incrementMatchCount()
        case .messageSent:
            incrementMessagesSent()
        case .premiumPurchased:
            UserDefaults.standard.set(true, forKey: Keys.premiumPurchased)
        case .profileCompleted, .photoAdded, .conversationStarted, .dateShared:
            break // These just increment the general counter
        }

        updateCanShowPrompt()

        // Check if we should show review prompt after this event
        checkAndShowReviewPromptAfterEvent(event)
    }

    // MARK: - Private Methods

    private func setupFirstLaunchDateIfNeeded() {
        if UserDefaults.standard.object(forKey: Keys.firstLaunchDate) == nil {
            UserDefaults.standard.set(Date(), forKey: Keys.firstLaunchDate)
        }
    }

    private func updateCanShowPrompt() {
        // Check all conditions
        let hasNotRated = !hasRatedApp()
        let enoughDaysSinceFirstLaunch = daysSinceFirstLaunch() >= minimumDaysSinceFirstLaunch
        let enoughDaysSinceLastPrompt = daysSinceLastPrompt() >= minimumDaysBetweenPrompts || daysSinceLastPrompt() == -1
        let notTooManyPrompts = getPromptCount() < maximumPromptsPerYear
        let enoughSignificantEvents = getSignificantEventCount() >= minimumSignificantEvents
        let enoughMatches = getMatchCount() >= minimumMatches
        let enoughMessages = getMessagesSent() >= minimumMessagesSent
        let enoughSessions = getSessionsCount() >= minimumSessions

        canShowReviewPrompt = hasNotRated &&
                              enoughDaysSinceFirstLaunch &&
                              enoughDaysSinceLastPrompt &&
                              notTooManyPrompts &&
                              enoughSignificantEvents &&
                              enoughMatches &&
                              enoughMessages &&
                              enoughSessions

        Logger.shared.debug("""
            Review prompt eligibility:
            - Not rated: \(hasNotRated)
            - Days since first launch: \(daysSinceFirstLaunch()) (need \(minimumDaysSinceFirstLaunch))
            - Days since last prompt: \(daysSinceLastPrompt()) (need \(minimumDaysBetweenPrompts))
            - Prompt count: \(getPromptCount()) (max \(maximumPromptsPerYear))
            - Significant events: \(getSignificantEventCount()) (need \(minimumSignificantEvents))
            - Matches: \(getMatchCount()) (need \(minimumMatches))
            - Messages: \(getMessagesSent()) (need \(minimumMessagesSent))
            - Sessions: \(getSessionsCount()) (need \(minimumSessions))
            - Can show: \(canShowReviewPrompt)
            """, category: .general)
    }

    private func recordReviewPromptShown() {
        let currentCount = getPromptCount()
        UserDefaults.standard.set(currentCount + 1, forKey: Keys.reviewPromptCount)
        UserDefaults.standard.set(Date(), forKey: Keys.lastReviewPromptDate)
        updateCanShowPrompt()
    }

    private func checkAndShowReviewPromptAfterEvent(_ event: SignificantEvent) {
        // Only show prompts after highly positive events
        let positiveEvents: [SignificantEvent] = [.newMatch, .conversationStarted, .premiumPurchased]

        guard positiveEvents.contains(event) else { return }

        // Add small delay to make it feel more natural
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            requestReviewIfAppropriate()
        }
    }

    // MARK: - Getters

    private func daysSinceFirstLaunch() -> Int {
        guard let firstLaunchDate = UserDefaults.standard.object(forKey: Keys.firstLaunchDate) as? Date else {
            return 0
        }
        return Calendar.current.dateComponents([.day], from: firstLaunchDate, to: Date()).day ?? 0
    }

    private func daysSinceLastPrompt() -> Int {
        guard let lastPromptDate = UserDefaults.standard.object(forKey: Keys.lastReviewPromptDate) as? Date else {
            return -1 // Never shown
        }
        return Calendar.current.dateComponents([.day], from: lastPromptDate, to: Date()).day ?? 0
    }

    private func getPromptCount() -> Int {
        return UserDefaults.standard.integer(forKey: Keys.reviewPromptCount)
    }

    private func hasRatedApp() -> Bool {
        return UserDefaults.standard.bool(forKey: Keys.hasRatedApp)
    }

    private func getSignificantEventCount() -> Int {
        return UserDefaults.standard.integer(forKey: Keys.significantEventCount)
    }

    private func getMatchCount() -> Int {
        return UserDefaults.standard.integer(forKey: Keys.matchCount)
    }

    private func getMessagesSent() -> Int {
        return UserDefaults.standard.integer(forKey: Keys.messagesSent)
    }

    private func getSessionsCount() -> Int {
        return UserDefaults.standard.integer(forKey: Keys.sessionsCount)
    }

    private func incrementMatchCount() {
        let currentCount = getMatchCount()
        UserDefaults.standard.set(currentCount + 1, forKey: Keys.matchCount)
    }

    private func incrementMessagesSent() {
        let currentCount = getMessagesSent()
        UserDefaults.standard.set(currentCount + 1, forKey: Keys.messagesSent)
    }

    // MARK: - Reset (for testing)

    func resetAllData() {
        UserDefaults.standard.removeObject(forKey: Keys.firstLaunchDate)
        UserDefaults.standard.removeObject(forKey: Keys.lastReviewPromptDate)
        UserDefaults.standard.removeObject(forKey: Keys.reviewPromptCount)
        UserDefaults.standard.removeObject(forKey: Keys.hasRatedApp)
        UserDefaults.standard.removeObject(forKey: Keys.significantEventCount)
        UserDefaults.standard.removeObject(forKey: Keys.matchCount)
        UserDefaults.standard.removeObject(forKey: Keys.messagesSent)
        UserDefaults.standard.removeObject(forKey: Keys.sessionsCount)
        UserDefaults.standard.removeObject(forKey: Keys.premiumPurchased)

        setupFirstLaunchDateIfNeeded()
        updateCanShowPrompt()

        Logger.shared.info("Review prompt data reset", category: .general)
    }
}

// MARK: - Significant Event

enum SignificantEvent: String {
    case newMatch
    case messageSent
    case conversationStarted
    case premiumPurchased
    case profileCompleted
    case photoAdded
    case dateShared

    var description: String {
        switch self {
        case .newMatch:
            return "User got a new match"
        case .messageSent:
            return "User sent a message"
        case .conversationStarted:
            return "User started a conversation"
        case .premiumPurchased:
            return "User purchased premium"
        case .profileCompleted:
            return "User completed their profile"
        case .photoAdded:
            return "User added a photo"
        case .dateShared:
            return "User shared date details"
        }
    }
}

// MARK: - Review Prompt Button (SwiftUI Component)

struct ReviewPromptButton: View {
    @StateObject private var reviewManager = ReviewPromptManager.shared

    var body: some View {
        Button(action: {
            reviewManager.requestReviewManually()
        }) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Rate Celestia")
                    .font(.body)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - Integration Examples

extension ReviewPromptManager {

    /// Example: Call when user gets a new match
    func onNewMatchReceived() {
        recordSignificantEvent(.newMatch)
    }

    /// Example: Call when user sends their first message to a match
    func onFirstMessageSent() {
        recordSignificantEvent(.conversationStarted)
        recordSignificantEvent(.messageSent)
    }

    /// Example: Call when user sends any message
    func onMessageSent() {
        recordSignificantEvent(.messageSent)
    }

    /// Example: Call when user purchases premium
    func onPremiumPurchased() {
        recordSignificantEvent(.premiumPurchased)
    }

    /// Example: Call when user completes their profile
    func onProfileCompleted() {
        recordSignificantEvent(.profileCompleted)
    }

    /// Example: Call when user adds a photo
    func onPhotoAdded() {
        recordSignificantEvent(.photoAdded)
    }

    /// Example: Call when user shares date details
    func onDateShared() {
        recordSignificantEvent(.dateShared)
    }
}

// MARK: - App Delegate Integration

/*
 To integrate with AppDelegate or App struct:

 @main
 struct CelestiaApp: App {
     @StateObject private var reviewManager = ReviewPromptManager.shared

     init() {
         // Increment session count on app launch
         Task { @MainActor in
             ReviewPromptManager.shared.incrementSessionCount()
         }
     }

     var body: some Scene {
         WindowGroup {
             ContentView()
         }
     }
 }
 */
