//
//  NotificationModels.swift
//  Celestia
//
//  Models and types for notification system
//  NotificationData is defined in NotificationSettingsView.swift
//

import Foundation
import Combine

// MARK: - Notification Category

import UserNotifications

enum NotificationCategory: String, CaseIterable, Codable {
    case newMatch = "NEW_MATCH"
    case newMessage = "NEW_MESSAGE"
    case profileView = "PROFILE_VIEW"
    case newLike = "NEW_LIKE"
    case superLike = "SUPER_LIKE"
    case dailyDigest = "DAILY_DIGEST"
    case premiumOffer = "PREMIUM_OFFER"
    case generalUpdate = "GENERAL_UPDATE"
    case matchReminder = "MATCH_REMINDER"
    case messageReminder = "MESSAGE_REMINDER"
    // Admin notification categories
    case adminNewReport = "ADMIN_NEW_REPORT"
    case adminNewAccount = "ADMIN_NEW_ACCOUNT"
    case adminIdVerification = "ADMIN_ID_VERIFICATION"
    case adminSuspiciousActivity = "ADMIN_SUSPICIOUS_ACTIVITY"

    var identifier: String {
        return rawValue
    }

    var defaultTitle: String {
        switch self {
        case .newMatch:
            return "New Match!"
        case .newMessage:
            return "New Message"
        case .profileView:
            return "Profile View"
        case .newLike:
            return "Someone Likes You!"
        case .superLike:
            return "Super Like!"
        case .dailyDigest:
            return "Your Daily Update"
        case .premiumOffer:
            return "Premium Offer"
        case .generalUpdate:
            return "Update"
        case .matchReminder:
            return "Match Reminder"
        case .messageReminder:
            return "Message Reminder"
        // Admin notifications
        case .adminNewReport:
            return "New Report"
        case .adminNewAccount:
            return "New Account"
        case .adminIdVerification:
            return "ID Verification"
        case .adminSuspiciousActivity:
            return "Suspicious Activity"
        }
    }

