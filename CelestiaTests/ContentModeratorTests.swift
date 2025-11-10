//
//  ContentModeratorTests.swift
//  CelestiaTests
//
//  Comprehensive unit tests for ContentModerator
//

import Testing
@testable import Celestia
import Foundation

@Suite("ContentModerator Tests")
struct ContentModeratorTests {

    let moderator = ContentModerator.shared

    // MARK: - Profanity Detection Tests

    @Test("Detects basic profanity")
    func testBasicProfanityDetection() async throws {
        let profaneTexts = [
            "This is shit",
            "What the fuck",
            "You're a bitch"
        ]

        for text in profaneTexts {
            let containsProfanity = moderator.containsProfanity(text)
            #expect(containsProfanity, "Should detect profanity in: \(text)")
        }
    }

    @Test("Allows clean content")
    func testCleanContentAllowed() async throws {
        let cleanTexts = [
            "Hello, how are you?",
            "Nice to meet you!",
            "What a beautiful day",
            "I love this app"
        ]

        for text in cleanTexts {
            let containsProfanity = moderator.containsProfanity(text)
            #expect(!containsProfanity, "Should allow clean text: \(text)")
        }
    }

    @Test("Detects profanity with punctuation")
    func testProfanityWithPunctuation() async throws {
        let texts = [
            "What the shit!",
            "Damn.",
            "Fuck!!!"
        ]

        for text in texts {
            let containsProfanity = moderator.containsProfanity(text)
            #expect(containsProfanity, "Should detect profanity with punctuation: \(text)")
        }
    }

    @Test("Detects obfuscated profanity")
    func testObfuscatedProfanity() async throws {
        let obfuscatedTexts = [
            "sh1t",      // 1 -> i
            "fu€k",      // € -> e
            "d@mn",      // @ -> a
            "b1tch",     // 1 -> i
            "a55"        // 5 -> s
        ]

        for text in obfuscatedTexts {
            let containsProfanity = moderator.containsProfanity(text)
            // Note: Some obfuscations may not be caught depending on implementation
            #expect(containsProfanity, "Should detect obfuscated profanity: \(text)")
        }
    }

    @Test("Case insensitive profanity detection")
    func testCaseInsensitiveProfanity() async throws {
        let texts = [
            "DAMN",
            "DaMn",
            "dAmN",
            "damn"
        ]

        for text in texts {
            let containsProfanity = moderator.containsProfanity(text)
            #expect(containsProfanity, "Should detect profanity regardless of case: \(text)")
        }
    }

    // MARK: - Profanity Filtering Tests

    @Test("Filters profanity with asterisks")
    func testProfanityFiltering() async throws {
        let filtered = moderator.filterProfanity("This is shit")

        #expect(filtered.contains("*"), "Should contain asterisks")
        #expect(!filtered.contains("shit"), "Should not contain profanity")
    }

    @Test("Filtering preserves clean words")
    func testFilteringPreservesCleanWords() async throws {
        let text = "This is a nice day"
        let filtered = moderator.filterProfanity(text)

        #expect(filtered == text, "Clean text should remain unchanged")
    }

    @Test("Filters multiple profane words")
    func testMultipleProfanityFiltering() async throws {
        let text = "damn this shit"
        let filtered = moderator.filterProfanity(text)

        #expect(filtered.contains("*"), "Should filter multiple words")
        #expect(!filtered.lowercased().contains("damn"), "Should filter first word")
        #expect(!filtered.lowercased().contains("shit"), "Should filter second word")
    }

    // MARK: - Spam Detection Tests

    @Test("Detects URLs as spam")
    func testURLSpamDetection() async throws {
        let spamTexts = [
            "Check out http://example.com",
            "Visit https://spam.com",
            "Go to www.website.com",
            "Link: example.net"
        ]

        for text in spamTexts {
            let isSpam = moderator.containsSpam(text)
            #expect(isSpam, "Should detect URL spam: \(text)")
        }
    }

    @Test("Detects social media handles as spam")
    func testSocialMediaSpam() async throws {
        let spamTexts = [
            "Add me on snapchat",
            "Follow me on instagram",
            "Message me on telegram",
            "Hit me up on whatsapp"
        ]

        for text in spamTexts {
            let isSpam = moderator.containsSpam(text)
            #expect(isSpam, "Should detect social media spam: \(text)")
        }
    }

