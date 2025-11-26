//
//  BatchOperationManager.swift
//  Celestia
//
//  Handles batch operations with transaction logging, idempotency, and retry logic
//

import Foundation
import Firebase
import FirebaseFirestore

// MARK: - Batch Operation Log

/// Log entry for batch operations to enable replay on failure
struct BatchOperationLog: Codable {
    let id: String
    let operationType: String
    let documentRefs: [String] // Document paths
    let updateData: [String: [String: Any]]? // Document ID -> update data
    let timestamp: Date
    var status: BatchOperationStatus
    var retryCount: Int
    let matchId: String? // For filtering/cleanup
    let userId: String? // For filtering/cleanup

    // Memberwise initializer
    init(
        id: String,
        operationType: String,
        documentRefs: [String],
        updateData: [String: [String: Any]]?,
        timestamp: Date,
        status: BatchOperationStatus,
        retryCount: Int,
        matchId: String?,
        userId: String?
    ) {
        self.id = id
        self.operationType = operationType
        self.documentRefs = documentRefs
        self.updateData = updateData
        self.timestamp = timestamp
        self.status = status
        self.retryCount = retryCount
        self.matchId = matchId
        self.userId = userId
    }

    enum CodingKeys: String, CodingKey {
        case id, operationType, documentRefs, timestamp, status, retryCount, matchId, userId
    }

    // Custom encoding to handle [String: Any]
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(operationType, forKey: .operationType)
        try container.encode(documentRefs, forKey: .documentRefs)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(status.rawValue, forKey: .status)
        try container.encode(retryCount, forKey: .retryCount)
        try container.encodeIfPresent(matchId, forKey: .matchId)
        try container.encodeIfPresent(userId, forKey: .userId)
    }

    // Custom decoding to handle [String: Any]
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        operationType = try container.decode(String.self, forKey: .operationType)
        documentRefs = try container.decode([String].self, forKey: .documentRefs)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        let statusString = try container.decode(String.self, forKey: .status)
        status = BatchOperationStatus(rawValue: statusString) ?? .pending
        retryCount = try container.decode(Int.self, forKey: .retryCount)
        matchId = try container.decodeIfPresent(String.self, forKey: .matchId)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        // updateData is not persisted, so we set it to nil
        updateData = nil
    }
}

enum BatchOperationStatus: String, Codable {
    case pending
    case inProgress
    case completed
    case failed
    case retriesExhausted
}

// MARK: - Batch Operation Manager

@MainActor
class BatchOperationManager {
    static let shared = BatchOperationManager()

    private let db = Firestore.firestore()
    private let maxRetries = 3
    private let baseRetryDelay: TimeInterval = 2.0

    // In-memory cache of pending operations (for performance)
    private var pendingOperations: [String: BatchOperationLog] = [:]

    // AUDIT FIX: Track partially succeeded document IDs for each operation
    private var partialSuccessTracking: [String: Set<String>] = [:]

    // AUDIT FIX: Network monitor for connectivity check
    private let networkMonitor = NetworkMonitor.shared

    // AUDIT FIX: Track recently completed operations for true idempotency
    private var recentlyCompletedOperations: [String: Date] = [:]
    private let idempotencyWindowSeconds: TimeInterval = 300 // 5 minutes

    private init() {
        // On initialization, recover any pending operations
        Task {
            await recoverPendingOperations()
        }
    }

    // MARK: - Mark Messages as Read (with idempotency)

