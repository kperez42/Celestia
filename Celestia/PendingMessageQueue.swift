//
//  PendingMessageQueue.swift
//  Celestia
//
//  Queue service for messages awaiting server-side validation
//  Provides security by preventing client-side validation bypass
//

import Foundation
import FirebaseFirestore

@MainActor
class PendingMessageQueue: ObservableObject {
    static let shared = PendingMessageQueue()

    @Published private(set) var pendingMessages: [PendingMessage] = []
    @Published private(set) var queueSize: Int = 0
    // CONCURRENCY FIX: Prevent race condition between timer and manual processQueue calls
    @Published private(set) var isProcessing = false

    private let persistenceKey = "com.celestia.pendingMessageQueue"
    private var processingTimer: Timer?
    private let db = Firestore.firestore()

    private init() {
        loadQueue()
        startBackgroundProcessing()
    }

    // MARK: - Queue Management

    /// Add a message to the pending queue
    func enqueue(_ message: PendingMessage) {
        pendingMessages.append(message)
        queueSize = pendingMessages.count
        saveQueue()

        Logger.shared.info("Message queued for validation: \(message.id)", category: .messaging)

        // Track analytics
        AnalyticsManager.shared.logEvent(.queuedMessage, parameters: [
            "queue_size": queueSize,
            "message_id": message.id
        ])

        // Trigger immediate processing attempt
        Task {
            await processQueue()
        }
    }

    /// Remove a message from the queue
    private func dequeue(_ messageId: String) {
        pendingMessages.removeAll { $0.id == messageId }
        queueSize = pendingMessages.count
        saveQueue()

        Logger.shared.debug("Message removed from queue: \(messageId)", category: .messaging)
    }

    /// Update a message's status in the queue
    private func updateMessage(_ messageId: String, status: PendingMessageStatus, failureReason: String? = nil) {
        guard let index = pendingMessages.firstIndex(where: { $0.id == messageId }) else { return }

        pendingMessages[index].status = status
        pendingMessages[index].lastValidationAttempt = Date()
        pendingMessages[index].validationAttempts += 1

        if let reason = failureReason {
            pendingMessages[index].failureReason = reason
        }

        saveQueue()
    }

    /// Get pending message count
    func getPendingCount() -> Int {
        return pendingMessages.filter { $0.status == .pendingValidation }.count
    }

    /// Get all pending messages for a specific match
    func getPendingMessages(forMatch matchId: String) -> [PendingMessage] {
        return pendingMessages.filter { $0.matchId == matchId && $0.status == .pendingValidation }
    }

    /// Clear all messages (for testing or logout)
    func clearQueue() {
        pendingMessages.removeAll()
        queueSize = 0
        saveQueue()
        Logger.shared.info("Pending message queue cleared", category: .messaging)
    }

    // MARK: - Queue Processing

