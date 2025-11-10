//
//  ReportingManager.swift
//  Celestia
//
//  User reporting system for inappropriate behavior, scams, harassment
//  Integrates with moderation workflow and automated detection
//

import Foundation

// MARK: - Reporting Manager

@MainActor
class ReportingManager: ObservableObject {

    // MARK: - Singleton

    static let shared = ReportingManager()

    // MARK: - Published Properties

    @Published var pendingReports: [Report] = []
    @Published var userReportHistory: [Report] = []

    // MARK: - Private Properties

    private let maxReportsPerDay = 10
    private var reportCounts: [String: Int] = [:] // userId -> count

    // MARK: - Initialization

    private init() {
        loadReportHistory()
        Logger.shared.info("ReportingManager initialized", category: .general)
    }

    // MARK: - Report Submission

    /// Submit a report about another user
    func submitReport(
        reportedUserId: String,
        reason: ReportReason,
        description: String?,
        evidence: ReportEvidence?
    ) async throws -> Report {

        Logger.shared.info("Submitting report for user: \(reportedUserId)", category: .general)

        // Check rate limiting
        guard canSubmitReport() else {
            throw ReportError.rateLimitExceeded
        }

        // Create report
        let report = Report(
            id: UUID().uuidString,
            reportedUserId: reportedUserId,
            reporterId: getCurrentUserId(),
            reason: reason,
            description: description,
            evidence: evidence,
            status: .pending,
            submittedAt: Date(),
            updatedAt: Date()
        )

        // Auto-analyze report for urgency
        let urgency = analyzeReportUrgency(report)
        var updatedReport = report
        updatedReport.urgency = urgency

        // If high urgency, flag for immediate review
        if urgency == .critical {
            updatedReport.status = .underReview
            Logger.shared.warning("Critical report submitted for user: \(reportedUserId)", category: .general)
        }

        // Save report locally
        pendingReports.append(updatedReport)
        userReportHistory.append(updatedReport)
        saveReportHistory()

        // Update rate limiting
        incrementReportCount()

        // Send to backend
        try await sendReportToBackend(updatedReport)

        // Track analytics
        AnalyticsManager.shared.logEvent(.reportSubmitted, parameters: [
            "reason": reason.rawValue,
            "urgency": urgency.rawValue,
            "has_evidence": evidence != nil
        ])

        Logger.shared.info("Report submitted successfully", category: .general)

        return updatedReport
    }

    /// Quick report (no description needed)
    func quickReport(
        reportedUserId: String,
        reason: ReportReason
    ) async throws -> Report {
        return try await submitReport(
            reportedUserId: reportedUserId,
            reason: reason,
            description: nil,
            evidence: nil
        )
    }

    /// Report with message evidence
    func reportWithMessages(
        reportedUserId: String,
        reason: ReportReason,
        messages: [ChatMessage]
    ) async throws -> Report {

        // Analyze messages with scammer detector
        let scamAnalysis = ScammerDetector.shared.analyzeConversation(messages: messages)

        let evidence = ReportEvidence(
            type: .messages,
            messages: messages,
            screenshots: nil,
            scamAnalysis: scamAnalysis
        )

        return try await submitReport(
            reportedUserId: reportedUserId,
            reason: reason,
            description: "User exhibited scam behavior in chat. Scam score: \(scamAnalysis.scamScore)",
            evidence: evidence
        )
    }

    // MARK: - Report Status

    /// Check status of a submitted report
    func checkReportStatus(reportId: String) async throws -> ReportStatus {
        // In production, query backend API
        if let report = userReportHistory.first(where: { $0.id == reportId }) {
            return report.status
        }

        throw ReportError.reportNotFound
    }

    /// Get all reports submitted by current user
    func getUserReports() -> [Report] {
        return userReportHistory.sorted { $0.submittedAt > $1.submittedAt }
    }

    // MARK: - Urgency Analysis

    private func analyzeReportUrgency(_ report: Report) -> ReportUrgency {
        var urgencyScore = 0

        // Critical reasons
        if [.threats, .minors, .violence].contains(report.reason) {
            return .critical
        }

        // High priority reasons
        if [.scam, .harassment, .inappropriateContent].contains(report.reason) {
            urgencyScore += 2
        }

        // Evidence boosts urgency
        if let evidence = report.evidence {
            if evidence.scamAnalysis?.isScam == true {
                urgencyScore += 2
            }
            if evidence.messages != nil || evidence.screenshots != nil {
                urgencyScore += 1
            }
        }

        // Detailed description indicates serious report
        if let description = report.description, description.count > 100 {
            urgencyScore += 1
        }

        if urgencyScore >= 3 {
            return .high
        } else if urgencyScore >= 1 {
            return .medium
        } else {
            return .low
        }
    }

    // MARK: - Rate Limiting

    private func canSubmitReport() -> Bool {
        let userId = getCurrentUserId()
        let count = reportCounts[userId] ?? 0
        return count < maxReportsPerDay
    }

    private func incrementReportCount() {
        let userId = getCurrentUserId()
        reportCounts[userId, default: 0] += 1
    }

    // MARK: - Backend Communication

    private func sendReportToBackend(_ report: Report) async throws {
        // In production, send to moderation API
        Logger.shared.debug("Sending report to backend: \(report.id)", category: .general)

        // Simulate API call
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // In production:
        // let url = URL(string: "\(apiBaseURL)/reports")!
        // var request = URLRequest(url: url)
        // request.httpMethod = "POST"
        // request.httpBody = try JSONEncoder().encode(report)
        // let (_, response) = try await URLSession.shared.data(for: request)
        // ... handle response
    }

    // MARK: - Persistence

