//
//  BlockReportService.swift
//  Celestia
//
//  Service for managing blocked and reported users
//

import Foundation
import FirebaseFirestore

@MainActor
class BlockReportService: ObservableObject {
    static let shared = BlockReportService()

    private let db = Firestore.firestore()

    @Published var blockedUserIds: Set<String> = []
    @Published var isLoading = false

    private init() {
        loadBlockedUsers()
    }

    // MARK: - Block User

    func blockUser(userId: String, currentUserId: String) async throws {
        isLoading = true
        defer { isLoading = false }

        // Add to blocked users collection
        try await db.collection("blockedUsers")
            .document("\(currentUserId)_\(userId)")
            .setData([
                "blockerId": currentUserId,
                "blockedUserId": userId,
                "timestamp": Timestamp(date: Date())
            ])

        // Update local set
        blockedUserIds.insert(userId)

        // Remove any existing match
        await removeMatch(userId: userId, currentUserId: currentUserId)
    }

    func unblockUser(blockerId: String, blockedId: String) async throws {
        isLoading = true
        defer { isLoading = false }

        try await db.collection("blockedUsers")
            .document("\(blockerId)_\(blockedId)")
            .delete()

        blockedUserIds.remove(blockedId)
    }

    func isUserBlocked(_ userId: String) -> Bool {
        blockedUserIds.contains(userId)
    }

    func getBlockedUsers() async throws -> [User] {
        guard let currentUserId = AuthService.shared.currentUser?.id else {
            return []
        }

        let snapshot = try await db.collection("blockedUsers")
            .whereField("blockerId", isEqualTo: currentUserId)
            .getDocuments()

        let blockedUserIds = snapshot.documents.compactMap { doc -> String? in
            doc.data()["blockedUserId"] as? String
        }

        // Fetch user details for each blocked user
        var users: [User] = []
        for userId in blockedUserIds {
            if let userSnapshot = try? await db.collection("users").document(userId).getDocument(),
               let user = try? userSnapshot.data(as: User.self) {
                users.append(user)
            }
        }

        return users
    }

    private func loadBlockedUsers() {
        guard let currentUserId = AuthService.shared.currentUser?.id else { return }

        db.collection("blockedUsers")
            .whereField("blockerId", isEqualTo: currentUserId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }

                let blockedIds = Set(documents.compactMap { doc -> String? in
                    doc.data()["blockedUserId"] as? String
                })

                Task { @MainActor in
                    self?.blockedUserIds = blockedIds
                }
            }
    }

    // MARK: - Report User

    func reportUser(
        userId: String,
        currentUserId: String,
        reason: ReportReason,
        additionalDetails: String?
    ) async throws {
        isLoading = true
        defer { isLoading = false }

        var reportData: [String: Any] = [
            "reporterId": currentUserId,
            "reportedUserId": userId,
            "reason": reason.rawValue,
            "timestamp": Timestamp(date: Date()),
            "status": "pending"
        ]

        if let details = additionalDetails, !details.isEmpty {
            reportData["additionalDetails"] = details
        }

        try await db.collection("reports").addDocument(data: reportData)

        // Also block the user after reporting
        try await blockUser(userId: userId, currentUserId: currentUserId)
    }

    // MARK: - Unmatch

    func unmatchUser(matchId: String, reason: UnmatchReason?, feedback: String?) async throws {
        isLoading = true
        defer { isLoading = false }

        // Mark match as inactive
        var updateData: [String: Any] = [
            "isActive": false,
            "unmatchedAt": Timestamp(date: Date())
        ]

        if let reason = reason {
            updateData["unmatchReason"] = reason.rawValue
        }

        if let feedback = feedback, !feedback.isEmpty {
            updateData["unmatchFeedback"] = feedback
        }

        try await db.collection("matches")
            .document(matchId)
            .updateData(updateData)
    }

    // MARK: - Helper Methods

    private func removeMatch(userId: String, currentUserId: String) async {
        // Find and remove match between users
        do {
            let matchesSnapshot = try await db.collection("matches")
                .whereFilter(Filter.orFilter([
                    Filter.andFilter([
                        Filter.whereField("user1Id", isEqualTo: currentUserId),
                        Filter.whereField("user2Id", isEqualTo: userId)
                    ]),
                    Filter.andFilter([
                        Filter.whereField("user1Id", isEqualTo: userId),
                        Filter.whereField("user2Id", isEqualTo: currentUserId)
                    ])
                ]))
                .getDocuments()

            for document in matchesSnapshot.documents {
                try await document.reference.updateData(["isActive": false])
            }
        } catch {
            Logger.shared.error("Error removing match", category: .moderation, error: error)
        }
    }
}

// ReportReason is defined in Safety/Reporting/ReportingManager.swift

// MARK: - Unmatch Reason

enum UnmatchReason: String, CaseIterable {
    case notInterested = "Not interested anymore"
    case noResponse = "No response to messages"
    case foundSomeone = "Found someone else"
    case notRealPerson = "Doesn't seem like a real person"
    case inappropriate = "Inappropriate behavior"
    case other = "Other reason"

    var icon: String {
        switch self {
        case .notInterested: return "hand.raised.fill"
        case .noResponse: return "message.fill"
        case .foundSomeone: return "heart.fill"
        case .notRealPerson: return "person.fill.questionmark"
        case .inappropriate: return "exclamationmark.triangle.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}
