//
//  StripeIdentityManager.swift
//  Celestia
//
//  Third-party ID verification using Stripe Identity SDK
//  This replaces the on-device face recognition with Stripe's robust verification service
//
//  INTEGRATION: Requires StripeIdentity SDK via Swift Package Manager
//  Add: https://github.com/stripe/stripe-ios to your project
//
//  PRICING: $1.50 per verification (first 50 free)
//  DOCS: https://docs.stripe.com/identity
//

import Foundation
import UIKit
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions
import StripeIdentity

// MARK: - Stripe Configuration

enum StripeConfig {
    /// Stripe Publishable Key (safe to include in app)
    static let publishableKey = "pk_live_51Il3uhFgeBuSpm7JQHQEi7J8FdQnbkzndYl2Jeq0EKOjmZidgEwd7wacFpWgujpnAbCrLDOiiPESLPjNAQZ9V2h000FbzP66S5"

    /// Configure Stripe SDK - call this in AppDelegate/App init
    static func configure() {
        STPAPIClient.shared.publishableKey = publishableKey
    }
}

// MARK: - Stripe Identity Manager

@MainActor
class StripeIdentityManager: ObservableObject {

    // MARK: - Singleton

    static let shared = StripeIdentityManager()

    // MARK: - Published Properties

    @Published var isVerifying: Bool = false
    @Published var verificationStatus: StripeVerificationStatus = .unverified
    @Published var lastError: StripeIdentityError?

    // MARK: - Private Properties

    private let db = Firestore.firestore()
    private let functions = Functions.functions()

    // MARK: - Configuration

    /// Backend endpoint to create verification session
    /// Your backend should call Stripe API to create a VerificationSession
    private let createSessionEndpoint = "createStripeIdentitySession"

    // MARK: - Firestore Fields

    private enum FirestoreFields {
        static let stripeVerified = "stripeIdentityVerified"
        static let stripeVerifiedAt = "stripeIdentityVerifiedAt"
        static let stripeSessionId = "stripeIdentitySessionId"
        static let stripeVerificationStatus = "stripeVerificationStatus"
        static let verificationMethods = "verificationMethods"
    }

    // MARK: - Initialization

    private init() {
        Logger.shared.info("StripeIdentityManager initialized", category: .general)
    }

    // MARK: - Public Methods

    /// Start the Stripe Identity verification flow
    /// This creates a verification session and presents the Stripe Identity sheet
    ///
    /// - Parameter presentingViewController: The view controller to present from
    /// - Returns: StripeIdentityResult with verification outcome
    func startVerification(from presentingViewController: UIViewController) async throws -> StripeIdentityResult {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw StripeIdentityError.notAuthenticated
        }

        isVerifying = true
        lastError = nil

        defer {
            isVerifying = false
        }

        Logger.shared.info("Starting Stripe Identity verification", category: .general)

        // Track analytics
        AnalyticsManager.shared.logEvent(.verificationAttempt, parameters: [
            "type": "stripe_identity",
            "step": "started"
        ])

