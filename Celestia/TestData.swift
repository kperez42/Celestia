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
        fullName: "Alex Johnson",
        email: "alex@test.com",
        profileImageURL: "",
        age: 28,
        gender: "Male",
        location: "San Francisco",
        country: "USA",
        latitude: 37.7749,
        longitude: -122.4194,
        bio: "Love traveling, hiking, and good coffee. Always up for an adventure!",
        interests: ["Travel", "Hiking", "Coffee", "Photography", "Music"],
        photos: [],
        languages: ["English", "Spanish"],
        lookingFor: "Relationship",
        ageRangeMin: 24,
        ageRangeMax: 35,
        maxDistance: 50,
        isVerified: false,
        isPremium: false,
        timestamp: Date(),
        lastActive: Date(),
        matchCount: 12,
        profileViews: 234,
        likesReceived: 45
    )

    static let discoverUsers = [
        User(
            id: "test-user-2",
            fullName: "Sarah Martinez",
            email: "sarah@test.com",
            profileImageURL: "",
            age: 26,
            gender: "Female",
            location: "San Francisco",
            country: "USA",
            latitude: 37.7749,
            longitude: -122.4194,
            bio: "Adventure seeker and coffee enthusiast. Let's explore the city together!",
            interests: ["Coffee", "Hiking", "Food", "Art", "Yoga"],
            photos: [],
            languages: ["English"],
            lookingFor: "Relationship",
            ageRangeMin: 24,
            ageRangeMax: 32,
            maxDistance: 30,
            isVerified: true,
            isPremium: false,
            timestamp: Date(),
            lastActive: Date(),
            matchCount: 8,
            profileViews: 156,
            likesReceived: 32
        ),
        User(
            id: "test-user-3",
            fullName: "Michael Chen",
            email: "michael@test.com",
            profileImageURL: "",
            age: 30,
            gender: "Male",
            location: "Oakland",
            country: "USA",
            latitude: 37.8044,
            longitude: -122.2712,
            bio: "Tech enthusiast, foodie, and weekend traveler.",
            interests: ["Travel", "Food", "Gaming", "Movies", "Fitness"],
            photos: [],
            languages: ["English", "Mandarin"],
            lookingFor: "Casual",
            ageRangeMin: 25,
            ageRangeMax: 35,
            maxDistance: 40,
            isVerified: true,
            isPremium: true,
            timestamp: Date(),
            lastActive: Date(),
            matchCount: 24,
            profileViews: 456,
            likesReceived: 89
        )
    ]
}
