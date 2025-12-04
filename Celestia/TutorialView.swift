//
//  TutorialView.swift
//  Celestia
//
//  Interactive tutorials for core features
//  Guides new users through swiping, matching, and messaging
//

import SwiftUI

/// Tutorial system with interactive guides
struct TutorialView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentPage = 0
    @State private var showingTutorial = false
    @State private var animateBackground = false

    let tutorials: [Tutorial]
    let completion: () -> Void

    init(tutorials: [Tutorial], completion: @escaping () -> Void = {}) {
        self.tutorials = tutorials
        self.completion = completion
    }

    var body: some View {
        ZStack {
            // Premium background with animated gradient
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.15),
                    Color.pink.opacity(0.08),
                    Color.blue.opacity(0.05)
                ],
                startPoint: animateBackground ? .topLeading : .topTrailing,
                endPoint: animateBackground ? .bottomTrailing : .bottomLeading
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: animateBackground)

            // Decorative floating orbs
            GeometryReader { geometry in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.purple.opacity(0.15), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .offset(x: -50, y: -100)
                    .blur(radius: 2)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.pink.opacity(0.12), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                    .offset(x: geometry.size.width - 100, y: geometry.size.height - 200)
                    .blur(radius: 2)
            }

            VStack(spacing: 0) {
                // Premium skip button
                HStack {
                    Spacer()

                    Button {
                        completeTutorial()
                    } label: {
                        HStack(spacing: 6) {
                            Text("Skip")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Image(systemName: "arrow.right")
                                .font(.caption)
                        }
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.8))
                                .shadow(color: .purple.opacity(0.15), radius: 8, y: 4)
                        )
                    }
                    .padding()
                }

                TabView(selection: $currentPage) {
                    ForEach(Array(tutorials.enumerated()), id: \.element.id) { index, tutorial in
                        TutorialPageView(tutorial: tutorial, pageIndex: index, totalPages: tutorials.count)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                // Premium navigation buttons
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                currentPage -= 1
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Back")
                            }
                            .fontWeight(.semibold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.white)
                                    .shadow(color: .purple.opacity(0.1), radius: 8, y: 4)
                                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [.purple.opacity(0.5), .pink.opacity(0.5)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                        }
                    }

                    Button {
                        if currentPage < tutorials.count - 1 {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                currentPage += 1
                            }
                        } else {
                            completeTutorial()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(currentPage < tutorials.count - 1 ? "Next" : "Get Started")
                                .fontWeight(.bold)

                            Image(systemName: currentPage < tutorials.count - 1 ? "chevron.right" : "checkmark")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [.purple, .pink, .purple.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(18)
                        .shadow(color: .purple.opacity(0.4), radius: 12, y: 6)
                        .shadow(color: .pink.opacity(0.3), radius: 6, y: 3)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            animateBackground = true
        }
    }

    private func completeTutorial() {
        TutorialManager.shared.markTutorialCompleted(tutorials.first?.id ?? "")
        completion()
        dismiss()
    }
}

// MARK: - Tutorial Page View