    var actions: [UNNotificationAction] {
        switch self {
        case .newMatch:
            return [
                UNTextInputNotificationAction(
                    identifier: "SEND_MESSAGE",
                    title: "Send Message",
                    options: [.authenticationRequired],
                    textInputButtonTitle: "Send",
                    textInputPlaceholder: "Say hello..."
                ),
                UNNotificationAction(
                    identifier: "VIEW_MATCH",
                    title: "View Profile",
                    options: .foreground
                ),
                UNNotificationAction(
                    identifier: "UNMATCH",
                    title: "Unmatch",
                    options: [.destructive, .authenticationRequired]
                )
            ]
        case .newMessage:
            return [
                UNTextInputNotificationAction(
                    identifier: "REPLY",
                    title: "Reply",
                    options: [.authenticationRequired],
                    textInputButtonTitle: "Send",
                    textInputPlaceholder: "Type your reply..."
                ),
                UNNotificationAction(
                    identifier: "VIEW_CONVERSATION",
                    title: "View Chat",
                    options: .foreground
                ),
                UNNotificationAction(
                    identifier: "LIKE_MESSAGE",
                    title: "❤️ Like",
                    options: .authenticationRequired
                )
            ]
        case .profileView:
            return [
                UNNotificationAction(
                    identifier: "VIEW_PROFILE",
                    title: "View Profile",
                    options: .foreground
                ),
                UNNotificationAction(
                    identifier: "LIKE_BACK",
                    title: "Like Back",
                    options: [.authenticationRequired]
                )
            ]
        case .newLike:
            return [
                UNNotificationAction(
                    identifier: "VIEW_PROFILE",
                    title: "See Who",
                    options: .foreground
                ),
                UNNotificationAction(
                    identifier: "LIKE_BACK",
                    title: "Like Back",
                    options: [.authenticationRequired]
                )
            ]
        case .superLike:
            return [
                UNNotificationAction(
                    identifier: "VIEW_PROFILE",
                    title: "View Profile",
                    options: .foreground
                ),
                UNNotificationAction(
                    identifier: "LIKE_BACK",
                    title: "Like Back",
                    options: [.authenticationRequired]
                ),
                UNNotificationAction(
                    identifier: "SUPER_LIKE_BACK",
                    title: "⭐ Super Like Back",
                    options: [.authenticationRequired]
                )
            ]
        case .dailyDigest:
            return [
                UNNotificationAction(
                    identifier: "OPEN_APP",
                    title: "See Activity",
                    options: .foreground
                ),
                UNNotificationAction(
                    identifier: "DISMISS",
                    title: "Later",
                    options: []
                )
            ]
        case .matchReminder:
            return [
                UNTextInputNotificationAction(
                    identifier: "SEND_MESSAGE",
                    title: "Send Message",
                    options: [.authenticationRequired],
                    textInputButtonTitle: "Send",
                    textInputPlaceholder: "Start the conversation..."
                ),
                UNNotificationAction(
                    identifier: "VIEW_MATCH",
                    title: "View Profile",
                    options: .foreground
                ),
                UNNotificationAction(
                    identifier: "SNOOZE",
                    title: "Remind Later",
                    options: []
                )
            ]
        case .messageReminder:
            return [
                UNTextInputNotificationAction(
                    identifier: "REPLY",
                    title: "Reply Now",
                    options: [.authenticationRequired],
                    textInputButtonTitle: "Send",
                    textInputPlaceholder: "Type your reply..."
                ),
                UNNotificationAction(
                    identifier: "VIEW_CONVERSATION",
                    title: "View Chat",
                    options: .foreground
                )
            ]
        case .premiumOffer:
            return [
                UNNotificationAction(
                    identifier: "VIEW_OFFER",
                    title: "View Offer",
                    options: .foreground
                ),
                UNNotificationAction(
                    identifier: "DISMISS",
                    title: "Not Now",
                    options: []
                )
            ]
        case .generalUpdate:
            return [
                UNNotificationAction(
                    identifier: "OPEN_APP",
                    title: "Open App",
                    options: .foreground
                )
            ]
        // Admin notification actions
        case .adminNewReport:
            return [
                UNNotificationAction(
                    identifier: "VIEW_REPORT",
                    title: "View Report",
                    options: .foreground
                ),
                UNNotificationAction(
                    identifier: "DISMISS_REPORT",
                    title: "Dismiss",
                    options: []
                )
            ]
        case .adminNewAccount:
            return [
                UNNotificationAction(
                    identifier: "REVIEW_ACCOUNT",
                    title: "Review Account",
                    options: .foreground
                ),
                UNNotificationAction(
                    identifier: "APPROVE_ACCOUNT",
                    title: "Approve",
                    options: [.authenticationRequired]
                )
            ]
        case .adminIdVerification:
            return [
                UNNotificationAction(
                    identifier: "REVIEW_ID",
                    title: "Review ID",
                    options: .foreground
                ),
                UNNotificationAction(
                    identifier: "APPROVE_ID",
                    title: "Approve",
                    options: [.authenticationRequired]
                ),
                UNNotificationAction(
                    identifier: "REJECT_ID",
                    title: "Reject",
                    options: [.destructive, .authenticationRequired]
                )
            ]
        case .adminSuspiciousActivity:
            return [
                UNNotificationAction(
                    identifier: "INVESTIGATE",
                    title: "Investigate",
                    options: .foreground
                ),
                UNNotificationAction(
                    identifier: "BAN_USER",
                    title: "Ban User",
                    options: [.destructive, .authenticationRequired]
                )
            ]
        }
    }

    var options: UNNotificationCategoryOptions {
        switch self {
        case .newMessage, .messageReminder:
            // Allow previews and custom dismiss for messages
            return [.customDismissAction, .allowInCarPlay]
        case .newMatch, .superLike, .newLike, .profileView:
            // Hide previews for privacy-sensitive notifications
            return [.customDismissAction, .hiddenPreviewsShowTitle]
        case .dailyDigest:
            // Daily digest - allow previews
            return [.customDismissAction]
        case .premiumOffer:
            // No special options for marketing
            return [.customDismissAction]
        case .matchReminder, .generalUpdate:
            return [.customDismissAction]
        // Admin notifications - high priority with sound
        case .adminNewReport, .adminNewAccount, .adminIdVerification, .adminSuspiciousActivity:
            return [.customDismissAction, .allowAnnouncement]
        }
    }

    /// Summary argument for notification grouping
    var summaryArgument: String {
        switch self {
        case .newMatch:
            return "matches"
        case .newMessage, .messageReminder:
            return "messages"
        case .profileView:
            return "views"
        case .newLike, .superLike:
            return "likes"
        case .dailyDigest:
            return "updates"
        case .premiumOffer:
            return "offers"
        case .matchReminder:
            return "reminders"
        case .generalUpdate:
            return "updates"
        // Admin notifications
        case .adminNewReport:
            return "reports"
        case .adminNewAccount:
            return "accounts"
        case .adminIdVerification:
            return "verifications"
        case .adminSuspiciousActivity:
            return "alerts"
        }
    }
}

// MARK: - Notification Payload

