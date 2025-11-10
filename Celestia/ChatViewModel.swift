//
//  ChatViewModel.swift
//  Celestia
//
//  Handles chat and messaging functionality
//

import Foundation
import FirebaseFirestore

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var matches: [Match] = []
    @Published var isLoading = false
    
    private let firestore = Firestore.firestore()
    private var messagesListener: ListenerRegistration?
    
    var currentUserId: String
    var otherUserId: String
    
    init(currentUserId: String = "", otherUserId: String = "") {
        self.currentUserId = currentUserId
        self.otherUserId = otherUserId
    }
    
    func updateCurrentUserId(_ userId: String) {
        self.currentUserId = userId
    }
    
    func loadMatches(for userID: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Use OR filter for optimized single query
            let snapshot = try await firestore.collection("matches")
                .whereFilter(Filter.orFilter([
                    Filter.whereField("user1Id", isEqualTo: userID),
                    Filter.whereField("user2Id", isEqualTo: userID)
                ]))
                .whereField("isActive", isEqualTo: true)
                .getDocuments()

            matches = snapshot.documents
                .compactMap { try? $0.data(as: Match.self) }
                .sorted { ($0.lastMessageTimestamp ?? $0.timestamp) > ($1.lastMessageTimestamp ?? $1.timestamp) }
        } catch {
            print("Error loading matches: \(error)")
        }
    }
    
    func loadMessages() {
        guard !currentUserId.isEmpty && !otherUserId.isEmpty else { return }
        
        // Find match between current user and other user
        Task {
            if let match = try? await MatchService.shared.fetchMatch(user1Id: currentUserId, user2Id: otherUserId),
               let matchId = match.id {
                await loadMessages(for: matchId)
            }
        }
    }
    
    func loadMessages(for matchID: String) async {
        messagesListener?.remove()
        
        await MainActor.run {
            messagesListener = firestore.collection("messages")
                .whereField("matchId", isEqualTo: matchID)
                .order(by: "timestamp", descending: false)
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("Error loading messages: \(error)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    self.messages = documents.compactMap { doc -> Message? in
                        try? doc.data(as: Message.self)
                    }
                }
        }
    }
    
    func sendMessage(text: String) {
        guard !currentUserId.isEmpty && !otherUserId.isEmpty else { return }
        guard !text.isEmpty else { return }
        
        Task {
            do {
                // Find or create match
                if let match = try? await MatchService.shared.fetchMatch(user1Id: currentUserId, user2Id: otherUserId),
                   let matchId = match.id {
                    
                    try await MessageService.shared.sendMessage(
                        matchId: matchId,
                        senderId: currentUserId,
                        receiverId: otherUserId,
                        text: text
                    )
                }
            } catch {
                print("Error sending message: \(error)")
            }
        }
    }
    
    func sendMessage(matchID: String, senderID: String, receiverID: String, content: String) {
        let message = Message(
            matchId: matchID,
            senderId: senderID,
            receiverId: receiverID,
            text: content
        )
        
        do {
            try firestore.collection("messages").addDocument(from: message) { [weak self] error in
                if let error = error {
                    print("Error sending message: \(error)")
                    return
                }
                
                // Update match's lastMessageTimestamp
                self?.firestore.collection("matches").document(matchID).updateData([
                    "lastMessageTimestamp": Date()
                ])
            }
        } catch {
            print("Error encoding message: \(error)")
        }
    }
    
    func markMessagesAsRead(matchID: String, currentUserID: String) {
        firestore.collection("messages")
            .whereField("matchId", isEqualTo: matchID)
            .whereField("receiverId", isEqualTo: currentUserID)
            .whereField("isRead", isEqualTo: false)
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                for doc in documents {
                    doc.reference.updateData(["isRead": true])
                }
            }
    }
    
    deinit {
        messagesListener?.remove()
    }
}
