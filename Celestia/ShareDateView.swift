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
        .sheet(isPresented: $showMatchPicker) {
            MatchPickerView(selectedMatch: $selectedMatch)
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
                    showMatchPicker = true
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
