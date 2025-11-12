//
//  SearchManager.swift
//  Celestia
//
//  Manages user search and filtering functionality
//

import Foundation
import Combine
import FirebaseFirestore

// MARK: - Search Manager

@MainActor
class SearchManager: ObservableObject {

    // MARK: - Singleton

    static let shared = SearchManager()

    // MARK: - Published Properties

    @Published var isSearching: Bool = false
    @Published var searchResults: [UserProfile] = []
    @Published var currentFilter: SearchFilter = SearchFilter()
    @Published var totalResultsCount: Int = 0
    @Published var errorMessage: String?

    // MARK: - Properties

    private let firestore = Firestore.firestore()
    private var searchTask: Task<Void, Never>?

    // MARK: - Initialization

    private init() {
        Logger.shared.info("SearchManager initialized", category: .general)
    }

    // MARK: - Search Methods

    /// Perform search with current filter
    func search() async {
        await search(with: currentFilter)
    }

    /// Perform search with specific filter
    func search(with filter: SearchFilter) async {
        // Cancel any ongoing search
        searchTask?.cancel()

        searchTask = Task {
            guard !Task.isCancelled else { return }

            isSearching = true
            currentFilter = filter
            errorMessage = nil

            do {
                let results = try await performSearch(filter: filter)

                guard !Task.isCancelled else { return }

                searchResults = results
                totalResultsCount = results.count

                // Track analytics
                AnalyticsManager.shared.logEvent(.featureUsed, parameters: [
                    "feature": "search",
                    "results_count": results.count,
                    "active_filters": filter.activeFilterCount
                ])

                Logger.shared.info("Search completed: \(results.count) results", category: .general)
            } catch {
                guard !Task.isCancelled else { return }

                errorMessage = error.localizedDescription
                Logger.shared.error("Search failed", category: .general, error: error)
            }

            isSearching = false
        }
    }

    /// Reset filter to defaults
    func resetFilter() {
        currentFilter.reset()
    }

    /// Clear search results
    func clearResults() {
        searchResults = []
        totalResultsCount = 0
    }

    // MARK: - Private Methods

    private func performSearch(filter: SearchFilter) async throws -> [UserProfile] {
        var query = firestore.collection("users")
            .limit(to: 100)

        // Apply age filter
        query = query
            .whereField("age", isGreaterThanOrEqualTo: filter.ageRange.min)
            .whereField("age", isLessThanOrEqualTo: filter.ageRange.max)

        // Apply gender filter
        switch filter.showMe {
        case .men:
            query = query.whereField("gender", isEqualTo: "Male")
        case .women:
            query = query.whereField("gender", isEqualTo: "Female")
        case .everyone:
            break // No filter
        }

        // Apply verified filter
        if filter.verifiedOnly {
            query = query.whereField("isVerified", isEqualTo: true)
        }

        // Execute query
        let snapshot = try await query.getDocuments()

        // Convert to UserProfile objects
        var profiles: [UserProfile] = []
        for document in snapshot.documents {
            if let profile = UserProfile(document: document) {
                // Apply additional client-side filters
                if matchesFilter(profile: profile, filter: filter) {
                    profiles.append(profile)
                }
            }
        }

        return profiles
    }

    private func matchesFilter(profile: UserProfile, filter: SearchFilter) -> Bool {
        // Height filter
        if let heightRange = filter.heightRange,
           let profileHeight = profile.heightInInches {
            if profileHeight < heightRange.minInches || profileHeight > heightRange.maxInches {
                return false
            }
        }

        // Education filter
        if !filter.educationLevels.isEmpty,
           let profileEducation = profile.education {
            if !filter.educationLevels.contains(profileEducation) {
                return false
            }
        }

        // Relationship goals filter
        if !filter.relationshipGoals.isEmpty,
           let profileGoal = profile.relationshipGoal {
            if !filter.relationshipGoals.contains(profileGoal) {
                return false
            }
        }

        // Photos filter
        if filter.withPhotosOnly && profile.photos.isEmpty {
            return false
        }

        return true
    }
}

