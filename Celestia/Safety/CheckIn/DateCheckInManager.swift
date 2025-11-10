//
//  DateCheckInManager.swift
//  Celestia
//
//  Date check-in feature for user safety during in-person meetings
//  Allows users to share date details with trusted contacts and check in
//

import Foundation
import CoreLocation
import UserNotifications

// MARK: - Date Check-In Manager

@MainActor
class DateCheckInManager: ObservableObject {

    // MARK: - Singleton

    static let shared = DateCheckInManager()

    // MARK: - Published Properties

    @Published var activeCheckIn: DateCheckIn?
    @Published var checkInHistory: [DateCheckIn] = []
    @Published var missedCheckIns: [DateCheckIn] = []

    // MARK: - Private Properties

    private let emergencyContactManager = EmergencyContactManager.shared
    private let locationManager = CLLocationManager()

    // MARK: - Initialization

    private init() {
        loadCheckInHistory()
        checkForMissedCheckIns()
        Logger.shared.info("DateCheckInManager initialized", category: .general)
    }

    // MARK: - Create Check-In

    /// Create a new date check-in
    func createCheckIn(
        matchName: String,
        matchId: String,
        location: DateLocation,
        scheduledTime: Date,
        expectedDuration: TimeInterval
    ) async throws -> DateCheckIn {

        Logger.shared.info("Creating date check-in for: \(matchName)", category: .general)

        // Ensure user has emergency contacts
        guard !emergencyContactManager.contacts.isEmpty else {
            throw CheckInError.noEmergencyContacts
        }

        // Create check-in
        let checkIn = DateCheckIn(
            id: UUID().uuidString,
            matchName: matchName,
            matchId: matchId,
            location: location,
            scheduledTime: scheduledTime,
            expectedEndTime: scheduledTime.addingTimeInterval(expectedDuration),
            status: .scheduled,
            createdAt: Date()
        )

        // Schedule notifications
        try await scheduleCheckInNotifications(checkIn)

        // Notify emergency contacts
        await notifyEmergencyContacts(checkIn, event: .scheduled)

        // Save
        activeCheckIn = checkIn
        checkInHistory.append(checkIn)
        saveCheckInHistory()

        // Track analytics
        AnalyticsManager.shared.logEvent(.dateCheckInCreated, parameters: [
            "duration_hours": expectedDuration / 3600,
            "has_location": true
        ])

        Logger.shared.info("Date check-in created successfully", category: .general)

        return checkIn
    }

    // MARK: - Check-In Actions

    /// Check in at the start of the date
    func checkInAtStart() async throws {
        guard var checkIn = activeCheckIn else {
            throw CheckInError.noActiveCheckIn
        }

        Logger.shared.info("User checking in at start of date", category: .general)

        checkIn.status = .inProgress
        checkIn.actualStartTime = Date()

        // Get current location if available
        if let location = getCurrentLocation() {
            checkIn.actualLocation = location
        }

        activeCheckIn = checkIn
        updateCheckInHistory(checkIn)

        // Notify emergency contacts
        await notifyEmergencyContacts(checkIn, event: .started)

        // Schedule mid-date check-in reminder
        try await scheduleCheckInReminder(checkIn)

        // Track analytics
        AnalyticsManager.shared.logEvent(.dateCheckInStarted, parameters: [:])

        Logger.shared.info("Check-in at start completed", category: .general)
    }

    /// Check in during the date
    func checkInDuringDate() async throws {
        guard var checkIn = activeCheckIn else {
            throw CheckInError.noActiveCheckIn
        }

        Logger.shared.info("User checking in during date", category: .general)

        checkIn.midDateCheckIns.append(Date())

        activeCheckIn = checkIn
        updateCheckInHistory(checkIn)

        // Track analytics
        AnalyticsManager.shared.logEvent(.dateCheckInMid, parameters: [:])
    }

