//
//  ContentModerator.swift
//  Celestia
//
//  Content moderation service to filter inappropriate content
//

import Foundation

// MARK: - Content Moderation Protocol

protocol ContentModerating {
    func isAppropriate(_ text: String) -> Bool
    func containsProfanity(_ text: String) -> Bool
    func filterProfanity(_ text: String) -> String
    func containsSpam(_ text: String) -> Bool
    func containsPersonalInfo(_ text: String) -> Bool
}

// MARK: - Content Moderator Implementation

class ContentModerator: ContentModerating {
    static let shared = ContentModerator()

    private init() {}

    // MARK: - Profanity List

    private let profanityList: Set<String> = [
        // Common profanity (lowercase)
        "damn", "hell", "crap", "shit", "fuck", "bitch", "ass", "bastard",
        "dick", "cock", "pussy", "slut", "whore", "fag", "nigger", "cunt",
        "asshole", "bullshit", "motherfucker", "fucker", "dumbass", "jackass",
        "prick", "douche", "twat", "wanker", "tosser", "bollocks"
    ]

    // MARK: - Sexual/Inappropriate Name Terms (for username/name validation)

    private let inappropriateNameTerms: Set<String> = [
        // Sexual terms
        "sexy", "sexyy", "sexxy", "sexii", "horny", "hornyy", "hornii",
        "nude", "nudes", "naked", "xxx", "porn", "porno", "pornstar",
        "onlyfans", "escort", "hooker", "stripper", "camgirl", "camboy",
        "hotgirl", "hotboy", "hotbabe", "sexygirl", "sexyboy", "sexybabe",
        "bigdick", "bigcock", "bigboobs", "bigtits", "bigass", "thicc",
        "dtf", "hookup", "fuckbuddy", "fwb", "nsa", "ons",
        "blowjob", "handjob", "deepthroat", "anal", "oral", "cumshot",
        "milf", "dilf", "gilf", "daddy", "mommy", "sugar",
        "booty", "boobies", "titties", "nipples", "vagina", "penis",
        "erotic", "kinky", "fetish", "bdsm", "bondage", "dominatrix",
        "mistress", "master", "slave", "submissive", "dominant",
        // Scam-related
        "bitcoin", "crypto", "investment", "forex", "trading",
        "rich", "wealthy", "millionaire", "billionaire",
        "cashapp", "venmo", "paypal", "zelle", "moneygram",
        // Fake identity signals
        "realme", "notfake", "notabot", "realaccount", "verified100",
        "model", "supermodel", "influencer", "celebrity",
        // Drugs
        "weed", "marijuana", "cocaine", "heroin", "meth", "drugs",
        "dealer", "plug", "420", "blaze"
    ]

    // MARK: - Spam Patterns

    private let spamPatterns: [String] = [
        // URLs and links
        "http://", "https://", "www.", ".com", ".net", ".org",
        // Social media handles
        "@", "snapchat", "instagram", "telegram", "whatsapp",
        // Money-related spam
        "bitcoin", "crypto", "investment", "money transfer",
        "$$$", "cash app", "venmo", "paypal",
        // Common spam phrases
        "click here", "buy now", "limited time", "act now"
    ]

    // MARK: - Personal Info Patterns

    private let phoneNumberPattern = #"\b\d{3}[-.]?\d{3}[-.]?\d{4}\b"#
    private let emailPattern = #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"#
    private let addressPattern = #"\b\d+\s+[A-Za-z\s]+(?:Street|St|Avenue|Ave|Road|Rd|Drive|Dr|Lane|Ln|Boulevard|Blvd)\b"#

    // MARK: - Main Moderation Methods

    func isAppropriate(_ text: String) -> Bool {
        let lowerText = text.lowercased()

        // Check for profanity
        if containsProfanity(lowerText) {
            return false
        }

        // Check for spam
        if containsSpam(lowerText) {
            return false
        }

        // Check for personal information
        if containsPersonalInfo(text) {
            return false
        }

        // Check for excessive caps (shouting)
        if isExcessiveCaps(text) {
            return false
        }

        // Check for repetitive characters
        if hasExcessiveRepetition(text) {
            return false
        }

        return true
    }

    func containsProfanity(_ text: String) -> Bool {
        let lowerText = text.lowercased()
        let words = lowerText.components(separatedBy: .whitespacesAndNewlines)

        for word in words {
            let cleanedWord = word.components(separatedBy: .punctuationCharacters).joined()
            if profanityList.contains(cleanedWord) {
                return true
            }

            // Check for l33t speak variations (e.g., "sh1t", "fu€k")
            if containsObfuscatedProfanity(cleanedWord) {
                return true
            }
        }

        return false
    }

    func filterProfanity(_ text: String) -> String {
        var filtered = text
        let words = text.components(separatedBy: " ")

        for word in words {
            let cleanedWord = word.lowercased()
                .components(separatedBy: .punctuationCharacters)
                .joined()

            if profanityList.contains(cleanedWord) {
                let replacement = String(repeating: "*", count: word.count)
                filtered = filtered.replacingOccurrences(of: word, with: replacement, options: .caseInsensitive)
            }
        }

        return filtered
    }

