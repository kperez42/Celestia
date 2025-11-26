//
//  TestData.swift
//  Celestia
//
//  Created by Claude
//  Test data for previews and development
//

import Foundation
import FirebaseFirestore

#if DEBUG

struct TestData {

    // MARK: - Test Users for Discover Page

    static let discoverUsers: [User] = [
        User(
            id: "test_user_1",
            email: "sarah.johnson@test.com",
            fullName: "Sarah Johnson",
            age: 24,
            gender: "Female",
            lookingFor: "Male",
            bio: "Adventure seeker 🏔️ | Coffee enthusiast ☕ | Love hiking, photography, and spontaneous road trips. Always up for trying new restaurants!",
            location: "San Francisco",
            country: "USA",
            latitude: 37.7749,
            longitude: -122.4194,
            languages: ["English", "Spanish"],
            interests: ["Hiking", "Photography", "Coffee", "Travel", "Food"],
            photos: [
                "https://picsum.photos/seed/sarah1/400/500",
                "https://picsum.photos/seed/sarah2/400/500",
                "https://picsum.photos/seed/sarah3/400/500"
            ],
            profileImageURL: "https://picsum.photos/seed/sarah1/400/500",
            isPremium: false,
            isVerified: true
        ),

        User(
            id: "test_user_2",
            email: "mike.chen@test.com",
            fullName: "Mike Chen",
            age: 28,
            gender: "Male",
            lookingFor: "Female",
            bio: "Tech entrepreneur 💻 | Fitness junkie 💪 | Building the future one line of code at a time. Love cooking, gaming, and good conversations.",
            location: "San Francisco",
            country: "USA",
            latitude: 37.7849,
            longitude: -122.4094,
            languages: ["English", "Mandarin"],
            interests: ["Technology", "Fitness", "Cooking", "Gaming", "Startups"],
            photos: [
                "https://picsum.photos/seed/mike1/400/500",
                "https://picsum.photos/seed/mike2/400/500",
                "https://picsum.photos/seed/mike3/400/500"
            ],
            profileImageURL: "https://picsum.photos/seed/mike1/400/500",
            isPremium: true,
            isVerified: true
        ),

        User(
            id: "test_user_3",
            email: "emma.wilson@test.com",
            fullName: "Emma Wilson",
            age: 26,
            gender: "Female",
            lookingFor: "Male",
            bio: "Artist & dreamer 🎨 | Yoga instructor 🧘‍♀️ | Plant mom 🌱 | Looking for someone who appreciates art, nature, and deep conversations under the stars.",
            location: "Oakland",
            country: "USA",
            latitude: 37.8044,
            longitude: -122.2712,
            languages: ["English", "French"],
            interests: ["Art", "Yoga", "Plants", "Meditation", "Music"],
            photos: [
                "https://picsum.photos/seed/emma1/400/500",
                "https://picsum.photos/seed/emma2/400/500",
                "https://picsum.photos/seed/emma3/400/500",
                "https://picsum.photos/seed/emma4/400/500"
            ],
            profileImageURL: "https://picsum.photos/seed/emma1/400/500",
            isPremium: false,
            isVerified: false
        ),

        User(
            id: "test_user_4",
            email: "alex.rodriguez@test.com",
            fullName: "Alex Rodriguez",
            age: 30,
            gender: "Male",
            lookingFor: "Female",
            bio: "Marketing director by day, DJ by night 🎧 | Music lover | Foodie | Looking for a partner in crime to explore the city's best hidden gems.",
            location: "Berkeley",
            country: "USA",
            latitude: 37.8715,
            longitude: -122.2730,
            languages: ["English", "Spanish", "Portuguese"],
            interests: ["Music", "DJing", "Food", "Travel", "Nightlife"],
            photos: [
                "https://picsum.photos/seed/alex1/400/500",
                "https://picsum.photos/seed/alex2/400/500",
                "https://picsum.photos/seed/alex3/400/500",
                "https://picsum.photos/seed/alex4/400/500",
                "https://picsum.photos/seed/alex5/400/500"
            ],
            profileImageURL: "https://picsum.photos/seed/alex1/400/500",
            isPremium: true,
            isVerified: true
        ),

        User(
            id: "test_user_5",
            email: "jessica.lee@test.com",
            fullName: "Jessica Lee",
            age: 27,
            gender: "Female",
            lookingFor: "Male",
            bio: "Doctor saving lives 👩‍⚕️ | Bookworm 📚 | Dog lover 🐕 | When I'm not at the hospital, you'll find me with a good book and my golden retriever.",
            location: "San Francisco",
            country: "USA",
            latitude: 37.7649,
            longitude: -122.4294,
            languages: ["English", "Korean"],
            interests: ["Medicine", "Reading", "Dogs", "Volunteering", "Netflix"],
            photos: [
                "https://picsum.photos/seed/jessica1/400/500",
                "https://picsum.photos/seed/jessica2/400/500",
                "https://picsum.photos/seed/jessica3/400/500",
                "https://picsum.photos/seed/jessica4/400/500",
                "https://picsum.photos/seed/jessica5/400/500",
                "https://picsum.photos/seed/jessica6/400/500"
            ],
            profileImageURL: "https://picsum.photos/seed/jessica1/400/500",
            isPremium: false,
            isVerified: true
        )
    ]