    @Test("Detects money-related spam")
    func testMoneySpam() async throws {
        let spamTexts = [
            "Invest in bitcoin now",
            "Easy money with crypto",
            "Send via cash app",
            "$$$$ make money fast"
        ]

        for text in spamTexts {
            let isSpam = moderator.containsSpam(text)
            #expect(isSpam, "Should detect money spam: \(text)")
        }
    }

    @Test("Detects excessive emojis as spam")
    func testExcessiveEmojiSpam() async throws {
        let manyEmojis = String(repeating: "😀", count: 15)

        let isSpam = moderator.containsSpam(manyEmojis)
        #expect(isSpam, "Should detect excessive emojis as spam")
    }

    @Test("Allows reasonable emoji usage")
    func testReasonableEmojiUsage() async throws {
        let normalText = "Hi! 😊 How are you? 👋"

        let isSpam = moderator.containsSpam(normalText)
        #expect(!isSpam, "Should allow normal emoji usage")
    }

    // MARK: - Personal Info Detection Tests

    @Test("Detects phone numbers")
    func testPhoneNumberDetection() async throws {
        let textsWithPhones = [
            "Call me at 555-123-4567",
            "My number is 555.123.4567",
            "Text 5551234567"
        ]

        for text in textsWithPhones {
            let hasPersonalInfo = moderator.containsPersonalInfo(text)
            #expect(hasPersonalInfo, "Should detect phone number: \(text)")
        }
    }

    @Test("Detects email addresses")
    func testEmailDetection() async throws {
        let textsWithEmails = [
            "Email me at user@example.com",
            "My address: test.user@domain.co.uk",
            "Contact: name+tag@site.com"
        ]

        for text in textsWithEmails {
            let hasPersonalInfo = moderator.containsPersonalInfo(text)
            #expect(hasPersonalInfo, "Should detect email: \(text)")
        }
    }

    @Test("Detects physical addresses")
    func testAddressDetection() async throws {
        let textsWithAddresses = [
            "I live at 123 Main Street",
            "Meet me at 456 Oak Avenue",
            "My address is 789 Park Road"
        ]

        for text in textsWithAddresses {
            let hasPersonalInfo = moderator.containsPersonalInfo(text)
            #expect(hasPersonalInfo, "Should detect address: \(text)")
        }
    }

    @Test("Allows safe location mentions")
    func testSafeLocationMentions() async throws {
        let safeTexts = [
            "I'm from New York",
            "I live in California",
            "Located in downtown"
        ]

        for text in safeTexts {
            let hasPersonalInfo = moderator.containsPersonalInfo(text)
            #expect(!hasPersonalInfo, "Should allow general location: \(text)")
        }
    }

    // MARK: - Excessive Caps Detection Tests

    @Test("Detects excessive caps")
    func testExcessiveCapsDetection() async throws {
        let capsTexts = [
            "HELLO THERE HOW ARE YOU DOING TODAY",
            "THIS IS ALL CAPS",
            "SHOUTING AT YOU"
        ]

        for text in capsTexts {
            let isAppropriate = moderator.isAppropriate(text)
            #expect(!isAppropriate, "Should flag excessive caps: \(text)")
        }
    }

    @Test("Allows normal capitalization")
    func testNormalCapitalization() async throws {
        let normalTexts = [
            "Hello there",
            "This is IMPORTANT",
            "I LOVE pizza",
            "ALL CAPS word"
        ]

        for text in normalTexts {
            let isAppropriate = moderator.isAppropriate(text)
            #expect(isAppropriate, "Should allow normal caps: \(text)")
        }
    }

    @Test("Short all-caps text is allowed")
    func testShortCapsAllowed() async throws {
        let shortCaps = [
            "OK",
            "YES",
            "LOL",
            "OMG"
        ]

        for text in shortCaps {
            let isAppropriate = moderator.isAppropriate(text)
            #expect(isAppropriate, "Should allow short caps: \(text)")
        }
    }

    // MARK: - Repetition Detection Tests

    @Test("Detects excessive character repetition")
    func testExcessiveRepetition() async throws {
        let repetitiveTexts = [
            "hiiiiiiiii",
            "hahahahahaha",
            "noooooooooo",
            "yesssssssss"
        ]

        for text in repetitiveTexts {
            let isAppropriate = moderator.isAppropriate(text)
            #expect(!isAppropriate, "Should flag excessive repetition: \(text)")
        }
    }

