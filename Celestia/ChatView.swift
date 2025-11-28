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
    @State private var isOtherUserTyping = false
    @State private var showingUnmatchConfirmation = false
    @State private var showingUserProfile = false
    @State private var showingReportSheet = false
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
    @State private var cachedGroupedMessages: [(String, [Message])] = []
    @State private var lastMessageCount = 0

    // Track initial load to prevent scroll animation on first load
    @State private var isInitialLoad = true

    // Reusable date formatter for performance
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()

    private static let calendar = Calendar.current

    @Environment(\.dismiss) var dismiss

    // Initialize with the passed otherUser data
    init(match: Match, otherUser: User) {
        self.match = match
        self.otherUser = otherUser
        self._otherUserData = State(initialValue: otherUser)
    }

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
        .accessibilityIdentifier(AccessibilityIdentifier.chatView)
        .onAppear {
            setupChat()
            setupUserListener()
            VoiceOverAnnouncement.screenChanged(to: "Chat with \(otherUser.fullName)")
        }
        .onDisappear {
            messageService.stopListening()
            cleanupUserListener()
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
            context: ScreenshotDetectionService.ScreenshotContext.chat(
                matchId: match.id ?? "",
                otherUserId: otherUser.id ?? ""
            ),
            userName: otherUser.fullName
        )
        .sheet(isPresented: $showingUserProfile) {
            UserDetailView(user: otherUser)
        }
        .sheet(isPresented: $showingReportSheet) {
            ReportUserView(user: otherUser)
        }
        .onChange(of: messageService.messages.count) { oldCount, newCount in
            // SWIFTUI FIX: Defer safety check with longer delay to avoid modifying state during view update
            // Only check if message count actually increased (not on initial load or deletions)
            guard newCount > oldCount else { return }
            Task {
                // Longer delay ensures view update cycle completes
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
                checkConversationSafety()
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

                    // Show conversation starters if no messages
                    if messageService.messages.isEmpty, let currentUser = authService.currentUser {
                        if messageService.isLoading {
                            // Show loading state
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                Text("Loading messages...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 100)
                        } else {
                            conversationStartersView(currentUser: currentUser)
                        }
                    }

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
                    if isOtherUserTyping {
                        TypingIndicator(userName: otherUser.fullName)
                            .transition(.opacity)
                            .id("typing")
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.immediately)
            .background(Color(.systemGroupedBackground))
            .contentShape(Rectangle())
            .onTapGesture {
                // Dismiss keyboard when tapping in scroll view
                isInputFocused = false
            }
            .onChange(of: messageService.messages.count) {
                // Only scroll to bottom for new messages (not when loading older)
                if !messageService.isLoadingMore {
                    // PERFORMANCE: Don't animate scroll on initial load - just jump to bottom
                    let shouldAnimate = !isInitialLoad
                    scrollToBottom(proxy: proxy, animated: shouldAnimate)

                    // Mark initial load as complete after first scroll
                    if isInitialLoad {
                        isInitialLoad = false
                    }
                }
            }
            .onChange(of: isOtherUserTyping) {
                if isOtherUserTyping {
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

    private func groupedMessages() -> [(String, [Message])] {
        // Use cache if messages haven't changed
        if messageService.messages.count == lastMessageCount && !cachedGroupedMessages.isEmpty {
            return cachedGroupedMessages
        }

        // Recalculate and cache
        let grouped = Dictionary(grouping: messageService.messages) { message -> String in
            if Self.calendar.isDateInToday(message.timestamp) {
                return "Today"
            } else if Self.calendar.isDateInYesterday(message.timestamp) {
                return "Yesterday"
            } else {
                return Self.dateFormatter.string(from: message.timestamp)
            }
        }

        let sorted = grouped.sorted { first, second in
            // Sort by the date of the first message in each group
            if let firstMessage = first.value.first, let secondMessage = second.value.first {
                return firstMessage.timestamp < secondMessage.timestamp
            }
            return false
        }

        // Update cache
        cachedGroupedMessages = sorted
        lastMessageCount = messageService.messages.count

        return sorted
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        let scrollAction = {
            if isOtherUserTyping {
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
    
    // MARK: - Input Bar

    private var messageInputBar: some View {
        VStack(spacing: 8) {
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
                            Image(systemName: (messageText.isEmpty && selectedImage == nil) ? "arrow.up.circle" : "arrow.up.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(
                                    (messageText.isEmpty && selectedImage == nil) ?
                                    LinearGradient(colors: [.gray.opacity(0.5)], startPoint: .leading, endPoint: .trailing) :
                                    LinearGradient.brandPrimary
                                )
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

        messageService.listenToMessages(matchId: matchId)

        // Mark messages as read
        if let userId = authService.currentUser?.id {
            Task {
                await messageService.markMessagesAsRead(matchId: matchId, userId: userId)
            }
        }
    }

    private func setupUserListener() {
        guard let otherUserId = otherUser.id else { return }

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
    }

    private func sendMessage() {
        // Need either text or image
        let hasText = !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasImage = selectedImage != nil

        guard (hasText || hasImage) && !isSending else { return }

        guard let matchId = match.id else { return }
        guard let currentUserId = authService.currentUser?.id else { return }
        guard let receiverId = otherUser.id else { return }

        // Check rate limit locally for immediate feedback
        guard RateLimiter.shared.canSendMessage() else {
            errorToastMessage = "Slow down! You're sending messages too quickly."
            showErrorToast = true
            HapticManager.shared.notification(.warning)
            return
        }

        // Haptic feedback - instant response
        HapticManager.shared.impact(.light)

        // BUGFIX: Set isSending immediately to prevent double-send from rapid taps
        // Previous bug: isSending was only set for images, allowing double-tap for text
        isSending = true

        // Capture and sanitize values before clearing
        let text = InputSanitizer.standard(messageText)
        let imageToSend = selectedImage

        // PERFORMANCE: Clear input immediately for snappy UX
        // Message appears instantly via optimistic UI in MessageService
        messageText = ""
        selectedImage = nil
        selectedImageItem = nil
        isInputFocused = false

        // Track sending state for UI preview (images show preview while uploading)
        if hasImage {
            sendingMessagePreview = hasText ? text : "📷 Photo"
            sendingImagePreview = imageToSend
        }

        Task {
            do {
                if let image = imageToSend {
                    // Upload image first (this is the slow part)
                    let imageURL = try await ImageUploadService.shared.uploadChatImage(image, matchId: matchId)

                    // Send image message (with optional caption)
                    try await messageService.sendImageMessage(
                        matchId: matchId,
                        senderId: currentUserId,
                        receiverId: receiverId,
                        imageURL: imageURL,
                        caption: text.isEmpty ? nil : text
                    )

                    // Clear image preview on success
                    await MainActor.run {
                        sendingMessagePreview = nil
                        sendingImagePreview = nil
                        isSending = false
                    }
                } else {
                    // PERFORMANCE: Text messages use optimistic UI
                    // The message appears instantly in the list
                    try await messageService.sendMessage(
                        matchId: matchId,
                        senderId: currentUserId,
                        receiverId: receiverId,
                        text: text
                    )
                }

                // BUGFIX: Reset isSending for both text and image messages
                await MainActor.run {
                    isSending = false
                }

                // Success haptic only for image messages (text is already shown)
                if hasImage {
                    HapticManager.shared.notification(.success)
                }

            } catch {
                Logger.shared.error("Error sending message", category: .messaging, error: error)
                HapticManager.shared.notification(.error)

                // Store failed message for retry and show error toast
                await MainActor.run {
                    sendingMessagePreview = nil
                    sendingImagePreview = nil
                    isSending = false
                    failedMessage = (text: text, image: imageToSend)
                    errorToastMessage = "Failed to send message. Tap retry to try again."
                    showErrorToast = true

                    // Hide toast after 5 seconds
                    Task {
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        showErrorToast = false
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

    /// Retry sending failed message
    private func retryFailedMessage() {
        guard let failed = failedMessage else { return }
        guard let matchId = match.id else { return }
        guard let currentUserId = authService.currentUser?.id else { return }
        guard let receiverId = otherUser.id else { return }

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
                    // Upload image first
                    let imageURL = try await ImageUploadService.shared.uploadChatImage(image, matchId: matchId)

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
