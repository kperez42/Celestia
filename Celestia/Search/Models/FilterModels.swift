//
//  FilterModels.swift
//  Celestia
//
//  Data models for advanced search and filtering
//

import Foundation
import CoreLocation

// MARK: - Search Filter

struct SearchFilter: Codable, Equatable {

    // MARK: - Location
    var distanceRadius: Int = 50 // miles (1-100)
    var location: CLLocationCoordinate2D?
    var useCurrentLocation: Bool = true

    // MARK: - Demographics
    var ageRange: AgeRange = AgeRange(min: 18, max: 99)
    var heightRange: HeightRange? // Optional, nil = any height
    var gender: GenderFilter = .all
    var showMe: ShowMeFilter = .everyone

    // MARK: - Background
    var educationLevels: [EducationLevel] = []
    var ethnicities: [Ethnicity] = []
    var religions: [Religion] = []
    var languages: [Language] = []

    // MARK: - Lifestyle
    var smoking: LifestyleFilter = .any
    var drinking: LifestyleFilter = .any
    var pets: PetPreference = .any
    var hasChildren: LifestyleFilter = .any
    var wantsChildren: LifestyleFilter = .any
    var exercise: ExerciseFrequency = .any
    var diet: DietPreference = .any

    // MARK: - Relationship
    var relationshipGoals: [RelationshipGoal] = []
    var lookingFor: [LookingFor] = []

    // MARK: - Preferences
    var verifiedOnly: Bool = false
    var withPhotosOnly: Bool = true
    var activeInLastDays: Int? // nil = any, or 1, 7, 30
    var newUsers: Bool = false // Joined in last 30 days

    // MARK: - Advanced
    var zodiacSigns: [ZodiacSign] = []
    var politicalViews: [PoliticalView] = []
    var occupations: [String] = []

    // MARK: - Metadata
    var id: String = UUID().uuidString
    var createdAt: Date = Date()
    var lastUsed: Date = Date()

    // MARK: - Helper Methods

    /// Check if filter is default (no custom filtering)
    var isDefault: Bool {
        return distanceRadius == 50 &&
               ageRange.min == 18 &&
               ageRange.max == 99 &&
               heightRange == nil &&
               educationLevels.isEmpty &&
               ethnicities.isEmpty &&
               religions.isEmpty &&
               smoking == .any &&
               drinking == .any &&
               pets == .any &&
               relationshipGoals.isEmpty &&
               !verifiedOnly
    }

    /// Count active filters
    var activeFilterCount: Int {
        var count = 0

        if distanceRadius != 50 { count += 1 }
        if ageRange.min != 18 || ageRange.max != 99 { count += 1 }
        if heightRange != nil { count += 1 }
        if !educationLevels.isEmpty { count += 1 }
        if !ethnicities.isEmpty { count += 1 }
        if !religions.isEmpty { count += 1 }
        if smoking != .any { count += 1 }
        if drinking != .any { count += 1 }
        if pets != .any { count += 1 }
        if hasChildren != .any { count += 1 }
        if wantsChildren != .any { count += 1 }
        if !relationshipGoals.isEmpty { count += 1 }
        if verifiedOnly { count += 1 }
        if activeInLastDays != nil { count += 1 }
        if newUsers { count += 1 }

        return count
    }

    /// Reset to default
    mutating func reset() {
        self = SearchFilter()
    }
}

// MARK: - Age Range

struct AgeRange: Codable, Equatable {
    var min: Int // 18-99
    var max: Int // 18-99

    init(min: Int = 18, max: Int = 99) {
        self.min = Swift.max(18, Swift.min(99, min))
        self.max = Swift.max(18, Swift.min(99, max))
    }

    func contains(_ age: Int) -> Bool {
        return age >= min && age <= max
    }
}

// MARK: - Height Range

struct HeightRange: Codable, Equatable {
    var minInches: Int // 48-96 inches (4'0" - 8'0")
    var maxInches: Int

    init(minInches: Int = 48, maxInches: Int = 96) {
        self.minInches = Swift.max(48, Swift.min(96, minInches))
        self.maxInches = Swift.max(48, Swift.min(96, maxInches))
    }

    func contains(_ heightInches: Int) -> Bool {
        return heightInches >= minInches && heightInches <= maxInches
    }

    // Helper: Convert inches to feet/inches display
    static func formatHeight(_ inches: Int) -> String {
        let feet = inches / 12
        let remainingInches = inches % 12
        return "\(feet)'\(remainingInches)\""
    }
}

// MARK: - Gender Filter

enum GenderFilter: String, Codable, CaseIterable {
    case all = "all"
    case men = "men"
    case women = "women"
    case nonBinary = "non_binary"

    var displayName: String {
        switch self {
        case .all: return "Everyone"
        case .men: return "Men"
        case .women: return "Women"
        case .nonBinary: return "Non-Binary"
        }
    }
}

