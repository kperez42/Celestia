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
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Message content
                if let imageURL = message.imageURL, !imageURL.isEmpty {
                    // Image message
                    AsyncImage(url: URL(string: imageURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: 200, maxHeight: 200)
                                .cornerRadius(12)
                        case .failure(_):
                            Text("📷 Image")
                                .padding(12)
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(16)
                        case .empty:
                            ProgressView()
                                .frame(width: 200, height: 200)
                        @unknown default:
                            EmptyView()
                        }
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

// Gradient version with ViewBuilder pattern
struct MessageBubbleGradient: View {
    let message: Message
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Message text
                Text(message.text)
                    .padding(12)
                    .background {
                        bubbleBackground
                    }
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .cornerRadius(16)
                
                // Timestamp with read indicators
                HStack(spacing: 4) {
                    Text(message.timestamp.timeAgoDisplay())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
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
    func timeAgoDisplay() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day, .weekOfYear], from: self, to: now)
        
        if let week = components.weekOfYear, week > 0 {
            return week == 1 ? "1 week ago" : "\(week) weeks ago"
        } else if let day = components.day, day > 0 {
            return day == 1 ? "1 day ago" : "\(day) days ago"
        } else if let hour = components.hour, hour > 0 {
            return hour == 1 ? "1 hour ago" : "\(hour) hours ago"
        } else if let minute = components.minute, minute > 0 {
            return minute == 1 ? "1 min ago" : "\(minute) mins ago"
        } else {
            return "Just now"
        }
    }
    
    /// Format as "3:45 PM"
    func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    /// Format as "Today", "Yesterday", or "Dec 4"
    func formattedDate() -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(self) {
            return "Today"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: self)
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
