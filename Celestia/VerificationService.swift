//
//  VerificationService.swift
//  Celestia
//
//  Core service for managing user verification (photo, ID, background checks)
//  Coordinates between different verification types and maintains verification status
//
//  SECURITY: Verification status is persisted to Firestore (server-side) as source of truth.
//  Local UserDefaults is only used as a cache and is validated against server on load.
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
    @Published var photoVerified: Bool = false
    @Published var idVerified: Bool = false
    @Published var stripeIdentityVerified: Bool = false  // NEW: Stripe Identity verification
    @Published var backgroundCheckCompleted: Bool = false
    @Published var trustScore: Int = 0 // 0-100
    @Published var isLoadingVerification: Bool = false

    // MARK: - Private Properties

    private let photoVerifier = PhotoVerificationManager.shared
    private let idVerifier = IDVerificationManager.shared  // Kept for legacy/fallback
    private let stripeIdentityManager = StripeIdentityManager.shared  // NEW: Primary ID verification
    private let backgroundChecker = BackgroundCheckManager.shared
    private let defaults = UserDefaults.standard
    private let db = Firestore.firestore()

    // MARK: - Keys (Cache only - source of truth is Firestore)

    private enum CacheKeys {
        static let photoVerified = "cache_verification_photo"
        static let idVerified = "cache_verification_id"
        static let stripeIdentityVerified = "cache_verification_stripe_identity"  // NEW
        static let backgroundCheckCompleted = "cache_verification_background"
        static let lastSyncTimestamp = "cache_verification_sync_timestamp"
    }

    // MARK: - Firestore Fields

    private enum FirestoreFields {
        static let photoVerified = "photoVerified"
        static let photoVerifiedAt = "photoVerifiedAt"
        static let idVerified = "idVerified"  // Legacy on-device verification
        static let idVerifiedAt = "idVerifiedAt"
        static let stripeIdentityVerified = "stripeIdentityVerified"  // NEW: Stripe Identity
        static let stripeIdentityVerifiedAt = "stripeIdentityVerifiedAt"
        static let stripeSessionId = "stripeIdentitySessionId"
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

    // MARK: - Photo Verification

    /// Start photo verification flow
    /// SECURITY: Verification result is persisted to Firestore (server-side)
    func startPhotoVerification(profilePhotos: [UIImage]) async throws -> PhotoVerificationResult {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw VerificationError.notAuthenticated
        }

        Logger.shared.info("Starting photo verification", category: .general)

        // Perform verification
        let result = try await photoVerifier.verifyUser(profilePhotos: profilePhotos)

        if result.isVerified {
            // SECURITY FIX: Persist verification to Firestore (server-side source of truth)
            try await persistPhotoVerification(userId: userId, confidence: result.confidence)

            // Update local state after successful server persistence
            photoVerified = true
            updateLocalCache()
            updateVerificationStatus()
            updateTrustScore()

            // Track analytics
            AnalyticsManager.shared.logEvent(.verificationCompleted, parameters: [
                "type": "photo",
                "confidence": result.confidence
            ])

            Logger.shared.info("Photo verification completed and persisted to server", category: .general)
        } else {
            Logger.shared.warning("Photo verification failed: \(result.failureReason ?? "Unknown")", category: .general)
        }

        return result
    }

    /// Persist photo verification to Firestore
    private func persistPhotoVerification(userId: String, confidence: Double) async throws {
        let updateData: [String: Any] = [
            FirestoreFields.photoVerified: true,
            FirestoreFields.photoVerifiedAt: FieldValue.serverTimestamp(),
            FirestoreFields.verificationMethods: FieldValue.arrayUnion(["photo"])
        ]

        try await db.collection("users").document(userId).updateData(updateData)

        // Update the main isVerified field based on new status
        try await updateServerVerificationStatus(userId: userId)

        Logger.shared.info("Photo verification persisted to Firestore", category: .general)
    }

    // MARK: - ID Verification

    /// Start ID verification flow
    /// SECURITY: Verification result is persisted to Firestore (server-side)
    func startIDVerification(idImage: UIImage, selfieImage: UIImage) async throws -> IDVerificationResult {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw VerificationError.notAuthenticated
        }

        Logger.shared.info("Starting ID verification", category: .general)

        // Perform verification
        let result = try await idVerifier.verifyID(idImage: idImage, selfieImage: selfieImage)

        if result.isVerified {
            // SECURITY FIX: Persist verification to Firestore (server-side source of truth)
            try await persistIDVerification(userId: userId, documentType: result.documentType, confidence: result.confidence)

            // Update local state after successful server persistence
            idVerified = true
            updateLocalCache()
            updateVerificationStatus()
            updateTrustScore()

            // Track analytics
            AnalyticsManager.shared.logEvent(.verificationCompleted, parameters: [
                "type": "id",
                "document_type": result.documentType.rawValue
            ])

            Logger.shared.info("ID verification completed and persisted to server", category: .general)
        } else {
            Logger.shared.warning("ID verification failed: \(result.failureReason ?? "Unknown")", category: .general)
        }

        return result
    }

    /// Persist ID verification to Firestore (Legacy - kept for backwards compatibility)
    private func persistIDVerification(userId: String, documentType: DocumentType, confidence: Double) async throws {
        let updateData: [String: Any] = [
            FirestoreFields.idVerified: true,
            FirestoreFields.idVerifiedAt: FieldValue.serverTimestamp(),
            FirestoreFields.verificationMethods: FieldValue.arrayUnion(["id_\(documentType.rawValue)"])
        ]

        try await db.collection("users").document(userId).updateData(updateData)

        // Update the main isVerified field based on new status
        try await updateServerVerificationStatus(userId: userId)

        Logger.shared.info("ID verification persisted to Firestore", category: .general)
    }

    // MARK: - Stripe Identity Verification (Primary ID Verification)

    /// Start Stripe Identity verification flow (RECOMMENDED)
    /// This is the primary and recommended method for ID verification
    /// Uses Stripe's robust third-party verification service
    ///
    /// - Parameter presentingViewController: The view controller to present from
    /// - Returns: StripeIdentityResult with verification outcome
    func startStripeIdentityVerification(from presentingViewController: UIViewController) async throws -> StripeIdentityResult {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw VerificationError.notAuthenticated
        }

        Logger.shared.info("Starting Stripe Identity verification (primary method)", category: .general)

        // Perform verification using Stripe Identity
        let result = try await stripeIdentityManager.startVerification(from: presentingViewController)

        if result.isVerified {
            // Persist verification to Firestore
            try await persistStripeIdentityVerification(userId: userId, sessionId: result.sessionId)

            // Update local state after successful server persistence
            stripeIdentityVerified = true
            idVerified = true  // Also set legacy flag for compatibility
            updateLocalCache()
            updateVerificationStatus()
            updateTrustScore()

            // Track analytics
            AnalyticsManager.shared.logEvent(.verificationCompleted, parameters: [
                "type": "stripe_identity",
                "session_id": result.sessionId
            ])

            Logger.shared.info("Stripe Identity verification completed and persisted to server", category: .general)
        } else {
            Logger.shared.warning("Stripe Identity verification not completed: \(result.failureReason ?? "Unknown")", category: .general)
        }

        return result
    }

    /// Persist Stripe Identity verification to Firestore
    private func persistStripeIdentityVerification(userId: String, sessionId: String) async throws {
        let updateData: [String: Any] = [
            FirestoreFields.stripeIdentityVerified: true,
            FirestoreFields.stripeIdentityVerifiedAt: FieldValue.serverTimestamp(),
            FirestoreFields.stripeSessionId: sessionId,
            FirestoreFields.idVerified: true,  // Set legacy flag for compatibility
            FirestoreFields.idVerifiedAt: FieldValue.serverTimestamp(),
            FirestoreFields.verificationMethods: FieldValue.arrayUnion(["stripe_identity"])
        ]

        try await db.collection("users").document(userId).updateData(updateData)

        // Update the main isVerified field based on new status
        try await updateServerVerificationStatus(userId: userId)

        Logger.shared.info("Stripe Identity verification persisted to Firestore", category: .general)
    }

    /// Check if user has completed Stripe Identity verification
    var isStripeIdentityVerified: Bool {
        return stripeIdentityVerified
    }

    /// Check if user has any form of ID verification (Stripe or legacy)
    var hasIDVerification: Bool {
        return stripeIdentityVerified || idVerified
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
        // Check for any form of ID verification (Stripe Identity preferred, legacy as fallback)
        let hasIDVerification = stripeIdentityVerified || idVerified

        if photoVerified && hasIDVerification && backgroundCheckCompleted {
            verificationStatus = .fullyVerified
        } else if photoVerified && hasIDVerification {
            verificationStatus = .verified
        } else if stripeIdentityVerified {
            // Stripe Identity alone grants verified status (more trusted than photo)
            verificationStatus = .verified
        } else if photoVerified {
            verificationStatus = .photoVerified
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

        let serverPhotoVerified = data[FirestoreFields.photoVerified] as? Bool ?? false
        let serverStripeIdentityVerified = data[FirestoreFields.stripeIdentityVerified] as? Bool ?? false
        let serverIdVerified = data[FirestoreFields.idVerified] as? Bool ?? false
        let serverBackgroundCheck = data[FirestoreFields.backgroundCheckCompleted] as? Bool ?? false

        // Check for any form of ID verification (Stripe Identity preferred)
        let hasIDVerification = serverStripeIdentityVerified || serverIdVerified

        // Calculate verification status
        let newStatus: VerificationStatus
        let isVerified: Bool

        if serverPhotoVerified && hasIDVerification && serverBackgroundCheck {
            newStatus = .fullyVerified
            isVerified = true
        } else if serverPhotoVerified && hasIDVerification {
            newStatus = .verified
            isVerified = true
        } else if serverStripeIdentityVerified {
            // Stripe Identity alone grants verified status (more trusted than photo-only)
            newStatus = .verified
            isVerified = true
        } else if serverPhotoVerified {
            newStatus = .photoVerified
            isVerified = true  // Photo verification grants basic verified badge
        } else {
            newStatus = .unverified
            isVerified = false
        }

        // Calculate trust score
        var score = 20 // Base score
        if serverPhotoVerified { score += 25 }
        if serverStripeIdentityVerified { score += 35 }  // Stripe Identity worth more (more reliable)
        else if serverIdVerified { score += 30 }  // Legacy ID verification
        if serverBackgroundCheck { score += 20 }
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

        // Base score for completed profile
        score += 20

        // Photo verification
        if photoVerified {
            score += 25
        }

        // ID verification (Stripe Identity is worth more than legacy)
        if stripeIdentityVerified {
            score += 35  // Stripe Identity is more reliable
        } else if idVerified {
            score += 30  // Legacy on-device verification
        }

        // Background check
        if backgroundCheckCompleted {
            score += 20
        }

        trustScore = min(100, score)
        Logger.shared.debug("Local trust score updated: \(trustScore)", category: .general)
    }

    // MARK: - Verification Badge

    func verificationBadge() -> VerificationBadge {
        switch verificationStatus {
        case .unverified:
            return .none
        case .photoVerified:
            return .photo
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
            let serverPhotoVerified = data[FirestoreFields.photoVerified] as? Bool ?? false
            let serverStripeIdentityVerified = data[FirestoreFields.stripeIdentityVerified] as? Bool ?? false
            let serverIdVerified = data[FirestoreFields.idVerified] as? Bool ?? false
            let serverBackgroundCheck = data[FirestoreFields.backgroundCheckCompleted] as? Bool ?? false
            let serverTrustScore = data[FirestoreFields.trustScore] as? Int ?? 0

            // Check for client-side spoofing attempt
            if photoVerified && !serverPhotoVerified {
                Logger.shared.warning("SECURITY: Client claimed photoVerified=true but server says false. Reverting.", category: .security)
            }
            if stripeIdentityVerified && !serverStripeIdentityVerified {
                Logger.shared.warning("SECURITY: Client claimed stripeIdentityVerified=true but server says false. Reverting.", category: .security)
            }
            if idVerified && !serverIdVerified {
                Logger.shared.warning("SECURITY: Client claimed idVerified=true but server says false. Reverting.", category: .security)
            }
            if backgroundCheckCompleted && !serverBackgroundCheck {
                Logger.shared.warning("SECURITY: Client claimed backgroundCheck=true but server says false. Reverting.", category: .security)
            }

            // Update local state from server
            photoVerified = serverPhotoVerified
            stripeIdentityVerified = serverStripeIdentityVerified
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
        photoVerified = defaults.bool(forKey: CacheKeys.photoVerified)
        stripeIdentityVerified = defaults.bool(forKey: CacheKeys.stripeIdentityVerified)
        idVerified = defaults.bool(forKey: CacheKeys.idVerified)
        backgroundCheckCompleted = defaults.bool(forKey: CacheKeys.backgroundCheckCompleted)

        updateVerificationStatus()
        updateTrustScore()

        Logger.shared.debug("Loaded cached verification status (will validate against server)", category: .general)
    }

    /// Update local cache to match current state
    private func updateLocalCache() {
        defaults.set(photoVerified, forKey: CacheKeys.photoVerified)
        defaults.set(stripeIdentityVerified, forKey: CacheKeys.stripeIdentityVerified)
        defaults.set(idVerified, forKey: CacheKeys.idVerified)
        defaults.set(backgroundCheckCompleted, forKey: CacheKeys.backgroundCheckCompleted)
        defaults.set(Date().timeIntervalSince1970, forKey: CacheKeys.lastSyncTimestamp)
    }

    /// Clear local cache (forces re-sync from server)
    func clearCache() {
        defaults.removeObject(forKey: CacheKeys.photoVerified)
        defaults.removeObject(forKey: CacheKeys.stripeIdentityVerified)
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
                FirestoreFields.photoVerified: false,
                FirestoreFields.stripeIdentityVerified: false,
                FirestoreFields.stripeSessionId: FieldValue.delete(),
                FirestoreFields.idVerified: false,
                FirestoreFields.backgroundCheckCompleted: false,
                FirestoreFields.isVerified: false,
                FirestoreFields.verificationStatus: VerificationStatus.unverified.rawValue,
                FirestoreFields.trustScore: 0,
                FirestoreFields.verificationMethods: []
            ])

            // Then reset local state
            photoVerified = false
            stripeIdentityVerified = false
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
    case photoVerified = "photo_verified"
    case verified = "verified"
    case fullyVerified = "fully_verified"

    var displayName: String {
        switch self {
        case .unverified:
            return "Not Verified"
        case .photoVerified:
            return "Photo Verified"
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
        case .photoVerified:
            return "checkmark.shield"
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
    case photo
    case verified
    case premium

    var icon: String {
        switch self {
        case .none:
            return ""
        case .photo:
            return "checkmark.circle.fill"
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
        case .photo:
            return "blue"
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
    case noProfilePhotos
    case verificationFailed
    case networkError
    case invalidID
    case faceNotDetected
    case facesMismatch
    case notAuthenticated
    case serverPersistFailed

    var errorDescription: String? {
        switch self {
        case .consentRequired:
            return "User consent is required for background checks"
        case .noProfilePhotos:
            return "No profile photos available for verification"
        case .verificationFailed:
            return "Verification failed. Please try again."
        case .networkError:
            return "Network error during verification"
        case .invalidID:
            return "Invalid ID document"
        case .faceNotDetected:
            return "Face not detected in photo"
        case .facesMismatch:
            return "Faces do not match"
        case .notAuthenticated:
            return "You must be logged in to verify your identity"
        case .serverPersistFailed:
            return "Failed to save verification status. Please try again."
        }
    }
}
