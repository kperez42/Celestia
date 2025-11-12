//
//  AnalyticsManager.swift
//  Celestia
//
//  Advanced analytics system for tracking user behavior and app performance
//  Integrates with Firebase Analytics, Crashlytics, and custom tracking
//

import Foundation
import FirebaseAnalytics
import FirebaseCrashlytics

// MARK: - Analytics Manager

@MainActor
class AnalyticsManager: ObservableObject, AnalyticsManagerProtocol {

    // MARK: - Singleton

    static let shared = AnalyticsManager()

    // MARK: - Properties

    private var sessionStartTime: Date?
    private var currentScreen: String?
    private var userProperties: [String: Any] = [:]
    private var eventQueue: [AnalyticsEventData] = []

    // MARK: - Configuration

    private let maxQueueSize = 100
    private let flushInterval: TimeInterval = 30.0

    // MARK: - Initialization

    private init() {
        Logger.shared.info("AnalyticsManager initialized", category: .analytics)
        startSession()
        setupPeriodicFlush()
    }

    // MARK: - Session Management

    func startSession() {
        sessionStartTime = Date()
        logEvent(.sessionStart)
        Logger.shared.info("Analytics session started", category: .analytics)
    }

    func endSession() {
        guard let startTime = sessionStartTime else { return }

        let duration = Date().timeIntervalSince(startTime)
        logEvent(.sessionEnd, parameters: [
            "duration": duration
        ])

        Logger.shared.info("Analytics session ended: \(duration)s", category: .analytics)
        sessionStartTime = nil
    }

    // MARK: - Event Tracking

    /// Log a custom event
    func logEvent(_ event: AnalyticsEvent, parameters: [String: Any]? = nil) {
        var params = event.defaultParameters
        if let additionalParams = parameters {
            params.merge(additionalParams) { _, new in new }
        }

        // Log to Firebase Analytics
        Analytics.logEvent(event.name, parameters: params)

        // Log to Crashlytics for context
        Crashlytics.crashlytics().log("\(event.name): \(params)")

        // Log to console
        Logger.shared.info("Event: \(event.name) \(params)", category: .analytics)

        // Queue event for batch processing
        queueEvent(event, parameters: params)
    }

