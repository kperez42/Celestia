//
//  SearchManager.swift
//  Celestia
//
//  Manages user search and filtering functionality
//  Filter types are defined in FilterModels.swift
//

import Foundation
import Combine
import FirebaseFirestore
import SwiftUI

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
        currentFilter = SearchFilter()
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
        case .nonBinary:
            query = query.whereField("gender", isEqualTo: "Non-Binary")
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

// Note: FilterPresetManager is defined in FilterPresetManager.swift
// Note: SearchHistoryEntry is defined in FilterModels.swift
// Note: FilterPresetsView is defined in FilterPresetsView.swift
