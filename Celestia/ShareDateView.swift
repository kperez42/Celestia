//
//  ShareDateView.swift
//  Celestia
//
//  Share date details with trusted contacts for safety
//

import SwiftUI
import FirebaseFirestore
import MapKit

struct ShareDateView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = ShareDateViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var selectedMatch: User?
    @State private var dateTime = Date()
    @State private var location = ""
    @State private var additionalNotes = ""
    @State private var selectedContacts: Set<EmergencyContact> = []

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Date Details
                dateDetailsSection

                // Emergency Contacts
                contactsSection

                // Share Button
                shareButton
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Share Your Date")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadEmergencyContacts()
        }
        .sheet(item: $viewModel.shareConfirmation) { confirmation in
            DateSharedConfirmationView(confirmation: confirmation)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.badge.gearshape")
                .font(.system(size: 50))
                .foregroundColor(.blue)

            Text("Stay Safe on Your Date")
                .font(.title2.bold())

            Text("Share your date plans with trusted contacts. They'll receive your details and can check in on you.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(16)
    }

    // MARK: - Date Details Section

    private var dateDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Date Details")
                .font(.headline)

            VStack(spacing: 16) {
                // Match Selection
                Button {
                    // TODO: Show match picker
                } label: {
                    HStack {
                        Image(systemName: "person.crop.circle")
                            .font(.title2)
                            .foregroundColor(.purple)

                        VStack(alignment: .leading) {
                            Text("Who are you meeting?")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(selectedMatch?.fullName ?? "Select match")
                                .font(.body)
                                .foregroundColor(.primary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                }

                // Date & Time
                VStack(alignment: .leading, spacing: 8) {
                    Label("Date & Time", systemImage: "calendar.clock")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    DatePicker("", selection: $dateTime, in: Date()...)
                        .datePickerStyle(.graphical)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                }

                // Location
                VStack(alignment: .leading, spacing: 8) {
                    Label("Location", systemImage: "mappin.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("Restaurant name or address", text: $location)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                }

                // Additional Notes
                VStack(alignment: .leading, spacing: 8) {
                    Label("Additional Notes (Optional)", systemImage: "note.text")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextEditor(text: $additionalNotes)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
    }

    // MARK: - Contacts Section

    private var contactsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Share With")
                    .font(.headline)

                Spacer()

                NavigationLink {
                    EmergencyContactsView()
                } label: {
                    Text("Manage")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }

            if viewModel.emergencyContacts.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))

                    Text("No Emergency Contacts")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Add trusted contacts who can check on you during your date.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    NavigationLink {
                        EmergencyContactsView()
                    } label: {
                        Text("Add Contacts")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(12)
            } else {
                // Contacts list
                VStack(spacing: 8) {
                    ForEach(viewModel.emergencyContacts) { contact in
                        ContactSelectionRow(
                            contact: contact,
                            isSelected: selectedContacts.contains(contact)
                        ) {
                            if selectedContacts.contains(contact) {
                                selectedContacts.remove(contact)
                            } else {
                                selectedContacts.insert(contact)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Share Button

    private var shareButton: some View {
        Button {
            Task {
                await viewModel.shareDateDetails(
                    match: selectedMatch,
                    dateTime: dateTime,
                    location: location,
                    notes: additionalNotes,
                    contacts: Array(selectedContacts)
                )
            }
        } label: {
            HStack {
                Image(systemName: "paperplane.fill")
                Text("Share Date Details")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
        }
        .disabled(!viewModel.canShare(
            match: selectedMatch,
            location: location,
            contacts: selectedContacts
        ))
        .opacity(viewModel.canShare(
            match: selectedMatch,
            location: location,
            contacts: selectedContacts
        ) ? 1.0 : 0.5)
    }
}

// MARK: - Contact Selection Row

struct ContactSelectionRow: View {
    let contact: EmergencyContact
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Profile image
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(contact.name.prefix(1))
                            .font(.headline)
                            .foregroundColor(.blue)
                    )

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name)
                        .font(.body)
                        .foregroundColor(.primary)

                    Text(contact.phoneNumber)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Checkmark
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .gray.opacity(0.3))
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Date Shared Confirmation View

struct DateSharedConfirmationView: View {
    let confirmation: DateShareConfirmation
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Success Icon
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 100, height: 100)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                }

                // Message
                VStack(spacing: 12) {
                    Text("Date Details Shared!")
                        .font(.title.bold())

                    Text("Your trusted contacts have been notified and will receive updates.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Shared with
                VStack(alignment: .leading, spacing: 12) {
                    Text("Shared with:")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    ForEach(confirmation.sharedWith, id: \.self) { name in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(name)
                                .font(.body)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGroupedBackground))
                .cornerRadius(12)

                Spacer()

                // Done Button
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(16)
                }
            }
            .padding()
            .navigationTitle("Success")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Models

struct DateShareConfirmation: Identifiable {
    let id = UUID()
    let sharedWith: [String]
    let dateTime: Date
}

// MARK: - View Model

@MainActor
class ShareDateViewModel: ObservableObject {
    @Published var emergencyContacts: [EmergencyContact] = []
    @Published var shareConfirmation: DateShareConfirmation?

    private let db = Firestore.firestore()

    func loadEmergencyContacts() async {
        guard let userId = AuthService.shared.currentUser?.id else { return }

        do {
            let snapshot = try await db.collection("emergency_contacts")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()

            emergencyContacts = snapshot.documents.compactMap { doc in
                let contact = try? doc.data(as: EmergencyContact.self)
                // Filter for contacts that have date alerts enabled
                return contact?.notificationPreferences.receiveScheduledDateAlerts == true ? contact : nil
            }

            Logger.shared.info("Loaded \(emergencyContacts.count) emergency contacts", category: .general)
        } catch {
            Logger.shared.error("Error loading emergency contacts", category: .general, error: error)
        }
    }

    func canShare(match: User?, location: String, contacts: Set<EmergencyContact>) -> Bool {
        match != nil && !location.isEmpty && !contacts.isEmpty
    }

    func shareDateDetails(
        match: User?,
        dateTime: Date,
        location: String,
        notes: String,
        contacts: [EmergencyContact]
    ) async {
        guard let match = match, let userId = AuthService.shared.currentUser?.id else { return }

        do {
            let dateShare: [String: Any] = [
                "userId": userId,
                "matchId": match.id as Any,
                "matchName": match.fullName,
                "dateTime": Timestamp(date: dateTime),
                "location": location,
                "notes": notes,
                "sharedWith": contacts.map { $0.id },
                "sharedAt": Timestamp(date: Date()),
                "status": "active"
            ]

            try await db.collection("shared_dates").addDocument(data: dateShare)

            // Send notifications to contacts
            for contact in contacts {
                try await sendDateNotification(to: contact, match: match, dateTime: dateTime, location: location)
            }

            shareConfirmation = DateShareConfirmation(
                sharedWith: contacts.map { $0.name },
                dateTime: dateTime
            )

            AnalyticsServiceEnhanced.shared.trackEvent(
                .featureUsed,
                properties: [
                    "feature": "share_date",
                    "contactsCount": contacts.count
                ]
            )

            Logger.shared.info("Date details shared with \(contacts.count) contacts", category: .general)
        } catch {
            Logger.shared.error("Error sharing date details", category: .general, error: error)
        }
    }

    private func sendDateNotification(
        to contact: EmergencyContact,
        match: User,
        dateTime: Date,
        location: String
    ) async throws {
        // TODO: Implement actual SMS/notification sending
        // For now, just log
        Logger.shared.info("Sending date notification to \(contact.name)", category: .general)
    }
}

#Preview {
    NavigationStack {
        ShareDateView()
            .environmentObject(AuthService.shared)
    }
}
