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

    // Direct messaging state - using dedicated struct for item-based presentation
    @State private var chatPresentation: ChatPresentation?

    struct ChatPresentation: Identifiable {
        let id = UUID()
        let match: Match
        let user: User
    }

    private let tabs = ["Liked Me", "My Likes", "Mutual Likes"]

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
                await viewModel.loadAllLikes()
            }
            .onAppear {
                // Refresh data when tab becomes visible, but only if not currently loading
                // LazyTabContent caches views, so we need this for tab switches
                if !viewModel.isLoading {
                    Task {
                        await viewModel.loadAllLikes()
                    }
                }
            }
            .refreshable {
                HapticManager.shared.impact(.light)
                await viewModel.loadAllLikes()
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
            } else {
                likesGrid(users: viewModel.usersWhoLikedMe, showLikeBack: true)
            }
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
                        .foregroundColor(.pink)
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
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        .onTapGesture {
            HapticManager.shared.impact(.light)
            onTap()
        }
    }

    private var profileImage: some View {
        Group {
            if let imageURL = URL(string: user.profileImageURL), !user.profileImageURL.isEmpty {
                CachedCardImage(url: imageURL)
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholderImage
            }
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var placeholderImage: some View {
        ZStack {
            LinearGradient(
                colors: [Color.pink.opacity(0.7), Color.purple.opacity(0.5)],
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
        .background(Color.white)
        .cornerRadius(16)
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear { isAnimating = true }
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

    var totalLikesReceived: Int { usersWhoLikedMe.count }
    var totalLikesSent: Int { usersILiked.count }

    func loadAllLikes() async {
        isLoading = true
        defer { isLoading = false }

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
            }

            Logger.shared.info("Loaded likes - Received: \(likesReceivedUsers.count), Sent: \(likesSentUsers.count), Mutual: \(mutualUsers.count)", category: .matching)

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
                // Move to mutual likes
                await MainActor.run {
                    if let index = usersWhoLikedMe.firstIndex(where: { $0.effectiveId == targetUserId }) {
                        let likedUser = usersWhoLikedMe.remove(at: index)
                        mutualLikes.append(likedUser)
                        usersILiked.append(likedUser)
                    }
                }
                HapticManager.shared.notification(.success)
                Logger.shared.info("Liked back user - now mutual!", category: .matching)
            } else {
                await MainActor.run {
                    usersILiked.append(user)
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
