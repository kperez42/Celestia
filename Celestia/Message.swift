//
//  Message.swift
//  Celestia
//
//  Message model for chat functionality
//

import Foundation
import FirebaseFirestore

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
        isDelivered: Bool = false
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
    }
}
