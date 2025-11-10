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
    @State private var isOtherUserTyping = false
    @State private var showingUnmatchConfirmation = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Custom header
            customHeader

            Divider()

            // Messages
            messagesScrollView

            // Input bar
            messageInputBar
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupChat()
        }
        .onDisappear {
            messageService.stopListening()
        }
        .confirmationDialog("Unmatch with \(otherUser.fullName)?", isPresented: $showingUnmatchConfirmation, titleVisibility: .visible) {
            Button("Unmatch", role: .destructive) {
                HapticManager.shared.notification(.warning)
                Task {
                    do {
                        if let matchId = match?.id {
                            try await MatchService.shared.unmatch(matchId: matchId, userId: currentUserId)
                            dismiss()
                        }
                    } catch {
                        print("Error unmatching: \(error)")
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                HapticManager.shared.impact(.light)
            }
        } message: {
            Text("You won't be able to message each other anymore, and this match will be removed from your list.")
        }
        .detectScreenshots(
            context: .chat(
                matchId: match.id ?? "",
                otherUserId: otherUser.id ?? ""
            ),
            userName: otherUser.fullName
        )
    }

    // MARK: - Custom Header

    private var customHeader: some View {
        HStack(spacing: 12) {
            // Back button
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.purple)
            }

            // Profile image
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.7), Color.pink.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay(
                    Text(otherUser.fullName.prefix(1))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                )

            // Name and status
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(otherUser.fullName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if otherUser.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                }

                if isOtherUserTyping {
                    Text("typing...")
                        .font(.caption)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                } else if otherUser.isOnline {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Active now")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Active \(otherUser.lastActive.timeAgoShort())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // More options menu
            Menu {
                Button {
                    // View profile
                } label: {
                    Label("View Profile", systemImage: "person.circle")
                }

                Button(role: .destructive) {
                    showingUnmatchConfirmation = true
                } label: {
                    Label("Unmatch", systemImage: "xmark.circle")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Messages ScrollView

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(groupedMessages(), id: \.0) { section in
                        // Date divider
                        Text(section.0)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)

                        // Messages for this date
                        ForEach(section.1) { message in
                            MessageBubbleGradient(
                                message: message,
                                isFromCurrentUser: message.senderId == authService.currentUser?.id || message.senderId == "current_user"
                            )
                            .id(message.id)
                        }
                    }

                    // Typing indicator
                    if isOtherUserTyping {
                        TypingIndicator(userName: otherUser.fullName)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .id("typing")
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .onChange(of: messageService.messages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isOtherUserTyping) { _ in
                if isOtherUserTyping {
                    withAnimation {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
        }
    }

    private func groupedMessages() -> [(String, [Message])] {
        let grouped = Dictionary(grouping: messageService.messages) { message -> String in
            let formatter = DateFormatter()
            let calendar = Calendar.current

            if calendar.isDateInToday(message.timestamp) {
                return "Today"
            } else if calendar.isDateInYesterday(message.timestamp) {
                return "Yesterday"
            } else {
                formatter.dateFormat = "MMMM d, yyyy"
                return formatter.string(from: message.timestamp)
            }
        }

        return grouped.sorted { first, second in
            // Sort by the date of the first message in each group
            if let firstMessage = first.value.first, let secondMessage = second.value.first {
                return firstMessage.timestamp < secondMessage.timestamp
            }
            return false
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if isOtherUserTyping {
            withAnimation {
                proxy.scrollTo("typing", anchor: .bottom)
            }
        } else if let lastMessage = messageService.messages.last {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    // MARK: - Input Bar

    private var messageInputBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Text input
                TextField("Message...", text: $messageText, axis: .vertical)
                    .focused($isInputFocused)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .lineLimit(1...5)
                    .onChange(of: messageText) { _ in
                        // Simulate typing indicator (in production, send to Firestore)
                        #if DEBUG
                        // Toggle typing indicator for demo
                        #endif
                    }

                // Send button
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: messageText.isEmpty ? "arrow.up.circle" : "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            messageText.isEmpty ?
                            LinearGradient(colors: [.gray.opacity(0.5)], startPoint: .leading, endPoint: .trailing) :
                            LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                        )
                }
                .disabled(messageText.isEmpty)
            }

            // Character count (if over 100 characters)
            if messageText.count > 100 {
                HStack {
                    Spacer()
                    Text("\(messageText.count)/500")
                        .font(.caption2)
                        .foregroundColor(messageText.count > 450 ? .red : .secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 5, y: -2)
    }
    
    // MARK: - Helper Functions
    
    private func setupChat() {
        guard let matchId = match.id else { return }

        messageService.listenToMessages(matchId: matchId)

        // Mark messages as read
        if let userId = authService.currentUser?.id {
            Task {
                await messageService.markMessagesAsRead(matchId: matchId, userId: userId)
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }

        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            messageText = ""
            return
        }

        guard let matchId = match.id else { return }

        // Haptic feedback
        HapticManager.shared.impact(.light)

        // Clear input immediately for better UX
        messageText = ""

        guard let currentUserId = authService.currentUser?.id else { return }
        guard let receiverId = otherUser.id else { return }

        Task {
            do {
                try await messageService.sendMessage(
                    matchId: matchId,
                    senderId: currentUserId,
                    receiverId: receiverId,
                    text: text
                )
                HapticManager.shared.notification(.success)
            } catch {
                print("Error sending message: \(error)")
                HapticManager.shared.notification(.error)
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