    /// Log screen view
    func logScreenView(_ screenName: String, screenClass: String? = nil) {
        currentScreen = screenName

        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass ?? screenName
        ])

        Logger.shared.debug("Screen view: \(screenName)", category: .analytics)
    }

    // MARK: - User Properties

    /// Set user property
    func setUserProperty(_ value: String?, forName name: String) {
        userProperties[name] = value
        Analytics.setUserProperty(value, forName: name)
        Crashlytics.crashlytics().setCustomValue(value ?? "", forKey: name)

        Logger.shared.debug("User property: \(name) = \(value ?? "nil")", category: .analytics)
    }

    /// Set user ID
    func setUserId(_ userId: String?) {
        Analytics.setUserID(userId)
        Crashlytics.crashlytics().setUserID(userId ?? "")
        setUserProperty(userId, forName: "user_id")
    }

    /// Set multiple user properties
    func setUserProperties(_ properties: [String: String]) {
        for (key, value) in properties {
            setUserProperty(value, forName: key)
        }
    }

    // MARK: - E-commerce Tracking

    /// Track purchase event
    func trackPurchase(
        transactionId: String,
        productId: String,
        productName: String,
        price: Double,
        currency: String = "USD"
    ) {
        logEvent(.purchase, parameters: [
            AnalyticsParameterTransactionID: transactionId,
            AnalyticsParameterItemID: productId,
            AnalyticsParameterItemName: productName,
            AnalyticsParameterPrice: price,
            AnalyticsParameterCurrency: currency
        ])

        CrashlyticsManager.shared.logEvent("purchase", parameters: [
            "product": productName,
            "price": price
        ])
    }

    /// Track refund
    func trackRefund(transactionId: String, value: Double, currency: String = "USD") {
        logEvent(.refund, parameters: [
            AnalyticsParameterTransactionID: transactionId,
            AnalyticsParameterValue: value,
            AnalyticsParameterCurrency: currency
        ])
    }

    // MARK: - User Engagement

    /// Track user engagement time
    func trackEngagement(duration: TimeInterval, screen: String) {
        logEvent(.engagement, parameters: [
            "duration": duration,
            "screen": screen
        ])
    }

    /// Track feature usage
    func trackFeatureUsage(_ featureName: String, action: String? = nil) {
        logEvent(.featureUsed, parameters: [
            "feature": featureName,
            "action": action ?? "used"
        ])
    }

    // MARK: - Funnel Tracking

    /// Track funnel step
    func trackFunnelStep(_ funnel: AnalyticsFunnel, step: Int, stepName: String) {
        logEvent(.funnelStep, parameters: [
            "funnel": funnel.rawValue,
            "step": step,
            "step_name": stepName
        ])
    }

    /// Track funnel completion
    func trackFunnelCompletion(_ funnel: AnalyticsFunnel, duration: TimeInterval) {
        logEvent(.funnelCompleted, parameters: [
            "funnel": funnel.rawValue,
            "duration": duration
        ])
    }

    /// Track funnel abandonment
    func trackFunnelAbandonment(_ funnel: AnalyticsFunnel, step: Int, reason: String?) {
        logEvent(.funnelAbandoned, parameters: [
            "funnel": funnel.rawValue,
            "step": step,
            "reason": reason ?? "unknown"
        ])
    }

    // MARK: - Social Features

    /// Track match event
    func trackMatch(matchId: String, userId: String) {
        logEvent(.match, parameters: [
            "match_id": matchId,
            "user_id": userId
        ])
    }

    /// Track match between two users
    func trackMatch(user1Id: String, user2Id: String) async throws {
        logEvent(.match, parameters: [
            "user1_id": user1Id,
            "user2_id": user2Id
        ])
    }

    /// Track message sent
    func trackMessageSent(matchId: String, messageLength: Int, hasMedia: Bool) {
        logEvent(.messageSent, parameters: [
            "match_id": matchId,
            "length": messageLength,
            "has_media": hasMedia
        ])
    }

    /// Track swipe action
    func trackSwipe(action: AnalyticsSwipeAction, userId: String) {
        logEvent(.swipe, parameters: [
            "action": action.rawValue,
            "user_id": userId
        ])
    }

    /// Track swipe with direction
    func trackSwipe(swipedUserId: String, swiperUserId: String, direction: AnalyticsSwipeDirection) async throws {
        let action: AnalyticsSwipeAction
        switch direction {
        case .right:
            action = .like
        case .left:
            action = .dislike
        case .up:
            action = .superLike
        }

        logEvent(.swipe, parameters: [
            "action": action.rawValue,
            "swiped_user_id": swipedUserId,
            "swiper_user_id": swiperUserId,
            "direction": direction.rawValue
        ])
    }

    /// Track profile view
    func trackProfileView(viewedUserId: String, viewerUserId: String) async throws {
        logEvent(.profileViewed, parameters: [
            "viewed_user_id": viewedUserId,
            "viewer_user_id": viewerUserId
        ])
    }

    // MARK: - Error Tracking

    /// Track error
    func trackError(_ error: Error, context: String? = nil) {
        logEvent(.error, parameters: [
            "error": error.localizedDescription,
            "context": context ?? "unknown"
        ])

        CrashlyticsManager.shared.recordError(error, userInfo: [
            "context": context ?? "unknown"
        ])
    }

    // MARK: - Performance Tracking

    /// Track performance metric
    func trackPerformance(operation: String, duration: TimeInterval, success: Bool) {
        logEvent(.performance, parameters: [
            "operation": operation,
            "duration": duration,
            "success": success
        ])

        if duration > 1.0 {
            Logger.shared.warning("Slow operation: \(operation) (\(duration)s)", category: .analytics)
        }
    }

    // MARK: - A/B Testing

    /// Track experiment exposure
    func trackExperimentExposure(experimentName: String, variant: String) {
        logEvent(.experimentExposure, parameters: [
            "experiment": experimentName,
            "variant": variant
        ])
    }

    // MARK: - Profile Insights

    /// Fetch profile insights for a user from Firestore analytics
    func fetchProfileInsights(for userId: String) async throws -> ProfileInsights {
        var insights = ProfileInsights()

        // Calculate date ranges for weekly analysis
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.date(byAdding: .day, value: -7, to: now)!
        let lastWeekStart = calendar.date(byAdding: .day, value: -14, to: now)!

        do {
            // Fetch analytics data from Firestore
            let db = Firestore.firestore()

            // Profile views (all time)
            let profileViewsSnapshot = try await db.collection("analytics")
                .whereField("type", isEqualTo: "profile_view")
                .whereField("targetUserId", isEqualTo: userId)
                .getDocuments()
            insights.profileViews = profileViewsSnapshot.documents.count

            // Views this week
            let viewsThisWeekSnapshot = try await db.collection("analytics")
                .whereField("type", isEqualTo: "profile_view")
                .whereField("targetUserId", isEqualTo: userId)
                .whereField("timestamp", isGreaterThan: Timestamp(date: weekStart))
                .getDocuments()
            insights.viewsThisWeek = viewsThisWeekSnapshot.documents.count

            // Views last week
            let viewsLastWeekSnapshot = try await db.collection("analytics")
                .whereField("type", isEqualTo: "profile_view")
                .whereField("targetUserId", isEqualTo: userId)
                .whereField("timestamp", isGreaterThan: Timestamp(date: lastWeekStart))
                .whereField("timestamp", isLessThan: Timestamp(date: weekStart))
                .getDocuments()
            insights.viewsLastWeek = viewsLastWeekSnapshot.documents.count

            // Swipes received (right swipes on user's profile)
            let swipesSnapshot = try await db.collection("interests")
                .whereField("toUserId", isEqualTo: userId)
                .getDocuments()
            insights.swipesReceived = swipesSnapshot.documents.count

            // Likes received (filter for likes, not passes)
            insights.likesReceived = swipesSnapshot.documents.filter { doc in
                (doc.data()["isLike"] as? Bool) == true
            }.count

            // Calculate like rate
            insights.likeRate = Double(insights.likesReceived) / Double(max(insights.swipesReceived, 1))

            // Match count
            let matchesSnapshot = try await db.collection("matches")
                .whereFilter(Filter.orFilter([
                    Filter.whereField("user1Id", isEqualTo: userId),
                    Filter.whereField("user2Id", isEqualTo: userId)
                ]))
                .whereField("isActive", isEqualTo: true)
                .getDocuments()
            insights.matchCount = matchesSnapshot.documents.count

            // Calculate match rate (matches / likes)
            insights.matchRate = Double(insights.matchCount) / Double(max(insights.likesReceived, 1))

            // Calculate profile score (0-100 based on engagement metrics)
            insights.profileScore = calculateProfileScore(insights: insights)

            // Get last active date from user doc
            let userDoc = try await db.collection("users").document(userId).getDocument()
            if let lastActive = userDoc.data()?["lastActive"] as? Timestamp {
                insights.lastActiveDate = lastActive.dateValue()
            } else {
                insights.lastActiveDate = Date()
            }

            Logger.shared.debug("Fetched real analytics for user \(userId): \(insights.profileViews) views, \(insights.likesReceived) likes, \(insights.matchCount) matches", category: .analytics)

        } catch {
            Logger.shared.error("Failed to fetch analytics from Firestore, using defaults", category: .analytics, error: error)
            // Fall back to defaults if Firestore query fails
            insights = createDefaultInsights()
        }

        return insights
    }

    /// Calculate profile score based on engagement metrics
    private func calculateProfileScore(insights: ProfileInsights) -> Int {
        var score = 50 // Base score

        // Boost for profile completeness (views indicate profile is interesting)
        if insights.profileViews > 100 {
            score += 15
        } else if insights.profileViews > 50 {
            score += 10
        } else if insights.profileViews > 20 {
            score += 5
        }

        // Boost for like rate
        if insights.likeRate > 0.5 {
            score += 20
        } else if insights.likeRate > 0.3 {
            score += 10
        } else if insights.likeRate > 0.1 {
            score += 5
        }

        // Boost for match rate
        if insights.matchRate > 0.5 {
            score += 15
        } else if insights.matchRate > 0.3 {
            score += 10
        } else if insights.matchRate > 0.1 {
            score += 5
        }

        return min(100, max(0, score))
    }

    /// Create default insights when data unavailable
    private func createDefaultInsights() -> ProfileInsights {
        var insights = ProfileInsights()
        insights.profileViews = 0
        insights.viewsThisWeek = 0
        insights.viewsLastWeek = 0
        insights.swipesReceived = 0
        insights.likesReceived = 0
        insights.likeRate = 0.0
        insights.matchCount = 0
        insights.matchRate = 0.0
        insights.profileScore = 50
        insights.lastActiveDate = Date()
        return insights
    }

    // MARK: - Private Methods

    private func queueEvent(_ event: AnalyticsEvent, parameters: [String: Any]) {
        let analyticsEvent = AnalyticsEventData(
            name: event.name,
            parameters: parameters,
            timestamp: Date()
        )

        eventQueue.append(analyticsEvent)

        if eventQueue.count >= maxQueueSize {
            flushEvents()
        }
    }

    private func setupPeriodicFlush() {
        Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.flushEvents()
            }
        }
    }

    private func flushEvents() {
        guard !eventQueue.isEmpty else { return }

        Logger.shared.debug("Flushing \(eventQueue.count) analytics events", category: .analytics)

        // In production, you'd send these to your analytics backend
        // For now, they're already sent to Firebase

        eventQueue.removeAll()
    }
}