struct TutorialPageView: View {
    let tutorial: Tutorial
    let pageIndex: Int
    let totalPages: Int
    @State private var animateIcon = false
    @State private var animateTips = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Premium Icon with radial glow
            ZStack {
                // Outer radial glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                tutorial.accentColor.opacity(0.25),
                                tutorial.accentColor.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: 140
                        )
                    )
                    .frame(width: 280, height: 280)
                    .scaleEffect(animateIcon ? 1.05 : 0.95)
                    .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: animateIcon)

                // Inner glow ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                tutorial.accentColor.opacity(0.3),
                                tutorial.accentColor.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 180, height: 180)

                // Background circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                tutorial.accentColor.opacity(0.15),
                                tutorial.accentColor.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 160)
                    .shadow(color: tutorial.accentColor.opacity(0.2), radius: 20)

                if let animation = tutorial.animation {
                    animation
                        .font(.system(size: 80, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [tutorial.accentColor, tutorial.accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: tutorial.accentColor.opacity(0.3), radius: 10)
                } else {
                    Image(systemName: tutorial.icon)
                        .font(.system(size: 80, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [tutorial.accentColor, tutorial.accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: tutorial.accentColor.opacity(0.3), radius: 10)
                        .symbolEffect(.pulse, options: .repeating)
                }
            }

            VStack(spacing: 16) {
                // Premium title with gradient
                Text(tutorial.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)

                Text(tutorial.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineSpacing(4)

                // Interactive demo
                if let interactiveDemo = tutorial.interactiveDemo {
                    interactiveDemo
                        .padding(.top, 20)
                }

                // Premium Tips section
                if !tutorial.tips.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(tutorial.tips.enumerated()), id: \.element) { index, tip in
                            HStack(alignment: .top, spacing: 14) {
                                // Gradient lightbulb icon
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.yellow.opacity(0.3), .orange.opacity(0.2)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 28, height: 28)

                                    Image(systemName: "lightbulb.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.yellow, .orange],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                }
                                .scaleEffect(animateTips ? 1.0 : 0.8)
                                .opacity(animateTips ? 1.0 : 0)
                                .animation(.spring(response: 0.4).delay(Double(index) * 0.1), value: animateTips)

                                Text(tip)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineSpacing(2)

                                Spacer()
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.7))
                            .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.yellow.opacity(0.3), .orange.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .padding(.horizontal, 24)
                }
            }

            Spacer()
        }
        .padding()
        .onAppear {
            animateIcon = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                animateTips = true
            }
        }
    }
}

// MARK: - Tutorial Model

struct Tutorial: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let accentColor: Color
    let tips: [String]
    let animation: AnyView?
    let interactiveDemo: AnyView?

    init(
        id: String,
        title: String,
        description: String,
        icon: String,
        accentColor: Color = .purple,
        tips: [String] = [],
        animation: AnyView? = nil,
        interactiveDemo: AnyView? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.accentColor = accentColor
        self.tips = tips
        self.animation = animation
        self.interactiveDemo = interactiveDemo
    }
}

// MARK: - Tutorial Manager

@MainActor
class TutorialManager: ObservableObject {
    static let shared = TutorialManager()

    @Published var completedTutorials: Set<String> = []
    @Published var shouldShowOnboardingTutorial: Bool = true

    private let completedTutorialsKey = "completedTutorials"

    init() {
        loadCompletedTutorials()
    }

    func markTutorialCompleted(_ tutorialId: String) {
        completedTutorials.insert(tutorialId)
        saveCompletedTutorials()

        // Track analytics
        AnalyticsManager.shared.logEvent(.tutorialViewed, parameters: [
            "tutorial_id": tutorialId,
            "status": "completed"
        ])
    }

    func isTutorialCompleted(_ tutorialId: String) -> Bool {
        return completedTutorials.contains(tutorialId)
    }

    func resetTutorials() {
        completedTutorials.removeAll()
        saveCompletedTutorials()
    }

