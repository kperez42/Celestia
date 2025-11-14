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

    // Dependency injection: Services
    private let matchService: any MatchServiceProtocol
    private let messageService: any MessageServiceProtocol

    private var messagesListener: ListenerRegistration?
    private var loadTask: Task<Void, Never>?

    var currentUserId: String
    var otherUserId: String

    // Dependency injection initializer
    init(
        currentUserId: String = "",
        otherUserId: String = "",
        matchService: any MatchServiceProtocol = MatchService.shared,
        messageService: any MessageServiceProtocol = MessageService.shared
    ) {
        self.currentUserId = currentUserId
        self.otherUserId = otherUserId
        self.matchService = matchService
        self.messageService = messageService
    }
    
    func updateCurrentUserId(_ userId: String) {
        self.currentUserId = userId
    }
    
    func loadMatches(for userID: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Use MatchService instead of direct Firestore access
            try await matchService.fetchMatches(userId: userID)
            matches = matchService.matches
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
        messagesListener?.remove()
        
        await MainActor.run {
            messagesListener = firestore.collection("messages")
                .whereField("matchId", isEqualTo: matchID)
                .order(by: "timestamp", descending: false)
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        Logger.shared.error("Error loading messages", category: .messaging, error: error)
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    self.messages = documents.compactMap { doc -> Message? in
                        try? doc.data(as: Message.self)
                    }
                }
        }
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
    }

    deinit {
        loadTask?.cancel()
        messagesListener?.remove()
    }
}
