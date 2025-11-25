//
//  ProfileFeedCard.swift
//  Celestia
//
//  Feed-style profile card for vertical scrolling discovery
//

import SwiftUI

struct ProfileFeedCard: View {
    let user: User
    let currentUser: User?  // NEW: For calculating shared interests
    let initialIsFavorited: Bool
    let onLike: () -> Void
    let onFavorite: () -> Void
    let onMessage: () -> Void
    let onViewPhotos: () -> Void
    let onViewProfile: () -> Void  // NEW: Callback to view full profile with interests

    @State private var isFavorited = false
    @State private var isLiked = false
    @State private var isProcessingLike = false
    @State private var isProcessingSave = false

    // MARK: - Computed Properties

    // Calculate shared interests with current user
    private var sharedInterests: [String] {
        guard let currentUser = currentUser else { return [] }
        let userInterests = Set(user.interests)
        let myInterests = Set(currentUser.interests)
        return Array(userInterests.intersection(myInterests)).sorted()
    }

    // Get the best available photo URL (photos array first, then profileImageURL)
    private var displayPhotoURL: String {
        if let firstPhoto = user.photos.first, !firstPhoto.isEmpty {
            return firstPhoto
        }
        return user.profileImageURL
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Profile Image
            profileImage

            // User Details (tappable to view full profile)
            VStack(alignment: .leading, spacing: 8) {
                // Name and Verification
                nameRow

                // Age and Location
                locationRow

                // Seeking preferences
                seekingRow

                // Last active
                lastActiveRow
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                HapticManager.shared.impact(.light)
                onViewProfile()
            }

            // Shared Interests (if any)
            if !sharedInterests.isEmpty {
                sharedInterestsView
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            // Action Buttons
            actionButtons
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .onAppear {
            isFavorited = initialIsFavorited
        }
        .onChange(of: initialIsFavorited) { newValue in
            // Update when parent changes favorites set (e.g., unsaved from another view)
            if !isProcessingSave {
                isFavorited = newValue
            }
        }
    }

    // MARK: - Components

    private var profileImage: some View {
        CachedCardImage(url: URL(string: displayPhotoURL))
            .frame(height: 400)
            .clipped()
            .cornerRadius(16, corners: [.topLeft, .topRight])
            .onTapGesture {
                HapticManager.shared.impact(.medium)
                onViewProfile()
            }
    }

    private var nameRow: some View {
        HStack(spacing: 8) {
            Text(user.fullName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            if user.isVerified {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
            }

            Spacer()
        }
    }

    private var locationRow: some View {
        HStack(spacing: 4) {
            Text("\(user.age)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("•")
                .foregroundColor(.secondary)

            Image(systemName: "mappin.circle.fill")
                .font(.caption)
                .foregroundColor(.purple)

            Text("\(user.location), \(user.country)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)

            Spacer()
        }
    }

    private var seekingRow: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.2.fill")
                .font(.caption)
                .foregroundColor(.pink)

            Text("Seeking \(user.lookingFor), \(user.ageRangeMin)-\(user.ageRangeMax)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
    }

    private var lastActiveRow: some View {
        HStack(spacing: 4) {
            // Consider user active if they're online OR were active in the last 5 minutes
            let interval = Date().timeIntervalSince(user.lastActive)
            let isActive = user.isOnline || interval < 300

            if isActive {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)

                Text(user.isOnline ? "Online" : "Active now")
                    .font(.caption)
                    .foregroundColor(.green)
                    .fontWeight(.medium)
            } else {
                Image(systemName: "clock.fill")
                    .font(.caption)
                    .foregroundColor(.gray)

                Text("Active \(formatLastActive(user.lastActive))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private var sharedInterestsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("You both like")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Spacer()
            }

            // Interest tags
            FlowLayoutImproved(spacing: 8) {
                ForEach(Array(sharedInterests.prefix(3)), id: \.self) { interest in
                    HStack(spacing: 6) {
                        Text(getInterestEmoji(interest))
                            .font(.caption)

                        Text(interest)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [.purple.opacity(0.15), .pink.opacity(0.15)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.purple)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [.purple.opacity(0.3), .pink.opacity(0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    )
                }

                // Show count if more than 3
                if sharedInterests.count > 3 {
                    Text("+\(sharedInterests.count - 3) more")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.1))
                        .foregroundColor(.purple)
                        .cornerRadius(12)
                }
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.05), Color.pink.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Like/Heart button
            ActionButton(
                icon: isLiked ? "heart.fill" : "heart",
                color: .pink,
                label: "Like",
                isProcessing: isProcessingLike,
                action: {
                    guard !isProcessingLike else { return }
                    HapticManager.shared.impact(.medium)
                    isProcessingLike = true
                    isLiked = true  // Optimistic update
                    onLike()
                    // Reset processing state after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isProcessingLike = false
                    }
                }
            )

            // Favorite button with enhanced feedback
            ActionButton(
                icon: isFavorited ? "star.fill" : "star",
                color: .orange,
                label: isFavorited ? "Saved" : "Save",
                isProcessing: isProcessingSave,
                action: {
                    guard !isProcessingSave else { return }
                    // Enhanced haptic feedback for save action
                    if !isFavorited {
                        HapticManager.shared.notification(.success)
                    } else {
                        HapticManager.shared.impact(.light)
                    }
                    isProcessingSave = true
                    isFavorited.toggle()
                    onFavorite()
                    // Reset processing state after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isProcessingSave = false
                    }
                }
            )

            // Message button
            ActionButton(
                icon: "message.fill",
                color: .blue,
                label: "Message",
                isProcessing: false,
                action: {
                    HapticManager.shared.impact(.medium)
                    onMessage()
                }
            )

            // View photos button
            ActionButton(
                icon: "camera.fill",
                color: .purple,
                label: "Photos",
                isProcessing: false,
                action: {
                    HapticManager.shared.impact(.light)
                    onViewPhotos()
                }
            )
        }
    }

    // MARK: - Helper Functions

    private func formatLastActive(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else if interval < 2592000 {
            let weeks = Int(interval / 604800)
            return "\(weeks)w ago"
        } else {
            let months = Int(interval / 2592000)
            return "\(months)mo ago"
        }
    }

    private func getInterestEmoji(_ interest: String) -> String {
        let lowercased = interest.lowercased()

        // Map common interests to emojis
        switch lowercased {
        // Arts & Entertainment
        case let str where str.contains("art"): return "🎨"
        case let str where str.contains("music"): return "🎵"
        case let str where str.contains("movie") || str.contains("film"): return "🎬"
        case let str where str.contains("read") || str.contains("book"): return "📚"
        case let str where str.contains("photo"): return "📸"
        case let str where str.contains("dance"): return "💃"
        case let str where str.contains("theater") || str.contains("theatre"): return "🎭"

        // Food & Drink
        case let str where str.contains("coffee"): return "☕"
        case let str where str.contains("cook"): return "🍳"
        case let str where str.contains("wine"): return "🍷"
        case let str where str.contains("food"): return "🍕"
        case let str where str.contains("baking"): return "🧁"

        // Sports & Fitness
        case let str where str.contains("yoga"): return "🧘"
        case let str where str.contains("gym") || str.contains("fitness"): return "💪"
        case let str where str.contains("run"): return "🏃"
        case let str where str.contains("swim"): return "🏊"
        case let str where str.contains("hik"): return "🥾"
        case let str where str.contains("bike") || str.contains("cycl"): return "🚴"
        case let str where str.contains("soccer") || str.contains("football"): return "⚽"
        case let str where str.contains("basketball"): return "🏀"
        case let str where str.contains("tennis"): return "🎾"

        // Travel & Outdoors
        case let str where str.contains("travel"): return "✈️"
        case let str where str.contains("beach"): return "🏖️"
        case let str where str.contains("camp"): return "🏕️"
        case let str where str.contains("nature"): return "🌲"
        case let str where str.contains("adventure"): return "🧗"

        // Technology & Gaming
        case let str where str.contains("gaming") || str.contains("video game"): return "🎮"
        case let str where str.contains("tech"): return "💻"
        case let str where str.contains("coding") || str.contains("programming"): return "👨‍💻"

        // Animals & Pets
        case let str where str.contains("dog"): return "🐕"
        case let str where str.contains("cat"): return "🐱"
        case let str where str.contains("pet"): return "🐾"

        // Other
        case let str where str.contains("fashion"): return "👗"
        case let str where str.contains("meditation"): return "🧘‍♀️"
        case let str where str.contains("gardening"): return "🌱"
        case let str where str.contains("volunteer"): return "🤝"

        default: return "✨" // Default sparkle emoji
        }
    }
}

// MARK: - Action Button Component

struct ActionButton: View {
    let icon: String
    let color: Color
    let label: String
    let isProcessing: Bool
    let action: () -> Void

    @State private var isAnimating = false

    var body: some View {
        Button(action: {
            action()
            // Trigger scale animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                isAnimating = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    isAnimating = false
                }
            }
        }) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(color.opacity(isProcessing ? 0.25 : (label == "Saved" ? 0.25 : 0.15)))
                        .frame(width: 56, height: 56)

                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: color))
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: icon)
                            .font(.title3)
                            .fontWeight(label == "Saved" ? .semibold : .regular)
                            .foregroundColor(color)
                    }
                }
                .scaleEffect(isAnimating ? 1.15 : 1.0)

                Text(label)
                    .font(.caption2)
                    .fontWeight(label == "Saved" ? .semibold : .regular)
                    .foregroundColor(label == "Saved" ? color : (isProcessing ? color.opacity(0.6) : .secondary))
            }
        }
        .disabled(isProcessing)
        .opacity(isProcessing ? 0.7 : 1.0)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Profile Feed Card Skeleton

