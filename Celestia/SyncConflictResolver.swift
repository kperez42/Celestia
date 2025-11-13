//
//  SyncConflictResolver.swift
//  Celestia
//
//  Handles synchronization conflicts when offline changes conflict with server state
//

import Foundation
import FirebaseFirestore

@MainActor
class SyncConflictResolver: ObservableObject {
    static let shared = SyncConflictResolver()

    @Published var conflicts: [SyncConflict] = []
    @Published var isResolving = false

    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Conflict Detection

    /// Detects conflicts between local and server data
    func detectConflicts<T: Codable & Identifiable>(
        local: T,
        server: T,
        lastSyncTimestamp: Date?
    ) -> SyncConflict? where T.ID == String {
        // If local was modified after last sync, and server was also modified, we have a conflict
        guard let lastSync = lastSyncTimestamp else {
            // No last sync timestamp - use server version
            return nil
        }

        // This is a simplified conflict detection
        // In production, you'd compare field-by-field timestamps
        let conflict = SyncConflict(
            id: UUID().uuidString,
            entityType: String(describing: T.self),
            entityId: local.id,
            localData: try? JSONEncoder().encode(local),
            serverData: try? JSONEncoder().encode(server),
            timestamp: Date(),
            status: .pending
        )

        return conflict
    }

    /// Adds a conflict to the resolution queue
    func addConflict(_ conflict: SyncConflict) {
        conflicts.append(conflict)
        Logger.shared.warning("Sync conflict detected - entityType: \(conflict.entityType), entityId: \(conflict.entityId)", category: .general)
    }

    // MARK: - Conflict Resolution Strategies

    /// Resolves conflicts using the specified strategy
    func resolveConflict(
        _ conflict: SyncConflict,
        strategy: ResolutionStrategy
    ) async throws {
        isResolving = true
        defer { isResolving = false }

        switch strategy {
        case .useLocal:
            try await applyLocalVersion(conflict)

        case .useServer:
            try await applyServerVersion(conflict)

        case .merge:
            try await mergeVersions(conflict)

        case .manual:
            // User will manually resolve
            break
        }

        // Mark conflict as resolved
        if let index = conflicts.firstIndex(where: { $0.id == conflict.id }) {
            conflicts[index].status = .resolved
            conflicts[index].resolvedAt = Date()
            conflicts[index].resolutionStrategy = strategy
        }

        Logger.shared.info("Conflict resolved - strategy: \(strategy)", category: .general)
    }

    /// Resolves all conflicts using auto-resolution rules
    func resolveAllConflicts() async {
        for conflict in conflicts where conflict.status == .pending {
            let strategy = determineAutoResolutionStrategy(conflict)

            do {
                try await resolveConflict(conflict, strategy: strategy)
            } catch {
                Logger.shared.error("Auto-resolution failed", category: .general, error: error)
            }
        }
    }

    // MARK: - Resolution Implementations

    private func applyLocalVersion(_ conflict: SyncConflict) async throws {
        guard let localData = conflict.localData else {
            throw SyncError.invalidData
        }

        // Apply local version to server
        switch conflict.entityType {
        case "Message":
            try await applyLocalMessage(entityId: conflict.entityId, data: localData)

        case "User":
            try await applyLocalUser(entityId: conflict.entityId, data: localData)

        case "Match":
            try await applyLocalMatch(entityId: conflict.entityId, data: localData)

        default:
            Logger.shared.warning("Unknown entity type for conflict resolution", category: .general)
        }
    }

    private func applyServerVersion(_ conflict: SyncConflict) async throws {
        guard let serverData = conflict.serverData else {
            throw SyncError.invalidData
        }

        // Server version is already applied, just need to update local cache
        switch conflict.entityType {
        case "Message":
            try updateLocalMessage(entityId: conflict.entityId, data: serverData)

        case "User":
            try updateLocalUser(entityId: conflict.entityId, data: serverData)

        case "Match":
            try updateLocalMatch(entityId: conflict.entityId, data: serverData)

        default:
            Logger.shared.warning("Unknown entity type for conflict resolution", category: .general)
        }
    }

    private func mergeVersions(_ conflict: SyncConflict) async throws {
        guard let localData = conflict.localData,
              let serverData = conflict.serverData else {
            throw SyncError.invalidData
        }

        // Merge strategy: take newer fields from both versions
        switch conflict.entityType {
        case "Message":
            // Messages are immutable - use server version
            try await applyServerVersion(conflict)

        case "User":
            try await mergeUserData(entityId: conflict.entityId, localData: localData, serverData: serverData)

        case "Match":
            try await mergeMatchData(entityId: conflict.entityId, localData: localData, serverData: serverData)

        default:
            // Default to server version
            try await applyServerVersion(conflict)
        }
    }

