//
//  User.swift
//  Celestia
//
//  Core user model
//

import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable {
    @DocumentID var id: String?
    
    // Basic Info
    var email: String
    var fullName: String
    var age: Int
    var gender: String
    var lookingFor: String
    var bio: String
    
    // Location
    var location: String
    var country: String
    var latitude: Double?
    var longitude: Double?
    
    // Profile Details
    var languages: [String]
    var interests: [String]
    var photos: [String]
    var profileImageURL: String
    
    // Timestamps
    var timestamp: Date
    var lastActive: Date
    var isOnline: Bool = false
    
    // Premium & Verification
    var isPremium: Bool
    var isVerified: Bool = false
    var premiumTier: String?
    var subscriptionExpiryDate: Date?
    
    // Preferences
    var ageRangeMin: Int
    var ageRangeMax: Int
    var maxDistance: Int
    var showMeInSearch: Bool = true
    
    // Stats
    var likesGiven: Int = 0
    var likesReceived: Int = 0
    var matchCount: Int = 0
    var profileViews: Int = 0

    // Consumables (Premium Features)
    var superLikesRemaining: Int = 0
    var boostsRemaining: Int = 0
    var rewindsRemaining: Int = 0

    // Daily Limits (Free Users)
    var likesRemainingToday: Int = 50  // Free users get 50 likes/day
    var lastLikeResetDate: Date = Date()

    // Boost Status
    var isBoostActive: Bool = false
    var boostExpiryDate: Date?

    // Notifications
    var fcmToken: String?
    var notificationsEnabled: Bool = true

    // Advanced Profile Fields
    var educationLevel: String?
    var height: Int? // in cm
    var religion: String?
    var relationshipGoal: String?
    var smoking: String?
    var drinking: String?
    var pets: String?
    var exercise: String?
    var diet: String?

    // Profile Prompts
    var prompts: [ProfilePrompt] = []

    // Referral System
    var referralStats: ReferralStats = ReferralStats()
    var referredByCode: String?  // Code used during signup

    // Helper computed property for backward compatibility
    var name: String {
        get { fullName }
        set { fullName = newValue }
    }

    // Custom encoding to handle nil values properly for Firebase
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encode(fullName, forKey: .fullName)
        try container.encode(age, forKey: .age)
        try container.encode(gender, forKey: .gender)
        try container.encode(lookingFor, forKey: .lookingFor)
        try container.encode(bio, forKey: .bio)
        try container.encode(location, forKey: .location)
        try container.encode(country, forKey: .country)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encode(languages, forKey: .languages)
        try container.encode(interests, forKey: .interests)
        try container.encode(photos, forKey: .photos)
        try container.encode(profileImageURL, forKey: .profileImageURL)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(lastActive, forKey: .lastActive)
        try container.encode(isOnline, forKey: .isOnline)
        try container.encode(isPremium, forKey: .isPremium)
        try container.encode(isVerified, forKey: .isVerified)
        try container.encodeIfPresent(premiumTier, forKey: .premiumTier)
        try container.encodeIfPresent(subscriptionExpiryDate, forKey: .subscriptionExpiryDate)
        try container.encode(ageRangeMin, forKey: .ageRangeMin)
        try container.encode(ageRangeMax, forKey: .ageRangeMax)
        try container.encode(maxDistance, forKey: .maxDistance)
        try container.encode(showMeInSearch, forKey: .showMeInSearch)
        try container.encode(likesGiven, forKey: .likesGiven)
        try container.encode(likesReceived, forKey: .likesReceived)
        try container.encode(matchCount, forKey: .matchCount)
        try container.encode(profileViews, forKey: .profileViews)
        try container.encodeIfPresent(fcmToken, forKey: .fcmToken)
        try container.encode(notificationsEnabled, forKey: .notificationsEnabled)
        try container.encodeIfPresent(educationLevel, forKey: .educationLevel)
        try container.encodeIfPresent(height, forKey: .height)
        try container.encodeIfPresent(religion, forKey: .religion)
        try container.encodeIfPresent(relationshipGoal, forKey: .relationshipGoal)
        try container.encodeIfPresent(smoking, forKey: .smoking)
        try container.encodeIfPresent(drinking, forKey: .drinking)
        try container.encodeIfPresent(pets, forKey: .pets)
        try container.encodeIfPresent(exercise, forKey: .exercise)
        try container.encodeIfPresent(diet, forKey: .diet)
        try container.encode(prompts, forKey: .prompts)
        try container.encode(referralStats, forKey: .referralStats)
        try container.encodeIfPresent(referredByCode, forKey: .referredByCode)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case email, fullName, age, gender, lookingFor, bio
        case location, country, latitude, longitude
        case languages, interests, photos, profileImageURL
        case timestamp, lastActive, isOnline
        case isPremium, isVerified, premiumTier, subscriptionExpiryDate
        case ageRangeMin, ageRangeMax, maxDistance, showMeInSearch
        case likesGiven, likesReceived, matchCount, profileViews
        case fcmToken, notificationsEnabled
        case educationLevel, height, religion, relationshipGoal
        case smoking, drinking, pets, exercise, diet
        case prompts
        case referralStats, referredByCode
    }
    
    // Initialize from dictionary (for legacy code)
    init(dictionary: [String: Any]) {
        self.id = dictionary["id"] as? String
        self.email = dictionary["email"] as? String ?? ""
        self.fullName = dictionary["fullName"] as? String ?? dictionary["name"] as? String ?? ""
        self.age = dictionary["age"] as? Int ?? 18
        self.gender = dictionary["gender"] as? String ?? ""
        self.lookingFor = dictionary["lookingFor"] as? String ?? "Everyone"
        self.bio = dictionary["bio"] as? String ?? ""
        self.location = dictionary["location"] as? String ?? ""
        self.country = dictionary["country"] as? String ?? ""
        self.latitude = dictionary["latitude"] as? Double
        self.longitude = dictionary["longitude"] as? Double
        self.languages = dictionary["languages"] as? [String] ?? []
        self.interests = dictionary["interests"] as? [String] ?? []
        self.photos = dictionary["photos"] as? [String] ?? []
        self.profileImageURL = dictionary["profileImageURL"] as? String ?? ""
        
        if let timestamp = dictionary["timestamp"] as? Timestamp {
            self.timestamp = timestamp.dateValue()
        } else {
            self.timestamp = Date()
        }
        
        if let lastActive = dictionary["lastActive"] as? Timestamp {
            self.lastActive = lastActive.dateValue()
        } else {
            self.lastActive = Date()
        }
        
        self.isOnline = dictionary["isOnline"] as? Bool ?? false
        self.isPremium = dictionary["isPremium"] as? Bool ?? false
        self.isVerified = dictionary["isVerified"] as? Bool ?? false
        self.premiumTier = dictionary["premiumTier"] as? String
        
        if let expiryDate = dictionary["subscriptionExpiryDate"] as? Timestamp {
            self.subscriptionExpiryDate = expiryDate.dateValue()
        }
        
        self.ageRangeMin = dictionary["ageRangeMin"] as? Int ?? 18
        self.ageRangeMax = dictionary["ageRangeMax"] as? Int ?? 99
        self.maxDistance = dictionary["maxDistance"] as? Int ?? 100
        self.showMeInSearch = dictionary["showMeInSearch"] as? Bool ?? true
        
        self.likesGiven = dictionary["likesGiven"] as? Int ?? 0
        self.likesReceived = dictionary["likesReceived"] as? Int ?? 0
        self.matchCount = dictionary["matchCount"] as? Int ?? 0
        self.profileViews = dictionary["profileViews"] as? Int ?? 0
        
        self.fcmToken = dictionary["fcmToken"] as? String
        self.notificationsEnabled = dictionary["notificationsEnabled"] as? Bool ?? true

        // Advanced Profile Fields
        self.educationLevel = dictionary["educationLevel"] as? String
        self.height = dictionary["height"] as? Int
        self.religion = dictionary["religion"] as? String
        self.relationshipGoal = dictionary["relationshipGoal"] as? String
        self.smoking = dictionary["smoking"] as? String
        self.drinking = dictionary["drinking"] as? String
        self.pets = dictionary["pets"] as? String
        self.exercise = dictionary["exercise"] as? String
        self.diet = dictionary["diet"] as? String

        // Profile Prompts
        if let promptsData = dictionary["prompts"] as? [[String: Any]] {
            self.prompts = promptsData.compactMap { promptDict in
                guard let question = promptDict["question"] as? String,
                      let answer = promptDict["answer"] as? String else {
                    return nil
                }
                let id = promptDict["id"] as? String ?? UUID().uuidString
                return ProfilePrompt(id: id, question: question, answer: answer)
            }
        } else {
            self.prompts = []
        }

        // Referral System
        if let referralStatsDict = dictionary["referralStats"] as? [String: Any] {
            self.referralStats = ReferralStats(dictionary: referralStatsDict)
        } else {
            self.referralStats = ReferralStats()
        }
        self.referredByCode = dictionary["referredByCode"] as? String
    }
    
    // Standard initializer
    init(
        id: String? = nil,
        email: String,
        fullName: String,
        age: Int,
        gender: String,
        lookingFor: String,
        bio: String = "",
        location: String,
        country: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        languages: [String] = [],
        interests: [String] = [],
        photos: [String] = [],
        profileImageURL: String = "",
        timestamp: Date = Date(),
        isPremium: Bool = false,
        isVerified: Bool = false,
        lastActive: Date = Date(),
        ageRangeMin: Int = 18,
        ageRangeMax: Int = 99,
        maxDistance: Int = 100
    ) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.age = age
        self.gender = gender
        self.lookingFor = lookingFor
        self.bio = bio
        self.location = location
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.languages = languages
        self.interests = interests
        self.photos = photos
        self.profileImageURL = profileImageURL
        self.timestamp = timestamp
        self.isPremium = isPremium
        self.isVerified = isVerified
        self.lastActive = lastActive
        self.ageRangeMin = ageRangeMin
        self.ageRangeMax = ageRangeMax
        self.maxDistance = maxDistance
    }
}

