//
//  BlockReportService.swift
//  Celestia
//
//  Service for managing blocked and reported users
//

import Foundation
import FirebaseFirestore

@MainActor
class BlockReportService: ObservableObject, ListenerLifecycleAware {
    static let shared = BlockReportService()

    private let db = Firestore.firestore()

    @Published var blockedUserIds: Set<String> = []
    @Published var isLoading = false

    // AUDIT FIX: Store listener reference for proper cleanup
    private var blockedUsersListener: ListenerRegistration?

    // MARK: - ListenerLifecycleAware Conformance

    nonisolated var listenerId: String { "BlockReportService" }

    var areListenersActive: Bool {
        blockedUsersListener != nil
    }

    func reconnectListeners() {
        Logger.shared.info("BlockReportService: Reconnecting listeners", category: .general)
        restartListening()
    }

    func pauseListeners() {
        Logger.shared.info("BlockReportService: Pausing listeners", category: .general)
        stopListening()
    }

    private init() {
        // Register with lifecycle manager for automatic reconnection handling
        ListenerLifecycleManager.shared.register(self)
        loadBlockedUsers()
    }

    // AUDIT FIX: Clean up listener when no longer needed
    func stopListening() {
        blockedUsersListener?.remove()
        blockedUsersListener = nil
    }

    // MARK: - Block User

    func blockUser(userId: String, currentUserId: String) async throws {
        isLoading = true
        defer { isLoading = false }

        // ATOMICITY FIX: Use batch to ensure blocking and match removal happen together
        // If either operation fails, neither is applied
        do {
            // First, find any existing matches to deactivate
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
                .whereField("isActive", isEqualTo: true)
                .getDocuments()

            // Create batch for atomic operation
            let batch = db.batch()

            // 1. Add to blocked users
            let blockRef = db.collection("blockedUsers").document("\(currentUserId)_\(userId)")
            batch.setData([
                "blockerId": currentUserId,
                "blockedUserId": userId,
                "timestamp": Timestamp(date: Date())
            ], forDocument: blockRef)

            // 2. Deactivate any active matches
            for matchDoc in matchesSnapshot.documents {
                batch.updateData([
                    "isActive": false,
                    "deactivatedReason": "blocked",
                    "deactivatedAt": Timestamp(date: Date())
                ], forDocument: matchDoc.reference)
            }

            // Commit all operations atomically
            try await batch.commit()

            // Update local state only after successful commit
            blockedUserIds.insert(userId)

            Logger.shared.info("User blocked successfully (deactivated \(matchesSnapshot.documents.count) matches)", category: .moderation)

        } catch {
            Logger.shared.error("Failed to block user atomically", category: .moderation, error: error)
            throw error
        }
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
        // BUGFIX: Use effectiveId for reliable user identification
        guard let currentUserId = AuthService.shared.currentUser?.effectiveId else {
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
        // BUGFIX: Use effectiveId for reliable user identification
        guard let currentUserId = AuthService.shared.currentUser?.effectiveId else { return }

        // AUDIT FIX: Remove existing listener before creating new one
        blockedUsersListener?.remove()

        // AUDIT FIX: Store the listener reference so it can be cleaned up
        blockedUsersListener = db.collection("blockedUsers")
            .whereField("blockerId", isEqualTo: currentUserId)
            .addSnapshotListener { [weak self] snapshot, error in
                // AUDIT FIX: Log errors instead of silently ignoring them
                if let error = error {
                    Logger.shared.error("Error listening to blocked users", category: .general, error: error)
                    return
                }

                guard let documents = snapshot?.documents else { return }

                let blockedIds = Set(documents.compactMap { doc -> String? in
                    doc.data()["blockedUserId"] as? String
                })

                Task { @MainActor in
                    self?.blockedUserIds = blockedIds
                }
            }
    }

    /// Restart listening after user logs in or changes
    func restartListening() {
        loadBlockedUsers()
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

        // ATOMICITY FIX: Create report and block user in a single batch operation
        // This ensures both operations succeed or fail together

        do {
            // First, find any existing matches to deactivate
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
                .whereField("isActive", isEqualTo: true)
                .getDocuments()

            // Create batch for atomic operation
            let batch = db.batch()

            // 1. Create report
            let reportRef = db.collection("reports").document()
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
            batch.setData(reportData, forDocument: reportRef)

            // 2. Block the user
            let blockRef = db.collection("blockedUsers").document("\(currentUserId)_\(userId)")
            batch.setData([
                "blockerId": currentUserId,
                "blockedUserId": userId,
                "timestamp": Timestamp(date: Date()),
                "reportId": reportRef.documentID  // Link to report for reference
            ], forDocument: blockRef)

            // 3. Deactivate any active matches
            for matchDoc in matchesSnapshot.documents {
                batch.updateData([
                    "isActive": false,
                    "deactivatedReason": "reported",
                    "deactivatedAt": Timestamp(date: Date())
                ], forDocument: matchDoc.reference)
            }

            // Commit all operations atomically
            try await batch.commit()

            // Update local state only after successful commit
            blockedUserIds.insert(userId)

            Logger.shared.info("User reported and blocked successfully (report: \(reportRef.documentID), deactivated \(matchesSnapshot.documents.count) matches)", category: .moderation)

        } catch {
            Logger.shared.error("Failed to report user atomically", category: .moderation, error: error)
            throw error
        }
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
