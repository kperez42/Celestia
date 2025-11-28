//
//  ReferralFraudDetector.swift
//  Celestia
//
//  Advanced fraud detection for referral system
//  Features: Device fingerprinting, IP analysis, behavioral patterns, ML-based risk scoring
//

import Foundation
import FirebaseFirestore
import UIKit
import CoreTelephony
import AdSupport

// MARK: - Fraud Risk Level

enum FraudRiskLevel: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case blocked = "blocked"

    var threshold: Double {
        switch self {
        case .low: return 0.3
        case .medium: return 0.6
        case .high: return 0.85
        case .blocked: return 1.0
        }
    }

    static func fromScore(_ score: Double) -> FraudRiskLevel {
        switch score {
        case 0..<0.3: return .low
        case 0.3..<0.6: return .medium
        case 0.6..<0.85: return .high
        default: return .blocked
        }
    }
}

// MARK: - Device Fingerprint

struct DeviceFingerprint: Codable {
    let fingerprintId: String
    let deviceModel: String
    let systemVersion: String
    let screenResolution: String
    let timezone: String
    let language: String
    let carrier: String?
    let isSimulator: Bool
    let isJailbroken: Bool
    let advertisingId: String?
    let vendorId: String
    let createdAt: Date

    /// Generates a unique fingerprint hash combining device attributes
    var hash: String {
        let components = [
            deviceModel,
            systemVersion,
            screenResolution,
            timezone,
            language,
            carrier ?? "unknown",
            vendorId
        ]
        let combined = components.joined(separator: "|")
        return combined.sha256Hash
    }

    static func generate() -> DeviceFingerprint {
        let device = UIDevice.current
        let screen = UIScreen.main.bounds

        // Get carrier info
        var carrierName: String?
        let networkInfo = CTTelephonyNetworkInfo()
        if let carrier = networkInfo.serviceSubscriberCellularProviders?.values.first {
            carrierName = carrier.carrierName
        }

        // Get advertising ID if available
        var advertisingId: String?
        if ASIdentifierManager.shared().isAdvertisingTrackingEnabled {
            advertisingId = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        }

        return DeviceFingerprint(
            fingerprintId: UUID().uuidString,
            deviceModel: device.model,
            systemVersion: device.systemVersion,
            screenResolution: "\(Int(screen.width))x\(Int(screen.height))",
            timezone: TimeZone.current.identifier,
            language: Locale.current.language.languageCode?.identifier ?? "en",
            carrier: carrierName,
            isSimulator: isRunningOnSimulator(),
            isJailbroken: isDeviceJailbroken(),
            advertisingId: advertisingId,
            vendorId: device.identifierForVendor?.uuidString ?? UUID().uuidString,
            createdAt: Date()
        )
    }

    private static func isRunningOnSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private static func isDeviceJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        // Check for common jailbreak indicators
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/"
        ]

        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }

        // Check if app can write to system directories
        let testPath = "/private/jailbreak_test.txt"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            return false
        }
        #endif
    }
}

// MARK: - Fraud Signal

struct FraudSignal: Codable {
    let signalType: FraudSignalType
    let weight: Double
    let description: String
    let detectedAt: Date
    let metadata: [String: String]
}

enum FraudSignalType: String, Codable {
    // Device-based signals
    case duplicateDevice = "duplicate_device"
    case jailbrokenDevice = "jailbroken_device"
    case simulatorUsage = "simulator_usage"
    case suspiciousDeviceAge = "suspicious_device_age"

    // IP-based signals
    case duplicateIP = "duplicate_ip"
    case vpnDetected = "vpn_detected"
    case datacenterIP = "datacenter_ip"
    case proxyDetected = "proxy_detected"
    case ipCountryMismatch = "ip_country_mismatch"

    // Behavioral signals
    case rapidReferrals = "rapid_referrals"
    case unusualSignupTime = "unusual_signup_time"
    case sameWifiNetwork = "same_wifi_network"
    case shortSessionDuration = "short_session_duration"
    case noAppEngagement = "no_app_engagement"
    case immediateUninstall = "immediate_uninstall"

    // Account signals
    case disposableEmail = "disposable_email"
    case similarUsernames = "similar_usernames"
    case incompleteProfile = "incomplete_profile"
    case noProfilePhoto = "no_profile_photo"
    case suspiciousPhoneNumber = "suspicious_phone_number"

