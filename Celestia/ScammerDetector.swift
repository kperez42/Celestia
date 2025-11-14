//
//  ScammerDetector.swift
//  Celestia
//
//  Automated scammer detection analyzing chat messages for scam patterns
//  Detects romance scams, financial scams, catfishing, and malicious behavior
//

import Foundation
import NaturalLanguage

// MARK: - Scammer Detector

class ScammerDetector {

    // MARK: - Singleton

    static let shared = ScammerDetector()

    // MARK: - Properties

    private let scamThreshold: Float = 0.6 // 60% confidence threshold
    private let sentimentAnalyzer = NLTagger(tagSchemes: [.sentimentScore])

    // MARK: - Scam Keywords Database

    private let financialScamKeywords = [
        "send money", "cash app", "venmo", "paypal", "zelle", "western union",
        "wire transfer", "gift card", "bitcoin", "cryptocurrency", "invest",
        "business opportunity", "make money", "financial help", "need money",
        "emergency", "hospital", "medical bills", "rent due", "eviction"
    ]

    private let romanceScamKeywords = [
        "true love", "soul mate", "meant to be", "destiny", "falling for you",
        "love you so much", "never felt this way", "special connection",
        "move to your country", "visit you", "need visa", "need ticket"
    ]

    private let urgencyKeywords = [
        "urgent", "emergency", "right now", "immediately", "asap", "hurry",
        "quick", "limited time", "expire", "deadline", "last chance"
    ]

    private let suspiciousRequestKeywords = [
        "nude", "naked", "sexy pic", "private photo", "onlyfans", "premium snap",
        "click link", "visit website", "download app", "install", "sign up"
    ]

    private let catfishingIndicators = [
        "can't meet", "camera broken", "phone broken", "mic broken",
        "no video", "can't call", "not ready", "shy", "anxious",
        "in military", "overseas", "deployed", "oil rig", "ship"
    ]

    // MARK: - Initialization

    private init() {
        Logger.shared.info("ScammerDetector initialized", category: .general)
    }

    // MARK: - Message Analysis

    /// Analyze a single message for scam indicators
    func analyzeMessage(_ message: String) -> ScamAnalysis {
        var scamScore: Float = 0
        var indicators: [ScamIndicator] = []
        var scamTypes: Set<ScamType> = []

        let messageLower = message.lowercased()

        // 1. Financial scam detection
        let financialScore = detectFinancialScam(messageLower)
        if financialScore > 0 {
            scamScore += financialScore
            indicators.append(.financialRequest)
            scamTypes.insert(.financialScam)
        }

        // 2. Romance scam detection
        let romanceScore = detectRomanceScam(messageLower)
        if romanceScore > 0 {
            scamScore += romanceScore
            indicators.append(.romanceScamLanguage)
            scamTypes.insert(.romanceScam)
        }

        // 3. Urgency tactics
        let urgencyScore = detectUrgency(messageLower)
        if urgencyScore > 0 {
            scamScore += urgencyScore
            indicators.append(.urgencyTactics)
        }

        // 4. Suspicious requests
        let suspiciousScore = detectSuspiciousRequests(messageLower)
        if suspiciousScore > 0 {
            scamScore += suspiciousScore
            indicators.append(.suspiciousRequest)
            scamTypes.insert(.phishing)
        }

        // 5. External links
        if containsExternalLinks(message) {
            scamScore += 0.4
            indicators.append(.externalLinks)
            scamTypes.insert(.phishing)
        }

        // 6. Phone numbers or alternative contact info
        if containsContactInfo(message) {
            scamScore += 0.3
            indicators.append(.alternativeContactInfo)
        }

        // 7. Excessive length (long scripted messages)
        if message.count > 500 {
            scamScore += 0.2
            indicators.append(.excessiveLength)
        }

        // 8. Sentiment analysis (overly positive/manipulative)
        let sentiment = analyzeSentiment(message)
        if sentiment > 0.8 {
            scamScore += 0.3
            indicators.append(.manipulativeTone)
        }

        // Normalize score
        let normalizedScore = min(1.0, scamScore)
        let isScam = normalizedScore >= scamThreshold

        return ScamAnalysis(
            isScam: isScam,
            scamScore: normalizedScore,
            indicators: indicators,
            scamTypes: Array(scamTypes),
            recommendation: isScam ? .blockUser : .monitor
        )
    }

