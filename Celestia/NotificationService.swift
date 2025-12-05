//
//  NotificationService.swift
//  Celestia
//
//  Service for sending notifications (local and remote)
//  Used by other services to trigger notifications
//

import Foundation
import Combine
import FirebaseFirestore

// MARK: - Notification Service

@MainActor
class NotificationService: ObservableObject, ListenerLifecycleAware {

    // MARK: - Singleton

    static let shared = NotificationService()

    // MARK: - Properties

    private let manager = PushNotificationManager.shared
    private let badgeManager = BadgeManager.shared
    private let messageService = MessageService.shared
    private var listener: ListenerRegistration?

    // LIFECYCLE: Track current user for reconnection
    private var currentUserId: String?

    // MARK: - Published Properties

    @Published var notificationHistory: [NotificationData] = []

    // MARK: - ListenerLifecycleAware Conformance

    nonisolated var listenerId: String { "NotificationService" }

    var areListenersActive: Bool {
        listener != nil
    }

    func reconnectListeners() {
        guard let userId = currentUserId else {
            Logger.shared.debug("NotificationService: No userId for reconnection", category: .general)
            return
        }
        Logger.shared.info("NotificationService: Reconnecting listeners for user: \(userId)", category: .general)
        listenToNotifications(userId: userId)
    }

    func pauseListeners() {
        Logger.shared.info("NotificationService: Pausing listeners", category: .general)
        listener?.remove()
        listener = nil
    }

    // MARK: - Initialization

    private init() {
        Logger.shared.info("NotificationService initialized", category: .general)
        // Register with lifecycle manager for automatic reconnection handling
        ListenerLifecycleManager.shared.register(self)
    }

    // MARK: - Public Methods

    /// Send new match notification
    func sendNewMatchNotification(
        matchId: String,
        matchName: String,
        matchImageURL: URL?
    ) async {
        let payload = NotificationPayload.newMatch(
            matchName: matchName,
            matchId: matchId,
            imageURL: matchImageURL
        )

        await sendNotification(payload: payload)
        badgeManager.incrementNewMatches()

        // Track in analytics
        AnalyticsManager.shared.logEvent(.match, parameters: [
            "match_id": matchId,
            "notification_sent": true
        ])
    }

    /// Send new message notification
    func sendNewMessageNotification(
        matchId: String,
        senderName: String,
        message: String,
        senderImageURL: URL?
    ) async {
        let payload = NotificationPayload.newMessage(
            senderName: senderName,
            message: message,
            matchId: matchId,
            imageURL: senderImageURL
        )

        await sendNotification(payload: payload)
        badgeManager.incrementUnreadMessages()

        // Track in analytics
        AnalyticsManager.shared.logEvent(.messageReceived, parameters: [
            "match_id": matchId,
            "notification_sent": true
        ])
    }

    /// Send profile view notification
    func sendProfileViewNotification(
        viewerId: String,
        viewerName: String,
        viewerImageURL: URL?
    ) async {
        let payload = NotificationPayload.profileView(
            viewerName: viewerName,
            viewerId: viewerId,
            imageURL: viewerImageURL
        )

        await sendNotification(payload: payload)
        badgeManager.incrementProfileViews()

        // Track in analytics
        AnalyticsManager.shared.logEvent(.profileViewed, parameters: [
            "viewer_id": viewerId,
            "notification_sent": true
        ])
    }

    /// Send super like notification
    func sendSuperLikeNotification(
        likerId: String,
        likerName: String,
        likerImageURL: URL?
    ) async {
        let payload = NotificationPayload.superLike(
            likerName: likerName,
            likerId: likerId,
            imageURL: likerImageURL
        )

        await sendNotification(payload: payload)

        // Track in analytics
        AnalyticsManager.shared.logEvent(.superLike, parameters: [
            "liker_id": likerId,
            "notification_sent": true
        ])
    }

    /// Send premium offer notification
    func sendPremiumOfferNotification(title: String, body: String) async {
        let payload = NotificationPayload.premiumOffer(
            title: title,
            body: body
        )

        await sendNotification(payload: payload)
    }

    /// Send match reminder notification
    func sendMatchReminderNotification(
        matchId: String,
        matchName: String,
        matchImageURL: URL?
    ) async {
        let payload = NotificationPayload.matchReminder(
            matchName: matchName,
            matchId: matchId,
            imageURL: matchImageURL
        )

        await sendNotification(payload: payload)
    }

    /// Send message reminder notification
    func sendMessageReminderNotification(
        matchId: String,
        matchName: String,
        matchImageURL: URL?
    ) async {
        let payload = NotificationPayload.messageReminder(
            matchName: matchName,
            matchId: matchId,
            imageURL: matchImageURL
        )

        await sendNotification(payload: payload)
    }

