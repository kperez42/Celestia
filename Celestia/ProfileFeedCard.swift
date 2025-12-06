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
    // BUGFIX: Changed to completion-based callbacks to prevent rapid-tap issues
    // The completion(success) is called when the async operation finishes
    let onLike: (@escaping (Bool) -> Void) -> Void
    let onUnlike: (@escaping (Bool) -> Void) -> Void
    let onFavorite: () -> Void
    let onMessage: () -> Void
    let onViewPhotos: () -> Void
    let onViewProfile: () -> Void  // NEW: Callback to view full profile with interests

    @State private var isFavorited = false
    @State private var isLiked = false
    @State private var isProcessingLike = false
    @State private var isProcessingSave = false
    @State private var showFullScreenPhoto = false
    @State private var selectedPhotoIndex = 0

    // MARK: - Computed Properties

    // Get all available photos for the user
    private var allPhotos: [String] {
        let photos = user.photos.filter { !$0.isEmpty }
        if photos.isEmpty && !user.profileImageURL.isEmpty {
            return [user.profileImageURL]
        }
        return photos
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
        ZStack(alignment: .bottom) {
            HighQualityCardImage(
                url: URL(string: displayPhotoURL),
                targetHeight: Self.cardImageHeight,
                cornerRadius: 0,  // We apply corner radius to specific corners below
                priority: .high  // High priority for better quality
            )
            .frame(height: Self.cardImageHeight)
            .frame(maxWidth: .infinity)

            // Subtle gradient overlay for depth and visual appeal
            LinearGradient(
                colors: [
                    Color.black.opacity(0),
                    Color.black.opacity(0.02),
                    Color.black.opacity(0.08),
                    Color.black.opacity(0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: Self.cardImageHeight * 0.4)

            // Photo count indicator if multiple photos
            if allPhotos.count > 1 {
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "photo.stack.fill")
                            .font(.caption2)
                        Text("\(allPhotos.count)")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(12)
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(height: Self.cardImageHeight)
        .clipShape(
            RoundedCorner(radius: 16, corners: [.topLeft, .topRight])
        )
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.impact(.medium)
            selectedPhotoIndex = 0
            showFullScreenPhoto = true
        }
        .fullScreenCover(isPresented: $showFullScreenPhoto) {
            CardFullScreenPhotoViewer(
                photos: allPhotos,
                selectedIndex: $selectedPhotoIndex,
                isPresented: $showFullScreenPhoto,
                userName: user.fullName,
                onViewProfile: onViewProfile
            )
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
                        let previousState = isLiked
                        isLiked = false  // Optimistic update
                        onUnlike { success in
                            // BUGFIX: Only reset processing after async operation completes
                            isProcessingLike = false
                            if !success {
                                // Revert optimistic update on failure
                                isLiked = previousState
                            }
                        }
                    } else {
                        // Like
                        let previousState = isLiked
                        isLiked = true  // Optimistic update
                        onLike { success in
                            // BUGFIX: Only reset processing after async operation completes
                            isProcessingLike = false
                            if !success {
                                // Revert optimistic update on failure
                                isLiked = previousState
                            }
                        }
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

// MARK: - Card Full Screen Photo Viewer

struct CardFullScreenPhotoViewer: View {
    let photos: [String]
    @Binding var selectedIndex: Int
    @Binding var isPresented: Bool
    let userName: String
    let onViewProfile: () -> Void

    @State private var dismissDragOffset: CGFloat = 0
    @State private var isDismissing = false

    private let dismissThreshold: CGFloat = 150

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Black background with opacity based on drag
                Color.black
                    .opacity(backgroundOpacity)
                    .ignoresSafeArea()

                // Photo carousel with smooth swiping
                TabView(selection: $selectedIndex) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, photoURL in
                        FullScreenPhotoItem(
                            url: URL(string: photoURL),
                            isCurrentPhoto: index == selectedIndex
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .offset(y: dismissDragOffset)
                .scaleEffect(dismissScale)
                .onChange(of: selectedIndex) { _, newIndex in
                    ImageCache.shared.prefetchAdjacentPhotos(photos: photos, currentIndex: newIndex)
                }

                // Top controls overlay
                VStack {
                    HStack {
                        // Close button
                        Button {
                            HapticManager.shared.impact(.light)
                            isPresented = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
                        }

                        Spacer()

                        // Photo counter
                        if photos.count > 1 {
                            Text("\(selectedIndex + 1) / \(photos.count)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(20)
                                .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)

                    Spacer()

                    // Bottom user info and view profile button
                    VStack(spacing: 16) {
                        Text(userName)
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 4, y: 2)

                        Button {
                            HapticManager.shared.impact(.medium)
                            isPresented = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onViewProfile()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "person.circle.fill")
                                    .font(.body)
                                Text("View Profile")
                                    .font(.body.weight(.semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(25)
                            .shadow(color: .purple.opacity(0.4), radius: 10, y: 4)
                        }
                    }
                    .padding(.bottom, 50)
                }
                .opacity(controlsOpacity)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dismissDragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > dismissThreshold {
                            isDismissing = true
                            HapticManager.shared.impact(.light)
                            withAnimation(.easeOut(duration: 0.2)) {
                                dismissDragOffset = geometry.size.height
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                isPresented = false
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dismissDragOffset = 0
                            }
                        }
                    }
            )
        }
        .statusBarHidden()
        .onAppear {
            ImageCache.shared.prefetchAdjacentPhotos(photos: photos, currentIndex: selectedIndex)
        }
    }

    private var backgroundOpacity: Double {
        let progress = min(dismissDragOffset / dismissThreshold, 1.0)
        return 1.0 - (progress * 0.5)
    }

    private var dismissScale: CGFloat {
        let progress = min(dismissDragOffset / dismissThreshold, 1.0)
        return 1.0 - (progress * 0.1)
    }

    private var controlsOpacity: Double {
        let progress = min(dismissDragOffset / dismissThreshold, 1.0)
        return 1.0 - progress
    }
}

// MARK: - Full Screen Photo Item

struct FullScreenPhotoItem: View {
    let url: URL?
    let isCurrentPhoto: Bool

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black

                CachedCardImage(url: url, priority: isCurrentPhoto ? .immediate : .high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(scale)
                    .offset(offset)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale = min(max(scale * delta, 1), 4)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                if scale < 1 {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        scale = 1
                                        offset = .zero
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        scale > 1 ?
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                        : nil
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            if scale > 1 {
                                scale = 1
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2
                            }
                        }
                        HapticManager.shared.impact(.light)
                    }
            }
        }
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
            onLike: { completion in completion(true) },
            onUnlike: { completion in completion(true) },
            onFavorite: {},
            onMessage: {},
            onViewPhotos: {},
            onViewProfile: {}
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
