//
//  ProfileQualityScorer.swift
//  Celestia
//
//  Real-time profile quality scoring with actionable tips
//  Helps users create high-quality profiles that get more matches
//

import Foundation
import SwiftUI

/// Profile quality scoring system with real-time feedback
@MainActor
class ProfileQualityScorer: ObservableObject {

    static let shared = ProfileQualityScorer()

    @Published var currentScore: Int = 0
    @Published var maxScore: Int = 100
    @Published var qualityTips: [ProfileQualityTip] = []
    @Published var completedSteps: Set<String> = []

    // MARK: - Quality Metrics

    struct ProfileMetrics {
        var hasName: Bool = false
        var hasAge: Bool = false
        var hasBio: Bool = false
        var bioLength: Int = 0
        var hasLocation: Bool = false
        var photoCount: Int = 0
        var hasInterests: Bool = false
        var interestCount: Int = 0
        var hasLanguages: Bool = false
        var languageCount: Int = 0
        var hasVerifiedPhoto: Bool = false
        var bioHasEmoji: Bool = false
        var bioWordCount: Int = 0
    }

    // MARK: - Quality Tip Model

    struct ProfileQualityTip: Identifiable {
        let id = UUID()
        let category: TipCategory
        let title: String
        let message: String
        let impact: ImpactLevel
        let isCompleted: Bool
        let points: Int
        let actionIcon: String

        enum TipCategory: String {
            case photos = "Photos"
            case bio = "Bio"
            case interests = "Interests"
            case verification = "Verification"
            case completeness = "Completeness"
        }

        enum ImpactLevel {
            case critical  // Red - must do
            case high      // Orange - should do
            case medium    // Yellow - nice to have
            case low       // Green - bonus

            var color: Color {
                switch self {
                case .critical: return .red
                case .high: return .orange
                case .medium: return .yellow
                case .low: return .green
                }
            }

            var icon: String {
                switch self {
                case .critical: return "exclamationmark.triangle.fill"
                case .high: return "exclamationmark.circle.fill"
                case .medium: return "info.circle.fill"
                case .low: return "star.fill"
                }
            }
        }
    }

    // MARK: - Score Calculation

