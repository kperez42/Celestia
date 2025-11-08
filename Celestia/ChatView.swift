//
//  ChatView.swift
//  Celestia
//
//  Chat view with real-time messaging
//

import SwiftUI

struct ChatView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var messageService = MessageService.shared
    
    let match: Match
    let otherUser: User
    
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages
            messagesScrollView
            
            // Input bar
            messageInputBar
        }
        .navigationTitle(otherUser.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupChat()
        }
        .onDisappear {
            messageService.stopListening()
        }
    }
    
    // MARK: - Messages ScrollView
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messageService.messages) { message in
                        MessageBubbleGradient(
                            message: message,
                            isFromCurrentUser: message.senderId == authService.currentUser?.id
                        )
                        .id(message.id)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .onChange(of: messageService.messages.count) { _ in
                if let lastMessage = messageService.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Input Bar
    
    private var messageInputBar: some View {
        HStack(spacing: 12) {
            TextField("Message...", text: $messageText, axis: .vertical)
                .focused($isInputFocused)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .lineLimit(1...5)
            
            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        messageText.isEmpty ?
                        LinearGradient(colors: [.gray, .gray], startPoint: .leading, endPoint: .trailing) :
                        LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                    )
            }
            .disabled(messageText.isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Helper Functions
    
    private func setupChat() {
        guard let matchId = match.id else { return }

        #if DEBUG
        // Use test messages in preview/debug mode
        messageService.messages = TestData.messagesForMatch(matchId)
        #else
        messageService.listenToMessages(matchId: matchId)

        // Mark messages as read
        if let userId = authService.currentUser?.id {
            Task {
                await messageService.markMessagesAsRead(matchId: matchId, userId: userId)
            }
        }
        #endif
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        guard let matchId = match.id else { return }
        guard let currentUserId = authService.currentUser?.id else { return }
        guard let receiverId = otherUser.id else { return }
        
        let text = messageText
        messageText = ""
        
        Task {
            do {
                try await messageService.sendMessage(
                    matchId: matchId,
                    senderId: currentUserId,
                    receiverId: receiverId,
                    text: text
                )
            } catch {
                print("Error sending message: \(error)")
                // Could show error alert here
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(
            match: Match(user1Id: "1", user2Id: "2"),
            otherUser: User(
                email: "test@example.com",
                fullName: "Test User",
                age: 25,
                gender: "Female",
                lookingFor: "Male",
                location: "New York",
                country: "USA"
            )
        )
        .environmentObject(AuthService.shared)
    }
}