enum NotificationPayload {
    case newMatch(matchName: String, matchId: String, imageURL: URL?)
    case newMessage(senderName: String, message: String, matchId: String, imageURL: URL?)
    case profileView(viewerName: String, viewerId: String, imageURL: URL?)
    case newLike(likerName: String?, likerId: String, likeCount: Int, imageURL: URL?)
    case superLike(likerName: String, likerId: String, imageURL: URL?)
    case dailyDigest(newLikes: Int, newMatches: Int, unreadMessages: Int)
    case premiumOffer(title: String, body: String)
    case matchReminder(matchName: String, matchId: String, imageURL: URL?)
    case messageReminder(matchName: String, matchId: String, imageURL: URL?)
    // Admin notifications
    case adminNewReport(reporterName: String, reportedName: String, reason: String, reportId: String)
    case adminNewAccount(userName: String, userId: String, photoURL: URL?)
    case adminIdVerification(userName: String, userId: String, idType: String, photoURL: URL?)
    case adminSuspiciousActivity(userName: String, userId: String, activityType: String, riskScore: Int)

    var category: NotificationCategory {
        switch self {
        case .newMatch:
            return .newMatch
        case .newMessage:
            return .newMessage
        case .profileView:
            return .profileView
        case .newLike:
            return .newLike
        case .superLike:
            return .superLike
        case .dailyDigest:
            return .dailyDigest
        case .premiumOffer:
            return .premiumOffer
        case .matchReminder:
            return .matchReminder
        case .messageReminder:
            return .messageReminder
        case .adminNewReport:
            return .adminNewReport
        case .adminNewAccount:
            return .adminNewAccount
        case .adminIdVerification:
            return .adminIdVerification
        case .adminSuspiciousActivity:
            return .adminSuspiciousActivity
        }
    }

    var title: String {
        switch self {
        case .newMatch(let matchName, _, _):
            return Self.randomMatchTitle(name: matchName)
        case .newMessage(let senderName, _, _, _):
            return senderName
        case .profileView(let viewerName, _, _):
            return Self.randomProfileViewTitle(name: viewerName)
        case .newLike(let likerName, _, let likeCount, _):
            return Self.randomNewLikeTitle(name: likerName, count: likeCount)
        case .superLike(let likerName, _, _):
            return Self.randomSuperLikeTitle(name: likerName)
        case .dailyDigest(let newLikes, let newMatches, let unreadMessages):
            return Self.dailyDigestTitle(likes: newLikes, matches: newMatches, messages: unreadMessages)
        case .premiumOffer(let title, _):
            return title
        case .matchReminder(let matchName, _, _):
            return Self.randomMatchReminderTitle(name: matchName)
        case .messageReminder(let matchName, _, _):
            return Self.randomMessageReminderTitle(name: matchName)
        // Admin notifications
        case .adminNewReport(_, let reportedName, _, _):
            return "New Report: \(reportedName)"
        case .adminNewAccount(let userName, _, _):
            return "New Account: \(userName)"
        case .adminIdVerification(let userName, _, let idType, _):
            return "ID Verification: \(userName) (\(idType))"
        case .adminSuspiciousActivity(let userName, _, let activityType, _):
            return "Alert: \(activityType) - \(userName)"
        }
    }

    var body: String {
        switch self {
        case .newMatch(let matchName, _, _):
            return Self.randomMatchBody(name: matchName)
        case .newMessage(_, let message, _, _):
            return message
        case .profileView(let viewerName, _, _):
            return Self.randomProfileViewBody(name: viewerName)
        case .newLike(let likerName, _, let likeCount, _):
            return Self.randomNewLikeBody(name: likerName, count: likeCount)
        case .superLike(let likerName, _, _):
            return Self.randomSuperLikeBody(name: likerName)
        case .dailyDigest(let newLikes, let newMatches, let unreadMessages):
            return Self.dailyDigestBody(likes: newLikes, matches: newMatches, messages: unreadMessages)
        case .premiumOffer(_, let body):
            return body
        case .matchReminder(let matchName, _, _):
            return Self.randomMatchReminderBody(name: matchName)
        case .messageReminder(let matchName, _, _):
            return Self.randomMessageReminderBody(name: matchName)
        // Admin notifications
        case .adminNewReport(let reporterName, _, let reason, _):
            return "Reported by \(reporterName): \(reason)"
        case .adminNewAccount:
            return "A new account needs review"
        case .adminIdVerification:
            return "ID verification request pending review"
        case .adminSuspiciousActivity(_, _, _, let riskScore):
            return "Risk score: \(riskScore)/100 - Tap to investigate"
        }
    }

    // MARK: - Engaging Notification Templates

    private static func randomMatchTitle(name: String) -> String {
        let titles = [
            "It's a match with \(name)!",
            "You matched with \(name)!",
            "\(name) likes you too!",
            "New match: \(name)",
            "Sparks flying with \(name)!"
        ]
        return titles.randomElement() ?? "New Match with \(name)!"
    }

