//
//  DiscoverView.swift
//  Celestia
//
//  ACCESSIBILITY: Full VoiceOver support, Dynamic Type, Reduce Motion, and WCAG 2.1 AA compliant
//

import SwiftUI

struct SwipeAction {
    let user: User
    let index: Int
    let wasLike: Bool
}

struct DiscoverView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = DiscoverViewModel()
    @ObservedObject private var filters = DiscoveryFilters.shared
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color.purple.opacity(0.1), Color.pink.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Main content
                    if viewModel.isLoading {
                        // Skeleton loading state
                        ZStack {
                            ForEach(0..<3, id: \.self) { index in
                                CardSkeleton()
                                    .padding(.horizontal, 16)
                                    .padding(.top, 16)
                                    .padding(.bottom, 200)
                                    .offset(y: CGFloat(index * 8))
                                    .scaleEffect(1.0 - CGFloat(index) * 0.05)
                                    .opacity(1.0 - Double(index) * 0.2)
                                    .zIndex(Double(3 - index))
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if !viewModel.errorMessage.isEmpty {
                        errorStateView
                    } else if viewModel.users.isEmpty || viewModel.currentIndex >= viewModel.users.count {
                        emptyStateView
                    } else {
                        cardStackView
                    }
                }
                
                // Match animation
                if viewModel.showingMatchAnimation {
                    matchCelebrationView
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .accessibilityIdentifier(AccessibilityIdentifier.discoverView)
            .task {
                await viewModel.loadUsers()
                VoiceOverAnnouncement.screenChanged(to: "Discover view. \(viewModel.users.count) potential matches available.")
            }
            .refreshable {
                HapticManager.shared.impact(.light)
                await viewModel.loadUsers()
                HapticManager.shared.notification(.success)
                VoiceOverAnnouncement.announce("Profiles refreshed. \(viewModel.users.count) profiles available.")
            }
            .sheet(isPresented: $viewModel.showingUserDetail) {
                if let user = viewModel.selectedUser {
                    UserDetailView(user: user)
                        .environmentObject(authService)
                }
            }
            .sheet(isPresented: $viewModel.showingFilters) {
                DiscoverFiltersView()
            }
            .sheet(isPresented: $viewModel.showingUpgradeSheet) {
                PremiumUpgradeView(contextMessage: viewModel.upgradeReason.message)
                    .environmentObject(authService)
            }
            .onChange(of: filters.hasActiveFilters) { _, _ in
                viewModel.applyFilters()
            }
        }
        .networkStatusBanner() // UX: Show offline status
        .overlay(alignment: .top) {
            // Error toast for action failures
            if viewModel.showActionError {
                actionErrorToast
                    .padding(.top, 100)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(999)
            }
        }
        .animation(.spring(response: 0.3), value: viewModel.showActionError)
    }

    // MARK: - Action Error Toast

    private var actionErrorToast: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.title3)
                .foregroundColor(.white)

            Text(viewModel.actionErrorMessage)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)

            Spacer()

            Button {
                viewModel.showActionError = false
                HapticManager.shared.impact(.light)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.9))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Discover")
                    .font(.system(size: 36, weight: .bold))
                    .dynamicTypeSize(min: .large, max: .accessibility2)
                    .accessibilityAddTraits(.isHeader)

                if !viewModel.users.isEmpty {
                    HStack(spacing: 4) {
                        Text("\(viewModel.remainingCount) people")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .dynamicTypeSize(min: .xSmall, max: .accessibility1)

                        if viewModel.hasActiveFilters {
                            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                    }
                }
            }

            Spacer()

            // Shuffle button
            Button {
                viewModel.shuffleUsers()
                HapticManager.shared.impact(.light)
                VoiceOverAnnouncement.announce("Profiles shuffled")
            } label: {
                Image(systemName: "shuffle")
                    .font(.title3)
                    .foregroundColor(.purple)
                    .frame(width: 44, height: 44)
            }
            .accessibilityElement(
                label: "Shuffle users",
                hint: "Randomly reorder the list of potential matches",
                traits: .isButton,
                identifier: AccessibilityIdentifier.shuffleButton
            )
            .padding(.trailing, 8)

            // Filter button
            Button {
                viewModel.showFilters()
                HapticManager.shared.impact(.light)
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.title2)
                        .foregroundColor(.purple)

                    if viewModel.hasActiveFilters {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: 44, height: 44)
            }
            .accessibilityElement(
                label: viewModel.hasActiveFilters ? "Filters active" : "Filters",
                hint: "Show discovery filters to refine your matches",
                traits: .isButton,
                identifier: AccessibilityIdentifier.filterButton,
                value: viewModel.hasActiveFilters ? "Active" : "Inactive"
            )
        }
        .padding()
        .background(Color.white)
    }
    
    // MARK: - Card Stack

    private var cardStackView: some View {
        ZStack {
            // Card stack layer (lower z-index)
            ZStack {
                // PERFORMANCE FIX: Use pre-computed visibleUsers instead of filtering in view body
                // Old: O(n) enumerated().filter() on every render
                // New: O(1) direct access to visible users
                ForEach(viewModel.visibleUsers, id: \.index) { item in
                    let cardIndex = item.index - viewModel.currentIndex
                    let user = item.user

                    cardView(for: user, at: cardIndex)
                }
            }
            .zIndex(0)

            // Action buttons overlay - Separate layer with higher z-index
            VStack {
                Spacer()

                // Button container with explicit hit testing
                HStack(spacing: 24) {
                    // Pass button
                    SwipeActionButton(
                        icon: "xmark",
                        iconSize: .title,
                        iconWeight: .bold,
                        size: 68,
                        colors: [Color.red.opacity(0.9), Color.red],
                        shadowColor: .red.opacity(0.4),
                        isProcessing: viewModel.isProcessingAction
                    ) {
                        Task {
                            await viewModel.handlePass()
                            VoiceOverAnnouncement.announce("Passed. Next profile.")
                        }
                    }
                    .accessibilityElement(
                        label: "Pass",
                        hint: "Skip this profile and move to the next",
                        traits: .isButton,
                        identifier: AccessibilityIdentifier.passButton
                    )
                    .disabled(viewModel.isProcessingAction)

                    // Super Like button
                    SwipeActionButton(
                        icon: "star.fill",
                        iconSize: .title2,
                        iconWeight: .semibold,
                        size: 60,
                        colors: [Color.blue, Color.cyan],
                        shadowColor: .blue.opacity(0.4),
                        isProcessing: viewModel.isProcessingAction
                    ) {
                        Task {
                            await viewModel.handleSuperLike()
                            VoiceOverAnnouncement.announce("Super like sent!")
                        }
                    }
                    .accessibilityElement(
                        label: "Super Like",
                        hint: "Send a super like to stand out and increase your chances of matching",
                        traits: .isButton,
                        identifier: AccessibilityIdentifier.superLikeButton
                    )
                    .disabled(viewModel.isProcessingAction)

                    // Like button
                    SwipeActionButton(
                        icon: "heart.fill",
                        iconSize: .title,
                        iconWeight: .bold,
                        size: 68,
                        colors: [Color.green.opacity(0.9), Color.green],
                        shadowColor: .green.opacity(0.4),
                        isProcessing: viewModel.isProcessingAction
                    ) {
                        Task {
                            await viewModel.handleLike()
                            VoiceOverAnnouncement.announce("Liked! Next profile.")
                        }
                    }
                    .accessibilityElement(
                        label: "Like",
                        hint: "Like this profile to potentially match",
                        traits: .isButton,
                        identifier: AccessibilityIdentifier.likeButton
                    )
                    .disabled(viewModel.isProcessingAction)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100) // Stay above tab bar and safe area
                .frame(maxWidth: .infinity)
            }
            .zIndex(100) // Ensure buttons are always on top
            .allowsHitTesting(true) // Explicitly enable hit testing for buttons
        }
    }
    
    // MARK: - Error State

    private var errorStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.red.opacity(0.6), .orange.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 12) {
                Text("Oops! Something Went Wrong")
                    .font(.title2)
                    .fontWeight(.bold)
                    .dynamicTypeSize(min: .large, max: .accessibility2)
                    .accessibilityAddTraits(.isHeader)

                Text(viewModel.errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .dynamicTypeSize(min: .small, max: .accessibility1)
            }
            .accessibilityElement(children: .combine)

            Button {
                HapticManager.shared.impact(.medium)
                Task {
                    await viewModel.loadUsers()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.body.weight(.semibold))
                    Text("Try Again")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundColor(.white)
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .contentShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(ScaleButtonStyle(scaleEffect: 0.96))
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle" : "person.2.slash")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple.opacity(0.6), .pink.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 12) {
                Text(viewModel.hasActiveFilters ? "No Matches Found" : "No More Profiles")
                    .font(.title2)
                    .fontWeight(.bold)
                    .dynamicTypeSize(min: .large, max: .accessibility2)
                    .accessibilityAddTraits(.isHeader)

                Text(viewModel.hasActiveFilters ?
                     "Try adjusting your filters to see more people" :
                     "Check back later for new people nearby")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .dynamicTypeSize(min: .small, max: .accessibility1)
            }
            .accessibilityElement(children: .combine)

            VStack(spacing: 12) {
                if viewModel.hasActiveFilters {
                    Button {
                        HapticManager.shared.impact(.medium)
                        viewModel.resetFilters()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.body.weight(.semibold))
                            Text("Clear Filters")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundColor(.white)
                        .background(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .contentShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(ScaleButtonStyle(scaleEffect: 0.96))
                    .padding(.horizontal, 40)
                }

                Button {
                    HapticManager.shared.impact(.light)
                    Task {
                        await viewModel.loadUsers()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.body.weight(.semibold))
                        Text("Refresh")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundColor(.purple)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .contentShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(ScaleButtonStyle(scaleEffect: 0.96))
                .padding(.horizontal, 40)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Match Animation
    
    private var matchCelebrationView: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Image(systemName: "sparkles")
                    .font(.system(size: 80))
                    .foregroundColor(.yellow)

                Text("It's a Match! 🎉")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .dynamicTypeSize(min: .large, max: .accessibility2)
                    .accessibilityAddTraits(.isHeader)

                if let user = viewModel.matchedUser {
                    Text("You and \(user.fullName) liked each other!")
                        .font(.title3)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .dynamicTypeSize(min: .medium, max: .accessibility1)
                }

                Button("Send Message") {
                    // Navigate to Messages tab (tab index 2)
                    if let matchedUserId = viewModel.matchedUser?.id {
                        NotificationCenter.default.post(
                            name: .navigateToMessages,
                            object: nil,
                            userInfo: ["matchedUserId": matchedUserId]
                        )
                    }
                    viewModel.dismissMatchAnimation()
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.large)

                Button("Keep Swiping") {
                    viewModel.dismissMatchAnimation()
                }
                .foregroundColor(.white)
            }
            .task {
                if let user = viewModel.matchedUser {
                    VoiceOverAnnouncement.announce("It's a match! You and \(user.fullName) liked each other!")
                }
            }
            .padding(40)
        }
    }

    // MARK: - Card View Helper

    @ViewBuilder
    private func cardView(for user: User, at cardIndex: Int) -> some View {
        UserCardView(user: user)
            .overlay(alignment: .topLeading) {
                // Pass indicator
                if cardIndex == 0 && viewModel.dragOffset.width < -50 {
                    swipeIndicator(icon: "xmark", color: .red, text: "PASS")
                        .opacity(min(1.0, abs(Double(viewModel.dragOffset.width)) / 100.0))
                }
            }
            .overlay(alignment: .topTrailing) {
                // Like indicator
                if cardIndex == 0 && viewModel.dragOffset.width > 50 {
                    swipeIndicator(icon: "heart.fill", color: .green, text: "LIKE")
                        .opacity(min(1.0, Double(viewModel.dragOffset.width) / 100.0))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 200) // Space for buttons and tab bar
            .offset(y: CGFloat(cardIndex * 8))
            .scaleEffect(1.0 - CGFloat(cardIndex) * 0.05)
            .opacity(1.0 - Double(cardIndex) * 0.2)
            .zIndex(Double(3 - cardIndex))
            .offset(cardIndex == 0 ? viewModel.dragOffset : .zero)
            .rotationEffect(.degrees(cardIndex == 0 ? (reduceMotion ? 0 : Double(viewModel.dragOffset.width / 20)) : 0))
            .animation(.swipeSpring, value: viewModel.dragOffset)
            .contentShape(Rectangle()) // Define tappable area
            .accessibilityElement(
                label: cardIndex == 0 ? "\(user.fullName), \(user.age) years old, from \(user.location)" : "",
                hint: cardIndex == 0 ? "Swipe right to like, left to pass, or tap for full profile. Use the action buttons below for more options" : "",
                traits: cardIndex == 0 ? .isButton : [],
                identifier: cardIndex == 0 ? AccessibilityIdentifier.userCard : nil,
                isHidden: cardIndex != 0
            )
            .accessibilityActions(cardIndex == 0 ? [
                AccessibilityCustomAction(name: "Like") {
                    Task { await viewModel.handleLike() }
                },
                AccessibilityCustomAction(name: "Pass") {
                    Task { await viewModel.handlePass() }
                },
                AccessibilityCustomAction(name: "Super Like") {
                    Task { await viewModel.handleSuperLike() }
                },
                AccessibilityCustomAction(name: "View Profile") {
                    viewModel.showUserDetail(user)
                }
            ] : [])
            .onTapGesture {
                if cardIndex == 0 {
                    viewModel.showUserDetail(user)
                }
            }
            .gesture(
                cardIndex == 0 ? DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        viewModel.dragOffset = value.translation
                    }
                    .onEnded { value in
                        viewModel.handleSwipeEnd(value: value)
                    } : nil
            )
    }

    // MARK: - Swipe Indicator Helper

    private func swipeIndicator(icon: String, color: Color, text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(color)

            Text(text)
                .font(.headline)
                .fontWeight(.black)
                .foregroundColor(color)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: color.opacity(0.4), radius: 12, y: 4)
        )
        .padding(32)
        .accessibilityHidden(true)
    }

}

