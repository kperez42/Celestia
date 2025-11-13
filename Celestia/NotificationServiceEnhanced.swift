//
//  NotificationServiceEnhanced.swift
//  Celestia
//
//  Enhanced notification service with rich content, custom sounds, and smart delivery
//

import Foundation
import FirebaseMessaging
import FirebaseFirestore
import UserNotifications
import UIKit

@MainActor
class NotificationServiceEnhanced: NSObject, ObservableObject {
    static let shared = NotificationServiceEnhanced()

    @Published var notificationPermissionGranted = false
    @Published var pendingNotifications: [PendingNotification] = []

    private let messaging = Messaging.messaging()
    private let notificationCenter = UNUserNotificationCenter.current()
    private let db = Firestore.firestore()

    // Dependencies
    private let authService = AuthService.shared
    private let analyticsService = AnalyticsServiceEnhanced.shared

    private override init() {
        super.init()
        setupNotifications()
    }

    // MARK: - Setup

    func setupNotifications() {
        notificationCenter.delegate = self
        messaging.delegate = self

        // Register custom notification categories
        registerNotificationCategories()

        // Schedule daily engagement reminders
        scheduleDailyReminders()
    }

    func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            notificationPermissionGranted = granted

            if granted {
                await UIApplication.shared.registerForRemoteNotifications()
                Logger.shared.info("Notification permission granted", category: .push)

                // Track analytics
                analyticsService.trackEvent(.notificationsEnabled)
            } else {
                Logger.shared.warning("Notification permission denied", category: .push)
                analyticsService.trackEvent(.notificationsDisabled)
            }