    /// Check in at the end of the date (safe return)
    func checkInAtEnd(rating: SafetyRating?) async throws {
        guard var checkIn = activeCheckIn else {
            throw CheckInError.noActiveCheckIn
        }

        Logger.shared.info("User checking in at end of date", category: .general)

        checkIn.status = .completed
        checkIn.actualEndTime = Date()
        checkIn.safetyRating = rating

        activeCheckIn = nil
        updateCheckInHistory(checkIn)

        // Notify emergency contacts
        await notifyEmergencyContacts(checkIn, event: .completed)

        // Cancel all pending notifications
        cancelCheckInNotifications(checkIn)

        // Track analytics
        AnalyticsManager.shared.logEvent(.dateCheckInCompleted, parameters: [
            "safety_rating": rating?.rawValue ?? "none",
            "duration_minutes": checkIn.actualDuration ?? 0
        ])

        Logger.shared.info("Check-in at end completed", category: .general)
    }

    /// Trigger emergency alert
    func triggerEmergency() async throws {
        guard var checkIn = activeCheckIn else {
            throw CheckInError.noActiveCheckIn
        }

        Logger.shared.warning("EMERGENCY ALERT TRIGGERED", category: .general)

        checkIn.status = .emergency
        checkIn.emergencyTriggeredAt = Date()

        // Get current location
        if let location = getCurrentLocation() {
            checkIn.actualLocation = location
        }

        activeCheckIn = checkIn
        updateCheckInHistory(checkIn)

        // Send emergency alerts to all contacts
        await sendEmergencyAlerts(checkIn)

        // Track analytics
        AnalyticsManager.shared.logEvent(.emergencyAlertTriggered, parameters: [
            "has_location": checkIn.actualLocation != nil
        ])

        Logger.shared.error("Emergency alerts sent", category: .general)
    }

    // MARK: - Notifications

    private func scheduleCheckInNotifications(_ checkIn: DateCheckIn) async throws {
        let center = UNUserNotificationCenter.current()

        // Notification 1: Before date starts (30 minutes before)
        let beforeDateContent = UNMutableNotificationContent()
        beforeDateContent.title = "Date Safety Reminder"
        beforeDateContent.body = "Your date with \(checkIn.matchName) starts soon. Remember to check in!"
        beforeDateContent.sound = .default

        let beforeDateTrigger = UNTimeIntervalNotificationTrigger(
            timeInterval: checkIn.scheduledTime.timeIntervalSinceNow - 1800,
            repeats: false
        )

        let beforeDateRequest = UNNotificationRequest(
            identifier: "check_in_before_\(checkIn.id)",
            content: beforeDateContent,
            trigger: beforeDateTrigger
        )

        try await center.add(beforeDateRequest)

        // Notification 2: Expected end time
        let endTimeContent = UNMutableNotificationContent()
        endTimeContent.title = "Check In Reminder"
        endTimeContent.body = "Are you safe? Please check in to let your contacts know you're okay."
        endTimeContent.sound = .default
        endTimeContent.categoryIdentifier = "CHECK_IN_REMINDER"

        let endTimeTrigger = UNTimeIntervalNotificationTrigger(
            timeInterval: checkIn.expectedEndTime.timeIntervalSinceNow,
            repeats: false
        )

        let endTimeRequest = UNNotificationRequest(
            identifier: "check_in_end_\(checkIn.id)",
            content: endTimeContent,
            trigger: endTimeTrigger
        )

        try await center.add(endTimeRequest)

        // Notification 3: Overdue check-in (30 minutes after expected end)
        let overdueContent = UNMutableNotificationContent()
        overdueContent.title = "⚠️ Safety Check Required"
        overdueContent.body = "You haven't checked in. Your emergency contacts will be notified if you don't respond."
        overdueContent.sound = .defaultCritical
        overdueContent.categoryIdentifier = "CHECK_IN_OVERDUE"

        let overdueTrigger = UNTimeIntervalNotificationTrigger(
            timeInterval: checkIn.expectedEndTime.timeIntervalSinceNow + 1800,
            repeats: false
        )

        let overdueRequest = UNNotificationRequest(
            identifier: "check_in_overdue_\(checkIn.id)",
            content: overdueContent,
            trigger: overdueTrigger
        )

        try await center.add(overdueRequest)

        Logger.shared.debug("Scheduled 3 check-in notifications", category: .general)
    }

