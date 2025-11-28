//
//  ReferralCompliance.swift
//  Celestia
//
//  Privacy compliance for referral system (GDPR, CCPA, etc.)
//  Features: Consent management, data export, data deletion, audit logging
//

import Foundation
import FirebaseFirestore

// MARK: - Compliance Models

enum PrivacyRegulation: String, Codable {
    case gdpr = "GDPR"           // EU General Data Protection Regulation
    case ccpa = "CCPA"           // California Consumer Privacy Act
    case lgpd = "LGPD"           // Brazil's Lei Geral de Proteção de Dados
    case pipeda = "PIPEDA"       // Canada's Personal Information Protection
    case appi = "APPI"           // Japan's Act on Protection of Personal Information
    case pdpa = "PDPA"           // Singapore Personal Data Protection Act

    var requiresExplicitConsent: Bool {
        switch self {
        case .gdpr, .lgpd:
            return true
        case .ccpa, .pipeda, .appi, .pdpa:
            return false  // Opt-out model
        }
    }

    var dataRetentionDays: Int {
        switch self {
        case .gdpr: return 365 * 3     // 3 years typical
        case .ccpa: return 365 * 2     // 2 years
        case .lgpd: return 365 * 5     // 5 years
        case .pipeda: return 365 * 2
        case .appi: return 365 * 3
        case .pdpa: return 365 * 3
        }
    }

    var deletionDeadlineDays: Int {
        switch self {
        case .gdpr: return 30
        case .ccpa: return 45
        case .lgpd: return 15
        case .pipeda: return 30
        case .appi: return 30
        case .pdpa: return 30
        }
    }
}

// MARK: - Consent Types

enum ConsentType: String, Codable {
    case referralParticipation = "referral_participation"
    case referralMarketing = "referral_marketing"
    case referralAnalytics = "referral_analytics"
    case shareContactInfo = "share_contact_info"
    case deviceTracking = "device_tracking"
    case crossPlatformTracking = "cross_platform_tracking"
}

struct ConsentRecord: Codable {
    let consentId: String
    let userId: String
    let consentType: ConsentType
    let granted: Bool
    let grantedAt: Date
    let expiresAt: Date?
    let ipAddress: String?
    let userAgent: String?
    let method: ConsentMethod
    let version: String           // Version of privacy policy
    let regulation: PrivacyRegulation?
}

enum ConsentMethod: String, Codable {
    case explicit = "explicit"        // User clicked accept
    case implicit = "implicit"        // Implied consent
    case optOut = "opt_out"          // User opted out
    case parentalConsent = "parental" // For minors
}

// MARK: - Data Subject Request

struct DataSubjectRequest: Codable, Identifiable {
    let id: String
    let userId: String
    let email: String
    let requestType: DataRequestType
    let status: RequestStatus
    let regulation: PrivacyRegulation
    let requestedAt: Date
    let deadline: Date
    let completedAt: Date?
    let notes: String?
    let verificationToken: String?
    let verified: Bool
}

enum DataRequestType: String, Codable {
    case access = "access"             // Right to access data
    case portability = "portability"   // Right to data portability
    case erasure = "erasure"           // Right to be forgotten
    case rectification = "rectification" // Right to correction
    case restriction = "restriction"   // Right to restrict processing
    case objection = "objection"       // Right to object
}

enum RequestStatus: String, Codable {
    case pending = "pending"
    case verifying = "verifying"
    case inProgress = "in_progress"
    case completed = "completed"
    case rejected = "rejected"
    case extended = "extended"         // Deadline extended (with reason)
}

// MARK: - Audit Log

struct ComplianceAuditLog: Codable {
    let logId: String
    let timestamp: Date
    let action: ComplianceAction
    let userId: String?
    let performedBy: String          // System or admin user ID
    let details: [String: String]
    let ipAddress: String?
    let successful: Bool
    let errorMessage: String?
}

enum ComplianceAction: String, Codable {
    // Consent actions
    case consentGranted = "consent_granted"
    case consentRevoked = "consent_revoked"
    case consentExpired = "consent_expired"

