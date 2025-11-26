//
//  InterestService.swift
//  Celestia
//
//  Service for handling user interests and likes
//

import Foundation
import Firebase
import FirebaseFirestore

@MainActor
class InterestService: ObservableObject, ListenerLifecycleAware {
    @Published var sentInterests: [Interest] = []
    @Published var receivedInterests: [Interest] = []
    @Published var isLoading = false
    @Published var error: Error?

    static let shared = InterestService()
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var lastReceivedDocument: DocumentSnapshot?
    private var lastSentDocument: DocumentSnapshot?

    // LIFECYCLE: Track current user for reconnection
    private var currentUserId: String?

    // MARK: - ListenerLifecycleAware Conformance

    nonisolated var listenerId: String { "InterestService" }

    var areListenersActive: Bool {
        listener != nil
    }

    func reconnectListeners() {
        guard let userId = currentUserId else {
            Logger.shared.debug("InterestService: No userId for reconnection", category: .matching)
            return
        }
        Logger.shared.info("InterestService: Reconnecting listeners for user: \(userId)", category: .matching)
        listenToReceivedInterests(userId: userId)
    }

    func pauseListeners() {
        Logger.shared.info("InterestService: Pausing listeners", category: .matching)
        stopListening()
    }

    private init() {
        // Register with lifecycle manager for automatic reconnection handling
        ListenerLifecycleManager.shared.register(self)
    }
    
    // MARK: - Send Interest
    
    func sendInterest(
        fromUserId: String,
        toUserId: String,
        message: String? = nil
    ) async throws {
        // Check rate limiting
        guard RateLimiter.shared.canSendLike() else {
            if let timeRemaining = RateLimiter.shared.timeUntilReset(for: .like) {
                throw CelestiaError.rateLimitExceededWithTime(timeRemaining)
            }
            throw CelestiaError.rateLimitExceeded
        }

        // UX FIX: Properly handle interest check instead of silent failure
        do {
            if let existingInterest = try await fetchInterest(fromUserId: fromUserId, toUserId: toUserId) {
                Logger.shared.info("Interest already sent to this user: \(existingInterest.id ?? "unknown")", category: .matching)
                return
            }
        } catch {
            Logger.shared.error("Failed to check existing interest, proceeding anyway", category: .matching, error: error)
            // Continue with sending interest rather than failing silently
        }

        // Validate message if provided
        if let msg = message, !msg.isEmpty {
            guard ContentModerator.shared.isAppropriate(msg) else {
                let violations = ContentModerator.shared.getViolations(msg)
                throw CelestiaError.inappropriateContentWithReasons(violations)
            }
        }

        let interest = Interest(
            fromUserId: fromUserId,
            toUserId: toUserId,
            message: message
        )
        
        let docRef = try db.collection("interests").addDocument(from: interest)
        Logger.shared.info("Interest sent: \(docRef.documentID)", category: .matching)

        // CRITICAL UX FIX: Properly handle mutual match check - silently failing prevents matches!
        do {
            if let mutualInterest = try await fetchInterest(fromUserId: toUserId, toUserId: fromUserId),
               mutualInterest.status == "pending" {
                // Both users liked each other - create match!
                await MatchService.shared.createMatch(user1Id: fromUserId, user2Id: toUserId)

                // Update both interests to accepted
                try await acceptInterest(interestId: docRef.documentID, fromUserId: fromUserId, toUserId: toUserId)
                if let mutualId = mutualInterest.id {
                    try await acceptInterest(interestId: mutualId, fromUserId: toUserId, toUserId: fromUserId)
                }
            }
        } catch {
            Logger.shared.error("Failed to check for mutual interest - match may be delayed", category: .matching, error: error)
            // Don't throw - the interest was still sent successfully
        }
    }
    
    // MARK: - Fetch Interest
    
    func fetchInterest(fromUserId: String, toUserId: String) async throws -> Interest? {
        let snapshot = try await db.collection("interests")
            .whereField("fromUserId", isEqualTo: fromUserId)
            .whereField("toUserId", isEqualTo: toUserId)
            .limit(to: 1)
            .getDocuments()
        
        return snapshot.documents.first.flatMap { try? $0.data(as: Interest.self) }
    }
    