// MARK: - Show Me Filter

enum ShowMeFilter: String, Codable, CaseIterable {
    case everyone = "everyone"
    case men = "men"
    case women = "women"
    case nonBinary = "non_binary"

    var displayName: String {
        switch self {
        case .everyone: return "Everyone"
        case .men: return "Men"
        case .women: return "Women"
        case .nonBinary: return "Non-Binary"
        }
    }
}

// MARK: - Education Level

enum EducationLevel: String, Codable, CaseIterable {
    case highSchool = "high_school"
    case someCollege = "some_college"
    case bachelors = "bachelors"
    case masters = "masters"
    case doctorate = "doctorate"
    case tradeSchool = "trade_school"

    var displayName: String {
        switch self {
        case .highSchool: return "High School"
        case .someCollege: return "Some College"
        case .bachelors: return "Bachelor's Degree"
        case .masters: return "Master's Degree"
        case .doctorate: return "Doctorate"
        case .tradeSchool: return "Trade School"
        }
    }

    var icon: String {
        switch self {
        case .highSchool: return "building.2"
        case .someCollege: return "book"
        case .bachelors: return "graduationcap"
        case .masters: return "graduationcap.fill"
        case .doctorate: return "star.fill"
        case .tradeSchool: return "hammer"
        }
    }
}

// MARK: - Ethnicity

enum Ethnicity: String, Codable, CaseIterable {
    case asian = "asian"
    case black = "black"
    case hispanic = "hispanic"
    case middleEastern = "middle_eastern"
    case nativeAmerican = "native_american"
    case pacificIslander = "pacific_islander"
    case white = "white"
    case mixed = "mixed"
    case other = "other"

    var displayName: String {
        switch self {
        case .asian: return "Asian"
        case .black: return "Black / African"
        case .hispanic: return "Hispanic / Latino"
        case .middleEastern: return "Middle Eastern"
        case .nativeAmerican: return "Native American"
        case .pacificIslander: return "Pacific Islander"
        case .white: return "White / Caucasian"
        case .mixed: return "Mixed"
        case .other: return "Other"
        }
    }
}

// MARK: - Religion

enum Religion: String, Codable, CaseIterable {
    case agnostic = "agnostic"
    case atheist = "atheist"
    case buddhist = "buddhist"
    case catholic = "catholic"
    case christian = "christian"
    case hindu = "hindu"
    case jewish = "jewish"
    case muslim = "muslim"
    case spiritual = "spiritual"
    case other = "other"

    var displayName: String {
        switch self {
        case .agnostic: return "Agnostic"
        case .atheist: return "Atheist"
        case .buddhist: return "Buddhist"
        case .catholic: return "Catholic"
        case .christian: return "Christian"
        case .hindu: return "Hindu"
        case .jewish: return "Jewish"
        case .muslim: return "Muslim"
        case .spiritual: return "Spiritual"
        case .other: return "Other"
        }
    }
}

// MARK: - Language

enum Language: String, Codable, CaseIterable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    case arabic = "ar"
    case russian = "ru"
    case hindi = "hi"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .chinese: return "Chinese"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .arabic: return "Arabic"
        case .russian: return "Russian"
        case .hindi: return "Hindi"
        }
    }
}

// MARK: - Lifestyle Filter

enum LifestyleFilter: String, Codable, CaseIterable {
    case any = "any"
    case yes = "yes"
    case no = "no"
    case sometimes = "sometimes"

    var displayName: String {
        switch self {
        case .any: return "Any"
        case .yes: return "Yes"
        case .no: return "No"
        case .sometimes: return "Sometimes"
        }
    }
}

// MARK: - Pet Preference

enum PetPreference: String, Codable, CaseIterable {
    case any = "any"
    case hasDogs = "has_dogs"
    case hasCats = "has_cats"
    case hasPets = "has_pets"
    case noPets = "no_pets"
    case allergicToPets = "allergic"

    var displayName: String {
        switch self {
        case .any: return "Any"
        case .hasDogs: return "Has Dog(s)"
        case .hasCats: return "Has Cat(s)"
        case .hasPets: return "Has Pets"
        case .noPets: return "No Pets"
        case .allergicToPets: return "Allergic to Pets"
        }
    }

    var icon: String {
        switch self {
        case .any: return "pawprint"
        case .hasDogs: return "dog"
        case .hasCats: return "cat"
        case .hasPets: return "pawprint.fill"
        case .noPets: return "nosign"
        case .allergicToPets: return "bandage"
        }
    }
}

// MARK: - Exercise Frequency

enum ExerciseFrequency: String, Codable, CaseIterable {
    case any = "any"
    case daily = "daily"
    case often = "often"
    case sometimes = "sometimes"
    case rarely = "rarely"
    case never = "never"

