//
//  ProfilePrompt.swift
//  Celestia
//
//  Personality prompts for engaging profiles
//

import Foundation

struct ProfilePrompt: Codable, Identifiable, Equatable {
    var id: String
    var question: String
    var answer: String

    init(id: String = UUID().uuidString, question: String, answer: String) {
        self.id = id
        self.question = question
        self.answer = answer
    }

    func toDictionary() -> [String: String] {
        return [
            "id": id,
            "question": question,
            "answer": answer
        ]
    }
}

// MARK: - Available Prompts

struct PromptLibrary {
    static let allPrompts: [String] = [
        // Lifestyle & Personality
        "My ideal Sunday is...",
        "The key to my heart is...",
        "Don't judge me, but I love...",
        "I'm the type of person who...",
        "My perfect day includes...",
        "You'll know I like you if...",
        "My greatest passion is...",
        "I find it attractive when...",

        // Relationship & Dating
        "I'm looking for someone who...",
        "The way to win me over is...",
        "My love language is...",
        "A relationship deal-breaker for me is...",
        "I know I'm dating the right person when...",
        "In a relationship, I value...",
        "My idea of a perfect date is...",

        // Quirks & Fun
        "An unpopular opinion I have is...",
        "My most controversial take is...",
        "I'm weirdly attracted to...",
        "A random fact I love is...",
        "My guilty pleasure is...",
        "I'm convinced that...",
        "The dorkiest thing about me is...",

        // Life Goals & Dreams
        "My biggest goal this year is...",
        "In 5 years, I'll be...",
        "A bucket list item of mine is...",
        "I won't shut up about...",
        "The best thing I've done recently is...",
        "I'm currently learning...",

        // Favorites & Preferences
        "My go-to karaoke song is...",
        "The best way to start a conversation with me is...",
        "My signature dish is...",
        "The movie I can watch on repeat is...",
        "My favorite way to spend a weekend is...",
        "The song that never gets old is...",

        // Deep Questions
        "What makes me feel alive is...",
        "The most meaningful thing to me is...",
        "I believe strongly that...",
        "My biggest motivation is...",
        "What I'm most grateful for is...",

        // Travel & Adventure
        "My dream vacation is...",
        "The best trip I've ever taken was...",
        "A place I've always wanted to visit is...",
        "My travel style is...",

        // Social & Friends
        "Ask me about...",
        "My friends would describe me as...",
        "The best advice I've received is...",
        "Something I'll teach you is...",
        "Something you should know about me is...",

        // Humor & Wit
        "Two truths and a lie...",
        "Let's debate...",
        "Change my mind about...",
        "I'll fall for you if...",
        "Together we could...",
        "We'll get along if...",

        // Unique & Creative
        "If I could have any superpower, it would be...",
        "My zombie apocalypse survival plan is...",
        "The hill I'll die on is...",
        "My hot take is...",
        "I'm still not over...",
        "The award I deserve is..."
    ]

    static let categories: [String: [String]] = [
        "Lifestyle": [
            "My ideal Sunday is...",
            "My perfect day includes...",
            "My greatest passion is...",
            "My favorite way to spend a weekend is..."
        ],
        "Dating": [
            "I'm looking for someone who...",
            "The way to win me over is...",
            "My love language is...",
            "My idea of a perfect date is..."
        ],
        "Personality": [
            "I'm the type of person who...",
            "You'll know I like you if...",
            "My friends would describe me as...",
            "Something you should know about me is..."
        ],
        "Fun & Quirky": [
            "Don't judge me, but I love...",
            "My guilty pleasure is...",
            "The dorkiest thing about me is...",
            "Two truths and a lie..."
        ],
        "Goals & Dreams": [
            "My biggest goal this year is...",
            "In 5 years, I'll be...",
            "A bucket list item of mine is...",
            "I'm currently learning..."
        ],
        "Hot Takes": [
            "An unpopular opinion I have is...",
            "My most controversial take is...",
            "The hill I'll die on is...",
            "Change my mind about..."
        ]
    ]

    static func randomPrompts(count: Int = 5) -> [String] {
        return Array(allPrompts.shuffled().prefix(count))
    }

    static func suggestedPrompts() -> [String] {
        // Return a curated mix of prompts
        return [
            "My ideal Sunday is...",
            "I'm looking for someone who...",
            "Don't judge me, but I love...",
            "My perfect day includes...",
            "The key to my heart is..."
        ]
    }
}
