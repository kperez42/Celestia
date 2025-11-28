//
//  VerificationService.swift
//  Celestia
//
//  Core service for managing user verification (ID, background checks)
//  Coordinates between different verification types and maintains verification status
//
//  SECURITY: Verification status is persisted to Firestore (server-side) as source of truth.
//  Local UserDefaults is only used as a cache and is validated against server on load.
//
//  NOTE: Face verification has been removed. ID verification is now manual review only.
//

import Foundation
import UIKit
import FirebaseFirestore
import FirebaseAuth

// MARK: - Verification Service

@MainActor
class VerificationService: ObservableObject {

    // MARK: - Singleton

    static let shared = VerificationService()

    // MARK: - Published Properties

    @Published var verificationStatus: VerificationStatus = .unverified
    @Published var idVerified: Bool = false
    @Published var backgroundCheckCompleted: Bool = false
    @Published var trustScore: Int = 0 // 0-100
    @Published var isLoadingVerification: Bool = false

    // MARK: - Private Properties

    private let backgroundChecker = BackgroundCheckManager.shared
    private let defaults = UserDefaults.standard
    private let db = Firestore.firestore()

    // MARK: - Keys (Cache only - source of truth is Firestore)

    private enum CacheKeys {
        static let idVerified = "cache_verification_id"
        static let backgroundCheckCompleted = "cache_verification_background"
        static let lastSyncTimestamp = "cache_verification_sync_timestamp"
    }

    // MARK: - Firestore Fields

    private enum FirestoreFields {
        static let idVerified = "idVerified"
        static let idVerifiedAt = "idVerifiedAt"
        static let backgroundCheckCompleted = "backgroundCheckCompleted"
        static let backgroundCheckAt = "backgroundCheckAt"
        static let isVerified = "isVerified"  // Main verification badge field
        static let verificationStatus = "verificationStatus"
        static let verificationMethods = "verificationMethods"
        static let trustScore = "trustScore"
    }

    // MARK: - Initialization

    private init() {
        // SECURITY: Load cached values for immediate UI, then validate against server
        loadCachedStatus()

        Logger.shared.info("VerificationService initialized", category: .general)

        // Sync with server in background
        Task {
            await syncVerificationStatusFromServer()
        }
    }

    // MARK: - ID Verification (Manual Review)
    // Note: ID verification is now handled through ManualIDVerificationView
    // Admin reviews submissions in the admin panel and approves/rejects them
    // This service just tracks the verification status from the server

    /// Check if user has ID verification
    var hasIDVerification: Bool {
        return idVerified
    }

    // MARK: - Background Check

    /// Request background check (premium feature)
    /// SECURITY: Verification result is persisted to Firestore (server-side)
    func requestBackgroundCheck(consent: Bool) async throws -> BackgroundCheckResult {
        guard consent else {
            throw VerificationError.consentRequired
        }

        guard let userId = Auth.auth().currentUser?.uid else {
            throw VerificationError.notAuthenticated
        }

        Logger.shared.info("Starting background check", category: .general)

        // Perform background check
        let result = try await backgroundChecker.performBackgroundCheck()

        if result.isClean {
            // SECURITY FIX: Persist verification to Firestore (server-side source of truth)
            try await persistBackgroundCheck(userId: userId)

            // Update local state after successful server persistence
            backgroundCheckCompleted = true
            updateLocalCache()
            updateVerificationStatus()
            updateTrustScore()

            // Track analytics
            AnalyticsManager.shared.logEvent(.verificationCompleted, parameters: [
                "type": "background_check",
                "clean": result.isClean
            ])

            Logger.shared.info("Background check completed and persisted to server", category: .general)
        } else {
            Logger.shared.warning("Background check found issues", category: .general)
        }

        return result
    }

    /// Persist background check to Firestore
    private func persistBackgroundCheck(userId: String) async throws {
        let updateData: [String: Any] = [
            FirestoreFields.backgroundCheckCompleted: true,
            FirestoreFields.backgroundCheckAt: FieldValue.serverTimestamp(),
            FirestoreFields.verificationMethods: FieldValue.arrayUnion(["background_check"])
        ]

        try await db.collection("users").document(userId).updateData(updateData)

        // Update the main isVerified field based on new status
        try await updateServerVerificationStatus(userId: userId)

        Logger.shared.info("Background check persisted to Firestore", category: .general)
    }

