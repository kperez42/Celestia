//
//  ProfileStrengthCard.swift
//  Celestia
//
//  Beautiful profile strength visualization with actionable tips
//

import SwiftUI

struct ProfileStrengthCard: View {
    let user: User
    let onTipTapped: (ProfileTip.TipAction) -> Void

    @State private var analysis: ProfileTips.ProfileAnalysis?
    @State private var appeared = false
    @State private var showAllTips = false

    var body: some View {
        VStack(spacing: 0) {
            if let analysis = analysis {
                // Header with circular progress
                headerSection(analysis: analysis)

                Divider()
                    .padding(.vertical, 16)

                // Tips section
                tipsSection(tips: analysis.tips)

                // Strengths (if any)
                if !analysis.strengths.isEmpty {
                    Divider()
                        .padding(.vertical, 16)

                    strengthsSection(strengths: analysis.strengths)
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.05),
                    Color.pink.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.2), Color.pink.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .onAppear {
            loadAnalysis()
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: - Header Section

    private func headerSection(analysis: ProfileTips.ProfileAnalysis) -> some View {
        HStack(spacing: 20) {
            // Circular progress
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 100, height: 100)

                // Progress circle
                Circle()
                    .trim(from: 0, to: appeared ? CGFloat(analysis.completionPercentage) / 100 : 0)
                    .stroke(
                        LinearGradient(
                            colors: gradientColors(for: analysis.completionPercentage),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.2, dampingFraction: 0.7), value: appeared)

                // Percentage text
                VStack(spacing: 2) {
                    Text("\(analysis.completionPercentage)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: gradientColors(for: analysis.completionPercentage),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Rating info
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(analysis.overallRating.emoji)
                        .font(.title2)

                    Text(analysis.overallRating.title)
                        .font(.title3)
                        .fontWeight(.bold)
                }

                Text(analysis.overallRating.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }

    // MARK: - Tips Section

    private func tipsSection(tips: [ProfileTip]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Complete Your Profile", systemImage: "checklist")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                if tips.count > 3 {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showAllTips.toggle()
                        }
                    } label: {
                        Text(showAllTips ? "Show Less" : "Show All")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                    }
                }
            }

            let displayedTips = showAllTips ? tips : Array(tips.prefix(3))

            ForEach(Array(displayedTips.enumerated()), id: \.element.id) { index, tip in
                TipRow(tip: tip, index: index, appeared: appeared) {
                    HapticManager.shared.impact(.medium)
                    onTipTapped(tip.action)
                }
            }
        }
    }

    // MARK: - Strengths Section

    private func strengthsSection(strengths: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Your Strengths")
                    .font(.headline)
            }

            FlowLayout(spacing: 8) {
                ForEach(strengths, id: \.self) { strength in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text(strength)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(16)
                }
            }
        }
    }

    // MARK: - Helpers

    private func gradientColors(for percentage: Int) -> [Color] {
        switch percentage {
        case 90...100:
            return [.green, .mint]
        case 75..<90:
            return [.blue, .cyan]
        case 60..<75:
            return [.purple, .pink]
        default:
            return [.orange, .yellow]
        }
    }

    private func loadAnalysis() {
        analysis = ProfileTips.shared.analyzeProfile(user)
    }
}

// MARK: - Tip Row

struct TipRow: View {
    let tip: ProfileTip
    let index: Int
    let appeared: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(priorityColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: tip.icon)
                        .font(.body)
                        .foregroundColor(priorityColor)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(tip.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(tip.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    // Impact badge
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                        Text(tip.impact)
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(priorityColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priorityColor.opacity(0.1))
                    .cornerRadius(8)
                }

                Spacer()

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
        .offset(x: appeared ? 0 : -50)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.08), value: appeared)
    }

    private var priorityColor: Color {
        switch tip.priority {
        case .high:
            return .purple
        case .medium:
            return .blue
        case .low:
            return .gray
        }
    }
}

// MARK: - Flow Layout (for strengths tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )

        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + result.positions[index].x,
                    y: bounds.minY + result.positions[index].y
                ),
                proposal: .unspecified
            )
        }
    }

    struct FlowResult {
        var size: CGSize
        var positions: [CGPoint]

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var positions: [CGPoint] = []
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }

            self.positions = positions
            self.size = CGSize(
                width: maxWidth,
                height: currentY + lineHeight
            )
        }
    }
}

// MARK: - Compact Version (for empty states)

struct CompactProfileStrengthCard: View {
    let user: User
    let onImproveTapped: () -> Void

    @State private var completion: Int = 0

    var body: some View {
        Button(action: onImproveTapped) {
            HStack(spacing: 16) {
                // Circular progress (smaller)
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: CGFloat(completion) / 100)
                        .stroke(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))

                    Text("\(completion)%")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.purple)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Profile Strength")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(completion < 100 ? "Complete your profile to get more matches" : "Your profile looks great!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
        .onAppear {
            let analysis = ProfileTips.shared.analyzeProfile(user)
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.2)) {
                completion = analysis.completionPercentage
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            ProfileStrengthCard(user: TestData.currentUser) { action in
                print("Tapped: \(action)")
            }
            .padding()

            CompactProfileStrengthCard(user: TestData.currentUser) {
                print("Improve tapped")
            }
            .padding()
        }
    }
}
