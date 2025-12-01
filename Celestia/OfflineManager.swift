//
//  OfflineManager.swift
//  Celestia
//
//  Manages offline functionality and data synchronization
//  Handles caching, queue management, and sync when online
//

import Foundation
import SwiftUI
import Combine
import Network
import CryptoKit

// MARK: - Offline Manager Error

enum OfflineManagerError: LocalizedError {
    case invalidData(String)
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        }
    }
}

// MARK: - Offline Manager

@MainActor
class OfflineManager: ObservableObject {

    // MARK: - Singleton

    static let shared = OfflineManager()

    // MARK: - Published Properties

    @Published private(set) var isOnline = true
    @Published private(set) var isSyncing = false
    @Published private(set) var pendingOperations: [OfflineOperation] = []

    // MARK: - Properties

    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.celestia.network-monitor")
    private let syncQueue = DispatchQueue(label: "com.celestia.sync-queue")

    private var cancellables = Set<AnyCancellable>()
    private let cache = OfflineCache.shared
    private let syncEngine = SyncEngine.shared

    // MARK: - Initialization

    private init() {
        setupNetworkMonitoring()
        loadPendingOperations()
        Logger.shared.info("OfflineManager initialized", category: .general)
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOnline = self?.isOnline ?? true
                self?.isOnline = path.status == .satisfied

                if !wasOnline && (self?.isOnline ?? false) {
                    Logger.shared.info("Network connection restored", category: .networking)
                    self?.onNetworkRestored()
                } else if wasOnline && !(self?.isOnline ?? true) {
                    Logger.shared.warning("Network connection lost", category: .networking)
                    self?.onNetworkLost()
                }
            }
        }

        networkMonitor.start(queue: monitorQueue)
    }

    // MARK: - Public Methods

    /// Queue an operation for offline execution
    func queueOperation(_ operation: OfflineOperation) {
        pendingOperations.append(operation)
        savePendingOperations()

        Logger.shared.info("Queued offline operation: \(operation.type)", category: .general)

        if isOnline {
            syncPendingOperations()
        }
    }

    /// Force sync all pending operations
    func syncNow() async {
        guard isOnline else {
            Logger.shared.warning("Cannot sync: offline", category: .networking)
            return
        }

        await performSync()
    }

    /// Check if data is available offline
    func isDataAvailableOffline<T: Codable>(key: String, type: T.Type) -> Bool {
        return cache.hasData(forKey: key)
    }

    /// Get cached data
    func getCachedData<T: Codable>(key: String, type: T.Type) -> T? {
        return cache.getData(forKey: key, type: type)
    }

    /// Cache data for offline access
    func cacheData<T: Codable>(_ data: T, key: String, expiration: TimeInterval = 3600) {
        cache.setData(data, forKey: key, expiration: expiration)
        Logger.shared.debug("Cached data: \(key)", category: .general)
    }

    /// Clear all cached data
    func clearCache() {
        cache.clearAll()
        Logger.shared.info("Cleared offline cache", category: .general)
    }

    // MARK: - Network State Handlers

    private func onNetworkRestored() {
        Logger.shared.info("Initiating sync after network restore", category: .networking)
        CrashlyticsManager.shared.logEvent("network_restored")

        Task {
            await performSync()
        }
    }

    private func onNetworkLost() {
        Logger.shared.warning("Entered offline mode", category: .networking)
        CrashlyticsManager.shared.logEvent("network_lost")
    }

    // MARK: - Synchronization

    private func syncPendingOperations() {
        guard !isSyncing else { return }

        Task {
            await performSync()
        }
    }

    private func performSync() async {
        guard !pendingOperations.isEmpty else { return }

        isSyncing = true
        Logger.shared.info("Starting sync of \(pendingOperations.count) operations", category: .networking)

        let operations = pendingOperations
        var successfulOperations: [String] = []

        for operation in operations {
            do {
                try await syncEngine.execute(operation)
                successfulOperations.append(operation.id)
                Logger.shared.info("Synced operation: \(operation.type)", category: .networking)
            } catch {
                Logger.shared.error("Failed to sync operation: \(operation.type)", category: .networking, error: error)

                // Retry failed operations (up to max retries)
                if operation.retryCount < operation.maxRetries {
                    var updatedOp = operation
                    updatedOp.retryCount += 1
                    if let index = pendingOperations.firstIndex(where: { $0.id == operation.id }) {
                        pendingOperations[index] = updatedOp
                    }
                }
            }
        }

        // Remove successful operations
        pendingOperations.removeAll { successfulOperations.contains($0.id) }
        savePendingOperations()

        isSyncing = false
        Logger.shared.info("Sync completed. \(successfulOperations.count) successful, \(pendingOperations.count) remaining", category: .networking)

        CrashlyticsManager.shared.logEvent("sync_completed", parameters: [
            "successful": successfulOperations.count,
            "failed": pendingOperations.count
        ])
    }

    // MARK: - Persistence

    private func loadPendingOperations() {
        if let data = UserDefaults.standard.data(forKey: "PendingOperations"),
           let operations = try? JSONDecoder().decode([OfflineOperation].self, from: data) {
            pendingOperations = operations
            Logger.shared.info("Loaded \(operations.count) pending operations", category: .general)
        }
    }

    private func savePendingOperations() {
        if let data = try? JSONEncoder().encode(pendingOperations) {
            UserDefaults.standard.set(data, forKey: "PendingOperations")
        }
    }
}

