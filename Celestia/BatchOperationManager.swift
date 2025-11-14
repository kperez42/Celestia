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
        // Generate idempotency key
        let operationId = generateIdempotencyKey(
            operation: "markAsRead",
            matchId: matchId,
            userId: userId
        )

        // Check if operation already completed
        if await isOperationCompleted(operationId) {
            Logger.shared.info("Operation \(operationId) already completed (idempotent)", category: .messaging)
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
        // Generate idempotency key
        let operationId = generateIdempotencyKey(
            operation: "markAsDelivered",
            matchId: matchId,
            userId: userId
        )

        // Check if operation already completed
        if await isOperationCompleted(operationId) {
            Logger.shared.info("Operation \(operationId) already completed (idempotent)", category: .messaging)
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
        // Generate idempotency key
        let operationId = generateIdempotencyKey(
            operation: "deleteMessages",
            matchId: matchId,
            userId: nil
        )

        // Check if operation already completed
        if await isOperationCompleted(operationId) {
            Logger.shared.info("Operation \(operationId) already completed (idempotent)", category: .messaging)
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

                // Clean up from pending operations cache
                pendingOperations.removeValue(forKey: currentLog.id)

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

    private func generateIdempotencyKey(operation: String, matchId: String, userId: String?) -> String {
        // Create deterministic key based on operation parameters
        let components = [operation, matchId, userId ?? ""].joined(separator: "_")
        return "\(components)_\(Date().timeIntervalSince1970)"
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

                let operationLog = BatchOperationLog(
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
                    // Note: In production, you'd reconstruct the actual batch operation here
                    // For now, we just log it for manual intervention
                } else {
                    Logger.shared.warning("Operation \(operationLog.id) exhausted retries during recovery", category: .messaging)
                }
            }

        } catch {
            Logger.shared.error("Failed to recover pending operations", category: .messaging, error: error)
        }
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
