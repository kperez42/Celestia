//
//  ProfileBoostService.swift
//  Celestia
//
//  Profile Boost functionality - temporarily increases profile visibility
//

import Foundation
import FirebaseFirestore

@MainActor
class ProfileBoostService: ObservableObject {
    static let shared = ProfileBoostService()

    @Published var isBoostActive: Bool = false
    @Published var boostExpiresAt: Date?
    @Published var timeRemaining: TimeInterval = 0

    private let db = Firestore.firestore()
    private let authService = AuthService.shared
    private var boostTimer: Timer?

    // Boost duration: 30 minutes
    private let boostDuration: TimeInterval = 30 * 60 // 30 minutes

    private init() {
        // Check if user has active boost on init
        Task {
            await checkActiveBoost()
        }
    }

    /// Check if user has an active boost
    func checkActiveBoost() async {
        guard let user = authService.currentUser else { return }

        if user.isBoostActive, let expiryDate = user.boostExpiryDate {
            if expiryDate > Date() {
                // Boost is still active
                isBoostActive = true
                boostExpiresAt = expiryDate
                timeRemaining = expiryDate.timeIntervalSince(Date())
                startBoostTimer()
            } else {
                // Boost expired, deactivate it
                await deactivateBoost()
            }
        }
    }

    /// Activate profile boost
    func activateBoost() async throws {
        // BUGFIX: Use effectiveId for reliable user identification
        guard let currentUser = authService.currentUser,
              let userId = currentUser.effectiveId else {
            throw ProfileBoostError.noCurrentUser
        }

        // Check if user has boosts remaining
        guard currentUser.boostsRemaining > 0 else {
            throw ProfileBoostError.noBoostsRemaining
        }

        // Check if boost is already active
        if currentUser.isBoostActive, let expiryDate = currentUser.boostExpiryDate, expiryDate > Date() {
            throw ProfileBoostError.boostAlreadyActive
        }

        let expiryDate = Date().addingTimeInterval(boostDuration)

        // Update Firestore
        try await db.collection("users").document(userId).updateData([
            "isBoostActive": true,
            "boostExpiryDate": Timestamp(date: expiryDate),
            "boostsRemaining": FieldValue.increment(Int64(-1)),
            "lastBoostActivatedAt": FieldValue.serverTimestamp()
        ])

        // Update local state
        await MainActor.run {
            self.isBoostActive = true
            self.boostExpiresAt = expiryDate
            self.timeRemaining = boostDuration
        }

        // Refresh user data
        await authService.fetchUser()

        // Start countdown timer
        startBoostTimer()

        // Send analytics event
        Logger.shared.info("Profile boost activated for 30 minutes", category: .user)

        // Trigger haptic feedback
        HapticManager.shared.notification(.success)
    }

    /// Deactivate profile boost (when it expires)
    private func deactivateBoost() async {
        guard let userId = authService.currentUser?.effectiveId else { return }

        do {
            try await db.collection("users").document(userId).updateData([
                "isBoostActive": false,
                "boostExpiryDate": FieldValue.delete()
            ])

            await MainActor.run {
                self.isBoostActive = false
                self.boostExpiresAt = nil
                self.timeRemaining = 0
                self.boostTimer?.invalidate()
                self.boostTimer = nil
            }

            await authService.fetchUser()

            Logger.shared.info("Profile boost expired and deactivated", category: .user)

        } catch {
            Logger.shared.error("Error deactivating boost", category: .user, error: error)
        }
    }

    /// Start countdown timer
    private func startBoostTimer() {
        boostTimer?.invalidate()

        boostTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                if let expiryDate = self.boostExpiresAt {
                    self.timeRemaining = expiryDate.timeIntervalSince(Date())

                    if self.timeRemaining <= 0 {
                        // Boost expired
                        await self.deactivateBoost()
                    }
                }
            }
        }
    }

    /// Get formatted time remaining string
    func getFormattedTimeRemaining() -> String {
        guard isBoostActive, timeRemaining > 0 else {
            return "Inactive"
        }

        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60

        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Cancel boost early (optional - allows users to stop boost)
    func cancelBoost() async {
        guard isBoostActive else { return }

        await deactivateBoost()
        Logger.shared.info("Profile boost cancelled by user", category: .user)
    }

    deinit {
        boostTimer?.invalidate()
    }
}

// MARK: - Errors

enum ProfileBoostError: LocalizedError {
    case noCurrentUser
    case noBoostsRemaining
    case boostAlreadyActive

    var errorDescription: String? {
        switch self {
        case .noCurrentUser:
            return "No user is currently logged in"
        case .noBoostsRemaining:
            return "You don't have any boosts remaining. Upgrade to Premium for more boosts!"
        case .boostAlreadyActive:
            return "Your profile boost is already active"
        }
    }
}
