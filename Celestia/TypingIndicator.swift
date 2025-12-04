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
    @State private var dotScale: CGFloat = 1.0

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // User avatar circle with enhanced styling
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.85),
                                Color.pink.opacity(0.75),
                                Color.purple.opacity(0.65)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .shadow(color: Color.purple.opacity(0.3), radius: 4, y: 2)

                Text(userName.prefix(1))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.95)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            // Typing bubble with animated gradient dots
            HStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.purple.opacity(0.7),
                                    Color.pink.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 9, height: 9)
                        .scaleEffect(dotScale)
                        .offset(y: animationOffset)
                        .animation(
                            Animation.easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.15),
                            value: animationOffset
                        )
                        .animation(
                            Animation.easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.15),
                            value: dotScale
                        )
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.systemGray6))
                    .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
            )

            Spacer()
        }
        .padding(.horizontal)
        .onAppear {
            animationOffset = -5
            dotScale = 0.85
        }
    }
}

// Alternative minimal typing indicator with enhanced styling
struct TypingIndicatorMinimal: View {
    @State private var animationOffset: CGFloat = 0
    @State private var dotOpacity: Double = 1.0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.6),
                                Color.pink.opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 7, height: 7)
                    .opacity(dotOpacity)
                    .offset(y: animationOffset)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: animationOffset
                    )
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: dotOpacity
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGray6))
                .shadow(color: .black.opacity(0.03), radius: 3, y: 1)
        )
        .onAppear {
            animationOffset = -4
            dotOpacity = 0.6
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
