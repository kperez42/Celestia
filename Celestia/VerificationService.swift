//
//  VerificationService.swift
//  Celestia
//
//  Core service for managing user verification (photo, ID, background checks)
//  Coordinates between different verification types and maintains verification status
//

import Foundation
import UIKit

// MARK: - Verification Service

@MainActor
class VerificationService: ObservableObject {

    // MARK: - Singleton

    static let shared = VerificationService()

    // MARK: - Published Properties

    @Published var verificationStatus: VerificationStatus = .unverified
    @Published var photoVerified: Bool = false
    @Published var idVerified: Bool = false
    @Published var backgroundCheckCompleted: Bool = false
    @Published var trustScore: Int = 0 // 0-100

    // MARK: - Private Properties

    private let photoVerifier = PhotoVerificationManager.shared
    private let idVerifier = IDVerificationManager.shared
    private let backgroundChecker = BackgroundCheckManager.shared
    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let photoVerified = "verification_photo_verified"
        static let idVerified = "verification_id_verified"
        static let backgroundCheckCompleted = "verification_background_check"
        static let verificationStatus = "verification_status"
        static let trustScore = "verification_trust_score"
    }

    // MARK: - Initialization

    private init() {
        loadVerificationStatus()
        updateTrustScore()
        Logger.shared.info("VerificationService initialized", category: .general)
    }

    // MARK: - Photo Verification

    /// Start photo verification flow
    func startPhotoVerification(profilePhotos: [UIImage]) async throws -> PhotoVerificationResult {
        Logger.shared.info("Starting photo verification", category: .general)

        // Perform verification
        let result = try await photoVerifier.verifyUser(profilePhotos: profilePhotos)

        if result.isVerified {
            photoVerified = true
            defaults.set(true, forKey: Keys.photoVerified)
            updateVerificationStatus()
            updateTrustScore()

            // Track analytics
            AnalyticsManager.shared.logEvent(.verificationCompleted, parameters: [
                "type": "photo",
                "confidence": result.confidence
            ])

            Logger.shared.info("Photo verification completed successfully", category: .general)
        } else {
            Logger.shared.warning("Photo verification failed: \(result.failureReason ?? "Unknown")", category: .general)
        }

        return result
    }

    // MARK: - ID Verification

    /// Start ID verification flow
    func startIDVerification(idImage: UIImage, selfieImage: UIImage) async throws -> IDVerificationResult {
        Logger.shared.info("Starting ID verification", category: .general)

        // Perform verification
        let result = try await idVerifier.verifyID(idImage: idImage, selfieImage: selfieImage)

        if result.isVerified {
            idVerified = true
            defaults.set(true, forKey: Keys.idVerified)
            updateVerificationStatus()
            updateTrustScore()

            // Track analytics
            AnalyticsManager.shared.logEvent(.verificationCompleted, parameters: [
                "type": "id",
                "document_type": result.documentType.rawValue
            ])

            Logger.shared.info("ID verification completed successfully", category: .general)
        } else {
            Logger.shared.warning("ID verification failed: \(result.failureReason ?? "Unknown")", category: .general)
        }

        return result
    }

    // MARK: - Background Check

    /// Request background check (premium feature)
    func requestBackgroundCheck(consent: Bool) async throws -> BackgroundCheckResult {
        guard consent else {
            throw VerificationError.consentRequired
        }

        Logger.shared.info("Starting background check", category: .general)

        // Perform background check
        let result = try await backgroundChecker.performBackgroundCheck()

        if result.isClean {
            backgroundCheckCompleted = true
            defaults.set(true, forKey: Keys.backgroundCheckCompleted)
            updateVerificationStatus()
            updateTrustScore()

            // Track analytics
            AnalyticsManager.shared.logEvent(.verificationCompleted, parameters: [
                "type": "background_check",
                "clean": result.isClean
            ])

            Logger.shared.info("Background check completed", category: .general)
        } else {
            Logger.shared.warning("Background check found issues", category: .general)
        }

        return result
    }

    // MARK: - Verification Status

    private func updateVerificationStatus() {
        if photoVerified && idVerified && backgroundCheckCompleted {
            verificationStatus = .fullyVerified
        } else if photoVerified && idVerified {
            verificationStatus = .verified
        } else if photoVerified {
            verificationStatus = .photoVerified
        } else {
            verificationStatus = .unverified
        }

        defaults.set(verificationStatus.rawValue, forKey: Keys.verificationStatus)
        Logger.shared.debug("Verification status updated: \(verificationStatus.rawValue)", category: .general)
    }

    // MARK: - Trust Score

    private func updateTrustScore() {
        var score = 0

        // Base score for completed profile
        score += 20

        // Photo verification
        if photoVerified {
            score += 30
        }

        // ID verification
        if idVerified {
            score += 30
        }

        // Background check
        if backgroundCheckCompleted {
            score += 20
        }

        trustScore = min(100, score)
        defaults.set(trustScore, forKey: Keys.trustScore)

        Logger.shared.debug("Trust score updated: \(trustScore)", category: .general)
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

    // MARK: - Load/Save

    private func loadVerificationStatus() {
        photoVerified = defaults.bool(forKey: Keys.photoVerified)
        idVerified = defaults.bool(forKey: Keys.idVerified)
        backgroundCheckCompleted = defaults.bool(forKey: Keys.backgroundCheckCompleted)
        trustScore = defaults.integer(forKey: Keys.trustScore)

        if let statusRaw = defaults.string(forKey: Keys.verificationStatus),
           let status = VerificationStatus(rawValue: statusRaw) {
            verificationStatus = status
        }
    }

    // MARK: - Reset (for testing)

    func resetVerification() {
        photoVerified = false
        idVerified = false
        backgroundCheckCompleted = false
        verificationStatus = .unverified
        trustScore = 0

        defaults.removeObject(forKey: Keys.photoVerified)
        defaults.removeObject(forKey: Keys.idVerified)
        defaults.removeObject(forKey: Keys.backgroundCheckCompleted)
        defaults.removeObject(forKey: Keys.verificationStatus)
        defaults.removeObject(forKey: Keys.trustScore)

        Logger.shared.info("Verification status reset", category: .general)
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
        }
    }
}