    // MARK: - Entity-Specific Handlers

    private func applyLocalMessage(entityId: String, data: Data) async throws {
        let message = try JSONDecoder().decode(Message.self, from: data)
        try db.collection("messages").document(entityId).setData(from: message)
    }

    private func updateLocalMessage(entityId: String, data: Data) throws {
        // Update local cache if needed
        let message = try JSONDecoder().decode(Message.self, from: data)
        // Notify services to update their cache
        NotificationCenter.default.post(
            name: .messageUpdated,
            object: nil,
            userInfo: ["message": message]
        )
    }

    private func applyLocalUser(entityId: String, data: Data) async throws {
        let user = try JSONDecoder().decode(User.self, from: data)
        try db.collection("users").document(entityId).setData(from: user)
    }

    private func updateLocalUser(entityId: String, data: Data) throws {
        let user = try JSONDecoder().decode(User.self, from: data)
        NotificationCenter.default.post(
            name: .userUpdated,
            object: nil,
            userInfo: ["user": user]
        )
    }

    private func applyLocalMatch(entityId: String, data: Data) async throws {
        let match = try JSONDecoder().decode(Match.self, from: data)
        try db.collection("matches").document(entityId).setData(from: match)
    }

    private func updateLocalMatch(entityId: String, data: Data) throws {
        let match = try JSONDecoder().decode(Match.self, from: data)
        NotificationCenter.default.post(
            name: .matchUpdated,
            object: nil,
            userInfo: ["match": match]
        )
    }

    private func mergeUserData(entityId: String, localData: Data, serverData: Data) async throws {
        var localUser = try JSONDecoder().decode(User.self, from: localData)
        let serverUser = try JSONDecoder().decode(User.self, from: serverData)

        // Merge strategy: use newer values for each field
        // For user profiles, prefer local edits but keep server's system fields

        // Keep local user's profile edits
        // But use server's system fields (isPremium, isVerified, etc.)
        localUser.isPremium = serverUser.isPremium
        localUser.isVerified = serverUser.isVerified
        localUser.likesGiven = serverUser.likesGiven
        localUser.likesReceived = serverUser.likesReceived
        localUser.matchCount = serverUser.matchCount
        localUser.profileViews = serverUser.profileViews

        // Save merged version
        try db.collection("users").document(entityId).setData(from: localUser)
    }

    private func mergeMatchData(entityId: String, localData: Data, serverData: Data) async throws {
        let localMatch = try JSONDecoder().decode(Match.self, from: localData)
        var serverMatch = try JSONDecoder().decode(Match.self, from: serverData)

        // For matches, prefer server's message data but keep local's unread status if newer
        // Use server version as base
        // This is simplified - in production you'd compare timestamps

        try db.collection("matches").document(entityId).setData(from: serverMatch)
    }

    // MARK: - Auto-Resolution Strategy

    private func determineAutoResolutionStrategy(_ conflict: SyncConflict) -> ResolutionStrategy {
        switch conflict.entityType {
        case "Message":
            // Messages are immutable - always use server
            return .useServer

        case "User":
            // User profiles - merge to preserve both local edits and server updates
            return .merge

        case "Match":
            // Matches - use server (contains the source of truth for messages)
            return .useServer

        default:
            return .useServer
        }
    }

    // MARK: - Utilities

    /// Clears resolved conflicts
    func clearResolvedConflicts() {
        conflicts.removeAll { $0.status == .resolved }
    }

    /// Gets conflict count
    var pendingConflictCount: Int {
        conflicts.filter { $0.status == .pending }.count
    }
}

// MARK: - Models

struct SyncConflict: Identifiable {
    let id: String
    let entityType: String
    let entityId: String
    let localData: Data?
    let serverData: Data?
    let timestamp: Date
    var status: ConflictStatus
    var resolvedAt: Date?
    var resolutionStrategy: ResolutionStrategy?

    enum ConflictStatus {
        case pending
        case resolving
        case resolved
        case failed
    }
}

enum ResolutionStrategy {
    case useLocal      // Apply local changes to server
    case useServer     // Discard local changes, use server version
    case merge         // Merge both versions intelligently
    case manual        // User will manually resolve
}

enum SyncError: LocalizedError {
    case invalidData
    case resolutionFailed
    case unknownEntityType

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data for sync"
        case .resolutionFailed:
            return "Failed to resolve sync conflict"
        case .unknownEntityType:
            return "Unknown entity type for conflict resolution"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let messageUpdated = Notification.Name("messageUpdated")
    static let userUpdated = Notification.Name("userUpdated")
    static let matchUpdated = Notification.Name("matchUpdated")
}
