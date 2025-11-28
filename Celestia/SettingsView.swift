//
//  SettingsView.swift
//  Celestia
//
//  Created by Kevin Perez on 10/29/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService

    @State private var showDeleteConfirmation = false
    @State private var showReferralDashboard = false
    @State private var showPremiumUpgrade = false
    @State private var showSeeWhoLikesYou = false
    @State private var showAdminDashboard = false

    // CODE QUALITY FIX: Define URL constants to avoid force unwrapping
    private static let supportEmailURL = URL(string: "mailto:support@celestia.app")!
    private static let privacyPolicyURL = URL(string: "https://celestia.app/privacy")!
    private static let termsOfServiceURL = URL(string: "https://celestia.app/terms")!

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(authService.currentUser?.email ?? "")
                            .foregroundColor(.gray)
                    }

                    HStack {
                        Text("Account Type")
                        Spacer()
                        HStack(spacing: 4) {
                            if authService.currentUser?.isPremium == true {
                                Image(systemName: "crown.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            Text(authService.currentUser?.isPremium == true ? "Premium" : "Free")
                                .foregroundColor(.gray)
                        }
                    }

                    // Show premium expiry date if user is premium
                    if let user = authService.currentUser,
                       user.isPremium,
                       let expiryDate = user.subscriptionExpiryDate {
                        HStack {
                            Text("Premium Until")
                            Spacer()
                            Text(expiryDate.formatted(date: .abbreviated, time: .omitted))
                                .foregroundColor(.orange)
                                .fontWeight(.medium)
                        }
                    }
                }

                Section {
                    Button {
                        showPremiumUpgrade = true
                    } label: {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.orange)
                            Text("Upgrade to Premium")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    Button {
                        showReferralDashboard = true
                    } label: {
                        HStack {
                            Image(systemName: "gift.fill")
                                .foregroundColor(.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Invite Friends")
                                    .foregroundColor(.primary)
                                Text("Earn 7 days per referral")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if let referrals = authService.currentUser?.referralStats.totalReferrals, referrals > 0 {
                                Text("\(referrals)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.purple)
                                    .cornerRadius(10)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    Button {
                        showSeeWhoLikesYou = true
                    } label: {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.pink)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("See Who Likes You")
                                        .foregroundColor(.primary)
                                    if !(authService.currentUser?.isPremium ?? false) {
                                        Image(systemName: "crown.fill")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    }
                                }
                                Text("Premium feature")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                } header: {
                    Text("Premium & Rewards")
                }

                Section("Preferences") {
                    NavigationLink {
                        FilterView()
                    } label: {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                            Text("Discovery Filters")
                        }
                    }
                }

                Section("Notifications") {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                            Text("Notification Preferences")
                        }
                    }
                }

                Section("Safety & Privacy") {
                    NavigationLink {
                        PrivacySettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "hand.raised.shield")
                            Text("Privacy Controls")
                        }
                    }

                    NavigationLink {
                        SafetyCenterView()
                    } label: {
                        HStack {
                            Image(systemName: "shield.checkered")
                            Text("Safety Center")
                        }
                    }

                    NavigationLink {
                        BlockedUsersView()
                    } label: {
                        HStack {
                            Image(systemName: "hand.raised.slash")
                            Text("Blocked Users")
                        }
                    }
                }
                
                Section("Support") {
                    Link(destination: Self.supportEmailURL) {
                        HStack {
                            Image(systemName: "envelope")
                            Text("Contact Support")
                        }
                    }

                    Link(destination: Self.privacyPolicyURL) {
                        HStack {
                            Image(systemName: "lock.shield")
                            Text("Privacy Policy")
                        }
                    }

                    Link(destination: Self.termsOfServiceURL) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("Terms of Service")
                        }
                    }
                }
                
                // Admin section - only visible for admin users
                if isAdminUser {
                    Section("Admin") {
                        Button {
                            showAdminDashboard = true
                        } label: {
                            HStack {
                                Image(systemName: "shield.checkered")
                                    .foregroundColor(.red)
                                Text("Moderation Dashboard")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }

                Section("Danger Zone") {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Account")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        do {
                            try await authService.deleteAccount()
                        } catch {
                            Logger.shared.error("Error deleting account", category: .general, error: error)
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone.")
            }
            .sheet(isPresented: $showReferralDashboard) {
                ReferralDashboardView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showPremiumUpgrade) {
                PremiumUpgradeView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showSeeWhoLikesYou) {
                SeeWhoLikesYouView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showAdminDashboard) {
                AdminModerationDashboard()
            }
        }
    }

    // Check if current user is an admin
    private var isAdminUser: Bool {
        guard let email = authService.currentUser?.email else { return false }
        // Add your admin email(s) here
        let adminEmails = ["perezkevin640@gmail.com", "admin@celestia.app"]
        return adminEmails.contains(email.lowercased())
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthService.shared)
}
