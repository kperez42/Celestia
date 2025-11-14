//
//  MatchingAlgorithm.swift
//  Celestia
//
//  Profile compatibility scoring algorithm
//  Calculates compatibility based on shared interests, preferences, demographics, and location
//

import Foundation
import CoreLocation

class MatchingAlgorithm {
    static let shared = MatchingAlgorithm()

    private init() {}

    // MARK: - Main Compatibility Scoring

    /// Calculate overall compatibility score between two users
    /// Returns a score between 0.0 (incompatible) and 1.0 (highly compatible)
    func calculateCompatibilityScore(currentUser: User, candidate: User) -> Double {
        var totalScore = 0.0
        var componentCount = 0.0

        // 1. Interest Overlap Score (weighted 30%)
        let interestScore = calculateInterestScore(currentUser: currentUser, candidate: candidate)
        totalScore += interestScore * 0.30
        componentCount += 0.30

        // 2. Language Compatibility Score (weighted 15%)
        let languageScore = calculateLanguageScore(currentUser: currentUser, candidate: candidate)
        totalScore += languageScore * 0.15
        componentCount += 0.15

        // 3. Age Compatibility Score (weighted 15%)
        let ageScore = calculateAgeCompatibilityScore(currentUser: currentUser, candidate: candidate)
        totalScore += ageScore * 0.15
        componentCount += 0.15

        // 4. Lifestyle Compatibility Score (weighted 20%)
        let lifestyleScore = calculateLifestyleCompatibilityScore(currentUser: currentUser, candidate: candidate)
        totalScore += lifestyleScore * 0.20
        componentCount += 0.20

        // 5. Relationship Goal Alignment (weighted 15%)
        let goalScore = calculateRelationshipGoalScore(currentUser: currentUser, candidate: candidate)
        totalScore += goalScore * 0.15
        componentCount += 0.15

        // 6. Profile Completeness Bonus (weighted 5%)
        let completenessBonus = calculateProfileCompletenessBonus(candidate)
        totalScore += completenessBonus * 0.05
        componentCount += 0.05

        return totalScore / componentCount
    }

    // MARK: - Component Scores

    /// Calculate interest overlap score
    /// Higher score when users share more interests
    func calculateInterestScore(currentUser: User, candidate: User) -> Double {
        let userInterests = Set(currentUser.interests)
        let candidateInterests = Set(candidate.interests)

        guard !userInterests.isEmpty || !candidateInterests.isEmpty else {
            return 0.5 // Neutral score if no interests defined
        }

        // Calculate Jaccard similarity
        let intersection = userInterests.intersection(candidateInterests)
        let union = userInterests.union(candidateInterests)

        guard !union.isEmpty else { return 0.5 }

        let jaccardScore = Double(intersection.count) / Double(union.count)

        // Boost score if they have many shared interests
        let sharedCount = intersection.count
        let bonus: Double = {
            if sharedCount >= 5 { return 0.2 }
            if sharedCount >= 3 { return 0.1 }
            return 0.0
        }()

        return min(jaccardScore + bonus, 1.0)
    }

    /// Calculate language compatibility score
    /// Higher score when users share common languages
    func calculateLanguageScore(currentUser: User, candidate: User) -> Double {
        let userLanguages = Set(currentUser.languages)
        let candidateLanguages = Set(candidate.languages)

        guard !userLanguages.isEmpty && !candidateLanguages.isEmpty else {
            return 0.5 // Neutral if languages not specified
        }

        let commonLanguages = userLanguages.intersection(candidateLanguages)

        if commonLanguages.isEmpty {
            return 0.2 // Low score for no common languages
        }

        // Score based on number of common languages
        let score = min(Double(commonLanguages.count) * 0.4, 1.0)
        return score
    }

