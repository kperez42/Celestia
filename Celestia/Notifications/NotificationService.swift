//
//  NotificationService.swift
//  Celestia
//
//  Service for sending notifications (local and remote)
//  Used by other services to trigger notifications
//

import Foundation

// MARK: - Notification Service

@MainActor
class NotificationService {

    // MARK: - Singleton

    static let shared = NotificationService()

    // MARK: - Properties

    private let manager = PushNotificationManager.shared
    private let badgeManager = BadgeManager.shared

    // MARK: - Initialization

    private init() {
        Logger.shared.info("NotificationService initialized", category: .general)
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

        // Send local notification (for testing/development)
        #if DEBUG
        do {
            try await manager.scheduleLocalNotification(
                title: payload.title,
                body: payload.body,
                category: payload.category,
                userInfo: payload.userInfo,
                imageURL: payload.imageURL
            )
        } catch {
            Logger.shared.error("Failed to send local notification", category: .general, error: error)
        }
        #endif

        // In production, this would send via your backend to FCM/APNs
        // Example:
        // try await sendRemoteNotification(payload: payload)
    }

    // MARK: - Backend Integration (Placeholder)

    private func sendRemoteNotification(payload: NotificationPayload) async throws {
        // TODO: Send notification via your backend
        // Your backend should use FCM/APNs to deliver the notification

        guard let fcmToken = manager.fcmToken else {
            Logger.shared.warning("No FCM token available", category: .general)
            return
        }

        Logger.shared.info("Would send remote notification with FCM token: \(fcmToken)", category: .general)

        // Example API call:
        // let request = NotificationRequest(
        //     token: fcmToken,
        //     title: payload.title,
        //     body: payload.body,
        //     data: payload.userInfo,
        //     imageURL: payload.imageURL
        // )
        // try await api.sendNotification(request)
    }

    // MARK: - Reminder Scheduling

    /// Schedule match reminder (24 hours after match if no message sent)
    func scheduleMatchReminder(matchId: String, matchName: String, matchImageURL: URL?) {
        Task {
            // Wait 24 hours
            try? await Task.sleep(nanoseconds: 24 * 60 * 60 * 1_000_000_000)

            // Check if user still hasn't messaged
            // TODO: Check message status from MessageService
            let hasMessaged = false // Placeholder

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

            // Check if user still hasn't replied
            // TODO: Check reply status from MessageService
            let hasReplied = false // Placeholder

            if !hasReplied {
                await sendMessageReminderNotification(
                    matchId: matchId,
                    matchName: matchName,
                    matchImageURL: matchImageURL
                )
            }
        }
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
}