    private func loadReportHistory() {
        // Load from UserDefaults or local database
        if let data = UserDefaults.standard.data(forKey: "user_report_history"),
           let reports = try? JSONDecoder().decode([Report].self, from: data) {
            userReportHistory = reports
        }
    }

    private func saveReportHistory() {
        if let data = try? JSONEncoder().encode(userReportHistory) {
            UserDefaults.standard.set(data, forKey: "user_report_history")
        }
    }

    // MARK: - Helpers

    private func getCurrentUserId() -> String {
        // In production, get from authentication service
        return "current_user_id"
    }

    // MARK: - Block Management

    /// Block a user after reporting
    func blockUserAfterReport(userId: String) {
        Logger.shared.info("User blocked after report: \(userId)", category: .general)

        // Track analytics
        AnalyticsManager.shared.logEvent(.userBlocked, parameters: [
            "source": "report",
            "user_id": userId
        ])

        // In production, call blocking service
        // BlockingManager.shared.blockUser(userId)
    }
}

// MARK: - Report Model

struct Report: Codable, Identifiable {
    let id: String
    let reportedUserId: String
    let reporterId: String
    let reason: ReportReason
    let description: String?
    let evidence: ReportEvidence?
    var status: ReportStatus
    var urgency: ReportUrgency = .low
    let submittedAt: Date
    var updatedAt: Date
    var moderatorNotes: String?
    var resolution: String?
}

// MARK: - Report Reason

enum ReportReason: String, Codable, CaseIterable {
    case scam = "scam"
    case fakeProfile = "fake_profile"
    case harassment = "harassment"
    case inappropriateContent = "inappropriate_content"
    case spam = "spam"
    case threats = "threats"
    case violence = "violence"
    case hateSpeech = "hate_speech"
    case minors = "minors"
    case stolen_photos = "stolen_photos"
    case impersonation = "impersonation"
    case other = "other"

    var displayName: String {
        switch self {
        case .scam:
            return "Scam or Fraud"
        case .fakeProfile:
            return "Fake Profile"
        case .harassment:
            return "Harassment"
        case .inappropriateContent:
            return "Inappropriate Content"
        case .spam:
            return "Spam"
        case .threats:
            return "Threats or Violence"
        case .violence:
            return "Violence"
        case .hateSpeech:
            return "Hate Speech"
        case .minors:
            return "Underage User"
        case .stolen_photos:
            return "Stolen Photos"
        case .impersonation:
            return "Impersonation"
        case .other:
            return "Other"
        }
    }

    var description: String {
        switch self {
        case .scam:
            return "User is attempting to scam or defraud others"
        case .fakeProfile:
            return "Profile appears to be fake or bot account"
        case .harassment:
            return "User is harassing or bullying others"
        case .inappropriateContent:
            return "Profile contains inappropriate or offensive content"
        case .spam:
            return "User is sending spam or promotional content"
        case .threats:
            return "User is making threats or promoting violence"
        case .violence:
            return "Content depicts violence or harm"
        case .hateSpeech:
            return "User is using hate speech or discrimination"
        case .minors:
            return "Profile appears to belong to someone under 18"
        case .stolen_photos:
            return "User is using stolen or unauthorized photos"
        case .impersonation:
            return "User is impersonating someone else"
        case .other:
            return "Other safety concern"
        }
    }

    var icon: String {
        switch self {
        case .scam:
            return "dollarsign.circle"
        case .fakeProfile:
            return "person.crop.circle.badge.xmark"
        case .harassment:
            return "exclamationmark.bubble"
        case .inappropriateContent:
            return "eye.slash"
        case .spam:
            return "envelope.badge.fill"
        case .threats:
            return "exclamationmark.triangle.fill"
        case .violence:
            return "exclamationmark.shield"
        case .hateSpeech:
            return "hand.raised.fill"
        case .minors:
            return "person.crop.circle.badge.exclamationmark"
        case .stolen_photos:
            return "photo.badge.exclamationmark"
        case .impersonation:
            return "person.2.badge.gearshape"
        case .other:
            return "flag"
        }
    }
}

// MARK: - Report Status

enum ReportStatus: String, Codable {
    case pending = "pending"
    case underReview = "under_review"
    case resolved = "resolved"
    case dismissed = "dismissed"
    case actionTaken = "action_taken"

    var displayName: String {
        switch self {
        case .pending:
            return "Pending Review"
        case .underReview:
            return "Under Review"
        case .resolved:
            return "Resolved"
        case .dismissed:
            return "Dismissed"
        case .actionTaken:
            return "Action Taken"
        }
    }
}

// MARK: - Report Urgency

enum ReportUrgency: String, Codable {
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

// MARK: - Report Evidence

struct ReportEvidence: Codable {
    let type: EvidenceType
    let messages: [ChatMessage]?
    let screenshots: [String]? // URLs or base64
    let scamAnalysis: ConversationScamAnalysis?
}

enum EvidenceType: String, Codable {
    case messages = "messages"
    case screenshots = "screenshots"
    case profile = "profile"
}

// MARK: - Errors

enum ReportError: LocalizedError {
    case rateLimitExceeded
    case reportNotFound
    case networkError
    case invalidReport

    var errorDescription: String? {
        switch self {
        case .rateLimitExceeded:
            return "You've submitted too many reports today. Please try again tomorrow."
        case .reportNotFound:
            return "Report not found"
        case .networkError:
            return "Network error while submitting report"
        case .invalidReport:
            return "Invalid report data"
        }
    }
}

// MARK: - Codable Conformance
// ChatMessage, ScamAnalysis, and ConversationScamAnalysis are Codable (defined in ScammerDetector.swift)
