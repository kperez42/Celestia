//
//  SafetyManager.swift
//  Celestia
//
//  Main coordinator for all safety features
//  Integrates verification, detection, reporting, and check-in systems
//

import Foundation
import UIKit

// MARK: - Safety Manager

@MainActor
class SafetyManager: ObservableObject {

    // MARK: - Singleton

    static let shared = SafetyManager()

    // MARK: - Services

    let verificationService = VerificationService.shared
    let fakeProfileDetector = FakeProfileDetector.shared
    let scammerDetector = ScammerDetector.shared
    let reportingManager = ReportingManager.shared
    let checkInManager = DateCheckInManager.shared
    let emergencyContactManager = EmergencyContactManager.shared

    // MARK: - Published Properties

    @Published var safetyScore: Int = 0 // 0-100
    @Published var safetyTips: [SafetyTip] = []
    @Published var activeAlerts: [SafetyAlert] = []

    // MARK: - Initialization

    private init() {
        calculateSafetyScore()
        loadSafetyTips()
        Logger.shared.info("SafetyManager initialized", category: .general)
    }

    // MARK: - Safety Score

    /// Calculate overall safety score
    func calculateSafetyScore() {
        var score = 0

        // Verification (40 points)
        score += verificationService.trustScore / 100 * 40

        // Emergency contacts (20 points)
        if emergencyContactManager.hasContacts() {
            score += 20
        }

        // Profile completeness (20 points)
        // In production, check actual profile data
        score += 15

        // Active safety features (20 points)
        if verificationService.idVerified {
            score += 10
        }
        if verificationService.backgroundCheckCompleted {
            score += 5
        }
        if emergencyContactManager.contacts.count >= 2 {
            score += 5
        }

        safetyScore = min(100, score)

        Logger.shared.debug("Safety score calculated: \(safetyScore)", category: .general)
    }

    // MARK: - Profile Safety Check

    /// Comprehensive safety check for a user profile
    func checkProfileSafety(
        userId: String,
        photos: [UIImage],
        bio: String,
        name: String,
        age: Int,
        location: String?
    ) async -> ProfileSafetyReport {

        Logger.shared.info("Running comprehensive safety check for user: \(userId)", category: .general)

        // Run fake profile detection
        let fakeProfileAnalysis = await fakeProfileDetector.analyzeProfile(
            photos: photos,
            bio: bio,
            name: name,
            age: age,
            location: location
        )

        // Determine overall safety
        let isSafe = !fakeProfileAnalysis.isSuspicious

        // Generate recommendations
        var recommendations: [String] = []

        if fakeProfileAnalysis.isSuspicious {
            recommendations.append("Profile shows signs of being fake or suspicious")
            recommendations.append("Consider reporting this profile if behavior is concerning")
        }

        if !verificationService.idVerified {
            recommendations.append("This user has not verified their ID")
        }

        let report = ProfileSafetyReport(
            userId: userId,
            isSafe: isSafe,
            safetyLevel: determineSafetyLevel(fakeProfileAnalysis.suspicionScore),
            fakeProfileAnalysis: fakeProfileAnalysis,
            verificationStatus: verificationService.verificationStatus,
            trustScore: verificationService.trustScore,
            recommendations: recommendations
        )

        Logger.shared.info("Safety check completed. Level: \(report.safetyLevel.rawValue)", category: .general)

        return report
    }

    // MARK: - Conversation Safety Check

    /// Check conversation for scam patterns
    func checkConversationSafety(messages: [ChatMessage]) async -> ConversationSafetyReport {
        Logger.shared.info("Checking conversation safety", category: .general)

        // Run scammer detection
        let scamAnalysis = scammerDetector.analyzeConversation(messages: messages)

        // Determine if conversation is safe
        let isSafe = !scamAnalysis.isScam

        // Generate warnings
        var warnings: [String] = []

        if scamAnalysis.isScam {
            warnings.append("⚠️ This conversation shows signs of a scam")

            for scamType in scamAnalysis.scamTypes {
                warnings.append(scamType.description)
            }
        }

        if scamAnalysis.escalationDetected {
            warnings.append("⚠️ Suspicious behavior is escalating over time")
        }

        let report = ConversationSafetyReport(
            isSafe: isSafe,
            scamAnalysis: scamAnalysis,
            warnings: warnings,
            recommendation: scamAnalysis.recommendation
        )

        // Create alert if dangerous
        if !isSafe {
            createSafetyAlert(
                type: .scamDetected,
                message: "Potential scam detected in conversation",
                severity: .high
            )
        }

        return report
    }

