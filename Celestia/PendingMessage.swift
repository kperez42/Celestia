//
//  PendingMessage.swift
//  Celestia
//
//  Model for messages awaiting server-side validation
//  Used in offline queue when backend validation is unavailable
//

import Foundation
import FirebaseFirestore

/// Status of a pending message in the validation queue
enum PendingMessageStatus: String, Codable {
    case pendingValidation      // Waiting for backend validation
    case validationFailed        // Backend rejected the message
    case validated              // Backend approved, ready to send
    case sent                   // Successfully sent to Firestore
    case failed                 // Failed to send (permanent error)
}

/// A message waiting in the queue for validation or sending
struct PendingMessage: Codable, Identifiable {
    let id: String
    let matchId: String
    let senderId: String
    let receiverId: String
    let text: String
    let sanitizedText: String
    var status: PendingMessageStatus
    let createdAt: Date
    var lastValidationAttempt: Date?
    var validationAttempts: Int
    var failureReason: String?
    let imageURL: String?

    /// Maximum validation attempts before giving up
    static let maxValidationAttempts = 5

    /// Time between validation retry attempts (exponential backoff)
    static func retryDelay(for attempt: Int) -> TimeInterval {
        let baseDelay: TimeInterval = 30 // 30 seconds
        let maxDelay: TimeInterval = 300 // 5 minutes
        let delay = baseDelay * pow(2.0, Double(attempt - 1))
        return min(delay, maxDelay)
    }

    init(
        matchId: String,
        senderId: String,
        receiverId: String,
        text: String,
        sanitizedText: String,
        imageURL: String? = nil
    ) {
        self.id = UUID().uuidString
        self.matchId = matchId
        self.senderId = senderId
        self.receiverId = receiverId
        self.text = text
        self.sanitizedText = sanitizedText
        self.status = .pendingValidation
        self.createdAt = Date()
        self.lastValidationAttempt = nil
        self.validationAttempts = 0
        self.failureReason = nil
        self.imageURL = imageURL
    }

    /// Check if this message is ready for another validation attempt
    var isReadyForRetry: Bool {
        guard status == .pendingValidation else { return false }
        guard validationAttempts < Self.maxValidationAttempts else { return false }

        // If never attempted, ready immediately
        guard let lastAttempt = lastValidationAttempt else { return true }

        // Check if enough time has passed since last attempt
        let requiredDelay = Self.retryDelay(for: validationAttempts)
        let timeSinceLastAttempt = Date().timeIntervalSince(lastAttempt)

        return timeSinceLastAttempt >= requiredDelay
    }

    /// Check if this message has expired (too old to retry)
    var isExpired: Bool {
        let maxAge: TimeInterval = 3600 // 1 hour
        return Date().timeIntervalSince(createdAt) > maxAge
    }

    /// Convert to Message object for sending
    func toMessage() -> Message {
        return Message(
            matchId: matchId,
            senderId: senderId,
            receiverId: receiverId,
            text: sanitizedText,
            imageURL: imageURL
        )
    }
}