    /// Calculate age compatibility score
    /// Score based on age difference and user preferences
    func calculateAgeCompatibilityScore(currentUser: User, candidate: User) -> Double {
        let candidateAge = candidate.age

        // Check if candidate's age is within current user's preferred range
        if candidateAge < currentUser.ageRangeMin || candidateAge > currentUser.ageRangeMax {
            return 0.0 // Outside preferred range
        }

        // Calculate ideal age (middle of range)
        let idealAge = (currentUser.ageRangeMin + currentUser.ageRangeMax) / 2
        let ageDifference = abs(candidateAge - idealAge)
        let rangeSpan = currentUser.ageRangeMax - currentUser.ageRangeMin

        // Score decreases as age moves away from ideal
        guard rangeSpan > 0 else { return 1.0 }

        let score = 1.0 - (Double(ageDifference) / Double(rangeSpan))
        return max(score, 0.0)
    }

    /// Calculate lifestyle compatibility score
    /// Based on smoking, drinking, exercise, diet preferences
    func calculateLifestyleCompatibilityScore(currentUser: User, candidate: User) -> Double {
        var matchCount = 0
        var totalComparisons = 0

        // Compare smoking preferences
        if let userSmoking = currentUser.smoking, let candidateSmoking = candidate.smoking {
            if userSmoking == candidateSmoking {
                matchCount += 1
            } else if (userSmoking == "Never" && candidateSmoking == "Socially") ||
                      (userSmoking == "Socially" && candidateSmoking == "Never") {
                matchCount += 0 // Partial mismatch
            }
            totalComparisons += 1
        }

        // Compare drinking preferences
        if let userDrinking = currentUser.drinking, let candidateDrinking = candidate.drinking {
            if userDrinking == candidateDrinking {
                matchCount += 1
            } else if (userDrinking == "Socially" && candidateDrinking == "Regularly") ||
                      (userDrinking == "Regularly" && candidateDrinking == "Socially") {
                matchCount += 0 // Partial match
            }
            totalComparisons += 1
        }

        // Compare exercise habits
        if let userExercise = currentUser.exercise, let candidateExercise = candidate.exercise {
            if userExercise == candidateExercise {
                matchCount += 1
            }
            totalComparisons += 1
        }

        // Compare diet preferences
        if let userDiet = currentUser.diet, let candidateDiet = candidate.diet {
            if userDiet == candidateDiet {
                matchCount += 1
            }
            totalComparisons += 1
        }

        // Compare pet preferences
        if let userPets = currentUser.pets, let candidatePets = candidate.pets {
            if userPets == candidatePets {
                matchCount += 1
            }
            totalComparisons += 1
        }

        guard totalComparisons > 0 else {
            return 0.5 // Neutral if no lifestyle data available
        }

        return Double(matchCount) / Double(totalComparisons)
    }

    /// Calculate relationship goal alignment score
    func calculateRelationshipGoalScore(currentUser: User, candidate: User) -> Double {
        guard let userGoal = currentUser.relationshipGoal,
              let candidateGoal = candidate.relationshipGoal else {
            return 0.5 // Neutral if goals not specified
        }

        // Exact match = perfect score
        if userGoal == candidateGoal {
            return 1.0
        }

        // Partial matches (e.g., "Long-term" and "Open to either")
        let compatibleGoals: [String: [String]] = [
            "Long-term": ["Open to anything", "See where it goes"],
            "Short-term": ["Open to anything", "Casual"],
            "Casual": ["Short-term", "Open to anything"],
            "Friendship": ["Open to anything"],
            "Open to anything": ["Long-term", "Short-term", "Casual", "Friendship"]
        ]

        if let compatible = compatibleGoals[userGoal], compatible.contains(candidateGoal) {
            return 0.6 // Partial compatibility
        }

        return 0.2 // Incompatible goals
    }