    private func scheduleCheckInReminder(_ checkIn: DateCheckIn) async throws {
        let center = UNUserNotificationCenter.current()

        // Mid-date check-in (halfway through expected duration)
        let midpoint = checkIn.scheduledTime.addingTimeInterval(
            checkIn.expectedEndTime.timeIntervalSince(checkIn.scheduledTime) / 2
        )

        let content = UNMutableNotificationContent()
        content.title = "Mid-Date Check In"
        content.body = "Everything going well? Tap to check in."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: midpoint.timeIntervalSinceNow,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "check_in_mid_\(checkIn.id)",
            content: content,
            trigger: trigger
        )

        try await center.add(request)
    }

    private func cancelCheckInNotifications(_ checkIn: DateCheckIn) {
        let center = UNUserNotificationCenter.current()

        let identifiers = [
            "check_in_before_\(checkIn.id)",
            "check_in_end_\(checkIn.id)",
            "check_in_overdue_\(checkIn.id)",
            "check_in_mid_\(checkIn.id)"
        ]

        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        Logger.shared.debug("Cancelled check-in notifications", category: .general)
    }

    // MARK: - Emergency Contacts

    private func notifyEmergencyContacts(_ checkIn: DateCheckIn, event: CheckInEvent) async {
        let contacts = emergencyContactManager.contacts

        Logger.shared.info("Notifying \(contacts.count) emergency contacts: \(event.rawValue)", category: .general)

        for contact in contacts {
            await sendNotification(to: contact, checkIn: checkIn, event: event)
        }
    }

    private func sendNotification(
        to contact: EmergencyContact,
        checkIn: DateCheckIn,
        event: CheckInEvent
    ) async {

        let message = generateMessage(for: event, checkIn: checkIn)

        Logger.shared.debug("Sending notification to \(contact.name): \(message)", category: .general)

        // In production, send SMS via Twilio or similar service
        // For now, just log
    }

    private func sendEmergencyAlerts(_ checkIn: DateCheckIn) async {
        let contacts = emergencyContactManager.contacts

        Logger.shared.warning("Sending emergency alerts to \(contacts.count) contacts", category: .general)

        for contact in contacts {
            let message = """
            🚨 EMERGENCY ALERT 🚨

            \(getCurrentUserName()) has triggered an emergency alert during a date.

            Date Details:
            - Match: \(checkIn.matchName)
            - Location: \(checkIn.location.name)
            - Address: \(checkIn.location.address)
            - Time: \(formatDate(checkIn.scheduledTime))

            \(checkIn.actualLocation != nil ? "Current Location: \(formatLocation(checkIn.actualLocation!))" : "")

            Please check on them immediately.
            """

            Logger.shared.error("Emergency alert: \(message)", category: .general)

            // In production, send SMS immediately
        }
    }

    private func generateMessage(for event: CheckInEvent, checkIn: DateCheckIn) -> String {
        let userName = getCurrentUserName()

        switch event {
        case .scheduled:
            return """
            \(userName) has scheduled a date and added you as an emergency contact.

            Date Details:
            - Match: \(checkIn.matchName)
            - Location: \(checkIn.location.name)
            - Time: \(formatDate(checkIn.scheduledTime))

            They will check in when safe.
            """

        case .started:
            return "\(userName) has checked in at the start of their date with \(checkIn.matchName)."

        case .completed:
            return "\(userName) has safely completed their date with \(checkIn.matchName)."

        case .missed:
            return """
            ⚠️ \(userName) has missed their check-in.

            Expected check-in: \(formatDate(checkIn.expectedEndTime))
            Location: \(checkIn.location.name)

            You may want to reach out to them.
            """
        }
    }

    // MARK: - Missed Check-Ins

    private func checkForMissedCheckIns() {
        let now = Date()

        for checkIn in checkInHistory where checkIn.status == .inProgress {
            // Check if expected end time has passed by more than 30 minutes
            if now.timeIntervalSince(checkIn.expectedEndTime) > 1800 {
                handleMissedCheckIn(checkIn)
            }
        }
    }

    private func handleMissedCheckIn(_ checkIn: DateCheckIn) {
        var updatedCheckIn = checkIn
        updatedCheckIn.status = .missed

        missedCheckIns.append(updatedCheckIn)
        updateCheckInHistory(updatedCheckIn)

        // Notify emergency contacts
        Task {
            await notifyEmergencyContacts(updatedCheckIn, event: .missed)
        }

        Logger.shared.warning("Missed check-in detected for date with \(checkIn.matchName)", category: .general)
    }

    // MARK: - Location

    private func getCurrentLocation() -> CLLocationCoordinate2D? {
        // In production, use CLLocationManager
        return nil
    }

    // MARK: - Persistence

    private func loadCheckInHistory() {
        if let data = UserDefaults.standard.data(forKey: "check_in_history"),
           let history = try? JSONDecoder().decode([DateCheckIn].self, from: data) {
            checkInHistory = history
        }
    }

    private func saveCheckInHistory() {
        if let data = try? JSONEncoder().encode(checkInHistory) {
            UserDefaults.standard.set(data, forKey: "check_in_history")
        }
    }

    private func updateCheckInHistory(_ checkIn: DateCheckIn) {
        if let index = checkInHistory.firstIndex(where: { $0.id == checkIn.id }) {
            checkInHistory[index] = checkIn
            saveCheckInHistory()
        }
    }

    // MARK: - Helpers

    private func getCurrentUserName() -> String {
        // In production, get from user profile
        return "User"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatLocation(_ coordinate: CLLocationCoordinate2D) -> String {
        return "\(coordinate.latitude), \(coordinate.longitude)"
    }
}

