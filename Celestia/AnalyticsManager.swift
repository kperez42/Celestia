//
//  AnalyticsManager.swift
//  Celestia
//
//  Analytics tracking and event logging
//  Integrates with Firebase Analytics
//

import Foundation
import FirebaseAnalytics

// MARK: - Analytics Event

enum AnalyticsEvent: String {
    // User Actions
    case featureUsed = "feature_used"
    case profileViewed = "profile_viewed"
    case match = "match"
    case superLike = "super_like"
    case messageReceived = "message_received"
    case queuedMessage = "queued_message"
    case messageSentFromQueue = "message_sent_from_queue"
    case messageRejected = "message_rejected"

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

    // Listener Lifecycle
    case listenersReconnected = "listeners_reconnected"

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

    // Advanced Analytics Events
    case profileHeatmapGenerated = "profile_heatmap_generated"
    case matchQualityCalculated = "match_quality_calculated"
    case timeToMatchAnalyzed = "time_to_match_analyzed"
    case userInsightsGenerated = "user_insights_generated"
    case matchNotificationSent = "match_notification_sent"
    case messageNotificationSent = "message_notification_sent"
    case likeNotificationSent = "like_notification_sent"
    case smartReminderSent = "smart_reminder_sent"
    case notificationActionTaken = "notification_action_taken"
    case quickReplySent = "quick_reply_sent"
    case likeBackFromNotification = "like_back_from_notification"
    case experimentVariantAssigned = "experiment_variant_assigned"
    case featureFlagChanged = "feature_flag_changed"
    case fraudDetected = "fraud_detected"

    // Batch Operations
    case batchOperationFailed = "batch_operation_failed"
    case batchOperationRetried = "batch_operation_retried"
    case batchOperationRecovered = "batch_operation_recovered"

    // Saved Profiles
    case profileSaved = "profile_saved"
    case profileUnsaved = "profile_unsaved"
    case savedProfilesCleared = "saved_profiles_cleared"

    // UX Enhancement Events (20+ new events)

    // Localization & Language
    case languageChanged = "language_changed"
    case localizationLoaded = "localization_loaded"
    case translationFallback = "translation_fallback"

    // App Shortcuts & Siri
    case appShortcutUsed = "app_shortcut_used"
    case siriIntentTriggered = "siri_intent_triggered"
    case shortcutSuggestionShown = "shortcut_suggestion_shown"
    case deepLinkOpened = "deep_link_opened"

    // Review Prompts
    case reviewPromptShown = "review_prompt_shown"
    case reviewPromptAccepted = "review_prompt_accepted"
    case reviewPromptDismissed = "review_prompt_dismissed"
    case reviewPromptManual = "review_prompt_manual"
    case reviewConditionsMet = "review_conditions_met"

    // Rich Notifications
    case notificationActionClicked = "notification_action_clicked"
    case notificationReplyInline = "notification_reply_inline"
    case notificationImageLoaded = "notification_image_loaded"
    case notificationDismissed = "notification_dismissed"

    // Emergency Contacts & Safety
    case emergencyContactEdited = "emergency_contact_edited"
    case emergencyContactViewed = "emergency_contact_viewed"
    case safetyFeatureDiscovered = "safety_feature_discovered"
    case dateDetailsShared = "date_details_shared"
    case safetyCheckInReminder = "safety_checkin_reminder"

    // Onboarding & User Journey
    case onboardingStarted = "onboarding_started"
    case onboardingStepCompleted = "onboarding_step_completed"
    case onboardingCompleted = "onboarding_completed"
    case onboardingSkipped = "onboarding_skipped"
    case tutorialViewed = "tutorial_viewed"
    case featureDiscovered = "feature_discovered"
    case firstTimeActionCompleted = "first_time_action_completed"

    // User Engagement
    case appLaunched = "app_launched"
    case appBackgrounded = "app_backgrounded"
    case appForegrounded = "app_foregrounded"
    case sessionStarted = "session_started"
    case sessionEnded = "session_ended"
    case sessionDuration = "session_duration"
    case dailyActiveUser = "daily_active_user"
    case weeklyActiveUser = "weekly_active_user"
    case monthlyActiveUser = "monthly_active_user"

