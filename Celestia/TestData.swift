//
//  TestData.swift
//  Celestia
//
//  Test data for SwiftUI previews
//

import Foundation

struct TestData {
    static let currentUser = User(
        id: "test-user-1",
        email: "alex@test.com",
        fullName: "Alex Johnson",
        age: 28,
        gender: "Male",
        lookingFor: "Relationship",
        bio: "Love traveling, hiking, and good coffee. Always up for an adventure!",
        location: "San Francisco",
        country: "USA",
        latitude: 37.7749,
        longitude: -122.4194,
        languages: ["English", "Spanish"],
        interests: ["Travel", "Hiking", "Coffee", "Photography", "Music"],
        photos: [],
        profileImageURL: "",
        timestamp: Date(),
        isPremium: false,
        isVerified: false,
        lastActive: Date(),
        ageRangeMin: 24,
        ageRangeMax: 35,
        maxDistance: 50
    )

    static let discoverUsers = [
        User(
            id: "test-user-2",
            email: "sarah@test.com",
            fullName: "Sarah Martinez",
            age: 26,
            gender: "Female",
            lookingFor: "Relationship",
            bio: "Adventure seeker and coffee enthusiast. Let's explore the city together!",
            location: "San Francisco",
            country: "USA",
            latitude: 37.7749,
            longitude: -122.4194,
            languages: ["English"],
            interests: ["Coffee", "Hiking", "Food", "Art", "Yoga"],
            photos: [],
            profileImageURL: "",
            timestamp: Date(),
            isPremium: false,
            isVerified: true,
            lastActive: Date(),
            ageRangeMin: 24,
            ageRangeMax: 32,
            maxDistance: 30
        ),
        User(
            id: "test-user-3",
            email: "michael@test.com",
            fullName: "Michael Chen",
            age: 30,
            gender: "Male",
            lookingFor: "Casual",
            bio: "Tech enthusiast, foodie, and weekend traveler.",
            location: "Oakland",
            country: "USA",
            latitude: 37.8044,
            longitude: -122.2712,
            languages: ["English", "Mandarin"],
            interests: ["Travel", "Food", "Gaming", "Movies", "Fitness"],
            photos: [],
            profileImageURL: "",
            timestamp: Date(),
            isPremium: true,
            isVerified: true,
            lastActive: Date(),
            ageRangeMin: 25,
            ageRangeMax: 35,
            maxDistance: 40
        ),
        User(
            id: "test-user-4",
            email: "emma@test.com",
            fullName: "Emma Wilson",
            age: 27,
            gender: "Female",
            lookingFor: "Relationship",
            bio: "Yoga instructor and nature lover. Looking for someone to share sunsets with 🌅",
            location: "Berkeley",
            country: "USA",
            latitude: 37.8715,
            longitude: -122.2730,
            languages: ["English", "French"],
            interests: ["Yoga", "Hiking", "Photography", "Travel", "Music"],
            photos: [],
            profileImageURL: "",
            timestamp: Date(),
            isPremium: false,
            isVerified: true,
            lastActive: Date(),
            ageRangeMin: 25,
            ageRangeMax: 33,
            maxDistance: 25
        ),
        User(
            id: "test-user-5",
            email: "david@test.com",
            fullName: "David Rodriguez",
            age: 29,
            gender: "Male",
            lookingFor: "Casual",
            bio: "Musician and craft beer enthusiast. Always down for live shows and good vibes.",
            location: "San Jose",
            country: "USA",
            latitude: 37.3382,
            longitude: -121.8863,
            languages: ["English", "Spanish"],
            interests: ["Music", "Beer", "Food", "Concerts", "Dogs"],
            photos: [],
            profileImageURL: "",
            timestamp: Date(),
            isPremium: true,
            isVerified: false,
            lastActive: Date(),
            ageRangeMin: 24,
            ageRangeMax: 32,
            maxDistance: 45
        ),
        User(
            id: "test-user-6",
            email: "jessica@test.com",
            fullName: "Jessica Kim",
            age: 25,
            gender: "Female",
            lookingFor: "Relationship",
            bio: "Bookworm, coffee addict, and aspiring chef. Let's grab coffee and talk about our favorite books!",
            location: "San Francisco",
            country: "USA",
            latitude: 37.7749,
            longitude: -122.4194,
            languages: ["English", "Korean"],
            interests: ["Reading", "Coffee", "Cooking", "Art", "Wine"],
            photos: [],
            profileImageURL: "",
            timestamp: Date(),
            isPremium: false,
            isVerified: true,
            lastActive: Date(),
            ageRangeMin: 23,
            ageRangeMax: 30,
            maxDistance: 20
        )
    ]

