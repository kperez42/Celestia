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
class InterestService: ObservableObject {
    @Published var sentInterests: [Interest] = []
    @Published var receivedInterests: [Interest] = []
    @Published var isLoading = false
    @Published var error: Error?

    static let shared = InterestService()
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var lastReceivedDocument: DocumentSnapshot?
    private var lastSentDocument: DocumentSnapshot?

    // Dependency injection for better testability and reduced coupling
    private let matchCreator: MatchCreating

    private init(matchCreator: MatchCreating = MatchService.shared) {
        self.matchCreator = matchCreator
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

        // Check if interest already exists
        if let existingInterest = try? await fetchInterest(fromUserId: fromUserId, toUserId: toUserId) {
            print("Interest already sent to this user: \(existingInterest.id ?? "unknown")")
            return
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
        print("✅ Interest sent: \(docRef.documentID)")

        // Check for mutual match
        if let mutualInterest = try? await fetchInterest(fromUserId: toUserId, toUserId: fromUserId),
           mutualInterest.status == "pending" {
            // Both users liked each other - create match!
            await matchCreator.createMatch(user1Id: fromUserId, user2Id: toUserId)

            // Update both interests to accepted
            try await acceptInterest(interestId: docRef.documentID, fromUserId: fromUserId, toUserId: toUserId)
            if let mutualId = mutualInterest.id {
                try await acceptInterest(interestId: mutualId, fromUserId: toUserId, toUserId: fromUserId)
            }
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
        listener?.remove()
        
        listener = db.collection("interests")
            .whereField("toUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error listening to interests: \(error)")
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
        let matchExists = try? await matchCreator.hasMatched(user1Id: fromUserId, user2Id: toUserId)
        if matchExists != true {
            await matchCreator.createMatch(user1Id: fromUserId, user2Id: toUserId)
        }

        print("✅ Interest accepted")
    }
    
    func rejectInterest(interestId: String) async throws {
        try await db.collection("interests").document(interestId).updateData([
            "status": "rejected",
            "rejectedAt": FieldValue.serverTimestamp()
        ])

        print("✅ Interest rejected")
    }
    
    // MARK: - Check if Liked
    
    func hasLiked(fromUserId: String, toUserId: String) async -> Bool {
        do {
            let interest = try await fetchInterest(fromUserId: fromUserId, toUserId: toUserId)
            return interest != nil
        } catch {
            print("Error checking if liked: \(error)")
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
            print("Error getting interest count: \(error)")
            return 0
        }
    }
    
    deinit {
        listener?.remove()
    }
}
