//
//  ProfileTips.swift
//  Celestia
//
//  Smart profile improvement tips with impact metrics
//

import Foundation

class ProfileTips {
    static let shared = ProfileTips()

    private init() {}

    // MARK: - Profile Analysis

    struct ProfileAnalysis {
        let completionPercentage: Int
        let tips: [ProfileTip]
        let strengths: [String]
        let overallRating: ProfileRating
    }

    enum ProfileRating {
        case excellent  // 90-100%
        case great      // 75-89%
        case good       // 60-74%
        case needsWork  // < 60%

        var title: String {
            switch self {
            case .excellent: return "Excellent Profile!"
            case .great: return "Great Profile"
            case .good: return "Good Start"
            case .needsWork: return "Needs Improvement"
            }
        }

        var emoji: String {
            switch self {
            case .excellent: return "🌟"
            case .great: return "✨"
            case .good: return "👍"
            case .needsWork: return "💪"
            }
        }

        var message: String {
            switch self {
            case .excellent: return "Your profile looks amazing! You're getting maximum visibility."
            case .great: return "Almost there! A few tweaks and you'll be at 100%."
            case .good: return "You're on the right track. Complete these tips to stand out more."
            case .needsWork: return "Let's boost your profile! Follow these tips to get more matches."
            }
        }
    }

    func analyzeProfile(_ user: User) -> ProfileAnalysis {
        let completion = calculateCompletion(user)
        let tips = generateTips(for: user)
        let strengths = identifyStrengths(user)
        let rating = getRating(for: completion)

        return ProfileAnalysis(
            completionPercentage: completion,
            tips: tips,
            strengths: strengths,
            overallRating: rating
        )
    }

    // MARK: - Completion Calculation

    private func calculateCompletion(_ user: User) -> Int {
        var score = 0
        let totalPoints = 100

        // Photos (30 points)
        let photoCount = user.photos.isEmpty ? 0 : user.photos.count
        if photoCount >= 4 {
            score += 30
        } else if photoCount >= 2 {
            score += 20
        } else if photoCount >= 1 {
            score += 10
        }

        // Bio (20 points)
        if !user.bio.isEmpty {
            if user.bio.count >= 100 {
                score += 20
            } else if user.bio.count >= 50 {
                score += 15
            } else {
                score += 10
            }
        }

        // Interests (20 points)
        if user.interests.count >= 5 {
            score += 20
        } else if user.interests.count >= 3 {
            score += 15
        } else if user.interests.count >= 1 {
            score += 10
        }

        // Languages (10 points)
        if user.languages.count >= 2 {
            score += 10
        } else if user.languages.count >= 1 {
            score += 5
        }

        // Verification (10 points)
        if user.isVerified {
            score += 10
        }

        // Premium (10 points bonus)
        if user.isPremium {
            score += 10
        }

        return min(score, totalPoints)
    }

    // MARK: - Tip Generation

    private func generateTips(for user: User) -> [ProfileTip] {
        var tips: [ProfileTip] = []

        // Photo tips
        let photoCount = user.photos.isEmpty ? 0 : user.photos.count
        if photoCount < 4 {
            let photosNeeded = 4 - photoCount
            let impactPercent = photosNeeded * 10
            tips.append(ProfileTip(
                icon: "photo.fill",
                title: "Add \(photosNeeded) more photo\(photosNeeded > 1 ? "s" : "")",
                description: "Profiles with 4+ photos get 3x more matches",
                impact: "Boost visibility by \(impactPercent)%",
                priority: .high,
                action: .addPhotos
            ))
        }

        // Bio tips
        if user.bio.isEmpty {
            tips.append(ProfileTip(
                icon: "text.alignleft",
                title: "Write your bio",
                description: "Tell people what makes you unique",
                impact: "Increase matches by 40%",
                priority: .high,
                action: .writeBio
            ))
        } else if user.bio.count < 100 {
            tips.append(ProfileTip(
                icon: "text.alignleft",
                title: "Expand your bio",
                description: "Add more details about your personality",
                impact: "Boost engagement by 25%",
                priority: .medium,
                action: .writeBio
            ))
        }

        // Interest tips
        if user.interests.count < 5 {
            let needed = 5 - user.interests.count
            tips.append(ProfileTip(
                icon: "star.fill",
                title: "Add \(needed) more interest\(needed > 1 ? "s" : "")",
                description: "Help people find common ground with you",
                impact: "Improve match quality by 35%",
                priority: .medium,
                action: .addInterests
            ))
        }

        // Language tips
        if user.languages.isEmpty {
            tips.append(ProfileTip(
                icon: "globe",
                title: "Add languages you speak",
                description: "Connect with people from different backgrounds",
                impact: "Expand your reach by 20%",
                priority: .low,
                action: .addLanguages
            ))
        }

        // Verification tip
        if !user.isVerified {
            tips.append(ProfileTip(
                icon: "checkmark.seal.fill",
                title: "Get verified",
                description: "Build trust with a quick selfie verification",
                impact: "Get 2x more likes",
                priority: .high,
                action: .getVerified
            ))
        }

        // Sort by priority
        return tips.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }

    // MARK: - Strengths Identification

    private func identifyStrengths(_ user: User) -> [String] {
        var strengths: [String] = []

        if user.photos.count >= 4 {
            strengths.append("Great photo variety")
        }

        if user.bio.count >= 100 {
            strengths.append("Detailed bio")
        }

        if user.interests.count >= 5 {
            strengths.append("Lots of interests")
        }

        if user.isVerified {
            strengths.append("Verified profile")
        }

        if user.isPremium {
            strengths.append("Premium member")
        }

        return strengths
    }

    private func getRating(for completion: Int) -> ProfileRating {
        switch completion {
        case 90...100:
            return .excellent
        case 75..<90:
            return .great
        case 60..<75:
            return .good
        default:
            return .needsWork
        }
    }
}

// MARK: - Models

struct ProfileTip: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let impact: String
    let priority: Priority
    let action: TipAction

    enum Priority: Int {
        case high = 3
        case medium = 2
        case low = 1
    }

    enum TipAction {
        case addPhotos
        case writeBio
        case addInterests
        case addLanguages
        case getVerified
    }
}
