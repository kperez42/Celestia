//
//  CelestiaApp.swift
//  Celestia
//
//  Created by Kevin Perez on 10/29/25.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAnalytics
import FirebaseMessaging
import StripeIdentity
import UserNotifications

// MARK: - AppDelegate for Push Notifications
// Required for receiving push notifications when app is in background/killed

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure Firebase FIRST in AppDelegate (not in App.init())
        // This ensures proper swizzling for push notifications and analytics
        // NOTE: This is the SINGLE initialization point for Firebase
        // Do NOT call FirebaseApp.configure() anywhere else in the app
        FirebaseApp.configure()

        // Configure Firestore settings immediately after Firebase configuration
        // This must happen before any Firestore operations
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = 50 * 1024 * 1024 // 50MB limit
        Firestore.firestore().settings = settings
        Logger.shared.info("Firestore persistence initialized (50MB cache limit)", category: .database)

        // Enable Firebase Analytics for event tracking
        Analytics.setAnalyticsCollectionEnabled(true)

        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = self

        // Set Firebase Messaging delegate
        Messaging.messaging().delegate = self

        // Register for remote notifications
        application.registerForRemoteNotifications()

        Logger.shared.info("AppDelegate: Registered for remote notifications", category: .general)

        return true
    }

    // MARK: - Remote Notification Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Pass device token to Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken

        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Logger.shared.info("APNs device token received: \(tokenString.prefix(20))...", category: .general)

        // Also pass to PushNotificationManager
        Task { @MainActor in
            PushNotificationManager.shared.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Logger.shared.error("Failed to register for remote notifications", category: .general, error: error)

        Task { @MainActor in
            PushNotificationManager.shared.didFailToRegisterForRemoteNotifications(withError: error)
        }
    }

    // MARK: - Background Notification Handling

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Handle background/silent notifications
        Logger.shared.info("Received background notification: \(userInfo)", category: .general)

        // Check if this is an admin notification
        if let type = userInfo["type"] as? String, type == "admin_alert" {
            Logger.shared.info("Admin alert received in background", category: .general)
        }

        completionHandler(.newData)
    }

    // MARK: - Firebase Messaging Delegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else { return }

        Logger.shared.info("FCM token received: \(fcmToken.prefix(20))...", category: .general)

        // Save FCM token to Firestore for the current user
        Task { @MainActor in
            if let userId = AuthService.shared.currentUser?.id {
                await NotificationService.shared.saveFCMToken(userId: userId, token: fcmToken)
                Logger.shared.info("FCM token saved for user: \(userId)", category: .general)
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Handle notification when app is in FOREGROUND
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        Logger.shared.info("Notification received in foreground: \(userInfo)", category: .general)

        // Show notification banner even when app is in foreground (like Instagram)
        completionHandler([.banner, .badge, .sound, .list])
    }

    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Logger.shared.info("Notification tapped: \(userInfo)", category: .general)

        // Handle admin notifications - navigate to admin tab
        if let type = userInfo["type"] as? String, type == "admin_alert" {
            Task { @MainActor in
                // Post notification to navigate to admin dashboard
                NotificationCenter.default.post(name: .navigateToAdminDashboard, object: nil, userInfo: userInfo)
            }
        }

        completionHandler()
    }
}

// MARK: - Notification Names Extension

extension Notification.Name {
    static let navigateToAdminDashboard = Notification.Name("navigateToAdminDashboard")
}

// MARK: - Main App

@main
struct CelestiaApp: App {
    // Connect AppDelegate for push notification handling
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var authService = AuthService.shared
    @StateObject private var deepLinkManager = DeepLinkManager()

    init() {
        // NOTE: Firebase and Firestore are configured in AppDelegate.didFinishLaunchingWithOptions
        // This ensures proper swizzling for push notifications and analytics
        // Do NOT call FirebaseApp.configure() or set Firestore settings here

        // Configure Stripe Identity SDK for ID verification
        StripeConfig.configure()

        // MEMORY FIX: Reduce startup memory pressure by deferring heavy service initialization
        // This helps reduce malloc errors during Firebase initialization
        Task.detached(priority: .background) {
            // Allow Firebase core services to initialize first
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay

            // Pre-warm AnalyticsServiceEnhanced singleton on background to distribute memory allocations
            await MainActor.run {
                _ = AnalyticsServiceEnhanced.shared
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(deepLinkManager)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        Logger.shared.info("Deep link received: \(url)", category: .general)

        // Handle celestia://join/CEL-XXXXXXXX or https://celestia.app/join/CEL-XXXXXXXX
        if url.pathComponents.contains("join"),
           let code = url.pathComponents.last,
           code.hasPrefix("CEL-") {
            deepLinkManager.referralCode = code
            Logger.shared.info("Extracted referral code from deep link: \(code)", category: .referral)
        }
    }
}
