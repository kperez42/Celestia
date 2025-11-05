//
//  Interest.swift
//  Celestia
//
//  Model for user interests/likes
//

import Foundation
import FirebaseFirestore

struct Interest: Identifiable, Codable {
    @DocumentID var id: String?
    var fromUserId: String
    var toUserId: String
    var message: String?
    var timestamp: Date
    var status: String // "pending", "accepted", "rejected"
    
    init(
        id: String? = nil,
        fromUserId: String,
        toUserId: String,
        message: String? = nil,
        timestamp: Date = Date(),
        status: String = "pending"
    ) {
        self.id = id
        self.fromUserId = fromUserId
        self.toUserId = toUserId
        self.message = message
        self.timestamp = timestamp
        self.status = status
    }
}