struct ProfileFeedCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Profile Image skeleton
            SkeletonView()
                .frame(height: 400)
                .clipped()
                .cornerRadius(16, corners: [.topLeft, .topRight])

            // User Details skeleton
            VStack(alignment: .leading, spacing: 8) {
                // Name row skeleton
                HStack(spacing: 8) {
                    SkeletonView()
                        .frame(width: 160, height: 28)
                        .cornerRadius(6)

                    Spacer()
                }

                // Location row skeleton
                HStack(spacing: 4) {
                    SkeletonView()
                        .frame(width: 40, height: 16)
                        .cornerRadius(6)

                    SkeletonView()
                        .frame(width: 180, height: 16)
                        .cornerRadius(6)

                    Spacer()
                }

                // Seeking row skeleton
                SkeletonView()
                    .frame(width: 220, height: 16)
                    .cornerRadius(6)

                // Last active skeleton
                SkeletonView()
                    .frame(width: 100, height: 14)
                    .cornerRadius(6)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Action Buttons skeleton
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(spacing: 6) {
                        SkeletonView()
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())

                        SkeletonView()
                            .frame(width: 40, height: 12)
                            .cornerRadius(4)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }
}

#Preview {
    ScrollView {
        ProfileFeedCard(
            user: User(
                email: "test@test.com",
                fullName: "Sarah Johnson",
                age: 28,
                gender: "Female",
                lookingFor: "Men",
                bio: "Love hiking and coffee",
                location: "Los Angeles",
                country: "USA",
                interests: ["Coffee", "Hiking", "Music", "Art", "Photography"],
                ageRangeMin: 25,
                ageRangeMax: 35
            ),
            currentUser: User(
                email: "me@test.com",
                fullName: "John Doe",
                age: 30,
                gender: "Male",
                lookingFor: "Women",
                bio: "Tech enthusiast",
                location: "Los Angeles",
                country: "USA",
                interests: ["Coffee", "Music", "Technology", "Hiking"],  // 3 shared: Coffee, Music, Hiking
                ageRangeMin: 25,
                ageRangeMax: 35
            ),
            initialIsFavorited: false,
            onLike: {},
            onFavorite: {},
            onMessage: {},
            onViewPhotos: {},
            onViewProfile: {}
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
