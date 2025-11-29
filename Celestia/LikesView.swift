//
//  LikesView.swift
//  Celestia
//
//  Likes view with three tabs: Liked Me, My Likes, Mutual Likes
//

import SwiftUI
import FirebaseFirestore

struct LikesView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = LikesViewModel()
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    @State private var selectedTab = 0
    @State private var selectedUserForDetail: User?
    @State private var showChatWithUser: User?
    @State private var showPremiumUpgrade = false

    // Direct messaging state - using dedicated struct for item-based presentation
    @State private var chatPresentation: ChatPresentation?

    struct ChatPresentation: Identifiable {
        let id = UUID()
        let match: Match
        let user: User
    }

    private let tabs = ["Liked Me", "My Likes", "Mutual Likes"]

    // Check if user has premium access
    private var isPremium: Bool {
        authService.currentUser?.isPremium == true
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    headerView

                    // Tab selector
                    tabSelector

                    // Content based on selected tab
                    if viewModel.isLoading {
                        loadingView
                    } else {
                        TabView(selection: $selectedTab) {
                            likedMeTab.tag(0)
                            myLikesTab.tag(1)
                            mutualLikesTab.tag(2)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .task {
                // PERFORMANCE: Initial load with cache check
                await viewModel.loadAllLikes()
            }
            .onAppear {
                // PERFORMANCE: Skip reload if cache is still fresh (within 2 minutes)
                // This prevents the glitchy loading state on tab switches
                // Users can still pull-to-refresh for fresh data
            }
            .refreshable {
                HapticManager.shared.impact(.light)
                await viewModel.loadAllLikes(forceRefresh: true)
                HapticManager.shared.notification(.success)
            }
            .sheet(item: $selectedUserForDetail) { user in
                UserDetailView(user: user)
                    .environmentObject(authService)
            }
            .sheet(item: $showChatWithUser) { user in
                // Find match for this user to open chat
                if let match = viewModel.findMatchForUser(user) {
                    NavigationStack {
                        ChatView(match: match, otherUser: user)
                            .environmentObject(authService)
                    }
                }
            }
            .sheet(item: $chatPresentation) { presentation in
                NavigationStack {
                    ChatView(match: presentation.match, otherUser: presentation.user)
                        .environmentObject(authService)
                }
            }
            .sheet(isPresented: $showPremiumUpgrade) {
                PremiumUpgradeView()
                    .environmentObject(authService)
            }
        }
        .networkStatusBanner()
    }

    // MARK: - Message Handling

    private func handleMessage(user: User) {
        guard let currentUserId = authService.currentUser?.effectiveId,
              let userId = user.effectiveId else {
            return
        }

        HapticManager.shared.impact(.medium)

        Task {
            do {
                // Check if a match already exists
                var existingMatch = try await MatchService.shared.fetchMatch(user1Id: currentUserId, user2Id: userId)

                if existingMatch == nil {
                    // No match exists - create one to enable messaging
                    Logger.shared.info("Creating conversation with \(user.fullName) from LikesView", category: .messaging)

                    // Create the match
                    await MatchService.shared.createMatch(user1Id: currentUserId, user2Id: userId)

                    // Fetch the newly created match
                    existingMatch = try await MatchService.shared.fetchMatch(user1Id: currentUserId, user2Id: userId)
                }

                await MainActor.run {
                    if let match = existingMatch {
                        // Open chat directly using item-based presentation
                        chatPresentation = ChatPresentation(match: match, user: user)
                        Logger.shared.info("Opening chat with \(user.fullName)", category: .messaging)
                    }
                }
            } catch {
                Logger.shared.error("Error starting conversation from LikesView", category: .messaging, error: error)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.pink.opacity(0.9),
                    Color.pink.opacity(0.7),
                    Color.purple.opacity(0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Likes")
                            .font(.largeTitle.weight(.bold))
                            .foregroundColor(.white)
                            .dynamicTypeSize(min: .large, max: .accessibility2)

                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.caption)
                                Text("\(viewModel.totalLikesReceived)")
                                    .fontWeight(.semibold)
                            }

                            Circle()
                                .fill(Color.white.opacity(0.5))
                                .frame(width: 4, height: 4)

                            HStack(spacing: 4) {
                                Image(systemName: "heart")
                                    .font(.caption)
                                Text("\(viewModel.totalLikesSent) sent")
                                    .fontWeight(.semibold)
                            }

                            if viewModel.mutualLikes.count > 0 {
                                Circle()
                                    .fill(Color.white.opacity(0.5))
                                    .frame(width: 4, height: 4)

                                HStack(spacing: 4) {
                                    Image(systemName: "heart.circle.fill")
                                        .font(.caption)
                                    Text("\(viewModel.mutualLikes.count) mutual")
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.95))
                    }

                    Spacer()

                    if authService.currentUser?.isPremium == true {
                        premiumBadge
                    }
                }
                .padding(.top, 50)
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 16)
        }
        .frame(height: 110)
    }

    private var premiumBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "crown.fill")
                .font(.caption)
            Text("Premium")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(.yellow)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.yellow.opacity(0.2))
                .overlay(
                    Capsule()
                        .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
                )
        )
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.0) { index, title in
                Button {
                    HapticManager.shared.selection()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Text(title)
                                .font(.subheadline)
                                .fontWeight(selectedTab == index ? .semibold : .medium)

                            // Badge count
                            let count = getCountForTab(index)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        selectedTab == index ?
                                        Color.pink : Color.gray.opacity(0.5)
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                        .foregroundColor(selectedTab == index ? .pink : .gray)

                        Rectangle()
                            .fill(selectedTab == index ? Color.pink : Color.clear)
                            .frame(height: 3)
                            .cornerRadius(1.5)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .background(Color.white)
    }

    private func getCountForTab(_ index: Int) -> Int {
        switch index {
        case 0: return viewModel.usersWhoLikedMe.count
        case 1: return viewModel.usersILiked.count
        case 2: return viewModel.mutualLikes.count
        default: return 0
        }
    }

    // MARK: - Liked Me Tab

    private var likedMeTab: some View {
        Group {
            if viewModel.usersWhoLikedMe.isEmpty {
                emptyStateView(
                    icon: "heart.fill",
                    title: "No Likes Yet",
                    message: "When someone likes you, they'll appear here. Keep swiping!"
                )
            } else if isPremium {
                // Premium users see full profiles
                likesGrid(users: viewModel.usersWhoLikedMe, showLikeBack: true)
            } else {
                // Free users see blurred/locked view with upgrade CTA
                premiumLockedLikesView
            }
        }
    }

    // MARK: - Premium Locked View

    private var premiumLockedLikesView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Blurred preview grid
                blurredProfilesGrid

                // Unlock CTA Card
                premiumUnlockCard

                // Features preview
                premiumFeaturesPreview
            }
            .padding(16)
            .padding(.bottom, 100)
        }
    }

    private var blurredProfilesGrid: some View {
        VStack(spacing: 12) {
            // Show up to 4 blurred profiles in a grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(Array(viewModel.usersWhoLikedMe.prefix(4).enumerated()), id: \.1.effectiveId) { index, user in
                    BlurredLikeCard(user: user, index: index)
                        .onTapGesture {
                            HapticManager.shared.impact(.medium)
                            showPremiumUpgrade = true
                        }
                }
            }

            // "And X more..." indicator if there are more likes
            if viewModel.usersWhoLikedMe.count > 4 {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.pink)
                    Text("And \(viewModel.usersWhoLikedMe.count - 4) more people liked you!")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
    }

    private var premiumUnlockCard: some View {
        VStack(spacing: 20) {
            // Icon with glow effect
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.pink.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "eye.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("\(viewModel.usersWhoLikedMe.count) people liked you!")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Upgrade to Premium to see who they are and match instantly")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            // Unlock button
            Button {
                HapticManager.shared.impact(.medium)
                showPremiumUpgrade = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "crown.fill")
                        .font(.body)

                    Text("Unlock Who Likes You")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.pink, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: .pink.opacity(0.4), radius: 10, y: 5)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
        )
    }

    private var premiumFeaturesPreview: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Premium Benefits")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 12) {
                premiumFeatureRow(icon: "eye.fill", title: "See Who Likes You", description: "Match instantly with people interested in you", color: .pink)
                premiumFeatureRow(icon: "infinity", title: "Unlimited Likes", description: "No daily limits, like as many as you want", color: .purple)
                premiumFeatureRow(icon: "bolt.fill", title: "Profile Boost", description: "Get 10x more views with monthly boosts", color: .orange)
                premiumFeatureRow(icon: "arrow.uturn.backward", title: "Rewind", description: "Undo accidental swipes", color: .blue)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func premiumFeatureRow(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - My Likes Tab

    private var myLikesTab: some View {
        Group {
            if viewModel.usersILiked.isEmpty {
                emptyStateView(
                    icon: "heart",
                    title: "No Likes Sent",
                    message: "Start swiping on the Discover page to like profiles!"
                )
            } else {
                likesGrid(users: viewModel.usersILiked, showLikeBack: false)
            }
        }
    }

    // MARK: - Mutual Likes Tab

    private var mutualLikesTab: some View {
        Group {
            if viewModel.mutualLikes.isEmpty {
                emptyStateView(
                    icon: "heart.circle.fill",
                    title: "No Mutual Likes",
                    message: "When you and someone else both like each other, you'll see them here!"
                )
            } else {
                likesGrid(users: viewModel.mutualLikes, showMessage: true)
            }
        }
    }

    // MARK: - Likes Grid

    private func likesGrid(users: [User], showLikeBack: Bool = false, showMessage: Bool = false) -> some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(users, id: \.effectiveId) { user in
                    LikeProfileCard(
                        user: user,
                        showLikeBack: showLikeBack,
                        showMessage: showMessage,
                        onTap: {
                            selectedUserForDetail = user
                        },
                        onLikeBack: {
                            Task {
                                await viewModel.likeBackUser(user)
                            }
                        },
                        onMessage: {
                            handleMessage(user: user)
                        }
                    )
                    .onAppear {
                        // PERFORMANCE: Prefetch images as cards appear in viewport
                        ImageCache.shared.prefetchUserPhotosHighPriority(user: user)
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(0..<6, id: \.self) { _ in
                    LikeCardSkeleton()
                }
            }
            .padding(16)
        }
    }

    // MARK: - Empty State

    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.pink.opacity(0.2), Color.purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)

                Image(systemName: icon)
                    .font(.system(size: 70))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Like Profile Card

