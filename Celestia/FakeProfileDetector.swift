//
//  FakeProfileDetector.swift
//  Celestia
//
//  AI-powered fake profile detection system
//  Analyzes photos, bio, behavior patterns to detect fake/bot profiles
//

import Foundation
import UIKit
import CoreML

// MARK: - Fake Profile Detector

class FakeProfileDetector {

    // MARK: - Singleton

    static let shared = FakeProfileDetector()

    // MARK: - Properties

    private let suspicionThreshold: Float = 0.7 // 70% confidence threshold

    // MARK: - Initialization

    private init() {
        Logger.shared.info("FakeProfileDetector initialized", category: .general)
    }

    // MARK: - Profile Analysis

    /// Analyze profile for fake/bot indicators
    func analyzeProfile(
        photos: [UIImage],
        bio: String,
        name: String,
        age: Int,
        location: String?
    ) async -> FakeProfileAnalysis {

        Logger.shared.info("Analyzing profile for fake indicators", category: .general)

        var suspicionScore: Float = 0
        var indicators: [FakeIndicator] = []

        // 1. Photo Analysis
        let photoAnalysis = await analyzePhotos(photos)
        suspicionScore += photoAnalysis.suspicionScore
        indicators.append(contentsOf: photoAnalysis.indicators)

        // 2. Bio Analysis
        let bioAnalysis = analyzeBio(bio)
        suspicionScore += bioAnalysis.suspicionScore
        indicators.append(contentsOf: bioAnalysis.indicators)

        // 3. Name Analysis
        let nameAnalysis = analyzeName(name)
        suspicionScore += nameAnalysis.suspicionScore
        indicators.append(contentsOf: nameAnalysis.indicators)

        // 4. Profile Completeness
        let completenessAnalysis = analyzeCompleteness(
            photos: photos,
            bio: bio,
            location: location
        )
        suspicionScore += completenessAnalysis.suspicionScore
        indicators.append(contentsOf: completenessAnalysis.indicators)

        // Normalize score (0-1)
        let normalizedScore = min(1.0, suspicionScore / 4.0)

        let isSuspicious = normalizedScore >= suspicionThreshold

        Logger.shared.info("Profile analysis completed. Suspicion score: \(normalizedScore)", category: .general)

        if isSuspicious {
            Logger.shared.warning("Suspicious profile detected", category: .general)
        }

        return FakeProfileAnalysis(
            isSuspicious: isSuspicious,
            suspicionScore: normalizedScore,
            indicators: indicators,
            recommendation: isSuspicious ? .flagForReview : .allowProfile
        )
    }

    // MARK: - Photo Analysis

    private func analyzePhotos(_ photos: [UIImage]) async -> (suspicionScore: Float, indicators: [FakeIndicator]) {
        var score: Float = 0
        var indicators: [FakeIndicator] = []

        // Check 1: Insufficient photos
        if photos.isEmpty {
            score += 0.8
            indicators.append(.noPhotos)
        } else if photos.count == 1 {
            score += 0.4
            indicators.append(.singlePhoto)
        }

        // Check 2: Reverse image search (check for stock photos)
        for (index, photo) in photos.enumerated() {
            if await isStockPhoto(photo) {
                score += 0.6
                indicators.append(.stockPhoto(index: index))
            }
        }

        // Check 3: Professional/model photos
        for (index, photo) in photos.enumerated() {
            if isProfessionalPhoto(photo) {
                score += 0.3
                indicators.append(.professionalPhoto(index: index))
            }
        }

        // Check 4: All photos look different (different people)
        if photos.count >= 2 {
            let faceConsistency = await checkFaceConsistency(photos)
            if faceConsistency < 0.5 {
                score += 0.7
                indicators.append(.inconsistentFaces)
            }
        }

        // Check 5: Image quality too perfect (professional editing)
        // SAFETY: Only calculate average quality if photos exist
        if !photos.isEmpty {
            let avgQuality = photos.map { analyzeImageQuality($0) }.reduce(0, +) / Float(photos.count)
            if avgQuality > 0.95 {
                score += 0.2
                indicators.append(.suspiciouslyHighQuality)
            }
        }

        return (score, indicators)
    }

    // MARK: - Bio Analysis