    // MARK: - Test Matches

    static let testMatches: [(user: User, match: Match)] = [
        (
            user: discoverUsers[0], // Sarah
            match: Match(
                id: "match_1",
                user1Id: "current_user",
                user2Id: "test_user_1",
                timestamp: Date().addingTimeInterval(-86400 * 2), // 2 days ago
                lastMessageTimestamp: Date().addingTimeInterval(-3600 * 2), // 2 hours ago
                lastMessage: "Sounds great! See you at 7pm 😊",
                lastMessageSenderId: "test_user_1", // Sarah sent last - RECEIVED
                unreadCount: ["current_user": 2],
                isActive: true
            )
        ),
        (
            user: discoverUsers[1], // Mike
            match: Match(
                id: "match_2",
                user1Id: "current_user",
                user2Id: "test_user_2",
                timestamp: Date().addingTimeInterval(-86400 * 5), // 5 days ago
                lastMessageTimestamp: Date().addingTimeInterval(-3600 * 8), // 8 hours ago
                lastMessage: "That startup idea sounds awesome! Let's grab coffee and discuss more.",
                lastMessageSenderId: "current_user", // You sent last - SENT
                unreadCount: [:],
                isActive: true
            )
        ),
        (
            user: discoverUsers[2], // Emma
            match: Match(
                id: "match_3",
                user1Id: "current_user",
                user2Id: "test_user_3",
                timestamp: Date().addingTimeInterval(-86400), // 1 day ago
                lastMessageTimestamp: Date().addingTimeInterval(-3600 * 5), // 5 hours ago
                lastMessage: "I'd love to see your artwork! Do you have an Instagram for your art?",
                lastMessageSenderId: "current_user", // You sent last - SENT
                unreadCount: [:],
                isActive: true
            )
        ),
        (
            user: discoverUsers[3], // Alex - New match, no messages yet
            match: Match(
                id: "match_4",
                user1Id: "current_user",
                user2Id: "test_user_4",
                timestamp: Date().addingTimeInterval(-3600), // 1 hour ago
                lastMessageTimestamp: nil,
                lastMessage: nil,
                lastMessageSenderId: nil, // New match - no messages - RECEIVED (needs action)
                unreadCount: [:],
                isActive: true
            )
        ),
        (
            user: discoverUsers[4], // Jessica
            match: Match(
                id: "match_5",
                user1Id: "current_user",
                user2Id: "test_user_5",
                timestamp: Date().addingTimeInterval(-86400 * 3), // 3 days ago
                lastMessageTimestamp: Date().addingTimeInterval(-60 * 10), // 10 mins ago
                lastMessage: "Hey! What's your dog's name? I have a golden too! 🐕",
                lastMessageSenderId: "test_user_5", // Jessica sent last - RECEIVED
                unreadCount: ["current_user": 1],
                isActive: true
            )
        )
    ]

    // MARK: - Test Messages