// MARK: - User Card View

struct UserCardView: View {
    let user: User
    @State private var selectedPhotoIndex = 0
    @State private var isSaved = false
    @ObservedObject private var savedProfilesVM = SavedProfilesViewModel.shared

    // Filter out empty photo URLs and ensure at least profileImageURL
    private var validPhotos: [String] {
        let allPhotos = user.photos.isEmpty ? [user.profileImageURL] : user.photos
        return allPhotos.filter { !$0.isEmpty }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Background
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(radius: 10)

                // Photo carousel (if multiple photos) or single image
                if validPhotos.count > 1 {
                    TabView(selection: $selectedPhotoIndex) {
                        ForEach(validPhotos.indices, id: \.self) { index in
                            CachedCardImage(url: URL(string: validPhotos[index]))
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                } else {
                    // Single image fallback
                    CachedCardImage(url: URL(string: validPhotos.first ?? user.profileImageURL))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }

                // Online Status Indicator - Top Right Corner
                VStack {
                    HStack {
                        Spacer()
                        OnlineStatusIndicator(user: user)
                            .padding(.top, 16)
                            .padding(.trailing, 16)
                    }
                    Spacer()
                }

                // Gradient overlay for better text readability
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.8)
                    ],
                    startPoint: .init(x: 0.5, y: 0.6),
                    endPoint: .bottom
                )
                .allowsHitTesting(false) // Allow touches to pass through to buttons below