// MARK: - Offline Operation

struct OfflineOperation: Codable, Identifiable {
    let id: String
    let type: OperationType
    let data: Data
    let timestamp: Date
    var retryCount: Int
    let maxRetries: Int

    enum OperationType: String, Codable {
        case sendMessage
        case updateProfile
        case swipeAction
        case uploadPhoto
        case deletePhoto
        case unmatch
        case reportUser
        case blockUser
    }

    init(type: OperationType, data: Data, maxRetries: Int = 3) {
        self.id = UUID().uuidString
        self.type = type
        self.data = data
        self.timestamp = Date()
        self.retryCount = 0
        self.maxRetries = maxRetries
    }
}

// MARK: - Offline Cache

class OfflineCache {

    // MARK: - Singleton

    static let shared = OfflineCache()

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    // MARK: - Initialization

    private init() {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        guard let baseURL = urls.first else {
            // Fallback to temporary directory if caches directory is unavailable
            cacheDirectory = fileManager.temporaryDirectory.appendingPathComponent("OfflineCache", isDirectory: true)
            createCacheDirectoryIfNeeded()
            return
        }
        cacheDirectory = baseURL.appendingPathComponent("OfflineCache", isDirectory: true)

        createCacheDirectoryIfNeeded()
    }

    // MARK: - Public Methods

    func setData<T: Codable>(_ data: T, forKey key: String, expiration: TimeInterval) {
        let cacheEntry = CacheEntry(
            data: data,
            expiration: Date().addingTimeInterval(expiration)
        )

        guard let encoded = try? JSONEncoder().encode(cacheEntry) else { return }

        let fileURL = cacheDirectory.appendingPathComponent(key.sha256())
        try? encoded.write(to: fileURL)
    }

    func getData<T: Codable>(forKey key: String, type: T.Type) -> T? {
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256())

        guard let data = try? Data(contentsOf: fileURL),
              let entry = try? JSONDecoder().decode(CacheEntry<T>.self, from: data) else {
            return nil
        }

        // Check if expired
        if entry.expiration < Date() {
            removeData(forKey: key)
            return nil
        }

        return entry.data
    }

    func hasData(forKey key: String) -> Bool {
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256())
        return fileManager.fileExists(atPath: fileURL.path)
    }

    func removeData(forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256())
        try? fileManager.removeItem(at: fileURL)
    }

    func clearAll() {
        try? fileManager.removeItem(at: cacheDirectory)
        createCacheDirectoryIfNeeded()
    }

    func getCacheSize() -> Int64 {
        guard let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        return contents.reduce(0) { size, url in
            let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return size + Int64(fileSize)
        }
    }

    // MARK: - Private Methods

    private func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Supporting Types

    struct CacheEntry<T: Codable>: Codable {
        let data: T
        let expiration: Date
    }
}

// MARK: - Sync Engine

class SyncEngine {

    // MARK: - Singleton

    static let shared = SyncEngine()

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    func execute(_ operation: OfflineOperation) async throws {
        Logger.shared.info("Executing operation: \(operation.type)", category: .networking)

        switch operation.type {
        case .sendMessage:
            try await executeSendMessage(operation)
        case .updateProfile:
            try await executeUpdateProfile(operation)
        case .swipeAction:
            try await executeSwipeAction(operation)
        case .uploadPhoto:
            try await executeUploadPhoto(operation)
        case .deletePhoto:
            try await executeDeletePhoto(operation)
        case .unmatch:
            try await executeUnmatch(operation)
        case .reportUser:
            try await executeReportUser(operation)
        case .blockUser:
            try await executeBlockUser(operation)
        }
    }

    // MARK: - Private Execute Methods

    private func executeSendMessage(_ operation: OfflineOperation) async throws {
        // Decode message data
        struct MessageData: Codable {
            let matchId: String
            let senderId: String
            let receiverId: String
            let text: String
        }

        let messageData = try JSONDecoder().decode(MessageData.self, from: operation.data)

        // Send message via MessageService
        Logger.shared.debug("Sending queued message to \(messageData.matchId)", category: .networking)

        try await MessageService.shared.sendMessage(
            matchId: messageData.matchId,
            senderId: messageData.senderId,
            receiverId: messageData.receiverId,
            text: messageData.text
        )

        Logger.shared.info("Successfully synced message", category: .messaging)
    }

    private func executeUpdateProfile(_ operation: OfflineOperation) async throws {
        Logger.shared.debug("Updating profile from queue", category: .networking)

        // Decode profile data
        let user = try JSONDecoder().decode(User.self, from: operation.data)

        // Update profile via AuthService
        try await AuthService.shared.updateUser(user)

        Logger.shared.info("Successfully synced profile update", category: .general)
    }

