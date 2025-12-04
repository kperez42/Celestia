//
//  ConversationStartersView.swift
//  Celestia
//
//  Beautiful UI for conversation starter suggestions
//

import SwiftUI

struct ConversationStartersView: View {
    let currentUser: User
    let otherUser: User
    let onStarterSelected: (String) -> Void

    @State private var starters: [ConversationStarter] = []
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Break the ice")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()
            }
            .padding(.horizontal, 20)

            // Starter cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(starters.enumerated()), id: \.element.id) { index, starter in
                        StarterCard(starter: starter, index: index, appeared: appeared) {
                            HapticManager.shared.impact(.medium)
                            onStarterSelected(starter.text)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 16)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            loadStarters()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                appeared = true
            }
        }
    }

    private func loadStarters() {
        starters = ConversationStarters.shared.generateStarters(
            currentUser: currentUser,
            otherUser: otherUser
        )
    }
}

// MARK: - Starter Card

struct StarterCard: View {
    let starter: ConversationStarter
    let index: Int
    let appeared: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(gradientForCategory)
                        .frame(width: 44, height: 44)

                    Image(systemName: starter.icon)
                        .font(.title3)
                        .foregroundColor(.white)
                }

                // Text
                Text(starter.text)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                // Send indicator
                HStack {
                    Spacer()
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(gradientForCategory)
                }
            }
            .padding(16)
            .frame(width: 240, height: 180)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [gradientColor.opacity(0.3), gradientColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
        }
        .scaleButton()
        .offset(y: appeared ? 0 : 50)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.1), value: appeared)
    }

    private var gradientForCategory: LinearGradient {
        LinearGradient(
            colors: [gradientColor, gradientColor.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var gradientColor: Color {
        switch starter.category {
        case .sharedInterest:
            return .purple
        case .location:
            return .blue
        case .bio:
            return .pink
        case .generic:
            return .green
        }
    }
}

// MARK: - Compact Version (for Chat View)

struct CompactConversationStartersView: View {
    let currentUser: User
    let otherUser: User
    let onStarterSelected: (String) -> Void

    @State private var starters: [ConversationStarter] = []
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.callout)
                    .foregroundColor(.yellow)

                Text("Try these conversation starters:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }

            // Compact starter buttons
            VStack(spacing: 8) {
                ForEach(Array(starters.prefix(3).enumerated()), id: \.element.id) { index, starter in
                    CompactStarterButton(starter: starter, index: index, appeared: appeared) {
                        HapticManager.shared.impact(.light)
                        onStarterSelected(starter.text)
                    }
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.05), Color.pink.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .onAppear {
            loadStarters()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                appeared = true
            }
        }
    }

    private func loadStarters() {
        starters = ConversationStarters.shared.generateStarters(
            currentUser: currentUser,
            otherUser: otherUser
        )
    }
}

struct CompactStarterButton: View {
    let starter: ConversationStarter
    let index: Int
    let appeared: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: starter.icon)
                    .font(.body)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)

                Text(starter.text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                Spacer()

                Image(systemName: "arrow.up.circle.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
        .scaleButton()
        .offset(x: appeared ? 0 : -50)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.08), value: appeared)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack {
        ConversationStartersView(
            currentUser: TestData.currentUser,
            otherUser: TestData.discoverUsers[0]
        ) { message in
            Logger.shared.debug("Selected: \(message)", category: .ui)
        }

        Spacer()

        CompactConversationStartersView(
            currentUser: TestData.currentUser,
            otherUser: TestData.discoverUsers[0]
        ) { message in
            Logger.shared.debug("Selected: \(message)", category: .ui)
        }
        .padding()
    }
}
#endif
