//
//  DiscoveryFilters.swift
//  Celestia
//
//  Discovery filter preferences
//

import Foundation

class DiscoveryFilters: ObservableObject {
    static let shared = DiscoveryFilters()

    @Published var maxDistance: Double = 50 // miles
    @Published var minAge: Int = 18
    @Published var maxAge: Int = 65
    @Published var showVerifiedOnly: Bool = false
    @Published var selectedInterests: Set<String> = []
    @Published var dealBreakers: Set<String> = []

    private init() {
        loadFromUserDefaults()
    }

    // MARK: - Filter Logic

    func matchesFilters(user: User, currentUserLocation: (lat: Double, lon: Double)?) -> Bool {
        // Age filter
        if user.age < minAge || user.age > maxAge {
            return false
        }

        // Verification filter
        if showVerifiedOnly && !user.isVerified {
            return false
        }

        // Distance filter
        if let currentLocation = currentUserLocation {
            let distance = calculateDistance(
                from: currentLocation,
                to: (user.latitude, user.longitude)
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

        return true
    }

    private func calculateDistance(from: (lat: Double, lon: Double), to: (lat: Double, lon: Double)) -> Double {
        let earthRadiusMiles = 3958.8

        let lat1 = from.lat * .pi / 180
        let lon1 = from.lon * .pi / 180
        let lat2 = to.lat * .pi / 180
        let lon2 = to.lon * .pi / 180

        let dLat = lat2 - lat1
        let dLon = lon2 - lon1

        let a = sin(dLat/2) * sin(dLat/2) + cos(lat1) * cos(lat2) * sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))

        return earthRadiusMiles * c
    }

    // MARK: - Persistence

    func saveToUserDefaults() {
        UserDefaults.standard.set(maxDistance, forKey: "maxDistance")
        UserDefaults.standard.set(minAge, forKey: "minAge")
        UserDefaults.standard.set(maxAge, forKey: "maxAge")
        UserDefaults.standard.set(showVerifiedOnly, forKey: "showVerifiedOnly")
        UserDefaults.standard.set(Array(selectedInterests), forKey: "selectedInterests")
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
    }

    func resetFilters() {
        maxDistance = 50
        minAge = 18
        maxAge = 65
        showVerifiedOnly = false
        selectedInterests.removeAll()
        saveToUserDefaults()
    }

    var hasActiveFilters: Bool {
        return maxDistance < 100 || minAge > 18 || maxAge < 65 || showVerifiedOnly || !selectedInterests.isEmpty
    }
}
