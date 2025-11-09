//
//  DiscoveryFilters.swift
//  Celestia
//
//  Service for managing discovery filters
//

import Foundation
import Combine

class DiscoveryFilters: ObservableObject {
    static let shared = DiscoveryFilters()

    @Published var maxDistance: Double {
        didSet {
            saveToUserDefaults()
        }
    }

    @Published var minAge: Int {
        didSet {
            // Ensure minAge is not greater than maxAge
            if minAge > maxAge {
                maxAge = minAge
            }
            saveToUserDefaults()
        }
    }

    @Published var maxAge: Int {
        didSet {
            // Ensure maxAge is not less than minAge
            if maxAge < minAge {
                minAge = maxAge
            }
            saveToUserDefaults()
        }
    }

    @Published var showVerifiedOnly: Bool {
        didSet {
            saveToUserDefaults()
        }
    }

    @Published var selectedInterests: Set<String> {
        didSet {
            saveToUserDefaults()
        }
    }

    private init() {
        // Load from UserDefaults or use defaults
        self.maxDistance = UserDefaults.standard.double(forKey: "maxDistance") > 0
            ? UserDefaults.standard.double(forKey: "maxDistance")
            : 50.0

        self.minAge = UserDefaults.standard.integer(forKey: "minAge") > 0
            ? UserDefaults.standard.integer(forKey: "minAge")
            : 18

        self.maxAge = UserDefaults.standard.integer(forKey: "maxAge") > 0
            ? UserDefaults.standard.integer(forKey: "maxAge")
            : 35

        self.showVerifiedOnly = UserDefaults.standard.bool(forKey: "showVerifiedOnly")

        if let interestsData = UserDefaults.standard.data(forKey: "selectedInterests"),
           let interests = try? JSONDecoder().decode(Set<String>.self, from: interestsData) {
            self.selectedInterests = interests
        } else {
            self.selectedInterests = []
        }
    }

    func saveToUserDefaults() {
        UserDefaults.standard.set(maxDistance, forKey: "maxDistance")
        UserDefaults.standard.set(minAge, forKey: "minAge")
        UserDefaults.standard.set(maxAge, forKey: "maxAge")
        UserDefaults.standard.set(showVerifiedOnly, forKey: "showVerifiedOnly")

        if let interestsData = try? JSONEncoder().encode(selectedInterests) {
            UserDefaults.standard.set(interestsData, forKey: "selectedInterests")
        }
    }

    func resetFilters() {
        maxDistance = 50.0
        minAge = 18
        maxAge = 35
        showVerifiedOnly = false
        selectedInterests = []
    }

    var hasActiveFilters: Bool {
        maxDistance != 50.0 ||
        minAge != 18 ||
        maxAge != 35 ||
        showVerifiedOnly ||
        !selectedInterests.isEmpty
    }

    func matches(user: User, currentUser: User) -> Bool {
        // Distance check
        if let userLat = user.latitude,
           let userLong = user.longitude,
           let currentLat = currentUser.latitude,
           let currentLong = currentUser.longitude {
            let distance = calculateDistance(
                lat1: currentLat,
                lon1: currentLong,
                lat2: userLat,
                lon2: userLong
            )
            if distance > maxDistance {
                return false
            }
        }

        // Age check
        if user.age < minAge || user.age > maxAge {
            return false
        }

        // Verification check
        if showVerifiedOnly && !user.isVerified {
            return false
        }

        // Interest check
        if !selectedInterests.isEmpty {
            let hasMatchingInterest = !Set(user.interests).intersection(selectedInterests).isEmpty
            if !hasMatchingInterest {
                return false
            }
        }

        return true
    }

    private func calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let earthRadius = 3958.8 // miles

        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180

        let a = sin(dLat/2) * sin(dLat/2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLon/2) * sin(dLon/2)

        let c = 2 * atan2(sqrt(a), sqrt(1-a))

        return earthRadius * c
    }
}