    /// Analyze conversation history for scam patterns
    func analyzeConversation(messages: [ChatMessage]) -> ConversationScamAnalysis {
        var totalScore: Float = 0
        var allIndicators: [ScamIndicator] = []
        var scamTypes: Set<ScamType> = []
        var escalationPattern = false

        // Analyze individual messages
        let messageAnalyses = messages.map { analyzeMessage($0.text) }

        for analysis in messageAnalyses {
            totalScore += analysis.scamScore
            allIndicators.append(contentsOf: analysis.indicators)
            scamTypes.formUnion(analysis.scamTypes)
        }

        // Check for escalation pattern
        if messages.count >= 3 {
            escalationPattern = detectEscalationPattern(messageAnalyses)
        }

        // Check for rapid relationship building
        let rapidRelationship = detectRapidRelationshipBuilding(messages)

        // Check for catfishing indicators
        let catfishingScore = detectCatfishing(messages)
        if catfishingScore > 0.5 {
            scamTypes.insert(.catfishing)
            allIndicators.append(.avoidanceBehavior)
        }

        // Calculate average score
        let avgScore = messages.isEmpty ? 0 : totalScore / Float(messages.count)

        // Boost score for conversation-level patterns
        var conversationScore = avgScore
        if escalationPattern {
            conversationScore += 0.2
            allIndicators.append(.escalationPattern)
        }
        if rapidRelationship {
            conversationScore += 0.3
            allIndicators.append(.rapidRelationshipBuilding)
        }

        conversationScore = min(1.0, conversationScore)
        let isScam = conversationScore >= scamThreshold

        return ConversationScamAnalysis(
            isScam: isScam,
            scamScore: conversationScore,
            indicators: Array(Set(allIndicators)), // Remove duplicates
            scamTypes: Array(scamTypes),
            escalationDetected: escalationPattern,
            messageCount: messages.count,
            recommendation: determineRecommendation(conversationScore, scamTypes: Array(scamTypes))
        )
    }

    // MARK: - Detection Methods

    private func detectFinancialScam(_ message: String) -> Float {
        var score: Float = 0
        var matchCount = 0

        for keyword in financialScamKeywords {
            if message.contains(keyword) {
                matchCount += 1
            }
        }

        if matchCount >= 1 {
            score = 0.6
        }
        if matchCount >= 2 {
            score = 0.8
        }
        if matchCount >= 3 {
            score = 1.0
        }

        return score
    }

    private func detectRomanceScam(_ message: String) -> Float {
        var score: Float = 0
        var matchCount = 0

        for keyword in romanceScamKeywords {
            if message.contains(keyword) {
                matchCount += 1
            }
        }

        if matchCount >= 2 {
            score = 0.4
        }
        if matchCount >= 4 {
            score = 0.7
        }

        return score
    }

    private func detectUrgency(_ message: String) -> Float {
        var matchCount = 0

        for keyword in urgencyKeywords {
            if message.contains(keyword) {
                matchCount += 1
            }
        }

        return matchCount >= 2 ? 0.3 : (matchCount == 1 ? 0.1 : 0)
    }

    private func detectSuspiciousRequests(_ message: String) -> Float {
        var matchCount = 0

        for keyword in suspiciousRequestKeywords {
            if message.contains(keyword) {
                matchCount += 1
            }
        }

        return matchCount >= 1 ? 0.5 : 0
    }

    private func containsExternalLinks(_ message: String) -> Bool {
        let patterns = [
            "http://", "https://", "www.", ".com", ".net", ".org",
            "bit.ly", "tinyurl", "t.me", "wa.me"
        ]

        for pattern in patterns {
            if message.lowercased().contains(pattern) {
                return true
            }
        }

        return false
    }

    private func containsContactInfo(_ message: String) -> Bool {
        // Phone number pattern - Check with ValidationHelper
        let words = message.components(separatedBy: .whitespacesAndNewlines)
        for word in words {
            // Check for phone numbers
            let cleanedWord = word.trimmingCharacters(in: .punctuationCharacters)
            if ValidationHelper.isValidPhoneNumber(cleanedWord) {
                return true
            }

            // Email pattern - REFACTORED: Use ValidationHelper for consistency
            if ValidationHelper.isValidEmail(word) {
                return true
            }
        }

        // Social media handles
        let socialPatterns = ["kik:", "snapchat:", "instagram:", "telegram:", "whatsapp:"]
        for pattern in socialPatterns {
            if message.lowercased().contains(pattern) {
                return true
            }
        }

        return false
    }

    private func analyzeSentiment(_ message: String) -> Float {
        sentimentAnalyzer.string = message

        var sentimentScore: Float = 0
        sentimentAnalyzer.enumerateTags(in: message.startIndex..<message.endIndex, unit: .paragraph, scheme: .sentimentScore) { tag, _ in
            if let tag = tag, let score = Double(tag.rawValue) {
                sentimentScore = Float(score)
            }
            return true
        }

        // Convert -1 to 1 scale to 0 to 1 scale
        return (sentimentScore + 1) / 2
    }

    private func detectEscalationPattern(_ analyses: [ScamAnalysis]) -> Bool {
        guard analyses.count >= 3 else { return false }

        // Check if scam scores increase over time
        let recentThree = analyses.suffix(3)
        let scores = recentThree.map { $0.scamScore }

        return scores[1] > scores[0] && scores[2] > scores[1]
    }

