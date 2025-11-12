//
//  NotificationModels.swift
//  Celestia
//
//  Models and types for notification system
//

import Foundation
import Combine

// MARK: - Notification Category

enum NotificationCategory: String, CaseIterable, Codable {
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

// MARK: - Notification Data

struct NotificationData: Codable, Identifiable {
    let id: String
    let type: NotificationCategory
    let title: String
    let body: String
    let timestamp: Date
    let userId: String?
    let matchId: String?
    let imageURL: String?
    var isRead: Bool

    init(
        id: String = UUID().uuidString,
        type: NotificationCategory,
        title: String,
        body: String,
        timestamp: Date,
        userId: String? = nil,
        matchId: String? = nil,
        imageURL: String? = nil,
        isRead: Bool = false
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.timestamp = timestamp
        self.userId = userId
        self.matchId = matchId
        self.imageURL = imageURL
        self.isRead = isRead
    }
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
