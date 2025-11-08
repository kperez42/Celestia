//
//  ReportBlockService.swift
//  Celestia
//
//  Created by Claude
//  Service for reporting and blocking users
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

enum ReportReason: String, CaseIterable {
    case inappropriateContent = "Inappropriate content"
    case spam = "Spam or scam"
    case harassment = "Harassment"
    case fakeProfile = "Fake profile"
    case underAge = "Underage user"
    case hateSpeech = "Hate speech"
    case violence = "Violence or threats"
    case other = "Other"

    var description: String {
        rawValue
    }
}

struct Report: Codable {
    var id: String?
    var reporterId: String
    var reportedUserId: String
    var reason: String
    var additionalInfo: String
    var timestamp: Date
    var status: String // "pending", "reviewed", "resolved"
}

@MainActor
class ReportBlockService: ObservableObject {
    static let shared = ReportBlockService()

    private let db = Firestore.firestore()
    @Published var blockedUserIDs: Set<String> = []
    @Published var isLoading = false

    private init() {
        loadBlockedUsers()
    }

    // MARK: - Block/Unblock

    func blockUser(userId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        isLoading = true
        defer { isLoading = false }

        // Add to blocked users collection
        let blockData: [String: Any] = [
            "blockerId": currentUserId,
            "blockedUserId": userId,
            "timestamp": Timestamp(date: Date())
        ]

        try await db.collection("blocked_users")
            .document("\(currentUserId)_\(userId)")
            .setData(blockData)

        // Add to local set
        blockedUserIDs.insert(userId)

        // Remove any existing matches
        try? await removeMatch(with: userId)

        // Analytics
        print("✅ Blocked user: \(userId)")
    }

    func unblockUser(userId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        isLoading = true
        defer { isLoading = false }

        try await db.collection("blocked_users")
            .document("\(currentUserId)_\(userId)")
            .delete()

        blockedUserIDs.remove(userId)

        print("✅ Unblocked user: \(userId)")
    }

    func isBlocked(userId: String) -> Bool {
        blockedUserIDs.contains(userId)
    }

    func loadBlockedUsers() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        db.collection("blocked_users")
            .whereField("blockerId", isEqualTo: currentUserId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching blocked users: \(error?.localizedDescription ?? "Unknown")")
                    return
                }

                let blockedIds = documents.compactMap { doc in
                    doc.data()["blockedUserId"] as? String
                }

                self?.blockedUserIDs = Set(blockedIds)
            }
    }

    // MARK: - Report

    func reportUser(
        userId: String,
        reason: ReportReason,
        additionalInfo: String = ""
    ) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        isLoading = true
        defer { isLoading = false }

        let report = Report(
            reporterId: currentUserId,
            reportedUserId: userId,
            reason: reason.rawValue,
            additionalInfo: additionalInfo,
            timestamp: Date(),
            status: "pending"
        )

        let reportData: [String: Any] = [
            "reporterId": report.reporterId,
            "reportedUserId": report.reportedUserId,
            "reason": report.reason,
            "additionalInfo": report.additionalInfo,
            "timestamp": Timestamp(date: report.timestamp),
            "status": report.status
        ]

        try await db.collection("reports").addDocument(data: reportData)

        // Also block the user automatically when reporting
        try await blockUser(userId: userId)

        print("✅ Reported user: \(userId) for \(reason.rawValue)")
    }

    // MARK: - Helper Methods

    private func removeMatch(with userId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        // Try both possible match document IDs
        let matchId1 = "\(currentUserId)_\(userId)"
        let matchId2 = "\(userId)_\(currentUserId)"

        try? await db.collection("matches").document(matchId1).delete()
        try? await db.collection("matches").document(matchId2).delete()
    }

    func getBlockedUsers() async throws -> [User] {
        guard !blockedUserIDs.isEmpty else { return [] }

        var blockedUsers: [User] = []

        for userId in blockedUserIDs {
            if let document = try? await db.collection("users").document(userId).getDocument(),
               let data = document.data() {
                let user = User(dictionary: data)
                blockedUsers.append(user)
            }
        }

        return blockedUsers
    }
}
