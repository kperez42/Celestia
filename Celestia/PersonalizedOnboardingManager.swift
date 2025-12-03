//
//  PersonalizedOnboardingManager.swift
//  Celestia
//
//  Manages personalized onboarding paths based on user goals and preferences
//  Adapts the onboarding experience to match user intentions
//

import Foundation
import SwiftUI

/// Manages personalized onboarding experiences based on user goals
@MainActor
class PersonalizedOnboardingManager: ObservableObject {

    static let shared = PersonalizedOnboardingManager()

    @Published var selectedGoal: DatingGoal?
    @Published var recommendedPath: OnboardingPath?
    @Published var customizations: [String: Any] = [:]

    private let userDefaultsKey = "selected_onboarding_goal"

    // MARK: - Models

    enum DatingGoal: String, Codable, CaseIterable {
        case seriousRelationship = "serious_relationship"
        case casualDating = "casual_dating"
        case newFriends = "new_friends"
        case networking = "networking"
        case figureItOut = "figure_it_out"

        var displayName: String {
            switch self {
            case .seriousRelationship: return "Long-term relationship"
            case .casualDating: return "Casual dating"
            case .newFriends: return "New friends"
            case .networking: return "Professional networking"
            case .figureItOut: return "Open to see what happens"
            }
        }

        var icon: String {
            switch self {
            case .seriousRelationship: return "heart.fill"
            case .casualDating: return "sparkles"
            case .newFriends: return "person.2.fill"
            case .networking: return "briefcase.fill"
            case .figureItOut: return "star.fill"
            }
        }

        var description: String {
            switch self {
            case .seriousRelationship:
                return "Looking for something meaningful and long-lasting"
            case .casualDating:
                return "Enjoying the journey, keeping it light"
            case .newFriends:
                return "Expanding your social circle"
            case .networking:
                return "Building professional connections"
            case .figureItOut:
                return "Exploring options and seeing where things go"
            }
        }

        var color: Color {
            switch self {
            case .seriousRelationship: return .red
            case .casualDating: return .orange
            case .newFriends: return .blue
            case .networking: return .purple
            case .figureItOut: return .green
            }
        }
    }

    struct OnboardingPath {
        let goal: DatingGoal
        let steps: [OnboardingPathStep]
        let focusAreas: [FocusArea]
        let recommendedFeatures: [String]
        let tutorialPriority: [String] // Tutorial IDs in priority order

        enum FocusArea: String {
            case profileDepth = "profile_depth"
            case photoQuality = "photo_quality"
            case bioOptimization = "bio_optimization"
            case interestMatching = "interest_matching"
            case locationAccuracy = "location_accuracy"
            case verificationTrust = "verification_trust"
        }
    }

    struct OnboardingPathStep {
        let id: String
        let title: String
        let description: String
        let importance: StepImportance
        let tips: [String]

        enum StepImportance {
            case critical
            case recommended
            case optional
        }
    }

    // MARK: - Initialization

    init() {
        loadSavedGoal()
    }

    // MARK: - Goal Selection

    func selectGoal(_ goal: DatingGoal) {
        selectedGoal = goal
        recommendedPath = generatePath(for: goal)
        saveGoal()

        // Track analytics
        AnalyticsManager.shared.logEvent(.onboardingStepCompleted, parameters: [
            "step": "goal_selection",
            "goal": goal.rawValue,
            "goal_name": goal.displayName
        ])

        Logger.shared.info("User selected onboarding goal: \(goal.displayName)", category: .onboarding)
    }

    // MARK: - Path Generation

    private func generatePath(for goal: DatingGoal) -> OnboardingPath {
        switch goal {
        case .seriousRelationship:
            return createSeriousRelationshipPath()
        case .casualDating:
            return createCasualDatingPath()
        case .newFriends:
            return createNewFriendsPath()
        case .networking:
            return createNetworkingPath()
        case .figureItOut:
            return createOpenPath()
        }
    }

