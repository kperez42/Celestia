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

    @State private var users: [User] = []
    @State private var displayedUsers: [User] = []
    @State private var currentPage = 0
    @State private var isLoading = false
    @State private var showFilters = false
    @State private var selectedUser: User?
    @State private var showUserDetail = false
    @State private var showPhotoGallery = false
    @State private var showMatchAnimation = false
    @State private var matchedUser: User?
    @State private var favorites: Set<String> = []

    private let usersPerPage = 10
    private let preloadThreshold = 3 // Load more when 3 items from bottom

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                // Main scroll view
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(displayedUsers.enumerated()), id: \.element.id) { index, user in
                            ProfileFeedCard(
                                user: user,
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

                        // Loading indicator
                        if isLoading {
                            ProgressView()
                                .padding()
                        }

                        // End of results
                        if !isLoading && displayedUsers.count >= users.count && users.count > 0 {
                            endOfResultsView
                        }

                        // Empty state
                        if !isLoading && displayedUsers.isEmpty {
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

                // Match animation overlay
                if showMatchAnimation {
                    matchCelebrationView
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
            }
            .sheet(isPresented: $showUserDetail) {
                if let user = selectedUser {
                    UserDetailView(user: user)
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
        }
        return
        #endif

        guard let currentUserId = authService.currentUser?.id else { return }

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
                loadMoreUsers()
            }
        } catch {
            print("❌ Error loading users: \(error)")
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

    private func handleLike(user: User) {
        guard let currentUserId = authService.currentUser?.id,
              let userId = user.id else { return }

        Task {
            do {
                // Track analytics
                try await AnalyticsManager.shared.trackSwipe(
                    swipedUserId: userId,
                    swiperUserId: currentUserId,
                    direction: "right"
                )

                // Simulate match (10% chance)
                if Int.random(in: 0...9) == 0 {
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
                }
            } catch {
                print("❌ Error tracking like: \(error)")
            }
        }
    }

    private func handleFavorite(user: User) {
        guard let userId = user.id else { return }

        if favorites.contains(userId) {
            favorites.remove(userId)
        } else {
            favorites.insert(userId)
        }

        // Save to UserDefaults
        UserDefaults.standard.set(Array(favorites), forKey: "favoriteUserIds")
    }

    private func handleMessage(user: User) {
        selectedUser = user
        // NOTE: Navigation to messaging should be implemented using NavigationPath or coordinator
        // For now, user should match first before messaging
        print("Message user: \(user.fullName)")
    }
}

// MARK: - Photo Gallery View

struct PhotoGalleryView: View {
    @Environment(\.dismiss) var dismiss
    let user: User

    @State private var selectedPhotoIndex = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if user.photos.isEmpty {
                    // Show profile image if no photos
                    AsyncImage(url: URL(string: user.profileImageURL)) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        Color.gray
                    }
                } else {
                    // Photo gallery
                    TabView(selection: $selectedPhotoIndex) {
                        ForEach(Array(user.photos.enumerated()), id: \.offset) { index, photoURL in
                            AsyncImage(url: URL(string: photoURL)) { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                            } placeholder: {
                                ProgressView()
                            }
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
    FeedDiscoverView()
        .environmentObject(AuthService.shared)
}
