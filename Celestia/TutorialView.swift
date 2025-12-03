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

    let tutorials: [Tutorial]
    let completion: () -> Void

    init(tutorials: [Tutorial], completion: @escaping () -> Void = {}) {
        self.tutorials = tutorials
        self.completion = completion
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.purple.opacity(0.1), Color.pink.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()

                    Button {
                        completeTutorial()
                    } label: {
                        Text("Skip")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.purple)
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

                // Navigation buttons
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button {
                            withAnimation {
                                currentPage -= 1
                            }
                        } label: {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.purple, lineWidth: 2)
                            )
                        }
                    }

                    Button {
                        if currentPage < tutorials.count - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            completeTutorial()
                        }
                    } label: {
                        HStack {
                            Text(currentPage < tutorials.count - 1 ? "Next" : "Get Started")
                                .fontWeight(.semibold)

                            Image(systemName: currentPage < tutorials.count - 1 ? "chevron.right" : "checkmark")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: .purple.opacity(0.3), radius: 10, y: 5)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
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

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon/Animation
            ZStack {
                Circle()
                    .fill(tutorial.accentColor.opacity(0.1))
                    .frame(width: 200, height: 200)

                if let animation = tutorial.animation {
                    animation
                        .font(.system(size: 100))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [tutorial.accentColor, tutorial.accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                } else {
                    Image(systemName: tutorial.icon)
                        .font(.system(size: 100))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [tutorial.accentColor, tutorial.accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }

            VStack(spacing: 16) {
                Text(tutorial.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(tutorial.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Interactive demo
                if let interactiveDemo = tutorial.interactiveDemo {
                    interactiveDemo
                        .padding(.top, 20)
                }

                // Tips
                if !tutorial.tips.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(tutorial.tips, id: \.self) { tip in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)

                                Text(tip)
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(12)
                    .padding(.horizontal, 32)
                }
            }

            Spacer()
        }
        .padding()
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
        ("Sarah", "person.fill"),
        ("Mike", "person.fill"),
        ("Emma", "person.fill")
    ]

    var body: some View {
        VStack(spacing: 12) {
            Text("Try it! Scroll through profiles")
                .font(.caption)
                .foregroundColor(.secondary)

            // Scrollable profile cards
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(demoProfiles.enumerated()), id: \.offset) { index, profile in
                        HStack(spacing: 12) {
                            // Profile image
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 50, height: 50)

                                Image(systemName: profile.1)
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            }

                            // Profile info
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.0)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                Text("Demo Profile")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // Like button
                            Button {
                                HapticManager.shared.impact(.light)
                                withAnimation(.spring(response: 0.3)) {
                                    isLiked[index].toggle()
                                }
                            } label: {
                                Image(systemName: isLiked[index] ? "heart.fill" : "heart")
                                    .font(.title3)
                                    .foregroundColor(isLiked[index] ? .pink : .gray)
                                    .scaleEffect(isLiked[index] ? 1.2 : 1.0)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.05), radius: 4)
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Scroll indicator
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption2)
                Text("Scroll to see more")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: 280)
    }
}

struct SwipeGestureDemo: View {
    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 12) {
            Text("Try it! Swipe left or right")
                .font(.caption)
                .foregroundColor(.secondary)

            ZStack {
                // Card
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .frame(width: 200, height: 280)
                    .overlay(
                        VStack {
                            Image(systemName: "person.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)

                            Text("Demo Profile")
                                .font(.headline)

                            Text("Swipe me!")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
                    .shadow(color: .black.opacity(0.1), radius: 10)

                // Like/Nope indicators
                if offset.width > 20 {
                    Text("LIKE")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .opacity(Double(offset.width / 100))
                } else if offset.width < -20 {
                    Text("NOPE")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .opacity(Double(abs(offset.width) / 100))
                }
            }
            .frame(height: 300)
        }
    }
}

struct MessageDemo: View {
    @State private var message = ""

    var body: some View {
        VStack(spacing: 12) {
            Text("Send your first message")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                // Sample message bubble
                HStack {
                    Spacer()
                    Text("Hey! Nice to match with you 👋")
                        .padding(12)
                        .background(Color.purple.opacity(0.2))
                        .cornerRadius(16)
                }

                // Input field
                HStack {
                    TextField("Type a message...", text: $message)
                        .padding(12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(20)

                    Button {
                        // Demo action
                        HapticManager.shared.impact(.light)
                        message = ""
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(message.isEmpty ? .gray : .purple)
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 5)
        }
        .frame(maxWidth: 300)
    }
}

#Preview {
    TutorialView(tutorials: TutorialManager.getOnboardingTutorials())
}
