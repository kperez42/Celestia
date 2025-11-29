//
//  PremiumUpgradeView.swift
//  Celestia
//
//  PREMIUM UPGRADE - Immersive Conversion Experience
//

import SwiftUI
import StoreKit

struct PremiumUpgradeView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @StateObject private var storeManager = StoreManager.shared

    @State private var selectedPlan: PremiumPlan = .annual
    @State private var showPurchaseSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isProcessing = false

    // Animation states
    @State private var animateHero = false
    @State private var animateCards = false
    @State private var animateFeatures = false
    @State private var pulseGlow = false
    @State private var currentShowcaseIndex = 0
    @State private var showLimitedOffer = true

    // Timer for showcase rotation
    let showcaseTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    // Dark background color used throughout
    private let darkBackground = Color(red: 0.1, green: 0.05, blue: 0.2)

    var body: some View {
        ZStack {
            // Full screen dark background
            darkBackground
                .ignoresSafeArea(.all)

            NavigationStack {
                ZStack {
                    // Content background
                    darkBackground
                        .ignoresSafeArea(.all)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Immersive hero with live preview
                            immersiveHero

                            // Content sections
                            VStack(spacing: 28) {
                                // Limited time banner
                                if showLimitedOffer {
                                    limitedTimeBanner
                                }

                                // Live feature showcase
                                liveFeatureShowcase

                                // Stats that matter
                                impactStats

                                // Feature comparison
                                featureComparisonSection

                                // Pricing cards
                                pricingSection

                                // Real success stories
                                successStoriesSection

                                // Money back guarantee
                                guaranteeSection

                                // FAQ
                                faqSection
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                            .padding(.bottom, 140)
                        }
                    }
                    .scrollContentBackground(.hidden)

                    // Floating CTA
                    VStack {
                        Spacer()
                        floatingCTA
                    }
                }
                .background(darkBackground.ignoresSafeArea(.all))
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Restore") {
                            restorePurchases()
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white.opacity(0.9))
                    }
                }
                .alert("Welcome to Premium!", isPresented: $showPurchaseSuccess) {
                    Button("Start Discovering") {
                        dismiss()
                    }
                } message: {
                    Text("You now have unlimited access to all premium features. Your feed just got a whole lot better!")
                }
                .alert("Error", isPresented: $showError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(errorMessage)
                }
                .overlay {
                    if isProcessing {
                        processingOverlay
                    }
                }
                .onAppear {
                    startAnimations()
                    Task {
                        await storeManager.loadProducts()
                    }
                }
                .onReceive(showcaseTimer) { _ in
                    withAnimation(.easeInOut(duration: 0.5)) {
                        currentShowcaseIndex = (currentShowcaseIndex + 1) % 4
                    }
                }
            }
        }
    }

    // MARK: - Animated Background

    private var animatedBackground: some View {
        darkBackground
            .ignoresSafeArea(.all)
    }

    // MARK: - Immersive Hero

    private var immersiveHero: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 20)

            // Animated crown with glow
            ZStack {
                // Glow rings
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.yellow.opacity(0.3), .orange.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2
                        )
                        .frame(width: CGFloat(100 + i * 30), height: CGFloat(100 + i * 30))
                        .scaleEffect(pulseGlow ? 1.1 : 0.9)
                        .opacity(pulseGlow ? 0.3 : 0.6)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2),
                            value: pulseGlow
                        )
                }

                // Crown icon
                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .yellow.opacity(0.6), radius: 20)
                    .shadow(color: .orange.opacity(0.4), radius: 40)
                    .scaleEffect(animateHero ? 1 : 0.5)
                    .rotationEffect(.degrees(animateHero ? 0 : -20))
            }
            .frame(height: 160)

            // Title
            VStack(spacing: 12) {
                Text("Go Premium")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(animateHero ? 1 : 0)
                    .offset(y: animateHero ? 0 : 20)

                Text("Discover more people who match your vibe")
                    .font(.title3.weight(.medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .opacity(animateHero ? 1 : 0)
                    .offset(y: animateHero ? 0 : 15)
            }

            // Mini preview cards (showing what premium unlocks)
            miniPreviewCards
                .padding(.top, 10)

            Spacer().frame(height: 10)
        }
        .frame(height: 420)
    }

    // MARK: - Mini Preview Cards

    private var miniPreviewCards: some View {
        HStack(spacing: -20) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: previewCardColors(for: index),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 90)
                    .overlay(
                        VStack {
                            Image(systemName: previewCardIcon(for: index))
                                .font(.title2)
                                .foregroundColor(.white)
                            Text(previewCardLabel(for: index))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    )
                    .shadow(color: previewCardColors(for: index)[0].opacity(0.4), radius: 8, y: 4)
                    .rotationEffect(.degrees(Double(index - 2) * 8))
                    .offset(y: index == currentShowcaseIndex ? -10 : 0)
                    .scaleEffect(index == currentShowcaseIndex ? 1.1 : 1)
                    .zIndex(index == currentShowcaseIndex ? 1 : 0)
                    .opacity(animateCards ? 1 : 0)
                    .offset(y: animateCards ? 0 : 30)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.1), value: animateCards)
            }
        }
    }

    private func previewCardColors(for index: Int) -> [Color] {
        switch index {
        case 0: return [.purple, .purple.opacity(0.7)]
        case 1: return [.pink, .pink.opacity(0.7)]
        case 2: return [.orange, .orange.opacity(0.7)]
        default: return [.cyan, .cyan.opacity(0.7)]
        }
    }

    private func previewCardIcon(for index: Int) -> String {
        switch index {
        case 0: return "infinity"
        case 1: return "eye.fill"
        case 2: return "message.fill"
        default: return "star.fill"
        }
    }

    private func previewCardLabel(for index: Int) -> String {
        switch index {
        case 0: return "Unlimited"
        case 1: return "See Likes"
        case 2: return "Message"
        default: return "Super Like"
        }
    }

    // MARK: - Limited Time Banner

    private var limitedTimeBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.title3)
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Limited Time: 50% Off Annual")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)

                Text("Offer ends soon")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            Button {
                withAnimation {
                    showLimitedOffer = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.3), Color.red.opacity(0.2)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .background(.ultraThinMaterial.opacity(0.5))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Live Feature Showcase

    private var liveFeatureShowcase: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("What You're Missing")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)

                Spacer()

                // Live indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(.green.opacity(0.5), lineWidth: 2)
                                .scaleEffect(pulseGlow ? 1.5 : 1)
                                .opacity(pulseGlow ? 0 : 0.5)
                        )

                    Text("LIVE")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.green)
                }
            }

            // Showcase card
            showcaseCard
        }
    }

    private var showcaseCard: some View {
        let showcases = [
            ("23 people liked you today", "heart.circle.fill", Color.pink, "See who they are with Premium"),
            ("You're missing 15+ profiles", "eye.slash.fill", Color.purple, "Get unlimited browsing"),
            ("5 Super Likes ready to use", "star.circle.fill", Color.yellow, "Stand out in their feed"),
            ("Send unlimited messages", "message.circle.fill", Color.orange, "Connect with anyone you like")
        ]

        let current = showcases[currentShowcaseIndex]

        return HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(current.2.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: current.1)
                    .font(.title)
                    .foregroundColor(current.2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(current.0)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(current.3)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [current.2.opacity(0.5), current.2.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: current.2.opacity(0.2), radius: 20, y: 10)
    }

    // MARK: - Impact Stats

    private var impactStats: some View {
        HStack(spacing: 0) {
            impactStat(value: "3x", label: "More Matches", icon: "heart.fill", color: .pink)

            Divider()
                .frame(height: 50)
                .background(Color.white.opacity(0.2))

            impactStat(value: "10x", label: "More Views", icon: "eye.fill", color: .purple)

            Divider()
                .frame(height: 50)
                .background(Color.white.opacity(0.2))

            impactStat(value: "85%", label: "Success Rate", icon: "checkmark.seal.fill", color: .green)
        }
        .padding(.vertical, 20)
        .background(.ultraThinMaterial.opacity(0.3))
        .cornerRadius(20)
    }

    private func impactStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)

                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
            }

            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Feature Comparison

    private var featureComparisonSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Premium vs Free")
                .font(.title2.weight(.bold))
                .foregroundColor(.white)

            VStack(spacing: 12) {
                comparisonRow(feature: "Send Messages", free: "Limited", premium: "Unlimited", icon: "message.fill")
                comparisonRow(feature: "Daily Likes", free: "50/day", premium: "Unlimited", icon: "heart.fill")
                comparisonRow(feature: "See Who Likes You", free: "Hidden", premium: "Full Access", icon: "eye.fill")
                comparisonRow(feature: "Super Likes", free: "1/day", premium: "5/day", icon: "star.fill")
                comparisonRow(feature: "Rewind Profiles", free: "No", premium: "Unlimited", icon: "arrow.uturn.backward")
                comparisonRow(feature: "Advanced Filters", free: "Basic", premium: "All Filters", icon: "slider.horizontal.3")
                comparisonRow(feature: "Read Receipts", free: "No", premium: "Yes", icon: "checkmark.message.fill")
                comparisonRow(feature: "Priority in Feed", free: "Standard", premium: "Top Priority", icon: "arrow.up.circle.fill")
            }
            .padding(20)
            .background(.ultraThinMaterial.opacity(0.3))
            .cornerRadius(20)
        }
    }

    private func comparisonRow(feature: String, free: String, premium: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.purple)
                .frame(width: 20)

            Text(feature)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(free)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 55, alignment: .trailing)

            Image(systemName: "chevron.right")
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.3))

            Text(premium)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.green)
                .frame(width: 60, alignment: .trailing)
        }
    }

    // MARK: - Pricing Section

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Choose Your Plan")
                .font(.title2.weight(.bold))
                .foregroundColor(.white)

            VStack(spacing: 12) {
                ForEach(PremiumPlan.allCases, id: \.self) { plan in
                    PremiumPlanCard(
                        plan: plan,
                        isSelected: selectedPlan == plan,
                        onSelect: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedPlan = plan
                                HapticManager.shared.selection()
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Success Stories

    private var successStoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Success Stories")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("4.8")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }

            VStack(spacing: 12) {
                successStoryCard(
                    initials: "JM",
                    name: "Jake M.",
                    story: "Found my match within 2 weeks! The 'See Who Likes You' feature was a game changer.",
                    color: .purple
                )

                successStoryCard(
                    initials: "SE",
                    name: "Sarah E.",
                    story: "So many more quality matches since upgrading. Unlimited likes means I never miss someone.",
                    color: .pink
                )

                successStoryCard(
                    initials: "AT",
                    name: "Alex T.",
                    story: "Profile boost got me 3x the views. Met amazing people I would have missed.",
                    color: .orange
                )
            }
        }
    }

    private func successStoryCard(initials: String, name: String, story: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay(
                    Text(initials)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)

                    Spacer()

                    HStack(spacing: 2) {
                        ForEach(0..<5) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.yellow)
                        }
                    }
                }

                Text("\"\(story)\"")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)
                    .italic()
            }
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.3))
        .cornerRadius(16)
    }

    // MARK: - Guarantee Section

    private var guaranteeSection: some View {
        HStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.title)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("7-Day Free Trial")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("Try Premium risk-free. Cancel anytime before your trial ends and pay nothing.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.15), Color.green.opacity(0.05)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .background(.ultraThinMaterial.opacity(0.3))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - FAQ Section

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Common Questions")
                .font(.title2.weight(.bold))
                .foregroundColor(.white)

            VStack(spacing: 8) {
                FAQItem(
                    question: "Can I cancel anytime?",
                    answer: "Yes! Cancel your subscription anytime from Settings. You'll keep premium access until your billing period ends."
                )

                FAQItem(
                    question: "Do I keep my matches if I cancel?",
                    answer: "Absolutely! All your matches and conversations are yours to keep. You just won't have access to premium features."
                )

                FAQItem(
                    question: "How does the free trial work?",
                    answer: "Try Premium free for 7 days. You won't be charged until the trial ends. Cancel anytime before that and pay nothing."
                )
            }
        }
    }

    // MARK: - Floating CTA

    private var floatingCTA: some View {
        VStack(spacing: 6) {
            // Main button
            Button {
                purchasePremium()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "crown.fill")
                        .font(.body)

                    Text("Start 7-Day Free Trial")
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    Text("\(selectedPlan.price)/\(selectedPlan.period)")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .purple.opacity(0.4), radius: 15, y: 8)
            }
            .disabled(isProcessing)

            // Trust indicators
            HStack(spacing: 12) {
                Label("Secure", systemImage: "lock.fill")
                Label("Cancel Anytime", systemImage: "arrow.clockwise")
            }
            .font(.caption2)
            .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(darkBackground.ignoresSafeArea(edges: .bottom))
    }

    // MARK: - Processing Overlay

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Animated loading
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 4)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(isProcessing ? 360 : 0))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isProcessing)
                }

                VStack(spacing: 8) {
                    Text("Processing...")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("Please wait while we set up your premium access")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
            animateHero = true
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3)) {
            animateCards = true
        }

        withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.5)) {
            animateFeatures = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pulseGlow = true
        }
    }

    // MARK: - Actions

    private func purchasePremium() {
        isProcessing = true

        Task {
            do {
                guard let product = storeManager.getProduct(for: selectedPlan) else {
                    throw PurchaseError.productNotFound
                }

                let result = try await storeManager.purchase(product)

                if result.isSuccess {
                    if var user = authService.currentUser {
                        user.isPremium = true
                        user.premiumTier = selectedPlan.rawValue
                        user.subscriptionExpiryDate = nil
                        try await authService.updateUser(user)
                    }

                    await MainActor.run {
                        isProcessing = false
                        showPurchaseSuccess = true
                        HapticManager.shared.notification(.success)
                    }
                } else {
                    await MainActor.run {
                        isProcessing = false
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func restorePurchases() {
        isProcessing = true

        Task {
            do {
                try await storeManager.restorePurchases()

                await MainActor.run {
                    isProcessing = false

                    if storeManager.hasActiveSubscription {
                        showPurchaseSuccess = true
                        HapticManager.shared.notification(.success)
                    } else {
                        errorMessage = "No active subscriptions found"
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Premium Plan Card

struct PremiumPlanCard: View {
    let plan: PremiumPlan
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.purple : Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 16, height: 16)
                    }
                }

                // Plan details
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(plan.name)
                            .font(.headline)
                            .foregroundColor(.white)

                        if plan == .annual {
                            Text("BEST VALUE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    LinearGradient(
                                        colors: [.green, .mint],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(6)
                        }

                        if plan == .sixMonth {
                            Text("POPULAR")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.orange)
                                .cornerRadius(6)
                        }
                    }

                    Text(plan.totalPrice)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                // Price
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(plan.price)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        Text("/\(plan.period)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }

                    if plan.savings > 0 {
                        Text("Save \(plan.savings)%")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ?
                        LinearGradient(
                            colors: [Color.purple.opacity(0.3), Color.pink.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ?
                        LinearGradient(
                            colors: [Color.purple, Color.pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(color: isSelected ? .purple.opacity(0.3) : .clear, radius: 15, y: 8)
        }
    }
}

// MARK: - FAQ Item

struct FAQItem: View {
    let question: String
    let answer: String

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(question)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(16)
            }

            if isExpanded {
                Text(answer)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .background(.ultraThinMaterial.opacity(0.2))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        PremiumUpgradeView()
            .environmentObject(AuthService.shared)
    }
}