    private func createSeriousRelationshipPath() -> OnboardingPath {
        OnboardingPath(
            goal: .seriousRelationship,
            steps: [
                OnboardingPathStep(
                    id: "detailed_profile",
                    title: "Create a Detailed Profile",
                    description: "Share your values, interests, and what you're looking for",
                    importance: .critical,
                    tips: [
                        "Write a thoughtful bio about your personality and values",
                        "Add 4-6 high-quality photos showing different aspects of your life",
                        "Share your long-term goals and what matters to you"
                    ]
                ),
                OnboardingPathStep(
                    id: "verify_profile",
                    title: "Verify Your Profile",
                    description: "Build trust with verified photos",
                    importance: .critical,
                    tips: [
                        "Verified profiles get 2x more meaningful matches",
                        "Shows you're serious and authentic",
                        "Takes less than 2 minutes"
                    ]
                ),
                OnboardingPathStep(
                    id: "interests_values",
                    title: "Share Your Interests & Values",
                    description: "Help us find compatible matches",
                    importance: .recommended,
                    tips: [
                        "Select interests that truly represent you",
                        "Be specific about what you're looking for",
                        "Authenticity attracts the right people"
                    ]
                )
            ],
            focusAreas: [.profileDepth, .verificationTrust, .bioOptimization, .interestMatching],
            recommendedFeatures: ["Video Prompts", "Voice Messages", "Verified Matches"],
            tutorialPriority: ["profile_quality", "matching", "messaging", "safety", "scrolling"]
        )
    }

    private func createCasualDatingPath() -> OnboardingPath {
        OnboardingPath(
            goal: .casualDating,
            steps: [
                OnboardingPathStep(
                    id: "fun_profile",
                    title: "Create a Fun Profile",
                    description: "Show your personality and what makes you interesting",
                    importance: .critical,
                    tips: [
                        "Add photos that show you having fun",
                        "Keep your bio light and engaging",
                        "Show different sides of your personality"
                    ]
                ),
                OnboardingPathStep(
                    id: "interests",
                    title: "Share Your Interests",
                    description: "Find people with shared hobbies",
                    importance: .recommended,
                    tips: [
                        "Select activities you enjoy",
                        "Be open to new experiences",
                        "Show what makes you unique"
                    ]
                )
            ],
            focusAreas: [.photoQuality, .interestMatching, .locationAccuracy],
            recommendedFeatures: ["Quick Match", "Nearby Matches", "Icebreakers"],
            tutorialPriority: ["scrolling", "matching", "messaging", "profile_quality"]
        )
    }

    private func createNewFriendsPath() -> OnboardingPath {
        OnboardingPath(
            goal: .newFriends,
            steps: [
                OnboardingPathStep(
                    id: "friendly_profile",
                    title: "Create a Friendly Profile",
                    description: "Show what kind of friend you'd be",
                    importance: .critical,
                    tips: [
                        "Highlight your hobbies and interests",
                        "Share what activities you enjoy",
                        "Be genuine and approachable"
                    ]
                ),
                OnboardingPathStep(
                    id: "location_interests",
                    title: "Share Location & Interests",
                    description: "Find friends with shared activities nearby",
                    importance: .critical,
                    tips: [
                        "Add your city for local connections",
                        "Select group activities you enjoy",
                        "Be specific about your interests"
                    ]
                )
            ],
            focusAreas: [.interestMatching, .locationAccuracy, .bioOptimization],
            recommendedFeatures: ["Group Activities", "Interest Groups", "Events"],
            tutorialPriority: ["scrolling", "matching", "messaging", "profile_quality"]
        )
    }

    private func createNetworkingPath() -> OnboardingPath {
        OnboardingPath(
            goal: .networking,
            steps: [
                OnboardingPathStep(
                    id: "professional_profile",
                    title: "Create a Professional Profile",
                    description: "Highlight your professional interests and goals",
                    importance: .critical,
                    tips: [
                        "Share your professional background",
                        "Mention industries or fields of interest",
                        "Keep photos professional yet approachable"
                    ]
                ),
                OnboardingPathStep(
                    id: "verify_credentials",
                    title: "Verify Your Profile",
                    description: "Build professional credibility",
                    importance: .recommended,
                    tips: [
                        "Verification builds trust in professional contexts",
                        "Shows you're a serious networker",
                        "Increases connection rate"
                    ]
                )
            ],
            focusAreas: [.profileDepth, .verificationTrust, .locationAccuracy],
            recommendedFeatures: ["Professional Mode", "Industry Tags", "LinkedIn Integration"],
            tutorialPriority: ["profile_quality", "matching", "messaging"]
        )
    }

