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
    let initialIsLiked: Bool
    let onLike: () -> Void
    let onUnlike: () -> Void
    let onFavorite: () -> Void
    let onMessage: () -> Void
    let onViewPhotos: () -> Void
    let onViewProfile: () -> Void  // NEW: Callback to view full profile with interests

    @State private var isFavorited = false
    @State private var isLiked = false
    @State private var isProcessingLike = false
    @State private var isProcessingSave = false

    // MARK: - Computed Properties

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

            // Action Buttons
            actionButtons
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        // PERFORMANCE: GPU acceleration for smooth scrolling
        .compositingGroup()
        .onAppear {
            isFavorited = initialIsFavorited
            isLiked = initialIsLiked
        }
        .onChange(of: initialIsFavorited) { newValue in
            // Update when parent changes favorites set (e.g., unsaved from another view)
            if !isProcessingSave {
                isFavorited = newValue
            }
        }
        .onChange(of: initialIsLiked) { newValue in
            // Update when parent changes likes set (e.g., unliked from another view)
            if !isProcessingLike {
                isLiked = newValue
            }
        }
    }

    // MARK: - Constants

    /// Fixed card image height for consistent card sizing regardless of image dimensions
    private static let cardImageHeight: CGFloat = 400

    // MARK: - Components

    private var profileImage: some View {
        // Use HighQualityCardImage for consistent sizing and high-quality rendering
        // The fixed height ensures cards don't expand based on image aspect ratios
        HighQualityCardImage(
            url: URL(string: displayPhotoURL),
            targetHeight: Self.cardImageHeight,
            cornerRadius: 0,  // We apply corner radius to specific corners below
            priority: .normal
        )
        .frame(height: Self.cardImageHeight)
        .frame(maxWidth: .infinity)
        .clipShape(
            RoundedCorner(radius: 16, corners: [.topLeft, .topRight])
        )
        .contentShape(Rectangle())
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

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Like/Heart button (toggle)
            ActionButton(
                icon: isLiked ? "heart.fill" : "heart",
                color: .pink,
                label: isLiked ? "Liked" : "Like",
                isProcessing: isProcessingLike,
                action: {
                    guard !isProcessingLike else { return }
                    HapticManager.shared.impact(.medium)
                    isProcessingLike = true

                    if isLiked {
                        // Unlike
                        isLiked = false  // Optimistic update
                        onUnlike()
                    } else {
                        // Like
                        isLiked = true  // Optimistic update
                        onLike()
                    }

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
}

// MARK: - Action Button Component

struct ActionButton: View {
    let icon: String
    let color: Color
    let label: String
    let isProcessing: Bool
    let action: () -> Void

    @State private var isAnimating = false
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            action()
            // PERFORMANCE: Snappy bounce animation
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5, blendDuration: 0)) {
                isAnimating = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    isAnimating = false
                }
            }
        }) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(color.opacity(isProcessing ? 0.25 : (isPressed || label == "Saved" ? 0.25 : 0.15)))
                        .frame(width: 56, height: 56)
                        .scaleEffect(isAnimating ? 1.2 : (isPressed ? 0.95 : 1.0))

                    // Show icon always (no loading spinner to avoid UIKit rendering issues)
                    Image(systemName: icon)
                        .font(.title3)
                        .fontWeight(label == "Saved" ? .bold : .medium)
                        .foregroundColor(color)
                        .scaleEffect(isAnimating ? 1.3 : 1.0)
                        .opacity(isProcessing ? 0.5 : 1.0)
                }

                Text(label)
                    .font(.caption2)
                    .fontWeight(label == "Saved" ? .semibold : .medium)
                    .foregroundColor(label == "Saved" ? color : (isProcessing ? color.opacity(0.6) : .secondary))
            }
        }
        .buttonStyle(ResponsiveButtonStyle(isPressed: $isPressed))
        .disabled(isProcessing)
        .opacity(isProcessing ? 0.7 : 1.0)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Responsive Button Style

/// Custom button style for immediate visual feedback
struct ResponsiveButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { newValue in
                isPressed = newValue
            }
    }
}

// MARK: - Profile Feed Card Skeleton

struct ProfileFeedCardSkeleton: View {
    /// Match the card image height from ProfileFeedCard for consistent sizing
    private static let cardImageHeight: CGFloat = 400

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Profile Image skeleton - uses same fixed height as ProfileFeedCard
            SkeletonView()
                .frame(height: Self.cardImageHeight)
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
            initialIsLiked: false,
            onLike: {},
            onUnlike: {},
            onFavorite: {},
            onMessage: {},
            onViewPhotos: {},
            onViewProfile: {}
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
