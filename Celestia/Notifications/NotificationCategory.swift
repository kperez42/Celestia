//
//  NotificationCategory.swift
//  Celestia
//
//  Defines notification categories and actions for different types of notifications
//

import Foundation
import UserNotifications

// MARK: - Notification Category

enum NotificationCategory: String, CaseIterable {
    case newMatch = "NEW_MATCH"
    case newMessage = "NEW_MESSAGE"
    case profileView = "PROFILE_VIEW"
    case superLike = "SUPER_LIKE"
    case premiumOffer = "PREMIUM_OFFER"
    case generalUpdate = "GENERAL_UPDATE"
    case matchReminder = "MATCH_REMINDER"
    case messageReminder = "MESSAGE_REMINDER"

    var identifier: String {
        return rawValue
    }

    var title: String {
        switch self {
        case .newMatch:
            return "New Match"
        case .newMessage:
            return "New Message"
        case .profileView:
            return "Profile View"
        case .superLike:
            return "Super Like"
        case .premiumOffer:
            return "Premium Offer"
        case .generalUpdate:
            return "Update"
        case .matchReminder:
            return "Match Reminder"
        case .messageReminder:
            return "Message Reminder"
        }
    }

    var actions: [UNNotificationAction] {
        switch self {
        case .newMatch:
            return [
                NotificationAction.viewMatch.action,
                NotificationAction.viewProfile.action
            ]

        case .newMessage:
            return [
                NotificationAction.reply.textInputAction,
                NotificationAction.viewProfile.action
            ]

        case .profileView:
            return [
                NotificationAction.viewProfile.action
            ]

        case .superLike:
            return [
                NotificationAction.viewProfile.action,
                NotificationAction.openApp.action
            ]

        case .premiumOffer:
            return [
                NotificationAction.openApp.action
            ]

        case .generalUpdate:
            return [
                NotificationAction.openApp.action
            ]

        case .matchReminder:
            return [
                NotificationAction.viewMatch.action
            ]

        case .messageReminder:
            return [
                NotificationAction.reply.textInputAction
            ]
        }
    }

    var options: UNNotificationCategoryOptions {
        switch self {
        case .newMessage, .messageReminder:
            return [.customDismissAction, .allowAnnouncement]
        default:
            return [.customDismissAction]
        }
    }

    static var allCategories: [NotificationCategory] {
        return NotificationCategory.allCases
    }
}

// MARK: - Notification Action

enum NotificationAction: String {
    case reply = "REPLY_ACTION"
    case viewProfile = "VIEW_PROFILE_ACTION"
    case viewMatch = "VIEW_MATCH_ACTION"
    case openApp = "OPEN_APP_ACTION"

    var identifier: String {
        return rawValue
    }

    var action: UNNotificationAction {
        switch self {
        case .reply:
            return UNNotificationAction(
                identifier: identifier,
                title: "Reply",
                options: [.foreground]
            )

        case .viewProfile:
            return UNNotificationAction(
                identifier: identifier,
                title: "View Profile",
                options: [.foreground]
            )

        case .viewMatch:
            return UNNotificationAction(
                identifier: identifier,
                title: "View Match",
                options: [.foreground]
            )

        case .openApp:
            return UNNotificationAction(
                identifier: identifier,
                title: "Open",
                options: [.foreground]
            )
        }
    }

    var textInputAction: UNTextInputNotificationAction {
        switch self {
        case .reply:
            return UNTextInputNotificationAction(
                identifier: identifier,
                title: "Reply",
                options: [.foreground],
                textInputButtonTitle: "Send",
                textInputPlaceholder: "Type a message..."
            )

        default:
            fatalError("Text input not supported for action: \(self)")
        }
    }
}

// MARK: - Notification Payload Builder

struct NotificationPayload {
    let title: String
    let body: String
    let category: NotificationCategory
    let userInfo: [String: Any]
    let imageURL: URL?

    static func newMatch(matchName: String, matchId: String, imageURL: URL?) -> NotificationPayload {
        return NotificationPayload(
            title: "It's a Match! 🎉",
            body: "You and \(matchName) liked each other!",
            category: .newMatch,
            userInfo: [
                "match_id": matchId,
                "type": "new_match"
            ],
            imageURL: imageURL
        )
    }

    static func newMessage(senderName: String, message: String, matchId: String, imageURL: URL?) -> NotificationPayload {
        return NotificationPayload(
            title: senderName,
            body: message,
            category: .newMessage,
            userInfo: [
                "match_id": matchId,
                "type": "new_message"
            ],
            imageURL: imageURL
        )
    }

    static func profileView(viewerName: String, viewerId: String, imageURL: URL?) -> NotificationPayload {
        return NotificationPayload(
            title: "Profile View 👀",
            body: "\(viewerName) viewed your profile",
            category: .profileView,
            userInfo: [
                "user_id": viewerId,
                "type": "profile_view"
            ],
            imageURL: imageURL
        )
    }

    static func superLike(likerName: String, likerId: String, imageURL: URL?) -> NotificationPayload {
        return NotificationPayload(
            title: "Super Like! ⭐",
            body: "\(likerName) sent you a Super Like!",
            category: .superLike,
            userInfo: [
                "user_id": likerId,
                "type": "super_like"
            ],
            imageURL: imageURL
        )
    }

    static func premiumOffer(title: String, body: String) -> NotificationPayload {
        return NotificationPayload(
            title: title,
            body: body,
            category: .premiumOffer,
            userInfo: [
                "type": "premium_offer"
            ],
            imageURL: nil
        )
    }

    static func matchReminder(matchName: String, matchId: String, imageURL: URL?) -> NotificationPayload {
        return NotificationPayload(
            title: "Don't Leave \(matchName) Waiting! 💬",
            body: "Say hi to start the conversation",
            category: .matchReminder,
            userInfo: [
                "match_id": matchId,
                "type": "match_reminder"
            ],
            imageURL: imageURL
        )
    }

    static func messageReminder(matchName: String, matchId: String, imageURL: URL?) -> NotificationPayload {
        return NotificationPayload(
            title: "\(matchName) is waiting for your reply",
            body: "Keep the conversation going!",
            category: .messageReminder,
            userInfo: [
                "match_id": matchId,
                "type": "message_reminder"
            ],
            imageURL: imageURL
        )
    }
}