        do {
            // Step 1: Create verification session via backend
            let sessionData = try await createVerificationSession(userId: userId)

            // Step 2: Present the Stripe Identity verification sheet
            let result = try await presentVerificationSheet(
                verificationSessionId: sessionData.sessionId,
                ephemeralKeySecret: sessionData.ephemeralKeySecret,
                from: presentingViewController
            )

            // Step 3: Handle the result
            switch result.status {
            case .verified:
                // Persist verification to Firestore
                try await persistVerification(userId: userId, sessionId: sessionData.sessionId)

                verificationStatus = .verified

                AnalyticsManager.shared.logEvent(.verificationCompleted, parameters: [
                    "type": "stripe_identity",
                    "success": true
                ])

                Logger.shared.info("Stripe Identity verification completed successfully", category: .general)

                return StripeIdentityResult(
                    isVerified: true,
                    sessionId: sessionData.sessionId,
                    status: .verified
                )

            case .canceled:
                verificationStatus = .canceled

                AnalyticsManager.shared.logEvent(.verificationCompleted, parameters: [
                    "type": "stripe_identity",
                    "success": false,
                    "reason": "canceled"
                ])

                Logger.shared.info("Stripe Identity verification canceled by user", category: .general)

                return StripeIdentityResult(
                    isVerified: false,
                    sessionId: sessionData.sessionId,
                    status: .canceled,
                    failureReason: "Verification was canceled"
                )

            case .failed:
                verificationStatus = .failed

                AnalyticsManager.shared.logEvent(.verificationCompleted, parameters: [
                    "type": "stripe_identity",
                    "success": false,
                    "reason": "failed"
                ])

                Logger.shared.warning("Stripe Identity verification failed", category: .general)

                return StripeIdentityResult(
                    isVerified: false,
                    sessionId: sessionData.sessionId,
                    status: .failed,
                    failureReason: result.failureReason ?? "Verification failed"
                )

            case .requiresInput:
                verificationStatus = .requiresInput

                Logger.shared.info("Stripe Identity verification requires additional input", category: .general)

                return StripeIdentityResult(
                    isVerified: false,
                    sessionId: sessionData.sessionId,
                    status: .requiresInput,
                    failureReason: "Additional information required"
                )

            case .processing:
                verificationStatus = .processing

                Logger.shared.info("Stripe Identity verification is processing", category: .general)

                return StripeIdentityResult(
                    isVerified: false,
                    sessionId: sessionData.sessionId,
                    status: .processing,
                    failureReason: "Verification is being processed"
                )

            case .unverified:
                verificationStatus = .unverified

                Logger.shared.info("Stripe Identity verification not completed", category: .general)

                return StripeIdentityResult(
                    isVerified: false,
                    sessionId: sessionData.sessionId,
                    status: .unverified,
                    failureReason: "Verification not completed"
                )

            case .unknown:
                verificationStatus = .unknown

                Logger.shared.warning("Stripe Identity verification returned unknown status", category: .general)

                return StripeIdentityResult(
                    isVerified: false,
                    sessionId: sessionData.sessionId,
                    status: .unknown,
                    failureReason: "Unknown verification status"
                )
            }

        } catch {
            lastError = error as? StripeIdentityError ?? .unknown(error.localizedDescription)
            verificationStatus = .failed

            AnalyticsManager.shared.logEvent(.verificationCompleted, parameters: [
                "type": "stripe_identity",
                "success": false,
                "error": error.localizedDescription
            ])

            Logger.shared.error("Stripe Identity verification error", category: .general, error: error)
            throw error
        }
    }

    /// Check verification status for a session
    func checkVerificationStatus(sessionId: String) async throws -> StripeVerificationStatus {
        guard Auth.auth().currentUser != nil else {
            throw StripeIdentityError.notAuthenticated
        }

        Logger.shared.info("Checking Stripe Identity verification status for session: \(sessionId)", category: .general)

        // Call backend to check status
        let result = try await functions.httpsCallable("checkStripeIdentityStatus").call([
            "sessionId": sessionId
        ])

        guard let data = result.data as? [String: Any],
              let statusString = data["status"] as? String else {
            throw StripeIdentityError.invalidResponse
        }

        let status = StripeVerificationStatus(rawValue: statusString) ?? .unknown
        verificationStatus = status

        return status
    }

    /// Sync verification status from Firestore
    func syncVerificationStatus() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            Logger.shared.debug("No user logged in, skipping Stripe verification sync", category: .general)
            return
        }

        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            let data = doc.data() ?? [:]

            let serverVerified = data[FirestoreFields.stripeVerified] as? Bool ?? false
            let statusString = data[FirestoreFields.stripeVerificationStatus] as? String

            if serverVerified {
                verificationStatus = .verified
            } else if let statusString = statusString {
                verificationStatus = StripeVerificationStatus(rawValue: statusString) ?? .unverified
            } else {
                verificationStatus = .unverified
            }

            Logger.shared.info("Synced Stripe verification status: \(verificationStatus.rawValue)", category: .general)

        } catch {
            Logger.shared.error("Failed to sync Stripe verification status", category: .general, error: error)
        }
    }

    // MARK: - Private Methods

    /// Create a verification session via Firebase Cloud Functions
    private func createVerificationSession(userId: String) async throws -> VerificationSessionData {
        Logger.shared.info("Creating Stripe Identity verification session", category: .general)

        let result = try await functions.httpsCallable(createSessionEndpoint).call([
            "userId": userId
        ])

        guard let data = result.data as? [String: Any],
              let sessionId = data["verificationSessionId"] as? String,
              let ephemeralKeySecret = data["ephemeralKeySecret"] as? String else {
            throw StripeIdentityError.invalidResponse
        }

        Logger.shared.info("Created verification session: \(sessionId)", category: .general)

        return VerificationSessionData(
            sessionId: sessionId,
            ephemeralKeySecret: ephemeralKeySecret
        )
    }

    /// Present the Stripe Identity verification sheet
    /// Uses the real Stripe Identity SDK to verify user's ID + selfie
    private func presentVerificationSheet(
        verificationSessionId: String,
        ephemeralKeySecret: String,
        from viewController: UIViewController
    ) async throws -> StripeSheetResult {

        Logger.shared.info("Presenting Stripe Identity verification sheet", category: .general)

        // Configure the verification sheet with brand logo
        let brandLogo = UIImage(named: "AppIcon") ?? UIImage(named: "app_logo") ?? UIImage()
        let configuration = IdentityVerificationSheet.Configuration(brandLogo: brandLogo)

        // Create the Identity Verification Sheet
        let sheet = IdentityVerificationSheet(
            verificationSessionId: verificationSessionId,
            ephemeralKeySecret: ephemeralKeySecret,
            configuration: configuration
        )

        // Present the sheet and wait for result
        return await withCheckedContinuation { continuation in
            sheet.present(from: viewController) { result in
                switch result {
                case .flowCompleted:
                    // User completed the verification flow
                    // Note: This doesn't mean verified yet - Stripe may still be processing
                    Logger.shared.info("Stripe Identity flow completed", category: .general)
                    continuation.resume(returning: StripeSheetResult(status: .verified))

                case .flowCanceled:
                    // User dismissed the sheet
                    Logger.shared.info("Stripe Identity flow canceled by user", category: .general)
                    continuation.resume(returning: StripeSheetResult(status: .canceled))

                case .flowFailed(let error):
                    // An error occurred
                    Logger.shared.error("Stripe Identity flow failed", category: .general, error: error)
                    continuation.resume(returning: StripeSheetResult(
                        status: .failed,
                        failureReason: error.localizedDescription
                    ))

                @unknown default:
                    // Handle future SDK cases
                    Logger.shared.warning("Unknown Stripe Identity result", category: .general)
                    continuation.resume(returning: StripeSheetResult(
                        status: .unknown,
                        failureReason: "Unknown verification result"
                    ))
                }
            }
        }
    }

    /// Persist successful verification to Firestore
    private func persistVerification(userId: String, sessionId: String) async throws {
        let updateData: [String: Any] = [
            FirestoreFields.stripeVerified: true,
            FirestoreFields.stripeVerifiedAt: FieldValue.serverTimestamp(),
            FirestoreFields.stripeSessionId: sessionId,
            FirestoreFields.stripeVerificationStatus: StripeVerificationStatus.verified.rawValue,
            FirestoreFields.verificationMethods: FieldValue.arrayUnion(["stripe_identity"])
        ]

        try await db.collection("users").document(userId).updateData(updateData)

        Logger.shared.info("Stripe Identity verification persisted to Firestore", category: .general)
    }
}

