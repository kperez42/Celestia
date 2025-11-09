//
//  ConversationStarters.swift
//  Celestia
//
//  Smart icebreaker suggestions based on shared interests
//

import Foundation

class ConversationStarters {
    static let shared = ConversationStarters()

    private init() {}

    // MARK: - Generate Starters

    /// Generate 3-4 conversation starters based on match context
    func generateStarters(currentUser: User, otherUser: User) -> [ConversationStarter] {
        var starters: [ConversationStarter] = []

        // 1. Shared interests (highest priority)
        if let sharedInterestStarter = generateSharedInterestStarter(currentUser: currentUser, otherUser: otherUser) {
            starters.append(sharedInterestStarter)
        }

        // 2. Location-based starter
        if let locationStarter = generateLocationStarter(currentUser: currentUser, otherUser: otherUser) {
            starters.append(locationStarter)
        }

        // 3. Bio-based starter
        if let bioStarter = generateBioStarter(otherUser: otherUser) {
            starters.append(bioStarter)
        }

        // 4. Add generic starters if we need more
        let genericStarters = getGenericStarters()
        let remainingCount = 4 - starters.count
        if remainingCount > 0 {
            starters.append(contentsOf: genericStarters.prefix(remainingCount))
        }

        return Array(starters.prefix(4))
    }

    // MARK: - Shared Interest Starters

    private func generateSharedInterestStarter(currentUser: User, otherUser: User) -> ConversationStarter? {
        let currentInterests = Set(currentUser.interests)
        let otherInterests = Set(otherUser.interests)
        let sharedInterests = currentInterests.intersection(otherInterests)

        guard let randomInterest = sharedInterests.randomElement() else {
            return nil
        }

        let templates = interestTemplates[randomInterest.lowercased()] ?? defaultInterestTemplates
        guard let template = templates.randomElement() else {
            return ConversationStarter(
                icon: "star.fill",
                text: "I see we both love \(randomInterest)! What got you into it?",
                category: .sharedInterest
            )
        }

        return ConversationStarter(
            icon: "star.fill",
            text: template.replacingOccurrences(of: "{interest}", with: randomInterest),
            category: .sharedInterest
        )
    }

    // MARK: - Location Starters

    private func generateLocationStarter(currentUser: User, otherUser: User) -> ConversationStarter? {
        // Same city
        if currentUser.location == otherUser.location {
            return ConversationStarter(
                icon: "mappin.circle.fill",
                text: "Hey! I'm in \(otherUser.location) too! What's your favorite spot here?",
                category: .location
            )
        }

        // Different cities in same area (could be enhanced)
        return ConversationStarter(
            icon: "mappin.circle.fill",
            text: "I see you're in \(otherUser.location)! I've always wanted to visit. Any recommendations?",
            category: .location
        )
    }

    // MARK: - Bio Starters

    private func generateBioStarter(otherUser: User) -> ConversationStarter? {
        let bio = otherUser.bio.lowercased()

        // Check for travel mentions
        if bio.contains("travel") || bio.contains("adventure") || bio.contains("explore") {
            return ConversationStarter(
                icon: "airplane",
                text: "I noticed you love to travel! What's been your favorite trip?",
                category: .bio
            )
        }

        // Check for food mentions
        if bio.contains("food") || bio.contains("cooking") || bio.contains("coffee") {
            return ConversationStarter(
                icon: "fork.knife",
                text: "Fellow foodie here! What's your go-to comfort food?",
                category: .bio
            )
        }

        // Check for music mentions
        if bio.contains("music") || bio.contains("concert") || bio.contains("festival") {
            return ConversationStarter(
                icon: "music.note",
                text: "I see you're into music! What's been on repeat for you lately?",
                category: .bio
            )
        }

        return nil
    }

    // MARK: - Generic Starters

    private func getGenericStarters() -> [ConversationStarter] {
        return [
            ConversationStarter(
                icon: "sparkles",
                text: "Hey! Your profile caught my eye. What's been the highlight of your week?",
                category: .generic
            ),
            ConversationStarter(
                icon: "sun.max.fill",
                text: "Hi there! If you could be doing anything right now, what would it be?",
                category: .generic
            ),
            ConversationStarter(
                icon: "hand.wave.fill",
                text: "Hey! I had to say hi 😊 What brings you to Celestia?",
                category: .generic
            ),
            ConversationStarter(
                icon: "heart.fill",
                text: "Your vibe seems awesome! Quick question: coffee or tea?",
                category: .generic
            )
        ]
    }

    // MARK: - Interest Templates

    private let defaultInterestTemplates = [
        "I see we both love {interest}! What got you into it?",
        "{interest} is awesome! How long have you been into it?",
        "Another {interest} fan! What's your favorite thing about it?"
    ]

    private let interestTemplates: [String: [String]] = [
        "travel": [
            "I see you love travel! What's your dream destination?",
            "Fellow traveler here! Where was your last trip?",
            "Travel is the best! Beach vacation or mountain adventure?"
        ],
        "hiking": [
            "I love hiking too! What's your favorite trail?",
            "Fellow hiker! What's the best view you've ever seen?",
            "Hiking is amazing! Sunrise or sunset hikes?"
        ],
        "photography": [
            "I see you're into photography! What do you love to shoot?",
            "Fellow photographer! Film or digital?",
            "Photography is awesome! What's your dream camera?"
        ],
        "cooking": [
            "I love cooking too! What's your signature dish?",
            "Fellow chef here! Sweet or savory?",
            "Cooking is the best! What cuisine do you love making?"
        ],
        "fitness": [
            "I see you're into fitness! Gym or outdoor workouts?",
            "Fellow fitness enthusiast! What's your favorite workout?",
            "Fitness gang! Morning or evening workouts?"
        ],
        "reading": [
            "I love reading too! What book are you into right now?",
            "Fellow bookworm! Fiction or non-fiction?",
            "Reading is the best! What's a book that changed your life?"
        ],
        "music": [
            "I see you love music! What's been on repeat lately?",
            "Fellow music lover! What's your go-to genre?",
            "Music is life! Concerts or festivals?"
        ],
        "yoga": [
            "I love yoga too! Morning or evening practice?",
            "Fellow yogi! What's your favorite pose?",
            "Yoga is amazing! Hot yoga or traditional?"
        ],
        "dogs": [
            "I see you're a dog person! Do you have one?",
            "Fellow dog lover! What's your dream breed?",
            "Dogs are the best! Big dogs or small dogs?"
        ],
        "cats": [
            "I see you love cats! Do you have any?",
            "Fellow cat person! What's your favorite thing about cats?",
            "Cats are amazing! Indoor or outdoor cats?"
        ]
    ]
}

// MARK: - Models

struct ConversationStarter: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
    let category: StarterCategory

    enum StarterCategory {
        case sharedInterest
        case location
        case bio
        case generic
    }
}
