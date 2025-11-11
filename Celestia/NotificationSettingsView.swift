//
//  NotificationSettingsView.swift
//  Celestia
//
//  Notification preferences and settings
//

import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var notificationService = NotificationService.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        List {
            // Permission status
            Section {
                if notificationService.hasNotificationPermission {
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
                                await notificationService.requestPermission()
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

            // Notification Types
            Section("Notification Types") {
                NotificationToggle(
                    icon: "heart.circle.fill",
                    title: "New Matches",
                    description: "When you match with someone",
                    isOn: $notificationService.preferences.newMatches
                )

                NotificationToggle(
                    icon: "message.circle.fill",
                    title: "Messages",
                    description: "When you receive a new message",
                    isOn: $notificationService.preferences.messages
                )

                NotificationToggle(
                    icon: "eye.circle.fill",
                    title: "Profile Views",
                    description: "When someone views your profile",
                    isOn: $notificationService.preferences.profileViews
                )

                NotificationToggle(
                    icon: "star.circle.fill",
                    title: "Likes",
                    description: "When someone likes your profile",
                    isOn: $notificationService.preferences.likes
                )

                NotificationToggle(
                    icon: "sparkles",
                    title: "Secret Admirer",
                    description: "Mystery likes and special alerts",
                    isOn: $notificationService.preferences.secretAdmirer
                )
            }

            // Engagement
            Section("Engagement") {
                NotificationToggle(
                    icon: "calendar.circle.fill",
                    title: "Weekly Digest",
                    description: "Your week in review (Sundays at 6 PM)",
                    isOn: $notificationService.preferences.weeklyDigest
                )

                NotificationToggle(
                    icon: "bell.circle.fill",
                    title: "Activity Reminders",
                    description: "Gentle nudges to stay active",
                    isOn: $notificationService.preferences.activityReminders
                )
            }

            // Sound & Badge
            Section("Preferences") {
                Toggle(isOn: $notificationService.preferences.sound) {
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

                Toggle(isOn: $notificationService.preferences.badge) {
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
                            Text("Badge")
                                .fontWeight(.medium)
                            Text("Show notification count on app icon")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Quiet Hours
            Section {
                Toggle(isOn: $notificationService.preferences.quietHoursEnabled) {
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

                if notificationService.preferences.quietHoursEnabled {
                    DatePicker(
                        "Start Time",
                        selection: $notificationService.preferences.quietHoursStart,
                        displayedComponents: .hourAndMinute
                    )

                    DatePicker(
                        "End Time",
                        selection: $notificationService.preferences.quietHoursEnd,
                        displayedComponents: .hourAndMinute
                    )
                }
            } header: {
                Text("Quiet Hours")
            } footer: {
                if notificationService.preferences.quietHoursEnabled {
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
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: notificationService.preferences) { _ in
            notificationService.savePreferences()
        }
        .task {
            await notificationService.checkPermissionStatus()
        }
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
        .onAppear {
            if let userId = authService.currentUser?.id {
                notificationService.listenToNotifications(userId: userId)
            }
        }
        .onDisappear {
            notificationService.stopListening()
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
