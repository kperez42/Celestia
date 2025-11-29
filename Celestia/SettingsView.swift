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

    // Legal document states
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    @State private var showCommunityGuidelines = false
    @State private var showSafetyTips = false
    @State private var showCookiePolicy = false
    @State private var showEULA = false
    @State private var showAccessibility = false

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
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }

                Section("Legal") {
                    Button {
                        showPrivacyPolicy = true
                    } label: {
                        HStack {
                            Image(systemName: "lock.shield")
                                .foregroundColor(.blue)
                            Text("Privacy Policy")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    Button {
                        showTermsOfService = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.purple)
                            Text("Terms of Service")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    Button {
                        showCommunityGuidelines = true
                    } label: {
                        HStack {
                            Image(systemName: "person.3.fill")
                                .foregroundColor(.green)
                            Text("Community Guidelines")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    Button {
                        showSafetyTips = true
                    } label: {
                        HStack {
                            Image(systemName: "shield.checkered")
                                .foregroundColor(.orange)
                            Text("Dating Safety Tips")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    Button {
                        showCookiePolicy = true
                    } label: {
                        HStack {
                            Image(systemName: "server.rack")
                                .foregroundColor(.gray)
                            Text("Cookie & Data Policy")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    Button {
                        showEULA = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.badge.gearshape")
                                .foregroundColor(.indigo)
                            Text("End User License Agreement")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    Button {
                        showAccessibility = true
                    } label: {
                        HStack {
                            Image(systemName: "accessibility")
                                .foregroundColor(.teal)
                            Text("Accessibility Statement")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
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
            .sheet(isPresented: $showPrivacyPolicy) {
                LegalDocumentView(documentType: .privacyPolicy)
            }
            .sheet(isPresented: $showTermsOfService) {
                LegalDocumentView(documentType: .termsOfService)
            }
            .sheet(isPresented: $showCommunityGuidelines) {
                LegalDocumentView(documentType: .communityGuidelines)
            }
            .sheet(isPresented: $showSafetyTips) {
                LegalDocumentView(documentType: .safetyTips)
            }
            .sheet(isPresented: $showCookiePolicy) {
                LegalDocumentView(documentType: .cookiePolicy)
            }
            .sheet(isPresented: $showEULA) {
                LegalDocumentView(documentType: .eula)
            }
            .sheet(isPresented: $showAccessibility) {
                LegalDocumentView(documentType: .accessibility)
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
