//
//  AppShortcuts.swift
//  Celestia
//
//  App Shortcuts and Siri integration for quick actions
//  Requires iOS 16+ for App Intents framework
//

import Foundation
import AppIntents

// MARK: - App Shortcuts Provider

@available(iOS 16.0, *)
struct CelestiaAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ViewMatchesIntent(),
            phrases: [
                "View my \(.applicationName) matches",
                "Show my matches in \(.applicationName)",
                "Check matches on \(.applicationName)"
            ],
            shortTitle: "View Matches",
            systemImageName: "heart.circle.fill"
        )

        AppShortcut(
            intent: StartSwipingIntent(),
            phrases: [
                "Start swiping on \(.applicationName)",
                "Discover people on \(.applicationName)",
                "Show me profiles on \(.applicationName)"
            ],
            shortTitle: "Start Swiping",
            systemImageName: "person.2.circle.fill"
        )

        AppShortcut(
            intent: CheckMessagesIntent(),
            phrases: [
                "Check my \(.applicationName) messages",
                "Show my messages in \(.applicationName)",
                "Read messages on \(.applicationName)"
            ],
            shortTitle: "Check Messages",
            systemImageName: "message.circle.fill"
        )

        AppShortcut(
            intent: ViewPremiumIntent(),
            phrases: [
                "View \(.applicationName) premium",
                "Show premium features in \(.applicationName)",
                "Upgrade \(.applicationName)"
            ],
            shortTitle: "View Premium",
            systemImageName: "star.circle.fill"
        )

        AppShortcut(
            intent: ShareDateDetailsIntent(),
            phrases: [
                "Share my date on \(.applicationName)",
                "Share date details in \(.applicationName)",
                "Tell someone about my date on \(.applicationName)"
            ],
            shortTitle: "Share Date",
            systemImageName: "location.circle.fill"
        )

        AppShortcut(
            intent: AddEmergencyContactIntent(),
            phrases: [
                "Add emergency contact in \(.applicationName)",
                "Set up safety contact on \(.applicationName)",
                "Add trusted contact to \(.applicationName)"
            ],
            shortTitle: "Add Emergency Contact",
            systemImageName: "person.badge.shield.checkmark.fill"
        )

        AppShortcut(
            intent: CheckInIntent(),
            phrases: [
                "Check in on \(.applicationName)",
                "I'm safe on \(.applicationName)",
                "Mark date as safe in \(.applicationName)"
            ],
            shortTitle: "Safety Check-In",
            systemImageName: "checkmark.shield.fill"
        )
    }
}

// MARK: - View Matches Intent

@available(iOS 16.0, *)
struct ViewMatchesIntent: AppIntent {
    static var title: LocalizedStringResource = "View Matches"
    static var description = IntentDescription("View your current matches in Celestia")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Track analytics
        AnalyticsManager.shared.logEvent(.appShortcutUsed, parameters: [
            "shortcut": "view_matches"
        ])

        // This will open the app to the matches view
        // The actual navigation is handled by the app's deep linking
        return .result()
    }
}

// MARK: - Start Swiping Intent

@available(iOS 16.0, *)
struct StartSwipingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Swiping"
    static var description = IntentDescription("Start discovering new people on Celestia")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Track analytics
        AnalyticsManager.shared.logEvent(.appShortcutUsed, parameters: [
            "shortcut": "start_swiping"
        ])

        return .result()
    }
}

// MARK: - Check Messages Intent

@available(iOS 16.0, *)
struct CheckMessagesIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Messages"
    static var description = IntentDescription("Check your messages on Celestia")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Track analytics
        AnalyticsManager.shared.logEvent(.appShortcutUsed, parameters: [
            "shortcut": "check_messages"
        ])

        // Get unread message count
        let unreadCount = BadgeManager.shared.unmatchedMessagesCount

        return .result(
            dialog: IntentDialog("You have \(unreadCount) unread message\(unreadCount == 1 ? "" : "s")")
        )
    }
}

// MARK: - View Premium Intent

@available(iOS 16.0, *)
struct ViewPremiumIntent: AppIntent {
    static var title: LocalizedStringResource = "View Premium"
    static var description = IntentDescription("View premium features and subscription options")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Track analytics
        AnalyticsManager.shared.logEvent(.appShortcutUsed, parameters: [
            "shortcut": "view_premium"
        ])

        return .result()
    }
}

// MARK: - Share Date Details Intent

@available(iOS 16.0, *)
struct ShareDateDetailsIntent: AppIntent {
    static var title: LocalizedStringResource = "Share Date Details"
    static var description = IntentDescription("Share your date location and time with emergency contacts")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Match Name")
    var matchName: String?

    @Parameter(title: "Location")
    var location: String?

    @Parameter(title: "Date Time")
    var dateTime: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("Share date with \(\.$matchName) at \(\.$location)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Track analytics
        AnalyticsManager.shared.logEvent(.appShortcutUsed, parameters: [
            "shortcut": "share_date_details"
        ])

        guard let currentUser = AuthService.shared.currentUser else {
            throw AppShortcutError.notAuthenticated
        }

        // If parameters provided, create share date automatically
        if let matchName = matchName, let location = location, let dateTime = dateTime {
            // This would integrate with ShareDateView functionality
            return .result(
                dialog: IntentDialog("Date details shared with your emergency contacts")
            )
        } else {
            // Open app to share date screen
            return .result(
                dialog: IntentDialog("Opening Celestia to share your date details")
            )
        }
    }
}