    // Pattern signals
    case referralRing = "referral_ring"
    case batchSignups = "batch_signups"
    case geographicAnomaly = "geographic_anomaly"

    var baseWeight: Double {
        switch self {
        case .duplicateDevice: return 0.9
        case .jailbrokenDevice: return 0.4
        case .simulatorUsage: return 0.8
        case .suspiciousDeviceAge: return 0.3
        case .duplicateIP: return 0.7
        case .vpnDetected: return 0.3
        case .datacenterIP: return 0.8
        case .proxyDetected: return 0.5
        case .ipCountryMismatch: return 0.4
        case .rapidReferrals: return 0.6
        case .unusualSignupTime: return 0.2
        case .sameWifiNetwork: return 0.5
        case .shortSessionDuration: return 0.4
        case .noAppEngagement: return 0.5
        case .immediateUninstall: return 0.7
        case .disposableEmail: return 0.8
        case .similarUsernames: return 0.5
        case .incompleteProfile: return 0.3
        case .noProfilePhoto: return 0.2
        case .suspiciousPhoneNumber: return 0.6
        case .referralRing: return 0.95
        case .batchSignups: return 0.7
        case .geographicAnomaly: return 0.4
        }
    }
}

// MARK: - Fraud Assessment

struct FraudAssessment: Codable {
    let assessmentId: String
    let userId: String
    let referralCode: String?
    let riskScore: Double
    let riskLevel: FraudRiskLevel
    let signals: [FraudSignal]
    let deviceFingerprint: DeviceFingerprint
    let ipAddress: String?
    let assessedAt: Date
    let decision: FraudDecision
    let reviewRequired: Bool

    var shouldBlock: Bool {
        return decision == .block || riskLevel == .blocked
    }

    var shouldFlagForReview: Bool {
        return reviewRequired || riskLevel == .high
    }
}

enum FraudDecision: String, Codable {
    case allow = "allow"
    case allowWithMonitoring = "allow_with_monitoring"
    case requireVerification = "require_verification"
    case block = "block"
    case manualReview = "manual_review"
}

// MARK: - Fraud Detector

@MainActor
class ReferralFraudDetector: ObservableObject {
    static let shared = ReferralFraudDetector()

    private let db = Firestore.firestore()

    // Known disposable email domains
    private let disposableEmailDomains: Set<String> = [
        "tempmail.com", "throwaway.email", "guerrillamail.com", "10minutemail.com",
        "mailinator.com", "fakeinbox.com", "trashmail.com", "getnada.com",
        "temp-mail.org", "mohmal.com", "dispostable.com", "sharklasers.com",
        "yopmail.com", "maildrop.cc", "mailnesia.com", "tempail.com"
    ]

    // Known VPN/Datacenter IP ranges (sample - in production, use a service)
    private let suspiciousIPRanges: [String] = [
        "104.238.", "45.33.", "45.79.", "96.126.", // Linode
        "159.89.", "138.68.", "167.99.", "206.189.", // DigitalOcean
        "35.192.", "35.224.", "35.240.", // Google Cloud
        "52.0.", "54.0.", "18.0." // AWS
    ]

    private init() {}

    // MARK: - Main Assessment

    /// Performs comprehensive fraud assessment for a referral signup
    func assessReferralFraud(
        userId: String,
        referrerId: String?,
        referralCode: String?,
        email: String,
        ipAddress: String?
    ) async throws -> FraudAssessment {
        var signals: [FraudSignal] = []

        // Generate device fingerprint
        let fingerprint = DeviceFingerprint.generate()

        // Run all fraud checks in parallel where possible
        async let deviceSignals = checkDeviceSignals(fingerprint: fingerprint, userId: userId)
        async let ipSignals = checkIPSignals(ipAddress: ipAddress, userId: userId)
        async let accountSignals = checkAccountSignals(email: email, userId: userId)
        async let behavioralSignals = checkBehavioralSignals(userId: userId, referrerId: referrerId)
        async let patternSignals = checkPatternSignals(userId: userId, referrerId: referrerId, referralCode: referralCode)

        // Collect all signals
        signals.append(contentsOf: try await deviceSignals)
        signals.append(contentsOf: try await ipSignals)
        signals.append(contentsOf: try await accountSignals)
        signals.append(contentsOf: try await behavioralSignals)
        signals.append(contentsOf: try await patternSignals)

        // Calculate risk score
        let riskScore = calculateRiskScore(signals: signals)
        let riskLevel = FraudRiskLevel.fromScore(riskScore)

        // Determine decision
        let decision = determineDecision(riskScore: riskScore, signals: signals)
        let reviewRequired = signals.contains { $0.signalType == .referralRing || $0.weight > 0.8 }

        let assessment = FraudAssessment(
            assessmentId: UUID().uuidString,
            userId: userId,
            referralCode: referralCode,
            riskScore: riskScore,
            riskLevel: riskLevel,
            signals: signals,
            deviceFingerprint: fingerprint,
            ipAddress: ipAddress,
            assessedAt: Date(),
            decision: decision,
            reviewRequired: reviewRequired
        )

        // Store assessment
        try await storeAssessment(assessment)

        // Store device fingerprint
        try await storeDeviceFingerprint(fingerprint, userId: userId)

        // Log for analytics
        Logger.shared.info("Fraud assessment completed: \(riskLevel.rawValue) (score: \(riskScore))", category: .referral)

        return assessment
    }