    static func messagesForMatch(_ matchId: String) -> [Message] {
        switch matchId {
        case "match_1": // Sarah
            return [
                Message(
                    id: "msg_1_1",
                    matchId: matchId,
                    senderId: "current_user",
                    receiverId: "test_user_1",
                    text: "Hey Sarah! Love your hiking photos! What's your favorite trail in the Bay Area?",
                    timestamp: Date().addingTimeInterval(-86400 * 2),
                    isRead: true
                ),
                Message(
                    id: "msg_1_2",
                    matchId: matchId,
                    senderId: "test_user_1",
                    receiverId: "current_user",
                    text: "Thanks! 😊 I'd say the Lands End trail is my favorite - the views are incredible!",
                    timestamp: Date().addingTimeInterval(-86400 * 2 + 600),
                    isRead: true
                ),
                Message(
                    id: "msg_1_3",
                    matchId: matchId,
                    senderId: "current_user",
                    receiverId: "test_user_1",
                    text: "Oh I love that one! Have you done the Dipsea Trail?",
                    timestamp: Date().addingTimeInterval(-86400 * 2 + 1200),
                    isRead: true
                ),
                Message(
                    id: "msg_1_4",
                    matchId: matchId,
                    senderId: "test_user_1",
                    receiverId: "current_user",
                    text: "Yes! That's on my list for this weekend actually. Want to join? ⛰️",
                    timestamp: Date().addingTimeInterval(-86400 * 2 + 1800),
                    isRead: true
                ),
                Message(
                    id: "msg_1_5",
                    matchId: matchId,
                    senderId: "current_user",
                    receiverId: "test_user_1",
                    text: "That would be awesome! What time were you thinking?",
                    timestamp: Date().addingTimeInterval(-3600 * 3),
                    isRead: true
                ),
                Message(
                    id: "msg_1_6",
                    matchId: matchId,
                    senderId: "test_user_1",
                    receiverId: "current_user",
                    text: "How about 7am on Saturday? Early start to beat the crowds!",
                    timestamp: Date().addingTimeInterval(-3600 * 2.5),
                    isRead: false
                ),
                Message(
                    id: "msg_1_7",
                    matchId: matchId,
                    senderId: "test_user_1",
                    receiverId: "current_user",
                    text: "Sounds great! See you at 7pm 😊",
                    timestamp: Date().addingTimeInterval(-3600 * 2),
                    isRead: false
                )
            ]

        case "match_2": // Mike
            return [
                Message(
                    id: "msg_2_1",
                    matchId: matchId,
                    senderId: "test_user_2",
                    receiverId: "current_user",
                    text: "Hey! Saw you're into tech too. What are you building?",
                    timestamp: Date().addingTimeInterval(-86400 * 5),
                    isRead: true
                ),
                Message(
                    id: "msg_2_2",
                    matchId: matchId,
                    senderId: "current_user",
                    receiverId: "test_user_2",
                    text: "Working on an AI-powered productivity app! What about you?",
                    timestamp: Date().addingTimeInterval(-86400 * 5 + 1800),
                    isRead: true
                ),
                Message(
                    id: "msg_2_3",
                    matchId: matchId,
                    senderId: "test_user_2",
                    receiverId: "current_user",
                    text: "Nice! I'm building a fintech platform for Gen Z. Been at it for 2 years now.",
                    timestamp: Date().addingTimeInterval(-86400 * 5 + 3600),
                    isRead: true
                ),
                Message(
                    id: "msg_2_4",
                    matchId: matchId,
                    senderId: "current_user",
                    receiverId: "test_user_2",
                    text: "That startup idea sounds awesome! Let's grab coffee and discuss more.",
                    timestamp: Date().addingTimeInterval(-3600 * 8),
                    isRead: true
                )
            ]

        case "match_3": // Emma
            return [
                Message(
                    id: "msg_3_1",
                    matchId: matchId,
                    senderId: "current_user",
                    receiverId: "test_user_3",
                    text: "Your bio caught my eye! What kind of art do you create?",
                    timestamp: Date().addingTimeInterval(-86400),
                    isRead: true
                ),
                Message(
                    id: "msg_3_2",
                    matchId: matchId,
                    senderId: "test_user_3",
                    receiverId: "current_user",
                    text: "Thank you! 🎨 I mostly do abstract paintings and mixed media. How about you, are you into art?",
                    timestamp: Date().addingTimeInterval(-86400 + 3600),
                    isRead: true
                ),
                Message(
                    id: "msg_3_3",
                    matchId: matchId,
                    senderId: "current_user",
                    receiverId: "test_user_3",
                    text: "I appreciate art but I'm definitely not talented enough to create it haha. More of an admirer!",
                    timestamp: Date().addingTimeInterval(-3600 * 6),
                    isRead: true
                ),
                Message(
                    id: "msg_3_4",
                    matchId: matchId,
                    senderId: "current_user",
                    receiverId: "test_user_3",
                    text: "I'd love to see your artwork! Do you have an Instagram for your art?",
                    timestamp: Date().addingTimeInterval(-3600 * 5),
                    isRead: true
                )
            ]

        case "match_4": // Alex
            return [
                Message(
                    id: "msg_4_1",
                    matchId: matchId,
                    senderId: "current_user",
                    receiverId: "test_user_4",
                    text: "Just matched! What kind of music do you spin? 🎵",
                    timestamp: Date().addingTimeInterval(-1800),
                    isRead: true
                )
            ]

        case "match_5": // Jessica
            return [
                Message(
                    id: "msg_5_1",
                    matchId: matchId,
                    senderId: "test_user_5",
                    receiverId: "current_user",
                    text: "Hi! Thanks for the match 😊",
                    timestamp: Date().addingTimeInterval(-86400 * 3),
                    isRead: true
                ),
                Message(
                    id: "msg_5_2",
                    matchId: matchId,
                    senderId: "current_user",
                    receiverId: "test_user_5",
                    text: "Hey Jessica! How's your week going?",
                    timestamp: Date().addingTimeInterval(-86400 * 3 + 7200),
                    isRead: true
                ),
                Message(
                    id: "msg_5_3",
                    matchId: matchId,
                    senderId: "test_user_5",
                    receiverId: "current_user",
                    text: "Busy as always at the hospital, but loving it! How about you?",
                    timestamp: Date().addingTimeInterval(-86400 * 2),
                    isRead: true
                ),
                Message(
                    id: "msg_5_4",
                    matchId: matchId,
                    senderId: "test_user_5",
                    receiverId: "current_user",
                    text: "Hey! What's your dog's name? I have a golden too! 🐕",
                    timestamp: Date().addingTimeInterval(-60 * 10),
                    isRead: false
                )
            ]

        default:
            return []
        }
    }

