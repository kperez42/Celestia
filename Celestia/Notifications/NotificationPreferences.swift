//
//  NotificationPreferences.swift
//  Celestia
//
//  Manages user notification preferences including quiet hours
//

import Foundation
import Combine

// MARK: - Notification Preferences

@MainActor
class NotificationPreferences: ObservableObject {

    // MARK: - Singleton

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

    // Quiet Hours
    @Published var quietHoursEnabled: Bool {
        didSet { save() }
    }

    @Published var quietHoursStart: Date {
        didSet { save() }
    }

    @Published var quietHoursEnd: Date {
        didSet { save() }
    }

    // Sound & Vibration
    @Published var soundEnabled: Bool {
        didSet { save() }
    }

    @Published var vibrationEnabled: Bool {
        didSet { save() }
    }

    // Preview Settings
    @Published var showPreview: Bool {
        didSet { save() }
    }

    // MARK: - Private Properties

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Keys

    private enum Keys {
        static let newMatches = "notification_new_matches"
        static let newMessages = "notification_new_messages"
        static let profileViews = "notification_profile_views"
        static let superLikes = "notification_super_likes"
        static let premiumOffers = "notification_premium_offers"
        static let generalUpdates = "notification_general_updates"
        static let matchReminders = "notification_match_reminders"
        static let messageReminders = "notification_message_reminders"
        static let quietHoursEnabled = "notification_quiet_hours_enabled"
        static let quietHoursStart = "notification_quiet_hours_start"
        static let quietHoursEnd = "notification_quiet_hours_end"
        static let soundEnabled = "notification_sound_enabled"
        static let vibrationEnabled = "notification_vibration_enabled"
        static let showPreview = "notification_show_preview"
    }

    // MARK: - Initialization

    private init() {
        // Load saved preferences or use defaults
        self.newMatchesEnabled = defaults.bool(forKey: Keys.newMatches, default: true)
        self.newMessagesEnabled = defaults.bool(forKey: Keys.newMessages, default: true)
        self.profileViewsEnabled = defaults.bool(forKey: Keys.profileViews, default: true)
        self.superLikesEnabled = defaults.bool(forKey: Keys.superLikes, default: true)
        self.premiumOffersEnabled = defaults.bool(forKey: Keys.premiumOffers, default: false)
        self.generalUpdatesEnabled = defaults.bool(forKey: Keys.generalUpdates, default: true)
        self.matchRemindersEnabled = defaults.bool(forKey: Keys.matchReminders, default: true)
        self.messageRemindersEnabled = defaults.bool(forKey: Keys.messageReminders, default: true)

        self.quietHoursEnabled = defaults.bool(forKey: Keys.quietHoursEnabled, default: false)
        self.quietHoursStart = defaults.date(forKey: Keys.quietHoursStart) ?? Calendar.current.date(from: DateComponents(hour: 22, minute: 0))!
        self.quietHoursEnd = defaults.date(forKey: Keys.quietHoursEnd) ?? Calendar.current.date(from: DateComponents(hour: 8, minute: 0))!

        self.soundEnabled = defaults.bool(forKey: Keys.soundEnabled, default: true)
        self.vibrationEnabled = defaults.bool(forKey: Keys.vibrationEnabled, default: true)
        self.showPreview = defaults.bool(forKey: Keys.showPreview, default: true)

        Logger.shared.info("NotificationPreferences initialized", category: .general)
    }

    // MARK: - Public Methods

    /// Check if a notification category is enabled
    func isEnabled(_ category: NotificationCategory) -> Bool {
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

    /// Check if current time is within quiet hours
    func isInQuietHours() -> Bool {
        guard quietHoursEnabled else { return false }

        let calendar = Calendar.current
        let now = Date()

        let startComponents = calendar.dateComponents([.hour, .minute], from: quietHoursStart)
        let endComponents = calendar.dateComponents([.hour, .minute], from: quietHoursEnd)
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)

        let nowMinutes = (nowComponents.hour ?? 0) * 60 + (nowComponents.minute ?? 0)
        let startMinutes = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
        let endMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)

        // Handle overnight quiet hours (e.g., 22:00 to 08:00)
        if startMinutes > endMinutes {
            return nowMinutes >= startMinutes || nowMinutes < endMinutes
        } else {
            return nowMinutes >= startMinutes && nowMinutes < endMinutes
        }
    }

    /// Enable all notifications
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

    /// Disable all notifications
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

    /// Reset to defaults
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
        quietHoursStart = Calendar.current.date(from: DateComponents(hour: 22, minute: 0))!
        quietHoursEnd = Calendar.current.date(from: DateComponents(hour: 8, minute: 0))!

        soundEnabled = true
        vibrationEnabled = true
        showPreview = true
    }

    // MARK: - Persistence

    private func save() {
        defaults.set(newMatchesEnabled, forKey: Keys.newMatches)
        defaults.set(newMessagesEnabled, forKey: Keys.newMessages)
        defaults.set(profileViewsEnabled, forKey: Keys.profileViews)
        defaults.set(superLikesEnabled, forKey: Keys.superLikes)
        defaults.set(premiumOffersEnabled, forKey: Keys.premiumOffers)
        defaults.set(generalUpdatesEnabled, forKey: Keys.generalUpdates)
        defaults.set(matchRemindersEnabled, forKey: Keys.matchReminders)
        defaults.set(messageRemindersEnabled, forKey: Keys.messageReminders)

        defaults.set(quietHoursEnabled, forKey: Keys.quietHoursEnabled)
        defaults.set(quietHoursStart, forKey: Keys.quietHoursStart)
        defaults.set(quietHoursEnd, forKey: Keys.quietHoursEnd)

        defaults.set(soundEnabled, forKey: Keys.soundEnabled)
        defaults.set(vibrationEnabled, forKey: Keys.vibrationEnabled)
        defaults.set(showPreview, forKey: Keys.showPreview)
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

    func date(forKey key: String) -> Date? {
        return object(forKey: key) as? Date
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
            description: "Get notified when you receive a message",
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
            category: .matchReminder,
            title: "Match Reminders",
            description: "Reminders to message your matches",
            icon: "bell.fill"
        ),
        NotificationPreferenceItem(
            category: .messageReminder,
            title: "Message Reminders",
            description: "Reminders to reply to messages",
            icon: "bubble.left.and.bubble.right.fill"
        ),
        NotificationPreferenceItem(
            category: .premiumOffer,
            title: "Premium Offers",
            description: "Special offers and premium features",
            icon: "crown.fill"
        ),
        NotificationPreferenceItem(
            category: .generalUpdate,
            title: "General Updates",
            description: "App updates and important announcements",
            icon: "info.circle.fill"
        )
    ]
}