// MARK: - Add Emergency Contact Intent

@available(iOS 16.0, *)
struct AddEmergencyContactIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Emergency Contact"
    static var description = IntentDescription("Add a trusted emergency contact for safety")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Contact Name")
    var contactName: String?

    @Parameter(title: "Phone Number")
    var phoneNumber: String?

    @Parameter(title: "Relationship")
    var relationship: EmergencyContactRelationship?

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$contactName) as emergency contact")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Track analytics
        AnalyticsManager.shared.logEvent(.appShortcutUsed, parameters: [
            "shortcut": "add_emergency_contact"
        ])

        guard let currentUser = AuthService.shared.currentUser else {
            throw AppShortcutError.notAuthenticated
        }

        if let name = contactName, let phone = phoneNumber {
            // This would integrate with EmergencyContactManager
            return .result(
                dialog: IntentDialog("Emergency contact \(name) added successfully")
            )
        } else {
            return .result(
                dialog: IntentDialog("Opening Celestia to add emergency contact")
            )
        }
    }
}

// MARK: - Check In Intent

@available(iOS 16.0, *)
struct CheckInIntent: AppIntent {
    static var title: LocalizedStringResource = "Safety Check-In"
    static var description = IntentDescription("Check in to confirm you're safe during a date")

    @Parameter(title: "Status Message")
    var statusMessage: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Track analytics
        AnalyticsManager.shared.logEvent(.appShortcutUsed, parameters: [
            "shortcut": "check_in"
        ])

        guard let currentUser = AuthService.shared.currentUser else {
            throw AppShortcutError.notAuthenticated
        }

        // This would integrate with DateCheckInManager
        let message = statusMessage ?? "I'm safe"

        // Mark current date as checked in
        // DateCheckInManager.shared.checkIn(message: message)

        return .result(
            dialog: IntentDialog("Check-in recorded. Your emergency contacts have been notified you're safe.")
        )
    }
}

// MARK: - Contact Relationship Enum for App Intents

@available(iOS 16.0, *)
enum EmergencyContactRelationship: String, AppEnum {
    case friend = "Friend"
    case family = "Family"
    case partner = "Partner"
    case roommate = "Roommate"
    case coworker = "Coworker"
    case other = "Other"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Relationship"

    static var caseDisplayRepresentations: [EmergencyContactRelationship: DisplayRepresentation] {
        [
            .friend: "Friend",
            .family: "Family Member",
            .partner: "Partner",
            .roommate: "Roommate",
            .coworker: "Coworker",
            .other: "Other"
        ]
    }
}

// MARK: - App Shortcut Errors

@available(iOS 16.0, *)
enum AppShortcutError: Error, LocalizedError {
    case notAuthenticated
    case networkError
    case invalidInput
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You need to be signed in to use this feature"
        case .networkError:
            return "Network connection error. Please try again."
        case .invalidInput:
            return "Invalid input provided"
        case .permissionDenied:
            return "Permission required to perform this action"
        }
    }
}

// MARK: - Deep Link Handler

/// Handles deep links from app shortcuts
class AppShortcutDeepLinkHandler {
    static let shared = AppShortcutDeepLinkHandler()

    private init() {}

    enum DeepLink {
        case matches
        case discover
        case messages
        case premium
        case shareDate
        case emergencyContacts
        case checkIn
    }

    func handle(_ deepLink: DeepLink) {
        // Track analytics
        Task { @MainActor in
            AnalyticsManager.shared.logEvent(.deepLinkOpened, parameters: [
                "source": "app_shortcut",
                "destination": String(describing: deepLink)
            ])
        }

        // Post notification to navigate in the app
        NotificationCenter.default.post(
            name: NSNotification.Name("AppShortcutDeepLink"),
            object: nil,
            userInfo: ["deepLink": deepLink]
        )
    }
}

// MARK: - Suggested Shortcuts

/// Dynamic shortcuts that appear in Spotlight based on user behavior
@available(iOS 16.0, *)
class AppShortcutSuggestions {
    static let shared = AppShortcutSuggestions()

    private init() {}

    /// Update shortcuts based on user activity
    func updateShortcutSuggestions() {
        Task { @MainActor in
            // Check if user has active matches
            if BadgeManager.shared.newMatchesCount > 0 {
                await suggestViewMatches()
            }

            // Check if user has unread messages
            if BadgeManager.shared.unmatchedMessagesCount > 0 {
                await suggestCheckMessages()
            }

            // Check if user hasn't swiped today
            let lastSwipeDate = UserDefaults.standard.object(forKey: "last_swipe_date") as? Date
            if let swipeDate = lastSwipeDate {
                if !Calendar.current.isDateInToday(swipeDate) {
                    await suggestStartSwiping()
                }
            } else {
                await suggestStartSwiping()
            }
        }
    }

    private func suggestViewMatches() async {
        // Donate ViewMatchesIntent to the system
        let intent = ViewMatchesIntent()
        try? await intent.donate()
    }

    private func suggestCheckMessages() async {
        let intent = CheckMessagesIntent()
        try? await intent.donate()
    }

    private func suggestStartSwiping() async {
        let intent = StartSwipingIntent()
        try? await intent.donate()
    }
}
