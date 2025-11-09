//
//  OfflineMessageQueue.swift
//  Celestia
//
//  Queue messages when offline and sync when connection restored
//

import Foundation
import FirebaseFirestore

@MainActor
class OfflineMessageQueue: ObservableObject {
    static let shared = OfflineMessageQueue()

    @Published var queuedMessages: [QueuedMessage] = []
    @Published var isSyncing: Bool = false

    private let userDefaults = UserDefaults.standard
    private let queueKey = "offlineMessageQueue"
    private var networkMonitor = NetworkMonitor.shared

    private init() {
        loadQueue()
        setupNetworkObserver()
    }

    // MARK: - Queue Management

    func enqueueMessage(
        matchId: String,
        senderId: String,
        receiverId: String,
        text: String,
        temporaryId: String = UUID().uuidString
    ) {
        let queuedMessage = QueuedMessage(
            id: temporaryId,
            matchId: matchId,
            senderId: senderId,
            receiverId: receiverId,
            text: text,
            timestamp: Date(),
            retryCount: 0
        )

        queuedMessages.append(queuedMessage)
        saveQueue()

        // Try to send immediately if connected
        if networkMonitor.isConnected {
            Task {
                await processQueue()
            }
        }
    }

    func processQueue() async {
        guard !queuedMessages.isEmpty, networkMonitor.isConnected else { return }

        isSyncing = true
        defer { isSyncing = false }

        // Process messages in order
        for message in queuedMessages {
            do {
                try await sendMessage(message)
                // Remove from queue on success
                removeFromQueue(id: message.id)
            } catch {
                // Increment retry count
                incrementRetryCount(for: message.id)
                print("Failed to send queued message: \(error.localizedDescription)")

                // If too many retries, remove it
                if let msg = queuedMessages.first(where: { $0.id == message.id }),
                   msg.retryCount >= 5 {
                    removeFromQueue(id: message.id)
                    print("Removed message after 5 failed attempts")
                }
            }
        }

        saveQueue()
    }

    private func sendMessage(_ queuedMessage: QueuedMessage) async throws {
        let db = Firestore.firestore()

        let messageData: [String: Any] = [
            "matchId": queuedMessage.matchId,
            "senderId": queuedMessage.senderId,
            "receiverId": queuedMessage.receiverId,
            "text": queuedMessage.text,
            "timestamp": Timestamp(date: queuedMessage.timestamp),
            "isRead": false
        ]

        try await db.collection("messages")
            .document(queuedMessage.matchId)
            .collection("messages")
            .addDocument(data: messageData)
    }

    private func removeFromQueue(id: String) {
        queuedMessages.removeAll { $0.id == id }
        saveQueue()
    }

    private func incrementRetryCount(for id: String) {
        if let index = queuedMessages.firstIndex(where: { $0.id == id }) {
            queuedMessages[index].retryCount += 1
        }
    }

    // MARK: - Persistence

    private func saveQueue() {
        if let encoded = try? JSONEncoder().encode(queuedMessages) {
            userDefaults.set(encoded, forKey: queueKey)
        }
    }

    private func loadQueue() {
        if let data = userDefaults.data(forKey: queueKey),
           let decoded = try? JSONDecoder().decode([QueuedMessage].self, from: data) {
            queuedMessages = decoded
        }
    }

    // MARK: - Network Observer

    private func setupNetworkObserver() {
        // Observe network connection restoration
        NotificationCenter.default.addObserver(
            forName: .networkConnected,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                // Wait a moment for connection to stabilize
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                await self?.processQueue()
            }
        }
    }

    // MARK: - Helpers

    func clearQueue() {
        queuedMessages.removeAll()
        saveQueue()
    }

    var hasQueuedMessages: Bool {
        !queuedMessages.isEmpty
    }
}

// MARK: - Models

struct QueuedMessage: Codable, Identifiable {
    let id: String
    let matchId: String
    let senderId: String
    let receiverId: String
    let text: String
    let timestamp: Date
    var retryCount: Int

    enum CodingKeys: String, CodingKey {
        case id, matchId, senderId, receiverId, text, timestamp, retryCount
    }
}