    @Test("Allows normal repetition")
    func testNormalRepetition() async throws {
        let normalTexts = [
            "Hello",
            "Good",
            "Book",
            "Hooray"
        ]

        for text in normalTexts {
            let isAppropriate = moderator.isAppropriate(text)
            #expect(isAppropriate, "Should allow normal text: \(text)")
        }
    }

    // MARK: - Content Score Tests

    @Test("Clean content gets perfect score")
    func testCleanContentScore() async throws {
        let cleanText = "Hello, nice to meet you!"
        let score = moderator.contentScore(cleanText)

        #expect(score == 100, "Clean content should score 100")
    }

    @Test("Profanity reduces score")
    func testProfanityReducesScore() async throws {
        let profaneText = "This is shit"
        let score = moderator.contentScore(profaneText)

        #expect(score < 100, "Profanity should reduce score")
        #expect(score >= 0, "Score should not be negative")
    }

    @Test("Multiple violations compound score reduction")
    func testMultipleViolations() async throws {
        let badText = "FUCK THIS SHIT http://spam.com"
        let score = moderator.contentScore(badText)

        #expect(score < 50, "Multiple violations should significantly reduce score")
    }

    @Test("Score never goes below zero")
    func testScoreFloor() async throws {
        let terribleText = "FUCK SHIT DAMN http://spam.com call 555-123-4567"
        let score = moderator.contentScore(terribleText)

        #expect(score >= 0, "Score should never be negative")
    }

    // MARK: - Violation Reporting Tests

    @Test("Get violations for inappropriate content")
    func testViolationReporting() async throws {
        let inappropriateText = "FUCK THIS http://spam.com"
        let violations = moderator.getViolations(inappropriateText)

        #expect(!violations.isEmpty, "Should report violations")
        #expect(violations.count > 0, "Should have at least one violation")
    }

    @Test("Clean content has no violations")
    func testNoViolationsForClean() async throws {
        let cleanText = "Hello, how are you?"
        let violations = moderator.getViolations(cleanText)

        #expect(violations.isEmpty, "Clean content should have no violations")
    }

    @Test("Violations are descriptive")
    func testViolationDescriptions() async throws {
        let profaneText = "This is shit"
        let violations = moderator.getViolations(profaneText)

        #expect(!violations.isEmpty)
        for violation in violations {
            #expect(!violation.isEmpty, "Violation description should not be empty")
        }
    }

    // MARK: - Integration Tests

    @Test("Overall appropriateness check")
    func testOverallAppropriatenessCheck() async throws {
        let testCases: [(text: String, shouldBeAppropriate: Bool)] = [
            ("Hello, nice to meet you!", true),
            ("This is shit", false),
            ("Check out http://spam.com", false),
            ("Call me at 555-123-4567", false),
            ("SHOUTING ALL THE TIME", false),
            ("hiiiiiiiii there", false),
            ("I love this app", true),
            ("Great to connect with you", true)
        ]

        for (text, shouldBeAppropriate) in testCases {
            let isAppropriate = moderator.isAppropriate(text)
            #expect(isAppropriate == shouldBeAppropriate,
                   "Text '\(text)' appropriateness should be \(shouldBeAppropriate)")
        }
    }

    // MARK: - Edge Cases

    @Test("Empty string is appropriate")
    func testEmptyString() async throws {
        let emptyText = ""
        let isAppropriate = moderator.isAppropriate(emptyText)

        #expect(isAppropriate, "Empty string should be considered appropriate")
    }

    @Test("Whitespace only is appropriate")
    func testWhitespaceOnly() async throws {
        let whitespace = "   \n   "
        let isAppropriate = moderator.isAppropriate(whitespace)

        #expect(isAppropriate, "Whitespace should be appropriate")
    }

    @Test("Unicode and emoji handling")
    func testUnicodeHandling() async throws {
        let unicodeText = "Hello 👋 こんにちは مرحبا"
        let isAppropriate = moderator.isAppropriate(unicodeText)

        #expect(isAppropriate, "Unicode should be handled properly")
    }

    @Test("Very long text performance")
    func testLongTextPerformance() async throws {
        let longText = String(repeating: "This is a test sentence. ", count: 100)
        let score = moderator.contentScore(longText)

        #expect(score >= 0, "Should handle long text")
        #expect(score <= 100, "Score should be in valid range")
    }
}
