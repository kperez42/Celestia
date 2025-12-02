//
//  OfflineOperationQueue.swift
//  Celestia
//
//  Queues operations for execution when network connection is restored
//  Provides offline support for critical app functions
//

import Foundation
import FirebaseFirestore
import UIKit

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

    /// Queue a photo upload for when network is restored
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - userId: The user ID for the upload path
    ///   - imageType: The type of image (profile, gallery, chat)
    /// - Returns: True if successfully queued, false otherwise
    func queuePhotoUpload(_ image: UIImage, userId: String, imageType: ImageType) -> Bool {
        // Save image to temp file
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            Logger.shared.error("Failed to convert image to JPEG data", category: .offline)
            return false
        }

        let tempFileName = "\(UUID().uuidString).jpg"
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirectory.appendingPathComponent("offline_uploads", isDirectory: true)
            .appendingPathComponent(tempFileName)

        do {
            // Create directory if needed
            try FileManager.default.createDirectory(
                at: tempFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            // Write image data to temp file
            try imageData.write(to: tempFileURL)

            // Determine image type string
            let imageTypeString: String
            switch imageType {
            case .profile:
                imageTypeString = "profile"
            case .gallery:
                imageTypeString = "gallery"
            case .chat:
                imageTypeString = "chat"
            }

            // Create and queue operation
            let operation = PendingOperation(
                type: .uploadPhoto,
                data: [
                    "userId": userId,
                    "tempFilePath": tempFileURL.path,
                    "imageType": imageTypeString
                ]
            )

            enqueue(operation)
            Logger.shared.info("Queued photo upload for offline sync", category: .offline)
            return true

        } catch {
            Logger.shared.error("Failed to save image to temp file", category: .offline, error: error)
            return false
        }
    }

    /// Queue a photo deletion for when network is restored
    func queuePhotoDelete(photoURL: String) {
        let operation = PendingOperation(
            type: .deletePhoto,
            data: ["photoURL": photoURL]
        )
        enqueue(operation)
        Logger.shared.info("Queued photo deletion for offline sync", category: .offline)
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
        guard let userId = operation.data["userId"],
              let tempFilePath = operation.data["tempFilePath"],
              let imageTypeRaw = operation.data["imageType"] else {
            throw NSError(domain: "OfflineQueue", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid photo upload data"])
        }

        // Load image from temp file
        let fileURL = URL(fileURLWithPath: tempFilePath)
        guard FileManager.default.fileExists(atPath: tempFilePath),
              let imageData = try? Data(contentsOf: fileURL),
              let image = UIImage(data: imageData) else {
            // Clean up temp file if it exists but couldn't be loaded
            try? FileManager.default.removeItem(at: fileURL)
            throw NSError(domain: "OfflineQueue", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to load image from temp file"])
        }

        // Determine image type
        let imageType: ImageType
        switch imageTypeRaw {
        case "profile":
            imageType = .profile
        case "gallery":
            imageType = .gallery
        case "chat":
            imageType = .chat
        default:
            imageType = .gallery
        }

        // Upload using PhotoUploadService
        let uploadedURL = try await PhotoUploadService.shared.uploadPhoto(image, userId: userId, imageType: imageType)

        // Clean up temp file after successful upload
        try? FileManager.default.removeItem(at: fileURL)

        Logger.shared.info("Successfully uploaded queued photo: \(uploadedURL)", category: .offline)
    }

    private func processPhotoDeleteOperation(_ operation: PendingOperation) async throws {
        guard let photoURL = operation.data["photoURL"] else {
            throw NSError(domain: "OfflineQueue", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid photo delete data"])
        }

        // Delete using ImageUploadService
        try await ImageUploadService.shared.deleteImage(url: photoURL)

        Logger.shared.info("Successfully deleted queued photo: \(photoURL)", category: .offline)
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