    // MARK: - Device Checks

    private func checkDeviceSignals(fingerprint: DeviceFingerprint, userId: String) async throws -> [FraudSignal] {
        var signals: [FraudSignal] = []

        // Check for simulator
        if fingerprint.isSimulator {
            signals.append(FraudSignal(
                signalType: .simulatorUsage,
                weight: FraudSignalType.simulatorUsage.baseWeight,
                description: "Signup from iOS simulator detected",
                detectedAt: Date(),
                metadata: ["deviceModel": fingerprint.deviceModel]
            ))
        }

        // Check for jailbroken device
        if fingerprint.isJailbroken {
            signals.append(FraudSignal(
                signalType: .jailbrokenDevice,
                weight: FraudSignalType.jailbrokenDevice.baseWeight,
                description: "Jailbroken device detected",
                detectedAt: Date(),
                metadata: [:]
            ))
        }

        // Check for duplicate device fingerprint
        let duplicateCheck = try await db.collection("deviceFingerprints")
            .whereField("hash", isEqualTo: fingerprint.hash)
            .limit(to: 5)
            .getDocuments()

        if !duplicateCheck.documents.isEmpty {
            let existingUserIds = duplicateCheck.documents.compactMap { $0.data()["userId"] as? String }
            let uniqueUsers = Set(existingUserIds).subtracting([userId])

            if !uniqueUsers.isEmpty {
                signals.append(FraudSignal(
                    signalType: .duplicateDevice,
                    weight: min(FraudSignalType.duplicateDevice.baseWeight * Double(uniqueUsers.count), 1.0),
                    description: "Device fingerprint matches \(uniqueUsers.count) other account(s)",
                    detectedAt: Date(),
                    metadata: ["matchedAccounts": String(uniqueUsers.count)]
                ))
            }
        }

        // Check device age (new device + new account is suspicious)
        if let vendorIdCreation = try await getVendorIdFirstSeen(vendorId: fingerprint.vendorId) {
            let hoursSinceCreation = Date().timeIntervalSince(vendorIdCreation) / 3600
            if hoursSinceCreation < 1 {
                signals.append(FraudSignal(
                    signalType: .suspiciousDeviceAge,
                    weight: FraudSignalType.suspiciousDeviceAge.baseWeight,
                    description: "Brand new device identifier",
                    detectedAt: Date(),
                    metadata: ["hoursSinceCreation": String(format: "%.2f", hoursSinceCreation)]
                ))
            }
        }

        return signals
    }

    // MARK: - IP Checks

    private func checkIPSignals(ipAddress: String?, userId: String) async throws -> [FraudSignal] {
        var signals: [FraudSignal] = []

        guard let ip = ipAddress, !ip.isEmpty else { return signals }

        // Check for duplicate IP in recent referrals
        let recentWindow = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        let duplicateIPCheck = try await db.collection("referralSignups")
            .whereField("ipAddress", isEqualTo: ip)
            .whereField("createdAt", isGreaterThan: Timestamp(date: recentWindow))
            .getDocuments()

        if duplicateIPCheck.documents.count > 1 {
            signals.append(FraudSignal(
                signalType: .duplicateIP,
                weight: min(FraudSignalType.duplicateIP.baseWeight * Double(duplicateIPCheck.documents.count - 1), 1.0),
                description: "\(duplicateIPCheck.documents.count) signups from same IP in 24h",
                detectedAt: Date(),
                metadata: ["ipAddress": ip, "signupCount": String(duplicateIPCheck.documents.count)]
            ))
        }

        // Check for datacenter/VPN IP
        if isSuspiciousIP(ip) {
            signals.append(FraudSignal(
                signalType: .datacenterIP,
                weight: FraudSignalType.datacenterIP.baseWeight,
                description: "IP appears to be from datacenter or VPN",
                detectedAt: Date(),
                metadata: ["ipAddress": ip]
            ))
        }

        return signals
    }