// MARK: - Analytics Event Definition

enum AnalyticsEvent {
    // Session
    case sessionStart
    case sessionEnd

    // Authentication
    case signUpStarted
    case signUpCompleted
    case signInStarted
    case signInCompleted
    case signOut
    case emailVerified

    // Onboarding
    case onboardingStarted
    case onboardingStepCompleted
    case onboardingCompleted
    case onboardingSkipped

    // Discovery
    case swipe
    case like
    case superLike
    case dislike
    case rewind
    case boost

    // Matching
    case match
    case unmatch

    // Messaging
    case messageSent
    case messageReceived
    case conversationStarted

    // Profile
    case profileViewed
    case profileEdited
    case photoUploaded
    case photoDeleted

    // Premium
    case premiumViewed
    case premiumPurchaseStarted
    case premiumPurchaseCompleted
    case premiumPurchaseFailed
    case purchase
    case refund
    case subscriptionStarted
    case subscriptionExpired
    case subscriptionManaged
    case consumablePurchased
    case consumableUsed
    case purchaseInitiated
    case purchaseCompleted
    case purchaseCancelled
    case purchaseFailed
    case purchasesRestored
    case promoCodeRedeemed

    // Social
    case profileShared
    case referralSent
    case referralCompleted

    // Settings
    case settingsOpened
    case notificationsEnabled
    case notificationsDisabled
    case privacySettingsChanged