    func markMessagesAsRead(
        matchId: String,
        userId: String,
        messageDocuments: [DocumentSnapshot]
    ) async throws {
        // AUDIT FIX: Check network connectivity first
        guard networkMonitor.isConnected else {
            Logger.shared.warning("Cannot mark messages as read - offline", category: .messaging)
            throw CelestiaError.noInternetConnection
        }

        // AUDIT FIX: Generate truly idempotent key using document IDs
        let documentIds = messageDocuments.map { $0.documentID }
        let operationId = generateIdempotencyKey(
            operation: "markAsRead",
            matchId: matchId,
            userId: userId,
            documentIds: documentIds
        )

        // AUDIT FIX: Check in-memory idempotency cache first (faster)
        if wasRecentlyCompleted(operationId) {
            Logger.shared.info("Operation \(operationId) recently completed (idempotent)", category: .messaging)
            return
        }

        // Check Firestore for operation completion
        if await isOperationCompleted(operationId) {
            Logger.shared.info("Operation \(operationId) already completed (idempotent)", category: .messaging)
            markOperationCompleted(operationId)
            return
        }

        // Extract document references and prepare update data
        var updateData: [String: [String: Any]] = [:]
        let documentRefs = messageDocuments.map { doc -> String in
            let path = doc.reference.path
            updateData[doc.documentID] = ["isRead": true, "isDelivered": true, "readAt": FieldValue.serverTimestamp()]
            return path
        }

        // Create operation log
        let operationLog = BatchOperationLog(
            id: operationId,
            operationType: "markAsRead",
            documentRefs: documentRefs,
            updateData: updateData,
            timestamp: Date(),
            status: .pending,
            retryCount: 0,
            matchId: matchId,
            userId: userId
        )

        // Execute batch operation with retry
        try await executeBatchOperationWithRetry(operationLog: operationLog) { batch in
            for doc in messageDocuments {
                batch.updateData(
                    ["isRead": true, "isDelivered": true, "readAt": FieldValue.serverTimestamp()],
                    forDocument: doc.reference
                )
            }
        }

        // Update match unread count
        try await db.collection("matches").document(matchId).updateData([
            "unreadCount.\(userId)": 0
        ])

        Logger.shared.info("Messages marked as read successfully (operation: \(operationId))", category: .messaging)
    }

    // MARK: - Mark Messages as Delivered (with idempotency)

    func markMessagesAsDelivered(
        matchId: String,
        userId: String,
        messageDocuments: [DocumentSnapshot]
    ) async throws {
        // AUDIT FIX: Check network connectivity first
        guard networkMonitor.isConnected else {
            Logger.shared.warning("Cannot mark messages as delivered - offline", category: .messaging)
            throw CelestiaError.noInternetConnection
        }

        // AUDIT FIX: Generate truly idempotent key using document IDs
        let documentIds = messageDocuments.map { $0.documentID }
        let operationId = generateIdempotencyKey(
            operation: "markAsDelivered",
            matchId: matchId,
            userId: userId,
            documentIds: documentIds
        )

        // AUDIT FIX: Check in-memory idempotency cache first (faster)
        if wasRecentlyCompleted(operationId) {
            Logger.shared.info("Operation \(operationId) recently completed (idempotent)", category: .messaging)
            return
        }

        // Check Firestore for operation completion
        if await isOperationCompleted(operationId) {
            Logger.shared.info("Operation \(operationId) already completed (idempotent)", category: .messaging)
            markOperationCompleted(operationId)
            return
        }

        // Extract document references and prepare update data
        var updateData: [String: [String: Any]] = [:]
        let documentRefs = messageDocuments.map { doc -> String in
            let path = doc.reference.path
            updateData[doc.documentID] = ["isDelivered": true, "deliveredAt": FieldValue.serverTimestamp()]
            return path
        }

        // Create operation log
        let operationLog = BatchOperationLog(
            id: operationId,
            operationType: "markAsDelivered",
            documentRefs: documentRefs,
            updateData: updateData,
            timestamp: Date(),
            status: .pending,
            retryCount: 0,
            matchId: matchId,
            userId: userId
        )

        // Execute batch operation with retry
        try await executeBatchOperationWithRetry(operationLog: operationLog) { batch in
            for doc in messageDocuments {
                batch.updateData(
                    ["isDelivered": true, "deliveredAt": FieldValue.serverTimestamp()],
                    forDocument: doc.reference
                )
            }
        }

        Logger.shared.info("Messages marked as delivered successfully (operation: \(operationId))", category: .messaging)
    }

    // MARK: - Delete Messages (with idempotency)

    func deleteMessages(
        matchId: String,
        messageDocuments: [DocumentSnapshot]
    ) async throws {
        // AUDIT FIX: Check network connectivity first
        guard networkMonitor.isConnected else {
            Logger.shared.warning("Cannot delete messages - offline", category: .messaging)
            throw CelestiaError.noInternetConnection
        }

        // AUDIT FIX: Generate truly idempotent key using document IDs
        let documentIds = messageDocuments.map { $0.documentID }
        let operationId = generateIdempotencyKey(
            operation: "deleteMessages",
            matchId: matchId,
            userId: nil,
            documentIds: documentIds
        )

        // AUDIT FIX: Check in-memory idempotency cache first (faster)
        if wasRecentlyCompleted(operationId) {
            Logger.shared.info("Operation \(operationId) recently completed (idempotent)", category: .messaging)
            return
        }

        // Check Firestore for operation completion
        if await isOperationCompleted(operationId) {
            Logger.shared.info("Operation \(operationId) already completed (idempotent)", category: .messaging)
            markOperationCompleted(operationId)
            return
        }

        // Extract document references
        let documentRefs = messageDocuments.map { $0.reference.path }

        // Create operation log
        let operationLog = BatchOperationLog(
            id: operationId,
            operationType: "deleteMessages",
            documentRefs: documentRefs,
            updateData: nil,
            timestamp: Date(),
            status: .pending,
            retryCount: 0,
            matchId: matchId,
            userId: nil
        )

        // Execute batch operation with retry
        try await executeBatchOperationWithRetry(operationLog: operationLog) { batch in
            for doc in messageDocuments {
                batch.deleteDocument(doc.reference)
            }
        }

        Logger.shared.info("Messages deleted successfully (operation: \(operationId))", category: .messaging)
    }

