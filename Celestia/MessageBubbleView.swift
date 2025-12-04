//
//  MessageBubbleView.swift
//  Celestia
//
//  Shared message bubble component for chat views
//

import SwiftUI

struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool

    @State private var showFullScreenImage = false

    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Message content
                if let imageURL = message.imageURL, !imageURL.isEmpty {
                    // Image message - using cached image for better scroll performance
                    // Fixed dimensions prevent layout shifts during load
                    CachedAsyncImage(url: URL(string: imageURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 200, height: 200)
                            .cornerRadius(12)
                    } placeholder: {
                        // Placeholder matches loaded image size to prevent layout shifts
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: 200, height: 200)
                            .overlay(
                                ProgressView()
                            )
                    }
                    .onTapGesture {
                        showFullScreenImage = true
                        HapticManager.shared.impact(.light)
                    }
                    .fullScreenCover(isPresented: $showFullScreenImage) {
                        FullScreenMessageImageViewer(imageURL: imageURL, isPresented: $showFullScreenImage)
                    }
                } else {
                    // Text message
                    Text(message.text)
                        .padding(12)
                        .background {
                            if isFromCurrentUser {
                                LinearGradient(
                                    colors: [Color.purple, Color.pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            } else {
                                Color(.systemGray5)
                            }
                        }
                        .foregroundColor(isFromCurrentUser ? .white : .primary)
                        .cornerRadius(16)
                }
                
                // Timestamp
                HStack(spacing: 4) {
                    Text(message.timestamp.timeAgoDisplay())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    // Read/delivered indicators for sent messages
                    if isFromCurrentUser {
                        if message.isRead {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        } else if message.isDelivered {
                            Image(systemName: "checkmark.circle")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
}

// Alternative simple version without gradients
struct MessageBubbleSimple: View {
    let message: Message
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(12)
                    .background(isFromCurrentUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .cornerRadius(16)
                
                Text(message.timestamp.timeAgoDisplay())
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
}

// Gradient version with ViewBuilder pattern - Enhanced with reactions, editing, and replies
struct MessageBubbleGradient: View {
    let message: Message
    let isFromCurrentUser: Bool
    var currentUserId: String? = nil
    var showReadStatus: Bool = true // Only show read indicator on the most recent read message
    var onReaction: ((String) -> Void)? = nil
    var onReply: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onTapReplyPreview: ((String) -> Void)? = nil

    @State private var showReactionPicker = false
    @State private var showContextMenu = false
    @State private var showFullScreenImage = false

    // Common reaction emojis
    private let quickReactions = ["❤️", "😂", "😮", "😢", "👍", "🔥"]

    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Reply preview if this message is a reply
                if let replyTo = message.replyTo {
                    replyPreviewView(replyTo: replyTo)
                }

                // Message content (image or text)
                VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 0) {
                    if let imageURL = message.imageURL, !imageURL.isEmpty {
                        // Image message - using cached image for better scroll performance
                        // Fixed dimensions prevent layout shifts during load
                        CachedAsyncImage(url: URL(string: imageURL)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 250, height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                        } placeholder: {
                            // Placeholder matches loaded image size to prevent layout shifts
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 250, height: 200)
                                .overlay(
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                                )
                        }
                        .onTapGesture {
                            showFullScreenImage = true
                            HapticManager.shared.impact(.light)
                        }
                        .fullScreenCover(isPresented: $showFullScreenImage) {
                            FullScreenMessageImageViewer(imageURL: imageURL, isPresented: $showFullScreenImage)
                        }

                        // Caption if text exists
                        if !message.text.isEmpty && message.text != "📷 Photo" {
                            Text(message.text)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .foregroundColor(isFromCurrentUser ? .white : .primary)
                                .background {
                                    if isFromCurrentUser {
                                        LinearGradient(
                                            colors: [Color.purple.opacity(0.9), Color.pink.opacity(0.9)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    } else {
                                        Color(.systemGray5)
                                    }
                                }
                                .cornerRadius(12)
                        }
                    } else {
                        // Text message
                        Text(message.text)
                            .padding(12)
                            .background {
                                bubbleBackground
                            }
                            .foregroundColor(isFromCurrentUser ? .white : .primary)
                            .cornerRadius(16)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    // Single tap does nothing, handled by context menu
                }
                .onLongPressGesture {
                    showReactionPicker = true
                    HapticManager.shared.impact(.medium)
                }
                .contextMenu {
                    messageContextMenu
                }

                // Reactions display
                if message.hasReactions {
                    reactionsView
                }

                // Timestamp with read/edited indicators
                HStack(spacing: 4) {
                    Text(message.timestamp.timeAgoDisplay())
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    // Edited indicator
                    if message.isEdited {
                        Text("(edited)")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                    }

                    if isFromCurrentUser {
                        // Only show "Read" on the most recent read message (controlled by showReadStatus)
                        if message.isRead && showReadStatus {
                            HStack(spacing: 2) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.blue)

                                Text("Read")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        } else if message.isDelivered || message.isRead {
                            // Show delivered checkmark for delivered messages or read messages that shouldn't show "Read"
                            Image(systemName: "checkmark.circle")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Image(systemName: "clock")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                    }
                }
            }

            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
        .sheet(isPresented: $showReactionPicker) {
            reactionPickerSheet
                .presentationDetents([.height(120)])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Reply Preview

    @ViewBuilder
    private func replyPreviewView(replyTo: MessageReply) -> some View {
        Button {
            onTapReplyPreview?(replyTo.messageId)
        } label: {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(isFromCurrentUser ? Color.white.opacity(0.5) : Color.purple.opacity(0.5))
                    .frame(width: 3)
                    .cornerRadius(2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(replyTo.senderName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(isFromCurrentUser ? .white.opacity(0.9) : .purple)

                    if let imageURL = replyTo.imageURL, !imageURL.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "photo")
                                .font(.caption2)
                            Text("Photo")
                                .font(.caption)
                        }
                        .foregroundColor(isFromCurrentUser ? .white.opacity(0.7) : .secondary)
                    } else {
                        Text(replyTo.text)
                            .font(.caption)
                            .foregroundColor(isFromCurrentUser ? .white.opacity(0.7) : .secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(8)
            .background(isFromCurrentUser ? Color.white.opacity(0.15) : Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reactions View

    @ViewBuilder
    private var reactionsView: some View {
        HStack(spacing: 4) {
            ForEach(message.uniqueReactionEmojis, id: \.self) { emoji in
                let count = message.reactionCount(for: emoji)
                let hasUserReacted = currentUserId.map { message.hasUserReacted(userId: $0, emoji: emoji) } ?? false

                Button {
                    onReaction?(emoji)
                } label: {
                    HStack(spacing: 2) {
                        Text(emoji)
                            .font(.system(size: 12))
                        if count > 1 {
                            Text("\(count)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(hasUserReacted ? Color.purple.opacity(0.2) : Color.gray.opacity(0.15))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(hasUserReacted ? Color.purple.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var messageContextMenu: some View {
        // Reply button
        Button {
            onReply?()
        } label: {
            Label("Reply", systemImage: "arrowshape.turn.up.left")
        }

        // Quick reactions
        Menu {
            ForEach(quickReactions, id: \.self) { emoji in
                Button {
                    onReaction?(emoji)
                } label: {
                    Text(emoji)
                }
            }
        } label: {
            Label("React", systemImage: "face.smiling")
        }

        // Edit button (only for own messages within 15 min)
        if isFromCurrentUser, canEditMessage {
            Button {
                onEdit?()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }

        Divider()

        // Copy text
        Button {
            UIPasteboard.general.string = message.text
            HapticManager.shared.notification(.success)
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
    }

    // MARK: - Reaction Picker Sheet

    @ViewBuilder
    private var reactionPickerSheet: some View {
        VStack(spacing: 16) {
            Text("Add Reaction")
                .font(.headline)

            HStack(spacing: 20) {
                ForEach(quickReactions, id: \.self) { emoji in
                    Button {
                        onReaction?(emoji)
                        showReactionPicker = false
                        HapticManager.shared.impact(.light)
                    } label: {
                        Text(emoji)
                            .font(.system(size: 32))
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private var canEditMessage: Bool {
        let minutesSinceSent = Date().timeIntervalSince(message.timestamp) / 60
        return minutesSinceSent <= 15
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if isFromCurrentUser {
            LinearGradient(
                colors: [Color.purple, Color.pink],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            Color(.systemGray5)
        }
    }
}

// MARK: - Date Extension

extension Date {
    // PERFORMANCE: Cache DateFormatters - creating them is expensive
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private static let calendar = Calendar.current

    /// Format as "3:45 PM"
    func formattedTime() -> String {
        Self.timeFormatter.string(from: self)
    }

    /// Format as "Today", "Yesterday", or "Dec 4"
    func formattedDate() -> String {
        if Self.calendar.isDateInToday(self) {
            return "Today"
        } else if Self.calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else {
            return Self.dateFormatter.string(from: self)
        }
    }
}

// MARK: - Preview

#Preview("Message Bubbles") {
    VStack(spacing: 16) {
        // Received message
        MessageBubble(
            message: Message(
                matchId: "test",
                senderId: "other",
                receiverId: "me",
                text: "Hey! How are you?",
                timestamp: Date().addingTimeInterval(-3600)
            ),
            isFromCurrentUser: false
        )
        
        // Sent message (read)
        MessageBubble(
            message: Message(
                matchId: "test",
                senderId: "me",
                receiverId: "other",
                text: "I'm great! Thanks for asking 😊",
                timestamp: Date().addingTimeInterval(-1800),
                isRead: true,
                isDelivered: true
            ),
            isFromCurrentUser: true
        )
        
        // Sent message (delivered but not read)
        MessageBubble(
            message: Message(
                matchId: "test",
                senderId: "me",
                receiverId: "other",
                text: "What have you been up to?",
                timestamp: Date().addingTimeInterval(-60),
                isRead: false,
                isDelivered: true
            ),
            isFromCurrentUser: true
        )
        
        // Very recent message
        MessageBubble(
            message: Message(
                matchId: "test",
                senderId: "other",
                receiverId: "me",
                text: "Just finished a great book!",
                timestamp: Date()
            ),
            isFromCurrentUser: false
        )
    }
    .padding()
}

#Preview("Gradient Style") {
    ScrollView {
        VStack(spacing: 16) {
            MessageBubbleGradient(
                message: Message(
                    matchId: "test",
                    senderId: "other",
                    receiverId: "me",
                    text: "Hey! Want to grab coffee?",
                    timestamp: Date().addingTimeInterval(-7200)
                ),
                isFromCurrentUser: false
            )
            
            MessageBubbleGradient(
                message: Message(
                    matchId: "test",
                    senderId: "me",
                    receiverId: "other",
                    text: "That sounds great! When are you free?",
                    timestamp: Date().addingTimeInterval(-3600),
                    isRead: true,
                    isDelivered: true
                ),
                isFromCurrentUser: true
            )
            
            MessageBubbleGradient(
                message: Message(
                    matchId: "test",
                    senderId: "other",
                    receiverId: "me",
                    text: "How about tomorrow at 3pm?",
                    timestamp: Date().addingTimeInterval(-1800)
                ),
                isFromCurrentUser: false
            )
            
            MessageBubbleGradient(
                message: Message(
                    matchId: "test",
                    senderId: "me",
                    receiverId: "other",
                    text: "Perfect! See you there! 😊",
                    timestamp: Date().addingTimeInterval(-60),
                    isRead: false,
                    isDelivered: true
                ),
                isFromCurrentUser: true
            )
        }
        .padding()
    }
}

// MARK: - Full Screen Message Image Viewer

struct FullScreenMessageImageViewer: View {
    let imageURL: String
    @Binding var isPresented: Bool

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var dismissDragOffset: CGFloat = 0

    private let dismissThreshold: CGFloat = 150

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Black background with opacity based on drag
                Color.black
                    .opacity(max(0.0, 1.0 - Double(dismissDragOffset) / 300.0))
                    .ignoresSafeArea()

                // Zoomable image
                CachedAsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(y: dismissDragOffset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let newScale = lastScale * value
                                    scale = min(max(newScale, 1.0), 4.0)
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    if scale < 1.0 {
                                        withAnimation(.spring()) {
                                            scale = 1.0
                                            lastScale = 1.0
                                        }
                                    }
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    // Only allow vertical drag for dismiss when not zoomed
                                    if scale <= 1.0 && value.translation.height > 0 {
                                        dismissDragOffset = value.translation.height
                                    }
                                }
                                .onEnded { value in
                                    if value.translation.height > dismissThreshold {
                                        HapticManager.shared.impact(.light)
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            dismissDragOffset = geometry.size.height
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            isPresented = false
                                        }
                                    } else {
                                        withAnimation(.spring()) {
                                            dismissDragOffset = 0
                                        }
                                    }
                                }
                        )
                        .onTapGesture(count: 2) {
                            // Double tap to zoom in/out
                            withAnimation(.spring()) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    lastScale = 1.0
                                } else {
                                    scale = 2.0
                                    lastScale = 2.0
                                }
                            }
                        }
                } placeholder: {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }

                // Close button
                VStack {
                    HStack {
                        Button {
                            HapticManager.shared.impact(.light)
                            isPresented = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)

                    Spacer()

                    // Hint text
                    Text("Pinch to zoom • Swipe down to close")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.bottom, 40)
                }
                .opacity(max(0.0, 1.0 - Double(dismissDragOffset) / 150.0))
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
    }
}
