//
//  ChatView.swift
//  Celestia
//
//  Created by Kevin Perez on 10/29/25.
//

import SwiftUI

struct ChatView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var messageService = MessageService.shared
    
    let match: Match
    let otherUser: User
    
    @State private var messageText = ""
    @State private var scrollProxy: ScrollViewProxy?
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messageService.messages) { message in
                            MessageBubbleView(
                                message: message,
                                isFromCurrentUser: message.senderId == authService.currentUser?.id
                            )
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onAppear {
                    scrollProxy = proxy
                    scrollToBottom()
                }
                .onChange(of: messageService.messages.count) { _ in
                    scrollToBottom()
                }
            }
            
            // Message input
            HStack(spacing: 12) {
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .lineLimit(1...5)
                
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .resizable()
                        .frame(width: 35, height: 35)
                        .foregroundStyle(
                            LinearGradient(
                                colors: messageText.isEmpty ? [.gray] : [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
            .background(Color.white)
        }
        .navigationTitle(otherUser.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard let matchId = match.id else { return }
            messageService.listenToMessages(matchId: matchId)
            
            // Mark messages as read - FIXED: Proper async handling
            Task {
                guard let currentUserId = authService.currentUser?.id else { return }
                await messageService.markMessagesAsRead(matchId: matchId, userId: currentUserId)
            }
        }
        .onDisappear {
            messageService.stopListening()
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        guard let matchId = match.id else { return }
        guard let currentUserId = authService.currentUser?.id else { return }
        guard let otherUserId = otherUser.id else { return }
        
        let text = messageText
        messageText = ""
        
        Task {
            do {
                try await messageService.sendMessage(
                    matchId: matchId,
                    senderId: currentUserId,
                    receiverId: otherUserId,
                    text: text
                )
            } catch {
                print("Error sending message: \(error)")
                // Restore message on error
                await MainActor.run {
                    messageText = text
                }
            }
        }
    }
    
    private func scrollToBottom() {
        guard let lastMessage = messageService.messages.last else { return }
        withAnimation {
            scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}

struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(12)
                    .background(bubbleBackground)
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .cornerRadius(16)
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: 250, alignment: isFromCurrentUser ? .trailing : .leading)
            
            if !isFromCurrentUser {
                Spacer()
            }
        }
    }
    
    private var bubbleBackground: some View {
        Group {
            if isFromCurrentUser {
                LinearGradient(
                    colors: [Color.purple, Color.blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(0.8)
            } else {
                Color(.systemGray5)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        ChatView(
            match: Match(user1Id: "1", user2Id: "2"),
            otherUser: User(
                email: "test@example.com",
                fullName: "Maria Garcia",
                age: 25,
                gender: "Female",
                lookingFor: "Male",
                location: "Barcelona",
                country: "Spain"
            )
        )
        .environmentObject(AuthService.shared)
    }
}
