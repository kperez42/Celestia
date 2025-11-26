//
//  Match.swift
//  Celestia
//
//  Match model for tracking user matches
//

import Foundation
import FirebaseFirestore

struct Match: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var user1Id: String
    var user2Id: String
    var timestamp: Date
    var lastMessageTimestamp: Date?
    var lastMessage: String?
    var lastMessageSenderId: String?
    var unreadCount: [String: Int]
    var isActive: Bool

    init(
        id: String? = nil,
        user1Id: String,
        user2Id: String,
        timestamp: Date = Date(),
        lastMessageTimestamp: Date? = nil,
        lastMessage: String? = nil,
        lastMessageSenderId: String? = nil,
        unreadCount: [String: Int] = [:],
        isActive: Bool = true
    ) {
        self.id = id
        self.user1Id = user1Id
        self.user2Id = user2Id
        self.timestamp = timestamp
        self.lastMessageTimestamp = lastMessageTimestamp
        self.lastMessage = lastMessage
        self.lastMessageSenderId = lastMessageSenderId
        self.unreadCount = unreadCount
        self.isActive = isActive
    }
}