    private func detectRapidRelationshipBuilding(_ messages: [ChatMessage]) -> Bool {
        guard messages.count >= 5 else { return false }

        // Check if user uses intimate language within first 5 messages
        let firstFive = messages.prefix(5)
        let intimateKeywords = ["love", "beautiful", "gorgeous", "perfect", "soul mate", "marry"]

        var intimateCount = 0
        for message in firstFive {
            for keyword in intimateKeywords {
                if message.text.lowercased().contains(keyword) {
                    intimateCount += 1
                    break
                }
            }
        }

        return intimateCount >= 2
    }

    private func detectCatfishing(_ messages: [ChatMessage]) -> Float {
        var score: Float = 0
        var matchCount = 0

        for message in messages {
            let messageLower = message.text.lowercased()
            for indicator in catfishingIndicators {
                if messageLower.contains(indicator) {
                    matchCount += 1
                    break
                }
            }
        }

        if matchCount >= 2 {
            score = 0.6
        }
        if matchCount >= 4 {
            score = 0.9
        }

        return score
    }

    private func determineRecommendation(_ score: Float, scamTypes: [ScamType]) -> ScamRecommendation {
        if score >= 0.8 || scamTypes.contains(.financialScam) {
            return .blockUser
        } else if score >= 0.6 {
            return .warnUser
        } else if score >= 0.4 {
            return .monitor
        } else {
            return .noAction
        }
    }
}

// MARK: - Chat Message Model

struct ChatMessage: Codable {
    let text: String
    let senderId: String
    let timestamp: Date
}

// MARK: - Scam Analysis

struct ScamAnalysis: Codable {
    let isScam: Bool
    let scamScore: Float // 0.0 to 1.0
    let indicators: [ScamIndicator]
    let scamTypes: [ScamType]
    let recommendation: ScamRecommendation
}

struct ConversationScamAnalysis: Codable {
    let isScam: Bool
    let scamScore: Float
    let indicators: [ScamIndicator]
    let scamTypes: [ScamType]
    let escalationDetected: Bool
    let messageCount: Int
    let recommendation: ScamRecommendation
}

// MARK: - Scam Types

enum ScamType: String, Codable {
    case financialScam = "financial_scam"
    case romanceScam = "romance_scam"
    case phishing = "phishing"
    case catfishing = "catfishing"
    case spam = "spam"

    var displayName: String {
        switch self {
        case .financialScam:
            return "Financial Scam"
        case .romanceScam:
            return "Romance Scam"
        case .phishing:
            return "Phishing/Malware"
        case .catfishing:
            return "Catfishing"
        case .spam:
            return "Spam"
        }
    }

    var description: String {
        switch self {
        case .financialScam:
            return "User is requesting money or financial information"
        case .romanceScam:
            return "User is building rapid emotional connection for manipulation"
        case .phishing:
            return "User is attempting to steal information via links or requests"
        case .catfishing:
            return "User may be using fake identity or avoiding verification"
        case .spam:
            return "User is sending unsolicited promotional content"
        }
    }
}

// MARK: - Scam Indicators

enum ScamIndicator: Equatable, Codable {
    case financialRequest
    case romanceScamLanguage
    case urgencyTactics
    case suspiciousRequest
    case externalLinks
    case alternativeContactInfo
    case excessiveLength
    case manipulativeTone
    case escalationPattern
    case rapidRelationshipBuilding
    case avoidanceBehavior

    var description: String {
        switch self {
        case .financialRequest:
            return "Requesting money or financial assistance"
        case .romanceScamLanguage:
            return "Using manipulative romantic language"
        case .urgencyTactics:
            return "Creating false sense of urgency"
        case .suspiciousRequest:
            return "Requesting inappropriate content or actions"
        case .externalLinks:
            return "Sharing external links (potential phishing)"
        case .alternativeContactInfo:
            return "Pushing to move conversation off-platform"
        case .excessiveLength:
            return "Sending unusually long scripted messages"
        case .manipulativeTone:
            return "Using manipulative or overly positive language"
        case .escalationPattern:
            return "Increasingly suspicious behavior over time"
        case .rapidRelationshipBuilding:
            return "Building emotional connection too quickly"
        case .avoidanceBehavior:
            return "Avoiding video calls or verification"
        }
    }
}

// MARK: - Recommendations

enum ScamRecommendation: Codable {
    case noAction
    case monitor
    case warnUser
    case blockUser

    var displayText: String {
        switch self {
        case .noAction:
            return "No action needed"
        case .monitor:
            return "Monitor conversation"
        case .warnUser:
            return "Warn user about potential scam"
        case .blockUser:
            return "Block user immediately"
        }
    }
}