    private static func randomMatchBody(name: String) -> String {
        let bodies = [
            "Say hi before someone else does!",
            "Start chatting now - don't keep \(name) waiting!",
            "Your next conversation could change everything.",
            "The first message matters - make it count!",
            "Break the ice and say hello!"
        ]
        return bodies.randomElement() ?? "Start a conversation now!"
    }

    private static func randomProfileViewTitle(name: String) -> String {
        let titles = [
            "\(name) checked you out",
            "Someone's interested...",
            "\(name) viewed your profile",
            "You caught \(name)'s eye",
            "\(name) is curious about you"
        ]
        return titles.randomElement() ?? "\(name) viewed your profile"
    }

    private static func randomProfileViewBody(name: String) -> String {
        let bodies = [
            "Like them back before they move on!",
            "See if you're a match - tap to view",
            "Could this be the one? Check out their profile",
            "They made the first move. Your turn!",
            "Don't miss your chance - see their profile now"
        ]
        return bodies.randomElement() ?? "Tap to view their profile"
    }

    private static func randomSuperLikeTitle(name: String) -> String {
        let titles = [
            "\(name) SUPER Liked you!",
            "Someone really likes you!",
            "\(name) thinks you're special",
            "You got a Super Like from \(name)!",
            "\(name) went all in on you!"
        ]
        return titles.randomElement() ?? "\(name) Super Liked you!"
    }

    private static func randomSuperLikeBody(name: String) -> String {
        let bodies = [
            "They really wanted you to notice. Will you?",
            "This is rare - \(name) saved their Super Like for you!",
            "You stood out from everyone else!",
            "Super Likes mean they're serious about you",
            "Out of everyone, they picked YOU!"
        ]
        return bodies.randomElement() ?? "They really like you!"
    }

    private static func randomMatchReminderTitle(name: String) -> String {
        let titles = [
            "Don't forget about \(name)!",
            "\(name) is still waiting...",
            "Say something to \(name)!",
            "Your match with \(name) needs attention",
            "Time to break the ice with \(name)!"
        ]
        return titles.randomElement() ?? "Say hi to \(name)!"
    }

    private static func randomMatchReminderBody(name: String) -> String {
        let bodies = [
            "Matches fade fast - send a message now!",
            "The longer you wait, the harder it gets",
            "A simple 'hey' could lead to something great",
            "Don't let this connection slip away",
            "They swiped right on you for a reason!"
        ]
        return bodies.randomElement() ?? "Don't let this match expire"
    }

    private static func randomMessageReminderTitle(name: String) -> String {
        let titles = [
            "\(name) is waiting for you",
            "You left \(name) hanging!",
            "Don't ghost \(name)!",
            "Reply to \(name)?",
            "\(name) wants to hear from you"
        ]
        return titles.randomElement() ?? "Reply to \(name)"
    }

    private static func randomMessageReminderBody(name: String) -> String {
        let bodies = [
            "Keep the conversation going!",
            "They're probably checking their phone right now...",
            "A quick reply keeps the spark alive",
            "Don't leave them on read!",
            "Good things happen when you show up"
        ]
        return bodies.randomElement() ?? "They're waiting for your response"
    }

    private static func randomNewLikeTitle(name: String?, count: Int) -> String {
        if let name = name {
            // Premium users see who liked them
            let titles = [
                "\(name) likes you!",
                "\(name) is interested in you",
                "You caught \(name)'s attention!",
                "\(name) wants to meet you",
                "Someone special likes you: \(name)"
            ]
            return titles.randomElement() ?? "\(name) likes you!"
        } else {
            // Free users see mystery notification
            if count > 1 {
                let titles = [
                    "You have \(count) new likes!",
                    "\(count) people like you!",
                    "\(count) new admirers are waiting",
                    "You're getting noticed! \(count) new likes"
                ]
                return titles.randomElement() ?? "You have \(count) new likes!"
            } else {
                let titles = [
                    "Someone likes you!",
                    "You have a secret admirer",
                    "Someone swiped right on you!",
                    "You're being noticed!",
                    "A new admirer is waiting"
                ]
                return titles.randomElement() ?? "Someone likes you!"
            }
        }
    }

    private static func randomNewLikeBody(name: String?, count: Int) -> String {
        if name != nil {
            let bodies = [
                "Like them back to start chatting!",
                "Will you match with them?",
                "Open the app to see their profile",
                "Tap to see if you're a match!",
                "Don't keep them waiting!"
            ]
            return bodies.randomElement() ?? "Like them back to start chatting!"
        } else {
            let bodies = [
                "Upgrade to see who likes you!",
                "Go Premium to reveal your admirers",
                "Find out who's interested in you",
                "Your next match could be waiting!",
                "See who's crushing on you"
            ]
            return bodies.randomElement() ?? "Upgrade to see who likes you!"
        }
    }

