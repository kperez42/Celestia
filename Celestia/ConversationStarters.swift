//
//  ConversationStarters.swift
//  Celestia
//
//  Service for generating smart conversation starters
//

import Foundation

// MARK: - Conversation Starter Model

struct ConversationStarter: Identifiable {
    let id = UUID()
    let text: String
    let icon: String
    let category: StarterCategory

    enum StarterCategory {
        case sharedInterest
        case location
        case bio
        case generic
    }
}

// MARK: - Conversation Starters Service

class ConversationStarters {
    static let shared = ConversationStarters()

    private init() {}

    func generateStarters(currentUser: User, otherUser: User) -> [ConversationStarter] {
        var starters: [ConversationStarter] = []

        // Shared interests
        let sharedInterests = Set(currentUser.interests).intersection(Set(otherUser.interests))
        if let interest = sharedInterests.first {
            starters.append(ConversationStarter(
                text: "I see you're into \(interest) too! What got you started?",
                icon: "star.fill",
                category: .sharedInterest
            ))
        }

        // Location-based
        if !otherUser.location.isEmpty {
            starters.append(ConversationStarter(
                text: "How do you like living in \(otherUser.location)?",
                icon: "mappin.circle.fill",
                category: .location
            ))
        }

        // Bio-based (if bio has keywords)
        if !otherUser.bio.isEmpty {
            if otherUser.bio.lowercased().contains("travel") {
                starters.append(ConversationStarter(
                    text: "I saw you mentioned travel! What's your favorite destination?",
                    icon: "airplane",
                    category: .bio
                ))
            } else if otherUser.bio.lowercased().contains("food") || otherUser.bio.lowercased().contains("coffee") {
                starters.append(ConversationStarter(
                    text: "Fellow foodie here! Any favorite spots you'd recommend?",
                    icon: "fork.knife",
                    category: .bio
                ))
            }
        }

        // Generic starters
        let genericStarters = [
            ConversationStarter(
                text: "What's something you're passionate about?",
                icon: "heart.fill",
                category: .generic
            ),
            ConversationStarter(
                text: "If you could travel anywhere right now, where would you go?",
                icon: "airplane.departure",
                category: .generic
            ),
            ConversationStarter(
                text: "What's your idea of a perfect weekend?",
                icon: "sun.max.fill",
                category: .generic
            ),
            ConversationStarter(
                text: "What's something you've always wanted to try?",
                icon: "sparkles",
                category: .generic
            )
        ]

        // Add generic starters to fill up to 5 total
        let remainingCount = max(0, 5 - starters.count)
        starters.append(contentsOf: genericStarters.prefix(remainingCount))

        return Array(starters.prefix(5))
    }
}