    // Data actions
    case dataExported = "data_exported"
    case dataDeleted = "data_deleted"
    case dataRectified = "data_rectified"
    case dataAccessed = "data_accessed"

    // Request actions
    case requestReceived = "request_received"
    case requestVerified = "request_verified"
    case requestCompleted = "request_completed"
    case requestRejected = "request_rejected"

    // System actions
    case dataRetentionPurge = "retention_purge"
    case anonymizationCompleted = "anonymization_completed"
    case breachNotification = "breach_notification"
}

// MARK: - Exported Data

struct ReferralDataExport: Codable {
    let exportId: String
    let userId: String
    let exportedAt: Date
    let format: ExportFormat
    let regulation: PrivacyRegulation

    // Referral data
    let referralCode: String
    let referrals: [ExportedReferral]
    let rewards: [ExportedReward]
    let shares: [ExportedShare]

    // Attribution data
    let touchpoints: [ExportedTouchpoint]

    // Consent history
    let consents: [ConsentRecord]

    // Device data
    let devices: [ExportedDevice]
}

enum ExportFormat: String, Codable {
    case json = "json"
    case csv = "csv"
    case pdf = "pdf"
}

struct ExportedReferral: Codable {
    let referralId: String
    let referredUserId: String       // Anonymized
    let status: String
    let createdAt: Date
    let completedAt: Date?
    let rewardClaimed: Bool
}

struct ExportedReward: Codable {
    let rewardId: String
    let days: Int
    let reason: String
    let awardedAt: Date
}

struct ExportedShare: Codable {
    let shareId: String
    let method: String
    let timestamp: Date
}

struct ExportedTouchpoint: Codable {
    let touchpointId: String
    let type: String
    let source: String
    let timestamp: Date
}

struct ExportedDevice: Codable {
    let deviceId: String
    let deviceModel: String
    let firstSeen: Date
    let lastSeen: Date
}

// MARK: - Compliance Manager

@MainActor
class ReferralCompliance: ObservableObject {
    static let shared = ReferralCompliance()

    private let db = Firestore.firestore()

    @Published var pendingRequests: [DataSubjectRequest] = []
    @Published var userConsents: [ConsentType: Bool] = [:]

    // Current privacy policy version
    let currentPolicyVersion = "2.0.0"

    private init() {}

    // MARK: - Consent Management

    /// Records user consent
    func recordConsent(
        userId: String,
        consentType: ConsentType,
        granted: Bool,
        method: ConsentMethod = .explicit,
        regulation: PrivacyRegulation? = nil,
        ipAddress: String? = nil
    ) async throws {
        let consent = ConsentRecord(
            consentId: UUID().uuidString,
            userId: userId,
            consentType: consentType,
            granted: granted,
            grantedAt: Date(),
            expiresAt: calculateConsentExpiry(regulation: regulation),
            ipAddress: ipAddress,
            userAgent: nil,
            method: method,
            version: currentPolicyVersion,
            regulation: regulation
        )

        // Store consent
        let data: [String: Any] = [
            "consentId": consent.consentId,
            "userId": consent.userId,
            "consentType": consent.consentType.rawValue,
            "granted": consent.granted,
            "grantedAt": Timestamp(date: consent.grantedAt),
            "expiresAt": consent.expiresAt.map { Timestamp(date: $0) } as Any,
            "ipAddress": consent.ipAddress as Any,
            "method": consent.method.rawValue,
            "version": consent.version,
            "regulation": consent.regulation?.rawValue as Any
        ]

        try await db.collection("consentRecords").document(consent.consentId).setData(data)

        // Update user's consent status
        try await db.collection("users").document(userId).updateData([
            "consents.\(consentType.rawValue)": granted,
            "consents.lastUpdated": Timestamp(date: Date())
        ])

        // Audit log
        await logAudit(
            action: granted ? .consentGranted : .consentRevoked,
            userId: userId,
            performedBy: userId,
            details: [
                "consentType": consentType.rawValue,
                "method": method.rawValue
            ],
            ipAddress: ipAddress
        )

        Logger.shared.info("Recorded consent: \(consentType.rawValue) = \(granted) for user \(userId)", category: .referral)
    }