    // MARK: - Test Matches

    static let matches = [
        Match(
            id: "match-1",
            user1Id: "test-user-1",
            user2Id: "test-user-2",
            timestamp: Date().addingTimeInterval(-86400 * 2), // 2 days ago
            lastMessageTimestamp: Date().addingTimeInterval(-3600), // 1 hour ago
            lastMessage: "Sounds great! Looking forward to it 😊",
            unreadCount: ["test-user-1": 1],
            isActive: true
        ),
        Match(
            id: "match-2",
            user1Id: "test-user-1",
            user2Id: "test-user-4",
            timestamp: Date().addingTimeInterval(-86400 * 5), // 5 days ago
            lastMessageTimestamp: Date().addingTimeInterval(-7200), // 2 hours ago
            lastMessage: "That sunset spot sounds amazing!",
            unreadCount: ["test-user-1": 2],
            isActive: true
        ),
        Match(
            id: "match-3",
            user1Id: "test-user-1",
            user2Id: "test-user-6",
            timestamp: Date().addingTimeInterval(-86400), // 1 day ago
            lastMessageTimestamp: Date().addingTimeInterval(-14400), // 4 hours ago
            lastMessage: "I love that author too! Have you read their latest?",
            unreadCount: [:],
            isActive: true
        ),
        Match(
            id: "match-4",
            user1Id: "test-user-1",
            user2Id: "test-user-3",
            timestamp: Date().addingTimeInterval(-86400 * 7), // 7 days ago
            lastMessageTimestamp: Date().addingTimeInterval(-86400 * 3), // 3 days ago
            lastMessage: "Cool, let me know when you're free",
            unreadCount: [:],
            isActive: true
        ),
        Match(
            id: "match-5",
            user1Id: "test-user-1",
            user2Id: "test-user-5",
            timestamp: Date().addingTimeInterval(-86400 * 3), // 3 days ago
            lastMessageTimestamp: Date().addingTimeInterval(-300), // 5 minutes ago
            lastMessage: "Just sent you the playlist!",
            unreadCount: ["test-user-1": 3],
            isActive: true
        )
    ]

    // MARK: - Test Messages

