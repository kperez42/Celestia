//
//  EnhancedEmptyState.swift
//  Celestia
//
//  Beautiful, engaging empty states with contextual guidance
//

import SwiftUI

struct EnhancedEmptyState: View {
    let config: EmptyStateConfig
    let primaryAction: (() -> Void)?
    let secondaryAction: (() -> Void)?

    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                Spacer()
                    .frame(height: 40)

                // Illustration
                illustrationView

                // Content
                VStack(spacing: 16) {
                    // Title
                    Text(config.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    // Description
                    Text(config.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                // Steps or tips (if provided)
                if !config.steps.isEmpty {
                    stepsView
                }

                // Actions
                VStack(spacing: 12) {
                    if let primaryAction = primaryAction {
                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            primaryAction()
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: config.primaryButtonIcon)
                                Text(config.primaryButtonTitle)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: 280)
                            .padding(.vertical, 14)
                            .foregroundColor(.white)
                            .background(
                                LinearGradient(
                                    colors: [Color.purple, Color.pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(25)
                            .shadow(color: .purple.opacity(0.4), radius: 15, y: 8)
                        }
                    }

                    if let secondaryAction = secondaryAction, let secondaryTitle = config.secondaryButtonTitle {
                        Button(action: {
                            HapticManager.shared.impact(.light)
                            secondaryAction()
                        }) {
                            Text(secondaryTitle)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.purple)
                                .padding(.vertical, 12)
                        }
                    }
                }
                .padding(.top, 8)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Illustration

    private var illustrationView: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            config.accentColor.opacity(0.15),
                            config.accentColor.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 160, height: 160)

            // Icon
            Image(systemName: config.iconName)
                .font(.system(size: 70, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            config.accentColor.opacity(0.8),
                            config.accentColor.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .scaleEffect(appeared ? 1 : 0.8)
        .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: appeared)
    }

    // MARK: - Steps View

    private var stepsView: some View {
        VStack(spacing: 12) {
            ForEach(Array(config.steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 12) {
                    // Number badge
                    ZStack {
                        Circle()
                            .fill(config.accentColor.opacity(0.15))
                            .frame(width: 32, height: 32)

                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(config.accentColor)
                    }

                    // Step text
                    Text(step)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
            }
        }
        .padding(.horizontal, 30)
    }
}

// MARK: - Configuration

struct EmptyStateConfig {
    let iconName: String
    let title: String
    let description: String
    let steps: [String]
    let primaryButtonIcon: String
    let primaryButtonTitle: String
    let secondaryButtonTitle: String?
    let accentColor: Color

    init(
        iconName: String,
        title: String,
        description: String,
        steps: [String] = [],
        primaryButtonIcon: String,
        primaryButtonTitle: String,
        secondaryButtonTitle: String? = nil,
        accentColor: Color = .purple
    ) {
        self.iconName = iconName
        self.title = title
        self.description = description
        self.steps = steps
        self.primaryButtonIcon = primaryButtonIcon
        self.primaryButtonTitle = primaryButtonTitle
        self.secondaryButtonTitle = secondaryButtonTitle
        self.accentColor = accentColor
    }
}

// MARK: - Preset Configurations

extension EmptyStateConfig {
    // Discover - No users (out of people)
    static let noUsersDiscover = EmptyStateConfig(
        iconName: "person.2.slash",
        title: "You're All Caught Up!",
        description: "You've seen everyone nearby. Check back later for new profiles, or adjust your filters.",
        steps: [
            "Expand your distance range",
            "Adjust your age preferences",
            "Check back tomorrow for new users"
        ],
        primaryButtonIcon: "arrow.clockwise",
        primaryButtonTitle: "Refresh",
        secondaryButtonTitle: "Adjust Filters",
        accentColor: .purple
    )

    // Discover - Filters too restrictive
    static let noMatchingFilters = EmptyStateConfig(
        iconName: "line.3.horizontal.decrease.circle",
        title: "No Matches Found",
        description: "Your current filters are too restrictive. Try adjusting them to see more people.",
        steps: [
            "Increase your distance radius",
            "Widen your age range",
            "Remove interest filters"
        ],
        primaryButtonIcon: "arrow.counterclockwise",
        primaryButtonTitle: "Clear All Filters",
        secondaryButtonTitle: "Adjust Filters",
        accentColor: .orange
    )

    // Matches - No matches yet
    static let noMatches = EmptyStateConfig(
        iconName: "heart.circle",
        title: "No Matches Yet",
        description: "Start swiping to find people you connect with. The more you swipe, the better your matches!",
        steps: [
            "Add more photos to your profile",
            "Write a compelling bio",
            "Be active and swipe daily",
            "Like profiles you genuinely connect with"
        ],
        primaryButtonIcon: "heart.fill",
        primaryButtonTitle: "Start Swiping",
        accentColor: .pink
    )

    // Messages - No conversations
    static let noMessages = EmptyStateConfig(
        iconName: "message.circle",
        title: "No Conversations Yet",
        description: "When you match with someone, you'll be able to start chatting here. Don't be shy - make the first move!",
        steps: [
            "Match with people you like",
            "Send an engaging first message",
            "Ask about their interests",
            "Be authentic and friendly"
        ],
        primaryButtonIcon: "heart.fill",
        primaryButtonTitle: "Find Matches",
        secondaryButtonTitle: "Improve Profile",
        accentColor: .blue
    )

    // Matches - Filtered view empty
    static let noUnreadMatches = EmptyStateConfig(
        iconName: "tray",
        title: "All Caught Up!",
        description: "You've read all your messages. Great job staying on top of conversations!",
        primaryButtonIcon: "arrow.clockwise",
        primaryButtonTitle: "Refresh",
        secondaryButtonTitle: "View All Matches",
        accentColor: .green
    )
}

// MARK: - Preview

#Preview("No Users") {
    EnhancedEmptyState(
        config: .noUsersDiscover,
        primaryAction: { print("Refresh") },
        secondaryAction: { print("Filters") }
    )
}

#Preview("No Matches") {
    EnhancedEmptyState(
        config: .noMatches,
        primaryAction: { print("Start Swiping") },
        secondaryAction: nil
    )
}

#Preview("No Messages") {
    EnhancedEmptyState(
        config: .noMessages,
        primaryAction: { print("Find Matches") },
        secondaryAction: { print("Improve Profile") }
    )
}
