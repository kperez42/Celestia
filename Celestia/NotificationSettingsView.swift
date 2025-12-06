//
//  NotificationSettingsView.swift
//  Celestia
//
//  Notification preferences and settings
//

import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var preferences = NotificationPreferences.shared
    @StateObject private var pushManager = PushNotificationManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        List {
            // Permission status
            Section {
                if pushManager.hasNotificationPermission {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Notifications Enabled")
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "bell.slash.fill")
                                .foregroundColor(.orange)
                            Text("Notifications Disabled")
                                .fontWeight(.semibold)
                        }

                        Text("Enable notifications to stay updated on matches, messages, and more.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button {
                            Task {
                                await pushManager.requestPermission()
                            }
                        } label: {
                            Text("Enable Notifications")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            // Core Notifications
            Section {
                NotificationToggle(
                    icon: "heart.circle.fill",
                    title: "Matches & Likes",
                    description: "When someone matches or likes you",
                    isOn: $preferences.newMatchesEnabled
                )

                NotificationToggle(
                    icon: "message.circle.fill",
                    title: "Messages",
                    description: "When you receive a new message",
                    isOn: $preferences.newMessagesEnabled
                )

                NotificationToggle(
                    icon: "shield.checkered",
                    title: "Account Updates",
                    description: "Important account and safety notifications",
                    isOn: $preferences.accountStatusEnabled
                )
            } header: {
                Text("Notifications")
            } footer: {
                Text("Stay updated on what matters most")
            }

            // Sound & Badge
            Section("Preferences") {
                Toggle(isOn: $preferences.soundEnabled) {
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sound")
                                .fontWeight(.medium)
                            Text("Play sound with notifications")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Toggle(isOn: $preferences.vibrationEnabled) {
                    HStack {
                        Image(systemName: "app.badge.fill")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Vibration")
                                .fontWeight(.medium)
                            Text("Vibrate with notifications")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Quiet Hours
            Section {
                Toggle(isOn: $preferences.quietHoursEnabled) {
                    HStack {
                        Image(systemName: "moon.fill")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quiet Hours")
                                .fontWeight(.medium)
                            Text("Pause notifications during specific times")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if preferences.quietHoursEnabled {
                    DatePicker(
                        "Start Time",
                        selection: $preferences.quietHoursStart,
                        displayedComponents: .hourAndMinute
                    )

                    DatePicker(
                        "End Time",
                        selection: $preferences.quietHoursEnd,
                        displayedComponents: .hourAndMinute
                    )
                }
            } header: {
                Text("Quiet Hours")
            } footer: {
                if preferences.quietHoursEnabled {
                    Text("Notifications will be paused during these hours")
                }
            }

            // Notification History
            Section("Recent Notifications") {
                NavigationLink {
                    NotificationHistoryView()
                } label: {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("View Notification History")
                    }
                }
            }

            // Admin Moderation Notifications (only visible for admin users)
            if isAdminUser {
                Section {
                    NotificationToggle(
                        icon: "person.badge.plus.fill",
                        title: "New Accounts",
                        description: "Get notified when new accounts need review",
                        isOn: $preferences.adminNewAccountsEnabled
                    )

                    NotificationToggle(
                        icon: "exclamationmark.triangle.fill",
                        title: "User Reports",
                        description: "Get notified about new user reports",
                        isOn: $preferences.adminReportsEnabled
                    )

                    NotificationToggle(
                        icon: "person.text.rectangle.fill",
                        title: "ID Verifications",
                        description: "Get notified about pending ID verifications",
                        isOn: $preferences.adminIdVerificationEnabled
                    )

                    NotificationToggle(
                        icon: "eye.trianglebadge.exclamationmark.fill",
                        title: "Suspicious Activity",
                        description: "Get notified about suspicious account activity",
                        isOn: $preferences.adminSuspiciousActivityEnabled
                    )
                } header: {
                    HStack {
                        Image(systemName: "shield.checkered")
                            .foregroundColor(.red)
                        Text("Admin Moderation")
                    }
                } footer: {
                    Text("These notifications help you stay on top of moderation tasks.")
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await pushManager.checkPermissionStatus()
        }
    }

    // MARK: - Admin Check

    private var isAdminUser: Bool {
        guard let user = AuthService.shared.currentUser else { return false }
        if user.isAdmin { return true }
        // Fallback to email whitelist
        let adminEmails = ["perezkevin640@gmail.com", "admin@celestia.app"]
        return adminEmails.contains(user.email.lowercased())
    }
}

// MARK: - Notification Toggle Row

struct NotificationToggle: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .fontWeight(.medium)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Notification History View

struct NotificationHistoryView: View {
    @StateObject private var notificationService = NotificationService.shared
    @EnvironmentObject var authService: AuthService

    var body: some View {
        List {
            if notificationService.notificationHistory.isEmpty {
                ContentUnavailableView {
                    Label("No Notifications", systemImage: "bell.slash")
                } description: {
                    Text("Your notification history will appear here")
                }
            } else {
                ForEach(notificationService.notificationHistory, id: \.timestamp) { notification in
                    NotificationHistoryRow(notification: notification)
                }
            }
        }
        .navigationTitle("Notification History")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Using .task ensures automatic cleanup when view disappears
            // The task is automatically cancelled when the view is dismissed
            guard let userId = authService.currentUser?.effectiveId else { return }

            notificationService.listenToNotifications(userId: userId)

            // Keep task alive until cancelled
            await withTaskCancellationHandler {
                // Infinite sleep - will be cancelled when view disappears
                do {
                    try await Task.sleep(nanoseconds: UInt64.max)
                } catch {
                    // Task cancelled, cleanup will happen in onCancel
                }
            } onCancel: {
                // Cleanup when view disappears
                Task { @MainActor in
                    notificationService.stopListening()
                }
            }
        }
    }
}

// MARK: - Notification History Row

struct NotificationHistoryRow: View {
    let notification: NotificationData

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: iconForType(notification.type))
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(10)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(notification.body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                Text(notification.timestamp.timeAgo())
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func iconForType(_ type: NotificationType) -> String {
        switch type {
        case .newMatch:
            return "heart.circle.fill"
        case .newMessage:
            return "message.circle.fill"
        case .secretAdmirer:
            return "sparkles"
        case .profileView:
            return "eye.circle.fill"
        case .weeklyDigest:
            return "calendar.circle.fill"
        case .activityReminder:
            return "bell.circle.fill"
        case .likeReceived:
            return "hand.thumbsup.circle.fill"
        case .superLikeReceived:
            return "star.circle.fill"
        }
    }
}

// MARK: - Supporting Types

enum NotificationType: String, Codable {
    case newMatch
    case newMessage
    case secretAdmirer
    case profileView
    case weeklyDigest
    case activityReminder
    case likeReceived
    case superLikeReceived
}

struct NotificationData: Identifiable, Codable {
    let id: String
    let type: NotificationType
    let title: String
    let body: String
    let timestamp: Date

    init(id: String = UUID().uuidString, type: NotificationType, title: String, body: String, timestamp: Date = Date()) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.timestamp = timestamp
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
