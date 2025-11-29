//
//  MessageQueueManager.swift
//  Celestia
//
//  Handles message queueing for offline support
//  Automatically sends messages when connection is restored
//

import Foundation
import FirebaseFirestore

@MainActor
class MessageQueueManager: ObservableObject {
    static let shared = MessageQueueManager()

    @Published var queuedMessages: [QueuedMessage] = []
    @Published var isSyncing = false
    @Published var failedMessageCount = 0

    private let queue = DispatchQueue(label: "com.celestia.messageQueue", qos: .userInitiated)
    private let persistenceKey = "queued_messages"
    private var syncTimer: Timer?

    // Dependencies
    private let messageService = MessageService.shared
    private let networkMonitor = NetworkMonitor.shared

    // MEMORY FIX: Store observer token for cleanup
    private var networkObserver: NSObjectProtocol?

    private init() {
        loadQueuedMessages()
        setupNetworkObserver()
        // PERFORMANCE: Only start timer if queue has items
        ensureTimerRunningIfNeeded()
    }

    // PERFORMANCE: Smart timer management - only run when queue has items
    private func ensureTimerRunningIfNeeded() {
        if !queuedMessages.isEmpty && syncTimer == nil {
            startSyncTimer()
        } else if queuedMessages.isEmpty && syncTimer != nil {
            stopSyncTimer()
        }
    }

    private func stopSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = nil
        Logger.shared.debug("MessageQueueManager: Timer stopped - queue empty", category: .messaging)
    }

    // MARK: - Public Methods

    /// Queues a message for sending
    func queueMessage(
        matchId: String,
        senderId: String,
        receiverId: String,
        text: String,
        imageURL: String? = nil
    ) {
        let queuedMessage = QueuedMessage(
            id: UUID().uuidString,
            matchId: matchId,
            senderId: senderId,
            receiverId: receiverId,
            text: text,
            imageURL: imageURL,
            timestamp: Date(),
            retryCount: 0,
            status: .pending
        )

        queuedMessages.append(queuedMessage)
        saveQueuedMessages()

        Logger.shared.info("Message queued - messageId: \(queuedMessage.id)", category: .messaging)

        // PERFORMANCE: Start timer now that we have items
        ensureTimerRunningIfNeeded()

        // Try to send immediately if online
        if networkMonitor.isConnected {
            Task {
                await processQueue()
            }
        }
    }

    /// Processes the message queue
    func processQueue() async {
        guard !isSyncing else {
            Logger.shared.info("Queue sync already in progress", category: .messaging)
            return
        }

        guard networkMonitor.isConnected else {
            Logger.shared.info("Offline - skipping queue processing", category: .messaging)
            return
        }

        guard !queuedMessages.isEmpty else {
            return
        }

        isSyncing = true
        Logger.shared.info("Processing message queue - count: \(queuedMessages.count)", category: .messaging)

        // Process messages in order
        for i in 0..<queuedMessages.count {
            guard i < queuedMessages.count else { break }

            var message = queuedMessages[i]

            // Skip failed messages (will retry later)
            if message.status == .failed && message.retryCount >= 3 {
                continue
            }

            // Update status to sending
            message.status = .sending
            queuedMessages[i] = message

            do {
                // Send the message
                if let imageURL = message.imageURL {
                    try await messageService.sendImageMessage(
                        matchId: message.matchId,
                        senderId: message.senderId,
                        receiverId: message.receiverId,
                        imageURL: imageURL,
                        caption: message.text.isEmpty ? nil : message.text
                    )
                } else {
                    try await messageService.sendMessage(
                        matchId: message.matchId,
                        senderId: message.senderId,
                        receiverId: message.receiverId,
                        text: message.text
                    )
                }

                // Remove from queue on success
                queuedMessages.remove(at: i)
                Logger.shared.info("Message sent from queue - messageId: \(message.id)", category: .messaging)

            } catch {
                // Handle failure
                message.status = .failed
                message.retryCount += 1
                message.lastError = error.localizedDescription
                queuedMessages[i] = message

                Logger.shared.error("Failed to send queued message - messageId: \(message.id), retryCount: \(message.retryCount)", category: .messaging, error: error)
            }
        }

        // Update failed count
        failedMessageCount = queuedMessages.filter { $0.status == .failed }.count

        // Save queue state
        saveQueuedMessages()

        // PERFORMANCE: Stop timer if queue is now empty
        ensureTimerRunningIfNeeded()

        isSyncing = false
        Logger.shared.info("Queue processing complete", category: .messaging)
    }

    /// Retries failed messages
    func retryFailedMessages() async {
        for i in 0..<queuedMessages.count {
            if queuedMessages[i].status == .failed {
                queuedMessages[i].status = .pending
                queuedMessages[i].retryCount = 0
            }
        }

        saveQueuedMessages()
        await processQueue()
    }

    /// Removes a message from the queue
    func removeMessage(id: String) {
        queuedMessages.removeAll { $0.id == id }
        saveQueuedMessages()
    }

    /// Clears all queued messages
    func clearQueue() {
        queuedMessages.removeAll()
        saveQueuedMessages()
        failedMessageCount = 0
        // PERFORMANCE: Stop timer since queue is now empty
        ensureTimerRunningIfNeeded()
    }

    // MARK: - Private Methods

    private func setupNetworkObserver() {
        // MEMORY FIX: Store observer token for proper cleanup
        // Process queue when connection is restored
        networkObserver = NotificationCenter.default.addObserver(
            forName: .networkConnectionRestored,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.processQueue()
            }
        }
    }

    private func startSyncTimer() {
        // Check queue every 30 seconds
        syncTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.processQueue()
            }
        }
    }

    private func saveQueuedMessages() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(queuedMessages)
            UserDefaults.standard.set(data, forKey: persistenceKey)
        } catch {
            Logger.shared.error("Failed to save queued messages", category: .messaging, error: error)
        }
    }

    private func loadQueuedMessages() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            queuedMessages = try decoder.decode([QueuedMessage].self, from: data)
            failedMessageCount = queuedMessages.filter { $0.status == .failed }.count

            Logger.shared.info("Loaded queued messages - count: \(queuedMessages.count)", category: .messaging)
        } catch {
            Logger.shared.error("Failed to load queued messages", category: .messaging, error: error)
        }
    }

    // MEMORY FIX: Clean up both timer and observer
    deinit {
        syncTimer?.invalidate()
        if let observer = networkObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - Models

struct QueuedMessage: Identifiable, Codable {
    let id: String
    let matchId: String
    let senderId: String
    let receiverId: String
    let text: String
    let imageURL: String?
    let timestamp: Date
    var retryCount: Int
    var status: MessageStatus
    var lastError: String?

    enum MessageStatus: String, Codable {
        case pending
        case sending
        case failed
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let networkConnectionRestored = Notification.Name("networkConnectionRestored")
    static let networkConnectionLost = Notification.Name("networkConnectionLost")
}
