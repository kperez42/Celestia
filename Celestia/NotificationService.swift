//
//  NotificationService.swift
//  Celestia
//
//  Smart notification system for user engagement
//

import Foundation
import UserNotifications
import FirebaseFirestore
import SwiftUI

// MARK: - Notification Types

enum NotificationType: String, Codable {
    case newMatch
    case newMessage
    case secretAdmirer
    case profileView
    case weeklyDigest
    case activityReminder
    case likeReceived
    case superLikeReceived
}

struct NotificationData: Codable {
    let type: NotificationType
    let title: String
    let body: String
    let userId: String?
    let matchId: String?
    let messageId: String?
    let timestamp: Date
    let actionURL: String?

    init(type: NotificationType, title: String, body: String, userId: String? = nil, matchId: String? = nil, messageId: String? = nil, actionURL: String? = nil) {
        self.type = type
        self.title = title
        self.body = body
        self.userId = userId
        self.matchId = matchId
        self.messageId = messageId
        self.timestamp = Date()
        self.actionURL = actionURL
    }
}

// MARK: - Notification Preferences

struct NotificationPreferences: Codable {
    var newMatches: Bool = true
    var messages: Bool = true
    var secretAdmirer: Bool = true
    var profileViews: Bool = true
    var weeklyDigest: Bool = true
    var activityReminders: Bool = true
    var likes: Bool = true
    var sound: Bool = true
    var badge: Bool = true

    // Quiet hours
    var quietHoursEnabled: Bool = false
    var quietHoursStart: Date = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    var quietHoursEnd: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
}

// MARK: - Notification Service

