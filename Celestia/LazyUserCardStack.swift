//
//  LazyUserCardStack.swift
//  Celestia
//
//  Lazy loading card stack with windowed rendering and image preloading
//  Significantly improves performance by only rendering visible cards
//

import SwiftUI

/// Lazy-loaded card stack with windowed rendering for optimal performance
struct LazyUserCardStack: View {
    let users: [User]
    let currentIndex: Int
    let dragOffset: CGSize
    let onTap: (User) -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: (DragGesture.Value) -> Void

    // Performance optimization: Only render visible cards + next 2
    private let visibleCardCount = 3
    private let preloadImageCount = 2

    @State private var preloadedImages: Set<String> = []

    var body: some View {
        ZStack {
            ForEach(visibleCards, id: \.index) { cardData in
                let cardIndex = cardData.index - currentIndex

                UserCardView(user: cardData.user)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 200) // Space for buttons and tab bar
                    .offset(y: CGFloat(cardIndex * 8))
                    .scaleEffect(1.0 - CGFloat(cardIndex) * 0.05)
                    .opacity(1.0 - Double(cardIndex) * 0.2)
                    .zIndex(Double(visibleCardCount - cardIndex))
                    .offset(cardIndex == 0 ? dragOffset : .zero)
                    .rotationEffect(.degrees(cardIndex == 0 ? Double(dragOffset.width / 20) : 0))
                    .contentShape(Rectangle())
                    .accessibilityLabel(cardIndex == 0 ? "\(cardData.user.fullName), \(cardData.user.age) years old" : "")
                    .accessibilityHint(cardIndex == 0 ? "Swipe right to like, left to pass, or tap for full profile" : "")
                    .onTapGesture {
                        if cardIndex == 0 {
                            onTap(cardData.user)
                        }
                    }
                    .gesture(
                        cardIndex == 0 ? DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                onDragChanged(value)
                            }
                            .onEnded { value in
                                onDragEnded(value)
                            } : nil
                    )
            }
        }
        .onChange(of: currentIndex) { newIndex in
            // Preload images for next cards when index changes
            Task {
                await preloadUpcomingImages(from: newIndex)
            }
        }
        .task {
            // Initial image preloading
            await preloadUpcomingImages(from: currentIndex)
        }
    }

    // MARK: - Computed Properties

    /// Get only the visible cards for rendering (windowed rendering)
    private var visibleCards: [(index: Int, user: User)] {
        users.enumerated()
            .filter { $0.offset >= currentIndex && $0.offset < currentIndex + visibleCardCount }
            .map { (index: $0.offset, user: $0.element) }
    }

    /// Get upcoming cards for preloading
    private var upcomingCards: [User] {
        let start = currentIndex
        let end = min(currentIndex + preloadImageCount, users.count)
        guard start < users.count, start < end else { return [] }
        return Array(users[start..<end])
    }

    // MARK: - Image Preloading

    /// Preload images for upcoming cards
    private func preloadUpcomingImages(from index: Int) async {
        let cardsToPreload = users.enumerated()
            .filter { $0.offset >= index && $0.offset < index + preloadImageCount }
            .map { $0.element }

        guard !cardsToPreload.isEmpty else { return }

        let imageURLs = cardsToPreload.compactMap { user -> String? in
            guard !user.profileImageURL.isEmpty,
                  !preloadedImages.contains(user.profileImageURL) else {
                return nil
            }
            return user.profileImageURL
        }

        guard !imageURLs.isEmpty else { return }

        // Use PerformanceMonitor for image preloading
        await PerformanceMonitor.shared.preloadImages(imageURLs)

        // Track preloaded images to avoid duplicate work
        await MainActor.run {
            preloadedImages.formUnion(imageURLs)
        }

        Logger.shared.debug("Preloaded \(imageURLs.count) images for cards at index \(index)", category: .performance)
    }
}

// MARK: - Card Data Structure

struct CardData: Identifiable {
    let id: String
    let index: Int
    let user: User
}

// MARK: - Preview

#Preview {
    LazyUserCardStack(
        users: [
            User(
                email: "test1@example.com",
                fullName: "Sofia Rodriguez",
                age: 25,
                gender: "Female",
                lookingFor: "Male",
                bio: "Love to travel and explore new cultures.",
                location: "Barcelona",
                country: "Spain",
                languages: ["Spanish", "English"],
                interests: ["Travel", "Photography"],
                profileImageURL: ""
            ),
            User(
                email: "test2@example.com",
                fullName: "Emma Thompson",
                age: 28,
                gender: "Female",
                lookingFor: "Male",
                bio: "Artist and coffee enthusiast.",
                location: "London",
                country: "UK",
                languages: ["English"],
                interests: ["Art", "Coffee"],
                profileImageURL: ""
            ),
            User(
                email: "test3@example.com",
                fullName: "Maria Garcia",
                age: 26,
                gender: "Female",
                lookingFor: "Male",
                bio: "Dancer and music lover.",
                location: "Madrid",
                country: "Spain",
                languages: ["Spanish", "English"],
                interests: ["Dancing", "Music"],
                profileImageURL: ""
            )
        ],
        currentIndex: 0,
        dragOffset: .zero,
        onTap: { _ in },
        onDragChanged: { _ in },
        onDragEnded: { _ in }
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
