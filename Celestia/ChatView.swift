//
//  ChatView.swift
//  Celestia
//
//  Chat view with real-time messaging
//  ACCESSIBILITY: Full VoiceOver support, Dynamic Type, Reduce Motion, and WCAG 2.1 AA compliant
//

import SwiftUI
import PhotosUI
import FirebaseFirestore

struct ChatView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var messageService = MessageService.shared
    @StateObject private var typingService = TypingStatusService.shared
    @StateObject private var safetyManager = SafetyManager.shared
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    let match: Match
    let otherUser: User

    // Real-time updated user data
    @State private var otherUserData: User
    @State private var userListener: ListenerRegistration?

    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    @State private var showingUnmatchConfirmation = false
    @State private var showingBlockConfirmation = false
    @State private var showingUserProfile = false
    @State private var showingReportSheet = false
    @State private var showingPremiumUpgrade = false
    @State private var isSending = false
    @State private var sendingMessagePreview: String?
    @State private var sendingImagePreview: UIImage?
    @State private var conversationSafetyReport: ConversationSafetyReport?
    @State private var showSafetyWarning = false

    // Image message states
    @State private var selectedImageItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showImagePreview = false

    // Error handling states
    @State private var showErrorToast = false
    @State private var errorToastMessage = ""
    @State private var failedMessage: (text: String, image: UIImage?)?

    // Cached grouped messages to prevent recalculation on every render
    // NOTE: Cache is updated via onChange, not during body computation (fixes "Modifying state during view update" warning)
    @State private var cachedGroupedMessages: [(String, [Message])] = []
    @State private var lastMessageCount = -1

    // Track initial load to prevent scroll animation on first load
    @State private var isInitialLoad = true

    // PERFORMANCE: Track if THIS chat has loaded messages to prevent conversation starters flash
    // This fixes a race condition where view renders before onAppear sets loading state
    @State private var hasLoadedMessagesForThisChat = false

    // PERFORMANCE: Debounce message count changes to prevent excessive updates
    @State private var pendingScrollTask: Task<Void, Never>?

    // Reply state
    @State private var replyingToMessage: Message?
    @State private var showReplyBar = false

    // Edit state
    @State private var editingMessage: Message?
    @State private var showEditSheet = false
    @State private var editText = ""

    // Reusable date formatter for performance
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()

    private static let calendar = Calendar.current

    @Environment(\.dismiss) var dismiss

    // Network monitoring for upload operations
    @ObservedObject var networkMonitor = NetworkMonitor.shared

    // Initialize with the passed otherUser data
    init(match: Match, otherUser: User) {
        self.match = match
        self.otherUser = otherUser
        self._otherUserData = State(initialValue: otherUser)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Network status banner - shows when offline
            if !networkMonitor.isConnected {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.subheadline)
                    Text("No Internet Connection")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange)
            }

            // Custom header
            customHeader

            Divider()

            // Safety warning banner
            if let safetyReport = conversationSafetyReport, !safetyReport.isSafe, showSafetyWarning {
                safetyWarningBanner(report: safetyReport)
            }

            // Messages
            messagesScrollView

            // Daily message limit banner for free users
            if let isPremium = authService.currentUser?.isPremium, !isPremium {
                dailyMessageLimitBanner
            }

            // Input bar
            messageInputBar
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(AccessibilityIdentifier.chatView)
        .onAppear {
            setupChat()
            setupUserListener()
            VoiceOverAnnouncement.screenChanged(to: "Chat with \(otherUser.fullName)")
        }
        .onDisappear {
            // Only clean up user-specific listener (typing indicators, online status)
            // Don't call stopListening() here - it clears all messages which breaks
            // the experience when user just switches tabs and comes back
            // The message listener will be cleaned up when:
            // - A new chat is opened (listenToMessages handles cleanup)
            // - App goes to background (ListenerLifecycleManager handles it)
            cleanupUserListener()
        }
        .onReceive(NotificationCenter.default.publisher(for: .networkConnectionRestored)) { _ in
            // AUTO-RETRY: When network is restored and we have a failed message, offer to retry
            if failedMessage != nil && networkMonitor.isConnected {
                Task { @MainActor in
                    errorToastMessage = "Connection restored! Tap retry to send your message."
                    showErrorToast = true
                    HapticManager.shared.notification(.success)

                    // Auto-hide after 5 seconds
                    Task {
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        if showErrorToast && errorToastMessage.contains("Connection restored") {
                            showErrorToast = false
                        }
                    }
                }
            }
        }
        .confirmationDialog("Unmatch with \(otherUser.fullName)?", isPresented: $showingUnmatchConfirmation, titleVisibility: .visible) {
            Button("Unmatch", role: .destructive) {
                HapticManager.shared.notification(.warning)
                Task {
                    do {
                        if let matchId = match.id,
                           let currentUserId = authService.currentUser?.effectiveId {
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
        .alert("Block \(otherUser.fullName)?", isPresented: $showingBlockConfirmation) {
            Button("Cancel", role: .cancel) {
                HapticManager.shared.impact(.light)
            }
            Button("Block", role: .destructive) {
                blockUser()
            }
        } message: {
            Text("They won't be able to see your profile or contact you. This will also remove them from your matches.")
        }
        .detectScreenshots(
            context: ScreenshotDetectionService.ScreenshotContext.chat(
                matchId: match.id ?? "",
                otherUserId: otherUser.effectiveId ?? ""
            ),
            userName: otherUser.fullName
        )
        .sheet(isPresented: $showingUserProfile) {
            UserDetailView(user: otherUser)
        }
        .sheet(isPresented: $showingReportSheet) {
            ReportUserView(user: otherUser)
        }
        .sheet(isPresented: $showingPremiumUpgrade) {
            PremiumUpgradeView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showEditSheet) {
            editMessageSheet
        }
        .onChange(of: messageService.messages.count) { oldCount, newCount in
            // BUGFIX: Only mark as loaded when messages are populated AND for THIS match
            // This prevents race condition when switching between chats
            let isActiveMatch = messageService.activeMatchId == match.id
            let messagesAreForThisMatch = messageService.messages.first?.matchId == match.id
            if newCount > 0 && !hasLoadedMessagesForThisChat && (isActiveMatch || messagesAreForThisMatch) {
                // FIX: Defer state change to avoid "Modifying state during view update" warning
                Task { @MainActor in
                    hasLoadedMessagesForThisChat = true
                }
            }
            // FIX: Update grouped messages cache outside of body computation
            Task { @MainActor in
                updateGroupedMessagesCache()
            }
            // SWIFTUI FIX: Defer safety check with longer delay to avoid modifying state during view update
            // Only check if message count actually increased (not on initial load or deletions)
            guard newCount > oldCount else { return }
            Task {
                // Longer delay ensures view update cycle completes
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
                checkConversationSafety()
            }
        }
        .onChange(of: messageService.isLoading) { _, isLoading in
            // BUGFIX: Mark as loaded once service finishes loading for THIS match
            // This ensures we only show conversation starters AFTER we confirm no messages exist
            let isActiveMatch = messageService.activeMatchId == match.id
            let messagesAreForThisMatch = messageService.messages.isEmpty || messageService.messages.first?.matchId == match.id
            if !isLoading && !hasLoadedMessagesForThisChat && (isActiveMatch || messagesAreForThisMatch) {
                // FIX: Defer state change to avoid "Modifying state during view update" warning
                Task { @MainActor in
                    hasLoadedMessagesForThisChat = true
                }
            }
        }
        .task {
            // SWIFTUI FIX: Defer initial safety check until view is fully loaded
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms delay
            checkConversationSafety()
        }
        .overlay(alignment: .top) {
            if showErrorToast {
                errorToastView
                    .padding(.top, 60)
                    .transition(.opacity)
                    .zIndex(999)
            }
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
                    .font(.body.weight(.semibold))
                    .foregroundColor(.purple)
                    .frame(width: 44, height: 44)
            }
            .accessibilityElement(
                label: "Back",
                hint: "Return to messages list",
                traits: .isButton,
                identifier: AccessibilityIdentifier.backButton
            )

            // Profile image
            Button {
                showingUserProfile = true
                HapticManager.shared.impact(.light)
            } label: {
                if let photoURL = otherUserData.photos.first, let url = URL(string: photoURL) {
                    CachedCardImage(url: url, priority: .immediate)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
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
                            Text(otherUserData.fullName.prefix(1))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
            }

            // Name and status
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(otherUserData.fullName)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if otherUserData.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                }

                if typingService.isOtherUserTyping {
                    Text("typing...")
                        .font(.caption)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                } else {
                    // Consider user active if they're online OR were active in the last 5 minutes
                    let interval = Date().timeIntervalSince(otherUserData.lastActive)
                    let isActive = otherUserData.isOnline || interval < 300

                    if isActive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text(otherUserData.isOnline ? "Online" : "Active now")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Active \(otherUserData.lastActive.timeAgoShort())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
                    showingBlockConfirmation = true
                    HapticManager.shared.impact(.medium)
                } label: {
                    Label("Block User", systemImage: "hand.raised.fill")
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
                    // Loading indicator for older messages (at top)
                    if messageService.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                            Text("Loading older messages...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .id("loadingTop")
                    }

                    // Load more trigger (invisible, detects when user scrolls to top)
                    if messageService.hasMoreMessages && !messageService.messages.isEmpty && !messageService.isLoadingMore {
                        Color.clear
                            .frame(height: 1)
                            .id("loadMoreTrigger")
                            .onAppear {
                                // User scrolled to top - load older messages
                                Task {
                                    if let matchId = match.id {
                                        await messageService.loadOlderMessages(matchId: matchId)
                                    }
                                }
                            }
                    }

                    // Show conversation starters ONLY for brand new conversations
                    // BUGFIX: Use hasLoadedMessagesForThisChat to prevent flash of conversation starters
                    // before messages are loaded. This fixes a race condition where the view renders
                    // before onAppear sets the loading state.
                    // FIX: Don't show conversation starters if there was an error loading messages
                    // FIX: Only show if this is truly a NEW conversation (no messages ever sent)
                    // Check match.lastMessage to determine if conversation has ever had messages
                    let isNewConversation = match.lastMessage == nil && match.lastMessageTimestamp == nil
                    if messageService.messages.isEmpty && isNewConversation, let currentUser = authService.currentUser {
                        if messageService.isLoading || !hasLoadedMessagesForThisChat {
                            // Show loading state - either service is loading OR we haven't confirmed load for this chat
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                Text("Loading messages...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 100)
                        } else if messageService.error != nil {
                            // Show error state instead of conversation starters if there was a load error
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.orange)
                                Text("Couldn't load messages")
                                    .font(.headline)
                                Text("Pull down to try again")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Button("Retry") {
                                    if let matchId = match.id {
                                        messageService.listenToMessages(matchId: matchId)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.purple)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 100)
                        } else {
                            conversationStartersView(currentUser: currentUser)
                        }
                    }

                    // Get the last read message ID to only show "Read" on the most recent
                    let lastReadId = lastReadMessageId()

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
                                isFromCurrentUser: message.senderId == authService.currentUser?.effectiveId || message.senderId == "current_user",
                                currentUserId: authService.currentUser?.effectiveId,
                                showReadStatus: message.id == lastReadId,
                                onReaction: { emoji in
                                    handleReaction(messageId: message.id ?? "", emoji: emoji)
                                },
                                onReply: {
                                    startReplyTo(message: message)
                                },
                                onEdit: {
                                    startEditing(message: message)
                                },
                                onTapReplyPreview: { replyMessageId in
                                    scrollToMessage(messageId: replyMessageId)
                                }
                            )
                            .id(message.id)
                        }
                    }

                    // Sending message preview
                    if isSending, let preview = sendingMessagePreview {
                        HStack {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                if let image = sendingImagePreview {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 200, height: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }

                                if !preview.isEmpty {
                                    Text(preview)
                                        .font(.body)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(
                                            LinearGradient(
                                                colors: [Color.purple.opacity(0.7), Color.pink.opacity(0.7)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .cornerRadius(18)
                                }

                                HStack(spacing: 4) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                                        .scaleEffect(0.7)
                                    Text("Sending...")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .transition(.opacity)
                        .id("sending")
                    }

                    // Typing indicator
                    if typingService.isOtherUserTyping {
                        TypingIndicator(userName: otherUser.fullName)
                            .transition(.opacity)
                            .id("typing")
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.immediately)
            .defaultScrollAnchor(.bottom) // Start at bottom (most recent messages) like phone messaging
            .background(Color(.systemGroupedBackground))
            .contentShape(Rectangle())
            .onTapGesture {
                // Dismiss keyboard when tapping in scroll view
                isInputFocused = false
            }
            .onChange(of: messageService.messages.count) { oldCount, newCount in
                // Only scroll to bottom for new messages (not when loading older)
                guard !messageService.isLoadingMore, newCount > oldCount else { return }

                // PERFORMANCE: Cancel pending scroll to avoid stacking
                pendingScrollTask?.cancel()

                if isInitialLoad {
                    // Initial load - defaultScrollAnchor handles positioning
                    // Just mark as loaded, no need to scroll since we start at bottom
                    // FIX: Defer state change to avoid "Modifying state during view update"
                    Task { @MainActor in
                        isInitialLoad = false
                    }
                } else {
                    // Subsequent messages - animate smoothly to bottom
                    // Use slight delay to allow layout to settle
                    pendingScrollTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms for layout
                        guard !Task.isCancelled else { return }
                        scrollToBottom(proxy: proxy, animated: !reduceMotion)
                    }
                }
            }
            .onChange(of: typingService.isOtherUserTyping) {
                if typingService.isOtherUserTyping {
                    withAnimation {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
            .onChange(of: isSending) {
                if isSending {
                    withAnimation {
                        proxy.scrollTo("sending", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Conversation Starters

    private func conversationStartersView(currentUser: User) -> some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Start the Conversation")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("Choose an icebreaker to send")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            .padding(.bottom, 8)

            // Conversation starters
            VStack(spacing: 12) {
                ForEach(ConversationStarters.shared.generateStarters(currentUser: currentUser, otherUser: otherUser)) { starter in
                    Button {
                        messageText = starter.text
                        HapticManager.shared.impact(.light)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: starter.icon)
                                .font(.title3)
                                .foregroundColor(.purple)
                                .frame(width: 32)

                            Text(starter.text)
                                .font(.body)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)

                            Spacer()

                            Image(systemName: "arrow.right.circle")
                                .font(.title3)
                                .foregroundColor(.purple.opacity(0.5))
                        }
                        .padding(16)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    /// Returns cached grouped messages - cache is updated via updateGroupedMessagesCache()
    /// NOTE: This function is called from body, so it must NOT modify @State (causes "Modifying state during view update")
    private func groupedMessages() -> [(String, [Message])] {
        // Return cache if available and valid
        if messageService.messages.count == lastMessageCount && !cachedGroupedMessages.isEmpty {
            return cachedGroupedMessages
        }
        // Cache miss - compute fresh (cache will be updated by onChange modifier)
        return computeGroupedMessages()
    }

    /// Computes grouped messages - pure function with no side effects
    private func computeGroupedMessages() -> [(String, [Message])] {
        let grouped = Dictionary(grouping: messageService.messages) { message -> String in
            if Self.calendar.isDateInToday(message.timestamp) {
                return "Today"
            } else if Self.calendar.isDateInYesterday(message.timestamp) {
                return "Yesterday"
            } else {
                return Self.dateFormatter.string(from: message.timestamp)
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

    /// Updates the grouped messages cache - call from onChange, not from body
    private func updateGroupedMessagesCache() {
        cachedGroupedMessages = computeGroupedMessages()
        lastMessageCount = messageService.messages.count
    }

    /// Returns the ID of the last read message from the current user
    /// This is used to only show "Read" indicator on the most recent read message
    private func lastReadMessageId() -> String? {
        guard let currentUserId = authService.currentUser?.effectiveId else { return nil }

        // Find all messages from current user that are read, then get the last one
        let currentUserReadMessages = messageService.messages.filter { message in
            (message.senderId == currentUserId || message.senderId == "current_user") && message.isRead
        }

        return currentUserReadMessages.last?.id
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        let scrollAction = {
            if typingService.isOtherUserTyping {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let lastMessage = messageService.messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }

        if animated {
            withAnimation {
                scrollAction()
            }
        } else {
            scrollAction()
        }
    }

    private func scrollToMessage(messageId: String) {
        // This needs to be called within a ScrollViewReader context
        // For now, we'll find and highlight the message
        Logger.shared.debug("Scroll to message: \(messageId)", category: .messaging)
    }
    
    // MARK: - Daily Message Limit Banner

    @ViewBuilder
    private var dailyMessageLimitBanner: some View {
        let remaining = RateLimiter.shared.getRemainingDailyMessages()
        let maxDaily = AppConstants.RateLimit.maxDailyMessagesForFreeUsers

        // Only show if they've used some messages
        if remaining < maxDaily {
            HStack(spacing: 8) {
                Image(systemName: remaining > 0 ? "bubble.left.and.bubble.right" : "lock.fill")
                    .font(.caption)
                    .foregroundColor(remaining > 0 ? .orange : .red)

                if remaining > 0 {
                    Text("\(remaining) daily message\(remaining == 1 ? "" : "s") left")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Daily limit reached")
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Spacer()

                Button {
                    showingPremiumUpgrade = true
                    HapticManager.shared.impact(.light)
                } label: {
                    Text("Unlimited")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(remaining > 0 ? Color.orange.opacity(0.1) : Color.red.opacity(0.1))
        }
    }

    // MARK: - Reply Preview Bar

    @ViewBuilder
    private func replyPreviewBar(message: Message) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.purple)
                .frame(width: 3)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 2) {
                Text("Replying to \(message.senderId == authService.currentUser?.effectiveId ? "yourself" : otherUser.fullName)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)

                if let imageURL = message.imageURL, !imageURL.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "photo")
                            .font(.caption2)
                        Text("Photo")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                } else {
                    Text(message.text)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                cancelReply()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Edit Message Sheet

    @ViewBuilder
    private var editMessageSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Edit Message")
                    .font(.headline)
                    .padding(.top)

                TextField("Message", text: $editText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                    .padding(.horizontal)

                HStack {
                    Text("\(editText.count)/\(AppConstants.Limits.maxMessageLength)")
                        .font(.caption)
                        .foregroundColor(editText.count > AppConstants.Limits.maxMessageLength - 50 ? .red : .secondary)
                    Spacer()
                }
                .padding(.horizontal)

                if let editingMessage = editingMessage, editingMessage.isEdited {
                    Text("This message has already been edited")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showEditSheet = false
                        editingMessage = nil
                        editText = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEditedMessage()
                    }
                    .disabled(editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Input Bar

    private var messageInputBar: some View {
        VStack(spacing: 8) {
            // Reply preview bar
            if showReplyBar, let replyMessage = replyingToMessage {
                replyPreviewBar(message: replyMessage)
            }

            // Image preview
            if let image = selectedImage {
                HStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    TextField("Add a caption...", text: $messageText, axis: .vertical)
                        .padding(.horizontal, 8)
                        .lineLimit(1...3)

                    Button {
                        selectedImage = nil
                        selectedImageItem = nil
                        messageText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Remove image")
                    .accessibilityHint("Cancel sending this image")
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            HStack(spacing: 12) {
                // Photo picker button
                PhotosPicker(selection: $selectedImageItem, matching: .images) {
                    Image(systemName: "photo.fill")
                        .font(.title3)
                        .foregroundColor(.purple)
                }
                .accessibilityLabel("Attach photo")
                .accessibilityHint("Select a photo to send")
                .onChange(of: selectedImageItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            selectedImage = uiImage
                        }
                    }
                }

                // Text input
                TextField("Message...", text: $messageText, axis: .vertical)
                    .focused($isInputFocused)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .lineLimit(1...5)
                    .dynamicTypeSize(min: .small, max: .accessibility2)
                    .accessibilityElement(
                        label: "Message",
                        hint: "Type your message to \(otherUser.fullName)",
                        identifier: AccessibilityIdentifier.messageInput
                    )
                    .onChange(of: messageText) { _, newValue in
                        // SAFETY: Enforce message character limit to prevent data overflow
                        if newValue.count > AppConstants.Limits.maxMessageLength {
                            messageText = String(newValue.prefix(AppConstants.Limits.maxMessageLength))
                        }

                        // Update typing indicator in Firestore
                        typingService.setTyping(!newValue.isEmpty)
                    }

                // Send button - simplified for performance
                Button {
                    sendMessage()
                } label: {
                    ZStack {
                        if isSending {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                        } else {
                            Image(systemName: (messageText.isEmpty && selectedImage == nil) ? "arrow.up.circle" : "arrow.up.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor((messageText.isEmpty && selectedImage == nil) ? .gray.opacity(0.5) : .purple)
                        }
                    }
                    .frame(width: 44, height: 44)
                }
                .disabled((messageText.isEmpty && selectedImage == nil) || isSending)
                .accessibilityElement(
                    label: isSending ? "Sending" : "Send message",
                    hint: isSending ? "Message is being sent" : "Send your message to \(otherUser.fullName)",
                    traits: .isButton,
                    identifier: AccessibilityIdentifier.sendButton
                )
            }

            // Character count (if over 100 characters)
            if messageText.count > 100 {
                HStack {
                    Spacer()
                    Text("\(messageText.count)/\(AppConstants.Limits.maxMessageLength)")
                        .font(.caption2)
                        .foregroundColor(messageText.count > AppConstants.Limits.maxMessageLength - 50 ? .red : .secondary)
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
        guard let currentUserId = authService.currentUser?.effectiveId else { return }
        guard let otherUserId = otherUser.effectiveId else { return }

        // BUGFIX: Only mark as loaded if messages are actually for THIS match
        // This prevents race condition where messages from a different chat cause
        // conversation starters to flash when opening a new chat
        // Check both the message matchId AND the service's active matchId for double validation
        let messagesAreForThisMatch = (messageService.messages.first?.matchId == matchId) ||
                                       (messageService.activeMatchId == matchId && !messageService.messages.isEmpty)
        // FIX: Defer state change to avoid "Modifying state during view update" warning
        Task { @MainActor in
            if messagesAreForThisMatch {
                hasLoadedMessagesForThisChat = true
            } else {
                // Reset the flag when switching to a different chat
                hasLoadedMessagesForThisChat = false
            }
        }

        messageService.listenToMessages(matchId: matchId)

        // Start listening to typing status
        typingService.startListening(
            matchId: matchId,
            currentUserId: currentUserId,
            otherUserId: otherUserId
        )

        // Mark messages as read
        Task {
            await messageService.markMessagesAsRead(matchId: matchId, userId: currentUserId)
        }
    }

    private func setupUserListener() {
        guard let otherUserId = otherUser.effectiveId else { return }

        // Listen to real-time updates for the other user's data (especially online status)
        let db = Firestore.firestore()
        userListener = db.collection("users").document(otherUserId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    Logger.shared.error("Error listening to user updates", category: .messaging, error: error)
                    return
                }

                guard let snapshot = snapshot, snapshot.exists else { return }

                do {
                    let updatedUser = try snapshot.data(as: User.self)
                    Task { @MainActor in
                        self.otherUserData = updatedUser
                    }
                } catch {
                    Logger.shared.error("Error decoding user update", category: .messaging, error: error)
                }
            }
    }

    private func cleanupUserListener() {
        userListener?.remove()
        typingService.stopListening()
    }

    private func sendMessage() {
        // Need either text or image
        let hasText = !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasImage = selectedImage != nil

        guard (hasText || hasImage) && !isSending else { return }

        guard let matchId = match.id else { return }
        guard let currentUserId = authService.currentUser?.effectiveId else { return }
        guard let receiverId = otherUser.effectiveId else { return }

        // Clear typing indicator immediately
        typingService.messageSent()

        // Check daily message limit for free users (10 messages/day total across ALL conversations)
        let isPremium = authService.currentUser?.isPremium ?? false
        if !isPremium {
            guard RateLimiter.shared.canSendDailyMessage() else {
                errorToastMessage = "Daily message limit reached (\(AppConstants.RateLimit.maxDailyMessagesForFreeUsers) messages). Upgrade to Premium for unlimited messaging!"
                showErrorToast = true
                HapticManager.shared.notification(.warning)
                return
            }
            // Record this message towards daily limit immediately (optimistic)
            RateLimiter.shared.recordDailyMessage()
        }

        // Check rate limit locally for immediate feedback (prevents spam)
        guard RateLimiter.shared.canSendMessage() else {
            errorToastMessage = "Slow down! You're sending messages too quickly."
            showErrorToast = true
            HapticManager.shared.notification(.warning)
            return
        }

        // NETWORK CHECK: Require connection for image uploads (text can use offline queue)
        if hasImage && !networkMonitor.isConnected {
            errorToastMessage = "No internet connection. Please check your WiFi or cellular data to send photos."
            showErrorToast = true
            HapticManager.shared.notification(.error)
            return
        }

        // PERFORMANCE: Capture and sanitize values BEFORE any state changes
        let text = InputSanitizer.standard(messageText)
        let imageToSend = selectedImage
        let replyMessage = replyingToMessage

        // PERFORMANCE: Clear input IMMEDIATELY for instant feedback
        // This makes the UI feel snappy - user sees their input cleared right away
        messageText = ""
        selectedImage = nil
        selectedImageItem = nil
        replyingToMessage = nil
        showReplyBar = false

        // Haptic feedback - instant response
        HapticManager.shared.impact(.light)

        // PERFORMANCE: Only set isSending for image messages (text uses optimistic UI)
        // This prevents the send button from showing loading spinner for text messages
        if hasImage {
            isSending = true
            sendingMessagePreview = hasText ? text : "📷 Photo"
            sendingImagePreview = imageToSend
        }

        // PERFORMANCE: Fire and forget for text messages - optimistic UI handles display
        // The message appears instantly in the list via MessageService's optimistic update
        Task.detached(priority: .userInitiated) {
            do {
                if let image = imageToSend {
                    // Upload image first (this is the slow part)
                    // Use PhotoUploadService for proper network check and logging
                    let imageURL = try await PhotoUploadService.shared.uploadPhoto(image, userId: matchId, imageType: .chat)

                    // Send image message (with optional caption)
                    try await MessageService.shared.sendImageMessage(
                        matchId: matchId,
                        senderId: currentUserId,
                        receiverId: receiverId,
                        imageURL: imageURL,
                        caption: text.isEmpty ? nil : text
                    )

                    // Clear image preview on success
                    await MainActor.run {
                        self.sendingMessagePreview = nil
                        self.sendingImagePreview = nil
                        self.isSending = false
                        HapticManager.shared.notification(.success)
                    }
                } else {
                    // PERFORMANCE: Text messages - optimistic UI shows instantly
                    if let reply = replyMessage, let replyId = reply.id {
                        // Send as a reply
                        let replyRef = MessageReply(
                            messageId: replyId,
                            senderId: reply.senderId,
                            senderName: reply.senderId == currentUserId ? "You" : self.otherUser.fullName,
                            text: reply.text,
                            imageURL: reply.imageURL
                        )
                        try await MessageService.shared.sendReplyMessage(
                            matchId: matchId,
                            senderId: currentUserId,
                            receiverId: receiverId,
                            text: text,
                            replyTo: replyRef
                        )
                    } else {
                        // Regular message
                        try await MessageService.shared.sendMessage(
                            matchId: matchId,
                            senderId: currentUserId,
                            receiverId: receiverId,
                            text: text
                        )
                    }
                    // No UI update needed - optimistic message already displayed
                }

            } catch {
                Logger.shared.error("Error sending message", category: .messaging, error: error)

                // Determine appropriate error message based on error type
                let errorMessage: String
                if let celestiaError = error as? CelestiaError {
                    switch celestiaError {
                    case .networkError, .noInternetConnection:
                        errorMessage = "No internet connection. Check your WiFi and tap retry."
                    case .timeout, .requestTimeout:
                        errorMessage = "Upload timed out. Check your connection and tap retry."
                    case .imageTooBig:
                        errorMessage = "Image is too large. Try a smaller photo."
                    case .imageUploadFailed:
                        errorMessage = "Failed to upload photo. Tap retry to try again."
                    default:
                        errorMessage = "Failed to send message. Tap retry to try again."
                    }
                } else if let photoError = error as? PhotoUploadError {
                    switch photoError {
                    case .noNetwork:
                        errorMessage = "No internet connection. Check your WiFi and tap retry."
                    case .wifiConnectedNoInternet:
                        errorMessage = "WiFi connected but no internet. Check your network and tap retry."
                    case .poorConnection:
                        errorMessage = "Weak connection. Move to better signal and tap retry."
                    case .uploadFailed(let reason):
                        errorMessage = "Upload failed: \(reason). Tap retry."
                    case .uploadTimeout:
                        errorMessage = "Upload timed out. Check your connection and tap retry."
                    }
                } else {
                    // Check for network-related NSError codes
                    let nsError = error as NSError
                    if nsError.domain == NSURLErrorDomain {
                        switch nsError.code {
                        case NSURLErrorNotConnectedToInternet:
                            errorMessage = "No internet connection. Check your WiFi and tap retry."
                        case NSURLErrorTimedOut:
                            errorMessage = "Upload timed out. Check your connection and tap retry."
                        case NSURLErrorNetworkConnectionLost:
                            errorMessage = "Connection lost. Check your WiFi and tap retry."
                        default:
                            errorMessage = "Network error. Check your connection and tap retry."
                        }
                    } else {
                        errorMessage = "Failed to send message. Tap retry to try again."
                    }
                }

                // Store failed message for retry and show error toast
                await MainActor.run {
                    self.sendingMessagePreview = nil
                    self.sendingImagePreview = nil
                    self.isSending = false
                    self.failedMessage = (text: text, image: imageToSend)
                    self.errorToastMessage = errorMessage
                    self.showErrorToast = true
                    HapticManager.shared.notification(.error)

                    // Hide toast after 5 seconds
                    Task {
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        self.showErrorToast = false
                    }
                }
            }
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
                    showingBlockConfirmation = true
                    HapticManager.shared.impact(.medium)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.raised.fill")
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

    // MARK: - Error Toast

    /// Error toast with retry button
    private var errorToastView: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.title3)
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text("Send Failed")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text(errorToastMessage)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
            }

            Spacer()

            // Retry button
            if failedMessage != nil {
                Button {
                    retryFailedMessage()
                } label: {
                    Text("Retry")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.3))
                        .cornerRadius(8)
                }
                .accessibilityLabel("Retry sending message")
            }

            // Dismiss button
            Button {
                showErrorToast = false
                failedMessage = nil
                HapticManager.shared.impact(.light)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(4)
            }
            .accessibilityLabel("Dismiss error")
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.red, Color.orange],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        .padding(.horizontal)
    }

    // MARK: - Reactions, Replies, and Editing

    /// Handle reaction on a message
    private func handleReaction(messageId: String, emoji: String) {
        guard let currentUserId = authService.currentUser?.effectiveId else { return }

        Task {
            do {
                try await messageService.toggleReaction(
                    messageId: messageId,
                    emoji: emoji,
                    userId: currentUserId
                )
                HapticManager.shared.impact(.light)
            } catch {
                Logger.shared.error("Failed to toggle reaction", category: .messaging, error: error)
                errorToastMessage = "Failed to add reaction"
                showErrorToast = true
            }
        }
    }

    /// Start replying to a message
    private func startReplyTo(message: Message) {
        replyingToMessage = message
        showReplyBar = true
        isInputFocused = true
        HapticManager.shared.impact(.light)
    }

    /// Cancel reply
    private func cancelReply() {
        replyingToMessage = nil
        showReplyBar = false
    }

    /// Start editing a message
    private func startEditing(message: Message) {
        editingMessage = message
        editText = message.text
        showEditSheet = true
        HapticManager.shared.impact(.light)
    }

    /// Save edited message
    private func saveEditedMessage() {
        guard let message = editingMessage,
              let messageId = message.id,
              let currentUserId = authService.currentUser?.effectiveId else {
            return
        }

        let newText = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newText.isEmpty else {
            errorToastMessage = "Message cannot be empty"
            showErrorToast = true
            return
        }

        Task {
            do {
                try await messageService.editMessage(
                    messageId: messageId,
                    newText: newText,
                    senderId: currentUserId
                )
                HapticManager.shared.notification(.success)
                showEditSheet = false
                editingMessage = nil
                editText = ""
            } catch let error as CelestiaError {
                Logger.shared.error("Failed to edit message", category: .messaging, error: error)
                errorToastMessage = error.errorDescription ?? "Failed to edit message"
                showErrorToast = true
            } catch {
                Logger.shared.error("Failed to edit message", category: .messaging, error: error)
                errorToastMessage = "Failed to edit message"
                showErrorToast = true
            }
        }
    }

    /// Retry sending failed message
    private func retryFailedMessage() {
        guard let failed = failedMessage else { return }
        guard let matchId = match.id else { return }
        guard let currentUserId = authService.currentUser?.effectiveId else { return }
        guard let receiverId = otherUser.effectiveId else { return }

        // Hide error toast and set sending preview
        showErrorToast = false
        failedMessage = nil
        sendingMessagePreview = failed.text.isEmpty ? "📷 Photo" : failed.text
        sendingImagePreview = failed.image

        // Haptic feedback
        HapticManager.shared.impact(.light)

        isSending = true

        Task {
            do {
                if let image = failed.image {
                    // Upload image first - use PhotoUploadService for proper network check
                    let imageURL = try await PhotoUploadService.shared.uploadPhoto(image, userId: matchId, imageType: .chat)

                    // Send image message (with optional caption)
                    try await messageService.sendImageMessage(
                        matchId: matchId,
                        senderId: currentUserId,
                        receiverId: receiverId,
                        imageURL: imageURL,
                        caption: failed.text.isEmpty ? nil : failed.text
                    )
                } else {
                    // Send text-only message
                    try await messageService.sendMessage(
                        matchId: matchId,
                        senderId: currentUserId,
                        receiverId: receiverId,
                        text: failed.text
                    )
                }
                HapticManager.shared.notification(.success)

                // Clear sending preview on success
                await MainActor.run {
                    sendingMessagePreview = nil
                    sendingImagePreview = nil
                }
            } catch {
                Logger.shared.error("Error retrying message", category: .messaging, error: error)
                HapticManager.shared.notification(.error)

                // Show error again
                await MainActor.run {
                    sendingMessagePreview = nil
                    sendingImagePreview = nil
                    failedMessage = failed
                    errorToastMessage = "Failed to send message. Check your connection."
                    showErrorToast = true

                    // Hide toast after 5 seconds
                    Task {
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        showErrorToast = false
                    }
                }
            }
            isSending = false
        }
    }

    /// Block the user and dismiss the chat
    private func blockUser() {
        guard let userId = otherUser.effectiveId,
              let currentUserId = authService.currentUser?.effectiveId else { return }

        HapticManager.shared.notification(.warning)

        Task {
            do {
                try await BlockReportService.shared.blockUser(
                    userId: userId,
                    currentUserId: currentUserId
                )
                HapticManager.shared.notification(.success)
                dismiss()
            } catch {
                Logger.shared.error("Error blocking user", category: .moderation, error: error)
                errorToastMessage = "Failed to block user. Please try again."
                showErrorToast = true
                HapticManager.shared.notification(.error)
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