    private func isSuspiciousIP(_ ip: String) -> Bool {
        return suspiciousIPRanges.contains { ip.hasPrefix($0) }
    }

    // MARK: - Account Checks

    private func checkAccountSignals(email: String, userId: String) async throws -> [FraudSignal] {
        var signals: [FraudSignal] = []

        // Check for disposable email
        let emailDomain = email.components(separatedBy: "@").last?.lowercased() ?? ""
        if disposableEmailDomains.contains(emailDomain) {
            signals.append(FraudSignal(
                signalType: .disposableEmail,
                weight: FraudSignalType.disposableEmail.baseWeight,
                description: "Disposable email domain detected",
                detectedAt: Date(),
                metadata: ["domain": emailDomain]
            ))
        }

        // Check for similar emails (e.g., john+1@gmail.com, john+2@gmail.com)
        let baseEmail = normalizeEmail(email)
        let similarEmailCheck = try await db.collection("users")
            .whereField("normalizedEmail", isEqualTo: baseEmail)
            .limit(to: 5)
            .getDocuments()

        if similarEmailCheck.documents.count > 1 {
            signals.append(FraudSignal(
                signalType: .similarUsernames,
                weight: FraudSignalType.similarUsernames.baseWeight,
                description: "Similar email pattern detected",
                detectedAt: Date(),
                metadata: ["similarCount": String(similarEmailCheck.documents.count)]
            ))
        }

        return signals
    }

    private func normalizeEmail(_ email: String) -> String {
        let parts = email.lowercased().components(separatedBy: "@")
        guard parts.count == 2 else { return email.lowercased() }

        var localPart = parts[0]
        let domain = parts[1]

        // Remove dots for gmail (Gmail ignores dots)
        if domain == "gmail.com" {
            localPart = localPart.replacingOccurrences(of: ".", with: "")
        }

        // Remove everything after + (plus addressing)
        if let plusIndex = localPart.firstIndex(of: "+") {
            localPart = String(localPart[..<plusIndex])
        }

        return "\(localPart)@\(domain)"
    }

    // MARK: - Behavioral Checks

    private func checkBehavioralSignals(userId: String, referrerId: String?) async throws -> [FraudSignal] {
        var signals: [FraudSignal] = []

        guard let referrerId = referrerId else { return signals }

        // Check for rapid referrals from same referrer
        let rapidWindow = Calendar.current.date(byAdding: .minute, value: -30, to: Date()) ?? Date()
        let rapidReferralsCheck = try await db.collection("referrals")
            .whereField("referrerUserId", isEqualTo: referrerId)
            .whereField("createdAt", isGreaterThan: Timestamp(date: rapidWindow))
            .getDocuments()

        if rapidReferralsCheck.documents.count >= 3 {
            signals.append(FraudSignal(
                signalType: .rapidReferrals,
                weight: min(FraudSignalType.rapidReferrals.baseWeight * Double(rapidReferralsCheck.documents.count) / 3.0, 1.0),
                description: "\(rapidReferralsCheck.documents.count) referrals in 30 minutes",
                detectedAt: Date(),
                metadata: ["referrerId": referrerId, "count": String(rapidReferralsCheck.documents.count)]
            ))
        }

        // Check signup time (very late night signups can be suspicious)
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 2 && hour <= 5 {
            signals.append(FraudSignal(
                signalType: .unusualSignupTime,
                weight: FraudSignalType.unusualSignupTime.baseWeight,
                description: "Signup at unusual hour (\(hour):00)",
                detectedAt: Date(),
                metadata: ["hour": String(hour)]
            ))
        }

        return signals
    }

    // MARK: - Pattern Checks

