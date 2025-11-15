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
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showErrorAlert = false

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
        matchService: (any MatchServiceProtocol)? = nil,
        messageService: (any MessageServiceProtocol)? = nil
    ) {
        self.currentUserId = currentUserId
        self.otherUserId = otherUserId
        self.matchService = matchService ?? MatchService.shared
        self.messageService = messageService ?? MessageService.shared
    }
    
    func updateCurrentUserId(_ userId: String) {
        self.currentUserId = userId
    }

    func loadMessages() {
        guard !currentUserId.isEmpty && !otherUserId.isEmpty else { return }

        // Cancel previous task if any
        loadTask?.cancel()

        // Find match between current user and other user
        loadTask = Task {
            guard !Task.isCancelled else { return }
            // UX FIX: Properly handle match fetch errors instead of silent failure
            do {
                // ARCHITECTURE FIX: Use injected matchService instead of .shared singleton
                let match = try await matchService.fetchMatch(user1Id: currentUserId, user2Id: otherUserId)
                guard let matchId = match.id else {
                    Logger.shared.error("Match found but has no ID", category: .messaging)
                    await showError("Unable to load chat. Please try again.")
                    return
                }
                guard !Task.isCancelled else { return }
                await loadMessages(for: matchId)
            } catch {
                Logger.shared.error("Failed to fetch match for chat", category: .messaging, error: error)
                await showError("Unable to load chat. Please check your connection.")
            }
        }
    }
    
    func loadMessages(for matchID: String) async {
        messagesListener?.remove()

        await MainActor.run {
            messagesListener = Firestore.firestore().collection("messages")
                .whereField("matchId", isEqualTo: matchID)
                .order(by: "timestamp", descending: false)
                .addSnapshotListener { [weak self] (snapshot: QuerySnapshot?, error: Error?) in
                    guard let self = self else { return }

                    if let error = error {
                        Logger.shared.error("Error loading messages", category: .messaging, error: error)
                        return
                    }

                    guard let documents = snapshot?.documents else { return }

                    // UX FIX: Properly handle message parsing errors instead of silent failure
                    var parsedMessages: [Message] = []
                    for doc in documents {
                        do {
                            let message = try doc.data(as: Message.self)
                            parsedMessages.append(message)
                        } catch {
                            Logger.shared.error("Failed to parse message \(doc.documentID)", category: .messaging, error: error)
                            // Continue processing other messages
                        }
                    }
                    self.messages = parsedMessages
                }
        }
    }
    
    func sendMessage(text: String) {
        guard !currentUserId.isEmpty && !otherUserId.isEmpty else { return }
        guard !text.isEmpty else { return }

        Task {
            do {
                // Find or create match
                // UX FIX: Properly handle match fetch errors instead of silent failure
                let match = try await matchService.fetchMatch(user1Id: currentUserId, user2Id: otherUserId)
                guard let matchId = match.id else {
                    Logger.shared.error("Match found but has no ID", category: .messaging)
                    await showError("Unable to send message. Please try again.")
                    return
                }

                // ARCHITECTURE FIX: Use injected messageService instead of .shared singleton
                try await messageService.sendMessage(
                    matchId: matchId,
                    senderId: currentUserId,
                    receiverId: otherUserId,
                    text: text
                )
            } catch {
                Logger.shared.error("Error sending message", category: .messaging, error: error)
                await showError("Failed to send message. Please check your connection.")
            }
        }
    }

    func markMessagesAsRead(matchID: String, currentUserID: String) async {
        // ARCHITECTURE FIX: Use injected messageService instead of .shared singleton
        await messageService.markMessagesAsRead(matchId: matchID, userId: currentUserID)
    }

    /// UX FIX: Show error message to user instead of failing silently
    private func showError(_ message: String) async {
        errorMessage = message
        showErrorAlert = true
        HapticManager.shared.notification(.error)
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