    /// Process the queue - validate and send pending messages
    func processQueue() async {
        // CONCURRENCY FIX: Prevent race condition between timer and manual calls
        guard !isProcessing else {
            Logger.shared.debug("Queue processing already in progress, skipping", category: .messaging)
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        Logger.shared.debug("Processing pending message queue (\(pendingMessages.count) messages)", category: .messaging)

        // Filter messages ready for processing
        let messagesToProcess = pendingMessages.filter { message in
            // Only process messages that are:
            // 1. Pending validation
            // 2. Ready for retry (timing)
            // 3. Not expired
            return message.status == .pendingValidation &&
                   message.isReadyForRetry &&
                   !message.isExpired
        }

        Logger.shared.info("Found \(messagesToProcess.count) messages ready for validation", category: .messaging)

        for message in messagesToProcess {
            await processMessage(message)
        }

        // Clean up expired or failed messages
        cleanupQueue()
    }

    /// Process a single message: validate and send
    private func processMessage(_ message: PendingMessage) async {
        Logger.shared.info("Attempting validation for message: \(message.id) (attempt \(message.validationAttempts + 1)/\(PendingMessage.maxValidationAttempts))", category: .messaging)

        // Step 1: Validate content with backend
        do {
            let validationResponse = try await BackendAPIService.shared.validateContent(
                message.sanitizedText,
                type: .message
            )

            if validationResponse.isAppropriate {
                // Message is appropriate - mark as validated and send
                Logger.shared.info("✅ Message validated successfully: \(message.id)", category: .messaging)
                updateMessage(message.id, status: .validated)

                // Step 2: Send to Firestore
                await sendValidatedMessage(message)

            } else {
                // Message contains inappropriate content
                let violations = validationResponse.violations.joined(separator: ", ")
                Logger.shared.warning("❌ Message rejected by validation: \(violations)", category: .moderation)

                updateMessage(
                    message.id,
                    status: .validationFailed,
                    failureReason: violations
                )

                // Notify user their message was rejected
                NotificationCenter.default.post(
                    name: .pendingMessageRejected,
                    object: nil,
                    userInfo: [
                        "messageId": message.id,
                        "violations": violations
                    ]
                )

                // Track analytics
                AnalyticsManager.shared.logEvent(.messageRejected, parameters: [
                    "message_id": message.id,
                    "violations": violations
                ])

                // Remove from queue after a delay (so user can see the error)
                Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    await MainActor.run {
                        self.dequeue(message.id)
                    }
                }
            }

        } catch let error as BackendAPIError {
            // Backend still unavailable - update retry counter
            Logger.shared.warning("Backend still unavailable for message: \(message.id)", category: .messaging)
            updateMessage(message.id, status: .pendingValidation, failureReason: "Backend unavailable")

            // Check if max attempts reached
            if message.validationAttempts + 1 >= PendingMessage.maxValidationAttempts {
                Logger.shared.error("Max validation attempts reached for message: \(message.id)", category: .messaging)
                updateMessage(message.id, status: .failed, failureReason: "Max retries exceeded")

                // Notify user
                NotificationCenter.default.post(
                    name: .pendingMessageFailed,
                    object: nil,
                    userInfo: [
                        "messageId": message.id,
                        "reason": "Service temporarily unavailable"
                    ]
                )

                // Remove from queue after delay
                Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    await MainActor.run {
                        self.dequeue(message.id)
                    }
                }
            }

        } catch {
            // Other error (network, etc.)
            Logger.shared.error("Validation error for message: \(message.id) - \(error.localizedDescription)", category: .messaging)
            updateMessage(message.id, status: .pendingValidation, failureReason: error.localizedDescription)
        }
    }

    /// Send a validated message to Firestore
    private func sendValidatedMessage(_ message: PendingMessage) async {
        do {
            let firestoreMessage = message.toMessage()

            // Add to Firestore
            _ = try db.collection("messages").addDocument(from: firestoreMessage)

            // Update match with last message
            try await db.collection("matches").document(message.matchId).updateData([
                "lastMessage": message.sanitizedText,
                "lastMessageTimestamp": FieldValue.serverTimestamp(),
                "unreadCount.\(message.receiverId)": FieldValue.increment(Int64(1))
            ])

            // Send notification
            let senderSnapshot = try? await db.collection("users").document(message.senderId).getDocument()
            if let senderName = senderSnapshot?.data()?["fullName"] as? String {
                await NotificationService.shared.sendMessageNotification(
                    message: firestoreMessage,
                    senderName: senderName,
                    matchId: message.matchId
                )
            }

            // Mark as sent and remove from queue
            updateMessage(message.id, status: .sent)
            Logger.shared.info("✅ Message sent successfully: \(message.id)", category: .messaging)

            // Notify UI that message was sent
            NotificationCenter.default.post(
                name: .pendingMessageSent,
                object: nil,
                userInfo: ["messageId": message.id]
            )

            // Remove from queue
            dequeue(message.id)

            // Track analytics
            AnalyticsManager.shared.logEvent(.messageSentFromQueue, parameters: [
                "message_id": message.id,
                "queue_time_seconds": Date().timeIntervalSince(message.createdAt)
            ])

        } catch {
            Logger.shared.error("Failed to send validated message: \(error.localizedDescription)", category: .messaging)
            updateMessage(message.id, status: .failed, failureReason: error.localizedDescription)
        }
    }

    /// Remove expired and permanently failed messages
    private func cleanupQueue() {
        let beforeCount = pendingMessages.count

        // Remove expired messages
        pendingMessages.removeAll { $0.isExpired }

        // Remove sent or permanently failed messages (after grace period)
        pendingMessages.removeAll { message in
            if message.status == .sent || message.status == .failed {
                // Keep for 5 seconds so UI can show status
                if let lastAttempt = message.lastValidationAttempt,
                   Date().timeIntervalSince(lastAttempt) > 5 {
                    return true
                }
            }
            return false
        }

        let afterCount = pendingMessages.count
        queueSize = afterCount

        if beforeCount != afterCount {
            Logger.shared.info("Queue cleanup: removed \(beforeCount - afterCount) messages", category: .messaging)
            saveQueue()
        }
    }

    // MARK: - Background Processing

    /// Start background timer to periodically process queue
    private func startBackgroundProcessing() {
        // Process every 30 seconds
        processingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.processQueue()
            }
        }

        Logger.shared.info("Background message queue processing started", category: .messaging)
    }

    /// Stop background processing (for cleanup)
    func stopBackgroundProcessing() {
        processingTimer?.invalidate()
        processingTimer = nil
        Logger.shared.info("Background message queue processing stopped", category: .messaging)
    }

    // MARK: - Persistence

    /// Save queue to disk
    private func saveQueue() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(pendingMessages)
            UserDefaults.standard.set(data, forKey: persistenceKey)
            Logger.shared.debug("Queue saved to disk (\(pendingMessages.count) messages)", category: .messaging)
        } catch {
            Logger.shared.error("Failed to save message queue", category: .messaging, error: error)
        }
    }

    /// Load queue from disk
    private func loadQueue() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else {
            Logger.shared.debug("No saved queue found", category: .messaging)
            return
        }

        do {
            let decoder = JSONDecoder()
            pendingMessages = try decoder.decode([PendingMessage].self, from: data)
            queueSize = pendingMessages.count
            Logger.shared.info("Queue loaded from disk (\(pendingMessages.count) messages)", category: .messaging)
        } catch {
            Logger.shared.error("Failed to load message queue", category: .messaging, error: error)
        }
    }

    deinit {
        // Swift 6 concurrency: Access main actor isolated properties in deinit
        MainActor.assumeIsolated {
            stopBackgroundProcessing()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let pendingMessageSent = Notification.Name("pendingMessageSent")
    static let pendingMessageRejected = Notification.Name("pendingMessageRejected")
    static let pendingMessageFailed = Notification.Name("pendingMessageFailed")
}
