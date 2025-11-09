//
//  TypingIndicator.swift
//  Celestia
//
//  Typing indicator animation for chat
//

import SwiftUI

struct TypingIndicator: View {
    let userName: String

    @State private var animationOffset: CGFloat = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // User avatar circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.7), Color.pink.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
                .overlay(
                    Text(userName.prefix(1))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                )

            // Typing bubble with animated dots
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.gray.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .offset(y: animationOffset)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: animationOffset
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray5))
            .cornerRadius(16)

            Spacer()
        }
        .padding(.horizontal)
        .onAppear {
            animationOffset = -4
        }
    }
}

// Alternative minimal typing indicator
struct TypingIndicatorMinimal: View {
    @State private var animationOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 6, height: 6)
                    .offset(y: animationOffset)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: animationOffset
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            animationOffset = -3
        }
    }
}

#Preview("Typing Indicator") {
    VStack(spacing: 20) {
        TypingIndicator(userName: "Sarah")

        Divider()

        HStack {
            TypingIndicatorMinimal()
            Spacer()
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