    /// Calculate profile completeness bonus
    /// Reward users with complete profiles
    func calculateProfileCompletenessBonus(_ user: User) -> Double {
        var completenessPoints = 0
        var maxPoints = 10

        // Check various profile fields
        if !user.bio.isEmpty { completenessPoints += 1 }
        if !user.interests.isEmpty { completenessPoints += 1 }
        if !user.languages.isEmpty { completenessPoints += 1 }
        if !user.photos.isEmpty { completenessPoints += 1 }
        if user.prompts.count >= 2 { completenessPoints += 1 }
        if user.educationLevel != nil { completenessPoints += 1 }
        if user.height != nil { completenessPoints += 1 }
        if user.relationshipGoal != nil { completenessPoints += 1 }
        if user.exercise != nil { completenessPoints += 1 }
        if user.diet != nil { completenessPoints += 1 }

        return Double(completenessPoints) / Double(maxPoints)
    }

    // MARK: - Geographic Scoring

    /// Calculate proximity score based on distance between users
    /// Returns higher score for users closer together
    func calculateProximityScore(currentUser: User, candidate: User) -> Double {
        // Check if both users have location data
        guard let userLat = currentUser.latitude,
              let userLon = currentUser.longitude,
              let candLat = candidate.latitude,
              let candLon = candidate.longitude else {
            return 0.5 // Neutral score if location not available
        }

        // Calculate distance in kilometers
        let userLocation = CLLocation(latitude: userLat, longitude: userLon)
        let candidateLocation = CLLocation(latitude: candLat, longitude: candLon)
        let distanceKm = userLocation.distance(from: candidateLocation) / 1000.0

        // Use user's max distance preference
        let maxDistance = Double(currentUser.maxDistance)

        // Outside preferred distance = low score
        if distanceKm > maxDistance {
            return 0.1
        }

        // Score decreases linearly with distance
        let score = 1.0 - (distanceKm / maxDistance)
        return max(score, 0.0)
    }

    // MARK: - Explanation Generation

    /// Generate compatibility reasons for UI display
    /// Returns top reasons why two users are compatible
    func generateCompatibilityReasons(currentUser: User, candidate: User) -> [String] {
        var reasons: [String] = []

        // Check for shared interests
        let sharedInterests = Set(currentUser.interests).intersection(Set(candidate.interests))
        if sharedInterests.count >= 3 {
            let interestList = Array(sharedInterests.prefix(3)).joined(separator: ", ")
            reasons.append("You both love \(interestList)")
        } else if sharedInterests.count > 0 {
            reasons.append("Shared interest in \(sharedInterests.first!)")
        }

        // Check for shared languages
        let sharedLanguages = Set(currentUser.languages).intersection(Set(candidate.languages))
        if sharedLanguages.count > 0 {
            reasons.append("Speak the same language: \(sharedLanguages.first!)")
        }

        // Check age compatibility
        if candidate.age >= currentUser.ageRangeMin && candidate.age <= currentUser.ageRangeMax {
            let idealAge = (currentUser.ageRangeMin + currentUser.ageRangeMax) / 2
            if abs(candidate.age - idealAge) <= 2 {
                reasons.append("Perfect age match")
            }
        }

        // Check relationship goals
        if let userGoal = currentUser.relationshipGoal,
           let candGoal = candidate.relationshipGoal,
           userGoal == candGoal {
            reasons.append("Same relationship goals")
        }

        // Check lifestyle compatibility
        if let userExercise = currentUser.exercise,
           let candExercise = candidate.exercise,
           userExercise == candExercise {
            reasons.append("Similar fitness lifestyle")
        }

        // Check location proximity
        if let userLat = currentUser.latitude,
           let userLon = currentUser.longitude,
           let candLat = candidate.latitude,
           let candLon = candidate.longitude {
            let distance = CLLocation(latitude: userLat, longitude: userLon)
                .distance(from: CLLocation(latitude: candLat, longitude: candLon)) / 1000.0

            if distance < 5 {
                reasons.append("Very close to you!")
            } else if distance < 20 {
                reasons.append("Nearby")
            }
        }

        // Premium badge
        if candidate.isPremium {
            reasons.append("Premium member")
        }

        // Verified badge
        if candidate.isVerified {
            reasons.append("Verified profile")
        }

        return Array(reasons.prefix(3)) // Return top 3 reasons
    }
}
