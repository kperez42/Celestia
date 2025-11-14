//
//  OfflineOperationQueue.swift
//  Celestia
//
//  Queues operations for execution when network connection is restored
//  Provides offline support for critical app functions
//

import Foundation
import FirebaseFirestore

/// Represents an operation that can be queued when offline
struct PendingOperation: Codable, Identifiable {
    let id: UUID
    let type: OperationType
    let data: [String: String]
    let timestamp: Date
    var retryCount: Int
    
    enum OperationType: String, Codable {
        case sendMessage
        case likeUser
        case superLikeUser
        case updateProfile
        case uploadPhoto
        case deletePhoto
    }
    
    init(type: OperationType, data: [String: String]) {
        self.id = UUID()
        self.type = type
        self.data = data
        self.timestamp = Date()
        self.retryCount = 0
    }
}

/// Manages pending operations when offline
@MainActor
class OfflineOperationQueue: ObservableObject {
    static let shared = OfflineOperationQueue()
    
    @Published private(set) var pendingOperations: [PendingOperation] = []
    @Published private(set) var isProcessing: Bool = false
    
    private let maxRetries = 3
    private let storageKey = "pendingOperations"
    
    private init() {
        loadPendingOperations()
    }
    
    // MARK: - Queue Management
    
    /// Add an operation to the queue
    func enqueue(_ operation: PendingOperation) {
        pendingOperations.append(operation)
        savePendingOperations()
        
        Logger.shared.info("Queued \(operation.type.rawValue) operation (id: \(operation.id))", category: .offline)
        
        // Try to process immediately if online
        if NetworkMonitor.shared.isConnected {
            Task {
                await processPendingOperations()
            }
        }
    }
    
    /// Remove an operation from the queue
    private func dequeue(_ operationId: UUID) {
        pendingOperations.removeAll { $0.id == operationId }
        savePendingOperations()
    }
    
    /// Clear all pending operations
    func clearAll() {
        pendingOperations.removeAll()
        savePendingOperations()
        Logger.shared.info("Cleared all pending operations", category: .offline)
    }
    
    // MARK: - Processing
    
    /// Process all pending operations
    func processPendingOperations() async {
        guard !isProcessing else {
            Logger.shared.debug("Already processing operations", category: .offline)
            return
        }
        
        guard NetworkMonitor.shared.isConnected else {
            Logger.shared.debug("Network offline - deferring operation processing", category: .offline)
            return
        }
        
        guard !pendingOperations.isEmpty else { return }
        
        isProcessing = true
        Logger.shared.info("Processing \(pendingOperations.count) pending operations", category: .offline)
        
        // Process operations in order
        for operation in pendingOperations {
            do {
                try await processOperation(operation)
                dequeue(operation.id)
                Logger.shared.info("Successfully processed \(operation.type.rawValue) operation", category: .offline)
            } catch {
                Logger.shared.error("Failed to process \(operation.type.rawValue) operation", category: .offline, error: error)
                
                // Increment retry count
                if var mutableOp = pendingOperations.first(where: { $0.id == operation.id }) {
                    mutableOp.retryCount += 1
                    
                    // Remove if max retries exceeded
                    if mutableOp.retryCount >= maxRetries {
                        Logger.shared.warning("Max retries exceeded for operation \(operation.id), removing", category: .offline)
                        dequeue(operation.id)
                    } else {
                        // Update retry count
                        if let index = pendingOperations.firstIndex(where: { $0.id == operation.id }) {
                            pendingOperations[index] = mutableOp
                            savePendingOperations()
                        }
                    }
                }
            }
        }
        
        isProcessing = false
        
        if pendingOperations.isEmpty {
            Logger.shared.info("All pending operations processed successfully", category: .offline)
        }
    }
    
    private func processOperation(_ operation: PendingOperation) async throws {
        switch operation.type {
        case .sendMessage:
            try await processMessageOperation(operation)
        case .likeUser:
            try await processLikeOperation(operation)
        case .superLikeUser:
            try await processSuperLikeOperation(operation)
        case .updateProfile:
            try await processProfileUpdateOperation(operation)
        case .uploadPhoto:
            try await processPhotoUploadOperation(operation)
        case .deletePhoto:
            try await processPhotoDeleteOperation(operation)
        }
    }
    
    // MARK: - Operation Handlers
    
    private func processMessageOperation(_ operation: PendingOperation) async throws {
        guard let matchId = operation.data["matchId"],
              let senderId = operation.data["senderId"],
              let receiverId = operation.data["receiverId"],
              let text = operation.data["text"] else {
            throw NSError(domain: "OfflineQueue", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid message data"])
        }
        
        try await MessageService.shared.sendMessage(
            matchId: matchId,
            senderId: senderId,
            receiverId: receiverId,
            text: text
        )
    }
    
    private func processLikeOperation(_ operation: PendingOperation) async throws {
        guard let userId = operation.data["userId"],
              let likedUserId = operation.data["likedUserId"] else {
            throw NSError(domain: "OfflineQueue", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid like data"])
        }

        _ = try await SwipeService.shared.likeUser(fromUserId: userId, toUserId: likedUserId, isSuperLike: false)
    }

    private func processSuperLikeOperation(_ operation: PendingOperation) async throws {
        guard let userId = operation.data["userId"],
              let likedUserId = operation.data["likedUserId"] else {
            throw NSError(domain: "OfflineQueue", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid super like data"])
        }

        _ = try await SwipeService.shared.likeUser(fromUserId: userId, toUserId: likedUserId, isSuperLike: true)
    }
    
    private func processProfileUpdateOperation(_ operation: PendingOperation) async throws {
        // Implement profile update logic
        Logger.shared.debug("Processing profile update operation", category: .offline)
    }
    
    private func processPhotoUploadOperation(_ operation: PendingOperation) async throws {
        // Implement photo upload logic
        Logger.shared.debug("Processing photo upload operation", category: .offline)
    }
    
    private func processPhotoDeleteOperation(_ operation: PendingOperation) async throws {
        // Implement photo delete logic
        Logger.shared.debug("Processing photo delete operation", category: .offline)
    }
    
    // MARK: - Persistence
    
    private func savePendingOperations() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(pendingOperations)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            Logger.shared.error("Failed to save pending operations", category: .offline, error: error)
        }
    }
    
    private func loadPendingOperations() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        
        do {
            let decoder = JSONDecoder()
            pendingOperations = try decoder.decode([PendingOperation].self, from: data)
            Logger.shared.info("Loaded \(pendingOperations.count) pending operations", category: .offline)
        } catch {
            Logger.shared.error("Failed to load pending operations", category: .offline, error: error)
        }
    }
}
