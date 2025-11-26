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

    /// Track message IDs that are being dequeued asynchronously (to prevent race conditions)
    private var pendingDequeuIds: Set<String> = []

    private let persistenceKey = "com.celestia.pendingMessageQueue"
    private var processingTimer: Timer?
    private let db = Firestore.firestore()

    // AUDIT FIX: Add network monitor for connectivity check
    private let networkMonitor = NetworkMonitor.shared

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

        // AUDIT FIX: Ensure background timer is running
        ensureTimerRunning()

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
        pendingDequeuIds.removeAll()
        queueSize = 0
        saveQueue()
        Logger.shared.info("Pending message queue cleared", category: .messaging)
    }

    // MARK: - User Actions (AUDIT FIX: Add user-facing methods)

    /// Allow user to retry a failed message
    func retryMessage(_ messageId: String) {
        guard let index = pendingMessages.firstIndex(where: { $0.id == messageId }) else {
            Logger.shared.warning("Cannot retry - message not found: \(messageId)", category: .messaging)
            return
        }

        // Reset status and attempt count for retry
        pendingMessages[index].status = .pendingValidation
        pendingMessages[index].validationAttempts = 0
        pendingMessages[index].failureReason = nil
        pendingMessages[index].lastValidationAttempt = nil

        // Remove from dequeue tracking if it was scheduled for removal
        pendingDequeuIds.remove(messageId)

        saveQueue()
        Logger.shared.info("Message marked for retry: \(messageId)", category: .messaging)

        // Provide haptic feedback
        HapticManager.shared.impact(.light)

        // Trigger immediate processing
        Task {
            await processQueue()
        }
    }

    /// Allow user to cancel/delete a pending message
    func cancelMessage(_ messageId: String) {
        // Remove from dequeue tracking
        pendingDequeuIds.remove(messageId)

        // Remove from queue
        let messageText = pendingMessages.first { $0.id == messageId }?.text
        pendingMessages.removeAll { $0.id == messageId }
        queueSize = pendingMessages.count
        saveQueue()

        Logger.shared.info("Message cancelled by user: \(messageId)", category: .messaging)

        // Provide haptic feedback
        HapticManager.shared.impact(.light)

        // Notify UI
        NotificationCenter.default.post(
            name: .pendingMessageCancelled,
            object: nil,
            userInfo: [
                "messageId": messageId,
                "messageText": messageText ?? ""
            ]
        )
    }

    /// Retry all failed messages
    func retryAllFailed() {
        var retriedCount = 0

        for i in 0..<pendingMessages.count {
            if pendingMessages[i].status == .failed || pendingMessages[i].status == .validationFailed {
                pendingMessages[i].status = .pendingValidation
                pendingMessages[i].validationAttempts = 0
                pendingMessages[i].failureReason = nil
                pendingMessages[i].lastValidationAttempt = nil
                pendingDequeuIds.remove(pendingMessages[i].id)
                retriedCount += 1
            }
        }

        if retriedCount > 0 {
            saveQueue()
            Logger.shared.info("Marked \(retriedCount) messages for retry", category: .messaging)
            HapticManager.shared.impact(.medium)

            Task {
                await processQueue()
            }
        }
    }

    /// Get count of messages that can be retried
    var retryableCount: Int {
        pendingMessages.filter { $0.status == .failed || $0.status == .validationFailed }.count
    }

    // MARK: - Queue Processing

    /// Process the queue - validate and send pending messages
    func processQueue() async {
        // CONCURRENCY FIX: Prevent race condition between timer and manual calls
        guard !isProcessing else {
            Logger.shared.debug("Queue processing already in progress, skipping", category: .messaging)
            return
        }

        // AUDIT FIX: Check network connectivity before processing
        guard networkMonitor.isConnected else {
            Logger.shared.debug("Offline - skipping pending message queue processing", category: .messaging)
            return
        }

        // AUDIT FIX: Skip if queue is empty (optimization)
        guard !pendingMessages.isEmpty else {
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
            // 4. Not already being dequeued (AUDIT FIX: prevent race condition)
            return message.status == .pendingValidation &&
                   message.isReadyForRetry &&
                   !message.isExpired &&
                   !pendingDequeuIds.contains(message.id)
        }

        Logger.shared.info("Found \(messagesToProcess.count) messages ready for validation", category: .messaging)

        for message in messagesToProcess {
            // AUDIT FIX: Check network is still connected before each message
            guard networkMonitor.isConnected else {
                Logger.shared.info("Lost connection during queue processing, pausing", category: .messaging)
                break
            }

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
                        "violations": violations,
                        "messageText": message.text  // AUDIT FIX: Include message text for UI display
                    ]
                )

                // AUDIT FIX: Add haptic feedback for validation failure
                HapticManager.shared.notification(.error)

                // Track analytics
                AnalyticsManager.shared.logEvent(.messageRejected, parameters: [
                    "message_id": message.id,
                    "violations": violations
                ])

                // AUDIT FIX: Mark for deferred removal to prevent race condition
                scheduleDequeue(message.id, delay: 5.0)
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
                        "reason": "Service temporarily unavailable",
                        "messageText": message.text  // AUDIT FIX: Include message text for UI display
                    ]
                )

                // AUDIT FIX: Add haptic feedback for failure
                HapticManager.shared.notification(.error)

                // AUDIT FIX: Mark for deferred removal to prevent race condition
                scheduleDequeue(message.id, delay: 5.0)
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

    /// AUDIT FIX: Schedule deferred removal to prevent race conditions
    private func scheduleDequeue(_ messageId: String, delay: TimeInterval) {
        // Track that this message is being dequeued
        pendingDequeuIds.insert(messageId)

        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await MainActor.run {
                self.pendingDequeuIds.remove(messageId)
                self.dequeue(messageId)
            }
        }
    }

    /// Remove expired and permanently failed messages
    private func cleanupQueue() {
        let beforeCount = pendingMessages.count

        // AUDIT FIX: Notify users about expired messages before removing them
        let expiredMessages = pendingMessages.filter { $0.isExpired && $0.status == .pendingValidation }
        for expiredMessage in expiredMessages {
            // Don't re-notify if already being dequeued
            guard !pendingDequeuIds.contains(expiredMessage.id) else { continue }

            NotificationCenter.default.post(
                name: .pendingMessageExpired,
                object: nil,
                userInfo: [
                    "messageId": expiredMessage.id,
                    "messageText": expiredMessage.text
                ]
            )
            Logger.shared.warning("Message expired and removed: \(expiredMessage.id)", category: .messaging)
        }

        // Remove expired messages
        pendingMessages.removeAll { $0.isExpired }

        // Remove sent or permanently failed messages (after grace period)
        // AUDIT FIX: Skip messages being dequeued asynchronously
        pendingMessages.removeAll { message in
            // Skip if being handled by scheduleDequeue
            guard !pendingDequeuIds.contains(message.id) else { return false }

            if message.status == .sent || message.status == .failed || message.status == .validationFailed {
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
        // AUDIT FIX: Only start timer if queue has messages
        guard !pendingMessages.isEmpty else {
            Logger.shared.debug("Queue empty - not starting background timer", category: .messaging)
            return
        }

        startTimerIfNeeded()
    }

    /// AUDIT FIX: Smart timer management - only run when there are messages
    private func startTimerIfNeeded() {
        guard processingTimer == nil else { return }

        // Process every 30 seconds
        processingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }

                // AUDIT FIX: Stop timer if queue is empty
                if self.pendingMessages.isEmpty {
                    self.stopBackgroundProcessing()
                    return
                }

                await self.processQueue()
            }
        }

        Logger.shared.info("Background message queue processing started", category: .messaging)
    }

    /// Ensure timer is running when messages are added
    private func ensureTimerRunning() {
        if !pendingMessages.isEmpty && processingTimer == nil {
            startTimerIfNeeded()
        }
    }

    /// Stop background processing (for cleanup)
    func stopBackgroundProcessing() {
        processingTimer?.invalidate()
        processingTimer = nil
        Logger.shared.debug("Background message queue processing stopped", category: .messaging)
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
    /// Posted when a pending message is successfully sent
    static let pendingMessageSent = Notification.Name("pendingMessageSent")

    /// Posted when a message is rejected by content validation
    /// userInfo: messageId, violations, messageText
    static let pendingMessageRejected = Notification.Name("pendingMessageRejected")

    /// Posted when a message fails to send after max retries
    /// userInfo: messageId, reason, messageText
    static let pendingMessageFailed = Notification.Name("pendingMessageFailed")

    /// AUDIT FIX: Posted when a message expires before being validated
    /// userInfo: messageId, messageText
    static let pendingMessageExpired = Notification.Name("pendingMessageExpired")

    /// AUDIT FIX: Posted when a user cancels a pending message
    /// userInfo: messageId, messageText
    static let pendingMessageCancelled = Notification.Name("pendingMessageCancelled")
}