    // Performance
    case performance
    case error

    // Engagement
    case engagement
    case featureUsed

    // Funnel
    case funnelStep
    case funnelCompleted
    case funnelAbandoned

    // Experiments
    case experimentExposure

    // Safety & Check-ins
    case dateCheckInCreated
    case dateCheckInStarted
    case dateCheckInMid
    case dateCheckInCompleted
    case emergencyAlertTriggered
    case reportSubmitted
    case userBlocked
    case emergencyContactAdded
    case emergencyContactRemoved
    case backgroundCheckCompleted
    case verificationCompleted
    case safetyAlertCreated

    // Search & Filters
    case filterPresetSaved
    case filterPresetUsed
    case searchPerformed

    var name: String {
        switch self {
        case .sessionStart: return "session_start"
        case .sessionEnd: return "session_end"
        case .signUpStarted: return "sign_up_started"
        case .signUpCompleted: return "sign_up"
        case .signInStarted: return "sign_in_started"
        case .signInCompleted: return "login"
        case .signOut: return "sign_out"
        case .emailVerified: return "email_verified"
        case .onboardingStarted: return "onboarding_started"
        case .onboardingStepCompleted: return "onboarding_step"
        case .onboardingCompleted: return "onboarding_completed"
        case .onboardingSkipped: return "onboarding_skipped"
        case .swipe: return "swipe"
        case .like: return "like"
        case .superLike: return "super_like"
        case .dislike: return "dislike"
        case .rewind: return "rewind"
        case .boost: return "boost"
        case .match: return "match"
        case .unmatch: return "unmatch"
        case .messageSent: return "message_sent"
        case .messageReceived: return "message_received"
        case .conversationStarted: return "conversation_started"
        case .profileViewed: return "profile_viewed"
        case .profileEdited: return "profile_edited"
        case .photoUploaded: return "photo_uploaded"
        case .photoDeleted: return "photo_deleted"
        case .premiumViewed: return "premium_viewed"
        case .premiumPurchaseStarted: return "begin_checkout"
        case .premiumPurchaseCompleted: return "purchase"
        case .premiumPurchaseFailed: return "purchase_failed"
        case .purchase: return "purchase"
        case .refund: return "refund"
        case .subscriptionStarted: return "subscription_started"
        case .subscriptionExpired: return "subscription_expired"
        case .subscriptionManaged: return "subscription_managed"
        case .consumablePurchased: return "consumable_purchased"
        case .consumableUsed: return "consumable_used"
        case .purchaseInitiated: return "purchase_initiated"
        case .purchaseCompleted: return "purchase_completed"
        case .purchaseCancelled: return "purchase_cancelled"
        case .purchaseFailed: return "purchase_failed"
        case .purchasesRestored: return "purchases_restored"
        case .promoCodeRedeemed: return "promo_code_redeemed"
        case .profileShared: return "share"
        case .referralSent: return "referral_sent"
        case .referralCompleted: return "referral_completed"
        case .settingsOpened: return "settings_opened"
        case .notificationsEnabled: return "notifications_enabled"
        case .notificationsDisabled: return "notifications_disabled"
        case .privacySettingsChanged: return "privacy_settings_changed"
        case .performance: return "performance"
        case .error: return "error"
        case .engagement: return "engagement"
        case .featureUsed: return "feature_used"
        case .funnelStep: return "funnel_step"
        case .funnelCompleted: return "funnel_completed"
        case .funnelAbandoned: return "funnel_abandoned"
        case .experimentExposure: return "experiment_exposure"
        case .dateCheckInCreated: return "date_check_in_created"
        case .dateCheckInStarted: return "date_check_in_started"
        case .dateCheckInMid: return "date_check_in_mid"
        case .dateCheckInCompleted: return "date_check_in_completed"
        case .emergencyAlertTriggered: return "emergency_alert_triggered"
        case .reportSubmitted: return "report_submitted"
        case .userBlocked: return "user_blocked"
        case .emergencyContactAdded: return "emergency_contact_added"
        case .emergencyContactRemoved: return "emergency_contact_removed"
        case .backgroundCheckCompleted: return "background_check_completed"
        case .verificationCompleted: return "verification_completed"
        case .safetyAlertCreated: return "safety_alert_created"
        case .filterPresetSaved: return "filter_preset_saved"
        case .filterPresetUsed: return "filter_preset_used"
        case .searchPerformed: return "search_performed"
        }
    }