    private func analyzeBio(_ bio: String) -> (suspicionScore: Float, indicators: [FakeIndicator]) {
        var score: Float = 0
        var indicators: [FakeIndicator] = []

        // Check 1: Empty or very short bio
        if bio.isEmpty {
            score += 0.6
            indicators.append(.emptyBio)
        } else if bio.count < 20 {
            score += 0.3
            indicators.append(.shortBio)
        }

        // Check 2: Generic bio patterns
        let genericPhrases = [
            "love to laugh",
            "live laugh love",
            "looking for fun",
            "just ask",
            "new to this",
            "swipe right",
            "no drama"
        ]

        let bioLower = bio.lowercased()
        var genericCount = 0
        for phrase in genericPhrases {
            if bioLower.contains(phrase) {
                genericCount += 1
            }
        }

        if genericCount >= 3 {
            score += 0.5
            indicators.append(.genericBio)
        }

        // Check 3: Contains external links (Instagram, Snapchat, etc.)
        let linkPatterns = ["instagram", "snapchat", "kik", "whatsapp", "@", "http"]
        for pattern in linkPatterns {
            if bioLower.contains(pattern) {
                score += 0.4
                indicators.append(.containsExternalLinks)
                break
            }
        }

        // Check 4: Contains money/payment keywords
        let moneyKeywords = ["cashapp", "venmo", "paypal", "donate", "support", "subscribe"]
        for keyword in moneyKeywords {
            if bioLower.contains(keyword) {
                score += 0.8
                indicators.append(.containsPaymentInfo)
                break
            }
        }

        // Check 5: All emojis, no text
        let emojiCount = bio.unicodeScalars.filter { $0.properties.isEmoji }.count
        if emojiCount > bio.count / 2 {
            score += 0.4
            indicators.append(.excessiveEmojis)
        }

        // Check 6: Suspicious patterns (bot-like text)
        if isBotLikeText(bio) {
            score += 0.7
            indicators.append(.botLikeText)
        }

        return (score, indicators)
    }

    // MARK: - Name Analysis

    private func analyzeName(_ name: String) -> (suspicionScore: Float, indicators: [FakeIndicator]) {
        var score: Float = 0
        var indicators: [FakeIndicator] = []

        let nameLower = name.lowercased()

        // Check 1: Single name or initials
        if !name.contains(" ") {
            score += 0.2
            indicators.append(.singleName)
        }

        // Check 2: Suspicious patterns
        if name.count < 2 {
            score += 0.6
            indicators.append(.suspiciousName)
        }

        // Check 3: All caps or all lowercase
        if name == name.uppercased() || name == name.lowercased() {
            score += 0.3
            indicators.append(.unusualNameFormat)
        }

        // Check 4: Contains numbers
        if name.rangeOfCharacter(from: .decimalDigits) != nil {
            score += 0.4
            indicators.append(.nameContainsNumbers)
        }

        // Check 5: Generic names (fake, test, bot, etc.)
        let suspiciousKeywords = ["fake", "test", "bot", "scam", "spam"]
        for keyword in suspiciousKeywords {
            if nameLower.contains(keyword) {
                score += 0.9
                indicators.append(.suspiciousKeywords)
                break
            }
        }

        return (score, indicators)
    }

    // MARK: - Profile Completeness

    private func analyzeCompleteness(
        photos: [UIImage],
        bio: String,
        location: String?
    ) -> (suspicionScore: Float, indicators: [FakeIndicator]) {
        var score: Float = 0
        var indicators: [FakeIndicator] = []

        var missingFields = 0

        if photos.isEmpty {
            missingFields += 1
        }

        if bio.isEmpty {
            missingFields += 1
        }

        if location == nil {
            missingFields += 1
        }

        if missingFields >= 2 {
            score += 0.5
            indicators.append(.incompleteProfile)
        }

        return (score, indicators)
    }

    // MARK: - Helper Methods

    private func isStockPhoto(_ image: UIImage) async -> Bool {
        // In production, use reverse image search API (Google, TinEye)
        // For now, return false
        return false
    }

    private func isProfessionalPhoto(_ image: UIImage) -> Bool {
        // Check for professional photo characteristics
        // - High resolution
        // - Professional lighting
        // - Studio background
        // Simplified implementation

        guard let cgImage = image.cgImage else { return false }

        let width = cgImage.width
        let height = cgImage.height

        // Very high resolution might indicate professional photos
        return width * height > 4000 * 3000
    }

    private func checkFaceConsistency(_ photos: [UIImage]) async -> Float {
        // Use facial recognition to check if all photos contain the same person
        // Simplified: return high consistency
        return 0.85
    }

    private func analyzeImageQuality(_ image: UIImage) -> Float {
        // Analyze image quality (sharpness, lighting, etc.)
        // Simplified: return moderate quality
        return 0.75
    }

