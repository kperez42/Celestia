//
//  SeeWhoLikesYouView.swift
//  Celestia
//
//  Premium feature: See who has liked you
//

import SwiftUI
import FirebaseFirestore

struct SeeWhoLikesYouView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = SeeWhoLikesYouViewModel()
    @Environment(\.dismiss) var dismiss

    @State private var showUpgradeSheet = false
    @State private var selectedUser: User?
    @State private var showUserProfile = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        headerView

                        // Premium badge if not premium
                        if !(authService.currentUser?.isPremium ?? false) {
                            premiumPromoBanner
                        }

                        // Likes grid
                        if viewModel.isLoading {
                            loadingView
                        } else if viewModel.usersWhoLiked.isEmpty {
                            emptyStateView
                        } else {
                            likesGridView
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Likes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
            }
            .task {
                await viewModel.loadUsersWhoLiked()
            }
            .sheet(isPresented: $showUpgradeSheet) {
                PremiumUpgradeView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showUserProfile) {
                if let user = selectedUser {
                    UserDetailView(user: user)
                        .environmentObject(authService)
                }
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .font(.title)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("\(viewModel.usersWhoLiked.count)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.primary)
            }

            Text(viewModel.usersWhoLiked.count == 1 ? "person likes you" : "people like you")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Premium Promo Banner

    private var premiumPromoBanner: some View {
        Button {
            showUpgradeSheet = true
            HapticManager.shared.impact(.medium)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.title2)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Upgrade to Premium")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("See who likes you without limits")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.orange.opacity(0.1), Color.pink.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
        }
    }

    // MARK: - Likes Grid

    private var likesGridView: some View {
        let columns = [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]

        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(viewModel.usersWhoLiked) { user in
                LikeCardView(
                    user: user,
                    isBlurred: !(authService.currentUser?.isPremium ?? false),
                    onTap: {
                        if authService.currentUser?.isPremium ?? false {
                            // Premium users can view profiles
                            // PERFORMANCE: Prefetch images for instant detail view
                            ImageCache.shared.prefetchUserPhotosHighPriority(user: user)
                            selectedUser = user
                            showUserProfile = true
                            HapticManager.shared.impact(.light)
                        } else {
                            showUpgradeSheet = true
                            HapticManager.shared.impact(.medium)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .shimmer()
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "heart.slash")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))

            VStack(spacing: 8) {
                Text("No Likes Yet")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Keep swiping to find your perfect match!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 60)
    }
}

// MARK: - Like Card View