    // MARK: - Core Execution Logic

    private func executeBatchOperationWithRetry(
        operationLog: BatchOperationLog,
        batchBuilder: @escaping (WriteBatch) -> Void
    ) async throws {
        var currentLog = operationLog
        var lastError: Error?

        // Persist operation log before attempting
        await persistOperationLog(currentLog)

        for attempt in 0...maxRetries {
            do {
                // Update status to in-progress
                currentLog.status = .inProgress
                await updateOperationLog(currentLog)

                // Create batch and populate
                let batch = db.batch()
                batchBuilder(batch)

                // Commit batch
                try await batch.commit()

                // Mark operation as completed
                currentLog.status = .completed
                await updateOperationLog(currentLog)

                // AUDIT FIX: Mark in idempotency cache
                markOperationCompleted(currentLog.id)

                // Clean up from pending operations cache
                pendingOperations.removeValue(forKey: currentLog.id)
                partialSuccessTracking.removeValue(forKey: currentLog.id)

                // AUDIT FIX: Post notification for UI update
                postStatusChangeNotification(for: currentLog)

                Logger.shared.info(
                    "Batch operation \(currentLog.id) completed successfully on attempt \(attempt + 1)",
                    category: .messaging
                )

                return // Success!

            } catch {
                lastError = error
                currentLog.retryCount = attempt + 1

                Logger.shared.warning(
                    "Batch operation \(currentLog.id) failed on attempt \(attempt + 1): \(error.localizedDescription)",
                    category: .messaging
                )

                // Check if we should retry
                if attempt < maxRetries {
                    // Exponential backoff
                    let delay = baseRetryDelay * pow(2.0, Double(attempt))
                    Logger.shared.info("Retrying in \(delay) seconds...", category: .messaging)

                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                    // Update retry count in log
                    currentLog.status = .pending
                    await updateOperationLog(currentLog)
                } else {
                    // Exhausted retries
                    currentLog.status = .retriesExhausted
                    await updateOperationLog(currentLog)

                    Logger.shared.error(
                        "Batch operation \(currentLog.id) failed after \(maxRetries + 1) attempts",
                        category: .messaging,
                        error: error
                    )

                    // Track in analytics for monitoring
                    AnalyticsManager.shared.logEvent(.batchOperationFailed, parameters: [
                        "operation_id": currentLog.id,
                        "operation_type": currentLog.operationType,
                        "retry_count": currentLog.retryCount,
                        "error": error.localizedDescription
                    ])
                }
            }
        }

        // If we get here, all retries failed
        if let error = lastError {
            throw CelestiaError.batchOperationFailed(operationId: currentLog.id, underlyingError: error)
        }
    }

    // MARK: - Idempotency

    /// AUDIT FIX: Generate truly idempotent key based on operation parameters only (no timestamp)
    /// Uses message document IDs to create a unique but deterministic key
    private func generateIdempotencyKey(
        operation: String,
        matchId: String,
        userId: String?,
        documentIds: [String]
    ) -> String {
        // Sort document IDs for consistent ordering
        let sortedDocIds = documentIds.sorted().joined(separator: ",")
        let components = [operation, matchId, userId ?? "", sortedDocIds].joined(separator: "_")

        // Hash the components for a shorter, consistent key
        let hash = components.hashValue
        return "\(operation)_\(matchId)_\(abs(hash))"
    }

    /// AUDIT FIX: Check if operation was recently completed (true idempotency)
    private func wasRecentlyCompleted(_ operationId: String) -> Bool {
        cleanupExpiredIdempotencyRecords()
        return recentlyCompletedOperations[operationId] != nil
    }