    private func isBotLikeText(_ text: String) -> Bool {
        // Check for bot-like patterns
        // - Excessive capitalization
        // - Too many special characters
        // - Copy-paste errors

        let specialChars = text.filter { "!@#$%^&*()".contains($0) }
        // SAFETY: Avoid division by zero for empty text
        if !text.isEmpty && Float(specialChars.count) / Float(text.count) > 0.3 {
            return true
        }

        return false
    }

    // MARK: - Behavioral Analysis

    /// Analyze user behavior for bot/scammer patterns
    func analyzeBehavior(
        messagesSent: Int,
        messagesReceived: Int,
        matchesCount: Int,
        accountAge: TimeInterval
    ) -> BehaviorAnalysis {

        var suspicionScore: Float = 0
        var indicators: [BehaviorIndicator] = []

        // Check 1: Mass messaging (bot behavior)
        if messagesSent > 100 && matchesCount < 10 {
            suspicionScore += 0.7
            indicators.append(.massMessaging)
        }

        // Check 2: New account with high activity
        let daysSinceCreation = accountAge / 86400 // Convert to days
        if daysSinceCreation < 1 && messagesSent > 50 {
            suspicionScore += 0.8
            indicators.append(.newAccountHighActivity)
        }

        // Check 3: No messages received (people don't engage)
        if messagesReceived == 0 && messagesSent > 20 {
            suspicionScore += 0.6
            indicators.append(.noEngagement)
        }

        // Check 4: Rapid matching
        if matchesCount > 100 && daysSinceCreation < 7 {
            suspicionScore += 0.5
            indicators.append(.rapidMatching)
        }

        return BehaviorAnalysis(
            suspicionScore: min(1.0, suspicionScore),
            indicators: indicators
        )
    }
}

// MARK: - Fake Profile Analysis

struct FakeProfileAnalysis {
    let isSuspicious: Bool
    let suspicionScore: Float // 0.0 to 1.0
    let indicators: [FakeIndicator]
    let recommendation: ProfileRecommendation
}

// MARK: - Fake Indicators

enum FakeIndicator: Equatable {
    case noPhotos
    case singlePhoto
    case stockPhoto(index: Int)
    case professionalPhoto(index: Int)
    case inconsistentFaces
    case suspiciouslyHighQuality
    case emptyBio
    case shortBio
    case genericBio
    case containsExternalLinks
    case containsPaymentInfo
    case excessiveEmojis
    case botLikeText
    case singleName
    case suspiciousName
    case unusualNameFormat
    case nameContainsNumbers
    case suspiciousKeywords
    case incompleteProfile

    var description: String {
        switch self {
        case .noPhotos:
            return "No profile photos"
        case .singlePhoto:
            return "Only one profile photo"
        case .stockPhoto(let index):
            return "Photo \(index + 1) appears to be a stock photo"
        case .professionalPhoto(let index):
            return "Photo \(index + 1) appears professionally shot"
        case .inconsistentFaces:
            return "Photos show different people"
        case .suspiciouslyHighQuality:
            return "Unusually high photo quality"
        case .emptyBio:
            return "No bio provided"
        case .shortBio:
            return "Very short bio"
        case .genericBio:
            return "Generic/template bio"
        case .containsExternalLinks:
            return "Bio contains external social media links"
        case .containsPaymentInfo:
            return "Bio contains payment/donation info"
        case .excessiveEmojis:
            return "Excessive emoji usage"
        case .botLikeText:
            return "Bio has bot-like patterns"
        case .singleName:
            return "Single name only"
        case .suspiciousName:
            return "Suspicious name format"
        case .unusualNameFormat:
            return "Unusual name formatting"
        case .nameContainsNumbers:
            return "Name contains numbers"
        case .suspiciousKeywords:
            return "Name contains suspicious keywords"
        case .incompleteProfile:
            return "Incomplete profile information"
        }
    }
}

// MARK: - Behavior Analysis

struct BehaviorAnalysis {
    let suspicionScore: Float
    let indicators: [BehaviorIndicator]
}

enum BehaviorIndicator {
    case massMessaging
    case newAccountHighActivity
    case noEngagement
    case rapidMatching

    var description: String {
        switch self {
        case .massMessaging:
            return "Sending many messages with few matches"
        case .newAccountHighActivity:
            return "New account with unusually high activity"
        case .noEngagement:
            return "Sending messages but receiving none"
        case .rapidMatching:
            return "Matching with many users very quickly"
        }
    }
}

// MARK: - Profile Recommendation

enum ProfileRecommendation {
    case allowProfile
    case flagForReview
    case autoBlock
}
