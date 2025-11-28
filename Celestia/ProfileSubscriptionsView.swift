//
//  ProfileSubscriptionsView.swift
//  Celestia
//
//  Shows subscription management with swipeable tabs - consistent with LikesView and SavedProfilesView
//

import SwiftUI

struct ProfileSubscriptionsView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var storeManager = StoreManager.shared

    @State private var selectedTab = 0
    @State private var showPremiumUpgrade = false
    @State private var isRestoring = false

    private let tabs = ["Current Plan", "Features", "Account"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerView

                // Tab selector - matching LikesView and SavedProfilesView pattern
                tabSelector

                // Content based on selected tab - SWIPEABLE TabView
                TabView(selection: $selectedTab) {
                    currentPlanTab.tag(0)
                    featuresTab.tag(1)
                    accountTab.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showPremiumUpgrade) {
                PremiumUpgradeView()
                    .environmentObject(authService)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        ZStack {
            // Gradient background - matching LikesView and SavedProfilesView
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.9),
                    Color.pink.opacity(0.7),
                    Color.orange.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Decorative elements
            GeometryReader { geo in
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)
                    .offset(x: -30, y: 20)

                Circle()
                    .fill(Color.yellow.opacity(0.15))
                    .frame(width: 60, height: 60)
                    .blur(radius: 15)
                    .offset(x: geo.size.width - 50, y: 40)
            }

            VStack(spacing: 12) {
                HStack(alignment: .center) {
                    // Back button
                    Button {
                        dismiss()
                        HapticManager.shared.impact(.light)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }

                    // Title section
                    HStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .yellow.opacity(0.4), radius: 10)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Subscription")
                                .font(.title2.weight(.bold))
                                .foregroundColor(.white)

                            Text(subscriptionStatusText)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                .padding(.bottom, 16)
            }
        }
        .frame(height: 130)
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }

    private var subscriptionStatusText: String {
        if authService.currentUser?.isPremium == true {
            return "Premium Member"
        } else {
            return "Free Account"
        }
    }

    // MARK: - Tab Selector (matching LikesView and SavedProfilesView)

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.0) { index, title in
                Button {
                    HapticManager.shared.selection()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Text(title)
                                .font(.subheadline)
                                .fontWeight(selectedTab == index ? .semibold : .medium)

                            // Status indicator for current plan
                            if index == 0 && authService.currentUser?.isPremium == true {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(selectedTab == index ? .green : .gray)
                            }
                        }
                        .foregroundColor(selectedTab == index ? .purple : .gray)

                        Rectangle()
                            .fill(selectedTab == index ? Color.purple : Color.clear)
                            .frame(height: 3)
                            .cornerRadius(1.5)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .background(Color.white)
    }

    // MARK: - Current Plan Tab

    private var currentPlanTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Current subscription status card
                currentPlanCard

                // Upgrade or manage button
                if authService.currentUser?.isPremium != true {
                    upgradePromptCard
                } else {
                    managePlanCard
                }

                // Subscription benefits summary
                benefitsSummaryCard
            }
            .padding(16)
            .padding(.bottom, 100)
        }
    }

    private var currentPlanCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: authService.currentUser?.isPremium == true ? "crown.fill" : "person.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                authService.currentUser?.isPremium == true ?
                                LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing)
                            )

                        Text(authService.currentUser?.isPremium == true ? "Premium" : "Free")
                            .font(.title2.weight(.bold))
                    }

                    Text(authService.currentUser?.isPremium == true ?
                         "Enjoying all premium features" :
                         "Upgrade to unlock more features")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if authService.currentUser?.isPremium == true {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Active")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(8)
                    }
                }
            }

            Divider()

            // Plan details
            VStack(spacing: 12) {
                planDetailRow(icon: "calendar", label: "Status", value: authService.currentUser?.isPremium == true ? "Active" : "Free Tier")
                planDetailRow(icon: "heart.fill", label: "Daily Likes", value: authService.currentUser?.isPremium == true ? "Unlimited" : "Limited")
                planDetailRow(icon: "eye.fill", label: "See Who Likes You", value: authService.currentUser?.isPremium == true ? "Yes" : "No")
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    private func planDetailRow(icon: String, label: String, value: String) -> some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(.purple)
                    .frame(width: 24)

                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    private var upgradePromptCard: some View {
        Button {
            showPremiumUpgrade = true
            HapticManager.shared.impact(.medium)
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: "crown.fill")
                        .font(.title3)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Upgrade to Premium")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Get unlimited likes & exclusive features")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color.yellow.opacity(0.1), Color.orange.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
        }
    }

    private var managePlanCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Manage Subscription")
                        .font(.headline)

                    Text("Update or cancel your plan")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    // Open App Store subscription management
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Manage")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    private var benefitsSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Benefits")
                .font(.headline)

            VStack(spacing: 12) {
                benefitRow(icon: "flame.fill", text: "Daily profile discovery", included: true)
                benefitRow(icon: "heart.fill", text: "Unlimited likes", included: authService.currentUser?.isPremium == true)
                benefitRow(icon: "eye.fill", text: "See who likes you", included: authService.currentUser?.isPremium == true)
                benefitRow(icon: "arrow.uturn.left", text: "Rewind swipes", included: authService.currentUser?.isPremium == true)
                benefitRow(icon: "star.fill", text: "Super likes", included: authService.currentUser?.isPremium == true)
                benefitRow(icon: "bolt.fill", text: "Profile boost", included: authService.currentUser?.isPremium == true)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    private func benefitRow(icon: String, text: String, included: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(included ? .purple : .gray.opacity(0.5))
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundColor(included ? .primary : .secondary)

            Spacer()

            Image(systemName: included ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(included ? .green : .gray.opacity(0.3))
        }
    }

    // MARK: - Features Tab

    private var featuresTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Premium features showcase
                featureCard(
                    icon: "infinity",
                    title: "Unlimited Likes",
                    description: "Like as many profiles as you want without daily limits",
                    color: .purple,
                    isPremium: true
                )

                featureCard(
                    icon: "eye.fill",
                    title: "See Who Likes You",
                    description: "Know who's interested before you swipe",
                    color: .pink,
                    isPremium: true
                )

                featureCard(
                    icon: "arrow.uturn.left",
                    title: "Rewind Swipes",
                    description: "Undo accidental passes and get another chance",
                    color: .blue,
                    isPremium: true
                )

                featureCard(
                    icon: "star.fill",
                    title: "Super Likes",
                    description: "Stand out and get 3x more matches",
                    color: .cyan,
                    isPremium: true
                )

                featureCard(
                    icon: "bolt.fill",
                    title: "Profile Boost",
                    description: "Be seen by 10x more people for 30 minutes",
                    color: .orange,
                    isPremium: true
                )

                featureCard(
                    icon: "shield.checkered",
                    title: "Priority Support",
                    description: "Get help faster when you need it",
                    color: .green,
                    isPremium: true
                )
            }
            .padding(16)
            .padding(.bottom, 100)
        }
    }

    private func featureCard(icon: String, title: String, description: String, color: Color, isPremium: Bool) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.headline)

                    if isPremium && authService.currentUser?.isPremium != true {
                        Text("PREMIUM")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple)
                            .cornerRadius(4)
                    }
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if authService.currentUser?.isPremium == true || !isPremium {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
            } else {
                Image(systemName: "lock.fill")
                    .foregroundColor(.gray.opacity(0.5))
                    .font(.title3)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    // MARK: - Account Tab

    private var accountTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Account info
                accountInfoCard

                // Account actions
                accountActionsCard

                // Help section
                helpCard
            }
            .padding(16)
            .padding(.bottom, 100)
        }
    }

    private var accountInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account Information")
                .font(.headline)

            VStack(spacing: 12) {
                if let user = authService.currentUser {
                    accountRow(label: "Name", value: user.fullName)
                    Divider()
                    accountRow(label: "Email", value: user.email)
                    Divider()
                    accountRow(label: "Member Since", value: formatDate(user.timestamp))
                    Divider()
                    accountRow(label: "Account Type", value: user.isPremium ? "Premium" : "Free")
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    private func accountRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    private var accountActionsCard: some View {
        VStack(spacing: 0) {
            Button {
                // Restore purchases using StoreManager
                isRestoring = true
                Task {
                    do {
                        try await storeManager.restorePurchases()
                        await subscriptionManager.updateSubscriptionStatus()
                        HapticManager.shared.notification(.success)
                    } catch {
                        HapticManager.shared.notification(.error)
                    }
                    isRestoring = false
                }
            } label: {
                HStack {
                    if isRestoring {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.purple)
                    }
                    Text(isRestoring ? "Restoring..." : "Restore Purchases")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(16)
            }
            .disabled(isRestoring)

            Divider()
                .padding(.leading, 44)

            Button {
                // Open App Store subscriptions
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Image(systemName: "gear")
                        .foregroundColor(.purple)
                    Text("Manage Subscriptions")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(16)
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    private var helpCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Need Help?")
                .font(.headline)

            VStack(spacing: 0) {
                Button {
                    if let url = URL(string: "mailto:support@celestia.app") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.blue)
                        Text("Contact Support")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 12)
                }

                Divider()

                Button {
                    if let url = URL(string: "https://celestia.app/faq") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("FAQ")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 12)
                }

                Divider()

                Button {
                    if let url = URL(string: "https://celestia.app/terms") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.gray)
                        Text("Terms of Service")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    ProfileSubscriptionsView()
        .environmentObject(AuthService.shared)
}
