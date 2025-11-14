//
//  Message.swift
//  Celestia
//
//  Message model for chat functionality
//

import Foundation
import FirebaseFirestore

struct Message: Identifiable, Codable, Equatable, Hashable {
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

    // Equatable conformance for performance optimization
    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id &&
        lhs.text == rhs.text &&
        lhs.isRead == rhs.isRead &&
        lhs.isDelivered == rhs.isDelivered &&
        lhs.imageURL == rhs.imageURL
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(timestamp)
    }

    // For compatibility with ChatDetailView
    var senderID: String {
        get { senderId }
        set { senderId = newValue }
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
        deliveredAt: Date? = nil
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
    }
}
