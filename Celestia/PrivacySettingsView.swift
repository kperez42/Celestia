//
//  PrivacySettingsView.swift
//  Celestia
//
//  Privacy controls for user safety
//

import SwiftUI
import FirebaseFirestore

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

                        // Profile Visibility
                        profileVisibilitySection

                        // Activity Status
                        activityStatusSection

                        // Blocked Users
                        blockedUsersSection
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
                    title: "Show Online Status",
                    description: "Let others see when you're online",
                    isOn: $viewModel.showOnlineStatus,
                    icon: "circle.fill"
                )
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Activity Status

    private var activityStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "message.fill")
                    .foregroundColor(.blue)

                Text("Chat Settings")
                    .font(.headline)
            }
            .padding(.horizontal)

            VStack(spacing: 12) {
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

// MARK: - Supporting Views

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

// MARK: - View Model

@MainActor
class PrivacySettingsViewModel: ObservableObject {
    @Published var showInDiscovery = true
    @Published var showDistance = true
    @Published var showOnlineStatus = true
    @Published var showTypingIndicator = true
    @Published var showReadReceipts = true
    @Published var blockedUsersCount = 0

    private let db = Firestore.firestore()
    private let userDefaults = UserDefaults.standard

    func loadSettings() {
        // Load from UserDefaults
        showInDiscovery = userDefaults.bool(forKey: "showInDiscovery")
        showDistance = userDefaults.bool(forKey: "showDistance")
        showOnlineStatus = userDefaults.bool(forKey: "showOnlineStatus")
        showTypingIndicator = userDefaults.bool(forKey: "showTypingIndicator")
        showReadReceipts = userDefaults.bool(forKey: "showReadReceipts")

        // Load blocked count
        loadBlockedCount()
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
