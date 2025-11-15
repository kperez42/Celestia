//
//  ChatDetailView.swift
//  Celestia
//
//  Chat conversation view
//

import SwiftUI

struct ChatDetailView: View {
    let otherUser: User
    @StateObject private var viewModel: ChatViewModel
    @EnvironmentObject var authService: AuthService
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    
    init(otherUser: User) {
        self.otherUser = otherUser
        _viewModel = StateObject(wrappedValue: ChatViewModel(currentUserId: "", otherUserId: otherUser.id ?? ""))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleGradient(
                                message: message,
                                isFromCurrentUser: message.senderID == authService.currentUser?.id
                            )
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages.count) {
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Message Input
            HStack(spacing: 12) {
                TextField("Message...", text: $messageText, axis: .vertical)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .focused($isInputFocused)
                    .lineLimit(1...5)
                    .onChange(of: messageText) { _, newValue in
                        // SAFETY: Enforce message character limit to prevent data overflow
                        if newValue.count > AppConstants.Limits.maxMessageLength {
                            messageText = String(newValue.prefix(AppConstants.Limits.maxMessageLength))
                        }
                    }

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            messageText.isEmpty ?
                            LinearGradient(colors: [.gray, .gray], startPoint: .leading, endPoint: .trailing) :
                            LinearGradient.brandPrimary
                        )
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationTitle(otherUser.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let currentUserId = authService.currentUser?.id {
                viewModel.updateCurrentUserId(currentUserId)
                viewModel.loadMessages()
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        viewModel.sendMessage(text: messageText)
        messageText = ""
    }
}

#Preview {
    NavigationView {
        ChatDetailView(otherUser: User(
            email: "test@test.com",
            fullName: "Sarah",
            age: 25,
            gender: "Female",
            lookingFor: "Men",
            location: "Paris",
            country: "France"
        ))
    }
    .environmentObject(AuthService.shared)
}
