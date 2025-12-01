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
    case superLike = "SUPER_LIKE"
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
        case .superLike:
            return "Super Like!"
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
        case .newMatch, .superLike, .profileView:
            // Hide previews for privacy-sensitive notifications
            return [.customDismissAction, .hiddenPreviewsShowTitle]
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
        case .superLike:
            return "likes"
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
    case superLike(likerName: String, likerId: String, imageURL: URL?)
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
        case .superLike:
            return .superLike
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
            return "New Match with \(matchName)!"
        case .newMessage(let senderName, _, _, _):
            return senderName
        case .profileView(let viewerName, _, _):
            return "\(viewerName) viewed your profile"
        case .superLike(let likerName, _, _):
            return "\(likerName) Super Liked you!"
        case .premiumOffer(let title, _):
            return title
        case .matchReminder(let matchName, _, _):
            return "Say hi to \(matchName)!"
        case .messageReminder(let matchName, _, _):
            return "Reply to \(matchName)"
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
        case .newMatch:
            return "Start a conversation now!"
        case .newMessage(_, let message, _, _):
            return message
        case .profileView:
            return "Tap to view their profile"
        case .superLike:
            return "They really like you!"
        case .premiumOffer(_, let body):
            return body
        case .matchReminder:
            return "Don't let this match expire"
        case .messageReminder:
            return "They're waiting for your response"
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

    var imageURL: URL? {
        switch self {
        case .newMatch(_, _, let url),
             .newMessage(_, _, _, let url),
             .profileView(_, _, let url),
             .superLike(_, _, let url),
             .matchReminder(_, _, let url),
             .messageReminder(_, _, let url):
            return url
        case .premiumOffer:
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
        case .superLike(let likerName, let likerId, _):
            info["likerName"] = likerName
            info["likerId"] = likerId
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

    @Published var superLikesEnabled: Bool {
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
        static let superLikesEnabled = "notif_super_likes"
        static let premiumOffersEnabled = "notif_premium_offers"
        static let generalUpdatesEnabled = "notif_general_updates"
        static let matchRemindersEnabled = "notif_match_reminders"
        static let messageRemindersEnabled = "notif_message_reminders"
        static let accountStatusEnabled = "notif_account_status"
        static let accountWarningsEnabled = "notif_account_warnings"
        static let verificationUpdatesEnabled = "notif_verification_updates"
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
        self.superLikesEnabled = UserDefaults.standard.bool(forKey: Keys.superLikesEnabled, default: true)
        self.premiumOffersEnabled = UserDefaults.standard.bool(forKey: Keys.premiumOffersEnabled, default: false)
        self.generalUpdatesEnabled = UserDefaults.standard.bool(forKey: Keys.generalUpdatesEnabled, default: true)
        self.matchRemindersEnabled = UserDefaults.standard.bool(forKey: Keys.matchRemindersEnabled, default: true)
        self.messageRemindersEnabled = UserDefaults.standard.bool(forKey: Keys.messageRemindersEnabled, default: true)
        self.accountStatusEnabled = UserDefaults.standard.bool(forKey: Keys.accountStatusEnabled, default: true)
        self.accountWarningsEnabled = UserDefaults.standard.bool(forKey: Keys.accountWarningsEnabled, default: true)
        self.verificationUpdatesEnabled = UserDefaults.standard.bool(forKey: Keys.verificationUpdatesEnabled, default: true)
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
        case .superLike:
            return superLikesEnabled
        case .premiumOffer:
            return premiumOffersEnabled
        case .generalUpdate:
            return generalUpdatesEnabled
        case .matchReminder:
            return matchRemindersEnabled
        case .messageReminder:
            return messageRemindersEnabled
        // Admin notifications are always enabled for admin users
        case .adminNewReport, .adminNewAccount, .adminIdVerification, .adminSuspiciousActivity:
            return true
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
        superLikesEnabled = true
        premiumOffersEnabled = true
        generalUpdatesEnabled = true
        matchRemindersEnabled = true
        messageRemindersEnabled = true
        accountStatusEnabled = true
        accountWarningsEnabled = true
        verificationUpdatesEnabled = true
    }

    func disableAll() {
        newMatchesEnabled = false
        newMessagesEnabled = false
        profileViewsEnabled = false
        superLikesEnabled = false
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
        superLikesEnabled = true
        premiumOffersEnabled = false
        generalUpdatesEnabled = true
        matchRemindersEnabled = true
        messageRemindersEnabled = true
        accountStatusEnabled = true
        accountWarningsEnabled = true
        verificationUpdatesEnabled = true
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
        UserDefaults.standard.set(superLikesEnabled, forKey: Keys.superLikesEnabled)
        UserDefaults.standard.set(premiumOffersEnabled, forKey: Keys.premiumOffersEnabled)
        UserDefaults.standard.set(generalUpdatesEnabled, forKey: Keys.generalUpdatesEnabled)
        UserDefaults.standard.set(matchRemindersEnabled, forKey: Keys.matchRemindersEnabled)
        UserDefaults.standard.set(messageRemindersEnabled, forKey: Keys.messageRemindersEnabled)
        UserDefaults.standard.set(accountStatusEnabled, forKey: Keys.accountStatusEnabled)
        UserDefaults.standard.set(accountWarningsEnabled, forKey: Keys.accountWarningsEnabled)
        UserDefaults.standard.set(verificationUpdatesEnabled, forKey: Keys.verificationUpdatesEnabled)
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
            title: "New Matches",
            description: "Get notified when you have a new match",
            icon: "heart.fill"
        ),
        NotificationPreferenceItem(
            category: .newMessage,
            title: "New Messages",
            description: "Get notified when someone messages you",
            icon: "message.fill"
        ),
        NotificationPreferenceItem(
            category: .profileView,
            title: "Profile Views",
            description: "Get notified when someone views your profile",
            icon: "eye.fill"
        ),
        NotificationPreferenceItem(
            category: .superLike,
            title: "Super Likes",
            description: "Get notified when someone super likes you",
            icon: "star.fill"
        ),
        NotificationPreferenceItem(
            category: .premiumOffer,
            title: "Premium Offers",
            description: "Get notified about special offers and promotions",
            icon: "gift.fill"
        ),
        NotificationPreferenceItem(
            category: .generalUpdate,
            title: "General Updates",
            description: "Get notified about app updates and news",
            icon: "bell.fill"
        ),
        NotificationPreferenceItem(
            category: .matchReminder,
            title: "Match Reminders",
            description: "Get reminded to message your matches",
            icon: "clock.fill"
        ),
        NotificationPreferenceItem(
            category: .messageReminder,
            title: "Message Reminders",
            description: "Get reminded to reply to messages",
            icon: "envelope.fill"
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