struct LikeProfileCard: View {
    let user: User
    var showLikeBack: Bool = false
    var showMessage: Bool = false
    var onTap: () -> Void
    var onLikeBack: (() -> Void)? = nil
    var onMessage: (() -> Void)? = nil

    // Fixed height for consistent card sizing across all grid cards
    private let imageHeight: CGFloat = 180

    var body: some View {
        VStack(spacing: 0) {
            // Profile image - fixed height for consistent card sizes
            ZStack(alignment: .topTrailing) {
                profileImage

                // Verified badge
                if user.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                        .background(Circle().fill(.white).padding(-2))
                        .padding(8)
                }
            }
            .frame(height: imageHeight)
            .clipped()
            .contentShape(Rectangle())
            .cornerRadius(16, corners: [.topLeft, .topRight])

            // User info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(user.fullName)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)

                    Text("\(user.age)")
                        .font(.system(size: 17))
                        .foregroundColor(.secondary)

                    Spacer()
                }

                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.purple)
                    Text(user.location)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                // Action buttons with snappy animations
                if showLikeBack || showMessage {
                    HStack(spacing: 8) {
                        if showLikeBack {
                            LikeActionButton(
                                icon: "heart.fill",
                                text: "Like",
                                colors: [.pink, .red]
                            ) {
                                onLikeBack?()
                            }
                        }

                        if showMessage {
                            LikeActionButton(
                                icon: "message.fill",
                                text: "Message",
                                colors: [.purple, .blue]
                            ) {
                                onMessage?()
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .onTapGesture {
            HapticManager.shared.impact(.light)
            onTap()
        }
    }

    private var profileImage: some View {
        Group {
            if let imageURL = URL(string: user.profileImageURL), !user.profileImageURL.isEmpty {
                CachedCardImage(url: imageURL)
                    .frame(height: imageHeight)
            } else {
                placeholderImage
            }
        }
        .frame(height: imageHeight)
        .frame(maxWidth: .infinity)
        .clipped()
        .contentShape(Rectangle())
    }

    private var placeholderImage: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple.opacity(0.7), Color.pink.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text(user.fullName.prefix(1))
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Skeleton

struct LikeCardSkeleton: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 180)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 20)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 14)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear { isAnimating = true }
    }
}