    private static func dailyDigestTitle(likes: Int, matches: Int, messages: Int) -> String {
        if matches > 0 {
            return matches == 1 ? "You got a new match!" : "You got \(matches) new matches!"
        } else if likes > 0 {
            return likes == 1 ? "Someone new likes you!" : "\(likes) people like you!"
        } else if messages > 0 {
            return messages == 1 ? "You have an unread message" : "You have \(messages) unread messages"
        } else {
            let titles = [
                "Your dating life awaits!",
                "New people are nearby",
                "Time to find your match!",
                "Ready to meet someone new?"
            ]
            return titles.randomElement() ?? "Your dating life awaits!"
        }
    }

    private static func dailyDigestBody(likes: Int, matches: Int, messages: Int) -> String {
        var parts: [String] = []

        if likes > 0 {
            parts.append("\(likes) new like\(likes == 1 ? "" : "s")")
        }
        if matches > 0 {
            parts.append("\(matches) new match\(matches == 1 ? "" : "es")")
        }
        if messages > 0 {
            parts.append("\(messages) unread message\(messages == 1 ? "" : "s")")
        }

        if parts.isEmpty {
            let bodies = [
                "New profiles are waiting to be discovered!",
                "Swipe now - your perfect match could be next!",
                "Don't miss out on today's connections",
                "The more you swipe, the more you match!"
            ]
            return bodies.randomElement() ?? "Open the app to see what's new!"
        }

        return parts.joined(separator: " • ") + " - Tap to see!"
    }

    var imageURL: URL? {
        switch self {
        case .newMatch(_, _, let url),
             .newMessage(_, _, _, let url),
             .profileView(_, _, let url),
             .newLike(_, _, _, let url),
             .superLike(_, _, let url),
             .matchReminder(_, _, let url),
             .messageReminder(_, _, let url):
            return url
        case .dailyDigest, .premiumOffer:
            return nil
        // Admin notifications
        case .adminNewAccount(_, _, let url),
             .adminIdVerification(_, _, _, let url):
            return url
        case .adminNewReport, .adminSuspiciousActivity:
            return nil
        }
    }

    var userInfo: [AnyHashable: Any] {
        var info: [AnyHashable: Any] = ["category": category.identifier]

        switch self {
        case .newMatch(let matchName, let matchId, _):
            info["matchName"] = matchName
            info["matchId"] = matchId
        case .newMessage(let senderName, let message, let matchId, _):
            info["senderName"] = senderName
            info["message"] = message
            info["matchId"] = matchId
        case .profileView(let viewerName, let viewerId, _):
            info["viewerName"] = viewerName
            info["viewerId"] = viewerId
        case .newLike(let likerName, let likerId, let likeCount, _):
            if let likerName = likerName {
                info["likerName"] = likerName
            }
            info["likerId"] = likerId
            info["likeCount"] = likeCount
        case .superLike(let likerName, let likerId, _):
            info["likerName"] = likerName
            info["likerId"] = likerId
        case .dailyDigest(let newLikes, let newMatches, let unreadMessages):
            info["newLikes"] = newLikes
            info["newMatches"] = newMatches
            info["unreadMessages"] = unreadMessages
        case .premiumOffer:
            break
        case .matchReminder(let matchName, let matchId, _):
            info["matchName"] = matchName
            info["matchId"] = matchId
        case .messageReminder(let matchName, let matchId, _):
            info["matchName"] = matchName
            info["matchId"] = matchId
        // Admin notifications
        case .adminNewReport(let reporterName, let reportedName, let reason, let reportId):
            info["reporterName"] = reporterName
            info["reportedName"] = reportedName
            info["reason"] = reason
            info["reportId"] = reportId
            info["isAdmin"] = true
        case .adminNewAccount(let userName, let userId, _):
            info["userName"] = userName
            info["userId"] = userId
            info["isAdmin"] = true
        case .adminIdVerification(let userName, let userId, let idType, _):
            info["userName"] = userName
            info["userId"] = userId
            info["idType"] = idType
            info["isAdmin"] = true
        case .adminSuspiciousActivity(let userName, let userId, let activityType, let riskScore):
            info["userName"] = userName
            info["userId"] = userId
            info["activityType"] = activityType
            info["riskScore"] = riskScore
            info["isAdmin"] = true
        }

        if let url = imageURL {
            info["imageURL"] = url.absoluteString
        }

        return info
    }
}

// MARK: - Notification Preferences

@MainActor
class NotificationPreferences: ObservableObject {
    static let shared = NotificationPreferences()