    // MARK: - Verification Status

    private func updateVerificationStatus() {
        if idVerified && backgroundCheckCompleted {
            verificationStatus = .fullyVerified
        } else if idVerified {
            verificationStatus = .verified
        } else {
            verificationStatus = .unverified
        }

        Logger.shared.debug("Local verification status updated: \(verificationStatus.rawValue)", category: .general)
    }

    /// Update verification status on server (source of truth)
    /// SECURITY: This determines the isVerified badge shown to other users
    private func updateServerVerificationStatus(userId: String) async throws {
        // Fetch current verification state from server
        let doc = try await db.collection("users").document(userId).getDocument()
        let data = doc.data() ?? [:]

        let serverIdVerified = data[FirestoreFields.idVerified] as? Bool ?? false
        let serverBackgroundCheck = data[FirestoreFields.backgroundCheckCompleted] as? Bool ?? false

        // Calculate verification status
        let newStatus: VerificationStatus
        let isVerified: Bool

        if serverIdVerified && serverBackgroundCheck {
            newStatus = .fullyVerified
            isVerified = true
        } else if serverIdVerified {
            newStatus = .verified
            isVerified = true
        } else {
            newStatus = .unverified
            isVerified = false
        }

        // Calculate trust score (ID verification + background check)
        var score = 20 // Base score for having an account
        if serverIdVerified { score += 50 }  // ID verification is worth the most
        if serverBackgroundCheck { score += 30 }
        let newTrustScore = min(100, score)

        // Update server with calculated values
        try await db.collection("users").document(userId).updateData([
            FirestoreFields.isVerified: isVerified,
            FirestoreFields.verificationStatus: newStatus.rawValue,
            FirestoreFields.trustScore: newTrustScore
        ])

        Logger.shared.info("Server verification status updated: \(newStatus.rawValue), isVerified: \(isVerified)", category: .general)
    }

    // MARK: - Trust Score

    private func updateTrustScore() {
        var score = 0

        // Base score for having an account
        score += 20

        // ID verification (manual review)
        if idVerified {
            score += 50  // ID verification is worth the most
        }

        // Background check
        if backgroundCheckCompleted {
            score += 30
        }

        trustScore = min(100, score)
        Logger.shared.debug("Local trust score updated: \(trustScore)", category: .general)
    }

    // MARK: - Verification Badge

    func verificationBadge() -> VerificationBadge {
        switch verificationStatus {
        case .unverified:
            return .none
        case .verified:
            return .verified
        case .fullyVerified:
            return .premium
        }
    }

    // MARK: - Server Sync (Source of Truth)