    // MARK: - Fetch Received Interests

    func fetchReceivedInterests(userId: String, limit: Int = 20, reset: Bool = true) async throws {
        isLoading = true
        defer { isLoading = false }

        if reset {
            lastReceivedDocument = nil
            receivedInterests = []
        }

        var query = db.collection("interests")
            .whereField("toUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)

        if let lastDoc = lastReceivedDocument {
            query = query.start(afterDocument: lastDoc)
        }

        let snapshot = try await query.getDocuments()
        lastReceivedDocument = snapshot.documents.last

        let newInterests = snapshot.documents.compactMap { try? $0.data(as: Interest.self) }
        receivedInterests.append(contentsOf: newInterests)
    }
    
    // MARK: - Fetch Sent Interests

    func fetchSentInterests(userId: String, limit: Int = 20, reset: Bool = true) async throws {
        isLoading = true
        defer { isLoading = false }

        if reset {
            lastSentDocument = nil
            sentInterests = []
        }

        var query = db.collection("interests")
            .whereField("fromUserId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)

        if let lastDoc = lastSentDocument {
            query = query.start(afterDocument: lastDoc)
        }

        let snapshot = try await query.getDocuments()
        lastSentDocument = snapshot.documents.last

        let newInterests = snapshot.documents.compactMap { try? $0.data(as: Interest.self) }
        sentInterests.append(contentsOf: newInterests)
    }
    
    // MARK: - Listen to Interests

    func listenToReceivedInterests(userId: String) {
        // LIFECYCLE: Store userId for reconnection
        currentUserId = userId

        listener?.remove()

        listener = db.collection("interests")
            .whereField("toUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    Logger.shared.error("Error listening to interests", category: .matching, error: error)
                    Task { @MainActor in
                        self.error = error
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    self.receivedInterests = documents.compactMap { try? $0.data(as: Interest.self) }
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    // MARK: - Accept/Reject
    
    func acceptInterest(interestId: String, fromUserId: String, toUserId: String) async throws {
        try await db.collection("interests").document(interestId).updateData([
            "status": "accepted",
            "acceptedAt": FieldValue.serverTimestamp()
        ])

        // Check if match already exists to avoid duplicates
        let matchExists = try? await MatchService.shared.hasMatched(user1Id: fromUserId, user2Id: toUserId)
        if matchExists != true {
            await MatchService.shared.createMatch(user1Id: fromUserId, user2Id: toUserId)
        }

        Logger.shared.info("Interest accepted", category: .matching)
    }

    func rejectInterest(interestId: String) async throws {
        try await db.collection("interests").document(interestId).updateData([
            "status": "rejected",
            "rejectedAt": FieldValue.serverTimestamp()
        ])

        Logger.shared.info("Interest rejected", category: .matching)
    }
    
    // MARK: - Check if Liked
    
    func hasLiked(fromUserId: String, toUserId: String) async -> Bool {
        do {
            let interest = try await fetchInterest(fromUserId: fromUserId, toUserId: toUserId)
            return interest != nil
        } catch {
            Logger.shared.error("Error checking if liked", category: .matching, error: error)
            return false
        }
    }
    
    // MARK: - Delete Interest
    
    func deleteInterest(interestId: String) async throws {
        try await db.collection("interests").document(interestId).delete()
    }
    
    // MARK: - Get Interest Count
    
    func getReceivedInterestCount(userId: String) async -> Int {
        do {
            let snapshot = try await db.collection("interests")
                .whereField("toUserId", isEqualTo: userId)
                .whereField("status", isEqualTo: "pending")
                .getDocuments()
            return snapshot.documents.count
        } catch {
            Logger.shared.error("Error getting interest count", category: .matching, error: error)
            return 0
        }
    }
    
    deinit {
        listener?.remove()
        // LIFECYCLE: Unregister from lifecycle manager
        Task { @MainActor in
            ListenerLifecycleManager.shared.unregister(id: "InterestService")
        }
    }
}
