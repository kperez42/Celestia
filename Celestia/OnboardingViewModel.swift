//
//  OnboardingViewModel.swift
//  Celestia
//
//  Centralized onboarding state management with progressive disclosure
//  Handles tutorial flow, profile quality, incentives, and A/B testing
//

import Foundation
import SwiftUI

@MainActor
class OnboardingViewModel: ObservableObject {

    // MARK: - Published State

    @Published var currentStep = 0
    @Published var shouldShowTutorial = false
    @Published var shouldShowProfileTips = false
    @Published var profileQualityScore = 0
    @Published var completionIncentive: CompletionIncentive?
    @Published var showMilestoneCelebration = false
    @Published var currentMilestone: ActivationMetrics.ActivationMilestone?

    // Dependencies
    private let abTestingManager = ABTestingManager.shared
    private let profileScorer = ProfileQualityScorer.shared
    private let tutorialManager = TutorialManager.shared
    private let activationMetrics = ActivationMetrics.shared

    // MEMORY FIX: Store observer token for cleanup
    private var milestoneObserver: NSObjectProtocol?

    // MARK: - Progressive Disclosure

    private var disclosureStrategy: DisclosureStrategy = .progressive

    enum DisclosureStrategy {
        case allAtOnce
        case progressive
    }

    // MARK: - Models

    struct CompletionIncentive {
        let type: IncentiveType
        let amount: Int
        let description: String
        let icon: String

        enum IncentiveType {
            case superLikes
            case boosts
            case premiumTrial

            var displayName: String {
                switch self {
                case .superLikes: return "Super Likes"
                case .boosts: return "Profile Boosts"
                case .premiumTrial: return "Premium Trial"
                }
            }
        }
    }

    // MARK: - Initialization

    init() {
        setupOnboarding()
        observeMilestones()
    }

    private func setupOnboarding() {
        // Get A/B test variant for onboarding
        shouldShowTutorial = abTestingManager.shouldShowTutorial()
        shouldShowProfileTips = abTestingManager.shouldShowTips()

        // Get disclosure strategy from A/B test
        let strategyValue = abTestingManager.getDisclosureStrategy()
        disclosureStrategy = strategyValue == "progressive" ? .progressive : .allAtOnce

        // Check for completion incentive
        let incentive = abTestingManager.shouldOfferCompletionReward()
        if incentive.offered, let type = incentive.type, let amount = incentive.amount {
            setupCompletionIncentive(type: type, amount: amount)
        }
    }

    private func setupCompletionIncentive(type: String, amount: Int) {
        switch type {
        case "super_likes":
            completionIncentive = CompletionIncentive(
                type: .superLikes,
                amount: amount,
                description: "Complete your profile to get \(amount) free Super Likes!",
                icon: "star.fill"
            )

        case "boosts":
            completionIncentive = CompletionIncentive(
                type: .boosts,
                amount: amount,
                description: "Complete your profile to get \(amount) free Profile Boosts!",
                icon: "flame.fill"
            )

        case "premium_trial":
            completionIncentive = CompletionIncentive(
                type: .premiumTrial,
                amount: amount,
                description: "Complete your profile to get \(amount) days of Premium free!",
                icon: "crown.fill"
            )

        default:
            break
        }
    }

    // MARK: - Milestone Observation

    private func observeMilestones() {
        // MEMORY FIX: Store observer token for proper cleanup
        milestoneObserver = NotificationCenter.default.addObserver(
            forName: .milestoneAchieved,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let milestone = notification.userInfo?["milestone"] as? ActivationMetrics.ActivationMilestone else {
                return
            }

            self?.celebrateMilestone(milestone)
        }
    }

