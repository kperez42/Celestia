//
//  TypingStatusService.swift
//  Celestia
//
//  Service for managing real-time typing indicators synced to Firestore
//

import Foundation
import FirebaseFirestore
import Combine

/// Represents the typing status of a user in a match
struct TypingStatus: Codable {
    var matchId: String
    var userId: String
    var isTyping: Bool
    var timestamp: Date

    init(matchId: String, userId: String, isTyping: Bool = false, timestamp: Date = Date()) {
        self.matchId = matchId
        self.userId = userId
        self.isTyping = isTyping
        self.timestamp = timestamp
    }
}

@MainActor
class TypingStatusService: ObservableObject {
    static let shared = TypingStatusService()

    /// Published typing status for the other user in current chat
    @Published var isOtherUserTyping = false
    @Published var typingUserName: String?

    private let db = Firestore.firestore()
    private var typingListener: ListenerRegistration?
    private var currentMatchId: String?
    private var currentUserId: String?
    private var otherUserId: String?

    // Debouncing for typing updates
    private var typingDebounceTimer: Timer?
    private var stopTypingTimer: Timer?
    private let typingDebounceInterval: TimeInterval = 0.5
    private let typingTimeoutInterval: TimeInterval = 5.0 // Auto-stop after 5 seconds of no typing

    // Track last typing state to avoid redundant updates
    private var lastTypingState = false

    private init() {}

    // MARK: - Public API

    /// Start listening to typing status for a specific match
    func startListening(matchId: String, currentUserId: String, otherUserId: String) {
        // Clean up any existing listener
        stopListening()

        self.currentMatchId = matchId
        self.currentUserId = currentUserId
        self.otherUserId = otherUserId

        Logger.shared.info("Starting typing status listener for match: \(matchId)", category: .messaging)

        // Listen to typing status document for the other user
        typingListener = db.collection("typingStatus")
            .whereField("matchId", isEqualTo: matchId)
            .whereField("userId", isEqualTo: otherUserId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    Logger.shared.error("Error listening to typing status", category: .messaging, error: error)
                    return
                }

                guard let documents = snapshot?.documents else {
                    Task { @MainActor in
                        self.isOtherUserTyping = false
                    }
                    return
                }

                Task { @MainActor in
                    if let doc = documents.first,
                       let status = try? doc.data(as: TypingStatus.self) {
                        // Check if typing status is recent (within 10 seconds)
                        let isRecent = Date().timeIntervalSince(status.timestamp) < 10
                        self.isOtherUserTyping = status.isTyping && isRecent

                        if self.isOtherUserTyping {
                            Logger.shared.debug("Other user is typing in match: \(matchId)", category: .messaging)
                        }
                    } else {
                        self.isOtherUserTyping = false
                    }
                }
            }
    }

    /// Stop listening to typing status
    func stopListening() {
        typingListener?.remove()
        typingListener = nil
        currentMatchId = nil
        otherUserId = nil
        isOtherUserTyping = false
        typingUserName = nil

        // Clear own typing status when leaving chat
        clearTypingStatus()
    }

    /// Update typing status (debounced to prevent spam)
    func setTyping(_ isTyping: Bool) {
        guard let matchId = currentMatchId,
              let userId = currentUserId else {
            return
        }

        // Cancel any pending stop typing timer
        stopTypingTimer?.invalidate()

        // If starting to type, set up auto-stop timer
        if isTyping {
            stopTypingTimer = Timer.scheduledTimer(withTimeInterval: typingTimeoutInterval, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.setTyping(false)
                }
            }
        }

        // Debounce typing updates to avoid excessive Firestore writes
        typingDebounceTimer?.invalidate()
        typingDebounceTimer = Timer.scheduledTimer(withTimeInterval: typingDebounceInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.updateTypingStatus(matchId: matchId, userId: userId, isTyping: isTyping)
            }
        }
    }

    /// Called when user sends a message - immediately clear typing status
    func messageSent() {
        stopTypingTimer?.invalidate()
        typingDebounceTimer?.invalidate()

        guard let matchId = currentMatchId,
              let userId = currentUserId else {
            return
        }

        Task {
            await updateTypingStatus(matchId: matchId, userId: userId, isTyping: false)
        }
    }

    // MARK: - Private Methods

    /// Update typing status in Firestore
    private func updateTypingStatus(matchId: String, userId: String, isTyping: Bool) async {
        // Skip redundant updates
        guard isTyping != lastTypingState else { return }
        lastTypingState = isTyping

        let status = TypingStatus(
            matchId: matchId,
            userId: userId,
            isTyping: isTyping,
            timestamp: Date()
        )

        let documentId = "\(matchId)_\(userId)"

        do {
            try db.collection("typingStatus").document(documentId).setData(from: status, merge: true)
            Logger.shared.debug("Updated typing status: \(isTyping) for match: \(matchId)", category: .messaging)
        } catch {
            Logger.shared.error("Failed to update typing status", category: .messaging, error: error)
        }
    }

    /// Clear typing status when leaving chat
    private func clearTypingStatus() {
        guard let matchId = currentMatchId,
              let userId = currentUserId else {
            return
        }

        let documentId = "\(matchId)_\(userId)"

        Task {
            do {
                try await db.collection("typingStatus").document(documentId).updateData([
                    "isTyping": false,
                    "timestamp": FieldValue.serverTimestamp()
                ])
            } catch {
                // Document might not exist, which is fine
                Logger.shared.debug("Could not clear typing status (document may not exist)", category: .messaging)
            }
        }
    }

    deinit {
        typingDebounceTimer?.invalidate()
        stopTypingTimer?.invalidate()
        typingListener?.remove()
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let typingStatusChanged = Notification.Name("typingStatusChanged")
}
