//
//  AnalyticsManager.swift
//  Celestia
//
//  Analytics tracking and event logging
//  Integrates with Firebase Analytics, Mixpanel, or similar services
//

import Foundation

// MARK: - Swipe Direction

enum SwipeDirection {
    case left, right
}

// MARK: - Analytics Event

enum AnalyticsEvent: String {
    // User Actions
    case featureUsed = "feature_used"
    case profileViewed = "profile_viewed"
    case match = "match"
    case superLike = "super_like"
    case messageReceived = "message_received"

    // Safety & Verification
    case backgroundCheckCompleted = "background_check_completed"
    case verificationCompleted = "verification_completed"
    case verificationAttempt = "verification_attempt"
    case safetyAlertCreated = "safety_alert_created"
    case emergencyTriggered = "emergency_triggered"
    case emergencyContactAdded = "emergency_contact_added"
    case emergencyContactRemoved = "emergency_contact_removed"

    // Date Check-ins
    case dateCheckInScheduled = "date_checkin_scheduled"
    case dateCheckInStarted = "date_checkin_started"
    case dateCheckInCompleted = "date_checkin_completed"

    // Filters & Search
    case filterPresetSaved = "filter_preset_saved"
    case filterPresetUsed = "filter_preset_used"

    // Notifications
    case notificationsEnabled = "notifications_enabled"
    case notificationsDisabled = "notifications_disabled"

    // Network
    case networkConnected = "network_connected"
    case networkDisconnected = "network_disconnected"
    case performance = "performance"

    // Reporting
    case reportSubmitted = "report_submitted"
    case userBlocked = "user_blocked"

    // Subscriptions & Purchases
    case subscriptionActive = "subscription_active"
    case purchaseInitiated = "purchase_initiated"
    case purchaseCompleted = "purchase_completed"
    case purchaseFailed = "purchase_failed"
    case purchaseCancelled = "purchase_cancelled"
    case purchasesRestored = "purchases_restored"
    case promoCodeRedeemed = "promo_code_redeemed"
    case validationError = "validation_error"
    case fraudDetected = "fraud_detected"
}

// MARK: - Analytics Manager

@MainActor
class AnalyticsManager: ObservableObject, AnalyticsManagerProtocol {

    // MARK: - Singleton

    static let shared = AnalyticsManager()

    // MARK: - Properties

    private var isEnabled: Bool = true
    private var userId: String?
    private var userProperties: [String: String] = [:]

    // MARK: - Initialization

    private init() {
        Logger.shared.info("AnalyticsManager initialized", category: .general)
        setupAnalytics()
    }

    // MARK: - Setup

    private func setupAnalytics() {
        // In production, initialize analytics services here:
        // - Firebase Analytics
        // - Mixpanel
        // - Amplitude
        // - Custom analytics backend

        #if DEBUG
        Logger.shared.debug("Analytics running in DEBUG mode", category: .general)
        #endif
    }

    // MARK: - Protocol Methods

    /// Log analytics event with parameters
    func log(event: String, parameters: [String: Any]) {
        guard isEnabled else { return }

        #if DEBUG
        var paramsString = ""
        for (key, value) in parameters {
            paramsString += "\n  - \(key): \(value)"
        }
        Logger.shared.debug("📊 Analytics Event: \(event)\(paramsString)", category: .analytics)
        #endif

        // In production, send to analytics service:
        // FirebaseAnalytics.Analytics.logEvent(event, parameters: parameters)
        // Mixpanel.track(event: event, properties: parameters)
    }

    /// Set user ID for analytics
    func setUserId(_ userId: String) {
        self.userId = userId

        #if DEBUG
        Logger.shared.debug("📊 Analytics User ID set: \(userId)", category: .analytics)
        #endif

        // In production:
        // FirebaseAnalytics.Analytics.setUserID(userId)
        // Mixpanel.identify(distinctId: userId)
    }

    /// Set user property
    func setUserProperty(_ value: String, forName name: String) {
        userProperties[name] = value

        #if DEBUG
        Logger.shared.debug("📊 Analytics User Property: \(name) = \(value)", category: .analytics)
        #endif

        // In production:
        // FirebaseAnalytics.Analytics.setUserProperty(value, forName: name)
        // Mixpanel.people.set(property: name, to: value)
    }

    /// Log screen view
    func logScreen(name: String, screenClass: String) {
        guard isEnabled else { return }

        #if DEBUG
        Logger.shared.debug("📊 Screen View: \(name) (\(screenClass))", category: .analytics)
        #endif

        // In production:
        // FirebaseAnalytics.Analytics.logEvent(AnalyticsEventScreenView, parameters: [
        //     AnalyticsParameterScreenName: name,
        //     AnalyticsParameterScreenClass: screenClass
        // ])
    }

    // MARK: - Convenience Methods

    /// Log event using AnalyticsEvent enum
    func logEvent(_ event: AnalyticsEvent, parameters: [String: Any] = [:]) {
        log(event: event.rawValue, parameters: parameters)
    }

    /// Track swipe action
    func trackSwipe(swipedUserId: String, swiperUserId: String, direction: SwipeDirection) async throws {
        let directionString = direction == .right ? "right" : "left"
        logEvent(.featureUsed, parameters: [
            "feature": "swipe",
            "direction": directionString,
            "swiped_user_id": swipedUserId,
            "swiper_user_id": swiperUserId
        ])
    }

    /// Track match
    func trackMatch(user1Id: String, user2Id: String) async throws {
        // Generate a match ID from the two user IDs (sorted for consistency)
        let sortedIds = [user1Id, user2Id].sorted()
        let matchId = "\(sortedIds[0])_\(sortedIds[1])"

        logEvent(.match, parameters: [
            "match_id": matchId,
            "user1_id": user1Id,
            "user2_id": user2Id
        ])
    }

    /// Enable/disable analytics
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled

        #if DEBUG
        Logger.shared.debug("📊 Analytics \(enabled ? "enabled" : "disabled")", category: .analytics)
        #endif

        // In production:
        // FirebaseAnalytics.Analytics.setAnalyticsCollectionEnabled(enabled)
    }

    // MARK: - Privacy

    /// Clear all user data for GDPR/privacy compliance
    func clearUserData() {
        userId = nil
        userProperties.removeAll()

        #if DEBUG
        Logger.shared.debug("📊 Analytics user data cleared", category: .analytics)
        #endif

        // In production:
        // FirebaseAnalytics.Analytics.resetAnalyticsData()
        // Mixpanel.reset()
    }
}

// MARK: - Extension for Protocol Conformance

extension AnalyticsManager {}
