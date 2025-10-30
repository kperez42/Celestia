//
//  Interest.swift
//  Celestia
//
//  Created by Kevin Perez on 10/29/25.
//

import Foundation
import FirebaseFirestore

struct Interest: Identifiable, Codable {
    @DocumentID var id: String?
    var fromUserId: String
    var toUserId: String
    var timestamp: Date
    var isAccepted: Bool?
    var message: String? // Optional initial message
    
    init(id: String? = nil,
         fromUserId: String,
         toUserId: String,
         timestamp: Date = Date(),
         isAccepted: Bool? = nil,
         message: String? = nil) {
        self.id = id
        self.fromUserId = fromUserId
        self.toUserId = toUserId
        self.timestamp = timestamp
        self.isAccepted = isAccepted
        self.message = message
    }
}
