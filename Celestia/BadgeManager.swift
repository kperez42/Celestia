//
//  BadgeManager.swift
//  Celestia
//
//  Manages app icon badge count across different notification types
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Badge Manager

@MainActor
class BadgeManager: ObservableObject {

    // MARK: - Singleton

    static let shared = BadgeManager()

    // MARK: - Published Properties

    @Published private(set) var totalBadgeCount: Int = 0
    @Published private(set) var unmatchedMessagesCount: Int = 0
    @Published private(set) var newMatchesCount: Int = 0
    @Published private(set) var profileViewsCount: Int = 0

    // MARK: - Private Properties

    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let unreadMessages = "badge_unread_messages"
        static let newMatches = "badge_new_matches"
        static let profileViews = "badge_profile_views"
    }

    // MARK: - Initialization

    private init() {
        loadCounts()
        updateTotal()
        Logger.shared.info("BadgeManager initialized", category: .general)
    }

    // MARK: - Public Methods

    /// Update unread messages count
    func setUnreadMessages(_ count: Int) {
        unmatchedMessagesCount = max(0, count)
        defaults.set(unmatchedMessagesCount, forKey: Keys.unreadMessages)
        updateTotal()

        Logger.shared.debug("Unread messages updated: \(unmatchedMessagesCount)", category: .general)
    }

    /// Increment unread messages
    func incrementUnreadMessages() {
        setUnreadMessages(unmatchedMessagesCount + 1)
    }

    /// Update new matches count
    func setNewMatches(_ count: Int) {
        newMatchesCount = max(0, count)
        defaults.set(newMatchesCount, forKey: Keys.newMatches)
        updateTotal()

        Logger.shared.debug("New matches updated: \(newMatchesCount)", category: .general)
    }

    /// Increment new matches
    func incrementNewMatches() {
        setNewMatches(newMatchesCount + 1)
    }

    /// Update profile views count
    func setProfileViews(_ count: Int) {
        profileViewsCount = max(0, count)
        defaults.set(profileViewsCount, forKey: Keys.profileViews)
        updateTotal()

        Logger.shared.debug("Profile views updated: \(profileViewsCount)", category: .general)
    }

    /// Increment profile views
    func incrementProfileViews() {
        setProfileViews(profileViewsCount + 1)
    }

    /// Clear all badge counts
    func clearAll() {
        setUnreadMessages(0)
        setNewMatches(0)
        setProfileViews(0)

        Logger.shared.info("All badge counts cleared", category: .general)
    }

    /// Clear specific category
    func clear(_ category: BadgeCategory) {
        switch category {
        case .messages:
            setUnreadMessages(0)
        case .matches:
            setNewMatches(0)
        case .profileViews:
            setProfileViews(0)
        }
    }

    // MARK: - Private Methods

    private func loadCounts() {
        unmatchedMessagesCount = defaults.integer(forKey: Keys.unreadMessages)
        newMatchesCount = defaults.integer(forKey: Keys.newMatches)
        profileViewsCount = defaults.integer(forKey: Keys.profileViews)
    }

    private func updateTotal() {
        let newTotal = unmatchedMessagesCount + newMatchesCount + profileViewsCount
        totalBadgeCount = newTotal

        // Update app icon badge
        UIApplication.shared.applicationIconBadgeNumber = totalBadgeCount

        // Update push notification manager
        PushNotificationManager.shared.updateBadgeCount(totalBadgeCount)

        Logger.shared.debug("Total badge count: \(totalBadgeCount)", category: .general)
    }

    // MARK: - Badge Category

    enum BadgeCategory {
        case messages
        case matches
        case profileViews
    }
}

// MARK: - Badge Count View

struct BadgeCountView: View {
    let count: Int
    let color: Color

    var body: some View {
        if count > 0 {
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, count > 9 ? 6 : 8)
                .padding(.vertical, 4)
                .background(color)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Tab Badge Modifier

extension View {
    func tabBadge(_ count: Int) -> some View {
        self.badge(count > 0 ? "\(count)" : nil)
    }
}
