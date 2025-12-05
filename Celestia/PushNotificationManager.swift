//
//  PushNotificationManager.swift
//  Celestia
//
//  Manages push notifications via APNs and Firebase Cloud Messaging
//  Handles registration, delivery, actions, and user preferences
//

import Foundation
import UserNotifications
import FirebaseMessaging
import UIKit

// MARK: - Push Notification Manager

@MainActor
class PushNotificationManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = PushNotificationManager()

    // MARK: - Published Properties

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var fcmToken: String?
    @Published var apnsToken: String?
    @Published private(set) var badgeCount: Int = 0

    // MARK: - Computed Properties

    var hasNotificationPermission: Bool {
        return authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    // MARK: - Properties

    private let preferences = NotificationPreferences.shared
    private let center = UNUserNotificationCenter.current()

    // MARK: - Initialization

    private override init() {
        super.init()
        Logger.shared.info("PushNotificationManager initialized", category: .general)
    }

    // MARK: - Setup

    func initialize() async {
        center.delegate = self

        // Register notification categories
        registerNotificationCategories()

        // Check current authorization status
        await updateAuthorizationStatus()

        // Configure Firebase Messaging
        Messaging.messaging().delegate = self

        Logger.shared.info("Push notifications initialized", category: .general)
    }

    // MARK: - Permission Handling

    /// Request notification permissions
    func requestAuthorization() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .badge, .sound, .criticalAlert, .provisional]
            let granted = try await center.requestAuthorization(options: options)

            await updateAuthorizationStatus()

            if granted {
                await registerForRemoteNotifications()
                Logger.shared.info("Notification authorization granted", category: .general)
                AnalyticsManager.shared.logEvent(.notificationsEnabled)
            } else {
                Logger.shared.warning("Notification authorization denied", category: .general)
                AnalyticsManager.shared.logEvent(.notificationsDisabled)
            }

            return granted
        } catch {
            Logger.shared.error("Failed to request notification authorization", category: .general, error: error)
            return false
        }
    }

    /// Request permission (alias for requestAuthorization)
    func requestPermission() async -> Bool {
        return await requestAuthorization()
    }

    /// Check current permission status
    func checkPermissionStatus() async {
        await updateAuthorizationStatus()
    }

    /// Register for remote notifications
    func registerForRemoteNotifications() async {
        await UIApplication.shared.registerForRemoteNotifications()
    }

    /// Update authorization status
    private func updateAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - Token Management

    /// Handle APNs device token
    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        apnsToken = tokenString

        Logger.shared.info("Registered for remote notifications: \(tokenString)", category: .general)

        // Send token to Firebase
        Messaging.messaging().apnsToken = deviceToken

        // Send token to your backend
        Task {
            await sendTokenToBackend(apnsToken: tokenString, fcmToken: fcmToken)
        }
    }

    /// Handle registration failure
    func didFailToRegisterForRemoteNotifications(withError error: Error) {
        Logger.shared.error("Failed to register for remote notifications", category: .general, error: error)
        CrashlyticsManager.shared.recordError(error, userInfo: ["context": "push_registration"])
    }

    /// Send tokens to backend
    private func sendTokenToBackend(apnsToken: String?, fcmToken: String?) async {
        // BUGFIX: Use effectiveId for reliable user identification
        guard let userId = AuthService.shared.currentUser?.effectiveId else {
            Logger.shared.warning("Cannot send token: user not authenticated", category: .general)
            return
        }

        Logger.shared.info("Sending push tokens to backend for user: \(userId)", category: .general)

        do {
            try await BackendAPIService.shared.updatePushTokens(
                userId: userId,
                apnsToken: apnsToken,
                fcmToken: fcmToken
            )
            Logger.shared.info("Push tokens sent to backend successfully", category: .general)
        } catch {
            Logger.shared.error("Failed to send push tokens to backend", category: .general, error: error)
            // Don't throw - we'll retry on next token refresh
        }
    }

    // MARK: - Notification Categories

    private func registerNotificationCategories() {
        let categories = NotificationCategory.allCases.map { category in
            UNNotificationCategory(
                identifier: category.identifier,
                actions: category.actions,
                intentIdentifiers: [],
                options: category.options
            )
        }

        center.setNotificationCategories(Set(categories))
        Logger.shared.debug("Registered \(categories.count) notification categories", category: .general)
    }

    // MARK: - Send Notifications (For Testing/Local)

    /// Schedule a local notification
    func scheduleLocalNotification(
        title: String,
        body: String,
        category: NotificationCategory,
        userInfo: [String: Any] = [:],
        delay: TimeInterval = 0,
        imageURL: URL? = nil
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = category.identifier
        content.userInfo = userInfo
        content.sound = .default
        content.badge = NSNumber(value: badgeCount + 1)

        // Add image attachment if provided
        if let imageURL = imageURL,
           let attachment = try? await createNotificationAttachment(from: imageURL) {
            content.attachments = [attachment]
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 0.1), repeats: false)
        let identifier = UUID().uuidString
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try await center.add(request)
        Logger.shared.debug("Scheduled local notification: \(title)", category: .general)
    }

    /// Create notification attachment from URL
    private func createNotificationAttachment(from url: URL) async throws -> UNNotificationAttachment? {
        let (data, _) = try await URLSession.shared.data(from: url)

        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFile = tempDirectory.appendingPathComponent(UUID().uuidString + ".jpg")

        try data.write(to: tempFile)

        return try UNNotificationAttachment(identifier: UUID().uuidString, url: tempFile)
    }

    // MARK: - Badge Management

    /// Update badge count
    func updateBadgeCount(_ count: Int) {
        badgeCount = max(0, count)

        // Use UNUserNotificationCenter instead of deprecated applicationIconBadgeNumber
        if #available(iOS 16.0, *) {
            Task {
                try? await center.setBadgeCount(badgeCount)
            }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = badgeCount
        }

        Logger.shared.debug("Badge count updated: \(badgeCount)", category: .general)
    }

    /// Increment badge count
    func incrementBadge() {
        updateBadgeCount(badgeCount + 1)
    }

    /// Clear badge count
    func clearBadge() {
        updateBadgeCount(0)
    }

    // MARK: - Notification Delivery

    /// Check if should deliver notification (respects quiet hours, preferences)
    func shouldDeliverNotification(category: NotificationCategory) -> Bool {
        // Check if category is enabled
        guard preferences.isEnabled(for: category) else {
            Logger.shared.debug("Notification disabled for category: \(category.identifier)", category: .general)
            return false
        }

        // Check quiet hours
        if preferences.quietHoursEnabled && preferences.isInQuietHours() {
            Logger.shared.debug("Notification blocked by quiet hours", category: .general)
            return false
        }

        return true
    }

    // MARK: - Notification Actions

    /// Handle notification action
    func handleNotificationAction(
        _ actionIdentifier: String,
        for notification: UNNotification
    ) async {
        let userInfo = notification.request.content.userInfo

        Logger.shared.info("Handling notification action: \(actionIdentifier)", category: .general)

        switch actionIdentifier {
        case "REPLY":
            await handleReplyAction(userInfo: userInfo)

        case "VIEW_PROFILE":
            await handleViewProfileAction(userInfo: userInfo)

        case "VIEW_MATCH":
            await handleViewMatchAction(userInfo: userInfo)

        case "OPEN_APP":
            await handleOpenAppAction(userInfo: userInfo)

        default:
            Logger.shared.warning("Unknown notification action: \(actionIdentifier)", category: .general)
        }

        // Track action in analytics
        await AnalyticsManager.shared.logEvent(.featureUsed, parameters: [
            "feature": "notification_action",
            "action": actionIdentifier
        ])
    }

    private func handleReplyAction(userInfo: [AnyHashable: Any]) async {
        guard let matchId = userInfo["match_id"] as? String else { return }

        Logger.shared.info("Opening message screen for match: \(matchId)", category: .general)

        // Post notification to open message screen
        NotificationCenter.default.post(
            name: .openMessageScreen,
            object: nil,
            userInfo: ["match_id": matchId]
        )
    }

    private func handleViewProfileAction(userInfo: [AnyHashable: Any]) async {
        guard let userId = userInfo["user_id"] as? String else { return }

        Logger.shared.info("Opening profile for user: \(userId)", category: .general)

        // Post notification to open profile
        NotificationCenter.default.post(
            name: .openProfile,
            object: nil,
            userInfo: ["user_id": userId]
        )
    }

    private func handleViewMatchAction(userInfo: [AnyHashable: Any]) async {
        guard let matchId = userInfo["match_id"] as? String else { return }

        Logger.shared.info("Opening match details: \(matchId)", category: .general)

        // Post notification to open match
        NotificationCenter.default.post(
            name: .openMatch,
            object: nil,
            userInfo: ["match_id": matchId]
        )
    }

    private func handleOpenAppAction(userInfo: [AnyHashable: Any]) async {
        Logger.shared.info("Opening app from notification", category: .general)

        // App is already opening, no additional action needed
    }

    // MARK: - Notification Removal

    /// Remove delivered notifications
    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    /// Remove all delivered notifications
    func removeAllDeliveredNotifications() {
        center.removeAllDeliveredNotifications()
        clearBadge()
    }

    /// Remove pending notifications
    func removePendingNotifications(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// Remove all pending notifications
    func removeAllPendingNotifications() {
        center.removeAllPendingNotificationRequests()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationManager: UNUserNotificationCenterDelegate {

    /// Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor in
            let userInfo = notification.request.content.userInfo
            Logger.shared.info("Notification received in foreground: \(userInfo)", category: .general)

            // Update badge
            incrementBadge()

            // Show notification even when app is in foreground
            completionHandler([.banner, .badge, .sound])
        }
    }

    /// Handle notification tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            let notification = response.notification
            let actionIdentifier = response.actionIdentifier

            Logger.shared.info("Notification tapped with action: \(actionIdentifier)", category: .general)

            // Handle action
            await handleNotificationAction(actionIdentifier, for: notification)

            completionHandler()
        }
    }
}

// MARK: - MessagingDelegate

extension PushNotificationManager: MessagingDelegate {

    /// Handle FCM token refresh
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in
            self.fcmToken = fcmToken
            Logger.shared.info("FCM token received: \(fcmToken ?? "nil")", category: .general)

            // Send token to backend
            await sendTokenToBackend(apnsToken: apnsToken, fcmToken: fcmToken)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openMessageScreen = Notification.Name("openMessageScreen")
    static let openProfile = Notification.Name("openProfile")
    static let openMatch = Notification.Name("openMatch")
}