    // MARK: - Private Methods

    private func sendNotification(payload: NotificationPayload) async {
        // Check if should deliver
        guard manager.shouldDeliverNotification(category: payload.category) else {
            Logger.shared.debug("Notification blocked by preferences: \(payload.category.identifier)", category: .general)
            return
        }

        #if DEBUG
        // Send local notification for testing/development
        do {
            // Convert [AnyHashable: Any] to [String: Any]
            let stringUserInfo = payload.userInfo.reduce(into: [String: Any]()) { result, pair in
                if let key = pair.key as? String {
                    result[key] = pair.value
                }
            }

            try await manager.scheduleLocalNotification(
                title: payload.title,
                body: payload.body,
                category: payload.category,
                userInfo: stringUserInfo,
                imageURL: payload.imageURL
            )
        } catch {
            Logger.shared.error("Failed to send local notification", category: .general, error: error)
        }
        #else
        // Send remote notification in production via backend to FCM/APNs
        do {
            try await sendRemoteNotification(payload: payload)
        } catch {
            Logger.shared.error("Failed to send remote notification", category: .general, error: error)
        }
        #endif
    }

    // MARK: - Backend Integration

    private func sendRemoteNotification(payload: NotificationPayload) async throws {
        guard let fcmToken = manager.fcmToken else {
            Logger.shared.warning("No FCM token available for remote notification", category: .general)
            return
        }

        do {
            // Send notification via backend API
            let request = NotificationRequest(
                token: fcmToken,
                title: payload.title,
                body: payload.body,
                data: payload.userInfo,
                imageURL: payload.imageURL?.absoluteString,
                category: payload.category.identifier
            )

            try await BackendAPIService.shared.sendPushNotification(request)
            Logger.shared.info("Remote notification sent successfully", category: .general)
        } catch {
            Logger.shared.error("Failed to send remote notification", category: .general, error: error)
            // Don't throw - we still want local notification to work
        }
    }

    // MARK: - Notification Request Model

    private struct NotificationRequest: Encodable {
        let token: String
        let title: String
        let body: String
        let data: [AnyHashable: Any]
        let imageURL: String?
        let category: String

        enum CodingKeys: String, CodingKey {
            case token, title, body, data, imageURL = "image_url", category
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(token, forKey: .token)
            try container.encode(title, forKey: .title)
            try container.encode(body, forKey: .body)
            try container.encodeIfPresent(imageURL, forKey: .imageURL)
            try container.encode(category, forKey: .category)

            // Convert data dictionary to JSON-serializable format (all values as strings)
            var stringData: [String: String] = [:]
            for (key, value) in data {
                guard let stringKey = key as? String else { continue }

                if let stringValue = value as? String {
                    stringData[stringKey] = stringValue
                } else if let intValue = value as? Int {
                    stringData[stringKey] = String(intValue)
                } else if let boolValue = value as? Bool {
                    stringData[stringKey] = String(boolValue)
                } else if let doubleValue = value as? Double {
                    stringData[stringKey] = String(doubleValue)
                }
            }
            try container.encode(stringData, forKey: .data)
        }
    }

    // MARK: - Reminder Scheduling

    /// Schedule match reminder (24 hours after match if no message sent)
    func scheduleMatchReminder(matchId: String, matchName: String, matchImageURL: URL?) {
        Task {
            // Wait 24 hours
            try? await Task.sleep(nanoseconds: 24 * 60 * 60 * 1_000_000_000)

            // Check if user has sent any messages in this match
            let hasMessaged = await checkIfUserHasMessaged(matchId: matchId)

            if !hasMessaged {
                await sendMatchReminderNotification(
                    matchId: matchId,
                    matchName: matchName,
                    matchImageURL: matchImageURL
                )
            }
        }
    }

    /// Schedule message reminder (if no reply within 24 hours)
    func scheduleMessageReminder(matchId: String, matchName: String, matchImageURL: URL?) {
        Task {
            // Wait 24 hours
            try? await Task.sleep(nanoseconds: 24 * 60 * 60 * 1_000_000_000)

            // Check if user has replied to messages
            let hasReplied = await checkIfUserHasMessaged(matchId: matchId)

            if !hasReplied {
                await sendMessageReminderNotification(
                    matchId: matchId,
                    matchName: matchName,
                    matchImageURL: matchImageURL
                )
            }
        }
    }

    // MARK: - Helper Methods

