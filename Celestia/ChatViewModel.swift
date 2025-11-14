//
//  ChatViewModel.swift
//  Celestia
//
//  Handles chat and messaging functionality
//

import Foundation
import FirebaseFirestore

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var matches: [Match] = []
    @Published var isLoading = false

    private let firestore = Firestore.firestore()
    private var messagesListener: ListenerRegistration?
    private var loadTask: Task<Void, Never>?

    // Use MessageService for optimized pagination
    private let messageService = MessageService.shared

    var currentUserId: String
    var otherUserId: String

    init(currentUserId: String = "", otherUserId: String = "") {
        self.currentUserId = currentUserId
        self.otherUserId = otherUserId
    }
    
    func updateCurrentUserId(_ userId: String) {
        self.currentUserId = userId
    }
    
    func loadMatches(for userID: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Use OR filter for optimized single query
            let snapshot = try await firestore.collection("matches")
                .whereFilter(Filter.orFilter([
                    Filter.whereField("user1Id", isEqualTo: userID),
                    Filter.whereField("user2Id", isEqualTo: userID)
                ]))
                .whereField("isActive", isEqualTo: true)
                .getDocuments()

            matches = snapshot.documents
                .compactMap { try? $0.data(as: Match.self) }
                .sorted { ($0.lastMessageTimestamp ?? $0.timestamp) > ($1.lastMessageTimestamp ?? $1.timestamp) }
        } catch {
            Logger.shared.error("Error loading matches", category: .messaging, error: error)
        }
    }
    
    func loadMessages() {
        guard !currentUserId.isEmpty && !otherUserId.isEmpty else { return }

        // Cancel previous task if any
        loadTask?.cancel()

        // Find match between current user and other user
        loadTask = Task {
            guard !Task.isCancelled else { return }
            if let match = try? await MatchService.shared.fetchMatch(user1Id: currentUserId, user2Id: otherUserId),
               let matchId = match.id {
                guard !Task.isCancelled else { return }
                await loadMessages(for: matchId)
            }
        }
    }
    
    func loadMessages(for matchID: String) async {
        // Clean up old listener
        messagesListener?.remove()
        messagesListener = nil

        // Use MessageService's optimized paginated loading
        // This prevents loading all messages at once and supports pagination
        messageService.listenToMessages(matchId: matchID)

        // NOTE: Messages are now accessed via MessageService.shared.messages
        // The ChatView should use MessageService directly for better performance
        Logger.shared.info("Using MessageService for optimized message loading", category: .messaging)
    }

    /// Load older messages (pagination support)
    func loadOlderMessages(for matchID: String) async {
        await messageService.loadOlderMessages(matchId: matchID)
    }
    
    func sendMessage(text: String) {
        guard !currentUserId.isEmpty && !otherUserId.isEmpty else { return }
        guard !text.isEmpty else { return }

        Task {
            do {
                // Find or create match
                if let match = try? await MatchService.shared.fetchMatch(user1Id: currentUserId, user2Id: otherUserId),
                   let matchId = match.id {

                    try await MessageService.shared.sendMessage(
                        matchId: matchId,
                        senderId: currentUserId,
                        receiverId: otherUserId,
                        text: text
                    )
                }
            } catch {
                Logger.shared.error("Error sending message", category: .messaging, error: error)
            }
        }
    }

    func markMessagesAsRead(matchID: String, currentUserID: String) async {
        await MessageService.shared.markMessagesAsRead(matchId: matchID, userId: currentUserID)
    }
    
    /// Cleanup method to cancel ongoing tasks and remove listeners
    func cleanup() {
        loadTask?.cancel()
        loadTask = nil
        messagesListener?.remove()
        messagesListener = nil
        messages = []
        // Clean up MessageService if needed
        messageService.stopListening()
    }

    deinit {
        loadTask?.cancel()
        messagesListener?.remove()
    }
}
