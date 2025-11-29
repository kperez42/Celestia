//
//  DiscoveryFilters.swift
//  Celestia
//
//  Discovery filter preferences
//

import Foundation

@MainActor
class DiscoveryFilters: ObservableObject {
    static let shared = DiscoveryFilters()

    @Published var maxDistance: Double = 50 // miles
    @Published var minAge: Int = 18
    @Published var maxAge: Int = 65
    @Published var showVerifiedOnly: Bool = false
    @Published var selectedInterests: Set<String> = []
    @Published var dealBreakers: Set<String> = []

    // Advanced Filters
    @Published var educationLevels: Set<String> = []
    @Published var minHeight: Int? = nil // cm
    @Published var maxHeight: Int? = nil // cm
    @Published var religions: Set<String> = []
    @Published var relationshipGoals: Set<String> = []
    @Published var smokingPreferences: Set<String> = []
    @Published var drinkingPreferences: Set<String> = []
    @Published var petPreferences: Set<String> = []
    @Published var exercisePreferences: Set<String> = []
    @Published var dietPreferences: Set<String> = []

    private init() {
        loadFromUserDefaults()
    }

    // MARK: - Filter Logic

    func matchesFilters(user: User, currentUserLocation: (lat: Double, lon: Double)?) -> Bool {
        // Validate age bounds to prevent crashes
        guard user.age > 0, user.age < 150 else {
            Logger.shared.warning("Invalid user age: \(user.age)", category: .matching)
            return false
        }

        // Age filter
        if user.age < minAge || user.age > maxAge {
            return false
        }

        // Verification filter
        if showVerifiedOnly && !user.isVerified {
            return false
        }

        // Distance filter
        if let currentLocation = currentUserLocation,
           let userLat = user.latitude,
           let userLon = user.longitude {
            let distance = calculateDistance(
                from: currentLocation,
                to: (userLat, userLon)
            )
            if distance > maxDistance {
                return false
            }
        }

        // Interest filter (if any selected, user must have at least one match)
        if !selectedInterests.isEmpty {
            let userInterests = Set(user.interests)
            if selectedInterests.intersection(userInterests).isEmpty {
                return false
            }
        }

        // Education level filter
        if !educationLevels.isEmpty {
            guard let userEducation = user.educationLevel else {
                return false
            }
            if !educationLevels.contains(userEducation) {
                return false
            }
        }

        // Height filter
        if let userHeight = user.height {
            if let min = minHeight, userHeight < min {
                return false
            }
            if let max = maxHeight, userHeight > max {
                return false
            }
        } else {
            // If user hasn't set height and we have height filters, exclude them
            if minHeight != nil || maxHeight != nil {
                return false
            }
        }

        // Religion filter
        if !religions.isEmpty {
            guard let userReligion = user.religion else {
                return false
            }
            if !religions.contains(userReligion) {
                return false
            }
        }

        // Relationship goal filter
        if !relationshipGoals.isEmpty {
            guard let userGoal = user.relationshipGoal else {
                return false
            }
            if !relationshipGoals.contains(userGoal) {
                return false
            }
        }

        // Smoking preference filter
        if !smokingPreferences.isEmpty {
            guard let userSmoking = user.smoking else {
                return false
            }
            if !smokingPreferences.contains(userSmoking) {
                return false
            }
        }

        // Drinking preference filter
        if !drinkingPreferences.isEmpty {
            guard let userDrinking = user.drinking else {
                return false
            }
            if !drinkingPreferences.contains(userDrinking) {
                return false
            }
        }

        // Pet preference filter
        if !petPreferences.isEmpty {
            guard let userPets = user.pets else {
                return false
            }
            if !petPreferences.contains(userPets) {
                return false
            }
        }

        // Exercise preference filter
        if !exercisePreferences.isEmpty {
            guard let userExercise = user.exercise else {
                return false
            }
            if !exercisePreferences.contains(userExercise) {
                return false
            }
        }

        // Diet preference filter
        if !dietPreferences.isEmpty {
            guard let userDiet = user.diet else {
                return false
            }
            if !dietPreferences.contains(userDiet) {
                return false
            }
        }

        return true
    }

