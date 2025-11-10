//
//  SearchManager.swift
//  Celestia
//
//  Core search and filtering engine with distance-based matching
//

import Foundation
import CoreLocation
import Combine

// MARK: - Search Manager

@MainActor
class SearchManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    // MARK: - Singleton

    static let shared = SearchManager()

    // MARK: - Published Properties

    @Published var currentFilter: SearchFilter = SearchFilter()
    @Published var searchResults: [UserProfile] = []
    @Published var isSearching: Bool = false
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var totalResultsCount: Int = 0

    // MARK: - Private Properties

    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private override init() {
        super.init()
        setupLocationManager()
        Logger.shared.info("SearchManager initialized", category: .general)
    }

    // MARK: - Location Setup

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }

    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    // CLLocationManagerDelegate
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            self.currentLocation = location.coordinate
            Logger.shared.debug("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)", category: .general)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Logger.shared.error("Location error: \(error.localizedDescription)", category: .general)
    }

    // MARK: - Search

    /// Perform search with current filter
    func search() async {
        isSearching = true

        Logger.shared.info("Starting search with \(currentFilter.activeFilterCount) active filters", category: .general)

        // Update filter location if using current location
        if currentFilter.useCurrentLocation, let location = currentLocation {
            currentFilter.location = location
        }

        do {
            // Fetch potential matches from backend/database
            let allUsers = try await fetchPotentialMatches()

            // Apply filters locally
            let filtered = filterUsers(allUsers, with: currentFilter)

            // Sort by relevance
            let sorted = sortByRelevance(filtered, filter: currentFilter)

            searchResults = sorted
            totalResultsCount = sorted.count

            // Track analytics
            AnalyticsManager.shared.logEvent(.searchPerformed, parameters: [
                "filter_count": currentFilter.activeFilterCount,
                "results_count": totalResultsCount,
                "distance_radius": currentFilter.distanceRadius,
                "age_min": currentFilter.ageRange.min,
                "age_max": currentFilter.ageRange.max
            ])

            Logger.shared.info("Search completed: \(totalResultsCount) results", category: .general)

        } catch {
            Logger.shared.error("Search failed: \(error.localizedDescription)", category: .general)
            searchResults = []
            totalResultsCount = 0
        }

        isSearching = false
    }

    /// Search with specific filter
    func search(with filter: SearchFilter) async {
        currentFilter = filter
        currentFilter.lastUsed = Date()
        await search()
    }

    /// Quick search with specific criteria
    func quickSearch(
        ageRange: AgeRange? = nil,
        distance: Int? = nil,
        verifiedOnly: Bool? = nil
    ) async {
        if let ageRange = ageRange {
            currentFilter.ageRange = ageRange
        }
        if let distance = distance {
            currentFilter.distanceRadius = distance
        }
        if let verifiedOnly = verifiedOnly {
            currentFilter.verifiedOnly = verifiedOnly
        }

        await search()
    }

    // MARK: - Fetch Data

    private func fetchPotentialMatches() async throws -> [UserProfile] {
        // In production, fetch from backend API
        // For now, return mock data

        // Simulate API delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        return generateMockProfiles(count: 100)
    }

    // MARK: - Filtering Logic

    /// Apply all filters to user list
    func filterUsers(_ users: [UserProfile], with filter: SearchFilter) -> [UserProfile] {
        var filtered = users

        // Distance filter
        if let userLocation = filter.location {
            filtered = filtered.filter { user in
                guard let profileLocation = user.location else { return false }
                let distance = calculateDistance(
                    from: userLocation,
                    to: profileLocation
                )
                return distance <= Double(filter.distanceRadius)
            }
        }

        // Age filter
        filtered = filtered.filter { user in
            filter.ageRange.contains(user.age)
        }

        // Height filter
        if let heightRange = filter.heightRange {
            filtered = filtered.filter { user in
                guard let height = user.heightInches else { return false }
                return heightRange.contains(height)
            }
        }

        // Gender filter
        if filter.gender != .all {
            filtered = filtered.filter { user in
                user.gender.rawValue == filter.gender.rawValue
            }
        }

        // Education filter
        if !filter.educationLevels.isEmpty {
            filtered = filtered.filter { user in
                guard let education = user.education else { return false }
                return filter.educationLevels.contains(education)
            }
        }

        // Ethnicity filter
        if !filter.ethnicities.isEmpty {
            filtered = filtered.filter { user in
                guard let ethnicity = user.ethnicity else { return false }
                return filter.ethnicities.contains(ethnicity)
            }
        }

        // Religion filter
        if !filter.religions.isEmpty {
            filtered = filtered.filter { user in
                guard let religion = user.religion else { return false }
                return filter.religions.contains(religion)
            }
        }

        // Smoking filter
        if filter.smoking != .any {
            filtered = filtered.filter { user in
                user.smoking == filter.smoking
            }
        }

        // Drinking filter
        if filter.drinking != .any {
            filtered = filtered.filter { user in
                user.drinking == filter.drinking
            }
        }

        // Pets filter
        if filter.pets != .any {
            filtered = filtered.filter { user in
                user.pets == filter.pets
            }
        }

        // Children filters
        if filter.hasChildren != .any {
            filtered = filtered.filter { user in
                user.hasChildren == filter.hasChildren
            }
        }

        if filter.wantsChildren != .any {
            filtered = filtered.filter { user in
                user.wantsChildren == filter.wantsChildren
            }
        }

        // Relationship goals
        if !filter.relationshipGoals.isEmpty {
            filtered = filtered.filter { user in
                guard let goal = user.relationshipGoal else { return false }
                return filter.relationshipGoals.contains(goal)
            }
        }

        // Verified only
        if filter.verifiedOnly {
            filtered = filtered.filter { $0.isVerified }
        }

        // With photos only
        if filter.withPhotosOnly {
            filtered = filtered.filter { !$0.photos.isEmpty }
        }

        // Active in last X days
        if let days = filter.activeInLastDays {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
            filtered = filtered.filter { user in
                guard let lastActive = user.lastActiveDate else { return false }
                return lastActive >= cutoffDate
            }
        }

        // New users (joined in last 30 days)
        if filter.newUsers {
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            filtered = filtered.filter { user in
                user.joinedDate >= thirtyDaysAgo
            }
        }

        // Zodiac signs
        if !filter.zodiacSigns.isEmpty {
            filtered = filtered.filter { user in
                guard let sign = user.zodiacSign else { return false }
                return filter.zodiacSigns.contains(sign)
            }
        }

        // Political views
        if !filter.politicalViews.isEmpty {
            filtered = filtered.filter { user in
                guard let view = user.politicalView else { return false }
                return filter.politicalViews.contains(view)
            }
        }

        return filtered
    }

    // MARK: - Distance Calculation

    /// Calculate distance between two coordinates in miles
    func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)

        let distanceMeters = fromLocation.distance(from: toLocation)
        let distanceMiles = distanceMeters / 1609.34 // Convert to miles

        return distanceMiles
    }

    // MARK: - Sorting

    private func sortByRelevance(_ users: [UserProfile], filter: SearchFilter) -> [UserProfile] {
        return users.sorted { user1, user2 in
            let score1 = calculateRelevanceScore(user1, filter: filter)
            let score2 = calculateRelevanceScore(user2, filter: filter)
            return score1 > score2
        }
    }

    private func calculateRelevanceScore(_ user: UserProfile, filter: SearchFilter) -> Double {
        var score: Double = 0

        // Distance score (closer = higher)
        if let userLocation = filter.location, let profileLocation = user.location {
            let distance = calculateDistance(from: userLocation, to: profileLocation)
            let distanceScore = max(0, 100 - (distance / Double(filter.distanceRadius)) * 100)
            score += distanceScore * 0.3
        }

        // Verification boost
        if user.isVerified {
            score += 20
        }

        // Activity boost (active recently)
        if let lastActive = user.lastActiveDate {
            let hoursSinceActive = Date().timeIntervalSince(lastActive) / 3600
            if hoursSinceActive < 24 {
                score += 15
            } else if hoursSinceActive < 168 { // 7 days
                score += 10
            }
        }

        // Photo count boost
        score += Double(min(user.photos.count, 6)) * 2

        // Bio completeness
        if !user.bio.isEmpty {
            score += 10
        }

        // Profile completeness
        if user.education != nil { score += 5 }
        if user.occupation != nil { score += 5 }
        if user.relationshipGoal != nil { score += 5 }

        return score
    }

    // MARK: - Reset

    func resetFilter() {
        currentFilter.reset()
    }

    // MARK: - Mock Data (For Development)

    private func generateMockProfiles(count: Int) -> [UserProfile] {
        var profiles: [UserProfile] = []

        let names = ["Alex", "Jordan", "Taylor", "Casey", "Morgan", "Riley", "Avery", "Parker", "Quinn", "Sage"]
        let occupations = ["Engineer", "Teacher", "Designer", "Doctor", "Artist", "Writer", "Chef", "Entrepreneur"]
        let bios = [
            "Love to travel and try new foods",
            "Fitness enthusiast and dog lover",
            "Coffee addict and bookworm",
            "Adventure seeker looking for a partner in crime",
            "Music lover and concert goer"
        ]

        for i in 0..<count {
            let age = Int.random(in: 22...45)
            let name = names.randomElement()!
            let distance = Double.random(in: 1...50)

            // Random location within radius
            let baseLat = currentLocation?.latitude ?? 37.7749
            let baseLon = currentLocation?.longitude ?? -122.4194
            let lat = baseLat + Double.random(in: -0.5...0.5)
            let lon = baseLon + Double.random(in: -0.5...0.5)

            let profile = UserProfile(
                id: UUID().uuidString,
                name: name,
                age: age,
                bio: bios.randomElement()!,
                photos: ["photo1", "photo2", "photo3"],
                location: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                occupation: occupations.randomElement(),
                education: EducationLevel.allCases.randomElement(),
                heightInches: Int.random(in: 60...78),
                gender: GenderFilter.allCases.randomElement() ?? .all,
                ethnicity: Ethnicity.allCases.randomElement(),
                religion: Religion.allCases.randomElement(),
                smoking: LifestyleFilter.allCases.randomElement() ?? .any,
                drinking: LifestyleFilter.allCases.randomElement() ?? .any,
                pets: PetPreference.allCases.randomElement() ?? .any,
                hasChildren: LifestyleFilter.allCases.randomElement() ?? .any,
                wantsChildren: LifestyleFilter.allCases.randomElement() ?? .any,
                relationshipGoal: RelationshipGoal.allCases.randomElement(),
                zodiacSign: ZodiacSign.allCases.randomElement(),
                politicalView: PoliticalView.allCases.randomElement(),
                isVerified: Bool.random(),
                lastActiveDate: Date().addingTimeInterval(-Double.random(in: 0...604800)), // Last 7 days
                joinedDate: Date().addingTimeInterval(-Double.random(in: 0...31536000)) // Last year
            )

            profiles.append(profile)
        }

        return profiles
    }
}

// MARK: - User Profile Model

struct UserProfile: Identifiable, Codable {
    let id: String
    var name: String
    var age: Int
    var bio: String
    var photos: [String] // URLs or identifiers
    var location: CLLocationCoordinate2D?

    // Demographics
    var occupation: String?
    var education: EducationLevel?
    var heightInches: Int?
    var gender: GenderFilter
    var ethnicity: Ethnicity?
    var religion: Religion?

    // Lifestyle
    var smoking: LifestyleFilter
    var drinking: LifestyleFilter
    var pets: PetPreference
    var hasChildren: LifestyleFilter
    var wantsChildren: LifestyleFilter
    var exercise: ExerciseFrequency?
    var diet: DietPreference?

    // Preferences
    var relationshipGoal: RelationshipGoal?
    var zodiacSign: ZodiacSign?
    var politicalView: PoliticalView?

    // Status
    var isVerified: Bool
    var lastActiveDate: Date?
    var joinedDate: Date

    // Computed properties
    var heightFormatted: String? {
        guard let inches = heightInches else { return nil }
        return HeightRange.formatHeight(inches)
    }

    var distanceString: String {
        // Would calculate from user's location in production
        return "\(Int.random(in: 1...50)) miles away"
    }
}
