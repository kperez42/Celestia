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
    @State private var animateHeader = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Premium gradient background
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.08),
                        Color.blue.opacity(0.05),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
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
                animateHeader = true
            }
        }
    }

    // MARK: - Header

    private var privacyHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                // Outer radial glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.purple.opacity(0.25),
                                Color.blue.opacity(0.1),
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

                // Inner gradient circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.2), .blue.opacity(0.15)],
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
                    .symbolEffect(.pulse, options: .repeating)
            }

            VStack(spacing: 8) {
                Text("Control Your Privacy")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("Manage who can see your profile and activity")
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
                .shadow(color: .purple.opacity(0.08), radius: 15, y: 5)
                .shadow(color: .black.opacity(0.03), radius: 5, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.15), Color.blue.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .padding(.horizontal)
    }

    // MARK: - Profile Visibility

    private var profileVisibilitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
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

                    Image(systemName: "eye.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text("Profile Visibility")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal)

            PrivacyToggleCard(
                title: "Show Online Status",
                description: "Let others see when you're online",
                isOn: $viewModel.showOnlineStatus,
                icon: "circle.fill",
                iconColor: .green
            )
            .padding(.horizontal)
        }
    }

    // MARK: - Chat Settings

    private var chatSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.2), .cyan.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: "message.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text("Chat Settings")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal)

            VStack(spacing: 12) {
                PrivacyToggleCard(
                    title: "Show Typing Indicator",
                    description: "Let others see when you're typing",
                    isOn: $viewModel.showTypingIndicator,
                    icon: "ellipsis.bubble.fill",
                    iconColor: .blue
                )

                PrivacyToggleCard(
                    title: "Show Read Receipts",
                    description: "Let senders know when you've read messages",
                    isOn: $viewModel.showReadReceipts,
                    icon: "checkmark.circle.fill",
                    iconColor: .blue
                )
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Blocked Users

    private var blockedUsersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.red.opacity(0.2), .orange.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text("Blocked Users")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal)

            NavigationLink {
                BlockedUsersView()
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.red.opacity(0.2), .red.opacity(0.08), Color.clear],
                                    center: .center,
                                    startRadius: 5,
                                    endRadius: 22
                                )
                            )
                            .frame(width: 44, height: 44)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.red.opacity(0.15), .orange.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)

                        Image(systemName: "person.crop.circle.badge.xmark")
                            .font(.system(size: 16))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Manage Blocked Users")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text("\(viewModel.blockedUsersCount) blocked")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                        .shadow(color: .red.opacity(0.06), radius: 10, y: 5)
                        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.red.opacity(0.1), Color.orange.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
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
    var iconColor: Color = .purple

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [iconColor.opacity(0.2), iconColor.opacity(0.08), Color.clear],
                                center: .center,
                                startRadius: 5,
                                endRadius: 22
                            )
                        )
                        .frame(width: 44, height: 44)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [iconColor.opacity(0.15), iconColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [iconColor, iconColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .tint(.purple)
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
                        colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
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