struct LikeCardView: View {
    let user: User
    let isBlurred: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Profile image section
                ZStack(alignment: .topLeading) {
                    // Profile image - cached for smooth scrolling
                    if let imageURL = user.photos.first, let url = URL(string: imageURL) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .interpolation(.high)
                                .antialiased(true)
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 180)
                                .clipped()
                        } placeholder: {
                            Color.gray.opacity(0.2)
                                .frame(height: 180)
                        }
                    } else {
                        // Placeholder when no image
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
                        .frame(height: 180)
                    }

                    // Online Status Indicator - Top Left (only if not blurred)
                    if !isBlurred {
                        OnlineStatusIndicator(user: user)
                            .padding(.top, 8)
                            .padding(.leading, 8)
                    }

                    // Blur overlay for non-premium
                    if isBlurred {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .blur(radius: 20)
                            .frame(height: 180)

                        VStack {
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.title)
                                .foregroundColor(.white)

                            Text("Premium")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .frame(height: 180)
                    }
                }
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipped()
                .cornerRadius(16, corners: [.topLeft, .topRight])

                // Info section with white background - separate from image
                VStack(alignment: .leading, spacing: 6) {
                    Text(isBlurred ? "••••••" : user.fullName)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(isBlurred ? "••" : "\(user.age)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if !isBlurred && !user.location.isEmpty {
                            Text("•")
                                .foregroundColor(.secondary)

                            Text(user.location)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - View Model

@MainActor
class SeeWhoLikesYouViewModel: ObservableObject {
    @Published var usersWhoLiked: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    // Cache management
    private var lastFetchTime: Date?
    private let cacheDuration: TimeInterval = 120 // 2 minutes

    func loadUsersWhoLiked(forceRefresh: Bool = false) async {
        // Check cache first
        if !forceRefresh,
           let lastFetch = lastFetchTime,
           !usersWhoLiked.isEmpty,
           Date().timeIntervalSince(lastFetch) < cacheDuration {
            Logger.shared.debug("SeeWhoLikesYou cache HIT - using cached data", category: .performance)
            return
        }

        guard let currentUserId = AuthService.shared.currentUser?.effectiveId else { return }

        // Only show loading if we have no cached data
        let shouldShowLoading = usersWhoLiked.isEmpty
        if shouldShowLoading {
            isLoading = true
        }
        defer {
            if shouldShowLoading {
                isLoading = false
            }
        }

        do {
            // Get user IDs who liked current user
            let likerIds = try await SwipeService.shared.getLikesReceived(userId: currentUserId)

            // PERFORMANCE FIX: Use batch queries instead of N+1 sequential queries
            // This reduces network calls from N to ceil(N/10)
            let users = try await fetchUsersBatched(ids: likerIds)

            usersWhoLiked = users
            lastFetchTime = Date()
            errorMessage = nil

            Logger.shared.info("Loaded \(users.count) users who liked you (batch query)", category: .matching)

            // Prefetch images for smooth scrolling
            Task {
                for user in users {
                    ImageCache.shared.prefetchUserPhotosHighPriority(user: user)
                }
            }
        } catch {
            Logger.shared.error("Error loading likes", category: .matching, error: error)
            errorMessage = "Failed to load likes. Pull to refresh."
        }
    }

    /// Fetch users in batches of 10 (Firestore whereIn limit)
    private func fetchUsersBatched(ids: [String]) async throws -> [User] {
        guard !ids.isEmpty else { return [] }

        var users: [User] = []
        let chunks = ids.chunked(into: 10)

        // Run batch queries in parallel for better performance
        try await withThrowingTaskGroup(of: [User].self) { group in
            for chunk in chunks {
                group.addTask {
                    let snapshot = try await self.db.collection("users")
                        .whereField(FieldPath.documentID(), in: chunk)
                        .getDocuments()

                    return snapshot.documents.compactMap { try? $0.data(as: User.self) }
                }
            }

            for try await chunkUsers in group {
                users.append(contentsOf: chunkUsers)
            }
        }

        // Filter out users who are not active (pending, suspended, flagged, banned)
        // Only show users with active profileStatus
        users = users.filter { user in
            let status = user.profileStatus.lowercased()
            return status == "active" || status.isEmpty
        }

        // Maintain original order (by like timestamp) by reordering based on input IDs
        // BUGFIX: Use effectiveId for reliable user identification
        let idOrder = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        users.sort { (idOrder[$0.effectiveId ?? ""] ?? Int.max) < (idOrder[$1.effectiveId ?? ""] ?? Int.max) }

        return users
    }

    func likeBack(user: User) async -> Bool {
        guard let targetUserId = user.effectiveId else { return false }
        guard let currentUserId = AuthService.shared.currentUser?.effectiveId else { return false }

        do {
            let isMatch = try await SwipeService.shared.likeUser(
                fromUserId: currentUserId,
                toUserId: targetUserId,
                isSuperLike: false
            )

            if isMatch {
                HapticManager.shared.notification(.success)
                Logger.shared.info("Liked back user - it's a match!", category: .matching)
            } else {
                HapticManager.shared.impact(.medium)
            }

            return isMatch
        } catch {
            Logger.shared.error("Error liking back user", category: .matching, error: error)
            HapticManager.shared.notification(.error)
            return false
        }
    }
}

#Preview {
    NavigationStack {
        SeeWhoLikesYouView()
            .environmentObject(AuthService.shared)
    }
}