                // User info overlay
                VStack(alignment: .leading, spacing: 12) {
                    // Name and age
                    HStack(alignment: .top, spacing: 8) {
                        Text(user.fullName)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)

                        Text("\(user.age)")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))

                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }

                        if user.isPremium {
                            Image(systemName: "crown.fill")
                                .font(.title3)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.yellow, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }

                        Spacer()
                    }

                    // Location
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.subheadline)
                        Text(user.location)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)

                    // Bio
                    if !user.bio.isEmpty {
                        Text(user.bio)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.95))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }

                    // Interests preview
                    if !user.interests.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(user.interests.prefix(4), id: \.self) { interest in
                                    Text(interest)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(Color.white.opacity(0.2))
                                                .overlay(
                                                    Capsule()
                                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                }
                            }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Save/Bookmark button overlay (top-right)
                VStack {
                    HStack {
                        Spacer()

                        Button {
                            HapticManager.shared.impact(.light)
                            let wasAlreadySaved = isSaved
                            isSaved.toggle()
                            Task {
                                if isSaved {
                                    // Saving - check for success and revert on failure
                                    let success = await savedProfilesVM.saveProfile(user: user)
                                    if !success {
                                        await MainActor.run {
                                            isSaved = wasAlreadySaved  // Revert on failure
                                            HapticManager.shared.notification(.error)
                                        }
                                    }
                                } else {
                                    // Unsave using deterministic ID
                                    if let userId = user.effectiveId {
                                        savedProfilesVM.unsaveByUserId(userId)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        }
                        .accessibilityLabel(isSaved ? "Remove from saved" : "Save profile")
                        .accessibilityHint("Bookmark this profile for later")
                    }
                    .padding(.top, 16)
                    .padding(.trailing, 16)

                    Spacer()
                }
            }
            .cornerRadius(20)
            .onAppear {
                // BUGFIX: Use effectiveId for reliable user identification (handles @DocumentID edge cases)
                isSaved = savedProfilesVM.savedProfiles.contains(where: { $0.user.effectiveId == user.effectiveId })
            }
            .onChange(of: savedProfilesVM.savedProfiles) { _ in
                // BUGFIX: Use effectiveId for reliable user identification (handles @DocumentID edge cases)
                isSaved = savedProfilesVM.savedProfiles.contains(where: { $0.user.effectiveId == user.effectiveId })
            }
        }
        .frame(maxHeight: .infinity) // Fill available space
        .gpuAccelerated() // PERFORMANCE: GPU rendering for butter-smooth scrolling
    }
}