    /// Check if current user has sent any messages in a match
    private func checkIfUserHasMessaged(matchId: String) async -> Bool {
        // BUGFIX: Use effectiveId for reliable user identification
        guard let currentUserId = AuthService.shared.currentUser?.effectiveId else {
            return false
        }

        do {
            let messages = try await messageService.fetchMessages(matchId: matchId, limit: 100)
            return messages.contains { $0.senderId == currentUserId }
        } catch {
            Logger.shared.error("Failed to check message status", category: .general, error: error)
            return false
        }
    }
}

// MARK: - Protocol Conformance Methods

extension NotificationService {
    /// Request notification permission (protocol method)
    func requestPermission() async -> Bool {
        return await manager.requestAuthorization()
    }

    /// Save FCM token to Firestore (for push notifications)
    func saveFCMToken(userId: String, token: String) async {
        Logger.shared.info("Saving FCM token for user: \(userId)", category: .general)

        do {
            try await Firestore.firestore().collection("users").document(userId).updateData([
                "fcmToken": token,
                "fcmTokenUpdatedAt": FieldValue.serverTimestamp()
            ])
            Logger.shared.info("FCM token saved successfully", category: .general)
        } catch {
            Logger.shared.error("Failed to save FCM token", category: .general, error: error)
        }
    }

    /// Send new match notification (protocol method)
    func sendNewMatchNotification(match: Match, otherUser: User) async {
        await sendNewMatchNotification(
            matchId: match.id ?? "",
            matchName: otherUser.name,
            matchImageURL: otherUser.photos.first.flatMap { URL(string: $0) }
        )
    }

    /// Send message notification (protocol method)
    func sendMessageNotification(message: Message, senderName: String, matchId: String) async {
        await sendNewMessageNotification(
            matchId: matchId,
            senderName: senderName,
            message: message.text,
            senderImageURL: nil
        )
    }

    /// Send like notification (protocol method)
    func sendLikeNotification(likerName: String?, userId: String, isSuperLike: Bool) async {
        if isSuperLike {
            await sendSuperLikeNotification(
                likerId: userId,
                likerName: likerName ?? "Someone",
                likerImageURL: nil
            )
        }
        // Regular likes don't send notifications in this implementation
    }

    /// Send referral success notification (protocol method)
    func sendReferralSuccessNotification(userId: String, referredName: String) async {
        // Implementation for referral notifications
        Logger.shared.info("Sending referral success notification to \(userId)", category: .general)
        // In production, implement the notification logic
    }
}

// MARK: - Integration Examples

extension NotificationService {

    /// Example: Send notification when user gets a new match
    func exampleNewMatch() async {
        await sendNewMatchNotification(
            matchId: "match_123",
            matchName: "Sarah",
            matchImageURL: URL(string: "https://example.com/sarah.jpg")
        )
    }

    /// Example: Send notification when user receives a message
    func exampleNewMessage() async {
        await sendNewMessageNotification(
            matchId: "match_123",
            senderName: "Sarah",
            message: "Hey! How's it going?",
            senderImageURL: URL(string: "https://example.com/sarah.jpg")
        )
    }

    // MARK: - Listener Management

    /// Listen to notifications for a user from Firestore
    func listenToNotifications(userId: String) {
        // LIFECYCLE: Store userId for reconnection
        currentUserId = userId

        // Remove existing listener
        listener?.remove()

        Logger.shared.debug("Starting notification listener for user: \(userId)", category: .general)

        // Listen to user's notifications collection
        listener = Firestore.firestore()
            .collection("notifications")
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                Task { @MainActor in
                    if let error = error {
                        Logger.shared.error("Error listening to notifications", category: .general, error: error)
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        Logger.shared.warning("No notification documents found", category: .general)
                        return
                    }

                    // Parse notifications
                    self.notificationHistory = documents.compactMap { doc -> NotificationData? in
                        guard let data = try? doc.data(as: NotificationData.self) else {
                            return nil
                        }
                        return data
                    }

                    Logger.shared.debug("Loaded \(self.notificationHistory.count) notifications", category: .general)
                }
            }
    }

    /// Stop listening to notifications
    func stopListening() {
        listener?.remove()
        listener = nil
        notificationHistory = []
        Logger.shared.debug("Stopped listening to notifications", category: .general)
    }

    /// Load mock notification history (for development)
    private func loadMockNotificationHistory() {
        // This is temporary mock data - in production, load from Firestore
        notificationHistory = [
            NotificationData(
                type: .newMatch,
                title: "New Match!",
                body: "You matched with Sarah",
                timestamp: Date().addingTimeInterval(-3600)
            ),
            NotificationData(
                type: .newMessage,
                title: "New Message",
                body: "Sarah sent you a message",
                timestamp: Date().addingTimeInterval(-7200)
            )
        ]
    }
}
