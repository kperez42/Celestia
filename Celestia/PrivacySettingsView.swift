//
//  PrivacySettingsView.swift
//  Celestia
//
//  Privacy controls for user safety
//

import SwiftUI
import FirebaseFirestore
import Combine

struct PrivacySettingsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = PrivacySettingsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        privacyHeader

                        // Profile Visibility
                        profileVisibilitySection

                        // Chat Settings
                        chatSettingsSection

                        // Blocked Users
                        blockedUsersSection
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Privacy Settings")
            .navigationBarTitleDisplayMode(.inline)
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

            PrivacyToggleCard(
                title: "Show Online Status",
                description: "Let others see when you're online",
                isOn: $viewModel.showOnlineStatus,
                icon: "circle.fill"
            )
            .padding(.horizontal)
        }
    }

    // MARK: - Chat Settings

    private var chatSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "message.fill")
                    .foregroundColor(.blue)

                Text("Chat Settings")
                    .font(.headline)
            }
            .padding(.horizontal)

            VStack(spacing: 12) {
                PrivacyToggleCard(
                    title: "Show Typing Indicator",
                    description: "Let others see when you're typing",
                    isOn: $viewModel.showTypingIndicator,
                    icon: "ellipsis.bubble.fill"
                )

                PrivacyToggleCard(
                    title: "Show Read Receipts",
                    description: "Let senders know when you've read messages",
                    isOn: $viewModel.showReadReceipts,
                    icon: "checkmark.circle.fill"
                )
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Blocked Users

    private var blockedUsersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(.red)

                Text("Blocked Users")
                    .font(.headline)
            }
            .padding(.horizontal)

            NavigationLink {
                BlockedUsersView()
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .foregroundColor(.red)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manage Blocked Users")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text("\(viewModel.blockedUsersCount) blocked")
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
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Privacy Toggle Card

struct PrivacyToggleCard: View {
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

// MARK: - View Model

@MainActor
class PrivacySettingsViewModel: ObservableObject {
    @Published var showOnlineStatus: Bool = true {
        didSet { saveSetting("showOnlineStatus", value: showOnlineStatus) }
    }
    @Published var showTypingIndicator: Bool = true {
        didSet { saveSetting("showTypingIndicator", value: showTypingIndicator) }
    }
    @Published var showReadReceipts: Bool = true {
        didSet { saveSetting("showReadReceipts", value: showReadReceipts) }
    }
    @Published var blockedUsersCount = 0

    private let db = Firestore.firestore()
    private let userDefaults = UserDefaults.standard
    private var isLoading = true // Prevent saving during initial load

    func loadSettings() {
        isLoading = true

        // Load from UserDefaults with proper defaults (true if not set)
        showOnlineStatus = userDefaults.object(forKey: "showOnlineStatus") as? Bool ?? true
        showTypingIndicator = userDefaults.object(forKey: "showTypingIndicator") as? Bool ?? true
        showReadReceipts = userDefaults.object(forKey: "showReadReceipts") as? Bool ?? true

        // Load blocked count
        loadBlockedCount()

        isLoading = false
    }

    private func saveSetting(_ key: String, value: Bool) {
        guard !isLoading else { return }

        // Save to UserDefaults
        userDefaults.set(value, forKey: key)

        // Save to Firestore
        guard let userId = AuthService.shared.currentUser?.id else { return }

        db.collection("users").document(userId).updateData([
            "privacySettings.\(key)": value
        ]) { error in
            if let error = error {
                Logger.shared.error("Failed to save privacy setting", category: .database, error: error)
            }
        }
    }

    private func loadBlockedCount() {
        guard let currentUserId = AuthService.shared.currentUser?.id else { return }

        db.collection("blockedUsers")
            .whereField("blockerId", isEqualTo: currentUserId)
            .getDocuments { snapshot, error in
                Task { @MainActor in
                    self.blockedUsersCount = snapshot?.documents.count ?? 0
                }
            }
    }
}

#Preview {
    PrivacySettingsView()
        .environmentObject(AuthService.shared)
}