    // MARK: - Published Properties

    @Published var newMatchesEnabled: Bool {
        didSet { save() }
    }

    @Published var newMessagesEnabled: Bool {
        didSet { save() }
    }

    @Published var profileViewsEnabled: Bool {
        didSet { save() }
    }

    @Published var newLikesEnabled: Bool {
        didSet { save() }
    }

    @Published var superLikesEnabled: Bool {
        didSet { save() }
    }

    @Published var dailyDigestEnabled: Bool {
        didSet { save() }
    }

    @Published var premiumOffersEnabled: Bool {
        didSet { save() }
    }

    @Published var generalUpdatesEnabled: Bool {
        didSet { save() }
    }

    @Published var matchRemindersEnabled: Bool {
        didSet { save() }
    }

    @Published var messageRemindersEnabled: Bool {
        didSet { save() }
    }

    // Account & Safety notifications
    @Published var accountStatusEnabled: Bool {
        didSet { save() }
    }

    @Published var accountWarningsEnabled: Bool {
        didSet { save() }
    }

    @Published var verificationUpdatesEnabled: Bool {
        didSet { save() }
    }

    // Admin notifications (only relevant for admin users)
    @Published var adminNewAccountsEnabled: Bool {
        didSet { save() }
    }

    @Published var adminReportsEnabled: Bool {
        didSet { save() }
    }

    @Published var adminIdVerificationEnabled: Bool {
        didSet { save() }
    }

    @Published var adminSuspiciousActivityEnabled: Bool {
        didSet { save() }
    }

    @Published var quietHoursEnabled: Bool {
        didSet { save() }
    }

    @Published var quietHoursStart: Date {
        didSet { save() }
    }

    @Published var quietHoursEnd: Date {
        didSet { save() }
    }

    @Published var soundEnabled: Bool {
        didSet { save() }
    }

    @Published var vibrationEnabled: Bool {
        didSet { save() }
    }