    var defaultParameters: [String: Any] {
        return [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "platform": "ios"
        ]
    }
}

// MARK: - Funnel Definition

enum AnalyticsFunnel: String {
    case signup = "signup"
    case onboarding = "onboarding"
    case matching = "matching"
    case messaging = "messaging"
    case premiumPurchase = "premium_purchase"
    case referral = "referral"
}

// MARK: - Analytics Swipe Action

enum AnalyticsSwipeAction: String {
    case like = "like"
    case dislike = "dislike"
    case superLike = "super_like"
}

// MARK: - Analytics Swipe Direction

enum AnalyticsSwipeDirection: String {
    case left = "left"
    case right = "right"
    case up = "up"
}

// MARK: - Supporting Types

struct AnalyticsEventData {
    let name: String
    let parameters: [String: Any]
    let timestamp: Date
}

// MARK: - User Properties

enum UserProperty: String {
    case isPremium = "is_premium"
    case gender = "gender"
    case ageGroup = "age_group"
    case location = "location"
    case matchCount = "match_count"
    case messageCount = "message_count"
    case swipeCount = "swipe_count"
    case daysActive = "days_active"
    case lastActiveDate = "last_active_date"
    case referralSource = "referral_source"
    case appVersion = "app_version"
}

// MARK: - Extensions

extension AnalyticsManager {
    /// Track user progress
    func trackUserProgress(
        matchCount: Int,
        messageCount: Int,
        swipeCount: Int
    ) {
        setUserProperty("\(matchCount)", forName: UserProperty.matchCount.rawValue)
        setUserProperty("\(messageCount)", forName: UserProperty.messageCount.rawValue)
        setUserProperty("\(swipeCount)", forName: UserProperty.swipeCount.rawValue)
    }

    /// Track user tier
    func trackUserTier(isPremium: Bool) {
        setUserProperty(isPremium ? "premium" : "free", forName: UserProperty.isPremium.rawValue)
    }
}

// MARK: - AnalyticsManagerProtocol Conformance

extension AnalyticsManager {
    /// Log event with string name (protocol method)
    nonisolated func log(event: String, parameters: [String: Any]) {
        Analytics.logEvent(event, parameters: parameters)
        Logger.shared.info("Event: \(event) \(parameters)", category: .analytics)
    }

    /// Set user ID (protocol method)
    nonisolated func setUserId(_ userId: String) {
        Analytics.setUserID(userId)
        Crashlytics.crashlytics().setUserID(userId)
    }

    /// Set user property (protocol method)
    nonisolated func setUserProperty(_ value: String, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
        Crashlytics.crashlytics().setCustomValue(value, forKey: name)
    }

    /// Log screen view (protocol method)
    nonisolated func logScreen(name: String, screenClass: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: name,
            AnalyticsParameterScreenClass: screenClass
        ])
    }
}