// MARK: - Supporting Types

struct VerificationSessionData {
    let sessionId: String
    let ephemeralKeySecret: String
}

struct StripeSheetResult {
    let status: StripeVerificationStatus
    let failureReason: String?

    init(status: StripeVerificationStatus, failureReason: String? = nil) {
        self.status = status
        self.failureReason = failureReason
    }
}

// MARK: - Stripe Verification Status

enum StripeVerificationStatus: String, Codable {
    case unverified = "unverified"
    case verified = "verified"
    case processing = "processing"
    case requiresInput = "requires_input"
    case canceled = "canceled"
    case failed = "failed"
    case unknown = "unknown"

    var displayName: String {
        switch self {
        case .unverified:
            return "Not Verified"
        case .verified:
            return "ID Verified"
        case .processing:
            return "Processing"
        case .requiresInput:
            return "Additional Info Required"
        case .canceled:
            return "Canceled"
        case .failed:
            return "Failed"
        case .unknown:
            return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .unverified:
            return "xmark.shield"
        case .verified:
            return "checkmark.shield.fill"
        case .processing:
            return "clock"
        case .requiresInput:
            return "exclamationmark.triangle"
        case .canceled:
            return "xmark.circle"
        case .failed:
            return "xmark.octagon"
        case .unknown:
            return "questionmark.circle"
        }
    }

    var isVerified: Bool {
        return self == .verified
    }
}

// MARK: - Stripe Identity Result

struct StripeIdentityResult {
    let isVerified: Bool
    let sessionId: String
    let status: StripeVerificationStatus
    let failureReason: String?
    let verifiedAt: Date

    init(
        isVerified: Bool,
        sessionId: String,
        status: StripeVerificationStatus,
        failureReason: String? = nil
    ) {
        self.isVerified = isVerified
        self.sessionId = sessionId
        self.status = status
        self.failureReason = failureReason
        self.verifiedAt = Date()
    }
}

// MARK: - Stripe Identity Errors

enum StripeIdentityError: LocalizedError {
    case notAuthenticated
    case sessionCreationFailed
    case verificationFailed(String)
    case invalidResponse
    case networkError
    case sdkNotConfigured
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to verify your identity"
        case .sessionCreationFailed:
            return "Failed to create verification session"
        case .verificationFailed(let reason):
            return "Verification failed: \(reason)"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError:
            return "Network error during verification"
        case .sdkNotConfigured:
            return "Stripe Identity SDK not configured"
        case .unknown(let message):
            return "An error occurred: \(message)"
        }
    }
}

// MARK: - SwiftUI View Controller Wrapper

/// Helper to get the presenting view controller in SwiftUI
struct ViewControllerHolder {
    weak var value: UIViewController?
}

struct ViewControllerKey: EnvironmentKey {
    static var defaultValue: ViewControllerHolder {
        return ViewControllerHolder(value: UIApplication.shared.windows.first?.rootViewController)
    }
}

extension EnvironmentValues {
    var viewController: UIViewController? {
        get { return self[ViewControllerKey.self].value }
        set { self[ViewControllerKey.self].value = newValue }
    }
}