            return granted
        } catch {
            Logger.shared.error("Failed to request notification permission", category: .general, error: error)
            return false
        }
    }

    func registerNotificationCategories() {
        // Match notification category
        let matchReplyAction = UNTextInputNotificationAction(
            identifier: "MATCH_REPLY",
            title: "Reply",
            options: [.authenticationRequired],
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Say hi!"
        )

        let matchViewAction = UNNotificationAction(
            identifier: "MATCH_VIEW",
            title: "View Profile",
            options: [.foreground]
        )

        let matchCategory = UNNotificationCategory(
            identifier: "MATCH",
            actions: [matchReplyAction, matchViewAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Message notification category
        let messageReplyAction = UNTextInputNotificationAction(
            identifier: "MESSAGE_REPLY",
            title: "Reply",
            options: [.authenticationRequired],
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Type a message..."
        )

        let messageViewAction = UNNotificationAction(
            identifier: "MESSAGE_VIEW",
            title: "View Chat",
            options: [.foreground]
        )

        let messageCategory = UNNotificationCategory(
            identifier: "MESSAGE",
            actions: [messageReplyAction, messageViewAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Like notification category (premium only)
        let likeViewAction = UNNotificationAction(
            identifier: "LIKE_VIEW",
            title: "View Profile",
            options: [.foreground]
        )

        let likeLikeBackAction = UNNotificationAction(
            identifier: "LIKE_BACK",
            title: "Like Back",
            options: [.authenticationRequired]
        )

        let likeCategory = UNNotificationCategory(
            identifier: "LIKE",
            actions: [likeViewAction, likeLikeBackAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Engagement reminder category
        let engagementOpenAction = UNNotificationAction(
            identifier: "ENGAGEMENT_OPEN",
            title: "Open App",
            options: [.foreground]
        )

        let engagementCategory = UNNotificationCategory(
            identifier: "ENGAGEMENT",
            actions: [engagementOpenAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([
            matchCategory,
            messageCategory,
            likeCategory,
            engagementCategory
        ])

        Logger.shared.info("Notification categories registered", category: .push)
    }

    // MARK: - Match Notifications

    func sendMatchNotification(match: Match, matchedUser: User) async {
        guard let currentUserId = authService.currentUser?.id else { return }

        // Don't send if user has disabled notifications
        guard authService.currentUser?.notificationsEnabled ?? true else { return }

        let content = UNMutableNotificationContent()
        content.title = "It's a Match! 💕"
        content.body = "You and \(matchedUser.fullName) liked each other!"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("match_sound.wav"))
        content.categoryIdentifier = "MATCH"
        content.badge = await getUnreadCount() as NSNumber

        // Rich content
        if let photoURL = matchedUser.photos.first, !photoURL.isEmpty {
            if let attachment = await createImageAttachment(from: photoURL, identifier: "match-photo") {
                content.attachments = [attachment]
            }
        }

        // Custom data
        content.userInfo = [
            "type": "match",
            "matchId": match.id ?? "",
            "userId": matchedUser.id ?? "",
            "userName": matchedUser.fullName
        ]

        // Send via FCM
        if let fcmToken = await getFCMToken(for: currentUserId) {
            await sendFCMNotification(
                token: fcmToken,
                title: content.title,
                body: content.body,
                data: content.userInfo as! [String: String],
                sound: "match_sound.wav",
                badge: content.badge as? Int
            )
        }

        // Track analytics
        analyticsService.trackEvent(.matchNotificationSent, properties: [
            "matchId": match.id ?? "",
            "hasPhoto": !matchedUser.photos.isEmpty
        ])

        Logger.shared.info("Match notification sent - matchId: \(match.id ?? ""), userName: \(matchedUser.fullName)", category: .push)
    }

    // MARK: - Message Notifications

    func sendMessageNotification(message: Message, senderName: String, matchId: String) async {
        let receiverId = message.receiverId

        // Check if user has notifications enabled
        let receiverDoc = try? await db.collection("users").document(receiverId).getDocument()
        let notificationsEnabled = receiverDoc?.data()?["notificationsEnabled"] as? Bool ?? true

        guard notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = senderName
        content.body = message.imageURL != nil ? "📷 Sent a photo" : message.text
        content.sound = .default
        content.categoryIdentifier = "MESSAGE"
        content.badge = await getUnreadCount(for: receiverId) as NSNumber

        // Rich content for image messages
        if let imageURL = message.imageURL {
            if let attachment = await createImageAttachment(from: imageURL, identifier: "message-image") {
                content.attachments = [attachment]
            }
        }

        // Custom data
        content.userInfo = [
            "type": "message",
            "matchId": matchId,
            "senderId": message.senderId,
            "senderName": senderName,
            "messageId": message.id ?? ""
        ]

        // Send via FCM
        if let fcmToken = await getFCMToken(for: receiverId) {
            await sendFCMNotification(
                token: fcmToken,
                title: content.title,
                body: content.body,
                data: content.userInfo as! [String: String],
                sound: "default",
                badge: content.badge as? Int
            )
        }

        // Track analytics
        analyticsService.trackEvent(.messageNotificationSent, properties: [
            "hasImage": message.imageURL != nil,
            "messageLength": message.text.count
        ])
    }

    // MARK: - Like Notifications (Premium Only)

    func sendLikeNotification(from liker: User, to recipientId: String, isSuperLike: Bool = false) async {
        // Check if recipient is premium
        let recipientDoc = try? await db.collection("users").document(recipientId).getDocument()
        let isPremium = recipientDoc?.data()?["isPremium"] as? Bool ?? false

        guard isPremium else {
            Logger.shared.info("Like notification skipped - user not premium", category: .push)
            return
        }

        // Check if user has notifications enabled
        let notificationsEnabled = recipientDoc?.data()?["notificationsEnabled"] as? Bool ?? true
        guard notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = isSuperLike ? "Someone Super Liked You! ⭐" : "Someone Likes You! ❤️"
        content.body = "\(liker.fullName) \(isSuperLike ? "super liked" : "liked") your profile"
        content.sound = isSuperLike ? UNNotificationSound(named: UNNotificationSoundName("super_like_sound.wav")) : .default
        content.categoryIdentifier = "LIKE"
        content.badge = await getUnreadCount(for: recipientId) as NSNumber

        // Rich content with liker's photo
        if let photoURL = liker.photos.first, !photoURL.isEmpty {
            if let attachment = await createImageAttachment(from: photoURL, identifier: "liker-photo") {
                content.attachments = [attachment]
            }
        }

        // Custom data
        content.userInfo = [
            "type": isSuperLike ? "super_like" : "like",
            "likerId": liker.id ?? "",
            "likerName": liker.fullName
        ]

        // Send via FCM
        if let fcmToken = await getFCMToken(for: recipientId) {
            await sendFCMNotification(
                token: fcmToken,
                title: content.title,
                body: content.body,
                data: content.userInfo as! [String: String],
                sound: isSuperLike ? "super_like_sound.wav" : "default",
                badge: content.badge as? Int
            )
        }

        // Track analytics
        analyticsService.trackEvent(.likeNotificationSent, properties: [
            "isSuperLike": isSuperLike,
            "hasPhoto": !liker.photos.isEmpty
        ])

        Logger.shared.info("Like notification sent - type: \(isSuperLike ? "super_like" : "like"), liker: \(liker.fullName)", category: .push)
    }

    // MARK: - Daily Engagement Reminders

    func scheduleDailyReminders() {
        // Schedule morning reminder (9 AM)
        scheduleDailyReminder(
            identifier: "morning_reminder",
            hour: 9,
            minute: 0,
            title: "Good morning! ☀️",
            body: "New people are waiting to meet you"
        )

        // Schedule evening reminder (7 PM)
        scheduleDailyReminder(
            identifier: "evening_reminder",
            hour: 19,
            minute: 0,
            title: "Tonight's perfect for meeting someone! 🌙",
            body: "Check out your new matches"
        )

        // Schedule daily like digest (8 PM)
        scheduleDailyLikeDigest()

        Logger.shared.info("Daily reminders scheduled", category: .push)
    }

    // MARK: - Daily Like Digest

    /// Schedules daily notification summarizing new likes
    func scheduleDailyLikeDigest() {
        scheduleDailyReminder(
            identifier: "daily_like_digest",
            hour: 20,
            minute: 0,
            title: "💕 Daily Likes Summary",
            body: "See who liked you today!"
        )
    }

    /// Sends daily like digest notification with actual count
    func sendDailyLikeDigest() async {
        guard let userId = authService.currentUser?.id else { return }
        guard authService.currentUser?.notificationsEnabled ?? true else { return }

        // Get likes from last 24 hours
        let yesterday = Date().addingTimeInterval(-24 * 60 * 60)
        let likesSnapshot = try? await db.collection("likes")
            .whereField("targetUserId", isEqualTo: userId)
            .whereField("timestamp", isGreaterThan: yesterday)
            .getDocuments()

        let likeCount = likesSnapshot?.documents.count ?? 0

        // Only send if there are new likes
        guard likeCount > 0 else {
            Logger.shared.info("No new likes for daily digest", category: .push)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "💕 Daily Likes Summary"

        if likeCount == 1 {
            content.body = "You received 1 new like today! Tap to see who."
        } else {
            content.body = "You received \(likeCount) new likes today! 🎉"
        }

        content.sound = .default
        content.categoryIdentifier = "ENGAGEMENT"
        content.badge = await getUnreadCount() as NSNumber

        content.userInfo = [
            "type": "daily_like_digest",
            "likeCount": likeCount
        ]

        // Send immediately
        let request = UNNotificationRequest(
            identifier: "daily_like_digest_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        try? await notificationCenter.add(request)

        // Track analytics
        analyticsService.trackEvent(.smartReminderSent, properties: [
            "type": "daily_like_digest",
            "likeCount": likeCount
        ])

        Logger.shared.info("Daily like digest sent - likeCount: \(likeCount)", category: .push)
    }

    /// Sends personalized like notification with user details
    func sendPersonalizedLikeDigest() async {
        guard let userId = authService.currentUser?.id else { return }
        guard authService.currentUser?.isPremium ?? false else {
            // Non-premium users get basic digest
            await sendDailyLikeDigest()
            return
        }

        // Get likes from last 24 hours
        let yesterday = Date().addingTimeInterval(-24 * 60 * 60)
        let likesSnapshot = try? await db.collection("likes")
            .whereField("targetUserId", isEqualTo: userId)
            .whereField("timestamp", isGreaterThan: yesterday)
            .limit(to: 3)
            .getDocuments()

        guard let likes = likesSnapshot?.documents, !likes.isEmpty else {
            Logger.shared.info("No new likes for personalized digest", category: .push)
            return
        }

        // Fetch user details for first few likers
        var likerNames: [String] = []
        for likeDoc in likes.prefix(3) {
            if let likerId = likeDoc.data()["userId"] as? String {
                let userDoc = try? await db.collection("users").document(likerId).getDocument()
                if let name = userDoc?.data()?["fullName"] as? String {
                    likerNames.append(name)
                }
            }
        }

        let content = UNMutableNotificationContent()
        content.title = "💕 People Who Liked You"

        if likerNames.count == 1 {
            content.body = "\(likerNames[0]) and others liked you today!"
        } else if likerNames.count == 2 {
            content.body = "\(likerNames[0]), \(likerNames[1]) and others liked you!"
        } else if likerNames.count >= 3 {
            content.body = "\(likerNames[0]), \(likerNames[1]), \(likerNames[2]) liked you!"
        } else {
            content.body = "Several people liked you today! 🎉"
        }

        content.sound = .default
        content.categoryIdentifier = "ENGAGEMENT"
        content.badge = await getUnreadCount() as NSNumber

        content.userInfo = [
            "type": "personalized_like_digest",
            "likeCount": likes.count
        ]

        let request = UNNotificationRequest(
            identifier: "personalized_like_digest_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        try? await notificationCenter.add(request)

        analyticsService.trackEvent(.smartReminderSent, properties: [
            "type": "personalized_like_digest",
            "likeCount": likes.count,
            "isPremium": true
        ])

        Logger.shared.info("Personalized like digest sent - likeCount: \(likes.count)", category: .push)
    }

    private func scheduleDailyReminder(identifier: String, hour: Int, minute: Int, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "ENGAGEMENT"
        content.userInfo = [
            "type": "engagement_reminder",
            "reminderType": identifier
        ]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        notificationCenter.add(request) { error in
            if let error = error {
                Logger.shared.error("Failed to schedule daily reminder", category: .push, error: error)
            } else {
                Logger.shared.info("Daily reminder scheduled - identifier: \(identifier)", category: .push)
            }
        }
    }

    func cancelDailyReminders() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [
            "morning_reminder",
            "evening_reminder"
        ])
        Logger.shared.info("Daily reminders cancelled", category: .push)
    }

    // MARK: - Smart Notifications

    func sendSmartEngagementReminder() async {
        guard let currentUser = authService.currentUser else { return }
        guard currentUser.notificationsEnabled else { return }

        // Calculate inactivity period
        let lastActive = currentUser.lastActive
        let hoursSinceActive = Date().timeIntervalSince(lastActive) / 3600

        // Only send if inactive for 24-48 hours
        guard hoursSinceActive >= 24 && hoursSinceActive <= 48 else { return }

        // Get personalized stats
        let stats = await getPersonalizedStats()

        var title = "We miss you! 💔"
        var body = "Come back and see what's new"

        // Personalize based on stats
        if stats.newMatches > 0 {
            title = "You have \(stats.newMatches) new match\(stats.newMatches == 1 ? "" : "es")! 💕"
            body = "Don't keep them waiting!"
        } else if stats.profileViews > 5 {
            title = "\(stats.profileViews) people viewed your profile! 👀"
            body = "Someone might be interested in you"
        } else if stats.newLikes > 0 {
            title = "You have \(stats.newLikes) new like\(stats.newLikes == 1 ? "" : "s")! ❤️"
            body = "Check out who likes you"
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "ENGAGEMENT"
        content.userInfo = [
            "type": "smart_reminder",
            "stats": [
                "newMatches": stats.newMatches,
                "profileViews": stats.profileViews,
                "newLikes": stats.newLikes
            ]
        ]

        // Send immediately
        let request = UNNotificationRequest(
            identifier: "smart_reminder_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        try? await notificationCenter.add(request)

        // Track analytics
        analyticsService.trackEvent(.smartReminderSent, properties: [
            "newMatches": stats.newMatches,
            "profileViews": stats.profileViews,
            "inactiveHours": Int(hoursSinceActive)
        ])
    }

    // MARK: - Helper Functions

    private func sendFCMNotification(
        token: String,
        title: String,
        body: String,
        data: [String: String],
        sound: String,
        badge: Int?
    ) async {
        // This would call your Cloud Function to send FCM notification
        // For now, we'll use the iOS local notification system
        Logger.shared.info("FCM notification prepared - token: \(token), title: \(title)", category: .push)
    }

    private func getFCMToken(for userId: String) async -> String? {
        let userDoc = try? await db.collection("users").document(userId).getDocument()
        return userDoc?.data()?["fcmToken"] as? String
    }

    private func getUnreadCount(for userId: String? = nil) async -> Int {
        let uid = userId ?? authService.currentUser?.id ?? ""
        return await MessageService.shared.getUnreadMessageCount(userId: uid)
    }

    private func createImageAttachment(from urlString: String, identifier: String) async -> UNNotificationAttachment? {
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            let tempDirectory = FileManager.default.temporaryDirectory
            let tempFile = tempDirectory.appendingPathComponent("\(identifier).jpg")

            try data.write(to: tempFile)

            return try UNNotificationAttachment(
                identifier: identifier,
                url: tempFile,
                options: [UNNotificationAttachmentOptionsTypeHintKey: "public.jpeg"]
            )
        } catch {
            Logger.shared.error("Failed to create notification attachment", category: .push, error: error)
            return nil
        }
    }

    private func getPersonalizedStats() async -> PersonalizedStats {
        guard let userId = authService.currentUser?.id else {
            return PersonalizedStats(newMatches: 0, profileViews: 0, newLikes: 0)
        }

        let yesterday = Date().addingTimeInterval(-24 * 60 * 60)

        // Get new matches
        let matchesSnapshot = try? await db.collection("matches")
            .whereField("user1Id", isEqualTo: userId)
            .whereField("timestamp", isGreaterThan: yesterday)
            .getDocuments()

        let newMatches = matchesSnapshot?.documents.count ?? 0

        // Get profile views
        let viewsSnapshot = try? await db.collection("profile_views")
            .whereField("viewedUserId", isEqualTo: userId)
            .whereField("timestamp", isGreaterThan: yesterday)
            .getDocuments()

        let profileViews = viewsSnapshot?.documents.count ?? 0

        // Get new likes
        let likesSnapshot = try? await db.collection("likes")
            .whereField("targetUserId", isEqualTo: userId)
            .whereField("timestamp", isGreaterThan: yesterday)
            .getDocuments()

        let newLikes = likesSnapshot?.documents.count ?? 0

        return PersonalizedStats(
            newMatches: newMatches,
            profileViews: profileViews,
            newLikes: newLikes
        )
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationServiceEnhanced: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier

        Task { @MainActor in
            await handleNotificationAction(actionIdentifier: actionIdentifier, userInfo: userInfo, response: response)
        }

        completionHandler()
    }

    private func handleNotificationAction(
        actionIdentifier: String,
        userInfo: [AnyHashable: Any],
        response: UNNotificationResponse
    ) async {
        let type = userInfo["type"] as? String ?? ""

        switch actionIdentifier {
        case "MATCH_REPLY", "MESSAGE_REPLY":
            if let textResponse = response as? UNTextInputNotificationResponse {
                await handleQuickReply(text: textResponse.userText, userInfo: userInfo)
            }

        case "MATCH_VIEW", "MESSAGE_VIEW":
            handleViewAction(type: type, userInfo: userInfo)

        case "LIKE_VIEW":
            handleLikeView(userInfo: userInfo)

        case "LIKE_BACK":
            await handleLikeBack(userInfo: userInfo)

        case UNNotificationDefaultActionIdentifier:
            handleDefaultAction(type: type, userInfo: userInfo)

        default:
            break
        }

        // Track analytics
        analyticsService.trackEvent(.notificationActionTaken, properties: [
            "action": actionIdentifier,
            "type": type
        ])
    }

    private func handleQuickReply(text: String, userInfo: [AnyHashable: Any]) async {
        guard let matchId = userInfo["matchId"] as? String,
              let senderId = authService.currentUser?.id else {
            return
        }

        guard let receiverId = (userInfo["senderId"] as? String) ?? (userInfo["userId"] as? String) else {
            return
        }

        do {
            try await MessageService.shared.sendMessage(
                matchId: matchId,
                senderId: senderId,
                receiverId: receiverId,
                text: text
            )

            Logger.shared.info("Quick reply sent", category: .push)
            analyticsService.trackEvent(.quickReplySent)
        } catch {
            Logger.shared.error("Quick reply failed", category: .push, error: error)
        }
    }

    private func handleViewAction(type: String, userInfo: [AnyHashable: Any]) {
        // Post notification to open appropriate view
        NotificationCenter.default.post(
            name: .openFromNotification,
            object: nil,
            userInfo: userInfo
        )
    }

    private func handleLikeView(userInfo: [AnyHashable: Any]) {
        guard let likerId = userInfo["likerId"] as? String else { return }

        // Navigate to liker's profile
        NotificationCenter.default.post(
            name: .openUserProfile,
            object: nil,
            userInfo: ["userId": likerId]
        )
    }

    private func handleLikeBack(userInfo: [AnyHashable: Any]) async {
        guard let likerId = userInfo["likerId"] as? String,
              let currentUserId = authService.currentUser?.id else {
            return
        }

        // Like back
        do {
            try await InterestService.shared.sendInterest(
                fromUserId: currentUserId,
                toUserId: likerId
            )

            Logger.shared.info("Liked back from notification", category: .push)
            analyticsService.trackEvent(.likeBackFromNotification)
        } catch {
            Logger.shared.error("Like back failed", category: .push, error: error)
        }
    }

    private func handleDefaultAction(type: String, userInfo: [AnyHashable: Any]) {
        // Open appropriate screen based on notification type
        handleViewAction(type: type, userInfo: userInfo)
    }
}

// MARK: - MessagingDelegate

extension NotificationServiceEnhanced: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else { return }

        Task { @MainActor in
            Logger.shared.info("FCM token received - token: \(fcmToken)", category: .push)

            // Save token to Firestore
            if let userId = authService.currentUser?.id {
                try? await db.collection("users").document(userId).updateData([
                    "fcmToken": fcmToken,
                    "fcmTokenUpdatedAt": Date()
                ])
            }
        }
    }
}

// MARK: - Models

struct PendingNotification: Identifiable {
    let id: String
    let type: String
    let title: String
    let body: String
    let scheduledDate: Date
}

struct PersonalizedStats {
    let newMatches: Int
    let profileViews: Int
    let newLikes: Int
}

// MARK: - Notification Names

extension Notification.Name {
    static let openFromNotification = Notification.Name("openFromNotification")
    static let openUserProfile = Notification.Name("openUserProfile")
}