    /// Gets current consent status for a user
    func getConsentStatus(userId: String) async throws -> [ConsentType: Bool] {
        let userDoc = try await db.collection("users").document(userId).getDocument()
        let consents = userDoc.data()?["consents"] as? [String: Any] ?? [:]

        var status: [ConsentType: Bool] = [:]

        for type in ConsentType.allCases {
            status[type] = consents[type.rawValue] as? Bool ?? false
        }

        userConsents = status
        return status
    }

    /// Checks if user has required consent for referral participation
    func hasRequiredConsent(userId: String, regulation: PrivacyRegulation?) async -> Bool {
        do {
            let status = try await getConsentStatus(userId: userId)

            // Referral participation consent is always required
            guard status[.referralParticipation] == true else {
                return false
            }

            // GDPR requires explicit consent for tracking
            if regulation == .gdpr {
                guard status[.referralAnalytics] == true else {
                    return false
                }
            }

            return true
        } catch {
            Logger.shared.error("Failed to check consent", category: .referral, error: error)
            return false
        }
    }

    private func calculateConsentExpiry(regulation: PrivacyRegulation?) -> Date? {
        // Consent typically doesn't expire, but can be regulated
        // GDPR recommends refreshing consent periodically
        if regulation == .gdpr {
            return Calendar.current.date(byAdding: .year, value: 1, to: Date())
        }
        return nil
    }

    // MARK: - Data Subject Requests

    /// Creates a new data subject request (right to access, delete, etc.)
    func createDataRequest(
        userId: String,
        email: String,
        requestType: DataRequestType,
        regulation: PrivacyRegulation
    ) async throws -> DataSubjectRequest {
        let requestId = UUID().uuidString
        let verificationToken = generateVerificationToken()
        let deadline = Calendar.current.date(
            byAdding: .day,
            value: regulation.deletionDeadlineDays,
            to: Date()
        ) ?? Date()

        let request = DataSubjectRequest(
            id: requestId,
            userId: userId,
            email: email,
            requestType: requestType,
            status: .pending,
            regulation: regulation,
            requestedAt: Date(),
            deadline: deadline,
            completedAt: nil,
            notes: nil,
            verificationToken: verificationToken,
            verified: false
        )

        // Store request
        let data: [String: Any] = [
            "id": request.id,
            "userId": request.userId,
            "email": request.email,
            "requestType": request.requestType.rawValue,
            "status": request.status.rawValue,
            "regulation": request.regulation.rawValue,
            "requestedAt": Timestamp(date: request.requestedAt),
            "deadline": Timestamp(date: request.deadline),
            "verificationToken": verificationToken,
            "verified": false
        ]

        try await db.collection("dataSubjectRequests").document(requestId).setData(data)

        // Audit log
        await logAudit(
            action: .requestReceived,
            userId: userId,
            performedBy: "system",
            details: [
                "requestType": requestType.rawValue,
                "regulation": regulation.rawValue,
                "deadline": ISO8601DateFormatter().string(from: deadline)
            ]
        )

        // Send verification email (would integrate with email service)
        await sendVerificationEmail(email: email, token: verificationToken, requestType: requestType)

        return request
    }

    /// Verifies a data subject request
    func verifyRequest(requestId: String, token: String) async throws -> Bool {
        let doc = try await db.collection("dataSubjectRequests").document(requestId).getDocument()
        guard let data = doc.data(),
              let storedToken = data["verificationToken"] as? String,
              storedToken == token else {
            return false
        }

        // Update request as verified
        try await db.collection("dataSubjectRequests").document(requestId).updateData([
            "verified": true,
            "status": RequestStatus.inProgress.rawValue
        ])

        let userId = data["userId"] as? String ?? ""

        await logAudit(
            action: .requestVerified,
            userId: userId,
            performedBy: "system",
            details: ["requestId": requestId]
        )

        return true
    }