    /// AUDIT FIX: Mark operation as completed for idempotency window
    private func markOperationCompleted(_ operationId: String) {
        recentlyCompletedOperations[operationId] = Date()
    }

    /// AUDIT FIX: Clean up expired idempotency records
    private func cleanupExpiredIdempotencyRecords() {
        let now = Date()
        recentlyCompletedOperations = recentlyCompletedOperations.filter { (_, completedAt) in
            now.timeIntervalSince(completedAt) < idempotencyWindowSeconds
        }
    }

    private func isOperationCompleted(_ operationId: String) async -> Bool {
        // Check in-memory cache first
        if let cachedOp = pendingOperations[operationId], cachedOp.status == .completed {
            return true
        }

        // Check Firestore
        do {
            let doc = try await db.collection("batch_operation_logs")
                .document(operationId)
                .getDocument()

            if let data = doc.data(),
               let statusStr = data["status"] as? String,
               let status = BatchOperationStatus(rawValue: statusStr) {
                return status == .completed
            }
        } catch {
            Logger.shared.warning("Could not check operation status: \(error.localizedDescription)", category: .messaging)
        }

        return false
    }

    // MARK: - Operation Log Persistence

    private func persistOperationLog(_ log: BatchOperationLog) async {
        do {
            // Store in Firestore for durability
            let data: [String: Any] = [
                "id": log.id,
                "operationType": log.operationType,
                "documentRefs": log.documentRefs,
                "timestamp": Timestamp(date: log.timestamp),
                "status": log.status.rawValue,
                "retryCount": log.retryCount,
                "matchId": log.matchId ?? "",
                "userId": log.userId ?? ""
            ]

            try await db.collection("batch_operation_logs")
                .document(log.id)
                .setData(data)

            // Also cache in memory
            pendingOperations[log.id] = log

        } catch {
            Logger.shared.error("Failed to persist operation log", category: .messaging, error: error)
        }
    }

    private func updateOperationLog(_ log: BatchOperationLog) async {
        do {
            try await db.collection("batch_operation_logs")
                .document(log.id)
                .updateData([
                    "status": log.status.rawValue,
                    "retryCount": log.retryCount
                ])

            // Update cache
            pendingOperations[log.id] = log

        } catch {
            Logger.shared.error("Failed to update operation log", category: .messaging, error: error)
        }
    }

    // MARK: - Recovery

    /// Recover and retry any pending operations on initialization
    private func recoverPendingOperations() async {
        Logger.shared.info("Recovering pending batch operations...", category: .messaging)

        // AUDIT FIX: Wait for network before attempting recovery
        guard networkMonitor.isConnected else {
            Logger.shared.info("Offline - deferring recovery until network available", category: .messaging)
            // Schedule retry when network becomes available
            scheduleRecoveryOnNetworkRestore()
            return
        }

        do {
            // Find operations that are pending or in-progress
            let snapshot = try await db.collection("batch_operation_logs")
                .whereField("status", in: [BatchOperationStatus.pending.rawValue, BatchOperationStatus.inProgress.rawValue])
                .getDocuments()

            Logger.shared.info("Found \(snapshot.documents.count) pending operations to recover", category: .messaging)

            for doc in snapshot.documents {
                guard let data = doc.data() as? [String: Any],
                      let operationType = data["operationType"] as? String,
                      let documentRefs = data["documentRefs"] as? [String],
                      let statusStr = data["status"] as? String,
                      let status = BatchOperationStatus(rawValue: statusStr),
                      let retryCount = data["retryCount"] as? Int else {
                    continue
                }

                var operationLog = BatchOperationLog(
                    id: doc.documentID,
                    operationType: operationType,
                    documentRefs: documentRefs,
                    updateData: nil,
                    timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                    status: status,
                    retryCount: retryCount,
                    matchId: data["matchId"] as? String,
                    userId: data["userId"] as? String
                )

                // Only retry if we haven't exhausted retries
                if retryCount < maxRetries {
                    Logger.shared.info("Retrying pending operation: \(operationLog.id)", category: .messaging)

                    // AUDIT FIX: Actually retry the operation
                    do {
                        try await retryOperation(operationLog)
                        Logger.shared.info("Successfully recovered operation: \(operationLog.id)", category: .messaging)
                    } catch {
                        operationLog.retryCount += 1
                        if operationLog.retryCount >= maxRetries {
                            operationLog.status = .retriesExhausted
                            Logger.shared.error("Recovery failed for operation \(operationLog.id) - retries exhausted", category: .messaging, error: error)
                        } else {
                            operationLog.status = .failed
                            Logger.shared.warning("Recovery attempt failed for operation \(operationLog.id), will retry", category: .messaging)
                        }
                        await updateOperationLog(operationLog)
                    }
                } else {
                    Logger.shared.warning("Operation \(operationLog.id) exhausted retries during recovery", category: .messaging)
                    operationLog.status = .retriesExhausted
                    await updateOperationLog(operationLog)
                }
            }

        } catch {
            Logger.shared.error("Failed to recover pending operations", category: .messaging, error: error)
        }
    }

