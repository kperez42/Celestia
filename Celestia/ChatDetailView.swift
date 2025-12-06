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
    @State private var isSending = false  // BUGFIX: Track sending state to prevent double-send
    @State private var showPremiumUpgrade = false
    @FocusState private var isInputFocused: Bool

    private var isPremium: Bool {
        authService.currentUser?.isPremium ?? false
    }

    // Daily message limit for free users (across ALL conversations)
    private var hasReachedLimit: Bool {
        !isPremium && RateLimiter.shared.hasReachedDailyMessageLimit()
    }

    private var remainingMessages: Int {
        RateLimiter.shared.getRemainingDailyMessages()
    }

    init(otherUser: User) {
        self.otherUser = otherUser
        // Note: currentUserId is set to placeholder here and updated in onAppear with actual effectiveId
        // This is because we don't have access to authService in init
        _viewModel = StateObject(wrappedValue: ChatViewModel(currentUserId: "", otherUserId: otherUser.effectiveId ?? ""))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Get the last read message ID to only show "Read" on the most recent
                        let lastReadId = lastReadMessageId()

                        ForEach(viewModel.messages) { message in
                            MessageBubbleGradient(
                                message: message,
                                isFromCurrentUser: message.senderID == authService.currentUser?.effectiveId,
                                showReadStatus: message.id == lastReadId
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

            // Daily message limit banner for free users
            if !isPremium && remainingMessages < AppConstants.RateLimit.maxDailyMessagesForFreeUsers {
                messageLimitBanner
            }

            // Message Input or Upgrade Prompt
            if hasReachedLimit {
                upgradeToContinueView
            } else {
                messageInputView
            }
        }
        .navigationTitle(otherUser.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // BUGFIX: Use effectiveId for reliable user identification
            if let currentUserId = authService.currentUser?.effectiveId {
                viewModel.updateCurrentUserId(currentUserId)
                viewModel.loadMessages()
            }
        }
        .sheet(isPresented: $showPremiumUpgrade) {
            PremiumUpgradeView()
                .environmentObject(authService)
        }
    }

    // MARK: - Message Limit Banner

    private var messageLimitBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.caption)
                .foregroundColor(.orange)

            if remainingMessages > 0 {
                Text("\(remainingMessages) daily message\(remainingMessages == 1 ? "" : "s") left")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Daily limit reached")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            Spacer()

            Button {
                showPremiumUpgrade = true
                HapticManager.shared.impact(.light)
            } label: {
                Text("Upgrade")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.1))
    }

    // MARK: - Upgrade to Continue View

    private var upgradeToContinueView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .foregroundColor(.orange)
                Text("Unlock unlimited messaging")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Button {
                showPremiumUpgrade = true
                HapticManager.shared.impact(.medium)
            } label: {
                Text("Upgrade to Premium")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(16)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Message Input View

    private var messageInputView: some View {
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
                        (messageText.isEmpty || isSending) ?
                        LinearGradient(colors: [.gray, .gray], startPoint: .leading, endPoint: .trailing) :
                        LinearGradient.brandPrimary
                    )
            }
            .disabled(messageText.isEmpty || isSending)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // BUGFIX: Prevent double-send from rapid taps
        guard !isSending else { return }

        // Check message limit for free users
        if hasReachedLimit {
            showPremiumUpgrade = true
            return
        }

        isSending = true
        let textToSend = messageText
        messageText = ""

        Task {
            await viewModel.sendMessage(text: textToSend)

            // Reset after a small delay to ensure message is processed
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            await MainActor.run {
                isSending = false
            }
        }
    }

    /// Returns the ID of the last read message from the current user
    /// This is used to only show "Read" indicator on the most recent read message
    private func lastReadMessageId() -> String? {
        guard let currentUserId = authService.currentUser?.effectiveId else { return nil }

        // Find all messages from current user that are read, then get the last one
        let currentUserReadMessages = viewModel.messages.filter { message in
            message.senderID == currentUserId && message.isRead
        }

        return currentUserReadMessages.last?.id
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