    private func checkPatternSignals(userId: String, referrerId: String?, referralCode: String?) async throws -> [FraudSignal] {
        var signals: [FraudSignal] = []

        guard let referrerId = referrerId else { return signals }

        // Check for referral rings (A refers B, B refers C, C refers A)
        let ringCheck = try await detectReferralRing(userId: userId, referrerId: referrerId)
        if ringCheck {
            signals.append(FraudSignal(
                signalType: .referralRing,
                weight: FraudSignalType.referralRing.baseWeight,
                description: "Circular referral pattern detected",
                detectedAt: Date(),
                metadata: ["referrerId": referrerId]
            ))
        }

        // Check for batch signups (many signups from same referrer in short time)
        let batchWindow = Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date()
        let batchCheck = try await db.collection("referrals")
            .whereField("referrerUserId", isEqualTo: referrerId)
            .whereField("createdAt", isGreaterThan: Timestamp(date: batchWindow))
            .getDocuments()

        if batchCheck.documents.count >= 5 {
            signals.append(FraudSignal(
                signalType: .batchSignups,
                weight: FraudSignalType.batchSignups.baseWeight,
                description: "\(batchCheck.documents.count) signups in 2 hours from same referrer",
                detectedAt: Date(),
                metadata: ["count": String(batchCheck.documents.count)]
            ))
        }

        return signals
    }

    private func detectReferralRing(userId: String, referrerId: String, depth: Int = 3) async throws -> Bool {
        var visited = Set<String>()
        var queue = [referrerId]

        for _ in 0..<depth {
            guard !queue.isEmpty else { break }

            let current = queue.removeFirst()
            if visited.contains(current) { continue }
            visited.insert(current)

            // Check if this user referred the original user (ring detected)
            if current == userId && visited.count > 1 {
                return true
            }

            // Get who referred the current user
            let referralDoc = try await db.collection("referrals")
                .whereField("referredUserId", isEqualTo: current)
                .limit(to: 1)
                .getDocuments()

            if let doc = referralDoc.documents.first,
               let nextReferrerId = doc.data()["referrerUserId"] as? String {
                queue.append(nextReferrerId)
            }
        }

        return false
    }

    // MARK: - Risk Calculation

    private func calculateRiskScore(signals: [FraudSignal]) -> Double {
        guard !signals.isEmpty else { return 0.0 }

        // Weighted average with diminishing returns for multiple signals
        var totalWeight = 0.0
        var weightedSum = 0.0

        for (index, signal) in signals.sorted(by: { $0.weight > $1.weight }).enumerated() {
            // Apply diminishing factor for subsequent signals
            let diminishingFactor = 1.0 / pow(1.5, Double(index))
            let adjustedWeight = signal.weight * diminishingFactor

            weightedSum += adjustedWeight
            totalWeight += diminishingFactor
        }

        let baseScore = totalWeight > 0 ? weightedSum / totalWeight : 0.0

        // Apply signal count multiplier (more signals = higher risk)
        let signalCountMultiplier = min(1.0 + Double(signals.count) * 0.05, 1.3)

        return min(baseScore * signalCountMultiplier, 1.0)
    }

    private func determineDecision(riskScore: Double, signals: [FraudSignal]) -> FraudDecision {
        // Automatic block for referral rings
        if signals.contains(where: { $0.signalType == .referralRing }) {
            return .block
        }

        // Block for very high risk
        if riskScore >= 0.85 {
            return .block
        }

        // Require verification for high risk
        if riskScore >= 0.6 {
            return .requireVerification
        }

        // Manual review for medium-high risk
        if riskScore >= 0.45 {
            return .manualReview
        }

        // Monitor medium risk
        if riskScore >= 0.3 {
            return .allowWithMonitoring
        }

        return .allow
    }

    // MARK: - Storage

    private func storeAssessment(_ assessment: FraudAssessment) async throws {
        let data: [String: Any] = [
            "assessmentId": assessment.assessmentId,
            "userId": assessment.userId,
            "referralCode": assessment.referralCode ?? "",
            "riskScore": assessment.riskScore,
            "riskLevel": assessment.riskLevel.rawValue,
            "signalCount": assessment.signals.count,
            "signalTypes": assessment.signals.map { $0.signalType.rawValue },
            "ipAddress": assessment.ipAddress ?? "",
            "deviceHash": assessment.deviceFingerprint.hash,
            "assessedAt": Timestamp(date: assessment.assessedAt),
            "decision": assessment.decision.rawValue,
            "reviewRequired": assessment.reviewRequired
        ]

        try await db.collection("fraudAssessments").document(assessment.assessmentId).setData(data)
    }