    func calculateScore(for metrics: ProfileMetrics) -> (score: Int, tips: [ProfileQualityTip]) {
        var score = 0
        var tips: [ProfileQualityTip] = []

        // 1. Name (5 points - critical)
        if metrics.hasName {
            score += 5
        } else {
            tips.append(ProfileQualityTip(
                category: .completeness,
                title: "Add Your Name",
                message: "Profiles with names get 3x more matches",
                impact: .critical,
                isCompleted: false,
                points: 5,
                actionIcon: "person.fill"
            ))
        }

        // 2. Age (5 points - critical)
        if metrics.hasAge {
            score += 5
        } else {
            tips.append(ProfileQualityTip(
                category: .completeness,
                title: "Add Your Age",
                message: "Required to help find age-appropriate matches",
                impact: .critical,
                isCompleted: false,
                points: 5,
                actionIcon: "calendar"
            ))
        }

        // 3. Bio (20 points total - high impact)
        if metrics.hasBio {
            if metrics.bioLength >= 50 {
                score += 15

                // Bonus for good bio length (150-300 chars)
                if metrics.bioLength >= 150 && metrics.bioLength <= 300 {
                    score += 5
                } else if metrics.bioLength > 300 {
                    tips.append(ProfileQualityTip(
                        category: .bio,
                        title: "Shorten Your Bio",
                        message: "Keep it under 300 characters for best results",
                        impact: .medium,
                        isCompleted: false,
                        points: 5,
                        actionIcon: "text.alignleft"
                    ))
                } else {
                    tips.append(ProfileQualityTip(
                        category: .bio,
                        title: "Expand Your Bio",
                        message: "Add more details about yourself (150-300 chars ideal)",
                        impact: .medium,
                        isCompleted: false,
                        points: 5,
                        actionIcon: "text.alignleft"
                    ))
                }

                // Bonus for word count (20+ words)
                if metrics.bioWordCount >= 20 {
                    score += 3
                } else {
                    tips.append(ProfileQualityTip(
                        category: .bio,
                        title: "Add More Details",
                        message: "Aim for 20+ words in your bio",
                        impact: .low,
                        isCompleted: false,
                        points: 3,
                        actionIcon: "text.quote"
                    ))
                }

                // Bonus for emoji (makes bio engaging)
                if metrics.bioHasEmoji {
                    score += 2
                }
            } else {
                tips.append(ProfileQualityTip(
                    category: .bio,
                    title: "Write a Better Bio",
                    message: "Add at least 50 characters to tell your story",
                    impact: .high,
                    isCompleted: false,
                    points: 15,
                    actionIcon: "text.bubble.fill"
                ))
            }
        } else {
            tips.append(ProfileQualityTip(
                category: .bio,
                title: "Add a Bio",
                message: "Profiles with bios get 5x more matches. Share what makes you unique!",
                impact: .critical,
                isCompleted: false,
                points: 20,
                actionIcon: "text.bubble.fill"
            ))
        }

        // 4. Photos (35 points total - highest impact)
        if metrics.photoCount >= 2 {
            score += 20  // Minimum photos

            if metrics.photoCount >= 4 {
                score += 10  // Good number of photos

                if metrics.photoCount >= 6 {
                    score += 5  // Maximum photos
                } else {
                    tips.append(ProfileQualityTip(
                        category: .photos,
                        title: "Add More Photos",
                        message: "Upload 6 photos for maximum visibility",
                        impact: .medium,
                        isCompleted: false,
                        points: 5,
                        actionIcon: "photo.stack.fill"
                    ))
                }
            } else {
                tips.append(ProfileQualityTip(
                    category: .photos,
                    title: "Add More Photos",
                    message: "4-6 photos get 40% more likes. Show different sides of you!",
                    impact: .high,
                    isCompleted: false,
                    points: 15,
                    actionIcon: "photo.on.rectangle.fill"
                ))
            }
        } else if metrics.photoCount == 1 {
            score += 10
            tips.append(ProfileQualityTip(
                category: .photos,
                title: "Add More Photos",
                message: "Add at least 2 photos to activate your profile",
                impact: .critical,
                isCompleted: false,
                points: 25,
                actionIcon: "photo.badge.plus"
            ))
        } else {
            tips.append(ProfileQualityTip(
                category: .photos,
                title: "Add Photos",
                message: "Photos are essential! Add at least 2 to get started",
                impact: .critical,
                isCompleted: false,
                points: 35,
                actionIcon: "photo.circle.fill"
            ))
        }

        // 5. Location (10 points - high)
        if metrics.hasLocation {
            score += 10
        } else {
            tips.append(ProfileQualityTip(
                category: .completeness,
                title: "Add Your Location",
                message: "Help us find matches near you",
                impact: .high,
                isCompleted: false,
                points: 10,
                actionIcon: "location.fill"
            ))
        }

        // 6. Interests (15 points - medium)
        if metrics.hasInterests {
            if metrics.interestCount >= 5 {
                score += 15
            } else if metrics.interestCount >= 3 {
                score += 10
                tips.append(ProfileQualityTip(
                    category: .interests,
                    title: "Add More Interests",
                    message: "5+ interests help find better matches",
                    impact: .medium,
                    isCompleted: false,
                    points: 5,
                    actionIcon: "heart.text.square.fill"
                ))
            } else {
                score += 5
                tips.append(ProfileQualityTip(
                    category: .interests,
                    title: "Add More Interests",
                    message: "Add at least 3 interests to show what you love",
                    impact: .medium,
                    isCompleted: false,
                    points: 10,
                    actionIcon: "heart.text.square"
                ))
            }
        } else {
            tips.append(ProfileQualityTip(
                category: .interests,
                title: "Add Interests",
                message: "Share your hobbies to find like-minded matches",
                impact: .medium,
                isCompleted: false,
                points: 15,
                actionIcon: "sparkles"
            ))
        }

        // 7. Languages (5 points - low)
        if metrics.hasLanguages {
            score += 5
        } else {
            tips.append(ProfileQualityTip(
                category: .completeness,
                title: "Add Languages",
                message: "Connect with people who speak your language",
                impact: .low,
                isCompleted: false,
                points: 5,
                actionIcon: "globe"
            ))
        }

        // 8. Verified Photo (5 points - bonus)
        if metrics.hasVerifiedPhoto {
            score += 5
        } else {
            tips.append(ProfileQualityTip(
                category: .verification,
                title: "Verify Your Profile",
                message: "Verified profiles get 2x more matches and build trust",
                impact: .medium,
                isCompleted: false,
                points: 5,
                actionIcon: "checkmark.seal.fill"
            ))
        }

        // Sort tips by impact (critical first)
        tips.sort { tip1, tip2 in
            if tip1.impact == tip2.impact {
                return tip1.points > tip2.points
            }

            let impactOrder: [ProfileQualityTip.ImpactLevel] = [.critical, .high, .medium, .low]
            guard let index1 = impactOrder.firstIndex(of: tip1.impact),
                  let index2 = impactOrder.firstIndex(of: tip2.impact) else {
                return false
            }
            return index1 < index2
        }

        return (min(score, 100), tips)
    }