// MARK: - Swipe Action Button Component

/// Reusable button component for swipe actions with improved touch handling
struct SwipeActionButton: View {
    let icon: String
    let iconSize: Font
    let iconWeight: Font.Weight
    let size: CGFloat
    let colors: [Color]
    let shadowColor: Color
    let isProcessing: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            HapticManager.shared.impact(.medium)
            action()
        } label: {
            ZStack {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                } else {
                    Image(systemName: icon)
                        .font(iconSize)
                        .fontWeight(iconWeight)
                        .foregroundColor(.white)
                }
            }
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(isProcessing ? 0.7 : 1.0)
            )
            .clipShape(Circle())
            .shadow(color: shadowColor, radius: isPressed ? 4 : 8, y: isPressed ? 2 : 4)
            .scaleEffect(isPressed ? 0.88 : 1.0)
            .animation(.snappy, value: isPressed)
            .contentShape(Circle()) // Ensure full circle is tappable
        }
        .buttonStyle(PlainButtonStyle()) // Prevent default button styling
        .opacity(isProcessing ? 0.6 : 1.0)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        // Ensure minimum tap target size (44x44 points)
        .frame(minWidth: max(size, 44), minHeight: max(size, 44))
    }
}

#Preview {
    DiscoverView()
        .environmentObject(AuthService.shared)
}
