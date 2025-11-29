//
//  ChatViewModel.swift
//  Celestia
//
//  Handles chat and messaging functionality
//

import Foundation
import FirebaseFirestore
import Combine
import UIKit

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showErrorAlert = false

    /// Track messages that are pending delivery (queued/sending)
    @Published var pendingMessageTexts: Set<String> = []

    /// Track messages that failed to send (can be retried)
    @Published var failedMessages: [(text: String, image: UIImage?, timestamp: Date)] = []

    /// Number of messages queued for offline delivery
    @Published var queuedMessageCount = 0

    /// Whether currently offline
    @Published var isOffline = false

    // Dependency injection: Services
    private let matchService: any MatchServiceProtocol
    private let messageService: any MessageServiceProtocol
    private let messageQueueManager = MessageQueueManager.shared
    private let networkMonitor = NetworkMonitor.shared

    private var messagesListener: ListenerRegistration?
    private var loadTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

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

        setupObservers()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Observe network status
        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.isOffline = !isConnected
                if isConnected {
                    // Trigger queue processing when connection restored
                    Task {
                        await self?.messageQueueManager.processQueue()
                    }
                }
            }
            .store(in: &cancellables)

        // Observe message queue count
        messageQueueManager.$queuedMessages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                self?.queuedMessageCount = messages.count
            }
            .store(in: &cancellables)

        // Observe message delivery status changes
        NotificationCenter.default.publisher(for: .messageDeliveryStatusChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleDeliveryStatusChange(notification)
            }
            .store(in: &cancellables)

        // Observe pending message queue updates
        NotificationCenter.default.publisher(for: .pendingMessageSent)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let messageId = notification.userInfo?["messageId"] as? String {
                    self?.pendingMessageTexts.remove(messageId)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .pendingMessageFailed)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let messageId = notification.userInfo?["messageId"] as? String,
                   let reason = notification.userInfo?["reason"] as? String {
                    self?.pendingMessageTexts.remove(messageId)
                    self?.errorMessage = "Message failed: \(reason)"
                    self?.showErrorAlert = true
                }
            }
            .store(in: &cancellables)
    }

    private func handleDeliveryStatusChange(_ notification: Notification) {
        guard let status = notification.userInfo?["status"] as? MessageDeliveryStatus,
              let messageText = notification.userInfo?["messageText"] as? String else {
            return
        }

        switch status {
        case .pending, .sending:
            pendingMessageTexts.insert(messageText)
        case .sent, .delivered:
            pendingMessageTexts.remove(messageText)
            // Remove from failed messages if it was there
            failedMessages.removeAll { $0.text == messageText }
        case .failed:
            pendingMessageTexts.remove(messageText)
            // Add to failed messages for retry UI
            if !failedMessages.contains(where: { $0.text == messageText }) {
                failedMessages.append((text: messageText, image: nil, timestamp: Date()))
            }
        case .failedPermanent:
            pendingMessageTexts.remove(messageText)
            let errorDesc = notification.userInfo?["error"] as? String ?? "Unknown error"
            errorMessage = "Message could not be sent: \(errorDesc)"
            showErrorAlert = true
            HapticManager.shared.notification(.error)
        }
    }
    
    func updateCurrentUserId(_ userId: String) {
        self.currentUserId = userId
    }

    func loadMessages() {
        guard !currentUserId.isEmpty && !otherUserId.isEmpty else { return }

        // Cancel previous task if any
        loadTask?.cancel()

        // PERFORMANCE: Use high priority for faster message loading
        loadTask = Task(priority: .userInitiated) {
            guard !Task.isCancelled else { return }
            // UX FIX: Properly handle match fetch errors instead of silent failure
            do {
                // ARCHITECTURE FIX: Use injected matchService instead of .shared singleton
                guard let match = try await matchService.fetchMatch(user1Id: currentUserId, user2Id: otherUserId) else {
                    Logger.shared.error("No match found", category: .messaging)
                    await showError("Unable to load chat. No match found.")
                    return
                }
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

        // Track as pending immediately for UI feedback
        pendingMessageTexts.insert(text)

        // PERFORMANCE: Use high priority for responsive message sending
        Task(priority: .userInitiated) {
            do {
                // Find or create match
                // UX FIX: Properly handle match fetch errors instead of silent failure
                guard let match = try await matchService.fetchMatch(user1Id: currentUserId, user2Id: otherUserId) else {
                    Logger.shared.error("No match found", category: .messaging)
                    pendingMessageTexts.remove(text)
                    await showError("Unable to send message. No match found.")
                    return
                }
                guard let matchId = match.id else {
                    Logger.shared.error("Match found but has no ID", category: .messaging)
                    pendingMessageTexts.remove(text)
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

                // Message sent successfully (or queued if offline)
                // Status tracking is handled by notification observers
                pendingMessageTexts.remove(text)

            } catch let error as CelestiaError {
                pendingMessageTexts.remove(text)
                Logger.shared.error("Error sending message", category: .messaging, error: error)

                // Provide specific error messages
                switch error {
                case .rateLimitExceeded, .rateLimitExceededWithTime:
                    await showError(error.errorDescription ?? "You're sending messages too quickly.")
                case .inappropriateContent, .inappropriateContentWithReasons:
                    await showError(error.errorDescription ?? "Message contains inappropriate content.")
                case .messageTooLong:
                    await showError("Message is too long. Please shorten it.")
                case .networkError, .noInternetConnection:
                    // Message will be queued automatically, show informative message
                    await showError("You're offline. Message will be sent when connection is restored.")
                default:
                    await showError("Failed to send message. Please try again.")
                }

            } catch {
                pendingMessageTexts.remove(text)
                Logger.shared.error("Error sending message", category: .messaging, error: error)

                // Check if it's a network error
                let celestiaError = CelestiaError.from(error)
                if case .networkError = celestiaError {
                    await showError("You're offline. Message will be sent when connection is restored.")
                } else if case .noInternetConnection = celestiaError {
                    await showError("No internet connection. Message will be sent when you're back online.")
                } else {
                    await showError("Failed to send message. Please check your connection.")
                }
            }
        }
    }

    /// Retry sending a failed message
    func retryFailedMessage(_ message: (text: String, image: UIImage?, timestamp: Date)) {
        // Remove from failed list
        failedMessages.removeAll { $0.text == message.text && $0.timestamp == message.timestamp }

        // Resend
        sendMessage(text: message.text)

        HapticManager.shared.impact(.light)
    }

    /// Clear all failed messages (user dismissed them)
    func clearFailedMessages() {
        failedMessages.removeAll()
    }

    /// Get the number of pending messages for this conversation
    var pendingCount: Int {
        pendingMessageTexts.count + failedMessages.count
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
        cancellables.removeAll()
        pendingMessageTexts.removeAll()
        failedMessages.removeAll()
    }

    deinit {
        loadTask?.cancel()
        messagesListener?.remove()
        cancellables.removeAll()
    }
}