    /// Sync verification status from Firestore (server-side source of truth)
    /// SECURITY: This validates that client-side cache matches server state
    func syncVerificationStatusFromServer() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            Logger.shared.debug("No user logged in, skipping verification sync", category: .general)
            return
        }

        isLoadingVerification = true
        defer { isLoadingVerification = false }

        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            let data = doc.data() ?? [:]

            // SECURITY: Server values override local cache
            let serverIdVerified = data[FirestoreFields.idVerified] as? Bool ?? false
            let serverBackgroundCheck = data[FirestoreFields.backgroundCheckCompleted] as? Bool ?? false
            let serverTrustScore = data[FirestoreFields.trustScore] as? Int ?? 0

            // Check for client-side spoofing attempt
            if idVerified && !serverIdVerified {
                Logger.shared.warning("SECURITY: Client claimed idVerified=true but server says false. Reverting.", category: .security)
            }
            if backgroundCheckCompleted && !serverBackgroundCheck {
                Logger.shared.warning("SECURITY: Client claimed backgroundCheck=true but server says false. Reverting.", category: .security)
            }

            // Update local state from server
            idVerified = serverIdVerified
            backgroundCheckCompleted = serverBackgroundCheck
            trustScore = serverTrustScore

            // Update local verification status
            updateVerificationStatus()

            // Update cache to match server
            updateLocalCache()

            Logger.shared.info("Verification status synced from server: \(verificationStatus.rawValue)", category: .general)

        } catch {
            Logger.shared.error("Failed to sync verification status from server", category: .general, error: error)
            // On error, keep using cached values but log the discrepancy
        }
    }

    // MARK: - Local Cache Management

    /// Load cached verification status for immediate UI display
    /// SECURITY: This is only a cache - server is authoritative
    private func loadCachedStatus() {
        idVerified = defaults.bool(forKey: CacheKeys.idVerified)
        backgroundCheckCompleted = defaults.bool(forKey: CacheKeys.backgroundCheckCompleted)

        updateVerificationStatus()
        updateTrustScore()

        Logger.shared.debug("Loaded cached verification status (will validate against server)", category: .general)
    }

    /// Update local cache to match current state
    private func updateLocalCache() {
        defaults.set(idVerified, forKey: CacheKeys.idVerified)
        defaults.set(backgroundCheckCompleted, forKey: CacheKeys.backgroundCheckCompleted)
        defaults.set(Date().timeIntervalSince1970, forKey: CacheKeys.lastSyncTimestamp)
    }

    /// Clear local cache (forces re-sync from server)
    func clearCache() {
        defaults.removeObject(forKey: CacheKeys.idVerified)
        defaults.removeObject(forKey: CacheKeys.backgroundCheckCompleted)
        defaults.removeObject(forKey: CacheKeys.lastSyncTimestamp)

        Logger.shared.info("Verification cache cleared", category: .general)
    }

    // MARK: - Reset (for testing)

    /// Reset verification status (removes from server and cache)
    /// WARNING: This should only be used for testing
    func resetVerification() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            Logger.shared.warning("Cannot reset verification: no user logged in", category: .general)
            return
        }

        do {
            // Reset on server first
            try await db.collection("users").document(userId).updateData([
                FirestoreFields.idVerified: false,
                FirestoreFields.backgroundCheckCompleted: false,
                FirestoreFields.isVerified: false,
                FirestoreFields.verificationStatus: VerificationStatus.unverified.rawValue,
                FirestoreFields.trustScore: 0,
                FirestoreFields.verificationMethods: []
            ])

            // Then reset local state
            idVerified = false
            backgroundCheckCompleted = false
            verificationStatus = .unverified
            trustScore = 0

            // Clear cache
            clearCache()

            Logger.shared.info("Verification status reset on server and locally", category: .general)
        } catch {
            Logger.shared.error("Failed to reset verification on server", category: .general, error: error)
        }
    }
}

// MARK: - Verification Status

enum VerificationStatus: String, Codable {
    case unverified = "unverified"
    case verified = "verified"
    case fullyVerified = "fully_verified"

    var displayName: String {
        switch self {
        case .unverified:
            return "Not Verified"
        case .verified:
            return "Verified"
        case .fullyVerified:
            return "Fully Verified"
        }
    }

    var icon: String {
        switch self {
        case .unverified:
            return "xmark.shield"
        case .verified:
            return "checkmark.shield.fill"
        case .fullyVerified:
            return "crown.fill"
        }
    }
}

// MARK: - Verification Badge

enum VerificationBadge {
    case none
    case verified
    case premium

    var icon: String {
        switch self {
        case .none:
            return ""
        case .verified:
            return "checkmark.seal.fill"
        case .premium:
            return "crown.fill"
        }
    }

    var color: String {
        switch self {
        case .none:
            return "gray"
        case .verified:
            return "green"
        case .premium:
            return "purple"
        }
    }
}

// MARK: - Errors

enum VerificationError: LocalizedError {
    case consentRequired
    case verificationFailed
    case networkError
    case invalidID
    case notAuthenticated
    case serverPersistFailed

    var errorDescription: String? {
        switch self {
        case .consentRequired:
            return "User consent is required for background checks"
        case .verificationFailed:
            return "Verification failed. Please try again."
        case .networkError:
            return "Network error during verification"
        case .invalidID:
            return "Invalid ID document"
        case .notAuthenticated:
            return "You must be logged in to verify your identity"
        case .serverPersistFailed:
            return "Failed to save verification status. Please try again."
        }
    }
}