    private func storeDeviceFingerprint(_ fingerprint: DeviceFingerprint, userId: String) async throws {
        let data: [String: Any] = [
            "fingerprintId": fingerprint.fingerprintId,
            "userId": userId,
            "hash": fingerprint.hash,
            "deviceModel": fingerprint.deviceModel,
            "systemVersion": fingerprint.systemVersion,
            "vendorId": fingerprint.vendorId,
            "isSimulator": fingerprint.isSimulator,
            "isJailbroken": fingerprint.isJailbroken,
            "createdAt": Timestamp(date: fingerprint.createdAt)
        ]

        try await db.collection("deviceFingerprints").document(fingerprint.fingerprintId).setData(data)
    }

    private func getVendorIdFirstSeen(vendorId: String) async throws -> Date? {
        let snapshot = try await db.collection("deviceFingerprints")
            .whereField("vendorId", isEqualTo: vendorId)
            .order(by: "createdAt")
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first,
              let timestamp = doc.data()["createdAt"] as? Timestamp else {
            return nil
        }

        return timestamp.dateValue()
    }

    // MARK: - Public Queries

    /// Gets fraud assessment history for a user
    func getAssessmentHistory(userId: String) async throws -> [FraudAssessment] {
        let snapshot = try await db.collection("fraudAssessments")
            .whereField("userId", isEqualTo: userId)
            .order(by: "assessedAt", descending: true)
            .limit(to: 10)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> FraudAssessment? in
            let data = doc.data()
            guard let assessmentId = data["assessmentId"] as? String,
                  let riskScore = data["riskScore"] as? Double,
                  let riskLevelStr = data["riskLevel"] as? String,
                  let riskLevel = FraudRiskLevel(rawValue: riskLevelStr),
                  let decisionStr = data["decision"] as? String,
                  let decision = FraudDecision(rawValue: decisionStr),
                  let assessedAt = (data["assessedAt"] as? Timestamp)?.dateValue() else {
                return nil
            }

            return FraudAssessment(
                assessmentId: assessmentId,
                userId: userId,
                referralCode: data["referralCode"] as? String,
                riskScore: riskScore,
                riskLevel: riskLevel,
                signals: [],
                deviceFingerprint: DeviceFingerprint.generate(),
                ipAddress: data["ipAddress"] as? String,
                assessedAt: assessedAt,
                decision: decision,
                reviewRequired: data["reviewRequired"] as? Bool ?? false
            )
        }
    }

    /// Gets flagged referrals requiring manual review
    func getFlaggedReferrals(limit: Int = 50) async throws -> [FraudAssessment] {
        let snapshot = try await db.collection("fraudAssessments")
            .whereField("reviewRequired", isEqualTo: true)
            .order(by: "assessedAt", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> FraudAssessment? in
            let data = doc.data()
            guard let assessmentId = data["assessmentId"] as? String,
                  let userId = data["userId"] as? String,
                  let riskScore = data["riskScore"] as? Double,
                  let riskLevelStr = data["riskLevel"] as? String,
                  let riskLevel = FraudRiskLevel(rawValue: riskLevelStr),
                  let decisionStr = data["decision"] as? String,
                  let decision = FraudDecision(rawValue: decisionStr),
                  let assessedAt = (data["assessedAt"] as? Timestamp)?.dateValue() else {
                return nil
            }

            return FraudAssessment(
                assessmentId: assessmentId,
                userId: userId,
                referralCode: data["referralCode"] as? String,
                riskScore: riskScore,
                riskLevel: riskLevel,
                signals: [],
                deviceFingerprint: DeviceFingerprint.generate(),
                ipAddress: data["ipAddress"] as? String,
                assessedAt: assessedAt,
                decision: decision,
                reviewRequired: true
            )
        }
    }

    /// Updates review status for a fraud assessment
    func markAsReviewed(assessmentId: String, approved: Bool, reviewerNotes: String) async throws {
        try await db.collection("fraudAssessments").document(assessmentId).updateData([
            "reviewRequired": false,
            "reviewedAt": Timestamp(date: Date()),
            "reviewApproved": approved,
            "reviewerNotes": reviewerNotes
        ])
    }
}

// MARK: - String Extension for Hashing

extension String {
    var sha256Hash: String {
        guard let data = self.data(using: .utf8) else { return self }

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }

        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// Import for SHA256
import CommonCrypto