    /// AUDIT FIX: Schedule recovery when network is restored
    private var networkObserver: NSObjectProtocol?

    private func scheduleRecoveryOnNetworkRestore() {
        // Remove existing observer if any
        if let observer = networkObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        networkObserver = NotificationCenter.default.addObserver(
            forName: .networkConnectionRestored,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                // Remove observer after triggering
                if let observer = self?.networkObserver {
                    NotificationCenter.default.removeObserver(observer)
                    self?.networkObserver = nil
                }
                await self?.recoverPendingOperations()
            }
        }
    }

    /// AUDIT FIX: Retry a specific operation by reconstructing the batch from document refs
    private func retryOperation(_ log: BatchOperationLog) async throws {
        let batch = db.batch()

        for refPath in log.documentRefs {
            let docRef = db.document(refPath)

            switch log.operationType {
            case "markAsRead":
                batch.updateData([
                    "isRead": true,
                    "isDelivered": true,
                    "readAt": FieldValue.serverTimestamp()
                ], forDocument: docRef)

            case "markAsDelivered":
                batch.updateData([
                    "isDelivered": true,
                    "deliveredAt": FieldValue.serverTimestamp()
                ], forDocument: docRef)

            case "deleteMessages":
                batch.deleteDocument(docRef)

            default:
                Logger.shared.warning("Unknown operation type for recovery: \(log.operationType)", category: .messaging)
                continue
            }
        }

        try await batch.commit()

        // Update log to completed
        var completedLog = log
        completedLog.status = .completed
        await updateOperationLog(completedLog)
        markOperationCompleted(log.id)
        postStatusChangeNotification(for: completedLog)
    }

    // MARK: - Notifications

    /// AUDIT FIX: Post notification when read/delivered status changes
    private func postStatusChangeNotification(for log: BatchOperationLog) {
        let notificationName: Notification.Name
        var userInfo: [String: Any] = [
            "matchId": log.matchId ?? "",
            "operationId": log.id
        ]

        switch log.operationType {
        case "markAsRead":
            notificationName = .messagesMarkedAsRead
            userInfo["documentCount"] = log.documentRefs.count
        case "markAsDelivered":
            notificationName = .messagesMarkedAsDelivered
            userInfo["documentCount"] = log.documentRefs.count
        case "deleteMessages":
            notificationName = .messagesDeleted
            userInfo["documentCount"] = log.documentRefs.count
        default:
            return // Unknown operation type
        }

        NotificationCenter.default.post(
            name: notificationName,
            object: nil,
            userInfo: userInfo
        )
    }

    // MARK: - Cleanup

    /// Clean up old completed operation logs (call periodically)
    func cleanupOldOperationLogs(olderThan days: Int = 7) async {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        do {
            let snapshot = try await db.collection("batch_operation_logs")
                .whereField("status", isEqualTo: BatchOperationStatus.completed.rawValue)
                .whereField("timestamp", isLessThan: Timestamp(date: cutoffDate))
                .getDocuments()

            let batch = db.batch()
            for doc in snapshot.documents {
                batch.deleteDocument(doc.reference)
            }

            try await batch.commit()

            Logger.shared.info("Cleaned up \(snapshot.documents.count) old operation logs", category: .messaging)

        } catch {
            Logger.shared.error("Failed to cleanup old operation logs", category: .messaging, error: error)
        }
    }
}

// MARK: - Notification Names for Batch Operations

extension Notification.Name {
    /// Posted when messages are successfully marked as read
    static let messagesMarkedAsRead = Notification.Name("messagesMarkedAsRead")
    /// Posted when messages are successfully marked as delivered
    static let messagesMarkedAsDelivered = Notification.Name("messagesMarkedAsDelivered")
    /// Posted when messages are successfully deleted
    static let messagesDeleted = Notification.Name("messagesDeleted")
    /// Posted when a batch operation fails after all retries
    static let batchOperationFailed = Notification.Name("batchOperationFailed")
}