// MARK: - User Profile Model

struct UserProfile: Identifiable, Codable {
    let id: String
    let name: String
    let age: Int
    let bio: String
    let photos: [String]
    let isVerified: Bool
    let distance: Double? // in miles
    let heightInInches: Int?
    let education: EducationLevel?
    let occupation: String?
    let relationshipGoal: RelationshipGoal?
    let zodiacSign: ZodiacSign?
    let ethnicity: Ethnicity?
    let religion: Religion?

    var distanceString: String {
        if let distance = distance {
            return String(format: "%.1f miles away", distance)
        }
        return "Distance unknown"
    }

    var heightFormatted: String? {
        guard let heightInInches = heightInInches else { return nil }
        return HeightRange.formatHeight(heightInInches)
    }

    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }

        self.id = document.documentID
        self.name = data["name"] as? String ?? "Unknown"
        self.age = data["age"] as? Int ?? 18
        self.bio = data["bio"] as? String ?? ""
        self.photos = data["photos"] as? [String] ?? []
        self.isVerified = data["isVerified"] as? Bool ?? false
        self.distance = data["distance"] as? Double
        self.heightInInches = data["heightInInches"] as? Int
        self.occupation = data["occupation"] as? String

        // Decode enum values
        if let educationRaw = data["education"] as? String {
            self.education = EducationLevel(rawValue: educationRaw)
        } else {
            self.education = nil
        }

        if let goalRaw = data["relationshipGoal"] as? String {
            self.relationshipGoal = RelationshipGoal(rawValue: goalRaw)
        } else {
            self.relationshipGoal = nil
        }

        if let zodiacRaw = data["zodiacSign"] as? String {
            self.zodiacSign = ZodiacSign(rawValue: zodiacRaw)
        } else {
            self.zodiacSign = nil
        }

        if let ethnicityRaw = data["ethnicity"] as? String {
            self.ethnicity = Ethnicity(rawValue: ethnicityRaw)
        } else {
            self.ethnicity = nil
        }

        if let religionRaw = data["religion"] as? String {
            self.religion = Religion(rawValue: religionRaw)
        } else {
            self.religion = nil
        }
    }
}

// MARK: - Search Filter

struct SearchFilter: Codable {
    var ageRange: AgeRange = AgeRange(min: 18, max: 99)
    var distanceRadius: Int = 50 // miles
    var useCurrentLocation: Bool = true
    var heightRange: HeightRange?
    var showMe: ShowMeFilter = .everyone
    var educationLevels: [EducationLevel] = []
    var ethnicities: [Ethnicity] = []
    var religions: [Religion] = []
    var smoking: LifestyleFilter = .any
    var drinking: LifestyleFilter = .any
    var pets: PetPreference = .any
    var hasChildren: LifestyleFilter = .any
    var wantsChildren: LifestyleFilter = .any
    var exercise: ExerciseFrequency?
    var diet: DietPreference?
    var relationshipGoals: [RelationshipGoal] = []
    var verifiedOnly: Bool = false
    var withPhotosOnly: Bool = true
    var activeInLastDays: Int?
    var newUsers: Bool = false
    var zodiacSigns: [ZodiacSign] = []
    var politicalViews: [PoliticalView] = []

    var activeFilterCount: Int {
        var count = 0

        if ageRange.min != 18 || ageRange.max != 99 { count += 1 }
        if distanceRadius != 50 { count += 1 }
        if heightRange != nil { count += 1 }
        if showMe != .everyone { count += 1 }
        if !educationLevels.isEmpty { count += 1 }
        if !ethnicities.isEmpty { count += 1 }
        if !religions.isEmpty { count += 1 }
        if smoking != .any { count += 1 }
        if drinking != .any { count += 1 }
        if pets != .any { count += 1 }
        if hasChildren != .any { count += 1 }
        if wantsChildren != .any { count += 1 }
        if exercise != nil { count += 1 }
        if diet != nil { count += 1 }
        if !relationshipGoals.isEmpty { count += 1 }
        if verifiedOnly { count += 1 }
        if !withPhotosOnly { count += 1 }
        if activeInLastDays != nil { count += 1 }
        if newUsers { count += 1 }
        if !zodiacSigns.isEmpty { count += 1 }
        if !politicalViews.isEmpty { count += 1 }

        return count
    }