    var displayName: String {
        switch self {
        case .any: return "Any"
        case .daily: return "Daily"
        case .often: return "Often (3-5x/week)"
        case .sometimes: return "Sometimes (1-2x/week)"
        case .rarely: return "Rarely"
        case .never: return "Never"
        }
    }
}

// MARK: - Diet Preference

enum DietPreference: String, Codable, CaseIterable {
    case any = "any"
    case vegan = "vegan"
    case vegetarian = "vegetarian"
    case pescatarian = "pescatarian"
    case kosher = "kosher"
    case halal = "halal"
    case glutenFree = "gluten_free"
    case omnivore = "omnivore"

    var displayName: String {
        switch self {
        case .any: return "Any"
        case .vegan: return "Vegan"
        case .vegetarian: return "Vegetarian"
        case .pescatarian: return "Pescatarian"
        case .kosher: return "Kosher"
        case .halal: return "Halal"
        case .glutenFree: return "Gluten-Free"
        case .omnivore: return "Omnivore"
        }
    }
}

// MARK: - Relationship Goal

enum RelationshipGoal: String, Codable, CaseIterable {
    case longTerm = "long_term"
    case shortTerm = "short_term"
    case marriage = "marriage"
    case friendship = "friendship"
    case casual = "casual"
    case figureItOut = "figure_out"

    var displayName: String {
        switch self {
        case .longTerm: return "Long-term Relationship"
        case .shortTerm: return "Short-term Relationship"
        case .marriage: return "Marriage"
        case .friendship: return "Friendship"
        case .casual: return "Casual Dating"
        case .figureItOut: return "Figure it Out"
        }
    }

    var icon: String {
        switch self {
        case .longTerm: return "heart.fill"
        case .shortTerm: return "heart"
        case .marriage: return "heart.circle.fill"
        case .friendship: return "person.2.fill"
        case .casual: return "figure.walk"
        case .figureItOut: return "questionmark.circle"
        }
    }
}

// MARK: - Looking For

enum LookingFor: String, Codable, CaseIterable {
    case relationshipPartner = "partner"
    case chatFriends = "chat_friends"
    case activityPartner = "activity_partner"
    case travelBuddy = "travel_buddy"
    case workoutPartner = "workout_partner"

    var displayName: String {
        switch self {
        case .relationshipPartner: return "Relationship Partner"
        case .chatFriends: return "Chat & Friends"
        case .activityPartner: return "Activity Partner"
        case .travelBuddy: return "Travel Buddy"
        case .workoutPartner: return "Workout Partner"
        }
    }
}

// MARK: - Zodiac Sign

enum ZodiacSign: String, Codable, CaseIterable {
    case aries, taurus, gemini, cancer, leo, virgo
    case libra, scorpio, sagittarius, capricorn, aquarius, pisces

    var displayName: String {
        return rawValue.capitalized
    }

    var symbol: String {
        switch self {
        case .aries: return "♈︎"
        case .taurus: return "♉︎"
        case .gemini: return "♊︎"
        case .cancer: return "♋︎"
        case .leo: return "♌︎"
        case .virgo: return "♍︎"
        case .libra: return "♎︎"
        case .scorpio: return "♏︎"
        case .sagittarius: return "♐︎"
        case .capricorn: return "♑︎"
        case .aquarius: return "♒︎"
        case .pisces: return "♓︎"
        }
    }
}

// MARK: - Political View

enum PoliticalView: String, Codable, CaseIterable {
    case liberal = "liberal"
    case moderate = "moderate"
    case conservative = "conservative"
    case notPolitical = "not_political"
    case other = "other"

    var displayName: String {
        switch self {
        case .liberal: return "Liberal"
        case .moderate: return "Moderate"
        case .conservative: return "Conservative"
        case .notPolitical: return "Not Political"
        case .other: return "Other"
        }
    }
}

// MARK: - Filter Preset

struct FilterPreset: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var filter: SearchFilter
    var createdAt: Date
    var lastUsed: Date
    var usageCount: Int

    init(
        id: String = UUID().uuidString,
        name: String,
        filter: SearchFilter,
        createdAt: Date = Date(),
        lastUsed: Date = Date(),
        usageCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.filter = filter
        self.createdAt = createdAt
        self.lastUsed = lastUsed
        self.usageCount = usageCount
    }
}

// MARK: - Search History Entry

struct SearchHistoryEntry: Codable, Identifiable, Equatable {
    let id: String
    let filter: SearchFilter
    let timestamp: Date
    let resultsCount: Int

    init(
        id: String = UUID().uuidString,
        filter: SearchFilter,
        timestamp: Date = Date(),
        resultsCount: Int
    ) {
        self.id = id
        self.filter = filter
        self.timestamp = timestamp
        self.resultsCount = resultsCount
    }
}

// MARK: - CLLocationCoordinate2D Extension

extension CLLocationCoordinate2D: @retroactive Codable, @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }


    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
}