    // MARK: - Safety Alerts

    /// Create a safety alert
    /// NOTE: Defers state modification to avoid "Modifying state during view update" warning
    func createSafetyAlert(type: SafetyAlertType, message: String, severity: AlertSeverity) {
        let alert = SafetyAlert(
            id: UUID().uuidString,
            type: type,
            message: message,
            severity: severity,
            createdAt: Date()
        )

        // FIX: Defer state modification to next run loop to avoid SwiftUI warning
        Task { @MainActor in
            activeAlerts.append(alert)
        }

        Logger.shared.warning("Safety alert created: \(type.rawValue)", category: .general)

        // Track analytics
        AnalyticsManager.shared.logEvent(.safetyAlertCreated, parameters: [
            "type": type.rawValue,
            "severity": severity.rawValue
        ])
    }

    /// Dismiss alert
    func dismissAlert(_ alert: SafetyAlert) {
        // FIX: Defer state modification to avoid SwiftUI warning
        Task { @MainActor in
            activeAlerts.removeAll { $0.id == alert.id }
        }
    }

    // MARK: - Safety Tips

    private func loadSafetyTips() {
        // Load all tips from all categories
        safetyTips = TipCategory.allCases.flatMap { category in
            SafetyTip.tips(for: category)
        }
    }

    // MARK: - Helpers

    private func determineSafetyLevel(_ suspicionScore: Float) -> SafetyLevel {
        if suspicionScore >= 0.7 {
            return .unsafe
        } else if suspicionScore >= 0.4 {
            return .caution
        } else {
            return .safe
        }
    }

    // MARK: - Emergency

    /// Quick access to emergency features
    func triggerEmergency() async throws {
        Logger.shared.error("EMERGENCY TRIGGERED", category: .general)

        // Trigger check-in emergency if there's an active check-in
        if let activeCheckIn = checkInManager.activeCheckIns.first {
            try await checkInManager.triggerEmergency(checkInId: activeCheckIn.id)
        }

        // Create critical alert
        createSafetyAlert(
            type: .emergency,
            message: "Emergency alert has been sent to your contacts",
            severity: .critical
        )
    }
}

// MARK: - Profile Safety Report

struct ProfileSafetyReport {
    let userId: String
    let isSafe: Bool
    let safetyLevel: SafetyLevel
    let fakeProfileAnalysis: FakeProfileAnalysis
    let verificationStatus: VerificationStatus
    let trustScore: Int
    let recommendations: [String]
}

// MARK: - Conversation Safety Report

struct ConversationSafetyReport {
    let isSafe: Bool
    let scamAnalysis: ConversationScamAnalysis
    let warnings: [String]
    let recommendation: ScamRecommendation
}

// MARK: - Safety Level

enum SafetyLevel: String {
    case safe = "safe"
    case caution = "caution"
    case unsafe = "unsafe"

    var displayName: String {
        switch self {
        case .safe:
            return "Safe"
        case .caution:
            return "Use Caution"
        case .unsafe:
            return "Potentially Unsafe"
        }
    }

    var color: String {
        switch self {
        case .safe:
            return "green"
        case .caution:
            return "yellow"
        case .unsafe:
            return "red"
        }
    }

    var icon: String {
        switch self {
        case .safe:
            return "checkmark.shield.fill"
        case .caution:
            return "exclamationmark.shield.fill"
        case .unsafe:
            return "xmark.shield.fill"
        }
    }
}

// MARK: - Safety Alert

struct SafetyAlert: Identifiable {
    let id: String
    let type: SafetyAlertType
    let message: String
    let severity: AlertSeverity
    let createdAt: Date
}

enum SafetyAlertType: String {
    case scamDetected = "scam_detected"
    case fakeProfile = "fake_profile"
    case missedCheckIn = "missed_check_in"
    case emergency = "emergency"
    case verification = "verification"
}

enum AlertSeverity: String {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"

    var color: String {
        switch self {
        case .low:
            return "gray"
        case .medium:
            return "yellow"
        case .high:
            return "orange"
        case .critical:
            return "red"
        }
    }
}