// MARK: - Blurred Like Card (Premium Locked)

struct BlurredLikeCard: View {
    let user: User
    let index: Int

    private let imageHeight: CGFloat = 180

    // Consistent purple/pink brand gradient
    private var gradientColors: [Color] {
        [.purple, .pink]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Blurred profile image with lock overlay
            ZStack {
                // Background image (blurred)
                if let imageURL = URL(string: user.profileImageURL), !user.profileImageURL.isEmpty {
                    CachedCardImage(url: imageURL)
                        .frame(height: imageHeight)
                        .blur(radius: 20)
                        .clipped()
                } else {
                    // Gradient placeholder
                    LinearGradient(
                        colors: gradientColors.map { $0.opacity(0.7) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: imageHeight)
                    .blur(radius: 10)
                }

                // Gradient overlay for depth
                LinearGradient(
                    colors: [
                        gradientColors[0].opacity(0.3),
                        gradientColors[1].opacity(0.5)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Lock icon
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 56, height: 56)

                        Image(systemName: "lock.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }

                    Text("Premium")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                        )
                }
            }
            .frame(height: imageHeight)
            .clipped()
            .cornerRadius(16, corners: [.topLeft, .topRight])

            // Blurred user info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Blurred name placeholder
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: gradientColors.map { $0.opacity(0.3) },
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 100, height: 20)

                    Spacer()

                    // Heart indicator
                    Image(systemName: "heart.fill")
                        .foregroundColor(.pink)
                        .font(.caption)
                }

                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.5))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 14)
                }

                // Tap to unlock hint
                HStack {
                    Spacer()
                    Text("Tap to unlock")
                        .font(.caption2)
                        .foregroundColor(.pink)
                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .purple.opacity(0.2), radius: 12, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.purple.opacity(0.3), .pink.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Like Action Button

/// Snappy animated button for like/message actions in likes view
struct LikeActionButton: View {
    let icon: String
    let text: String
    let colors: [Color]
    let action: () -> Void

    @State private var isPressed = false
    @State private var isAnimating = false

    var body: some View {
        Button {
            HapticManager.shared.impact(.medium)
            // Snappy animation
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                isAnimating = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    isAnimating = false
                }
            }
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .scaleEffect(isAnimating ? 1.3 : 1.0)
                Text(text)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: colors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(8)
            .scaleEffect(isPressed ? 0.95 : (isAnimating ? 1.05 : 1.0))
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.easeOut(duration: 0.1)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - View Model

@MainActor
class LikesViewModel: ObservableObject {
    @Published var usersWhoLikedMe: [User] = []
    @Published var usersILiked: [User] = []
    @Published var mutualLikes: [User] = []
    @Published var isLoading = false

    private let db = Firestore.firestore()
    private var matchesCache: [String: Match] = [:]

    // PERFORMANCE: Cache management to prevent reloads on every tab switch
    private var lastFetchTime: Date?
    private let cacheDuration: TimeInterval = 120 // 2 minutes cache

    var totalLikesReceived: Int { usersWhoLikedMe.count }
    var totalLikesSent: Int { usersILiked.count }

    func loadAllLikes(forceRefresh: Bool = false) async {
        // PERFORMANCE: Check cache first - skip fetch if we have recent data
        if !forceRefresh,
           let lastFetch = lastFetchTime,
           !usersWhoLikedMe.isEmpty || !usersILiked.isEmpty,
           Date().timeIntervalSince(lastFetch) < cacheDuration {
            Logger.shared.debug("LikesView cache HIT - using cached data", category: .performance)
            return // Use cached data - instant display
        }

        // Only show loading skeleton if we have no cached data
        let shouldShowLoading = usersWhoLikedMe.isEmpty && usersILiked.isEmpty
        if shouldShowLoading {
            isLoading = true
        }
        defer {
            if shouldShowLoading {
                isLoading = false
            }
        }

        guard let currentUserId = AuthService.shared.currentUser?.effectiveId else {
            return
        }

        do {
            // Fetch likes received
            let likesReceivedIds = try await SwipeService.shared.getLikesReceived(userId: currentUserId)
            let likesReceivedUsers = try await fetchUsers(ids: likesReceivedIds)

            // Fetch likes sent
            let likesSentIds = try await SwipeService.shared.getLikesSent(userId: currentUserId)
            let likesSentUsers = try await fetchUsers(ids: likesSentIds)

            // Calculate mutual likes (intersection of both)
            let receivedSet = Set(likesReceivedIds)
            let sentSet = Set(likesSentIds)
            let mutualIds = receivedSet.intersection(sentSet)
            let mutualUsers = likesSentUsers.filter { mutualIds.contains($0.effectiveId ?? "") }

            // Fetch matches for mutual likes
            try await loadMatchesForMutualLikes(userId: currentUserId, mutualUserIds: Array(mutualIds))

            await MainActor.run {
                self.usersWhoLikedMe = likesReceivedUsers
                self.usersILiked = likesSentUsers
                self.mutualLikes = mutualUsers
                // PERFORMANCE: Update cache timestamp after successful fetch
                self.lastFetchTime = Date()
            }

            Logger.shared.info("Loaded likes - Received: \(likesReceivedUsers.count), Sent: \(likesSentUsers.count), Mutual: \(mutualUsers.count) - cached for 2 min", category: .matching)

            // PERFORMANCE: Eagerly prefetch images for all loaded likes
            // This ensures images are cached when users tap cards
            Task {
                for user in likesReceivedUsers + likesSentUsers {
                    ImageCache.shared.prefetchUserPhotosHighPriority(user: user)
                }
            }
        } catch {
            Logger.shared.error("Error loading likes", category: .matching, error: error)
        }
    }

    private func fetchUsers(ids: [String]) async throws -> [User] {
        guard !ids.isEmpty else { return [] }

        var users: [User] = []
        let chunks = ids.chunked(into: 10)

        for chunk in chunks {
            let snapshot = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()

            let chunkUsers = snapshot.documents.compactMap { try? $0.data(as: User.self) }
            users.append(contentsOf: chunkUsers)
        }

        return users
    }

    private func loadMatchesForMutualLikes(userId: String, mutualUserIds: [String]) async throws {
        for otherUserId in mutualUserIds {
            if let match = try await MatchService.shared.fetchMatch(user1Id: userId, user2Id: otherUserId) {
                matchesCache[otherUserId] = match
            }
        }
    }

    func findMatchForUser(_ user: User) -> Match? {
        guard let userId = user.effectiveId else { return nil }
        return matchesCache[userId]
    }

    func likeBackUser(_ user: User) async {
        guard let targetUserId = user.effectiveId else { return }
        guard let currentUserId = AuthService.shared.currentUser?.effectiveId else { return }

        do {
            let isMatch = try await SwipeService.shared.likeUser(
                fromUserId: currentUserId,
                toUserId: targetUserId,
                isSuperLike: false
            )

            if isMatch {
                // Add to mutual likes but keep in "Liked Me" so user can still see who liked them
                await MainActor.run {
                    if !mutualLikes.contains(where: { $0.effectiveId == targetUserId }) {
                        mutualLikes.append(user)
                    }
                    if !usersILiked.contains(where: { $0.effectiveId == targetUserId }) {
                        usersILiked.append(user)
                    }
                }
                HapticManager.shared.notification(.success)
                Logger.shared.info("Liked back user - now mutual!", category: .matching)
            } else {
                await MainActor.run {
                    if !usersILiked.contains(where: { $0.effectiveId == targetUserId }) {
                        usersILiked.append(user)
                    }
                }
            }
        } catch {
            Logger.shared.error("Error liking back user", category: .matching, error: error)
        }
    }
}

#Preview {
    LikesView()
        .environmentObject(AuthService.shared)
}