// MARK: - Date Check-In Model

struct DateCheckIn: Codable, Identifiable {
    let id: String
    let matchName: String
    let matchId: String
    let location: DateLocation
    let scheduledTime: Date
    let expectedEndTime: Date
    var status: CheckInStatus
    var actualStartTime: Date?
    var actualEndTime: Date?
    var actualLocation: CLLocationCoordinate2D?
    var midDateCheckIns: [Date] = []
    var safetyRating: SafetyRating?
    var emergencyTriggeredAt: Date?
    let createdAt: Date

    var actualDuration: TimeInterval? {
        guard let start = actualStartTime, let end = actualEndTime else {
            return nil
        }
        return end.timeIntervalSince(start) / 60 // Minutes
    }
}

// MARK: - Date Location

struct DateLocation: Codable {
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D?
}

// MARK: - Check-In Status

enum CheckInStatus: String, Codable {
    case scheduled = "scheduled"
    case inProgress = "in_progress"
    case completed = "completed"
    case missed = "missed"
    case emergency = "emergency"

    var displayName: String {
        switch self {
        case .scheduled:
            return "Scheduled"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        case .missed:
            return "Missed Check-In"
        case .emergency:
            return "Emergency"
        }
    }

    var icon: String {
        switch self {
        case .scheduled:
            return "calendar"
        case .inProgress:
            return "clock.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .missed:
            return "exclamationmark.triangle.fill"
        case .emergency:
            return "exclamationmark.octagon.fill"
        }
    }
}

// MARK: - Safety Rating

enum SafetyRating: String, Codable {
    case felt_safe = "felt_safe"
    case felt_uncomfortable = "felt_uncomfortable"
    case felt_unsafe = "felt_unsafe"

    var displayName: String {
        switch self {
        case .felt_safe:
            return "Felt Safe"
        case .felt_uncomfortable:
            return "Felt Uncomfortable"
        case .felt_unsafe:
            return "Felt Unsafe"
        }
    }
}

// MARK: - Check-In Event

enum CheckInEvent: String {
    case scheduled = "scheduled"
    case started = "started"
    case completed = "completed"
    case missed = "missed"
}

// MARK: - Errors

enum CheckInError: LocalizedError {
    case noActiveCheckIn
    case noEmergencyContacts
    case locationPermissionDenied

    var errorDescription: String? {
        switch self {
        case .noActiveCheckIn:
            return "No active check-in found"
        case .noEmergencyContacts:
            return "Please add emergency contacts before creating a check-in"
        case .locationPermissionDenied:
            return "Location permission is required for safety check-ins"
        }
    }
}

// MARK: - Extensions
// CLLocationCoordinate2D Codable extension is defined in Search/Models/FilterModels.swift
