//
//  FeedDiscoverView.swift
//  Celestia
//
//  Feed-style discovery view with vertical scrolling and pagination
//

import SwiftUI

struct FeedDiscoverView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var filters = DiscoveryFilters.shared
    @ObservedObject private var savedProfilesViewModel = SavedProfilesViewModel.shared
    @Binding var selectedTab: Int

    @State private var users: [User] = []
    @State private var displayedUsers: [User] = []
    @State private var currentPage = 0
    @State private var isLoading = false
    @State private var isInitialLoad = true
    @State private var showFilters = false
    @State private var selectedUser: User?
    @State private var showUserDetail = false
    @State private var showPhotoGallery = false
    @State private var showMatchAnimation = false
    @State private var matchedUser: User?
    @State private var favorites: Set<String> = []
    @State private var errorMessage: String = ""

    // Action feedback toast
    @State private var showActionToast = false
    @State private var toastMessage = ""
    @State private var toastIcon = ""
    @State private var toastColor: Color = .green

    private let usersPerPage = 10
    private let preloadThreshold = 3 // Load more when 3 items from bottom

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                // Main content
                if isInitialLoad {
                    // Skeleton loader for initial load
                    initialLoadingView
                } else {
                    // Main scroll view
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(displayedUsers.enumerated()), id: \.element.id) { index, user in
                                ProfileFeedCard(
                                    user: user,
                                    initialIsFavorited: favorites.contains(user.id ?? ""),
                                    onLike: {
                                        handleLike(user: user)
                                    },
                                    onFavorite: {
                                        handleFavorite(user: user)
                                    },
                                    onMessage: {
                                        handleMessage(user: user)
                                    },
                                    onViewPhotos: {
                                        selectedUser = user
                                        showPhotoGallery = true
                                    }
                                )
                                .onAppear {
                                    if index == displayedUsers.count - preloadThreshold {
                                        loadMoreUsers()
                                    }
                                }
                            }

                            // Loading indicator (for pagination)
                            if isLoading {
                                ProgressView()
                                    .padding()
                            }

                            // End of results
                            if !isLoading && displayedUsers.count >= users.count && users.count > 0 {
                                endOfResultsView
                            }

                            // Error state
                            if !errorMessage.isEmpty {
                                errorStateView
                            }
                            // Empty state
                            else if !isLoading && displayedUsers.isEmpty {
                                emptyStateView
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom)
                    }
                    .refreshable {
                        await refreshFeed()
                    }
                }

                // Match animation overlay
                if showMatchAnimation {
                    matchCelebrationView
                }

                // Action feedback toast
                if showActionToast {
                    VStack {
                        HStack(spacing: 12) {
                            Image(systemName: toastIcon)
                                .font(.title3)
                                .foregroundColor(.white)

                            Text(toastMessage)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            toastColor
                                .shadow(color: toastColor.opacity(0.4), radius: 12, y: 6)
                        )
                        .cornerRadius(12)
                        .padding(.top, 16)

                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showFilters = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.title3)
                                .foregroundColor(.purple)

                            if filters.hasActiveFilters {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 2, y: -2)
                            }
                        }
                    }
                    .padding(.trailing, 4)
                }
            }
            .sheet(isPresented: $showFilters) {
                DiscoverFiltersView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showUserDetail) {
                if let user = selectedUser {
                    UserDetailView(user: user)
                        .environmentObject(authService)
                }
            }
            .sheet(isPresented: $showPhotoGallery) {
                if let user = selectedUser {
                    PhotoGalleryView(user: user)
                }
            }
            .onAppear {
                if users.isEmpty {
                    Task {
                        await loadUsers()
                        await savedProfilesViewModel.loadSavedProfiles()
                        // Sync favorites set with saved profiles
                        favorites = Set(savedProfilesViewModel.savedProfiles.compactMap { $0.user.id })
                    }
                }
            }
            .onChange(of: filters.hasActiveFilters) { _ in
                Task {
                    await reloadWithFilters()
                }
            }
        }
    }

    // MARK: - Initial Loading View

    private var initialLoadingView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in
                    ProfileFeedCardSkeleton()
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))

            Text("No Profiles Found")
                .font(.title2)
                .fontWeight(.bold)

            Text("Try adjusting your filters to see more people")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showFilters = true
            } label: {
                Text("Adjust Filters")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
        }
        .padding(40)
    }

    // MARK: - Error State

    private var errorStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 70))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.red.opacity(0.7), .orange.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 12) {
                Text("Oops! Something Went Wrong")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                errorMessage = ""  // Clear error
                Task {
                    await loadUsers()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .fontWeight(.semibold)
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
                .cornerRadius(12)
            }
        }
        .padding(40)
    }

    private var endOfResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)

            Text("You've seen everyone!")
                .font(.headline)

            Text("Check back later for new profiles")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button {
                Task {
                    await refreshFeed()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .foregroundColor(.purple)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .padding(40)
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

                if let user = matchedUser {
                    Text("You and \(user.fullName) liked each other!")
                        .font(.title3)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }

                Button("Send Message") {
                    showMatchAnimation = false
                    // NOTE: Navigation to messages should be implemented using NavigationPath or coordinator
                    // For now, user can access messages from Messages tab
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.large)

                Button("Keep Browsing") {
                    showMatchAnimation = false
                }
                .foregroundColor(.white)
            }
            .padding(40)
        }
    }

    // MARK: - Data Loading

    private func loadUsers() async {
        #if DEBUG
        // Use test data in debug builds for easier testing
        await MainActor.run {
            users = TestData.discoverUsers
            loadMoreUsers()
            isInitialLoad = false
        }
        return
        #endif

        guard let currentUserId = authService.currentUser?.id else {
            await MainActor.run {
                isInitialLoad = false
            }
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Fetch from Firestore with filters
            let currentLocation: (lat: Double, lon: Double)? = {
                if let user = authService.currentUser,
                   let lat = user.latitude,
                   let lon = user.longitude {
                    return (lat, lon)
                }
                return nil
            }()

            // Get age range with proper optional handling
            let ageRange: ClosedRange<Int>? = {
                if let minAge = authService.currentUser?.ageRangeMin,
                   let maxAge = authService.currentUser?.ageRangeMax {
                    return minAge...maxAge
                }
                return nil
            }()

            // Fetch users from Firestore using UserService
            try await UserService.shared.fetchUsers(
                excludingUserId: currentUserId,
                lookingFor: authService.currentUser?.lookingFor,
                ageRange: ageRange ?? 18...99,
                limit: 50,
                reset: true
            )

            await MainActor.run {
                users = UserService.shared.users
                errorMessage = ""  // Clear any previous errors
                isInitialLoad = false  // Hide skeleton and show content
                loadMoreUsers()
            }
        } catch {
            Logger.shared.error("Error loading users", category: .database, error: error)
            await MainActor.run {
                errorMessage = "Failed to load users. Please check your connection and try again."
                isInitialLoad = false  // Show error state instead of skeleton
            }
        }
    }

    private func loadMoreUsers() {
        guard !isLoading else { return }

        let startIndex = currentPage * usersPerPage
        let endIndex = min(startIndex + usersPerPage, users.count)

        guard startIndex < users.count else { return }

        let newUsers = Array(users[startIndex..<endIndex])
        displayedUsers.append(contentsOf: newUsers)
        currentPage += 1
    }

    private func refreshFeed() async {
        currentPage = 0
        displayedUsers = []
        await loadUsers()
        HapticManager.shared.notification(.success)
    }

    private func reloadWithFilters() async {
        currentPage = 0
        displayedUsers = []
        await loadUsers()
    }

    // MARK: - Actions

    private func showToast(message: String, icon: String, color: Color) {
        toastMessage = message
        toastIcon = icon
        toastColor = color

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showActionToast = true
        }

        // Auto-hide after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showActionToast = false
            }
        }
    }

    private func handleLike(user: User) {
        guard let currentUserId = authService.currentUser?.id,
              let userId = user.id else {
            showToast(
                message: "Unable to like. Please try again.",
                icon: "exclamationmark.triangle.fill",
                color: .red
            )
            return
        }

        // Prevent liking yourself
        guard currentUserId != userId else {
            showToast(
                message: "You can't like your own profile!",
                icon: "exclamationmark.triangle.fill",
                color: .orange
            )
            return
        }

        // Check rate limit
        guard RateLimiter.shared.canSendLike() else {
            let remaining = RateLimiter.shared.getRemainingLikes()
            showToast(
                message: "Daily like limit reached. Try again tomorrow.",
                icon: "exclamationmark.triangle.fill",
                color: .orange
            )
            return
        }

        Task {
            do {
                // Send like to backend
                let isMatch = try await SwipeService.shared.likeUser(
                    fromUserId: currentUserId,
                    toUserId: userId,
                    isSuperLike: false
                )

                // Track analytics
                try await AnalyticsManager.shared.trackSwipe(
                    swipedUserId: userId,
                    swiperUserId: currentUserId,
                    direction: "right"
                )

                if isMatch {
                    // It's a match!
                    await MainActor.run {
                        matchedUser = user
                        showMatchAnimation = true
                        HapticManager.shared.match()
                    }

                    // Track match
                    try await AnalyticsManager.shared.trackMatch(
                        user1Id: currentUserId,
                        user2Id: userId
                    )
                } else {
                    // Show toast for regular like (no match)
                    await MainActor.run {
                        let truncatedName = user.fullName.count > 20 ? String(user.fullName.prefix(20)) + "..." : user.fullName
                        showToast(
                            message: "Liked \(truncatedName)!",
                            icon: "heart.fill",
                            color: .pink
                        )
                    }
                }
            } catch {
                Logger.shared.error("Error sending like", category: .matching, error: error)
                await MainActor.run {
                    showToast(
                        message: "Failed to send like. Try again.",
                        icon: "exclamationmark.triangle.fill",
                        color: .red
                    )
                }
            }
        }
    }

    private func handleFavorite(user: User) {
        guard let userId = user.id else {
            showToast(
                message: "Unable to save profile",
                icon: "exclamationmark.triangle.fill",
                color: .red
            )
            return
        }

        let wasFavorited = favorites.contains(userId)

        if wasFavorited {
            // Remove from favorites (optimistic update)
            favorites.remove(userId)
            showToast(
                message: "Removed from saved",
                icon: "star.slash",
                color: .orange
            )

            // Remove from SavedProfilesViewModel
            if let savedProfile = savedProfilesViewModel.savedProfiles.first(where: { $0.user.id == userId }) {
                savedProfilesViewModel.unsaveProfile(savedProfile)
            }
        } else {
            // Add to favorites (optimistic update)
            favorites.insert(userId)
            let truncatedName = user.fullName.count > 20 ? String(user.fullName.prefix(20)) + "..." : user.fullName
            showToast(
                message: "Saved \(truncatedName)",
                icon: "star.fill",
                color: .orange
            )

            // Save to SavedProfilesViewModel
            Task {
                await savedProfilesViewModel.saveProfile(user: user)

                // Small delay to ensure state update has propagated
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

                // Check if save succeeded (will be in savedProfiles array)
                await MainActor.run {
                    let saveSucceeded = savedProfilesViewModel.savedProfiles.contains(where: { $0.user.id == userId })
                    if !saveSucceeded {
                        // Revert optimistic update on failure
                        favorites.remove(userId)
                        showToast(
                            message: "Failed to save. Try again.",
                            icon: "exclamationmark.triangle.fill",
                            color: .red
                        )
                        Logger.shared.warning("Save validation failed for user \(userId)", category: .general)
                    } else {
                        Logger.shared.debug("Save validated successfully for user \(userId)", category: .general)
                    }
                }
            }
        }

        HapticManager.shared.impact(.light)
    }

    private func handleMessage(user: User) {
        guard let currentUserId = authService.currentUser?.id,
              let userId = user.id else {
            showToast(
                message: "Unable to send message. Please try again.",
                icon: "exclamationmark.triangle.fill",
                color: .red
            )
            return
        }

        // Check if users have matched
        Task {
            do {
                let hasMatched = try await MatchService.shared.hasMatched(user1Id: currentUserId, user2Id: userId)

                await MainActor.run {
                    if hasMatched {
                        // Navigate to Messages tab
                        selectedTab = 2
                        HapticManager.shared.impact(.medium)
                        Logger.shared.debug("Navigate to messages for user: \(user.fullName)", category: .messaging)
                    } else {
                        // Not matched yet - show info
                        let truncatedName = user.fullName.count > 20 ? String(user.fullName.prefix(20)) + "..." : user.fullName
                        showToast(
                            message: "Like \(truncatedName) first to message",
                            icon: "heart.fill",
                            color: .pink
                        )
                    }
                }
            } catch {
                Logger.shared.error("Error checking match status", category: .matching, error: error)
                await MainActor.run {
                    showToast(
                        message: "Unable to check match status",
                        icon: "exclamationmark.triangle.fill",
                        color: .red
                    )
                }
            }
        }
    }
}

// MARK: - Photo Gallery View

struct PhotoGalleryView: View {
    @Environment(\.dismiss) var dismiss
    let user: User

    @State private var selectedPhotoIndex = 0

    // Filter out empty photo URLs
    private var validPhotos: [String] {
        user.photos.filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if validPhotos.isEmpty {
                    // Show profile image if no photos
                    VStack(spacing: 16) {
                        CachedCardImage(url: URL(string: user.profileImageURL))
                            .scaledToFit()
                            .cornerRadius(12)
                            .padding()

                        Text("No additional photos")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else {
                    // Photo gallery
                    TabView(selection: $selectedPhotoIndex) {
                        ForEach(Array(validPhotos.enumerated()), id: \.offset) { index, photoURL in
                            CachedCardImage(url: URL(string: photoURL))
                                .scaledToFit()
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                }
            }
            .navigationTitle("\(user.fullName)'s Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

#Preview {
    FeedDiscoverView(selectedTab: .constant(0))
        .environmentObject(AuthService.shared)
}
