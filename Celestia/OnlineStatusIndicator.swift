//
//  OnlineStatusIndicator.swift
//  Celestia
//
//  Reusable online status indicator component
//  Shows real-time online status with elegant animations
//

import SwiftUI

struct OnlineStatusIndicator: View {
    let user: User
    @Environment(\.colorScheme) var colorScheme

    private var isOnline: Bool {
        user.isOnline
    }

    // User is considered "active" if they're online OR were active in the last 5 minutes
    private var isActive: Bool {
        if isOnline {
            return true
        }
        let interval = Date().timeIntervalSince(user.lastActive)
        return interval < 300 // Less than 5 minutes
    }

    private var statusText: String {
        if isOnline {
            return "Online"
        } else {
            return timeAgoText
        }
    }

    private var timeAgoText: String {
        let interval = Date().timeIntervalSince(user.lastActive)

        if interval < 300 { // Less than 5 minutes
            return "Active now"
        } else if interval < 3600 { // Less than 1 hour
            let minutes = Int(interval / 60)
            return "Active \(minutes)m ago"
        } else if interval < 86400 { // Less than 24 hours
            let hours = Int(interval / 3600)
            return "Active \(hours)h ago"
        } else if interval < 604800 { // Less than 7 days
            let days = Int(interval / 86400)
            return "Active \(days)d ago"
        } else {
            return "Recently active"
        }
    }

    private var statusColor: Color {
        isActive ? Color.green : Color.gray
    }

    var body: some View {
        HStack(spacing: 6) {
            // Pulsing dot for active users
            ZStack {
                // Outer pulsing ring (only for active users)
                if isActive {
                    Circle()
                        .fill(statusColor.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .scaleEffect(1.5)
                        .opacity(0.8)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                            value: isActive
                        )
                }

                // Inner solid dot
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
            .frame(width: 12, height: 12)

            // Status text
            Text(statusText)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            statusColor.opacity(0.3),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(user.fullName) is \(statusText)")
    }
}