    mutating func reset() {
        self = SearchFilter()
    }
}

// MARK: - Supporting Types

struct AgeRange: Codable {
    var min: Int
    var max: Int
}

struct HeightRange: Codable {
    var minInches: Int = 48 // 4'0"
    var maxInches: Int = 96 // 8'0"

    static func formatHeight(_ inches: Int) -> String {
        let feet = inches / 12
        let remainingInches = inches % 12
        return "\(feet)'\(remainingInches)\""
    }
}

enum ShowMeFilter: String, Codable, CaseIterable {
    case men = "men"
    case women = "women"
    case everyone = "everyone"

    var displayName: String {
        switch self {
        case .men: return "Men"
        case .women: return "Women"
        case .everyone: return "Everyone"
        }
    }
}

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

enum PetPreference: String, Codable, CaseIterable {
    case any = "any"
    case dog = "dog"
    case cat = "cat"
    case both = "both"
    case none = "none"

    var displayName: String {
        switch self {
        case .any: return "Any"
        case .dog: return "Dog"
        case .cat: return "Cat"
        case .both: return "Both"
        case .none: return "None"
        }
    }
}

enum ExerciseFrequency: String, Codable, CaseIterable {
    case any = "any"
    case never = "never"
    case rarely = "rarely"
    case sometimes = "sometimes"
    case often = "often"
    case everyday = "everyday"

    var displayName: String {
        switch self {
        case .any: return "Any"
        case .never: return "Never"
        case .rarely: return "Rarely"
        case .sometimes: return "Sometimes"
        case .often: return "Often"
        case .everyday: return "Every day"
        }
    }
}

enum DietPreference: String, Codable, CaseIterable {
    case any = "any"
    case vegan = "vegan"
    case vegetarian = "vegetarian"
    case pescatarian = "pescatarian"
    case kosher = "kosher"
    case halal = "halal"
    case carnivore = "carnivore"
    case other = "other"

    var displayName: String {
        switch self {
        case .any: return "Any"
        case .vegan: return "Vegan"
        case .vegetarian: return "Vegetarian"
        case .pescatarian: return "Pescatarian"
        case .kosher: return "Kosher"
        case .halal: return "Halal"
        case .carnivore: return "Carnivore"
        case .other: return "Other"
        }
    }
}

// MARK: - Filter Preset Manager

@MainActor
class FilterPresetManager: ObservableObject {
    static let shared = FilterPresetManager()

    @Published var presets: [FilterPreset] = []
    @Published var searchHistory: [SearchHistoryItem] = []

    private init() {}

    func savePreset(name: String, filter: SearchFilter) throws -> FilterPreset {
        let preset = FilterPreset(id: UUID().uuidString, name: name, filter: filter, createdAt: Date())
        presets.append(preset)
        return preset
    }

    func addToHistory(filter: SearchFilter, resultsCount: Int) {
        let item = SearchHistoryItem(filter: filter, resultsCount: resultsCount, searchedAt: Date())
        searchHistory.insert(item, at: 0)

        // Keep only last 20 searches
        if searchHistory.count > 20 {
            searchHistory.removeLast()
        }
    }
}

struct FilterPreset: Identifiable, Codable {
    let id: String
    let name: String
    let filter: SearchFilter
    let createdAt: Date
}

struct SearchHistoryItem: Identifiable {
    let id = UUID()
    let filter: SearchFilter
    let resultsCount: Int
    let searchedAt: Date
}

// Filter Presets View (stub for compilation)
struct FilterPresetsView: View {
    let onSelect: (FilterPreset) -> Void

    var body: some View {
        Text("Filter Presets")
    }
}

import SwiftUI
