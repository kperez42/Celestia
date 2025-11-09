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
                    .padding()
                }
                .refreshable {
                    await refreshFeed()
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
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
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
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
            .fullScreenCover(isPresented: $showMatchAnimation) {
                if let user = matchedUser {
                    MatchAnimationView(matchedUser: user)
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

    // MARK: - Data Loading

    private func loadUsers() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Simulate loading from backend
            // In production, fetch from Firestore with filters
            let testUsers = generateTestUsers()

            await MainActor.run {
                users = testUsers
                loadMoreUsers()
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

    private func handleLike(user: User) {
        guard let currentUserId = authService.currentUser?.id,
              let userId = user.id else { return }

        Task {
            do {
                // Track analytics
                try await AnalyticsManager.shared.trackSwipe(
                    swipedUserId: userId,
                    swiperUserId: currentUserId,
                    direction: .right
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
        // TODO: Navigate to messaging
        print("Message user: \(user.fullName)")
    }

    // MARK: - Test Data

    private func generateTestUsers() -> [User] {
        let names = ["Emma", "Olivia", "Ava", "Isabella", "Sophia", "Mia", "Charlotte", "Amelia", "Harper", "Evelyn", "Michael", "James", "David", "William", "Alexander", "Daniel", "Matthew", "Henry", "Jackson", "Sebastian"]
        let cities = ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "Philadelphia", "San Antonio", "San Diego", "Dallas", "San Jose"]
        let countries = ["USA", "Canada", "UK", "Australia"]

        return names.map { name in
            User(
                id: UUID().uuidString,
                email: "\(name.lowercased())@test.com",
                fullName: name,
                age: Int.random(in: 22...35),
                gender: ["Male", "Female"].randomElement()!,
                lookingFor: ["Men", "Women", "Everyone"].randomElement()!,
                bio: "Love adventure and good coffee ☕️",
                location: cities.randomElement()!,
                country: countries.randomElement()!,
                languages: ["English"],
                interests: ["Travel", "Coffee", "Music", "Hiking"].shuffled().prefix(3).map { $0 },
                photos: [],
                profileImageURL: "",
                isPremium: Bool.random(),
                isVerified: Bool.random(),
                ageRangeMin: 22,
                ageRangeMax: 35
            )
        }
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
