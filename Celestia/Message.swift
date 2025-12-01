//
//  Message.swift
//  Celestia
//
//  Message model for chat functionality
//

import Foundation
import FirebaseFirestore

/// Represents an emoji reaction to a message
struct MessageReaction: Codable, Equatable, Hashable {
    var emoji: String
    var userId: String
    var timestamp: Date

    init(emoji: String, userId: String, timestamp: Date = Date()) {
        self.emoji = emoji
        self.userId = userId
        self.timestamp = timestamp
    }
}

/// Represents a reply reference to another message
struct MessageReply: Codable, Equatable {
    var messageId: String
    var senderId: String
    var senderName: String
    var text: String
    var imageURL: String?

    init(messageId: String, senderId: String, senderName: String, text: String, imageURL: String? = nil) {
        self.messageId = messageId
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        self.imageURL = imageURL
    }
}

struct Message: Identifiable, Codable {
    @DocumentID var id: String?
    var matchId: String
    var senderId: String
    var receiverId: String
    var text: String
    var imageURL: String?
    var timestamp: Date
    var isRead: Bool
    var isDelivered: Bool
    var readAt: Date? // Timestamp when message was read
    var deliveredAt: Date? // Timestamp when message was delivered

    // Editing support
    var isEdited: Bool
    var editedAt: Date?
    var originalText: String?

    // Reactions support
    var reactions: [MessageReaction]

    // Reply support
    var replyTo: MessageReply?

    // For compatibility with ChatDetailView
    var senderID: String {
        get { senderId }
        set { senderId = newValue }
    }

    /// Check if message has any reactions
    var hasReactions: Bool {
        !reactions.isEmpty
    }

    /// Get unique emojis used in reactions
    var uniqueReactionEmojis: [String] {
        Array(Set(reactions.map { $0.emoji }))
    }

    /// Get reaction count for a specific emoji
    func reactionCount(for emoji: String) -> Int {
        reactions.filter { $0.emoji == emoji }.count
    }

    /// Check if a user has reacted with a specific emoji
    func hasUserReacted(userId: String, emoji: String) -> Bool {
        reactions.contains { $0.userId == userId && $0.emoji == emoji }
    }

    /// Check if a user has any reaction on this message
    func hasUserReacted(userId: String) -> Bool {
        reactions.contains { $0.userId == userId }
    }

    init(
        id: String? = nil,
        matchId: String,
        senderId: String,
        receiverId: String,
        text: String,
        imageURL: String? = nil,
        timestamp: Date = Date(),
        isRead: Bool = false,
        isDelivered: Bool = false,
        readAt: Date? = nil,
        deliveredAt: Date? = nil,
        isEdited: Bool = false,
        editedAt: Date? = nil,
        originalText: String? = nil,
        reactions: [MessageReaction] = [],
        replyTo: MessageReply? = nil
    ) {
        self.id = id
        self.matchId = matchId
        self.senderId = senderId
        self.receiverId = receiverId
        self.text = text
        self.imageURL = imageURL
        self.timestamp = timestamp
        self.isRead = isRead
        self.isDelivered = isDelivered
        self.readAt = readAt
        self.deliveredAt = deliveredAt
        self.isEdited = isEdited
        self.editedAt = editedAt
        self.originalText = originalText
        self.reactions = reactions
        self.replyTo = replyTo
    }
}
