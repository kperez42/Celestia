//
//  MatchService.swift
//  Celestia
//
//  Service for match-related operations
//

import Foundation
import Firebase
import FirebaseFirestore

@MainActor
class MatchService: ObservableObject, MatchServiceProtocol, ListenerLifecycleAware {
    @Published var matches: [Match] = []
    @Published var isLoading = false
    @Published var error: Error?

    // Dependency injection: Repository for data access
    private let repository: MatchRepository

    // Singleton for backward compatibility (uses default repository)
    static let shared = MatchService(repository: FirestoreMatchRepository())

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    // LIFECYCLE: Track current user for reconnection
    private var currentUserId: String?

    // MARK: - ListenerLifecycleAware Conformance

    nonisolated var listenerId: String { "MatchService" }

    var areListenersActive: Bool {
        listener != nil
    }

    func reconnectListeners() {
        guard let userId = currentUserId else {
            Logger.shared.debug("MatchService: No userId for reconnection", category: .general)
            return
        }
        Logger.shared.info("MatchService: Reconnecting listeners for user: \(userId)", category: .general)
        listenToMatches(userId: userId)
    }

    func pauseListeners() {
        Logger.shared.info("MatchService: Pausing listeners", category: .general)
        stopListening()
    }

    // Dependency injection initializer
    init(repository: MatchRepository) {
        self.repository = repository
        // Register with lifecycle manager for automatic reconnection handling
        ListenerLifecycleManager.shared.register(self)
    }
    
    /// Fetch all matches for a user
    func fetchMatches(userId: String) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            matches = try await repository.fetchMatches(userId: userId)
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// Listen to matches in real-time
    func listenToMatches(userId: String) {
        // LIFECYCLE: Store userId for reconnection
        currentUserId = userId

        listener?.remove()

        // Use OR filter for optimized single listener (fixes race condition)
        listener = db.collection("matches")
            .whereFilter(Filter.orFilter([
                Filter.whereField("user1Id", isEqualTo: userId),
                Filter.whereField("user2Id", isEqualTo: userId)
            ]))
            .whereField("isActive", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                Task { @MainActor in
                    if let error = error {
                        Logger.shared.error("Error listening to matches: \(error)", category: .general)
                        return
                    }

                    guard let documents = snapshot?.documents else { return }

                    let allMatches = documents.compactMap { try? $0.data(as: Match.self) }
                    self.matches = allMatches.sorted {
                        ($0.lastMessageTimestamp ?? $0.timestamp) > ($1.lastMessageTimestamp ?? $1.timestamp)
                    }
                }
            }
    }
    
    /// Stop listening to matches
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    /// Create a new match between two users
    func createMatch(user1Id: String, user2Id: String) async {
        // CONCURRENCY FIX: Removed redundant check - repository now handles atomically with transaction
        // The FirestoreMatchRepository.createMatch() now uses a deterministic ID and transaction
        // to prevent race conditions, so no need to check before creating

        let match = Match(user1Id: user1Id, user2Id: user2Id)

        do {
            let matchId = try await repository.createMatch(match: match)

            // Update match counts for both users (non-blocking - may fail due to permissions)
            // Note: Security rules only allow users to update their own document, so updating
            // the other user's matchCount requires a Cloud Function. For now, we just update
            // the current user's count and log if the other fails.
            if let firestoreRepo = repository as? FirestoreMatchRepository {
                do {
                    try await firestoreRepo.updateMatchCounts(user1Id: user1Id, user2Id: user2Id)
                } catch {
                    // Expected to fail for the other user due to security rules
                    // The match is still created, just the denormalized count may be off
                    Logger.shared.debug("Could not update match counts (expected): \(error.localizedDescription)", category: .matching)
                }
            }

            // PERFORMANCE FIX: Batch fetch both users in a single query (prevents N+1 problem)
            let usersSnapshot = try? await db.collection("users")
                .whereField(FieldPath.documentID(), in: [user1Id, user2Id])
                .getDocuments()

            // Create a dictionary for quick lookup
            var userDataMap: [String: [String: Any]] = [:]
            usersSnapshot?.documents.forEach { doc in
                userDataMap[doc.documentID] = doc.data()
            }

            // Get user data from the map
            if let user1Data = userDataMap[user1Id],
               let user2Data = userDataMap[user2Id],
               let user1Name = user1Data["fullName"] as? String,
               let user2Name = user2Data["fullName"] as? String {

                // Create match object with ID for notifications
                var matchWithId = match
                matchWithId.id = matchId

                // Send notifications to both users
                let notificationService = NotificationService.shared

                // Create temporary user objects for notifications using factory method
                do {
                    let user1 = try User.createMinimal(id: user1Id, fullName: user1Name, from: user1Data)
                    let user2 = try User.createMinimal(id: user2Id, fullName: user2Name, from: user2Data)

                    await notificationService.sendNewMatchNotification(match: matchWithId, otherUser: user2)
                    await notificationService.sendNewMatchNotification(match: matchWithId, otherUser: user1)
                } catch {
                    Logger.shared.error("Failed to create user objects for match notification: \(error.localizedDescription)", category: .matching)
                    return
                }
            }
        } catch {
            Logger.shared.error("Error creating match: \(error)", category: .general)
            self.error = error
        }
    }
    
    /// Fetch a specific match between two users
    func fetchMatch(user1Id: String, user2Id: String) async throws -> Match? {
        return try await repository.fetchMatch(user1Id: user1Id, user2Id: user2Id)
    }
    
    /// Update match with last message info
    func updateMatchLastMessage(matchId: String, message: String, timestamp: Date) async throws {
        try await repository.updateMatchLastMessage(matchId: matchId, message: message, timestamp: timestamp)
    }
    
    /// Increment unread count for a user
    func incrementUnreadCount(matchId: String, userId: String) async throws {
        if let firestoreRepo = repository as? FirestoreMatchRepository {
            try await firestoreRepo.incrementUnreadCount(matchId: matchId, userId: userId)
        }
    }

    /// Reset unread count for a user
    func resetUnreadCount(matchId: String, userId: String) async throws {
        if let firestoreRepo = repository as? FirestoreMatchRepository {
            try await firestoreRepo.resetUnreadCount(matchId: matchId, userId: userId)
        }
    }

    /// Unmatch - Deactivate match and clean up related data
    func unmatch(matchId: String, userId: String) async throws {
        if let firestoreRepo = repository as? FirestoreMatchRepository {
            try await firestoreRepo.unmatch(matchId: matchId, userId: userId)
        }
        Logger.shared.info("Unmatched successfully", category: .matching)
    }

    /// Deactivate a match (soft delete)
    func deactivateMatch(matchId: String) async throws {
        try await repository.deactivateMatch(matchId: matchId)
    }

    /// Delete a match permanently (use with caution)
    func deleteMatch(matchId: String) async throws {
        try await repository.deleteMatch(matchId: matchId)
    }
    
    /// Get total unread messages count for user
    func getTotalUnreadCount(userId: String) async throws -> Int {
        try await fetchMatches(userId: userId)
        
        return matches.reduce(0) { total, match in
            total + (match.unreadCount[userId] ?? 0)
        }
    }
    
    /// Check if two users have matched
    func hasMatched(user1Id: String, user2Id: String) async throws -> Bool {
        let match = try await fetchMatch(user1Id: user1Id, user2Id: user2Id)
        return match != nil
    }
    
    
    deinit {
        listener?.remove()
        // LIFECYCLE: Unregister from lifecycle manager
        Task { @MainActor in
            ListenerLifecycleManager.shared.unregister(id: "MatchService")
        }
    }
}
