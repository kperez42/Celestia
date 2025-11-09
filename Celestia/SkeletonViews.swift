//
//  SkeletonViews.swift
//  Celestia
//
//  Created by Claude
//  Reusable skeleton loading components for better UX
//

import SwiftUI

// MARK: - Skeleton Base

struct SkeletonView: View {
    @State private var isAnimating = false

    var body: some View {
        LinearGradient(
            colors: [
                Color.gray.opacity(0.2),
                Color.gray.opacity(0.3),
                Color.gray.opacity(0.2)
            ],
            startPoint: isAnimating ? .leading : .trailing,
            endPoint: isAnimating ? .trailing : .leading
        )
        .onAppear {
            withAnimation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Card Skeleton

struct CardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image area
            SkeletonView()
                .frame(height: 450)
                .cornerRadius(20, corners: [.topLeft, .topRight])

            // Info area
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    SkeletonView()
                        .frame(width: 150, height: 30)
                        .cornerRadius(8)

                    SkeletonView()
                        .frame(width: 40, height: 30)
                        .cornerRadius(8)
                }

                SkeletonView()
                    .frame(width: 200, height: 20)
                    .cornerRadius(6)

                SkeletonView()
                    .frame(width: 280, height: 16)
                    .cornerRadius(6)
            }
            .padding(20)
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 10)
    }
}

// MARK: - Match List Skeleton

struct MatchListItemSkeleton: View {
    var body: some View {
        HStack(spacing: 16) {
            // Profile image
            SkeletonView()
                .frame(width: 60, height: 60)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 8) {
                SkeletonView()
                    .frame(width: 120, height: 18)
                    .cornerRadius(6)

                SkeletonView()
                    .frame(width: 180, height: 14)
                    .cornerRadius(6)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                SkeletonView()
                    .frame(width: 50, height: 14)
                    .cornerRadius(6)

                SkeletonView()
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

struct MatchListSkeleton: View {
    var count: Int = 5

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { _ in
                MatchListItemSkeleton()
                Divider()
            }
        }
    }
}

// MARK: - Message Skeleton

struct MessageBubbleSkeleton: View {
    let isFromCurrentUser: Bool

    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer()
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 6) {
                SkeletonView()
                    .frame(width: CGFloat.random(in: 150...250), height: 16)
                    .cornerRadius(6)

                SkeletonView()
                    .frame(width: 60, height: 12)
                    .cornerRadius(4)
            }

            if !isFromCurrentUser {
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

struct ChatSkeleton: View {
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<8, id: \.self) { index in
                MessageBubbleSkeleton(isFromCurrentUser: index % 3 == 0)
            }
        }
        .padding(.vertical)
    }
}

// MARK: - Profile Skeleton

struct ProfileHeaderSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            // Images carousel
            SkeletonView()
                .frame(height: 500)

            VStack(alignment: .leading, spacing: 16) {
                // Name and age
                HStack(spacing: 12) {
                    SkeletonView()
                        .frame(width: 180, height: 32)
                        .cornerRadius(8)

                    SkeletonView()
                        .frame(width: 50, height: 32)
                        .cornerRadius(8)
                }

                // Location
                SkeletonView()
                    .frame(width: 200, height: 18)
                    .cornerRadius(6)

                Divider()

                // Bio
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonView()
                        .frame(width: 100, height: 20)
                        .cornerRadius(6)

                    SkeletonView()
                        .frame(height: 16)
                        .cornerRadius(6)

                    SkeletonView()
                        .frame(height: 16)
                        .cornerRadius(6)

                    SkeletonView()
                        .frame(width: 250, height: 16)
                        .cornerRadius(6)
                }

                Divider()

                // Interests
                VStack(alignment: .leading, spacing: 12) {
                    SkeletonView()
                        .frame(width: 100, height: 20)
                        .cornerRadius(6)

                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonView()
                                .frame(width: CGFloat.random(in: 80...120), height: 36)
                                .cornerRadius(18)
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Grid Skeleton

struct GridItemSkeleton: View {
    var body: some View {
        SkeletonView()
            .aspectRatio(1, contentMode: .fill)
            .cornerRadius(12)
    }
}

struct GridSkeleton: View {
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<9, id: \.self) { _ in
                GridItemSkeleton()
            }
        }
        .padding()
    }
}

// MARK: - Match Card Skeleton

struct MatchCardSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            // Profile image skeleton
            SkeletonView()
                .frame(height: 220)

            // User info section
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    SkeletonView()
                        .frame(width: 80, height: 18)
                        .cornerRadius(6)

                    SkeletonView()
                        .frame(width: 30, height: 18)
                        .cornerRadius(6)

                    Spacer()
                }

                SkeletonView()
                    .frame(width: 120, height: 14)
                    .cornerRadius(6)

                SkeletonView()
                    .frame(width: 90, height: 24)
                    .cornerRadius(12)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

// MARK: - Conversation Row Skeleton

struct ConversationRowSkeleton: View {
    var body: some View {
        HStack(spacing: 16) {
            // Profile image
            SkeletonView()
                .frame(width: 70, height: 70)
                .clipShape(Circle())

            // Message content
            VStack(alignment: .leading, spacing: 8) {
                // Name and time
                HStack {
                    SkeletonView()
                        .frame(width: 140, height: 18)
                        .cornerRadius(6)

                    Spacer()

                    SkeletonView()
                        .frame(width: 40, height: 14)
                        .cornerRadius(6)
                }

                // Message preview
                SkeletonView()
                    .frame(height: 16)
                    .cornerRadius(6)

                SkeletonView()
                    .frame(width: 180, height: 16)
                    .cornerRadius(6)
            }
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

// MARK: - Preview

#Preview("Card Skeleton") {
    CardSkeleton()
        .padding()
}

#Preview("Match List Skeleton") {
    MatchListSkeleton()
}

#Preview("Chat Skeleton") {
    ChatSkeleton()
}

#Preview("Profile Skeleton") {
    ScrollView {
        ProfileHeaderSkeleton()
    }
}
