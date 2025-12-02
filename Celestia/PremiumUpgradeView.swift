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

    // Context message shown when upgrade is triggered for a specific reason
    var contextMessage: String = ""

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

    // Countdown timer state
    @State private var timeRemaining: Int = 23 * 3600 + 47 * 60 + 32 // 23:47:32
    let countdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Timer for showcase rotation
    let showcaseTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    // Light background colors
    private let lightBackground = Color(red: 0.98, green: 0.98, blue: 1.0)
    private let cardBackground = Color.white
    private let softPurple = Color(red: 0.95, green: 0.94, blue: 1.0)

    var body: some View {
        ZStack {
            // Full screen light background with subtle gradient
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.94, blue: 1.0),
                    Color(red: 1.0, green: 0.98, blue: 0.98),
                    Color.white
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(.all)

            NavigationStack {
                ZStack {
                    // Content background
                    Color.clear

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Immersive hero with live preview
                            immersiveHero

                            // Content sections
                            VStack(spacing: 24) {
                                // Context-specific banner (shown when triggered by limit)
                                if !contextMessage.isEmpty {
                                    contextBanner
                                }

                                // Limited time banner
                                if showLimitedOffer {
                                    limitedTimeBanner
                                }

                                // Who liked you preview (FOMO section)
                                whoLikedYouPreview

                                // Live feature showcase
                                liveFeatureShowcase

                                // Premium badge highlight
                                premiumBadgeSection

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
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(Material.ultraThinMaterial, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(.gray)
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Restore") {
                            restorePurchases()
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.purple)
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
                .onReceive(countdownTimer) { _ in
                    if timeRemaining > 0 {
                        timeRemaining -= 1
                    }
                }
            }
        }
        .preferredColorScheme(.light) // Force light mode for this view only
    }

    // MARK: - Animated Background

    private var animatedBackground: some View {
        lightBackground
            .ignoresSafeArea(.all)
    }

    // MARK: - Immersive Hero

    private var immersiveHero: some View {
        ZStack {
            // Soft gradient background for hero
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.15),
                    Color.pink.opacity(0.1),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 20) {
                Spacer().frame(height: 20)

                // Animated crown with glow
                ZStack {
                    // Soft glow rings
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.purple.opacity(0.15), .clear],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: CGFloat(60 + i * 20)
                                )
                            )
                            .frame(width: CGFloat(100 + i * 30), height: CGFloat(100 + i * 30))
                            .scaleEffect(pulseGlow ? 1.1 : 0.9)
                            .opacity(pulseGlow ? 0.5 : 0.8)
                            .animation(
                                .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.2),
                                value: pulseGlow
                            )
                    }

                    // Crown background circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.2), Color.pink.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)

                    // Crown icon
                    Image(systemName: "crown.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .orange.opacity(0.4), radius: 10)
                        .scaleEffect(animateHero ? 1 : 0.5)
                        .rotationEffect(.degrees(animateHero ? 0 : -20))
                }
                .frame(height: 140)

                // Title
                VStack(spacing: 12) {
                    Text("Go Premium")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(animateHero ? 1 : 0)
                        .offset(y: animateHero ? 0 : 20)

                    Text("Discover more people who match your vibe")
                        .font(.body.weight(.medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .opacity(animateHero ? 1 : 0)
                        .offset(y: animateHero ? 0 : 15)
                }

                // Mini preview cards (showing what premium unlocks)
                miniPreviewCards
                    .padding(.top, 10)

                Spacer().frame(height: 10)
            }
        }
        .frame(height: 380)
    }

    // MARK: - Mini Preview Cards

    private var miniPreviewCards: some View {
        HStack(spacing: -15) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white)
                    .frame(width: 72, height: 92)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: previewCardColors(for: index),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .padding(3)
                    )
                    .overlay(
                        VStack(spacing: 6) {
                            Image(systemName: previewCardIcon(for: index))
                                .font(.title2)
                                .foregroundColor(.white)
                            Text(previewCardLabel(for: index))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.white.opacity(0.95))
                        }
                    )
                    .shadow(color: previewCardColors(for: index)[0].opacity(0.3), radius: 8, y: 4)
                    .rotationEffect(.degrees(Double(index - 2) * 6))
                    .offset(y: index == currentShowcaseIndex ? -8 : 0)
                    .scaleEffect(index == currentShowcaseIndex ? 1.08 : 1)
                    .zIndex(index == currentShowcaseIndex ? 1 : 0)
                    .opacity(animateCards ? 1 : 0)
                    .offset(y: animateCards ? 0 : 30)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.05), value: animateCards)
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
        default: return "Premium"
        }
    }

    // MARK: - Context Banner (Like Limit / Super Like Limit)

    private var contextBanner: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "heart.slash.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Want to continue?")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.primary)

                Text(contextMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.1), Color.pink.opacity(0.06)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.purple.opacity(0.3), .pink.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: .purple.opacity(0.15), radius: 10, y: 5)
    }

    // MARK: - Limited Time Banner

    private var formattedTime: String {
        let hours = timeRemaining / 3600
        let minutes = (timeRemaining % 3600) / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private var limitedTimeBanner: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Fire icon for urgency
                Image(systemName: "flame.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Flash Sale: 50% Off")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.primary)

                    Text("Limited spots available in California")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    withAnimation {
                        showLimitedOffer = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            // Countdown timer
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.caption)
                    .foregroundColor(.red)

                Text("Offer expires in:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(formattedTime)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.red)

                Spacer()

                // Urgency indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                    Text("12 people viewing")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.08))
            .cornerRadius(8)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.1), Color.red.opacity(0.06)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .orange.opacity(0.1), radius: 8, y: 4)
    }

    // MARK: - Who Liked You Preview (FOMO Section)

    private var whoLikedYouPreview: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("People Who Like You")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.primary)

                        // Notification badge
                        Text("23")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.pink)
                            .clipShape(Capsule())
                    }

                    Text("Unlock to see who's interested in you")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "lock.fill")
                    .font(.title3)
                    .foregroundColor(.gray.opacity(0.5))
            }

            // Blurred profile previews
            HStack(spacing: -12) {
                ForEach(0..<5) { index in
                    ZStack {
                        // Blurred avatar placeholder
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: blurredAvatarColors(for: index),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .blur(radius: 3) // Light blur - enough to tease but still see shapes

                        // Subtle overlay - let them see more
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 56, height: 56)

                        // Lock icon on last one
                        if index == 4 {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.4))
                                    .frame(width: 56, height: 56)

                                VStack(spacing: 2) {
                                    Image(systemName: "lock.fill")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                    Text("+18")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // CTA Button
            Button {
                // Scroll to pricing
            } label: {
                HStack {
                    Image(systemName: "eye.fill")
                        .font(.subheadline)
                    Text("See Who Likes You")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.pink, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .pink.opacity(0.15), radius: 15, y: 8)
    }

    private func blurredAvatarColors(for index: Int) -> [Color] {
        let colorSets: [[Color]] = [
            [.pink, .purple],
            [.blue, .cyan],
            [.orange, .yellow],
            [.green, .mint],
            [.purple, .indigo]
        ]
        return colorSets[index % colorSets.count]
    }

    // MARK: - Premium Badge Section

    private var premiumBadgeSection: some View {
        HStack(spacing: 16) {
            // Badge preview
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.2), .pink.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)

                // Premium badge icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .shadow(color: .purple.opacity(0.4), radius: 8, y: 4)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Get the Premium Badge")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.primary)

                Text("Stand out with a verified premium badge on your profile. Members with badges get 2.5x more matches!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)

                // Social proof
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                        .foregroundColor(.purple)
                    Text("1,247 members upgraded today")
                        .font(.caption2)
                        .foregroundColor(.purple)
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.08), Color.pink.opacity(0.05)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.purple.opacity(0.3), .pink.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .purple.opacity(0.1), radius: 10, y: 5)
    }

    // MARK: - Live Feature Showcase

    private var liveFeatureShowcase: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("What You're Missing")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.primary)

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
            ("Unlimited likes available", "heart.fill", Color.red, "Like as many profiles as you want"),
            ("Send unlimited messages", "message.circle.fill", Color.blue, "Connect with anyone you like")
        ]

        let current = showcases[currentShowcaseIndex]

        return HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(current.2.opacity(0.12))
                    .frame(width: 56, height: 56)

                Image(systemName: current.1)
                    .font(.title2)
                    .foregroundColor(current.2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(current.0)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                Text(current.3)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.gray)
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(current.2.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: current.2.opacity(0.12), radius: 12, y: 6)
    }

    // MARK: - Impact Stats

    private var impactStats: some View {
        HStack(spacing: 0) {
            impactStat(value: "3x", label: "More Matches", icon: "heart.fill", color: .pink)

            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 1, height: 45)

            impactStat(value: "10x", label: "More Views", icon: "eye.fill", color: .purple)

            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 1, height: 45)

            impactStat(value: "85%", label: "Success Rate", icon: "checkmark.seal.fill", color: .green)
        }
        .padding(.vertical, 20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }

    private func impactStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)

                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
            }

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Feature Comparison

    private var featureComparisonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Premium vs Free")
                .font(.title3.weight(.bold))
                .foregroundColor(.primary)

            VStack(spacing: 0) {
                // Header row
                HStack(spacing: 8) {
                    Text("Feature")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Free")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 60)
                    Text("Premium")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.purple)
                        .frame(width: 70)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.06))

                VStack(spacing: 0) {
                    comparisonRow(feature: "Send Messages", free: "10/day", premium: "Unlimited", icon: "message.fill")
                    comparisonRow(feature: "Daily Likes", free: "10/day", premium: "Unlimited", icon: "heart.fill")
                    comparisonRow(feature: "See Who Likes You", free: "Hidden", premium: "Full Access", icon: "eye.fill")
                    comparisonRow(feature: "Advanced Filters", free: "Basic", premium: "All Filters", icon: "slider.horizontal.3")
                    comparisonRow(feature: "Read Receipts", free: "No", premium: "Yes", icon: "checkmark.message.fill")
                    comparisonRow(feature: "Priority in Feed", free: "Standard", premium: "Top Priority", icon: "arrow.up.circle.fill")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
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
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(free)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)

            Text(premium)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.green)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Pricing Section

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose Your Plan")
                .font(.title3.weight(.bold))
                .foregroundColor(.primary)

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
                    .font(.title3.weight(.bold))
                    .foregroundColor(.primary)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("4.8")
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
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
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .overlay(
                    Text(initials)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    HStack(spacing: 2) {
                        ForEach(0..<5) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.yellow)
                        }
                    }
                }

                Text("\"\(story)\"")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .italic()
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Guarantee Section

    private var guaranteeSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 50, height: 50)
                Image(systemName: "checkmark.shield.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("7-Day Free Trial")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                Text("Try Premium risk-free. Cancel anytime before your trial ends and pay nothing.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.08), Color.mint.opacity(0.04)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .green.opacity(0.08), radius: 8, y: 4)
    }

    // MARK: - FAQ Section

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Common Questions")
                .font(.title3.weight(.bold))
                .foregroundColor(.primary)

            VStack(spacing: 10) {
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
        VStack(spacing: 8) {
            // Main button
            Button {
                purchasePremium()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "crown.fill")
                        .font(.body)
                        .foregroundColor(.yellow)

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
                .shadow(color: .purple.opacity(0.3), radius: 12, y: 6)
            }
            .disabled(isProcessing)

            // Trust indicators
            HStack(spacing: 16) {
                Label("Secure", systemImage: "lock.fill")
                Label("Cancel Anytime", systemImage: "arrow.clockwise")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.95), Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
        .background(
            Rectangle()
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 10, y: -5)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Processing Overlay

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Animated loading
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                        .frame(width: 56, height: 56)

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
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(isProcessing ? 360 : 0))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isProcessing)
                }

                VStack(spacing: 8) {
                    Text("Processing...")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Please wait while we set up your premium access")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(36)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
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

                if storeManager.hasActiveSubscription {
                    // CRITICAL: Update user's isPremium flag in Firestore after successful restore
                    if var user = authService.currentUser {
                        user.isPremium = true
                        // Get tier from SubscriptionManager
                        let tier = await SubscriptionManager.shared.currentTier
                        user.premiumTier = tier.rawValue
                        user.subscriptionExpiryDate = await SubscriptionManager.shared.expirationDate
                        try await authService.updateUser(user)
                        Logger.shared.info("✅ User premium status updated after restore", category: .general)
                    }

                    await MainActor.run {
                        isProcessing = false
                        showPurchaseSuccess = true
                        HapticManager.shared.notification(.success)
                    }
                } else {
                    await MainActor.run {
                        isProcessing = false
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
                        .stroke(isSelected ? Color.purple : Color.gray.opacity(0.3), lineWidth: 2)
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
                            .frame(width: 14, height: 14)
                    }
                }

                // Plan details
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(plan.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .layoutPriority(1)

                        if plan == .annual {
                            Text("BEST")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    LinearGradient(
                                        colors: [.green, .mint],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(4)
                        }

                        if plan == .sixMonth {
                            Text("HOT")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(4)
                        }
                    }

                    Text(plan.totalPrice)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Price
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(plan.price)
                            .font(.title3.weight(.bold))
                            .foregroundColor(.primary)

                        Text("/\(plan.period)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if plan.savings > 0 {
                        Text("Save \(plan.savings)%")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ?
                        LinearGradient(
                            colors: [Color.purple.opacity(0.08), Color.pink.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.white, Color.white],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ?
                        LinearGradient(
                            colors: [Color.purple, Color.pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.15)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(color: isSelected ? .purple.opacity(0.15) : .black.opacity(0.04), radius: isSelected ? 12 : 6, y: isSelected ? 6 : 3)
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
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.gray)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(16)
            }

            if isExpanded {
                Text(answer)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
    }
}

#Preview {
    NavigationStack {
        PremiumUpgradeView()
            .environmentObject(AuthService.shared)
    }
}
