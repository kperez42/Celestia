//
//  EmergencyContactManager.swift
//  Celestia
//
//  Emergency contact management for safety features
//  Allows users to designate trusted contacts who receive safety alerts
//

import Foundation
import Contacts

// MARK: - Emergency Contact Manager

@MainActor
class EmergencyContactManager: ObservableObject {

    // MARK: - Singleton

    static let shared = EmergencyContactManager()

    // MARK: - Published Properties

    @Published var contacts: [EmergencyContact] = []

    // MARK: - Private Properties

    private let maxContacts = 5
    private let contactStore = CNContactStore()

    // MARK: - Initialization

    private init() {
        loadContacts()
        Logger.shared.info("EmergencyContactManager initialized", category: .general)
    }

    // MARK: - Add Contact

    /// Add an emergency contact
    func addContact(
        name: String,
        phoneNumber: String,
        relationship: ContactRelationship,
        email: String? = nil
    ) throws -> EmergencyContact {

        // Validate max contacts
        guard contacts.count < maxContacts else {
            throw ContactError.maxContactsReached
        }

        // Validate phone number
        guard isValidPhoneNumber(phoneNumber) else {
            throw ContactError.invalidPhoneNumber
        }

        // Check for duplicates
        if contacts.contains(where: { $0.phoneNumber == phoneNumber }) {
            throw ContactError.duplicateContact
        }

        // Create contact
        let contact = EmergencyContact(
            id: UUID().uuidString,
            name: name,
            phoneNumber: phoneNumber,
            email: email,
            relationship: relationship,
            addedAt: Date(),
            notificationPreferences: EmergencyNotificationPreferences()
        )

        contacts.append(contact)
        saveContacts()

        // Track analytics
        AnalyticsManager.shared.logEvent(.emergencyContactAdded, parameters: [
            "relationship": relationship.rawValue,
            "total_contacts": contacts.count
        ])

        Logger.shared.info("Emergency contact added: \(name)", category: .general)

        return contact
    }

    /// Import contact from device contacts
    func importFromDeviceContacts() async throws -> [CNContact] {
        // Request access
        let granted = try await contactStore.requestAccess(for: .contacts)

        guard granted else {
            throw ContactError.accessDenied
        }

        // Fetch contacts
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)

        var deviceContacts: [CNContact] = []

        try contactStore.enumerateContacts(with: request) { contact, _ in
            deviceContacts.append(contact)
        }

        Logger.shared.info("Fetched \(deviceContacts.count) contacts from device", category: .general)

        return deviceContacts
    }

    // MARK: - Remove Contact

    /// Remove an emergency contact
    func removeContact(_ contact: EmergencyContact) {
        contacts.removeAll { $0.id == contact.id }
        saveContacts()

        Logger.shared.info("Emergency contact removed: \(contact.name)", category: .general)

        // Track analytics
        AnalyticsManager.shared.logEvent(.emergencyContactRemoved, parameters: [
            "total_contacts": contacts.count
        ])
    }

    // MARK: - Update Contact

    /// Update emergency contact
    func updateContact(_ contact: EmergencyContact) {
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            contacts[index] = contact
            saveContacts()

            Logger.shared.debug("Emergency contact updated: \(contact.name)", category: .general)
        }
    }

    /// Update notification preferences for a contact
    func updateNotificationPreferences(
        for contactId: String,
        preferences: EmergencyNotificationPreferences
    ) {
        if let index = contacts.firstIndex(where: { $0.id == contactId }) {
            contacts[index].notificationPreferences = preferences
            saveContacts()
        }
    }

    // MARK: - Validation

    private func isValidPhoneNumber(_ phoneNumber: String) -> Bool {
        // Remove non-numeric characters
        let digits = phoneNumber.filter { $0.isNumber }

        // US phone numbers: 10 digits
        // International: 10-15 digits
        return digits.count >= 10 && digits.count <= 15
    }

    // MARK: - Persistence

    private func loadContacts() {
        if let data = UserDefaults.standard.data(forKey: "emergency_contacts"),
           let savedContacts = try? JSONDecoder().decode([EmergencyContact].self, from: data) {
            contacts = savedContacts
            Logger.shared.debug("Loaded \(contacts.count) emergency contacts", category: .general)
        }
    }

    private func saveContacts() {
        if let data = try? JSONEncoder().encode(contacts) {
            UserDefaults.standard.set(data, forKey: "emergency_contacts")
        }
    }

    // MARK: - Helpers

    /// Check if user has any emergency contacts
    func hasContacts() -> Bool {
        return !contacts.isEmpty
    }

    /// Get primary contact (first in list)
    func primaryContact() -> EmergencyContact? {
        return contacts.first
    }
}

// MARK: - Emergency Contact Model

struct EmergencyContact: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var phoneNumber: String
    var email: String?
    var relationship: ContactRelationship
    let addedAt: Date
    var notificationPreferences: EmergencyNotificationPreferences

    var formattedPhoneNumber: String {
        // Format phone number for display
        let digits = phoneNumber.filter { $0.isNumber }

        if digits.count == 10 {
            // US format: (123) 456-7890
            let areaCode = digits.prefix(3)
            let firstThree = digits.dropFirst(3).prefix(3)
            let lastFour = digits.dropFirst(6)
            return "(\(areaCode)) \(firstThree)-\(lastFour)"
        }

        return phoneNumber
    }

    // Hashable conformance - use id for hashing
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: EmergencyContact, rhs: EmergencyContact) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Contact Relationship

enum ContactRelationship: String, Codable, CaseIterable, Hashable {
    case family = "family"
    case friend = "friend"
    case partner = "partner"
    case roommate = "roommate"
    case coworker = "coworker"
    case other = "other"

    var displayName: String {
        switch self {
        case .family:
            return "Family Member"
        case .friend:
            return "Friend"
        case .partner:
            return "Partner/Spouse"
        case .roommate:
            return "Roommate"
        case .coworker:
            return "Coworker"
        case .other:
            return "Other"
        }
    }

    var icon: String {
        switch self {
        case .family:
            return "person.3.fill"
        case .friend:
            return "person.2.fill"
        case .partner:
            return "heart.fill"
        case .roommate:
            return "house.fill"
        case .coworker:
            return "briefcase.fill"
        case .other:
            return "person.fill"
        }
    }
}

// MARK: - Notification Preferences

struct EmergencyNotificationPreferences: Codable, Hashable {
    var receiveScheduledDateAlerts: Bool = true
    var receiveCheckInAlerts: Bool = true
    var receiveEmergencyAlerts: Bool = true
    var receiveMissedCheckInAlerts: Bool = true

    var allEnabled: Bool {
        return receiveScheduledDateAlerts &&
               receiveCheckInAlerts &&
               receiveEmergencyAlerts &&
               receiveMissedCheckInAlerts
    }
}

// MARK: - Errors

enum ContactError: LocalizedError {
    case maxContactsReached
    case invalidPhoneNumber
    case duplicateContact
    case accessDenied
    case contactNotFound

    var errorDescription: String? {
        switch self {
        case .maxContactsReached:
            return "You can only add up to 5 emergency contacts"
        case .invalidPhoneNumber:
            return "Please enter a valid phone number"
        case .duplicateContact:
            return "This contact has already been added"
        case .accessDenied:
            return "Please grant access to contacts in Settings"
        case .contactNotFound:
            return "Contact not found"
        }
    }
}
