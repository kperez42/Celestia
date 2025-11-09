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
        )
    ]
}