    // MARK: - User-Friendly Methods

    /// Updates score based on current user profile
    func updateScore(for user: User) {
        let metrics = ProfileMetrics(
            hasName: !user.fullName.isEmpty,
            hasAge: user.age > 0,
            hasBio: !user.bio.isEmpty,
            bioLength: user.bio.count,
            hasLocation: !user.location.isEmpty,
            photoCount: user.photos.count + (user.profileImageURL.isEmpty ? 0 : 1),
            hasInterests: !user.interests.isEmpty,
            interestCount: user.interests.count,
            hasLanguages: !user.languages.isEmpty,
            languageCount: user.languages.count,
            hasVerifiedPhoto: user.isVerified,
            bioHasEmoji: user.bio.containsEmoji,
            bioWordCount: user.bio.split(separator: " ").count
        )

        let result = calculateScore(for: metrics)
        currentScore = result.score
        qualityTips = result.tips
    }

    /// Get quality level description
    func getQualityLevel(for score: Int) -> (level: String, color: Color, message: String) {
        switch score {
        case 0..<30:
            return ("Incomplete", .red, "Complete your profile to start matching")
        case 30..<50:
            return ("Basic", .orange, "Add more details to improve your matches")
        case 50..<70:
            return ("Good", .yellow, "You're on the right track!")
        case 70..<85:
            return ("Great", .green, "Your profile looks great!")
        case 85..<100:
            return ("Excellent", .blue, "Almost perfect! Keep it up")
        case 100:
            return ("Perfect", .purple, "🌟 Your profile is amazing!")
        default:
            return ("Unknown", .gray, "")
        }
    }

    /// Get priority tip (most important to fix)
    func getPriorityTip() -> ProfileQualityTip? {
        return qualityTips.first
    }

    /// Get tips by category
    func getTips(for category: ProfileQualityTip.TipCategory) -> [ProfileQualityTip] {
        return qualityTips.filter { $0.category == category }
    }

    /// Calculate potential score increase
    func potentialScoreIncrease() -> Int {
        return qualityTips.reduce(0) { $0 + $1.points }
    }

    /// Get completion percentage
    func getCompletionPercentage() -> Double {
        return Double(currentScore) / Double(maxScore)
    }
}

// MARK: - String Extension

extension String {
    var containsEmoji: Bool {
        return unicodeScalars.contains { $0.properties.isEmoji }
    }
}

// MARK: - SwiftUI View for Profile Quality Card

struct ProfileQualityCard: View {
    @ObservedObject var scorer: ProfileQualityScorer
    let user: User

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Profile Quality")
                        .font(.headline)

                    let quality = scorer.getQualityLevel(for: scorer.currentScore)
                    Text(quality.level)
                        .font(.caption)
                        .foregroundColor(quality.color)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: scorer.getCompletionPercentage())
                        .stroke(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: scorer.currentScore)

                    Text("\(scorer.currentScore)")
                        .font(.headline)
                        .fontWeight(.bold)
                }
            }

            // Priority Tip
            if let priorityTip = scorer.getPriorityTip() {
                HStack(spacing: 12) {
                    Image(systemName: priorityTip.actionIcon)
                        .font(.title2)
                        .foregroundColor(priorityTip.impact.color)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(priorityTip.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(priorityTip.message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text("+\(priorityTip.points)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .padding()
                .background(priorityTip.impact.color.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
        .onAppear {
            scorer.updateScore(for: user)
        }
    }
}