@MainActor
class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    @Published var preferences = NotificationPreferences()
    @Published var hasNotificationPermission = false
    @Published var notificationHistory: [NotificationData] = []

    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        loadPreferences()
    }

    // MARK: - Permission Management

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            hasNotificationPermission = granted

            if granted {
                await scheduleWeeklyDigest()
            }

            return granted
        } catch {
            print("Error requesting notification permission: \(error)")
            return false
        }
    }

    func checkPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        hasNotificationPermission = settings.authorizationStatus == .authorized
    }

    // MARK: - New Match Notification

    func sendNewMatchNotification(match: Match, otherUser: User) async {
        guard preferences.newMatches, !isQuietHours() else { return }

        let notification = NotificationData(
            type: .newMatch,
            title: "It's a Match! 💕",
            body: "You and \(otherUser.fullName) liked each other!",
            userId: otherUser.id,
            matchId: match.id,
            actionURL: "celestia://matches/\(match.id ?? "")"
        )

        await sendLocalNotification(notification)
        await saveToHistory(notification)
        await sendPushNotification(notification, to: match.user1Id)

        // Add haptic feedback
        HapticManager.shared.notification(.success)
    }

    // MARK: - Message Notifications

    func sendMessageNotification(message: Message, senderName: String, matchId: String) async {
        guard preferences.messages, !isQuietHours() else { return }

        // Truncate message preview
        let preview = message.text.count > 50 ?
            String(message.text.prefix(47)) + "..." :
            message.text

        let notification = NotificationData(
            type: .newMessage,
            title: "\(senderName)",
            body: preview,
            userId: message.senderId,
            matchId: matchId,
            messageId: message.id,
            actionURL: "celestia://chat/\(matchId)"
        )

        await sendLocalNotification(notification)
        await saveToHistory(notification)
        await sendPushNotification(notification, to: message.receiverId)
    }

    // MARK: - Secret Admirer Notification

    func sendSecretAdmirerNotification(userId: String) async {
        guard preferences.secretAdmirer, !isQuietHours() else { return }

        let messages = [
            "You have a secret admirer! 😍",
            "Someone special is thinking of you... 💭",
            "You caught someone's eye! 👀",
            "Mystery like incoming! 💫",
            "Someone is crushing on you! 💕"
        ]

        let notification = NotificationData(
            type: .secretAdmirer,
            title: "Secret Admirer",
            body: messages.randomElement() ?? messages[0],
            actionURL: "celestia://discover"
        )

        await sendLocalNotification(notification)
        await saveToHistory(notification)
        await sendPushNotification(notification, to: userId)
    }

    // MARK: - Profile View Notification

    func sendProfileViewNotification(viewerName: String, userId: String, isPremium: Bool) async {
        guard preferences.profileViews, !isQuietHours() else { return }

        let body: String
        if isPremium {
            body = "\(viewerName) viewed your profile"
        } else {
            body = "Someone viewed your profile"
        }

        let notification = NotificationData(
            type: .profileView,
            title: "Profile View",
            body: body,
            userId: userId,
            actionURL: "celestia://profile/views"
        )

        await sendLocalNotification(notification)
        await saveToHistory(notification)
        await sendPushNotification(notification, to: userId)
    }

    // MARK: - Weekly Digest

    func generateWeeklyDigest(userId: String) async -> NotificationData? {
        guard preferences.weeklyDigest else { return nil }

        // Fetch user stats for the week
        let stats = await fetchWeeklyStats(userId: userId)

        guard stats.hasActivity else { return nil }

        var highlights: [String] = []

        if stats.newMatches > 0 {
            highlights.append("\(stats.newMatches) new match\(stats.newMatches == 1 ? "" : "es")")
        }
        if stats.messages > 0 {
            highlights.append("\(stats.messages) message\(stats.messages == 1 ? "" : "s")")
        }
        if stats.profileViews > 0 {
            highlights.append("\(stats.profileViews) profile view\(stats.profileViews == 1 ? "" : "s")")
        }
        if stats.likes > 0 {
            highlights.append("\(stats.likes) new like\(stats.likes == 1 ? "" : "s")")
        }

        let body = "This week: " + highlights.joined(separator: ", ") + " 🌟"

        let notification = NotificationData(
            type: .weeklyDigest,
            title: "Your Week in Review",
            body: body,
            actionURL: "celestia://profile"
        )

        return notification
    }

    func scheduleWeeklyDigest() async {
        // Schedule for Sunday at 6 PM
        var dateComponents = DateComponents()
        dateComponents.weekday = 1 // Sunday
        dateComponents.hour = 18
        dateComponents.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "Your Week in Review"
        content.body = "Check out your Celestia highlights from this week!"
        content.sound = preferences.sound ? .default : nil
        content.badge = preferences.badge ? 1 : 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly_digest", content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Error scheduling weekly digest: \(error)")
        }
    }

    // MARK: - Activity Reminder

    func sendActivityReminder(userId: String, daysSinceActive: Int) async {
        guard preferences.activityReminders, !isQuietHours() else { return }

        let messages = [
            "Your matches are waiting! Come back and say hi 👋",
            "Someone might be thinking about you right now... 💭",
            "Don't miss out on new connections! 🌟",
            "Your perfect match could be one swipe away ✨",
            "Time to check in! New people are joining daily 🎉"
        ]

        let notification = NotificationData(
            type: .activityReminder,
            title: "We Miss You!",
            body: messages.randomElement() ?? messages[0],
            actionURL: "celestia://discover"
        )

        await sendLocalNotification(notification)
        await saveToHistory(notification)
        await sendPushNotification(notification, to: userId)
    }

    // MARK: - Like Notifications

    func sendLikeNotification(likerName: String?, userId: String, isSuperLike: Bool) async {
        guard preferences.likes, !isQuietHours() else { return }

        let notification: NotificationData

        if isSuperLike {
            notification = NotificationData(
                type: .superLikeReceived,
                title: "Super Like! ⭐",
                body: likerName != nil ? "\(likerName!) sent you a Super Like!" : "Someone sent you a Super Like!",
                userId: userId,
                actionURL: "celestia://discover"
            )
        } else {
            notification = NotificationData(
                type: .likeReceived,
                title: "New Like 💕",
                body: "Someone liked your profile!",
                actionURL: "celestia://discover"
            )
        }

        await sendLocalNotification(notification)
        await saveToHistory(notification)
        await sendPushNotification(notification, to: userId)
    }

    // MARK: - Local Notification

    private func sendLocalNotification(_ data: NotificationData) async {
        let content = UNMutableNotificationContent()
        content.title = data.title
        content.body = data.body
        content.sound = preferences.sound ? .default : nil
        content.badge = preferences.badge ? 1 : 0

        // Add user info for handling taps
        content.userInfo = [
            "type": data.type.rawValue,
            "userId": data.userId ?? "",
            "matchId": data.matchId ?? "",
            "messageId": data.messageId ?? "",
            "actionURL": data.actionURL ?? ""
        ]

        // Trigger immediately
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Error sending local notification: \(error)")
        }
    }

    // MARK: - Push Notification (Firestore)

    private func sendPushNotification(_ data: NotificationData, to userId: String) async {
        // In production, this would trigger a Cloud Function to send FCM notification
        // For now, we'll just save to Firestore
        do {
            try await db.collection("notifications")
                .document(userId)
                .collection("inbox")
                .addDocument(data: [
                    "type": data.type.rawValue,
                    "title": data.title,
                    "body": data.body,
                    "userId": data.userId ?? "",
                    "matchId": data.matchId ?? "",
                    "messageId": data.messageId ?? "",
                    "timestamp": Timestamp(date: data.timestamp),
                    "actionURL": data.actionURL ?? "",
                    "isRead": false
                ])
        } catch {
            print("Error sending push notification: \(error)")
        }
    }

    // MARK: - Notification History

    private func saveToHistory(_ data: NotificationData) async {
        notificationHistory.insert(data, at: 0)

        // Keep only last 50 notifications
        if notificationHistory.count > 50 {
            notificationHistory = Array(notificationHistory.prefix(50))
        }
    }

    func listenToNotifications(userId: String) {
        listenerRegistration?.remove()

        listenerRegistration = db.collection("notifications")
            .document(userId)
            .collection("inbox")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching notifications: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }

                Task { @MainActor in
                    self?.notificationHistory = documents.compactMap { doc -> NotificationData? in
                        let data = doc.data()
                        guard let typeString = data["type"] as? String,
                              let type = NotificationType(rawValue: typeString),
                              let title = data["title"] as? String,
                              let body = data["body"] as? String,
                              let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
                            return nil
                        }

                        return NotificationData(
                            type: type,
                            title: title,
                            body: body,
                            userId: data["userId"] as? String,
                            matchId: data["matchId"] as? String,
                            messageId: data["messageId"] as? String,
                            actionURL: data["actionURL"] as? String
                        )
                    }
                }
            }
    }

    func stopListening() {
        listenerRegistration?.remove()
    }

    // MARK: - Helper Functions

    private func isQuietHours() -> Bool {
        guard preferences.quietHoursEnabled else { return false }

        let calendar = Calendar.current
        let now = Date()

        let startComponents = calendar.dateComponents([.hour, .minute], from: preferences.quietHoursStart)
        let endComponents = calendar.dateComponents([.hour, .minute], from: preferences.quietHoursEnd)
        let currentComponents = calendar.dateComponents([.hour, .minute], from: now)

        guard let startHour = startComponents.hour,
              let startMinute = startComponents.minute,
              let endHour = endComponents.hour,
              let endMinute = endComponents.minute,
              let currentHour = currentComponents.hour,
              let currentMinute = currentComponents.minute else {
            return false
        }

        let currentMinutes = currentHour * 60 + currentMinute
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute

        // Handle overnight quiet hours
        if startMinutes > endMinutes {
            return currentMinutes >= startMinutes || currentMinutes <= endMinutes
        } else {
            return currentMinutes >= startMinutes && currentMinutes <= endMinutes
        }
    }

    private struct WeeklyStats {
        let newMatches: Int
        let messages: Int
        let profileViews: Int
        let likes: Int

        var hasActivity: Bool {
            newMatches > 0 || messages > 0 || profileViews > 0 || likes > 0
        }
    }

    private func fetchWeeklyStats(userId: String) async -> WeeklyStats {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        var newMatches = 0
        var messages = 0
        var profileViews = 0
        var likes = 0

        do {
            // Fetch matches from last week
            let matchesSnapshot = try await db.collection("matches")
                .whereFilter(Filter.orFilter([
                    Filter.whereField("user1Id", isEqualTo: userId),
                    Filter.whereField("user2Id", isEqualTo: userId)
                ]))
                .whereField("timestamp", isGreaterThan: Timestamp(date: weekAgo))
                .getDocuments()
            newMatches = matchesSnapshot.documents.count

            // Fetch messages from last week
            let messagesSnapshot = try await db.collection("messages")
                .whereField("receiverId", isEqualTo: userId)
                .whereField("timestamp", isGreaterThan: Timestamp(date: weekAgo))
                .getDocuments()
            messages = messagesSnapshot.documents.count

            // Fetch profile views from last week
            let viewsSnapshot = try await db.collection("profileViews")
                .whereField("viewedUserId", isEqualTo: userId)
                .whereField("timestamp", isGreaterThan: Timestamp(date: weekAgo))
                .getDocuments()
            profileViews = viewsSnapshot.documents.count

            // Fetch likes from last week
            let likesSnapshot = try await db.collection("likes")
                .whereField("likedUserId", isEqualTo: userId)
                .whereField("timestamp", isGreaterThan: Timestamp(date: weekAgo))
                .getDocuments()
            likes = likesSnapshot.documents.count
        } catch {
            print("Error fetching weekly stats: \(error)")
        }

        return WeeklyStats(newMatches: newMatches, messages: messages, profileViews: profileViews, likes: likes)
    }

    // MARK: - Preferences Management

    func savePreferences() {
        if let encoded = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(encoded, forKey: "notificationPreferences")
        }
    }

    func loadPreferences() {
        if let data = UserDefaults.standard.data(forKey: "notificationPreferences"),
           let decoded = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            preferences = decoded
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // Show notification even when app is in foreground
        return [.banner, .sound, .badge]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo

        // Handle notification tap
        if let actionURL = userInfo["actionURL"] as? String {
            // In production, this would use deep linking to navigate to the appropriate screen
            print("Notification tapped: \(actionURL)")
        }
    }

    // MARK: - Badge Management

    func updateBadgeCount(_ count: Int) {
        guard preferences.badge else { return }

        Task {
            do {
                try await UNUserNotificationCenter.current().setBadgeCount(count)
            } catch {
                print("Error updating badge count: \(error)")
            }
        }
    }

    func clearBadge() {
        updateBadgeCount(0)
    }
}
