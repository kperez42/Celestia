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
    @State private var showMatchPicker = false
    @State private var animateHeader = false

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
        .background(
            // Premium gradient background
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.08),
                    Color.purple.opacity(0.05),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .onAppear {
            animateHeader = true
        }
        .navigationTitle("Share Your Date")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadEmergencyContacts()
        }
        .sheet(item: $viewModel.shareConfirmation) { confirmation in
            DateSharedConfirmationView(confirmation: confirmation)
        }
        .sheet(isPresented: $showMatchPicker) {
            MatchPickerView(selectedMatch: $selectedMatch)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                // Radial glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.blue.opacity(0.25),
                                Color.purple.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)
                    .scaleEffect(animateHeader ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: animateHeader)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.2), .purple.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)

                Image(systemName: "person.2.badge.gearshape")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.pulse, options: .repeating)
            }

            VStack(spacing: 8) {
                Text("Stay Safe on Your Date")
                    .font(.title2.bold())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("Share your date plans with trusted contacts. They'll receive your details and can check in on you.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .blue.opacity(0.08), radius: 15, y: 5)
                .shadow(color: .black.opacity(0.03), radius: 5, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Date Details Section

    private var dateDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.2), .pink.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 16))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text("Date Details")
                    .font(.headline)
            }

            VStack(spacing: 16) {
                // Match Selection
                Button {
                    showMatchPicker = true
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [.purple.opacity(0.2), .purple.opacity(0.08), Color.clear],
                                        center: .center,
                                        startRadius: 5,
                                        endRadius: 22
                                    )
                                )
                                .frame(width: 44, height: 44)

                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple.opacity(0.15), .pink.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 36, height: 36)

                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 16))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Who are you meeting?")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(selectedMatch?.fullName ?? "Select match")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .purple.opacity(0.06), radius: 10, y: 5)
                            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.1), Color.pink.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                }

                // Date & Time
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.clock")
                            .font(.system(size: 14))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("Date & Time")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }

                    DatePicker("", selection: $dateTime, in: Date()...)
                        .datePickerStyle(.graphical)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                        )
                }

                // Location
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("Location")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }

                    TextField("Restaurant name or address", text: $location)
                        .textFieldStyle(.plain)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                        )
                }

                // Additional Notes
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "note.text")
                            .font(.system(size: 14))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green, .mint],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("Additional Notes (Optional)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }

                    TextEditor(text: $additionalNotes)
                        .frame(height: 100)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .cornerRadius(14)
                        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                        )
                }
            }
        }
    }

    // MARK: - Contacts Section

    private var contactsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.green.opacity(0.2), .mint.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)

                        Image(systemName: "person.2.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green, .mint],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    Text("Share With")
                        .font(.headline)
                }

                Spacer()

                NavigationLink {
                    EmergencyContactsView()
                } label: {
                    Text("Manage")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }

            if viewModel.emergencyContacts.isEmpty {
                // Empty state
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.gray.opacity(0.15), .gray.opacity(0.05), Color.clear],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 60
                                )
                            )
                            .frame(width: 120, height: 120)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.gray.opacity(0.1), .gray.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)

                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 36))
                            .foregroundColor(.gray.opacity(0.5))
                    }

                    VStack(spacing: 8) {
                        Text("No Emergency Contacts")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Add trusted contacts who can check on you during your date.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    NavigationLink {
                        EmergencyContactsView()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Contacts")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
                )
            } else {
                // Contacts list
                VStack(spacing: 10) {
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
            HStack(spacing: 14) {
                // Profile image
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    (isSelected ? Color.green : Color.blue).opacity(0.2),
                                    (isSelected ? Color.green : Color.blue).opacity(0.08),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 5,
                                endRadius: 25
                            )
                        )
                        .frame(width: 50, height: 50)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isSelected
                                    ? [.green.opacity(0.2), .mint.opacity(0.15)]
                                    : [.blue.opacity(0.15), .cyan.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Text(contact.name.prefix(1))
                        .font(.headline)
                        .foregroundStyle(
                            LinearGradient(
                                colors: isSelected ? [.green, .mint] : [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(contact.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(contact.phoneNumber)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Checkmark
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.green.opacity(0.15) : Color.gray.opacity(0.08))
                        .frame(width: 32, height: 32)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(
                            isSelected
                                ? LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: isSelected ? .green.opacity(0.08) : .black.opacity(0.04), radius: 10, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: isSelected
                                ? [Color.green.opacity(0.2), Color.mint.opacity(0.1)]
                                : [Color.gray.opacity(0.1), Color.gray.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Date Shared Confirmation View

struct DateSharedConfirmationView: View {
    let confirmation: DateShareConfirmation
    @Environment(\.dismiss) var dismiss
    @State private var animateSuccess = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Success Icon
                ZStack {
                    // Outer radial glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.green.opacity(0.3),
                                    Color.mint.opacity(0.15),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 30,
                                endRadius: 90
                            )
                        )
                        .frame(width: 180, height: 180)
                        .scaleEffect(animateSuccess ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animateSuccess)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.green.opacity(0.2), .mint.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolEffect(.bounce, options: .repeating.speed(0.3))
                }

                // Message
                VStack(spacing: 12) {
                    Text("Date Details Shared!")
                        .font(.title.bold())
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("Your trusted contacts have been notified and will receive updates.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Shared with
                VStack(alignment: .leading, spacing: 14) {
                    Text("Shared with:")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    ForEach(confirmation.sharedWith, id: \.self) { name in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.green.opacity(0.15), .mint.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 28, height: 28)

                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.green, .mint],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }

                            Text(name)
                                .font(.body)
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .green.opacity(0.08), radius: 10, y: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.green.opacity(0.15), Color.mint.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

                Spacer()

                // Done Button
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Done")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .green.opacity(0.3), radius: 10, y: 5)
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [
                        Color.green.opacity(0.05),
                        Color.mint.opacity(0.03),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Success")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                animateSuccess = true
            }
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
        guard let userId = AuthService.shared.currentUser?.id else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        let notificationData: [String: Any] = [
            "contactId": contact.id,
            "contactName": contact.name,
            "contactEmail": contact.email ?? "",
            "contactPhone": contact.phoneNumber,
            "userId": userId,
            "matchName": match.fullName,
            "dateTime": Timestamp(date: dateTime),
            "location": location,
            "formattedDateTime": dateFormatter.string(from: dateTime),
            "sentAt": Timestamp(date: Date()),
            "type": "safety_date_alert"
        ]

        // Save notification to Firestore for tracking
        try await db.collection("safety_notifications").addDocument(data: notificationData)

        // PRODUCTION NOTE: Actual SMS/Email sending would be handled by a backend service
        // This would typically integrate with services like:
        // - Twilio for SMS
        // - SendGrid for Email
        // - Firebase Cloud Functions to trigger these services
        //
        // Example backend flow:
        // 1. Cloud Function watches 'safety_notifications' collection
        // 2. When new document added, function triggers
        // 3. Function calls Twilio/SendGrid to send SMS/Email to contact
        // 4. Updates notification document with delivery status
        //
        // For development/testing, notification is logged and saved to database

        let message = """
        Safety Alert from Celestia:
        \(AuthService.shared.currentUser?.fullName ?? "A user") has shared their date details with you.

        Date: \(dateFormatter.string(from: dateTime))
        Meeting: \(match.fullName)
        Location: \(location)

        This is an automated safety notification.
        """

        Logger.shared.info("""
        Safety notification created for \(contact.name):
        Phone: \(contact.phoneNumber)
        Email: \(contact.email ?? "N/A")
        Message: \(message)
        """, category: .general)
    }
}

// MARK: - Match Picker View

struct MatchPickerView: View {
    @Binding var selectedMatch: User?
    @Environment(\.dismiss) var dismiss
    @StateObject private var matchService = MatchService.shared
    @State private var isLoading = false
    @State private var matches: [Match] = []
    @State private var matchUsers: [String: User] = [:] // Map of match ID to User

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading matches...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if matches.isEmpty {
                    emptyStateView
                } else {
                    matchList
                }
            }
            .navigationTitle("Select Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadMatches()
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))

            VStack(spacing: 12) {
                Text("No Matches Yet")
                    .font(.title2.bold())

                Text("You don't have any matches to share your date with yet. Start swiping to find matches!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Match List

    private var matchList: some View {
        List {
            ForEach(Array(matches.enumerated()), id: \.0) { index, match in
                if let otherUser = getOtherUser(from: match) {
                    MatchPickerRow(user: otherUser) {
                        selectedMatch = otherUser
                        dismiss()

                        // Track analytics
                        AnalyticsManager.shared.logEvent(.matchSelected, parameters: [
                            "match_id": match.id ?? "",
                            "source": "share_date"
                        ])
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Helper Methods

    // PERFORMANCE FIX: Use batch queries instead of N+1 queries
    private func loadMatches() async {
        guard let currentUserId = AuthService.shared.currentUser?.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // Fetch matches
            try await matchService.fetchMatches(userId: currentUserId)
            matches = matchService.matches

            // Collect all other user IDs
            let otherUserIds = matches.map { match in
                match.user1Id == currentUserId ? match.user2Id : match.user1Id
            }

            guard !otherUserIds.isEmpty else { return }

            // Batch fetch users in groups of 10 (Firestore 'in' query limit)
            let db = Firestore.firestore()
            let uniqueUserIds = Array(Set(otherUserIds))

            for i in stride(from: 0, to: uniqueUserIds.count, by: 10) {
                let batchEnd = min(i + 10, uniqueUserIds.count)
                let batchIds = Array(uniqueUserIds[i..<batchEnd])

                guard !batchIds.isEmpty else { continue }

                let batchSnapshot = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: batchIds)
                    .getDocuments()

                let batchUsers = batchSnapshot.documents.compactMap { try? $0.data(as: User.self) }

                // Map users to their match IDs
                for user in batchUsers {
                    guard let userId = user.id else { continue }
                    // Find match that includes this user
                    if let match = matches.first(where: {
                        ($0.user1Id == userId || $0.user2Id == userId) && $0.user1Id != userId || $0.user2Id != userId
                    }), let matchId = match.id {
                        matchUsers[matchId] = user
                    }
                    // Also store by user ID for easier lookup
                    for match in matches {
                        let otherUserId = match.user1Id == currentUserId ? match.user2Id : match.user1Id
                        if otherUserId == userId, let matchId = match.id {
                            matchUsers[matchId] = user
                        }
                    }
                }
            }

            Logger.shared.info("Loaded \(matches.count) matches for date sharing using batch queries", category: .general)
        } catch {
            Logger.shared.error("Error loading matches for picker", category: .general, error: error)
        }
    }

    private func getOtherUser(from match: Match) -> User? {
        guard let currentUserId = AuthService.shared.currentUser?.id else { return nil }
        return matchUsers[match.id ?? ""]
    }
}

// MARK: - Match Picker Row

struct MatchPickerRow: View {
    let user: User
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Profile Image - PERFORMANCE: Use CachedAsyncImage
                if let photoURL = user.photos.first, let url = URL(string: photoURL) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(user.name.prefix(1))
                                .font(.title2.bold())
                                .foregroundColor(.white)
                        )
                }

                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if user.age > 0 {
                        Text("\(user.age) years old")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ShareDateView()
            .environmentObject(AuthService.shared)
    }
}
