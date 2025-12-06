//
//  NotificationPreferencesView.swift
//  Celestia
//
//  SwiftUI view for managing notification preferences
//

import SwiftUI

struct NotificationPreferencesView: View {
    @ObservedObject private var preferences = NotificationPreferences.shared
    @ObservedObject private var manager = PushNotificationManager.shared
    @State private var showingPermissionAlert = false

    var body: some View {
        List {
            // Permission Status Section
            permissionStatusSection

            // Notification Types Section
            notificationTypesSection

            // Quiet Hours Section
            quietHoursSection

            // Sound & Vibration Section
            soundVibrationSection

            // Preview Section
            previewSection

            // Quick Actions Section
            quickActionsSection
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .alert("Enable Notifications", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable notifications in Settings to receive updates about matches and messages.")
        }
    }

    // MARK: - Permission Status Section

    private var permissionStatusSection: some View {
        Section {
            HStack {
                Image(systemName: notificationStatusIcon)
                    .foregroundColor(notificationStatusColor)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Notification Status")
                        .font(.headline)
                    Text(notificationStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if manager.authorizationStatus != .authorized {
                    Button("Enable") {
                        Task {
                            let granted = await manager.requestAuthorization()
                            if !granted {
                                showingPermissionAlert = true
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Status")
        }
    }

    private var notificationStatusIcon: String {
        switch manager.authorizationStatus {
        case .authorized:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined, .provisional:
            return "questionmark.circle.fill"
        @unknown default:
            return "questionmark.circle.fill"
        }
    }

    private var notificationStatusColor: Color {
        switch manager.authorizationStatus {
        case .authorized:
            return .green
        case .denied:
            return .red
        case .notDetermined, .provisional:
            return .orange
        @unknown default:
            return .gray
        }
    }

    private var notificationStatusText: String {
        switch manager.authorizationStatus {
        case .authorized:
            return "Notifications are enabled"
        case .denied:
            return "Notifications are disabled. Enable in Settings."
        case .notDetermined:
            return "Notification permission not requested"
        case .provisional:
            return "Provisional authorization"
        @unknown default:
            return "Unknown status"
        }
    }

    // MARK: - Notification Types Section

    private var notificationTypesSection: some View {
        Section {
            ForEach(NotificationPreferenceItem.allItems) { item in
                notificationToggle(for: item)
            }
        } header: {
            Text("Notification Types")
        } footer: {
            Text("Choose which notifications you want to receive")
        }
    }

    private func notificationToggle(for item: NotificationPreferenceItem) -> some View {
        Toggle(isOn: binding(for: item.category)) {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.body)
                    Text(item.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func binding(for category: NotificationCategory) -> Binding<Bool> {
        switch category {
        case .newMatch:
            return $preferences.newMatchesEnabled
        case .newMessage:
            return $preferences.newMessagesEnabled
        case .profileView:
            return $preferences.profileViewsEnabled
        case .newLike:
            return $preferences.newLikesEnabled
        case .superLike:
            return $preferences.superLikesEnabled
        case .dailyDigest:
            return $preferences.dailyDigestEnabled
        case .premiumOffer:
            return $preferences.premiumOffersEnabled
        case .generalUpdate:
            return $preferences.generalUpdatesEnabled
        case .matchReminder:
            return $preferences.matchRemindersEnabled
        case .messageReminder:
            return $preferences.messageRemindersEnabled
        case .adminNewReport, .adminNewAccount, .adminIdVerification, .adminSuspiciousActivity:
            // Admin categories are not configurable in user preferences
            return .constant(false)
        }
    }

    // MARK: - Quiet Hours Section

    private var quietHoursSection: some View {
        Section {
            Toggle("Enable Quiet Hours", isOn: $preferences.quietHoursEnabled)

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

                // Preview
                if preferences.isInQuietHours() {
                    Label("Quiet hours active now", systemImage: "moon.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                } else {
                    Label("Quiet hours not active", systemImage: "sun.max.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
        } header: {
            Text("Quiet Hours")
        } footer: {
            Text("Mute notifications during specific hours")
        }
    }

    // MARK: - Sound & Vibration Section

    private var soundVibrationSection: some View {
        Section {
            Toggle(isOn: $preferences.soundEnabled) {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text("Sound")
                }
            }

            Toggle(isOn: $preferences.vibrationEnabled) {
                HStack {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text("Vibration")
                }
            }
        } header: {
            Text("Alerts")
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        Section {
            Toggle(isOn: $preferences.showPreview) {
                HStack {
                    Image(systemName: "eye.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text("Show Preview")
                }
            }
        } header: {
            Text("Privacy")
        } footer: {
            Text("Show message content in notification previews")
        }
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        Section {
            Button(action: {
                preferences.enableAll()
            }) {
                Label("Enable All", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }

            Button(action: {
                preferences.disableAll()
            }) {
                Label("Disable All", systemImage: "xmark.circle.fill")
                    .foregroundColor(.red)
            }

            Button(action: {
                preferences.resetToDefaults()
            }) {
                Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                    .foregroundColor(.blue)
            }
        } header: {
            Text("Quick Actions")
        }
    }
}

// MARK: - Preview

#if DEBUG
struct NotificationPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NotificationPreferencesView()
        }
    }
}
#endif