    private func loadCompletedTutorials() {
        if let data = UserDefaults.standard.data(forKey: completedTutorialsKey),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            completedTutorials = decoded
        }
    }

    private func saveCompletedTutorials() {
        if let encoded = try? JSONEncoder().encode(completedTutorials) {
            UserDefaults.standard.set(encoded, forKey: completedTutorialsKey)
        }
    }

    // MARK: - Predefined Tutorials

    static func getOnboardingTutorials() -> [Tutorial] {
        return [
            Tutorial(
                id: "welcome",
                title: "Welcome to Celestia! 🌟",
                description: "Your journey to meaningful connections starts here. Let's show you around!",
                icon: "star.fill",
                accentColor: .purple,
                tips: [
                    "Be authentic and genuine",
                    "Add photos that show your personality",
                    "Write a bio that sparks conversation"
                ]
            ),

            Tutorial(
                id: "scrolling",
                title: "Discover & Scroll",
                description: "Scroll through profiles one by one. Tap the heart to like or tap the profile card for more details!",
                icon: "arrow.up.arrow.down",
                accentColor: .pink,
                tips: [
                    "Scroll up and down to browse profiles",
                    "Tap the heart button to like someone",
                    "Tap the star to save profiles for later"
                ],
                interactiveDemo: AnyView(ScrollBrowseDemo())
            ),

            Tutorial(
                id: "matching",
                title: "Make Matches",
                description: "When someone you liked also likes you back, you'll both be notified and can start chatting!",
                icon: "heart.fill",
                accentColor: .red,
                tips: [
                    "Matches appear in your Matches tab",
                    "Send the first message to break the ice",
                    "Be respectful and genuine"
                ]
            ),

            Tutorial(
                id: "messaging",
                title: "Start Conversations",
                description: "Once matched, send a message to start getting to know each other better.",
                icon: "message.fill",
                accentColor: .blue,
                tips: [
                    "Ask about their interests",
                    "Reference something from their profile",
                    "Be yourself and have fun!"
                ],
                interactiveDemo: AnyView(MessageDemo())
            ),

            Tutorial(
                id: "profile_quality",
                title: "Complete Your Profile",
                description: "High-quality profiles get 5x more matches. Add photos, write a bio, and share your interests!",
                icon: "person.crop.circle.fill.badge.checkmark",
                accentColor: .green,
                tips: [
                    "Add 4-6 clear photos",
                    "Write a bio that shows your personality",
                    "Select at least 5 interests"
                ]
            ),

            Tutorial(
                id: "safety",
                title: "Stay Safe",
                description: "Your safety is our priority. Report inappropriate behavior and never share personal info too soon.",
                icon: "shield.checkered",
                accentColor: .orange,
                tips: [
                    "Meet in public places first",
                    "Tell a friend about your plans",
                    "Trust your instincts",
                    "Report and block suspicious accounts"
                ]
            )
        ]
    }

    static func getFeatureTutorial(feature: String) -> Tutorial? {
        switch feature {
        case "super_like":
            return Tutorial(
                id: "super_like",
                title: "Super Like ⭐",
                description: "Stand out from the crowd! Super Likes show you're really interested.",
                icon: "star.circle.fill",
                accentColor: .blue,
                tips: [
                    "You get 1 free Super Like per day",
                    "Premium users get 5 per day",
                    "Use them on profiles you really like!"
                ]
            )

        case "boost":
            return Tutorial(
                id: "boost",
                title: "Profile Boost 🚀",
                description: "Get 10x more profile views for 30 minutes. Perfect for busy times!",
                icon: "flame.fill",
                accentColor: .orange,
                tips: [
                    "Use during peak hours (6-9 PM)",
                    "Make sure your profile is complete",
                    "Premium users get 1 boost per month"
                ]
            )

        default:
            return nil
        }
    }
}

// MARK: - Interactive Demos

struct ScrollBrowseDemo: View {
    @State private var scrollOffset: CGFloat = 0
    @State private var isLiked: [Bool] = [false, false, false]

    private let demoProfiles = [
        ("Sarah", "person.fill", Color.pink),
        ("Mike", "person.fill", Color.blue),
        ("Emma", "person.fill", Color.purple)
    ]