    private func calculateDistance(from: (lat: Double, lon: Double), to: (lat: Double, lon: Double)) -> Double {
        // Validate coordinates
        guard isValidLatitude(from.lat), isValidLongitude(from.lon),
              isValidLatitude(to.lat), isValidLongitude(to.lon) else {
            Logger.shared.warning("Invalid coordinates: from(\(from.lat), \(from.lon)) to(\(to.lat), \(to.lon))", category: .matching)
            return Double.infinity // Return max distance for invalid coordinates
        }

        let earthRadiusMiles = 3958.8

        let lat1 = from.lat * .pi / 180
        let lon1 = from.lon * .pi / 180
        let lat2 = to.lat * .pi / 180
        let lon2 = to.lon * .pi / 180

        let dLat = lat2 - lat1
        let dLon = lon2 - lon1

        let a = sin(dLat/2) * sin(dLat/2) + cos(lat1) * cos(lat2) * sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))

        let distance = earthRadiusMiles * c

        // Validate result
        guard distance.isFinite, distance >= 0 else {
            Logger.shared.warning("Invalid distance calculation result: \(distance)", category: .matching)
            return Double.infinity
        }

        return distance
    }

    private func isValidLatitude(_ lat: Double) -> Bool {
        return lat >= -90 && lat <= 90 && lat.isFinite
    }

    private func isValidLongitude(_ lon: Double) -> Bool {
        return lon >= -180 && lon <= 180 && lon.isFinite
    }

    // MARK: - Persistence

    func saveToUserDefaults() {
        UserDefaults.standard.set(maxDistance, forKey: "maxDistance")
        UserDefaults.standard.set(minAge, forKey: "minAge")
        UserDefaults.standard.set(maxAge, forKey: "maxAge")
        UserDefaults.standard.set(showVerifiedOnly, forKey: "showVerifiedOnly")
        UserDefaults.standard.set(Array(selectedInterests), forKey: "selectedInterests")

        // Advanced Filters
        UserDefaults.standard.set(Array(educationLevels), forKey: "educationLevels")
        UserDefaults.standard.set(minHeight, forKey: "minHeight")
        UserDefaults.standard.set(maxHeight, forKey: "maxHeight")
        UserDefaults.standard.set(Array(religions), forKey: "religions")
        UserDefaults.standard.set(Array(relationshipGoals), forKey: "relationshipGoals")
        UserDefaults.standard.set(Array(smokingPreferences), forKey: "smokingPreferences")
        UserDefaults.standard.set(Array(drinkingPreferences), forKey: "drinkingPreferences")
        UserDefaults.standard.set(Array(petPreferences), forKey: "petPreferences")
        UserDefaults.standard.set(Array(exercisePreferences), forKey: "exercisePreferences")
        UserDefaults.standard.set(Array(dietPreferences), forKey: "dietPreferences")
    }

    private func loadFromUserDefaults() {
        if let distance = UserDefaults.standard.object(forKey: "maxDistance") as? Double {
            maxDistance = distance
        }
        if let min = UserDefaults.standard.object(forKey: "minAge") as? Int {
            minAge = min
        }
        if let max = UserDefaults.standard.object(forKey: "maxAge") as? Int {
            maxAge = max
        }
        showVerifiedOnly = UserDefaults.standard.bool(forKey: "showVerifiedOnly")
        if let interests = UserDefaults.standard.array(forKey: "selectedInterests") as? [String] {
            selectedInterests = Set(interests)
        }

        // Advanced Filters
        if let education = UserDefaults.standard.array(forKey: "educationLevels") as? [String] {
            educationLevels = Set(education)
        }
        minHeight = UserDefaults.standard.object(forKey: "minHeight") as? Int
        maxHeight = UserDefaults.standard.object(forKey: "maxHeight") as? Int
        if let religionArray = UserDefaults.standard.array(forKey: "religions") as? [String] {
            religions = Set(religionArray)
        }
        if let goals = UserDefaults.standard.array(forKey: "relationshipGoals") as? [String] {
            relationshipGoals = Set(goals)
        }
        if let smoking = UserDefaults.standard.array(forKey: "smokingPreferences") as? [String] {
            smokingPreferences = Set(smoking)
        }
        if let drinking = UserDefaults.standard.array(forKey: "drinkingPreferences") as? [String] {
            drinkingPreferences = Set(drinking)
        }
        if let pets = UserDefaults.standard.array(forKey: "petPreferences") as? [String] {
            petPreferences = Set(pets)
        }
        if let exercise = UserDefaults.standard.array(forKey: "exercisePreferences") as? [String] {
            exercisePreferences = Set(exercise)
        }
        if let diet = UserDefaults.standard.array(forKey: "dietPreferences") as? [String] {
            dietPreferences = Set(diet)
        }
    }

    func resetFilters() {
        maxDistance = 50
        minAge = 18
        maxAge = 65
        showVerifiedOnly = false
        selectedInterests.removeAll()

        // Reset Advanced Filters
        educationLevels.removeAll()
        minHeight = nil
        maxHeight = nil
        religions.removeAll()
        relationshipGoals.removeAll()
        smokingPreferences.removeAll()
        drinkingPreferences.removeAll()
        petPreferences.removeAll()
        exercisePreferences.removeAll()
        dietPreferences.removeAll()

        saveToUserDefaults()
    }

    var hasActiveFilters: Bool {
        // Removed distance from active filters check - not using location-based filtering
        return minAge > 18 || maxAge < 65 || showVerifiedOnly || !selectedInterests.isEmpty ||
               !educationLevels.isEmpty || minHeight != nil || maxHeight != nil ||
               !religions.isEmpty || !relationshipGoals.isEmpty ||
               !smokingPreferences.isEmpty || !drinkingPreferences.isEmpty ||
               !petPreferences.isEmpty || !exercisePreferences.isEmpty || !dietPreferences.isEmpty
    }
}