    /// Processes a data subject request
    func processRequest(_ request: DataSubjectRequest) async throws {
        guard request.verified else {
            throw ComplianceError.requestNotVerified
        }

        switch request.requestType {
        case .access, .portability:
            let export = try await exportUserData(userId: request.userId, regulation: request.regulation)
            try await deliverExport(export, to: request.email)

        case .erasure:
            try await deleteUserReferralData(userId: request.userId)

        case .rectification:
            // Would typically require admin intervention
            break

        case .restriction:
            try await restrictDataProcessing(userId: request.userId)

        case .objection:
            try await handleObjection(userId: request.userId)
        }

        // Mark request as completed
        try await db.collection("dataSubjectRequests").document(request.id).updateData([
            "status": RequestStatus.completed.rawValue,
            "completedAt": Timestamp(date: Date())
        ])

        await logAudit(
            action: .requestCompleted,
            userId: request.userId,
            performedBy: "system",
            details: ["requestId": request.id, "requestType": request.requestType.rawValue]
        )
    }

    // MARK: - Data Export

    /// Exports all referral-related data for a user
    func exportUserData(userId: String, regulation: PrivacyRegulation) async throws -> ReferralDataExport {
        // Fetch user's referral code
        let userDoc = try await db.collection("users").document(userId).getDocument()
        let userData = userDoc.data() ?? [:]
        let referralStats = userData["referralStats"] as? [String: Any] ?? [:]
        let referralCode = referralStats["referralCode"] as? String ?? ""

        // Fetch referrals
        let referralsSnapshot = try await db.collection("referrals")
            .whereField("referrerUserId", isEqualTo: userId)
            .getDocuments()

        let referrals: [ExportedReferral] = referralsSnapshot.documents.map { doc in
            let data = doc.data()
            return ExportedReferral(
                referralId: doc.documentID,
                referredUserId: anonymizeUserId(data["referredUserId"] as? String ?? ""),
                status: data["status"] as? String ?? "",
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                completedAt: (data["completedAt"] as? Timestamp)?.dateValue(),
                rewardClaimed: data["rewardClaimed"] as? Bool ?? false
            )
        }

        // Fetch rewards
        let rewardsSnapshot = try await db.collection("referralRewards")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        let rewards: [ExportedReward] = rewardsSnapshot.documents.map { doc in
            let data = doc.data()
            return ExportedReward(
                rewardId: doc.documentID,
                days: data["days"] as? Int ?? 0,
                reason: data["reason"] as? String ?? "",
                awardedAt: (data["awardedAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }

        // Fetch shares
        let sharesSnapshot = try await db.collection("referralShares")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        let shares: [ExportedShare] = sharesSnapshot.documents.map { doc in
            let data = doc.data()
            return ExportedShare(
                shareId: doc.documentID,
                method: data["shareMethod"] as? String ?? "",
                timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
            )
        }

        // Fetch touchpoints
        let touchpointsSnapshot = try await db.collection("attributionTouchpoints")
            .whereField("deviceId", isEqualTo: userData["deviceId"] ?? "")
            .getDocuments()

        let touchpoints: [ExportedTouchpoint] = touchpointsSnapshot.documents.map { doc in
            let data = doc.data()
            return ExportedTouchpoint(
                touchpointId: doc.documentID,
                type: data["type"] as? String ?? "",
                source: data["source"] as? String ?? "",
                timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
            )
        }

        // Fetch consent history
        let consentsSnapshot = try await db.collection("consentRecords")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        let consents: [ConsentRecord] = consentsSnapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let typeStr = data["consentType"] as? String,
                  let type = ConsentType(rawValue: typeStr),
                  let methodStr = data["method"] as? String,
                  let method = ConsentMethod(rawValue: methodStr) else {
                return nil
            }

            return ConsentRecord(
                consentId: doc.documentID,
                userId: userId,
                consentType: type,
                granted: data["granted"] as? Bool ?? false,
                grantedAt: (data["grantedAt"] as? Timestamp)?.dateValue() ?? Date(),
                expiresAt: (data["expiresAt"] as? Timestamp)?.dateValue(),
                ipAddress: data["ipAddress"] as? String,
                userAgent: data["userAgent"] as? String,
                method: method,
                version: data["version"] as? String ?? "",
                regulation: (data["regulation"] as? String).flatMap { PrivacyRegulation(rawValue: $0) }
            )
        }

        // Fetch device fingerprints
        let devicesSnapshot = try await db.collection("deviceFingerprints")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        let devices: [ExportedDevice] = devicesSnapshot.documents.map { doc in
            let data = doc.data()
            return ExportedDevice(
                deviceId: anonymizeDeviceId(doc.documentID),
                deviceModel: data["deviceModel"] as? String ?? "",
                firstSeen: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                lastSeen: (data["lastSeen"] as? Timestamp)?.dateValue() ?? Date()
            )
        }

        let export = ReferralDataExport(
            exportId: UUID().uuidString,
            userId: userId,
            exportedAt: Date(),
            format: .json,
            regulation: regulation,
            referralCode: referralCode,
            referrals: referrals,
            rewards: rewards,
            shares: shares,
            touchpoints: touchpoints,
            consents: consents,
            devices: devices
        )

        // Audit log
        await logAudit(
            action: .dataExported,
            userId: userId,
            performedBy: "system",
            details: [
                "exportId": export.exportId,
                "format": export.format.rawValue,
                "itemCount": String(referrals.count + rewards.count + shares.count)
            ]
        )

        return export
    }

    // MARK: - Data Deletion

    /// Deletes all referral-related data for a user (right to be forgotten)
    func deleteUserReferralData(userId: String) async throws {
        let batch = db.batch()

        // Delete referrals where user is referrer
        let referralsAsReferrer = try await db.collection("referrals")
            .whereField("referrerUserId", isEqualTo: userId)
            .getDocuments()

        for doc in referralsAsReferrer.documents {
            batch.deleteDocument(doc.reference)
        }

        // Anonymize referrals where user was referred (preserve referrer stats)
        let referralsAsReferred = try await db.collection("referrals")
            .whereField("referredUserId", isEqualTo: userId)
            .getDocuments()

        for doc in referralsAsReferred.documents {
            batch.updateData([
                "referredUserId": "DELETED_USER",
                "anonymizedAt": Timestamp(date: Date())
            ], forDocument: doc.reference)
        }

        // Delete rewards
        let rewards = try await db.collection("referralRewards")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        for doc in rewards.documents {
            batch.deleteDocument(doc.reference)
        }

        // Delete shares
        let shares = try await db.collection("referralShares")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        for doc in shares.documents {
            batch.deleteDocument(doc.reference)
        }

        // Delete touchpoints
        let touchpoints = try await db.collection("attributionTouchpoints")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        for doc in touchpoints.documents {
            batch.deleteDocument(doc.reference)
        }

        // Delete device fingerprints
        let fingerprints = try await db.collection("deviceFingerprints")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        for doc in fingerprints.documents {
            batch.deleteDocument(doc.reference)
        }

        // Delete fraud assessments
        let assessments = try await db.collection("fraudAssessments")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        for doc in assessments.documents {
            batch.deleteDocument(doc.reference)
        }

        // Delete experiment assignments
        let assignments = try await db.collection("experimentAssignments")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        for doc in assignments.documents {
            batch.deleteDocument(doc.reference)
        }

        // Delete segment assignments
        try? await db.collection("userSegmentAssignments").document(userId).delete()

        // Delete referral code from dedicated collection
        let userDoc = try await db.collection("users").document(userId).getDocument()
        if let referralCode = (userDoc.data()?["referralStats"] as? [String: Any])?["referralCode"] as? String {
            try? await db.collection("referralCodes").document(referralCode).delete()
        }

        // Clear referral stats from user document
        batch.updateData([
            "referralStats": FieldValue.delete()
        ], forDocument: db.collection("users").document(userId))

        // Commit batch
        try await batch.commit()

        // Audit log
        await logAudit(
            action: .dataDeleted,
            userId: userId,
            performedBy: "system",
            details: [
                "deletedCollections": "referrals,rewards,shares,touchpoints,fingerprints,assessments"
            ]
        )

        Logger.shared.info("Deleted referral data for user: \(userId)", category: .referral)
    }

    /// Restricts data processing for a user
    private func restrictDataProcessing(userId: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "dataProcessingRestricted": true,
            "restrictedAt": Timestamp(date: Date())
        ])

        // Revoke all consents
        for type in ConsentType.allCases {
            try await recordConsent(
                userId: userId,
                consentType: type,
                granted: false,
                method: .optOut
            )
        }
    }

    /// Handles objection to processing
    private func handleObjection(userId: String) async throws {
        // Similar to restriction but specifically for objections
        try await restrictDataProcessing(userId: userId)

        // Additional notification to admin
        await notifyAdminOfObjection(userId: userId)
    }

    // MARK: - Data Retention

    /// Purges data older than retention period
    func purgeExpiredData(regulation: PrivacyRegulation) async throws {
        let retentionDays = regulation.dataRetentionDays
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()

        var deletedCount = 0

        // Purge old referral shares
        let oldShares = try await db.collection("referralShares")
            .whereField("timestamp", isLessThan: Timestamp(date: cutoffDate))
            .limit(to: 500)
            .getDocuments()

        let batch = db.batch()
        for doc in oldShares.documents {
            batch.deleteDocument(doc.reference)
            deletedCount += 1
        }

        // Purge old touchpoints
        let oldTouchpoints = try await db.collection("attributionTouchpoints")
            .whereField("timestamp", isLessThan: Timestamp(date: cutoffDate))
            .limit(to: 500)
            .getDocuments()

        for doc in oldTouchpoints.documents {
            batch.deleteDocument(doc.reference)
            deletedCount += 1
        }

        // Purge old fraud assessments
        let oldAssessments = try await db.collection("fraudAssessments")
            .whereField("assessedAt", isLessThan: Timestamp(date: cutoffDate))
            .limit(to: 500)
            .getDocuments()

        for doc in oldAssessments.documents {
            batch.deleteDocument(doc.reference)
            deletedCount += 1
        }

        try await batch.commit()

        // Audit log
        await logAudit(
            action: .dataRetentionPurge,
            userId: nil,
            performedBy: "system",
            details: [
                "regulation": regulation.rawValue,
                "cutoffDate": ISO8601DateFormatter().string(from: cutoffDate),
                "deletedCount": String(deletedCount)
            ]
        )

        Logger.shared.info("Purged \(deletedCount) expired records (regulation: \(regulation.rawValue))", category: .referral)
    }

    // MARK: - Audit Logging

    /// Logs a compliance audit entry
    func logAudit(
        action: ComplianceAction,
        userId: String?,
        performedBy: String,
        details: [String: String],
        ipAddress: String? = nil,
        successful: Bool = true,
        errorMessage: String? = nil
    ) async {
        let log = ComplianceAuditLog(
            logId: UUID().uuidString,
            timestamp: Date(),
            action: action,
            userId: userId,
            performedBy: performedBy,
            details: details,
            ipAddress: ipAddress,
            successful: successful,
            errorMessage: errorMessage
        )

        let data: [String: Any] = [
            "logId": log.logId,
            "timestamp": Timestamp(date: log.timestamp),
            "action": log.action.rawValue,
            "userId": log.userId as Any,
            "performedBy": log.performedBy,
            "details": log.details,
            "ipAddress": log.ipAddress as Any,
            "successful": log.successful,
            "errorMessage": log.errorMessage as Any
        ]

        do {
            try await db.collection("complianceAuditLogs").document(log.logId).setData(data)
        } catch {
            Logger.shared.error("Failed to write audit log", category: .referral, error: error)
        }
    }

    /// Gets audit logs for a user
    func getAuditLogs(userId: String, limit: Int = 100) async throws -> [ComplianceAuditLog] {
        let snapshot = try await db.collection("complianceAuditLogs")
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> ComplianceAuditLog? in
            let data = doc.data()
            guard let actionStr = data["action"] as? String,
                  let action = ComplianceAction(rawValue: actionStr),
                  let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
                return nil
            }

            return ComplianceAuditLog(
                logId: doc.documentID,
                timestamp: timestamp,
                action: action,
                userId: data["userId"] as? String,
                performedBy: data["performedBy"] as? String ?? "",
                details: data["details"] as? [String: String] ?? [:],
                ipAddress: data["ipAddress"] as? String,
                successful: data["successful"] as? Bool ?? true,
                errorMessage: data["errorMessage"] as? String
            )
        }
    }

    // MARK: - Helper Methods

    private func generateVerificationToken() -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<32).compactMap { _ in characters.randomElement() })
    }

    private func anonymizeUserId(_ userId: String) -> String {
        // Return first 4 and last 4 characters with asterisks in between
        guard userId.count > 8 else { return "****" }
        let prefix = String(userId.prefix(4))
        let suffix = String(userId.suffix(4))
        return "\(prefix)****\(suffix)"
    }

    private func anonymizeDeviceId(_ deviceId: String) -> String {
        return anonymizeUserId(deviceId)
    }

    private func sendVerificationEmail(email: String, token: String, requestType: DataRequestType) async {
        // Would integrate with email service
        Logger.shared.info("Would send verification email to \(email) for \(requestType.rawValue)", category: .referral)
    }

    private func deliverExport(_ export: ReferralDataExport, to email: String) async throws {
        // Would send email with export attachment or secure download link
        Logger.shared.info("Would deliver export \(export.exportId) to \(email)", category: .referral)
    }

    private func notifyAdminOfObjection(userId: String) async {
        // Would send notification to admin
        Logger.shared.info("Admin notification: User \(userId) objected to data processing", category: .referral)
    }

    // MARK: - Pending Requests

    /// Fetches pending data subject requests
    func fetchPendingRequests() async throws {
        let snapshot = try await db.collection("dataSubjectRequests")
            .whereField("status", in: [RequestStatus.pending.rawValue, RequestStatus.inProgress.rawValue])
            .order(by: "deadline")
            .getDocuments()

        pendingRequests = snapshot.documents.compactMap { doc -> DataSubjectRequest? in
            let data = doc.data()
            guard let typeStr = data["requestType"] as? String,
                  let type = DataRequestType(rawValue: typeStr),
                  let statusStr = data["status"] as? String,
                  let status = RequestStatus(rawValue: statusStr),
                  let regStr = data["regulation"] as? String,
                  let regulation = PrivacyRegulation(rawValue: regStr) else {
                return nil
            }

            return DataSubjectRequest(
                id: doc.documentID,
                userId: data["userId"] as? String ?? "",
                email: data["email"] as? String ?? "",
                requestType: type,
                status: status,
                regulation: regulation,
                requestedAt: (data["requestedAt"] as? Timestamp)?.dateValue() ?? Date(),
                deadline: (data["deadline"] as? Timestamp)?.dateValue() ?? Date(),
                completedAt: (data["completedAt"] as? Timestamp)?.dateValue(),
                notes: data["notes"] as? String,
                verificationToken: data["verificationToken"] as? String,
                verified: data["verified"] as? Bool ?? false
            )
        }
    }
}

// MARK: - Errors

enum ComplianceError: LocalizedError {
    case requestNotVerified
    case consentRequired
    case dataNotFound
    case exportFailed
    case deletionFailed

    var errorDescription: String? {
        switch self {
        case .requestNotVerified:
            return "Request must be verified before processing"
        case .consentRequired:
            return "User consent is required for this operation"
        case .dataNotFound:
            return "Requested data not found"
        case .exportFailed:
            return "Failed to export user data"
        case .deletionFailed:
            return "Failed to delete user data"
        }
    }
}

// MARK: - ConsentType All Cases

extension ConsentType: CaseIterable {}