    var body: some View {
        VStack(spacing: 14) {
            // Premium header
            HStack(spacing: 6) {
                Image(systemName: "hand.draw.fill")
                    .font(.caption)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("Try it! Scroll through profiles")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }

            // Premium scrollable profile cards
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(demoProfiles.enumerated()), id: \.offset) { index, profile in
                        HStack(spacing: 14) {
                            // Premium profile image with gradient ring
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [profile.2.opacity(0.2), profile.2.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 52, height: 52)

                                Circle()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [profile.2.opacity(0.6), profile.2.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                                    .frame(width: 52, height: 52)

                                Image(systemName: profile.1)
                                    .font(.title3)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [profile.2, profile.2.opacity(0.7)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }

                            // Profile info
                            VStack(alignment: .leading, spacing: 3) {
                                Text(profile.0)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                Text("Demo Profile")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // Premium like button with glow
                            Button {
                                HapticManager.shared.impact(.light)
                                withAnimation(.spring(response: 0.3)) {
                                    isLiked[index].toggle()
                                }
                            } label: {
                                ZStack {
                                    if isLiked[index] {
                                        Circle()
                                            .fill(Color.pink.opacity(0.15))
                                            .frame(width: 40, height: 40)
                                    }

                                    Image(systemName: isLiked[index] ? "heart.fill" : "heart")
                                        .font(.title3)
                                        .foregroundStyle(
                                            isLiked[index] ?
                                            LinearGradient(colors: [.pink, .red], startPoint: .top, endPoint: .bottom) :
                                            LinearGradient(colors: [.gray, .gray.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                                        )
                                        .scaleEffect(isLiked[index] ? 1.15 : 1.0)
                                        .shadow(color: isLiked[index] ? .pink.opacity(0.4) : .clear, radius: 6)
                                }
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
                                .shadow(color: .purple.opacity(0.05), radius: 4, y: 2)
                        )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
            .frame(height: 210)
            .clipShape(RoundedRectangle(cornerRadius: 18))

            // Premium scroll indicator
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Text("Scroll to see more")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.purple.opacity(0.08))
            )
        }
        .frame(maxWidth: 300)
    }
}

struct SwipeGestureDemo: View {
    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 14) {
            // Premium header
            HStack(spacing: 6) {
                Image(systemName: "hand.draw.fill")
                    .font(.caption)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("Try it! Swipe left or right")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }

            ZStack {
                // Premium Card with gradient border
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .frame(width: 200, height: 280)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.purple.opacity(0.2), .pink.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .overlay(
                        VStack(spacing: 12) {
                            // Premium avatar
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.purple.opacity(0.15), .pink.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)

                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.purple, .pink],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }

                            Text("Demo Profile")
                                .font(.headline)
                                .fontWeight(.semibold)

                            Text("Swipe me!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.purple.opacity(0.1))
                                )
                        }
                    )
                    .rotationEffect(.degrees(Double(offset.width / 20)))
                    .offset(offset)
                    .scaleEffect(scale)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                offset = value.translation
                                scale = 1.0 - abs(value.translation.width) / 1000
                            }
                            .onEnded { value in
                                withAnimation(.spring()) {
                                    if abs(value.translation.width) > 100 {
                                        offset = CGSize(
                                            width: value.translation.width > 0 ? 500 : -500,
                                            height: 0
                                        )

                                        // Reset after animation
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            withAnimation {
                                                offset = .zero
                                                scale = 1.0
                                            }
                                        }
                                    } else {
                                        offset = .zero
                                        scale = 1.0
                                    }
                                }
                            }
                    )
                    .shadow(color: .purple.opacity(0.15), radius: 15, y: 8)
                    .shadow(color: .black.opacity(0.08), radius: 5, y: 3)

                // Premium Like/Nope indicators
                if offset.width > 20 {
                    Text("LIKE")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.15))
                        )
                        .opacity(Double(offset.width / 100))
                } else if offset.width < -20 {
                    Text("NOPE")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.15))
                        )
                        .opacity(Double(abs(offset.width) / 100))
                }
            }
            .frame(height: 300)
        }
    }
}

struct MessageDemo: View {
    @State private var message = ""
    @State private var showBubble = false

    var body: some View {
        VStack(spacing: 14) {
            // Premium header
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.caption)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("Send your first message")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                // Premium sample message bubble
                HStack {
                    Spacer()
                    Text("Hey! Nice to match with you 👋")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .clipShape(
                            .rect(
                                topLeadingRadius: 20,
                                bottomLeadingRadius: 20,
                                bottomTrailingRadius: 6,
                                topTrailingRadius: 20
                            )
                        )
                        .shadow(color: .purple.opacity(0.25), radius: 8, y: 4)
                        .scaleEffect(showBubble ? 1.0 : 0.8)
                        .opacity(showBubble ? 1.0 : 0)
                        .animation(.spring(response: 0.5).delay(0.2), value: showBubble)
                }

                // Premium input field
                HStack(spacing: 12) {
                    TextField("Type a message...", text: $message)
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(Color.gray.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.purple.opacity(0.2), .pink.opacity(0.2)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1
                                )
                        )

                    // Premium send button
                    Button {
                        HapticManager.shared.impact(.light)
                        message = ""
                    } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    message.isEmpty ?
                                    LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.2)], startPoint: .top, endPoint: .bottom) :
                                    LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 40, height: 40)
                                .shadow(color: message.isEmpty ? .clear : .purple.opacity(0.3), radius: 8, y: 4)

                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .scaleEffect(message.isEmpty ? 1.0 : 1.05)
                    .animation(.spring(response: 0.3), value: message.isEmpty)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: .purple.opacity(0.1), radius: 12, y: 6)
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            )
        }
        .frame(maxWidth: 320)
        .onAppear {
            showBubble = true
        }
    }
}

#Preview {
    TutorialView(tutorials: TutorialManager.getOnboardingTutorials())
}