    private func executeSwipeAction(_ operation: OfflineOperation) async throws {
        Logger.shared.debug("Executing swipe action from queue", category: .networking)

        // Decode swipe data
        struct SwipeData: Codable {
            let fromUserId: String
            let toUserId: String
            let isLike: Bool
        }

        let swipeData = try JSONDecoder().decode(SwipeData.self, from: operation.data)

        // Execute swipe via SwipeService
        if swipeData.isLike {
            _ = try await SwipeService.shared.likeUser(
                fromUserId: swipeData.fromUserId,
                toUserId: swipeData.toUserId
            )
        } else {
            try await SwipeService.shared.passUser(
                fromUserId: swipeData.fromUserId,
                toUserId: swipeData.toUserId
            )
        }

        Logger.shared.info("Successfully synced swipe action", category: .matching)
    }

    private func executeUploadPhoto(_ operation: OfflineOperation) async throws {
        Logger.shared.debug("Uploading photo from queue", category: .networking)

        // Decode photo data
        struct PhotoData: Codable {
            let userId: String
            let imageData: Data
        }

        let photoData = try JSONDecoder().decode(PhotoData.self, from: operation.data)

        // Convert Data to UIImage
        guard let image = UIImage(data: photoData.imageData) else {
            throw OfflineManagerError.invalidData("Failed to convert data to image")
        }

        // Upload photo via ImageUploadService
        // uploadImage expects a directory path and will append its own UUID filename
        let imageURL = try await ImageUploadService.shared.uploadImage(
            image,
            path: "profile_photos/\(photoData.userId)"
        )

        Logger.shared.info("Successfully synced photo upload: \(imageURL)", category: .storage)
    }

    private func executeDeletePhoto(_ operation: OfflineOperation) async throws {
        Logger.shared.debug("Deleting photo from queue", category: .networking)

        // Decode photo deletion data
        struct PhotoDeletionData: Codable {
            let userId: String
            let photoURL: String
        }

        let deletionData = try JSONDecoder().decode(PhotoDeletionData.self, from: operation.data)

        // Delete photo via ImageUploadService
        try await ImageUploadService.shared.deleteImage(url: deletionData.photoURL)

        Logger.shared.info("Successfully synced photo deletion", category: .storage)
    }

    private func executeUnmatch(_ operation: OfflineOperation) async throws {
        Logger.shared.debug("Executing unmatch from queue", category: .networking)

        // Decode unmatch data
        struct UnmatchData: Codable {
            let matchId: String
            let userId: String
        }

        let unmatchData = try JSONDecoder().decode(UnmatchData.self, from: operation.data)

        // Execute unmatch via MatchService
        try await MatchService.shared.unmatch(
            matchId: unmatchData.matchId,
            userId: unmatchData.userId
        )

        Logger.shared.info("Successfully synced unmatch", category: .matching)
    }

    private func executeReportUser(_ operation: OfflineOperation) async throws {
        Logger.shared.debug("Executing report user from queue", category: .networking)

        // Decode report data
        struct ReportData: Codable {
            let reporterId: String
            let reportedUserId: String
            let reason: String
            let details: String
        }

        let reportData = try JSONDecoder().decode(ReportData.self, from: operation.data)

        // Convert string reason to enum
        guard let reportReason = ReportReason(rawValue: reportData.reason) else {
            throw OfflineManagerError.invalidData("Invalid report reason: \(reportData.reason)")
        }

        // Execute report via BlockReportService
        try await BlockReportService.shared.reportUser(
            userId: reportData.reportedUserId,
            currentUserId: reportData.reporterId,
            reason: reportReason,
            additionalDetails: reportData.details
        )

        Logger.shared.info("Successfully synced user report", category: .moderation)
    }

    private func executeBlockUser(_ operation: OfflineOperation) async throws {
        Logger.shared.debug("Executing block user from queue", category: .networking)

        // Decode block data
        struct BlockData: Codable {
            let blockerId: String
            let blockedUserId: String
        }

        let blockData = try JSONDecoder().decode(BlockData.self, from: operation.data)

        // Execute block via BlockReportService
        try await BlockReportService.shared.blockUser(
            userId: blockData.blockedUserId,
            currentUserId: blockData.blockerId
        )

        Logger.shared.info("Successfully synced user block", category: .moderation)
    }
}

// MARK: - SwiftUI Integration

struct SimpleOfflineStatusView: View {
    @ObservedObject private var offlineManager = OfflineManager.shared

    var body: some View {
        Group {
            if !offlineManager.isOnline {
                HStack {
                    Image(systemName: "wifi.slash")
                    Text("Offline")
                    if !offlineManager.pendingOperations.isEmpty {
                        Text("(\(offlineManager.pendingOperations.count) pending)")
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(20)
            } else if offlineManager.isSyncing {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.7)
                    Text("Syncing...")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(20)
            }
        }
    }
}