    // MEMORY FIX: Clean up observer to prevent memory leak
    deinit {
        if let observer = milestoneObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func celebrateMilestone(_ milestone: ActivationMetrics.ActivationMilestone) {
        currentMilestone = milestone
        showMilestoneCelebration = true

        // Haptic feedback
        HapticManager.shared.notification(.success)

        // Track in A/B testing
        abTestingManager.trackConversion(event: "milestone_\(milestone.id)")
    }

    // MARK: - Step Management

    func shouldShowStep(_ step: OnboardingStep) -> Bool {
        switch disclosureStrategy {
        case .allAtOnce:
            return true

        case .progressive:
            // Show steps progressively based on completion
            switch step {
            case .basics:
                return true
            case .about:
                return currentStep >= 1
            case .photos:
                return currentStep >= 2
            case .preferences:
                return currentStep >= 3
            case .interests:
                return currentStep >= 4
            }
        }
    }

    enum OnboardingStep {
        case basics
        case about
        case photos
        case preferences
        case interests
    }

    // MARK: - Profile Quality

    func updateProfileQuality(for user: User) {
        profileScorer.updateScore(for: user)
        profileQualityScore = profileScorer.currentScore

        // Track profile updates
        activationMetrics.trackProfileUpdate(user: user)

        // Check if user completed profile
        if profileQualityScore >= 70 {
            onProfileCompleted()
        }
    }

    private func onProfileCompleted() {
        // Record conversion in A/B test
        abTestingManager.recordConversion(experimentId: "onboarding_flow_v1")

        // Grant completion incentive if offered
        if let incentive = completionIncentive {
            grantIncentive(incentive)
        }
    }

    private func grantIncentive(_ incentive: CompletionIncentive) {
        guard var user = AuthService.shared.currentUser else { return }

        switch incentive.type {
        case .superLikes:
            user.superLikesRemaining += incentive.amount
            Logger.shared.info("Granted \(incentive.amount) Super Likes for profile completion", category: .onboarding)

        case .boosts:
            user.boostsRemaining += incentive.amount
            Logger.shared.info("Granted \(incentive.amount) Boosts for profile completion", category: .onboarding)

        case .premiumTrial:
            user.isPremium = true
            user.premiumTier = "trial"
            user.subscriptionExpiryDate = Calendar.current.date(byAdding: .day, value: incentive.amount, to: Date())
            Logger.shared.info("Granted \(incentive.amount)-day Premium trial for profile completion", category: .onboarding)
        }

        // Update user in Firebase
        Task {
            try? await AuthService.shared.updateUser(user)
        }

        // Track analytics
        AnalyticsManager.shared.logEvent(.premiumFeatureViewed, parameters: [
            "feature": "completion_incentive",
            "incentive_type": "\(incentive.type)",
            "incentive_amount": incentive.amount
        ])
    }

    // MARK: - Tutorial Management

    func showTutorialIfNeeded() -> Bool {
        guard shouldShowTutorial else { return false }
        guard !tutorialManager.isTutorialCompleted("welcome") else { return false }

        return true
    }

    func getTutorials() -> [Tutorial] {
        return TutorialManager.getOnboardingTutorials()
    }

    // MARK: - Analytics

    func trackStepCompletion(_ step: Int) {
        AnalyticsManager.shared.logEvent(.onboardingStepCompleted, parameters: [
            "step": step,
            "total_steps": 5
        ])

        // Track in A/B testing
        abTestingManager.recordMetric(
            experimentId: "onboarding_flow_v1",
            metricName: "step_\(step)_completed",
            value: 1
        )
    }

    func trackOnboardingCompleted(timeSpent: TimeInterval) {
        AnalyticsManager.shared.logEvent(.onboardingCompleted, parameters: [
            "time_spent_seconds": timeSpent,
            "profile_quality_score": profileQualityScore
        ])

        // Record conversion
        abTestingManager.recordConversion(experimentId: "onboarding_flow_v1")
    }

    func trackOnboardingAbandoned(atStep step: Int) {
        AnalyticsManager.shared.logEvent(.onboardingSkipped, parameters: [
            "abandoned_at_step": step,
            "profile_quality_score": profileQualityScore
        ])
    }
}

// MARK: - Milestone Celebration View

struct MilestoneCelebrationView: View {
    let milestone: ActivationMetrics.ActivationMilestone
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Celebration card
            VStack(spacing: 24) {
                // Animated icon
                Text(getMilestoneEmoji(for: milestone.category))
                    .font(.system(size: 80))
                    .scaleEffect(scale)
                    .opacity(opacity)

                VStack(spacing: 8) {
                    Text(milestone.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text(milestone.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .opacity(opacity)

                // Reward points
                if milestone.rewardPoints > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)

                        Text("+\(milestone.rewardPoints) points")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(20)
                    .opacity(opacity)
                }

                Button {
                    onDismiss()
                } label: {
                    Text("Awesome!")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                }
                .opacity(opacity)
            }
            .padding(32)
            .background(Color.white)
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.2), radius: 20)
            .padding(40)
            .scaleEffect(scale)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }

    private func getMilestoneEmoji(for category: ActivationMetrics.ActivationMilestone.MilestoneCategory) -> String {
        switch category {
        case .profile:
            return "✨"
        case .discovery:
            return "👀"
        case .matching:
            return "💖"
        case .messaging:
            return "💬"
        case .engagement:
            return "🎉"
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AuthService.shared)
}
