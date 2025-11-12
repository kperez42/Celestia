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
    @StateObject private var safetyManager = SafetyManager.shared

    let match: Match
    let otherUser: User

    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    @State private var isOtherUserTyping = false
    @State private var showingUnmatchConfirmation = false
    @State private var showingUserProfile = false
    @State private var showingReportSheet = false
    @State private var isSending = false
    @State private var conversationSafetyReport: ConversationSafetyReport?
    @State private var showSafetyWarning = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Custom header
            customHeader

            Divider()

            // Safety warning banner
            if let safetyReport = conversationSafetyReport, !safetyReport.isSafe, showSafetyWarning {
                safetyWarningBanner(report: safetyReport)
            }

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
                        if let matchId = match.id,
                           let currentUserId = authService.currentUser?.id {
                            try await MatchService.shared.unmatch(matchId: matchId, userId: currentUserId)
                            dismiss()
                        }
                    } catch {
                        Logger.shared.error("Error unmatching", category: .matching, error: error)
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
        .sheet(isPresented: $showingUserProfile) {
            UserDetailView(user: otherUser)
        }
        .sheet(isPresented: $showingReportSheet) {
            if let userId = otherUser.id {
                ReportUserView(
                    reportedUserId: userId,
                    reportedUserName: otherUser.fullName,
                    context: .chat
                )
            }
        }
        .onChange(of: messageService.messages.count) {
            // Check conversation safety whenever new messages arrive
            checkConversationSafety()
        }
        .task {
            // Initial safety check
            checkConversationSafety()
        }
    }

    // MARK: - Custom Header

    private var customHeader: some View {
        HStack(spacing: 12) {
            // Back button
            Button {
                dismiss()
                HapticManager.shared.impact(.light)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.purple)
                    .frame(width: 44, height: 44)
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

                    // Safety score badge
                    if let safetyReport = conversationSafetyReport {
                        safetyScoreBadge(report: safetyReport)
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
                    showingUserProfile = true
                    HapticManager.shared.impact(.light)
                } label: {
                    Label("View Profile", systemImage: "person.circle")
                }

                Divider()

                Button {
                    showingReportSheet = true
                    HapticManager.shared.impact(.light)
                } label: {
                    Label("Report User", systemImage: "exclamationmark.triangle")
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
                    .frame(width: 44, height: 44)
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
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .onChange(of: messageService.messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isOtherUserTyping) {
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
                    .onChange(of: messageText) {
                        // Simulate typing indicator (in production, send to Firestore)
                        #if DEBUG
                        // Toggle typing indicator for demo
                        #endif
                    }

                // Send button
                Button {
                    sendMessage()
                } label: {
                    ZStack {
                        if isSending {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                        } else {
                            Image(systemName: messageText.isEmpty ? "arrow.up.circle" : "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(
                                    messageText.isEmpty ?
                                    LinearGradient(colors: [.gray.opacity(0.5)], startPoint: .leading, endPoint: .trailing) :
                                    LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                                )
                        }
                    }
                    .frame(width: 32, height: 32)
                }
                .disabled(messageText.isEmpty || isSending)
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
        guard !messageText.isEmpty, !isSending else { return }

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

        isSending = true

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
                Logger.shared.error("Error sending message", category: .messaging, error: error)
                HapticManager.shared.notification(.error)
                // Could show error alert here
            }
            isSending = false
        }
    }

    // MARK: - Safety Features

    /// Check conversation for scam patterns
    private func checkConversationSafety() {
        // Convert Message objects to ChatMessage for scam detection
        let chatMessages = messageService.messages.map { message in
            ChatMessage(
                text: message.text,
                senderId: message.senderId,
                timestamp: message.timestamp
            )
        }

        guard !chatMessages.isEmpty else { return }

        Task {
            let safetyReport = await safetyManager.checkConversationSafety(messages: chatMessages)

            await MainActor.run {
                conversationSafetyReport = safetyReport
                showSafetyWarning = !safetyReport.isSafe

                // Log safety check
                if !safetyReport.isSafe {
                    Logger.shared.warning("Scam detected in conversation. Score: \(safetyReport.scamAnalysis.scamScore)", category: .general)
                }
            }
        }
    }

    /// Safety warning banner view
    private func safetyWarningBanner(report: ConversationSafetyReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Safety Warning")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text(report.warnings.first ?? "This conversation shows signs of a potential scam")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()

                Button {
                    showSafetyWarning = false
                    HapticManager.shared.impact(.light)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(4)
                }
            }

            // Scam types
            if !report.scamAnalysis.scamTypes.isEmpty {
                HStack(spacing: 6) {
                    ForEach(report.scamAnalysis.scamTypes.prefix(2), id: \.self) { scamType in
                        Text(scamType.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    showingReportSheet = true
                    HapticManager.shared.impact(.medium)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill")
                        Text("Report")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(12)
                }

                Button {
                    showingUnmatchConfirmation = true
                    HapticManager.shared.impact(.medium)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                        Text("Block")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.red, Color.orange],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }

    /// Safety score badge
    private func safetyScoreBadge(report: ConversationSafetyReport) -> some View {
        HStack(spacing: 3) {
            Image(systemName: report.isSafe ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .font(.system(size: 10))
                .foregroundColor(report.isSafe ? .green : (report.scamAnalysis.scamScore >= 0.8 ? .red : .orange))

            Text(String(format: "%.0f%%", (1.0 - report.scamAnalysis.scamScore) * 100))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(report.isSafe ? .green : (report.scamAnalysis.scamScore >= 0.8 ? .red : .orange))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(report.isSafe ? Color.green.opacity(0.15) : (report.scamAnalysis.scamScore >= 0.8 ? Color.red.opacity(0.15) : Color.orange.opacity(0.15)))
        )
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