    // Activation Metrics
    case userSignup = "user_signup"
    case profileCompleted = "profile_completed"
    case firstMatch = "first_match"
    case milestoneAchieved = "milestone_achieved"

    // Error Tracking & Recovery
    case userFriendlyErrorShown = "user_friendly_error_shown"
    case errorOccurred = "error_occurred"
    case errorRecovered = "error_recovered"
    case errorReportSent = "error_report_sent"
    case retryActionSucceeded = "retry_action_succeeded"
    case gracefulDegradationUsed = "graceful_degradation_used"

    // Feature Adoption
    case premiumFeatureViewed = "premium_feature_viewed"
    case featureTooltipShown = "feature_tooltip_shown"
    case featureTooltipDismissed = "feature_tooltip_dismissed"
    case settingsOpened = "settings_opened"
    case helpDocumentViewed = "help_document_viewed"

    // Match Picker & Date Sharing
    case matchPickerOpened = "match_picker_opened"
    case matchSelected = "match_selected"
    case dateLocationAdded = "date_location_added"
    case dateTimeScheduled = "date_time_scheduled"
}

// MARK: - Analytics Manager

@MainActor
class AnalyticsManager: ObservableObject {

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

        // Send event to Firebase Analytics
        Analytics.logEvent(event, parameters: parameters)
    }

    /// Set user ID for analytics
    func setUserId(_ userId: String) {
        self.userId = userId

        #if DEBUG
        Logger.shared.debug("📊 Analytics User ID set: \(userId)", category: .analytics)
        #endif

        // Set user ID in Firebase Analytics
        Analytics.setUserID(userId)
    }

    /// Set user property
    func setUserProperty(_ value: String, forName name: String) {
        userProperties[name] = value

        #if DEBUG
        Logger.shared.debug("📊 Analytics User Property: \(name) = \(value)", category: .analytics)
        #endif

        // Set user property in Firebase Analytics
        Analytics.setUserProperty(value, forName: name)
    }

    /// Log screen view
    func logScreen(name: String, screenClass: String) {
        guard isEnabled else { return }

        #if DEBUG
        Logger.shared.debug("📊 Screen View: \(name) (\(screenClass))", category: .analytics)
        #endif

        // Log screen view to Firebase Analytics
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: name,
            AnalyticsParameterScreenClass: screenClass
        ])
    }

    // MARK: - Convenience Methods

    /// Log event using AnalyticsEvent enum
    func logEvent(_ event: AnalyticsEvent, parameters: [String: Any] = [:]) {
        log(event: event.rawValue, parameters: parameters)
    }

    /// Track swipe action
    func trackSwipe(swipedUserId: String, swiperUserId: String, direction: String) async throws {
        logEvent(.featureUsed, parameters: [
            "feature": "swipe",
            "direction": direction,
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

    /// Track profile view
    func trackProfileView(viewedUserId: String, viewerUserId: String) async throws {
        logEvent(.profileViewed, parameters: [
            "viewed_user_id": viewedUserId,
            "viewer_user_id": viewerUserId
        ])
    }

    /// Fetch profile insights for a user
    func fetchProfileInsights(for userId: String) async throws -> ProfileInsights {
        // In production, this would fetch real analytics from backend
        // For now, return empty insights that will be populated by the view
        return ProfileInsights()
    }

    /// Enable/disable analytics
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled

        #if DEBUG
        Logger.shared.debug("📊 Analytics \(enabled ? "enabled" : "disabled")", category: .analytics)
        #endif

        // Update Firebase Analytics collection state
        Analytics.setAnalyticsCollectionEnabled(enabled)
    }

    // MARK: - Privacy

    /// Clear all user data for GDPR/privacy compliance
    func clearUserData() {
        userId = nil
        userProperties.removeAll()

        #if DEBUG
        Logger.shared.debug("📊 Analytics user data cleared", category: .analytics)
        #endif

        // Reset Firebase Analytics data for privacy compliance
        Analytics.resetAnalyticsData()
    }
}

// MARK: - Extension for Protocol Conformance

extension AnalyticsManager {}
