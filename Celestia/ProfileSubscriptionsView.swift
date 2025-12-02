//
//  ProfileSubscriptionsView.swift
//  Celestia
//
//  Shows subscription management with swipeable tabs - consistent with LikesView and SavedProfilesView
//  Features tab now uses Tinder-style card swiping for better UX
//

import SwiftUI

// MARK: - Feature Card Model
struct FeatureCardItem: Identifiable, Equatable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let color: Color
    let gradient: [Color]
    let benefit: String

    static func == (lhs: FeatureCardItem, rhs: FeatureCardItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct ProfileSubscriptionsView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var storeManager = StoreManager.shared

    @State private var selectedTab = 0
    @State private var showPremiumUpgrade = false
    @State private var isRestoring = false

    // Feature cards state
    @State private var currentFeatureIndex = 0
    @State private var cardOffset: CGSize = .zero
    @State private var cardRotation: Double = 0

    private let tabs = ["Current Plan", "Features", "Account"]

    // Premium feature cards data
    private let featureCards: [FeatureCardItem] = [
        FeatureCardItem(
            icon: "infinity",
            title: "Unlimited Likes",
            description: "Like as many profiles as you want without daily limits. Never miss a potential match!",
            color: .purple,
            gradient: [Color.purple, Color.indigo],
            benefit: "No restrictions on your dating journey"
        ),
        FeatureCardItem(
            icon: "eye.fill",
            title: "See Who Likes You",
            description: "Know who's interested in you before you swipe. Make confident decisions!",
            color: .pink,
            gradient: [Color.pink, Color.red.opacity(0.8)],
            benefit: "Skip the guessing game"
        ),
        FeatureCardItem(
            icon: "star.fill",
            title: "Super Likes",
            description: "Stand out from the crowd and show you're really interested. Get 3x more matches!",
            color: .cyan,
            gradient: [Color.cyan, Color.teal],
            benefit: "Make a lasting impression"
        ),
        FeatureCardItem(
            icon: "bolt.fill",
            title: "Profile Boost",
            description: "Be seen by 10x more people for 30 minutes. Get more matches faster!",
            color: .orange,
            gradient: [Color.orange, Color.yellow],
            benefit: "Supercharge your visibility"
        ),
        FeatureCardItem(
            icon: "sparkles",
            title: "Priority Matching",
            description: "Get matched with compatible profiles first. Our algorithm works harder for you!",
            color: .green,
            gradient: [Color.green, Color.mint],
            benefit: "Quality over quantity"
        )
    ]

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
            .padding(.bottom, 80)
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

    // MARK: - Features Tab (Tinder-style Swipeable Cards)

    private var featuresTab: some View {
        VStack(spacing: 0) {
            // Header instruction
            VStack(spacing: 8) {
                Text("Swipe to explore features")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                // Progress indicator
                HStack(spacing: 6) {
                    ForEach(0..<featureCards.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentFeatureIndex ? Color.purple : Color.gray.opacity(0.3))
                            .frame(width: index == currentFeatureIndex ? 10 : 8, height: index == currentFeatureIndex ? 10 : 8)
                            .animation(.spring(response: 0.3), value: currentFeatureIndex)
                    }
                }

                Text("\(currentFeatureIndex + 1) of \(featureCards.count)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Card stack area
            GeometryReader { geometry in
                ZStack {
                    // Background cards (stacked effect)
                    ForEach(Array(featureCards.enumerated().reversed()), id: \.element.id) { index, card in
                        if index >= currentFeatureIndex && index < currentFeatureIndex + 3 {
                            SwipeableFeatureCard(
                                card: card,
                                isPremium: authService.currentUser?.isPremium == true,
                                isTopCard: index == currentFeatureIndex
                            )
                            .frame(width: geometry.size.width - 40)
                            .offset(
                                x: index == currentFeatureIndex ? cardOffset.width : 0,
                                y: CGFloat(index - currentFeatureIndex) * 8
                            )
                            .scaleEffect(index == currentFeatureIndex ? 1.0 : 1.0 - CGFloat(index - currentFeatureIndex) * 0.05)
                            .rotationEffect(.degrees(index == currentFeatureIndex ? cardRotation : 0))
                            .opacity(index == currentFeatureIndex ? 1.0 : 0.7 - Double(index - currentFeatureIndex) * 0.2)
                            .zIndex(Double(featureCards.count - index))
                            .gesture(
                                index == currentFeatureIndex ?
                                DragGesture()
                                    .onChanged { gesture in
                                        cardOffset = gesture.translation
                                        cardRotation = Double(gesture.translation.width / 25)
                                    }
                                    .onEnded { gesture in
                                        handleSwipeEnd(gesture: gesture)
                                    }
                                : nil
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 20)

            // Navigation buttons
            HStack(spacing: 40) {
                // Previous button
                Button {
                    goToPreviousCard()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 60, height: 60)

                        Image(systemName: "arrow.left")
                            .font(.title2.weight(.semibold))
                            .foregroundColor(currentFeatureIndex > 0 ? .purple : .gray.opacity(0.4))
                    }
                }
                .disabled(currentFeatureIndex == 0)

                // Upgrade button
                if authService.currentUser?.isPremium != true {
                    Button {
                        showPremiumUpgrade = true
                        HapticManager.shared.impact(.medium)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .font(.headline)
                            Text("Unlock All")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                        .shadow(color: .purple.opacity(0.4), radius: 10, y: 5)
                    }
                }

                // Next button
                Button {
                    goToNextCard()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 60, height: 60)

                        Image(systemName: "arrow.right")
                            .font(.title2.weight(.semibold))
                            .foregroundColor(currentFeatureIndex < featureCards.count - 1 ? .purple : .gray.opacity(0.4))
                    }
                }
                .disabled(currentFeatureIndex == featureCards.count - 1)
            }
            .padding(.bottom, 30)
        }
    }

    // MARK: - Card Navigation

    private func handleSwipeEnd(gesture: DragGesture.Value) {
        let threshold: CGFloat = 100
        let horizontalSwipe = gesture.translation.width

        if horizontalSwipe > threshold && currentFeatureIndex > 0 {
            // Swipe right - go to previous
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                cardOffset = CGSize(width: 500, height: 0)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                currentFeatureIndex -= 1
                cardOffset = .zero
                cardRotation = 0
                HapticManager.shared.impact(.light)
            }
        } else if horizontalSwipe < -threshold && currentFeatureIndex < featureCards.count - 1 {
            // Swipe left - go to next
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                cardOffset = CGSize(width: -500, height: 0)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                currentFeatureIndex += 1
                cardOffset = .zero
                cardRotation = 0
                HapticManager.shared.impact(.light)
            }
        } else {
            // Return to center
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                cardOffset = .zero
                cardRotation = 0
            }
        }
    }

    private func goToNextCard() {
        guard currentFeatureIndex < featureCards.count - 1 else { return }
        HapticManager.shared.selection()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            cardOffset = CGSize(width: -500, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            currentFeatureIndex += 1
            cardOffset = .zero
            cardRotation = 0
        }
    }

    private func goToPreviousCard() {
        guard currentFeatureIndex > 0 else { return }
        HapticManager.shared.selection()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            cardOffset = CGSize(width: 500, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            currentFeatureIndex -= 1
            cardOffset = .zero
            cardRotation = 0
        }
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
            .padding(.bottom, 80)
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

// MARK: - Swipeable Feature Card Component

struct SwipeableFeatureCard: View {
    let card: FeatureCardItem
    let isPremium: Bool
    let isTopCard: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Top gradient section with icon
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: card.gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Decorative circles
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .blur(radius: 30)
                    .offset(x: -80, y: -40)

                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .blur(radius: 20)
                    .offset(x: 100, y: 60)

                // Main icon
                VStack(spacing: 16) {
                    ZStack {
                        // Glow effect
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 100, height: 100)
                            .blur(radius: 20)

                        // Icon circle
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 90, height: 90)

                        Image(systemName: card.icon)
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    // Status badge
                    HStack(spacing: 6) {
                        Image(systemName: isPremium ? "checkmark.circle.fill" : "lock.fill")
                            .font(.caption)
                        Text(isPremium ? "Unlocked" : "Premium")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.25))
                    .cornerRadius(20)
                }
            }
            .frame(height: 200)

            // Content section
            VStack(spacing: 16) {
                // Title
                Text(card.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                // Description
                Text(card.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 8)

                // Benefit highlight
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(card.color)

                    Text(card.benefit)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(card.color)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(card.color.opacity(0.1))
                .cornerRadius(20)

                Spacer()

                // Swipe hint (only on top card)
                if isTopCard {
                    HStack(spacing: 20) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                                .font(.caption2)
                            Text("Swipe")
                                .font(.caption2)
                        }
                        .foregroundColor(.gray.opacity(0.6))

                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 4, height: 4)

                        HStack(spacing: 4) {
                            Text("Swipe")
                                .font(.caption2)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                        }
                        .foregroundColor(.gray.opacity(0.6))
                    }
                    .padding(.bottom, 8)
                }
            }
            .padding(20)
            .background(Color.white)
        }
        .frame(height: 420)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: card.color.opacity(0.3), radius: 20, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white, lineWidth: 2)
        )
    }
}