    static let messages = [
        // Conversation with Sarah (match-1)
        Message(
            id: "msg-1",
            matchId: "match-1",
            senderId: "test-user-2",
            receiverId: "test-user-1",
            text: "Hey! I saw you're into hiking too. Have you done any trails around here?",
            timestamp: Date().addingTimeInterval(-86400), // 1 day ago
            isRead: true,
            isDelivered: true
        ),
        Message(
            id: "msg-2",
            matchId: "match-1",
            senderId: "test-user-1",
            receiverId: "test-user-2",
            text: "Yes! I love the trails in Marin. Have you been to Mount Tamalpais?",
            timestamp: Date().addingTimeInterval(-82800), // 23 hours ago
            isRead: true,
            isDelivered: true
        ),
        Message(
            id: "msg-3",
            matchId: "match-1",
            senderId: "test-user-2",
            receiverId: "test-user-1",
            text: "Not yet, but it's on my list! Maybe we could go sometime?",
            timestamp: Date().addingTimeInterval(-79200), // 22 hours ago
            isRead: true,
            isDelivered: true
        ),
        Message(
            id: "msg-4",
            matchId: "match-1",
            senderId: "test-user-1",
            receiverId: "test-user-2",
            text: "That would be awesome! How about next weekend?",
            timestamp: Date().addingTimeInterval(-7200), // 2 hours ago
            isRead: true,
            isDelivered: true
        ),
        Message(
            id: "msg-5",
            matchId: "match-1",
            senderId: "test-user-2",
            receiverId: "test-user-1",
            text: "Sounds great! Looking forward to it 😊",
            timestamp: Date().addingTimeInterval(-3600), // 1 hour ago
            isRead: false,
            isDelivered: true
        ),

        // Conversation with Emma (match-2)
        Message(
            id: "msg-6",
            matchId: "match-2",
            senderId: "test-user-1",
            receiverId: "test-user-4",
            text: "I love your photos! That sunset is incredible.",
            timestamp: Date().addingTimeInterval(-86400 * 4), // 4 days ago
            isRead: true,
            isDelivered: true
        ),
        Message(
            id: "msg-7",
            matchId: "match-2",
            senderId: "test-user-4",
            receiverId: "test-user-1",
            text: "Thank you! That was at Lands End. It's my favorite spot in the city.",
            timestamp: Date().addingTimeInterval(-86400 * 4 + 3600), // 4 days ago + 1 hour
            isRead: true,
            isDelivered: true
        ),
        Message(
            id: "msg-8",
            matchId: "match-2",
            senderId: "test-user-4",
            receiverId: "test-user-1",
            text: "That sunset spot sounds amazing!",
            timestamp: Date().addingTimeInterval(-7200), // 2 hours ago
            isRead: false,
            isDelivered: true
        ),

        // Conversation with Jessica (match-3)
        Message(
            id: "msg-9",
            matchId: "match-3",
            senderId: "test-user-6",
            receiverId: "test-user-1",
            text: "Hi! I noticed we both love coffee. What's your favorite spot?",
            timestamp: Date().addingTimeInterval(-43200), // 12 hours ago
            isRead: true,
            isDelivered: true
        ),
        Message(
            id: "msg-10",
            matchId: "match-3",
            senderId: "test-user-1",
            receiverId: "test-user-6",
            text: "There's this amazing place in North Beach called Caffe Trieste. You?",
            timestamp: Date().addingTimeInterval(-39600), // 11 hours ago
            isRead: true,
            isDelivered: true
        ),
        Message(
            id: "msg-11",
            matchId: "match-3",
            senderId: "test-user-6",
            receiverId: "test-user-1",
            text: "I love that author too! Have you read their latest?",
            timestamp: Date().addingTimeInterval(-14400), // 4 hours ago
            isRead: true,
            isDelivered: true
        ),

        // Conversation with David (match-5)
        Message(
            id: "msg-12",
            matchId: "match-5",
            senderId: "test-user-5",
            receiverId: "test-user-1",
            text: "Hey! Saw you're into music too. What have you been listening to lately?",
            timestamp: Date().addingTimeInterval(-3600), // 1 hour ago
            isRead: true,
            isDelivered: true
        ),
        Message(
            id: "msg-13",
            matchId: "match-5",
            senderId: "test-user-1",
            receiverId: "test-user-5",
            text: "Lots of indie and alternative rock. Just discovered this band called The Marias.",
            timestamp: Date().addingTimeInterval(-1800), // 30 minutes ago
            isRead: true,
            isDelivered: true
        ),
        Message(
            id: "msg-14",
            matchId: "match-5",
            senderId: "test-user-5",
            receiverId: "test-user-1",
            text: "Oh nice! I actually saw them live last month. Let me send you a playlist.",
            timestamp: Date().addingTimeInterval(-600), // 10 minutes ago
            isRead: true,
            isDelivered: true
        ),
        Message(
            id: "msg-15",
            matchId: "match-5",
            senderId: "test-user-5",
            receiverId: "test-user-1",
            text: "Just sent you the playlist!",
            timestamp: Date().addingTimeInterval(-300), // 5 minutes ago
            isRead: false,
            isDelivered: true
        )
    ]
}