    func containsSpam(_ text: String) -> Bool {
        let lowerText = text.lowercased()

        // Check for spam patterns
        for pattern in spamPatterns {
            if lowerText.contains(pattern) {
                return true
            }
        }

        // Check for excessive emojis (likely spam)
        let emojiCount = text.unicodeScalars.filter { $0.properties.isEmoji }.count
        if emojiCount > 10 {
            return true
        }

        return false
    }

    func containsPersonalInfo(_ text: String) -> Bool {
        // Check for phone numbers
        if text.range(of: phoneNumberPattern, options: .regularExpression) != nil {
            return true
        }

        // Check for email addresses
        if text.range(of: emailPattern, options: .regularExpression) != nil {
            return true
        }

        // Check for physical addresses
        if text.range(of: addressPattern, options: .regularExpression) != nil {
            return true
        }

        return false
    }

    // MARK: - Helper Methods

    private func containsObfuscatedProfanity(_ word: String) -> Bool {
        // Replace common obfuscation characters
        let normalized = word
            .replacingOccurrences(of: "0", with: "o")
            .replacingOccurrences(of: "1", with: "i")
            .replacingOccurrences(of: "3", with: "e")
            .replacingOccurrences(of: "4", with: "a")
            .replacingOccurrences(of: "5", with: "s")
            .replacingOccurrences(of: "7", with: "t")
            .replacingOccurrences(of: "$", with: "s")
            .replacingOccurrences(of: "@", with: "a")
            .replacingOccurrences(of: "€", with: "e")

        return profanityList.contains(normalized)
    }

    private func isExcessiveCaps(_ text: String) -> Bool {
        let letters = text.filter { $0.isLetter }
        guard !letters.isEmpty else { return false }

        let uppercaseCount = letters.filter { $0.isUppercase }.count
        let capsPercentage = Double(uppercaseCount) / Double(letters.count)

        // More than 70% caps and at least 10 characters
        return capsPercentage > 0.7 && letters.count >= 10
    }

    private func hasExcessiveRepetition(_ text: String) -> Bool {
        // Check for repeated characters (e.g., "hiiiiiii", "hahahahahaha")
        let pattern = #"(.)\1{4,}"# // 5 or more of the same character
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Name Validation

    /// Validates a user's display name for inappropriate content
    /// Returns (isValid, reason) tuple
    func validateName(_ name: String) -> (isValid: Bool, reason: String?) {
        let lowerName = name.lowercased().replacingOccurrences(of: " ", with: "")

        // Check for profanity in name
        if containsProfanity(name) {
            return (false, "Name contains inappropriate language")
        }

        // Check for inappropriate terms (sexual, scam, etc.)
        for term in inappropriateNameTerms {
            if lowerName.contains(term) {
                return (false, "Name contains inappropriate content")
            }
        }

        // Check for profanity list in concatenated name
        for word in profanityList {
            if lowerName.contains(word) {
                return (false, "Name contains inappropriate language")
            }
        }

        // Check for numbers that look like phone/contact info
        let numbersOnly = name.filter { $0.isNumber }
        if numbersOnly.count >= 7 {
            return (false, "Name cannot contain phone numbers or long number sequences")
        }

        // Check for email patterns in name
        if name.contains("@") || name.contains(".com") || name.contains(".net") {
            return (false, "Name cannot contain email addresses or URLs")
        }

        // Check for excessive special characters
        let specialChars = name.filter { !$0.isLetter && !$0.isWhitespace }
        if Double(specialChars.count) / Double(max(name.count, 1)) > 0.3 {
            return (false, "Name contains too many special characters")
        }

        // Check name length
        if name.trimmingCharacters(in: .whitespaces).count < 2 {
            return (false, "Name must be at least 2 characters")
        }

        if name.count > 50 {
            return (false, "Name must be 50 characters or less")
        }

        return (true, nil)
    }

    /// Quick check if name is appropriate (convenience method)
    func isNameAppropriate(_ name: String) -> Bool {
        return validateName(name).isValid
    }

    // MARK: - Content Score

    /// Calculate content appropriateness score (0-100)
    func contentScore(_ text: String) -> Int {
        var score = 100

        // Deduct points for violations
        if containsProfanity(text) { score -= 40 }
        if containsSpam(text) { score -= 30 }
        if containsPersonalInfo(text) { score -= 20 }
        if isExcessiveCaps(text) { score -= 10 }
        if hasExcessiveRepetition(text) { score -= 10 }

        return max(0, score)
    }

    /// Get violation reasons
    func getViolations(_ text: String) -> [String] {
        var violations: [String] = []

        if containsProfanity(text) {
            violations.append("Contains inappropriate language")
        }
        if containsSpam(text) {
            violations.append("Contains spam or promotional content")
        }
        if containsPersonalInfo(text) {
            violations.append("Contains personal contact information")
        }
        if isExcessiveCaps(text) {
            violations.append("Excessive use of capital letters")
        }
        if hasExcessiveRepetition(text) {
            violations.append("Excessive character repetition")
        }

        return violations
    }
}
