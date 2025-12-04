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
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""
    @State private var isDeleting = false

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
                Section {
                    settingsRow(icon: "envelope.fill", colors: [.blue, .cyan]) {
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(authService.currentUser?.email ?? "")
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    settingsRow(icon: "crown.fill", colors: [.orange, .yellow]) {
                        HStack {
                            Text("Account Type")
                            Spacer()
                            if authService.currentUser?.isPremium == true {
                                Text("Premium")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(
                                        LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                                    )
                            } else {
                                Text("Free")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Show premium expiry date if user is premium
                    if let user = authService.currentUser,
                       user.isPremium,
                       let expiryDate = user.subscriptionExpiryDate {
                        settingsRow(icon: "calendar.badge.clock", colors: [.orange, .pink]) {
                            HStack {
                                Text("Premium Until")
                                Spacer()
                                Text(expiryDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(
                                        LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                                    )
                            }
                        }
                    }

                    // Profile Status
                    if let user = authService.currentUser {
                        settingsRow(icon: profileStatusIcon(for: user.profileStatus), colors: profileStatusColors(for: user.profileStatus)) {
                            HStack {
                                Text("Profile Status")
                                Spacer()
                                statusBadge(
                                    text: profileStatusText(for: user.profileStatus),
                                    colors: profileStatusColors(for: user.profileStatus)
                                )
                            }
                        }

                        // ID Verification Status
                        settingsRow(icon: verificationStatusIcon(for: user), colors: verificationStatusColors(for: user)) {
                            HStack {
                                Text("ID Verification")
                                Spacer()
                                statusBadge(
                                    text: verificationStatusText(for: user),
                                    colors: verificationStatusColors(for: user)
                                )
                            }
                        }
                    }
                } header: {
                    Text("Account")
                }

                Section {
                    Button {
                        showPremiumUpgrade = true
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.orange.opacity(0.15), Color.yellow.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                Image(systemName: "crown.fill")
                                    .font(.callout)
                                    .foregroundStyle(
                                        LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                            }
                            Text("Upgrade to Premium")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                    }

                    Button {
                        showReferralDashboard = true
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                Image(systemName: "gift.fill")
                                    .font(.callout)
                                    .foregroundStyle(
                                        LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                            }
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
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(
                                                LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                                            )
                                            .shadow(color: .purple.opacity(0.3), radius: 4, y: 2)
                                    )
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                    }

                    Button {
                        showSeeWhoLikesYou = true
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.pink.opacity(0.15), Color.red.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                Image(systemName: "heart.fill")
                                    .font(.callout)
                                    .foregroundStyle(
                                        LinearGradient(colors: [.pink, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("See Who Likes You")
                                        .foregroundColor(.primary)
                                    if !(authService.currentUser?.isPremium ?? false) {
                                        Image(systemName: "crown.fill")
                                            .font(.caption2)
                                            .foregroundStyle(
                                                LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                                            )
                                    }
                                }
                                Text("Premium feature")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Premium & Rewards")
                }

                Section {
                    NavigationLink {
                        FilterView()
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.indigo.opacity(0.15), Color.purple.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                Image(systemName: "slider.horizontal.3")
                                    .font(.callout)
                                    .foregroundStyle(
                                        LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                            }
                            Text("Discovery Filters")
                        }
                    }
                } header: {
                    Text("Preferences")
                }

                Section {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.red.opacity(0.15), Color.orange.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                Image(systemName: "bell.badge.fill")
                                    .font(.callout)
                                    .foregroundStyle(
                                        LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                            }
                            Text("Notification Preferences")
                        }
                    }
                } header: {
                    Text("Notifications")
                }

                Section {
                    NavigationLink {
                        PrivacySettingsView()
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue.opacity(0.15), Color.cyan.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                Image(systemName: "hand.raised.fill")
                                    .font(.callout)
                                    .foregroundStyle(
                                        LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                            }
                            Text("Privacy Controls")
                        }
                    }

                    NavigationLink {
                        SafetyCenterView()
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.green.opacity(0.15), Color.mint.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                Image(systemName: "shield.checkered")
                                    .font(.callout)
                                    .foregroundStyle(
                                        LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                            }
                            Text("Safety Center")
                        }
                    }

                    NavigationLink {
                        BlockedUsersView()
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.gray.opacity(0.15), Color.gray.opacity(0.08)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                Image(systemName: "hand.raised.slash")
                                    .font(.callout)
                                    .foregroundColor(.gray)
                            }
                            Text("Blocked Users")
                        }
                    }
                } header: {
                    Text("Safety & Privacy")
                }

                Section {
                    Link(destination: Self.supportEmailURL) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.teal.opacity(0.15), Color.cyan.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                Image(systemName: "envelope.fill")
                                    .font(.callout)
                                    .foregroundStyle(
                                        LinearGradient(colors: [.teal, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                            }
                            Text("Contact Support")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Support")
                }

                Section {
                    legalRow(icon: "lock.shield.fill", colors: [.blue, .cyan], title: "Privacy Policy") {
                        showPrivacyPolicy = true
                    }

                    legalRow(icon: "doc.text.fill", colors: [.purple, .pink], title: "Terms of Service") {
                        showTermsOfService = true
                    }

                    legalRow(icon: "person.3.fill", colors: [.green, .mint], title: "Community Guidelines") {
                        showCommunityGuidelines = true
                    }

                    legalRow(icon: "shield.checkered", colors: [.orange, .yellow], title: "Dating Safety Tips") {
                        showSafetyTips = true
                    }

                    legalRow(icon: "server.rack", colors: [.gray, .gray.opacity(0.7)], title: "Cookie & Data Policy") {
                        showCookiePolicy = true
                    }

                    legalRow(icon: "doc.badge.gearshape.fill", colors: [.indigo, .purple], title: "End User License Agreement") {
                        showEULA = true
                    }

                    legalRow(icon: "accessibility", colors: [.teal, .mint], title: "Accessibility Statement") {
                        showAccessibility = true
                    }
                } header: {
                    Text("Legal")
                }
                
                // Admin section - only visible for admin users
                if isAdminUser {
                    Section {
                        Button {
                            showAdminDashboard = true
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.red.opacity(0.15), Color.pink.opacity(0.1)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "shield.checkered")
                                        .font(.callout)
                                        .foregroundStyle(
                                            LinearGradient(colors: [.red, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        )
                                }
                                Text("Moderation Dashboard")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Admin")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "trash.fill")
                                    .font(.callout)
                                    .foregroundColor(.red)
                            }
                            Text("Delete Account")
                                .foregroundColor(.red)
                            if isDeleting {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .tint(.red)
                            }
                        }
                    }
                    .disabled(isDeleting)
                } header: {
                    Text("Danger Zone")
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
                        isDeleting = true
                        do {
                            try await authService.deleteAccount()
                        } catch let error as CelestiaError {
                            isDeleting = false
                            switch error {
                            case .requiresRecentLogin:
                                deleteErrorMessage = "For security, please sign out and sign back in before deleting your account."
                            case .notAuthenticated:
                                deleteErrorMessage = "You must be signed in to delete your account."
                            default:
                                deleteErrorMessage = "Failed to delete account. Please try again later."
                            }
                            showDeleteError = true
                            Logger.shared.error("Error deleting account", category: .general, error: error)
                        } catch let error as NSError {
                            isDeleting = false
                            if error.domain == "FIRFirestoreErrorDomain" && error.code == 7 {
                                deleteErrorMessage = "Permission denied. Please sign out and sign back in, then try again."
                            } else if error.domain == "FIRAuthErrorDomain" && error.code == 17014 {
                                deleteErrorMessage = "For security, please sign out and sign back in before deleting your account."
                            } else {
                                deleteErrorMessage = "Failed to delete account: \(error.localizedDescription)"
                            }
                            showDeleteError = true
                            Logger.shared.error("Error deleting account", category: .general, error: error)
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone.")
            }
            .alert("Delete Failed", isPresented: $showDeleteError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deleteErrorMessage)
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
    // Uses both Firestore isAdmin field AND email whitelist (for bootstrapping)
    private var isAdminUser: Bool {
        // First check if user has isAdmin flag in Firestore (authoritative)
        if authService.currentUser?.isAdmin == true {
            return true
        }

        // Fallback to email whitelist for bootstrapping new admin accounts
        // Once isAdmin is set in Firestore, this is just a secondary check
        guard let email = authService.currentUser?.email else { return false }
        let adminEmails = ["perezkevin640@gmail.com", "admin@celestia.app"]
        return adminEmails.contains(email.lowercased())
    }

    // MARK: - Row Styling Helpers

    @ViewBuilder
    private func settingsRow<Content: View>(icon: String, colors: [Color], @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [colors[0].opacity(0.15), colors.last!.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundStyle(
                        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            content()
        }
    }

    @ViewBuilder
    private func statusBadge(text: String, colors: [Color]) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
                    )
                    .shadow(color: colors[0].opacity(0.3), radius: 3, y: 2)
            )
    }

    @ViewBuilder
    private func legalRow(icon: String, colors: [Color], title: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [colors[0].opacity(0.15), colors.last!.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.callout)
                        .foregroundStyle(
                            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Profile Status Helpers

    private func profileStatusIcon(for status: String?) -> String {
        switch status?.lowercased() {
        case "active", "approved":
            return "checkmark.seal.fill"
        case "pending":
            return "clock.fill"
        case "rejected":
            return "xmark.circle.fill"
        case "flagged":
            return "flag.fill"
        case "suspended":
            return "pause.circle.fill"
        case "banned":
            return "nosign"
        default:
            return "clock.fill"
        }
    }

    private func profileStatusColors(for status: String?) -> [Color] {
        switch status?.lowercased() {
        case "active", "approved":
            return [.green, .mint]
        case "pending":
            return [.orange, .yellow]
        case "rejected":
            return [.red, .pink]
        case "flagged":
            return [.yellow, .orange]
        case "suspended":
            return [.orange, .red]
        case "banned":
            return [.red, .pink]
        default:
            return [.orange, .yellow]
        }
    }

    private func profileStatusText(for status: String?) -> String {
        switch status?.lowercased() {
        case "active", "approved":
            return "Active"
        case "pending":
            return "Pending Review"
        case "rejected":
            return "Needs Updates"
        case "flagged":
            return "Under Review"
        case "suspended":
            return "Suspended"
        case "banned":
            return "Banned"
        default:
            return "Pending Review"
        }
    }

    // MARK: - Verification Status Helpers

    private func verificationStatusIcon(for user: User) -> String {
        if user.isVerified {
            return "checkmark.shield.fill"
        } else if user.idVerificationRejected {
            return "xmark.shield.fill"
        } else {
            return "shield"
        }
    }

    private func verificationStatusColors(for user: User) -> [Color] {
        if user.isVerified {
            return [.green, .mint]
        } else if user.idVerificationRejected {
            return [.red, .pink]
        } else {
            return [.gray, .gray.opacity(0.7)]
        }
    }

    private func verificationStatusText(for user: User) -> String {
        if user.isVerified {
            return "Verified"
        } else if user.idVerificationRejected {
            return "Rejected"
        } else {
            return "Not Verified"
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthService.shared)
}
