//
//  PrivacySettingsView.swift
//  Celestia
//
//  Advanced privacy controls for user safety
//

import SwiftUI
import FirebaseFirestore
import Contacts

struct PrivacySettingsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = PrivacySettingsViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        privacyHeader

                        // Incognito Mode
                        incognitoSection

                        // Hide from Contacts
                        hideFromContactsSection

                        // Profile Visibility
                        profileVisibilitySection

                        // Screenshot Notifications
                        screenshotSection

                        // Activity Status
                        activityStatusSection

                        // Data Privacy
                        dataPrivacySection
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Privacy Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.purple)
                }
            }
            .onAppear {
                viewModel.loadSettings()
            }
        }
    }

    // MARK: - Header

    private var privacyHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.2), .blue.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Control Your Privacy")
                .font(.title2)
                .fontWeight(.bold)

            Text("Manage who can see your profile and activity")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Incognito Mode

    private var incognitoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "eye.slash.fill")
                    .foregroundColor(.purple)

                Text("Incognito Mode")
                    .font(.headline)
            }
            .padding(.horizontal)

            VStack(spacing: 0) {
                Toggle(isOn: $viewModel.incognitoMode) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Browse Anonymously")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(viewModel.incognitoMode ? "Active - Your views are hidden" : "Inactive - Others can see when you view them")
                            .font(.caption)
                            .foregroundColor(viewModel.incognitoMode ? .green : .secondary)
                    }
                }
                .tint(.purple)
                .padding()
                .background(Color(.systemBackground))

                if viewModel.incognitoMode {
                    VStack(alignment: .leading, spacing: 12) {
                        PrivacyInfoRow(
                            icon: "checkmark.circle.fill",
                            text: "Your profile views won't be recorded",
                            color: .green
                        )
                        PrivacyInfoRow(
                            icon: "checkmark.circle.fill",
                            text: "Others won't see you viewed their profile",
                            color: .green
                        )
                        PrivacyInfoRow(
                            icon: "info.circle.fill",
                            text: "You also won't see who viewed you",
                            color: .orange
                        )

                        if !viewModel.isPremiumUser {
                            HStack(spacing: 8) {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                Text("Premium Feature")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Spacer()
                                Button("Upgrade") {
                                    // Show premium upgrade
                                }
                                .font(.caption)
                                .foregroundColor(.purple)
                            }
                            .padding()
                            .background(Color.yellow.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    // MARK: - Hide from Contacts

    private var hideFromContactsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.xmark")
                    .foregroundColor(.blue)

                Text("Hide from Contacts")
                    .font(.headline)
            }
            .padding(.horizontal)

            VStack(spacing: 0) {
                Toggle(isOn: $viewModel.hideFromContacts) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Don't Show Me to Phone Contacts")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Your profile won't appear to people in your contacts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.blue)
                .padding()

                if viewModel.hideFromContacts {
                    VStack(alignment: .leading, spacing: 12) {
                        if viewModel.contactsAccess == .authorized {
                            PrivacyInfoRow(
                                icon: "checkmark.circle.fill",
                                text: "\(viewModel.blockedContactsCount) contacts will be hidden",
                                color: .green
                            )
                        } else {
                            Button {
                                viewModel.requestContactsAccess()
                            } label: {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                    Text("Grant Contacts Access")
                                        .font(.subheadline)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .foregroundColor(.blue)
                            }
                        }

                        Button {
                            viewModel.showContactsList = true
                        } label: {
                            HStack {
                                Image(systemName: "list.bullet")
                                Text("Manage Hidden Contacts")
                                    .font(.subheadline)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    // MARK: - Profile Visibility

    private var profileVisibilitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "eye.fill")
                    .foregroundColor(.green)

                Text("Profile Visibility")
                    .font(.headline)
            }
            .padding(.horizontal)

            VStack(spacing: 12) {
                VisibilityOptionCard(
                    title: "Show Me in Discovery",
                    description: "Appear in other users' discovery feed",
                    isOn: $viewModel.showInDiscovery,
                    icon: "magnifyingglass"
                )

                VisibilityOptionCard(
                    title: "Show My Distance",
                    description: "Display distance to other users",
                    isOn: $viewModel.showDistance,
                    icon: "location.fill"
                )

                VisibilityOptionCard(
                    title: "Show My Activity Status",
                    description: "Let others see when you're online",
                    isOn: $viewModel.showOnlineStatus,
                    icon: "circle.fill"
                )

                VisibilityOptionCard(
                    title: "Allow Profile Sharing",
                    description: "Let others share your profile",
                    isOn: $viewModel.allowProfileSharing,
                    icon: "square.and.arrow.up"
                )
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Screenshot Notifications

    private var screenshotSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "camera.fill")
                    .foregroundColor(.orange)

                Text("Screenshot Protection")
                    .font(.headline)
            }
            .padding(.horizontal)

            VStack(spacing: 0) {
                Toggle(isOn: $viewModel.notifyOnScreenshot) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Screenshot Notifications")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Get notified when someone screenshots your profile or chat")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.orange)
                .padding()

                if viewModel.notifyOnScreenshot {
                    VStack(alignment: .leading, spacing: 12) {
                        PrivacyInfoRow(
                            icon: "bell.fill",
                            text: "You'll receive alerts for screenshots",
                            color: .orange
                        )
                        PrivacyInfoRow(
                            icon: "shield.fill",
                            text: "Others will be notified if you screenshot",
                            color: .blue
                        )
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    // MARK: - Activity Status

    private var activityStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "clock.fill")
                    .foregroundColor(.mint)

                Text("Activity & Presence")
                    .font(.headline)
            }
            .padding(.horizontal)

            VStack(spacing: 12) {
                VisibilityOptionCard(
                    title: "Show Last Active",
                    description: "Display when you were last online",
                    isOn: $viewModel.showLastActive,
                    icon: "clock"
                )

                VisibilityOptionCard(
                    title: "Show Typing Indicator",
                    description: "Let others see when you're typing",
                    isOn: $viewModel.showTypingIndicator,
                    icon: "ellipsis.bubble.fill"
                )

                VisibilityOptionCard(
                    title: "Show Read Receipts",
                    description: "Let senders know when you've read messages",
                    isOn: $viewModel.showReadReceipts,
                    icon: "checkmark.circle.fill"
                )
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Data Privacy

    private var dataPrivacySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.indigo)

                Text("Data & Privacy")
                    .font(.headline)
            }
            .padding(.horizontal)

            VStack(spacing: 12) {
                NavigationLink {
                    // Blocked users list
                } label: {
                    DataPrivacyRow(
                        icon: "hand.raised.fill",
                        title: "Blocked Users",
                        subtitle: "\(viewModel.blockedUsersCount) blocked",
                        color: .red
                    )
                }

                NavigationLink {
                    // Data download
                } label: {
                    DataPrivacyRow(
                        icon: "arrow.down.doc.fill",
                        title: "Download My Data",
                        subtitle: "Get a copy of your data",
                        color: .blue
                    )
                }

                NavigationLink {
                    // Account deletion
                } label: {
                    DataPrivacyRow(
                        icon: "trash.fill",
                        title: "Delete Account",
                        subtitle: "Permanently delete your account",
                        color: .red
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Supporting Views

struct PrivacyInfoRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct VisibilityOptionCard: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    let icon: String

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.purple)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .tint(.purple)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct DataPrivacyRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - View Model

@MainActor
class PrivacySettingsViewModel: ObservableObject {
    @Published var incognitoMode = false
    @Published var hideFromContacts = false
    @Published var showInDiscovery = true
    @Published var showDistance = true
    @Published var showOnlineStatus = true
    @Published var allowProfileSharing = true
    @Published var notifyOnScreenshot = true
    @Published var showLastActive = true
    @Published var showTypingIndicator = true
    @Published var showReadReceipts = true

    @Published var contactsAccess: CNAuthorizationStatus = .notDetermined
    @Published var blockedContactsCount = 0
    @Published var blockedUsersCount = 0
    @Published var showContactsList = false

    private let db = Firestore.firestore()
    private let userDefaults = UserDefaults.standard

    var isPremiumUser: Bool {
        AuthService.shared.currentUser?.isPremium ?? false
    }

    func loadSettings() {
        // Load from UserDefaults
        incognitoMode = userDefaults.bool(forKey: "incognitoMode")
        hideFromContacts = userDefaults.bool(forKey: "hideFromContacts")
        showInDiscovery = userDefaults.bool(forKey: "showInDiscovery")
        showDistance = userDefaults.bool(forKey: "showDistance")
        showOnlineStatus = userDefaults.bool(forKey: "showOnlineStatus")
        allowProfileSharing = userDefaults.bool(forKey: "allowProfileSharing")
        notifyOnScreenshot = userDefaults.bool(forKey: "notifyOnScreenshot")
        showLastActive = userDefaults.bool(forKey: "showLastActive")
        showTypingIndicator = userDefaults.bool(forKey: "showTypingIndicator")
        showReadReceipts = userDefaults.bool(forKey: "showReadReceipts")

        // Check contacts access
        contactsAccess = CNContactStore.authorizationStatus(for: .contacts)

        // Load blocked counts
        loadBlockedCounts()
    }

    func requestContactsAccess() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, error in
            Task { @MainActor in
                if granted {
                    contactsAccess = .authorized
                    syncContactsWithFirebase()
                }
            }
        }
    }

    private func syncContactsWithFirebase() {
        // Sync contacts to hide from discovery
        guard let currentUserId = AuthService.shared.currentUser?.id else { return }

        let store = CNContactStore()
        let keys = [CNContactPhoneNumbersKey as CNKeyDescriptor]

        do {
            let request = CNContactFetchRequest(keysToFetch: keys)
            var phoneNumbers: [String] = []

            try store.enumerateContacts(with: request) { contact, _ in
                for phoneNumber in contact.phoneNumbers {
                    let number = phoneNumber.value.stringValue
                    phoneNumbers.append(number)
                }
            }

            // Save to Firestore
            db.collection("users")
                .document(currentUserId)
                .updateData([
                    "hiddenContacts": phoneNumbers,
                    "hideFromContactsEnabled": true
                ]) { error in
                    if error == nil {
                        Task { @MainActor in
                            blockedContactsCount = phoneNumbers.count
                        }
                    }
                }
        } catch {
            Logger.shared.error("Error fetching contacts", category: .database, error: error)
        }
    }

    private func loadBlockedCounts() {
        guard let currentUserId = AuthService.shared.currentUser?.id else { return }

        // Count blocked users
        db.collection("blockedUsers")
            .whereField("blockerId", isEqualTo: currentUserId)
            .getDocuments { snapshot, error in
                Task { @MainActor in
                    blockedUsersCount = snapshot?.documents.count ?? 0
                }
            }
    }
}

#Preview {
    PrivacySettingsView()
        .environmentObject(AuthService.shared)
}