    private func createOpenPath() -> OnboardingPath {
        OnboardingPath(
            goal: .figureItOut,
            steps: [
                OnboardingPathStep(
                    id: "basic_profile",
                    title: "Create Your Profile",
                    description: "Start with the basics and explore from there",
                    importance: .critical,
                    tips: [
                        "Add a few good photos",
                        "Write a brief bio about yourself",
                        "Select some interests you enjoy"
                    ]
                ),
                OnboardingPathStep(
                    id: "explore",
                    title: "Start Exploring",
                    description: "See who's out there and what feels right",
                    importance: .recommended,
                    tips: [
                        "Try swiping to see different people",
                        "You can always update your preferences",
                        "Take your time finding what you're looking for"
                    ]
                )
            ],
            focusAreas: [.photoQuality, .bioOptimization, .interestMatching],
            recommendedFeatures: ["Discovery", "Filters", "Profile Insights"],
            tutorialPriority: ["welcome", "scrolling", "matching", "messaging", "profile_quality"]
        )
    }

    // MARK: - Customizations

    func getCustomTips() -> [String] {
        guard let path = recommendedPath else { return [] }
        return path.steps.flatMap { $0.tips }
    }

    func shouldEmphasize(focusArea: OnboardingPath.FocusArea) -> Bool {
        guard let path = recommendedPath else { return false }
        return path.focusAreas.contains(focusArea)
    }

    func getPrioritizedTutorials() -> [String] {
        guard let path = recommendedPath else {
            return ["welcome", "scrolling", "matching", "messaging"]
        }
        return path.tutorialPriority
    }

    func getRecommendedFeatures() -> [String] {
        return recommendedPath?.recommendedFeatures ?? []
    }

    // MARK: - Persistence

    private func saveGoal() {
        if let goal = selectedGoal,
           let encoded = try? JSONEncoder().encode(goal) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func loadSavedGoal() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let goal = try? JSONDecoder().decode(DatingGoal.self, from: data) {
            selectedGoal = goal
            recommendedPath = generatePath(for: goal)
        }
    }
}

// MARK: - SwiftUI View for Goal Selection

struct OnboardingGoalSelectionView: View {
    @ObservedObject var manager = PersonalizedOnboardingManager.shared
    @Environment(\.dismiss) var dismiss

    let onGoalSelected: (PersonalizedOnboardingManager.DatingGoal) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Text("What brings you here?")
                    .font(.title)
                    .fontWeight(.bold)

                Text("This helps us personalize your experience")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            .padding(.horizontal, 24)

            // Goal Options
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ForEach(PersonalizedOnboardingManager.DatingGoal.allCases, id: \.self) { goal in
                        GoalCard(goal: goal, isSelected: manager.selectedGoal == goal) {
                            withAnimation(.spring(response: 0.3)) {
                                manager.selectGoal(goal)
                                HapticManager.shared.selection()
                            }
                        }
                    }
                }
                .padding(24)
            }

            // Continue Button
            if manager.selectedGoal != nil {
                Button {
                    if let goal = manager.selectedGoal {
                        onGoalSelected(goal)
                    }
                    dismiss()
                } label: {
                    HStack {
                        Text("Continue")
                            .fontWeight(.semibold)

                        Image(systemName: "arrow.right")
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
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .transition(.opacity)
            }
        }
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.05), Color.pink.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}

struct GoalCard: View {
    let goal: PersonalizedOnboardingManager.DatingGoal
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(goal.color.opacity(0.15))
                            .frame(width: 50, height: 50)

                        Image(systemName: goal.icon)
                            .font(.title2)
                            .foregroundColor(goal.color)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(goal.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? goal.color : Color.gray.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(color: isSelected ? goal.color.opacity(0.2) : .clear, radius: 8, y: 4)
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    OnboardingGoalSelectionView { goal in
        print("Selected goal: \(goal.displayName)")
    }
}