// MARK: - User Factory Methods

extension User {
    /// Factory method to create a minimal User object for notifications
    /// Validates required fields before creating
    static func createMinimal(
        id: String,
        fullName: String,
        from data: [String: Any]
    ) throws -> User {
        // Validate required fields
        guard let email = data["email"] as? String, !email.isEmpty else {
            throw UserCreationError.missingRequiredField("email")
        }

        guard let age = data["age"] as? Int, age >= AppConstants.Limits.minAge, age <= AppConstants.Limits.maxAge else {
            throw UserCreationError.invalidField("age", "Must be between \(AppConstants.Limits.minAge) and \(AppConstants.Limits.maxAge)")
        }

        guard let gender = data["gender"] as? String, !gender.isEmpty else {
            throw UserCreationError.missingRequiredField("gender")
        }

        // Create with validated data and safe defaults
        return User(
            id: id,
            email: email,
            fullName: fullName,
            age: age,
            gender: gender,
            lookingFor: data["lookingFor"] as? String ?? "",
            location: data["location"] as? String ?? "",
            country: data["country"] as? String ?? ""
        )
    }

    /// Factory method to create User from Firestore data with validation
    static func fromFirestore(id: String, data: [String: Any]) throws -> User {
        // Validate all required fields
        guard let email = data["email"] as? String, !email.isEmpty else {
            throw UserCreationError.missingRequiredField("email")
        }

        guard let fullName = data["fullName"] as? String, !fullName.isEmpty else {
            throw UserCreationError.missingRequiredField("fullName")
        }

        guard let age = data["age"] as? Int, age >= AppConstants.Limits.minAge, age <= AppConstants.Limits.maxAge else {
            throw UserCreationError.invalidField("age", "Must be between \(AppConstants.Limits.minAge) and \(AppConstants.Limits.maxAge)")
        }

        guard let gender = data["gender"] as? String, !gender.isEmpty else {
            throw UserCreationError.missingRequiredField("gender")
        }

        guard let lookingFor = data["lookingFor"] as? String, !lookingFor.isEmpty else {
            throw UserCreationError.missingRequiredField("lookingFor")
        }

        // Create with validated data
        return User(
            id: id,
            email: email,
            fullName: fullName,
            age: age,
            gender: gender,
            lookingFor: lookingFor,
            location: data["location"] as? String ?? "",
            country: data["country"] as? String ?? ""
        )
    }
}

// MARK: - User Creation Errors

enum UserCreationError: LocalizedError {
    case missingRequiredField(String)
    case invalidField(String, String)

    var errorDescription: String? {
        switch self {
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidField(let field, let reason):
            return "Invalid field '\(field)': \(reason)"
        }
    }
}