    // MARK: - Test Likes Data

    /// Users who liked the current user (for "Liked Me" tab)
    static let usersWhoLikedMe: [User] = [
        discoverUsers[0], // Sarah
        discoverUsers[2], // Emma
        discoverUsers[4]  // Jessica
    ]

    /// Users the current user liked (for "My Likes" tab)
    static let usersILiked: [User] = [
        discoverUsers[0], // Sarah - mutual
        discoverUsers[1], // Mike
        discoverUsers[2], // Emma - mutual
        discoverUsers[3], // Alex
        discoverUsers[4]  // Jessica - mutual
    ]

    /// Mutual likes (both liked each other) - for "Mutual Likes" tab
    static let mutualLikes: [User] = [
        discoverUsers[0], // Sarah
        discoverUsers[2], // Emma
        discoverUsers[4]  // Jessica
    ]

    // MARK: - Test Profile Viewers Data

    /// Users who viewed the current user's profile (for Profile Viewers page)
    static let profileViewers: [(user: User, timestamp: Date)] = [
        (discoverUsers[0], Date().addingTimeInterval(-3600)),        // Sarah - 1 hour ago
        (discoverUsers[1], Date().addingTimeInterval(-3600 * 3)),    // Mike - 3 hours ago
        (discoverUsers[2], Date().addingTimeInterval(-3600 * 8)),    // Emma - 8 hours ago
        (discoverUsers[3], Date().addingTimeInterval(-86400)),       // Alex - 1 day ago
        (discoverUsers[4], Date().addingTimeInterval(-86400 * 2)),   // Jessica - 2 days ago
        (discoverUsers[0], Date().addingTimeInterval(-86400 * 4)),   // Sarah again - 4 days ago
        (discoverUsers[1], Date().addingTimeInterval(-86400 * 6))    // Mike again - 6 days ago
    ]

    // MARK: - Helper to get current user for testing

    static let currentUser = User(
        id: "current_user",
        email: "you@test.com",
        fullName: "Kevin Perez",
        age: 25,
        gender: "Male",
        lookingFor: "Female",
        bio: "iOS Developer | Tech enthusiast | Love building cool apps and meeting interesting people!",
        location: "San Francisco",
        country: "USA",
        latitude: 37.7749,
        longitude: -122.4194,
        languages: ["English"],
        interests: ["Coding", "Tech", "Apps", "Music", "Travel"],
        photos: [
            "https://picsum.photos/seed/kevin1/400/500",
            "https://picsum.photos/seed/kevin2/400/500",
            "https://picsum.photos/seed/kevin3/400/500"
        ],
        profileImageURL: "https://picsum.photos/seed/kevin1/400/500",
        isPremium: true,
        isVerified: true
    )
}

#endif