    @Published var showPreview: Bool {
        didSet { save() }
    }

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let newMatchesEnabled = "notif_new_matches"
        static let newMessagesEnabled = "notif_new_messages"
        static let profileViewsEnabled = "notif_profile_views"
        static let newLikesEnabled = "notif_new_likes"
        static let superLikesEnabled = "notif_super_likes"
        static let dailyDigestEnabled = "notif_daily_digest"
        static let premiumOffersEnabled = "notif_premium_offers"
        static let generalUpdatesEnabled = "notif_general_updates"
        static let matchRemindersEnabled = "notif_match_reminders"
        static let messageRemindersEnabled = "notif_message_reminders"
        static let accountStatusEnabled = "notif_account_status"
        static let accountWarningsEnabled = "notif_account_warnings"
        static let verificationUpdatesEnabled = "notif_verification_updates"
        static let adminNewAccountsEnabled = "notif_admin_new_accounts"
        static let adminReportsEnabled = "notif_admin_reports"
        static let adminIdVerificationEnabled = "notif_admin_id_verification"
        static let adminSuspiciousActivityEnabled = "notif_admin_suspicious_activity"
        static let quietHoursEnabled = "notif_quiet_hours_enabled"
        static let quietHoursStart = "notif_quiet_hours_start"
        static let quietHoursEnd = "notif_quiet_hours_end"
        static let soundEnabled = "notif_sound_enabled"
        static let vibrationEnabled = "notif_vibration_enabled"
        static let showPreview = "notif_show_preview"
    }

    // MARK: - Initialization

    private init() {
        // Load saved preferences or use defaults
        self.newMatchesEnabled = UserDefaults.standard.bool(forKey: Keys.newMatchesEnabled, default: true)
        self.newMessagesEnabled = UserDefaults.standard.bool(forKey: Keys.newMessagesEnabled, default: true)
        self.profileViewsEnabled = UserDefaults.standard.bool(forKey: Keys.profileViewsEnabled, default: true)
        self.newLikesEnabled = UserDefaults.standard.bool(forKey: Keys.newLikesEnabled, default: true)
        self.superLikesEnabled = UserDefaults.standard.bool(forKey: Keys.superLikesEnabled, default: true)
        self.dailyDigestEnabled = UserDefaults.standard.bool(forKey: Keys.dailyDigestEnabled, default: true)
        self.premiumOffersEnabled = UserDefaults.standard.bool(forKey: Keys.premiumOffersEnabled, default: false)
        self.generalUpdatesEnabled = UserDefaults.standard.bool(forKey: Keys.generalUpdatesEnabled, default: true)
        self.matchRemindersEnabled = UserDefaults.standard.bool(forKey: Keys.matchRemindersEnabled, default: true)
        self.messageRemindersEnabled = UserDefaults.standard.bool(forKey: Keys.messageRemindersEnabled, default: true)
        self.accountStatusEnabled = UserDefaults.standard.bool(forKey: Keys.accountStatusEnabled, default: true)
        self.accountWarningsEnabled = UserDefaults.standard.bool(forKey: Keys.accountWarningsEnabled, default: true)
        self.verificationUpdatesEnabled = UserDefaults.standard.bool(forKey: Keys.verificationUpdatesEnabled, default: true)
        self.adminNewAccountsEnabled = UserDefaults.standard.bool(forKey: Keys.adminNewAccountsEnabled, default: true)
        self.adminReportsEnabled = UserDefaults.standard.bool(forKey: Keys.adminReportsEnabled, default: true)
        self.adminIdVerificationEnabled = UserDefaults.standard.bool(forKey: Keys.adminIdVerificationEnabled, default: true)
        self.adminSuspiciousActivityEnabled = UserDefaults.standard.bool(forKey: Keys.adminSuspiciousActivityEnabled, default: true)
        self.quietHoursEnabled = UserDefaults.standard.bool(forKey: Keys.quietHoursEnabled, default: false)
        self.soundEnabled = UserDefaults.standard.bool(forKey: Keys.soundEnabled, default: true)
        self.vibrationEnabled = UserDefaults.standard.bool(forKey: Keys.vibrationEnabled, default: true)
        self.showPreview = UserDefaults.standard.bool(forKey: Keys.showPreview, default: true)

        // Load quiet hours or use defaults (10 PM - 8 AM)
        if let startData = UserDefaults.standard.data(forKey: Keys.quietHoursStart),
           let start = try? JSONDecoder().decode(Date.self, from: startData) {
            self.quietHoursStart = start
        } else {
            var components = DateComponents()
            components.hour = 22
            components.minute = 0
            self.quietHoursStart = Calendar.current.date(from: components) ?? Date()
        }

        if let endData = UserDefaults.standard.data(forKey: Keys.quietHoursEnd),
           let end = try? JSONDecoder().decode(Date.self, from: endData) {
            self.quietHoursEnd = end
        } else {
            var components = DateComponents()
            components.hour = 8
            components.minute = 0
            self.quietHoursEnd = Calendar.current.date(from: components) ?? Date()
        }
    }

    // MARK: - Public Methods

    func isEnabled(for category: NotificationCategory) -> Bool {
        switch category {
        case .newMatch:
            return newMatchesEnabled
        case .newMessage:
            return newMessagesEnabled
        case .profileView:
            return profileViewsEnabled
        case .newLike:
            return newLikesEnabled
        case .superLike:
            return superLikesEnabled
        case .dailyDigest:
            return dailyDigestEnabled
        case .premiumOffer:
            return premiumOffersEnabled
        case .generalUpdate:
            return generalUpdatesEnabled
        case .matchReminder:
            return matchRemindersEnabled
        case .messageReminder:
            return messageRemindersEnabled
        // Admin notifications - controlled by admin preferences
        case .adminNewReport:
            return adminReportsEnabled
        case .adminNewAccount:
            return adminNewAccountsEnabled
        case .adminIdVerification:
            return adminIdVerificationEnabled
        case .adminSuspiciousActivity:
            return adminSuspiciousActivityEnabled
        }
    }

    func isInQuietHours() -> Bool {
        guard quietHoursEnabled else { return false }

        let now = Date()
        let calendar = Calendar.current
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        let startComponents = calendar.dateComponents([.hour, .minute], from: quietHoursStart)
        let endComponents = calendar.dateComponents([.hour, .minute], from: quietHoursEnd)

        let nowMinutes = (nowComponents.hour ?? 0) * 60 + (nowComponents.minute ?? 0)
        let startMinutes = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
        let endMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)

        if startMinutes < endMinutes {
            // Normal range (e.g., 9 AM - 5 PM)
            return nowMinutes >= startMinutes && nowMinutes < endMinutes
        } else {
            // Overnight range (e.g., 10 PM - 8 AM)
            return nowMinutes >= startMinutes || nowMinutes < endMinutes
        }
    }

    func enableAll() {
        newMatchesEnabled = true
        newMessagesEnabled = true
        profileViewsEnabled = true
        newLikesEnabled = true
        superLikesEnabled = true
        dailyDigestEnabled = true
        premiumOffersEnabled = true
        generalUpdatesEnabled = true
        matchRemindersEnabled = true
        messageRemindersEnabled = true
        accountStatusEnabled = true
        accountWarningsEnabled = true
        verificationUpdatesEnabled = true
        adminNewAccountsEnabled = true
        adminReportsEnabled = true
        adminIdVerificationEnabled = true
        adminSuspiciousActivityEnabled = true
    }

    func disableAll() {
        newMatchesEnabled = false
        newMessagesEnabled = false
        profileViewsEnabled = false
        newLikesEnabled = false
        superLikesEnabled = false
        dailyDigestEnabled = false
        premiumOffersEnabled = false
        generalUpdatesEnabled = false
        matchRemindersEnabled = false
        messageRemindersEnabled = false
        // Note: Account safety notifications remain enabled for user protection
        // accountStatusEnabled, accountWarningsEnabled, verificationUpdatesEnabled stay on
    }

    func resetToDefaults() {
        newMatchesEnabled = true
        newMessagesEnabled = true
        profileViewsEnabled = true
        newLikesEnabled = true
        superLikesEnabled = true
        dailyDigestEnabled = true
        premiumOffersEnabled = false
        generalUpdatesEnabled = true
        matchRemindersEnabled = true
        messageRemindersEnabled = true
        accountStatusEnabled = true
        accountWarningsEnabled = true
        verificationUpdatesEnabled = true
        adminNewAccountsEnabled = true
        adminReportsEnabled = true
        adminIdVerificationEnabled = true
        adminSuspiciousActivityEnabled = true
        quietHoursEnabled = false
        soundEnabled = true
        vibrationEnabled = true
        showPreview = true
    }

    // MARK: - Private Methods

    private func save() {
        UserDefaults.standard.set(newMatchesEnabled, forKey: Keys.newMatchesEnabled)
        UserDefaults.standard.set(newMessagesEnabled, forKey: Keys.newMessagesEnabled)
        UserDefaults.standard.set(profileViewsEnabled, forKey: Keys.profileViewsEnabled)
        UserDefaults.standard.set(newLikesEnabled, forKey: Keys.newLikesEnabled)
        UserDefaults.standard.set(superLikesEnabled, forKey: Keys.superLikesEnabled)
        UserDefaults.standard.set(dailyDigestEnabled, forKey: Keys.dailyDigestEnabled)
        UserDefaults.standard.set(premiumOffersEnabled, forKey: Keys.premiumOffersEnabled)
        UserDefaults.standard.set(generalUpdatesEnabled, forKey: Keys.generalUpdatesEnabled)
        UserDefaults.standard.set(matchRemindersEnabled, forKey: Keys.matchRemindersEnabled)
        UserDefaults.standard.set(messageRemindersEnabled, forKey: Keys.messageRemindersEnabled)
        UserDefaults.standard.set(accountStatusEnabled, forKey: Keys.accountStatusEnabled)
        UserDefaults.standard.set(accountWarningsEnabled, forKey: Keys.accountWarningsEnabled)
        UserDefaults.standard.set(verificationUpdatesEnabled, forKey: Keys.verificationUpdatesEnabled)
        UserDefaults.standard.set(adminNewAccountsEnabled, forKey: Keys.adminNewAccountsEnabled)
        UserDefaults.standard.set(adminReportsEnabled, forKey: Keys.adminReportsEnabled)
        UserDefaults.standard.set(adminIdVerificationEnabled, forKey: Keys.adminIdVerificationEnabled)
        UserDefaults.standard.set(adminSuspiciousActivityEnabled, forKey: Keys.adminSuspiciousActivityEnabled)
        UserDefaults.standard.set(quietHoursEnabled, forKey: Keys.quietHoursEnabled)
        UserDefaults.standard.set(soundEnabled, forKey: Keys.soundEnabled)
        UserDefaults.standard.set(vibrationEnabled, forKey: Keys.vibrationEnabled)
        UserDefaults.standard.set(showPreview, forKey: Keys.showPreview)

        if let startData = try? JSONEncoder().encode(quietHoursStart) {
            UserDefaults.standard.set(startData, forKey: Keys.quietHoursStart)
        }

        if let endData = try? JSONEncoder().encode(quietHoursEnd) {
            UserDefaults.standard.set(endData, forKey: Keys.quietHoursEnd)
        }
    }
}

// MARK: - Notification Preference Item

struct NotificationPreferenceItem: Identifiable {
    let id = UUID()
    let category: NotificationCategory
    let title: String
    let description: String
    let icon: String

    static let allItems: [NotificationPreferenceItem] = [
        NotificationPreferenceItem(
            category: .newMatch,
            title: "Matches & Likes",
            description: "Get notified when someone matches or likes you",
            icon: "heart.fill"
        ),
        NotificationPreferenceItem(
            category: .newMessage,
            title: "Messages",
            description: "Get notified when someone messages you",
            icon: "message.fill"
        )
    ]
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        if object(forKey: key) == nil {
            return defaultValue
        }
        return bool(forKey: key)
    }
}
