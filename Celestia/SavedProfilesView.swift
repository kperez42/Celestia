//
//  SavedProfilesView.swift
//  Celestia
//
//  Shows bookmarked/saved profiles for later viewing
//

import SwiftUI
import FirebaseFirestore

struct SavedProfilesView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var viewModel = SavedProfilesViewModel.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedUser: User?
    @State private var showUserDetail = false
    @State private var showClearAllConfirmation = false
    @State private var selectedTab = 0

    private let tabs = ["My Saves", "Viewed Me", "Saved Me"]

    var body: some View {
        VStack(spacing: 0) {
            // Custom gradient header (like Messages and Matches)
            headerView

            // Tab selector
            tabSelector

            // Main content
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                // PERFORMANCE: Only show loading skeleton on first load when we have no cached data
                // If cached data exists, show it instantly while refresh happens in background
                let hasAnyData = !viewModel.savedProfiles.isEmpty || !viewModel.viewedProfiles.isEmpty || !viewModel.savedYouProfiles.isEmpty
                if viewModel.isLoading && !hasAnyData {
                    loadingView
                } else if !viewModel.errorMessage.isEmpty {
                    errorStateView
                } else {
                    TabView(selection: $selectedTab) {
                        allSavedTab.tag(0)
                        viewedTab.tag(1)
                        savedYouTab.tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            // Load data once when view first appears
            // Silent refresh (no skeleton) if we already have cached data
            await viewModel.loadSavedProfiles()
            await viewModel.loadViewedProfiles()
            await viewModel.loadSavedYouProfiles()
        }
        .sheet(item: $selectedUser) { user in
            UserDetailView(user: user)
                .environmentObject(authService)
        }
        .confirmationDialog(
            "Clear All Saved Profiles?",
            isPresented: $showClearAllConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All (\(viewModel.savedProfiles.count))", role: .destructive) {
                HapticManager.shared.notification(.warning)
                viewModel.clearAllSaved()
            }
            Button("Cancel", role: .cancel) {
                HapticManager.shared.impact(.light)
            }
        } message: {
            Text("This will permanently remove all \(viewModel.savedProfiles.count) saved profiles. This action cannot be undone.")
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button {
                    HapticManager.shared.impact(.light)
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Text(tabs[index])
                                .font(.subheadline)
                                .fontWeight(selectedTab == index ? .bold : .medium)

                            // Show count badge
                            let count = countForTab(index)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(selectedTab == index ? .white : .orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(selectedTab == index ? Color.orange : Color.orange.opacity(0.2))
                                    )
                            }
                        }
                        .foregroundColor(selectedTab == index ? .primary : .secondary)

                        // Indicator line
                        Rectangle()
                            .fill(
                                selectedTab == index ?
                                LinearGradient(
                                    colors: [.orange, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ) :
                                LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(height: 3)
                            .cornerRadius(1.5)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .background(Color(.systemBackground))
    }

    private func countForTab(_ index: Int) -> Int {
        switch index {
        case 0: return viewModel.savedProfiles.count
        case 1: return viewModel.viewedProfiles.count
        case 2: return viewModel.savedYouProfiles.count
        default: return 0
        }
    }

    // MARK: - Tab Content

    private var allSavedTab: some View {
        Group {
            if viewModel.savedProfiles.isEmpty {
                emptyStateView(message: "No saved profiles yet", hint: "Tap the bookmark icon on any profile to save it")
            } else {
                profilesGrid(profiles: viewModel.savedProfiles)
            }
        }
    }

    private var viewedTab: some View {
        Group {
            if viewModel.viewedProfiles.isEmpty {
                emptyStateView(message: "No one viewed you yet", hint: "When someone views your profile, they'll appear here")
            } else {
                viewedProfilesGrid(profiles: viewModel.viewedProfiles)
            }
        }
    }

    private var savedYouTab: some View {
        Group {
            if viewModel.savedYouProfiles.isEmpty {
                emptyStateView(message: "No one saved you yet", hint: "When someone saves your profile, they'll appear here")
            } else {
                savedYouGrid(profiles: viewModel.savedYouProfiles)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color.orange.opacity(0.9),
                    Color.pink.opacity(0.7),
                    Color.purple.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Decorative elements
            GeometryReader { geo in
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)
                    .offset(x: -30, y: 20)

                Circle()
                    .fill(Color.yellow.opacity(0.15))
                    .frame(width: 60, height: 60)
                    .blur(radius: 15)
                    .offset(x: geo.size.width - 50, y: 40)
            }

            VStack(spacing: 12) {
                HStack(alignment: .center) {
                    // Title section
                    HStack(spacing: 12) {
                        Image(systemName: "bookmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .yellow.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .white.opacity(0.4), radius: 10)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Saved")
                                .font(.largeTitle.weight(.bold))
                                .foregroundColor(.white)

                            HStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Image(systemName: "bookmark.fill")
                                        .font(.caption)
                                    Text("\(viewModel.savedProfiles.count)")
                                        .fontWeight(.semibold)
                                }

                                if viewModel.viewedProfiles.count > 0 {
                                    Circle()
                                        .fill(Color.white.opacity(0.5))
                                        .frame(width: 4, height: 4)

                                    HStack(spacing: 4) {
                                        Image(systemName: "eye")
                                            .font(.caption)
                                        Text("\(viewModel.viewedProfiles.count) views")
                                            .fontWeight(.semibold)
                                    }
                                }

                                if viewModel.savedYouProfiles.count > 0 {
                                    Circle()
                                        .fill(Color.white.opacity(0.5))
                                        .frame(width: 4, height: 4)

                                    HStack(spacing: 4) {
                                        Image(systemName: "person.2.fill")
                                            .font(.caption)
                                        Text("\(viewModel.savedYouProfiles.count) saved you")
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.95))
                        }
                    }

                    Spacer()

                    // Clear all button
                    if !viewModel.savedProfiles.isEmpty {
                        Button {
                            showClearAllConfirmation = true
                            HapticManager.shared.impact(.light)
                        } label: {
                            Image(systemName: "trash.circle.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                .padding(.bottom, 16)
            }
        }
        .frame(height: 140)
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }

    // MARK: - Profiles Grid

    private func profilesGrid(profiles: [SavedProfile]) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Saved profiles grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(profiles) { saved in
                        SavedProfileCard(
                            savedProfile: saved,
                            isUnsaving: viewModel.unsavingProfileId == saved.id,
                            onTap: {
                                selectedUser = saved.user
                                HapticManager.shared.impact(.light)
                            },
                            onUnsave: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    viewModel.unsaveProfile(saved)
                                }
                                HapticManager.shared.impact(.medium)
                            }
                        )
                        .onAppear {
                            // PERFORMANCE: Prefetch images as cards appear in viewport
                            ImageCache.shared.prefetchUserPhotosHighPriority(user: saved.user)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top)
            .padding(.bottom, 20)
        }
        .refreshable {
            HapticManager.shared.impact(.light)
            await viewModel.loadSavedProfiles(forceRefresh: true)
            HapticManager.shared.notification(.success)
        }
    }

    // MARK: - Saved You Grid (simpler cards for people who saved your profile)

    private func savedYouGrid(profiles: [SavedYouProfile]) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(profiles) { profile in
                        SavedYouCard(
                            profile: profile,
                            onTap: {
                                selectedUser = profile.user
                                HapticManager.shared.impact(.light)
                            }
                        )
                        .onAppear {
                            // PERFORMANCE: Prefetch images as cards appear in viewport
                            ImageCache.shared.prefetchUserPhotosHighPriority(user: profile.user)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top)
            .padding(.bottom, 20)
        }
        .refreshable {
            HapticManager.shared.impact(.light)
            await viewModel.loadSavedYouProfiles()
            HapticManager.shared.notification(.success)
        }
    }

    // MARK: - Viewed Profiles Grid (profiles the current user has viewed)

    private func viewedProfilesGrid(profiles: [ViewedProfile]) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(profiles) { profile in
                        ViewedProfileCard(
                            profile: profile,
                            onTap: {
                                selectedUser = profile.user
                                HapticManager.shared.impact(.light)
                            }
                        )
                        .onAppear {
                            // PERFORMANCE: Prefetch images as cards appear in viewport
                            ImageCache.shared.prefetchUserPhotosHighPriority(user: profile.user)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top)
            .padding(.bottom, 20)
        }
        .refreshable {
            HapticManager.shared.impact(.light)
            await viewModel.loadViewedProfiles()
            HapticManager.shared.notification(.success)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Stats header skeleton
                HStack(spacing: 20) {
                    SkeletonView()
                        .frame(height: 80)
                        .cornerRadius(12)

                    SkeletonView()
                        .frame(height: 80)
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                // Skeleton grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(0..<6, id: \.self) { _ in
                        SavedProfileCardSkeleton()
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top)
        }
    }

    // MARK: - Error State

    private var errorStateView: some View {
        VStack(spacing: 24) {
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

                Text(viewModel.errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                Task {
                    await viewModel.loadSavedProfiles()
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
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Empty State

    private func emptyStateView(message: String, hint: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))

            VStack(spacing: 8) {
                Text(message)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(hint)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // CTA button to go back to discovering
            Button {
                dismiss()
                HapticManager.shared.impact(.light)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.body.weight(.semibold))
                    Text("Start Discovering")
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
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Saved Profile Card

struct SavedProfileCard: View {
    let savedProfile: SavedProfile
    let isUnsaving: Bool
    let onTap: () -> Void
    let onUnsave: () -> Void

    // Fixed height for consistent card sizing across all grid cards
    private let imageHeight: CGFloat = 180

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Profile image section - fixed height for consistent card sizes
                ZStack {
                    Group {
                        if let imageURL = savedProfile.user.photos.first, let url = URL(string: imageURL) {
                            CachedCardImage(url: url)
                                .frame(height: imageHeight)
                        } else {
                            LinearGradient(
                                colors: [.purple.opacity(0.6), .pink.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }

                    // Loading overlay when unsaving
                    if isUnsaving {
                        ZStack {
                            Color.black.opacity(0.6)

                            VStack(spacing: 12) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.3)

                                Text("Removing...")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .frame(height: imageHeight)
                .frame(maxWidth: .infinity)
                .clipped()
                .contentShape(Rectangle())
                .cornerRadius(16, corners: [.topLeft, .topRight])

                // User info section with white background - matching Likes page
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(savedProfile.user.fullName)
                            .font(.system(size: 17, weight: .semibold))
                            .lineLimit(1)

                        Text("\(savedProfile.user.age)")
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)

                        Spacer()

                        if savedProfile.user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.pink)
                        Text(savedProfile.user.location)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .opacity(isUnsaving ? 0.5 : 1.0)
            }
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isUnsaving)
    }
}

// MARK: - Saved Profile Card Skeleton

struct SavedProfileCardSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            // Image area skeleton - matching card height
            SkeletonView()
                .frame(height: 180)
                .clipped()

            // User info skeleton
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    SkeletonView()
                        .frame(width: 90, height: 18)
                        .cornerRadius(6)

                    SkeletonView()
                        .frame(width: 30, height: 18)
                        .cornerRadius(6)

                    Spacer()
                }

                SkeletonView()
                    .frame(width: 110, height: 14)
                    .cornerRadius(6)

                SkeletonView()
                    .frame(width: 100, height: 14)
                    .cornerRadius(6)
            }
            .padding(12)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
    }
}

// MARK: - Saved You Profile Model (people who saved your profile)

struct SavedYouProfile: Identifiable, Equatable {
    let id: String
    let user: User
    let savedAt: Date
}

// MARK: - Viewed Profile Model (profiles the current user has viewed)

struct ViewedProfile: Identifiable, Equatable {
    let id: String
    let user: User
    let viewedAt: Date
}

// MARK: - Saved You Card (simpler card for people who saved your profile)

struct SavedYouCard: View {
    let profile: SavedYouProfile
    let onTap: () -> Void

    // Fixed height for consistent card sizing across all grid cards
    private let imageHeight: CGFloat = 180

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Profile image section - fixed height for consistent card sizes
                Group {
                    if let imageURL = profile.user.photos.first, let url = URL(string: imageURL) {
                        CachedCardImage(url: url)
                            .frame(height: imageHeight)
                    } else {
                        LinearGradient(
                            colors: [.blue.opacity(0.6), .purple.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                .frame(height: imageHeight)
                .frame(maxWidth: .infinity)
                .clipped()
                .contentShape(Rectangle())
                .cornerRadius(16, corners: [.topLeft, .topRight])

                // User info section with white background - matching Likes page
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(profile.user.fullName)
                            .font(.system(size: 17, weight: .semibold))
                            .lineLimit(1)

                        Text("\(profile.user.age)")
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)

                        Spacer()

                        if profile.user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.pink)
                        Text(profile.user.location)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
            }
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Viewed Profile Card (for profiles the current user has viewed)

struct ViewedProfileCard: View {
    let profile: ViewedProfile
    let onTap: () -> Void

    // Fixed height for consistent card sizing across all grid cards
    private let imageHeight: CGFloat = 180

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Profile image section - fixed height for consistent card sizes
                Group {
                    if let imageURL = profile.user.photos.first, let url = URL(string: imageURL) {
                        CachedCardImage(url: url)
                            .frame(height: imageHeight)
                    } else {
                        LinearGradient(
                            colors: [.green.opacity(0.6), .teal.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                .frame(height: imageHeight)
                .frame(maxWidth: .infinity)
                .clipped()
                .contentShape(Rectangle())
                .cornerRadius(16, corners: [.topLeft, .topRight])

                // User info section with white background
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(profile.user.fullName)
                            .font(.system(size: 17, weight: .semibold))
                            .lineLimit(1)

                        Text("\(profile.user.age)")
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)

                        Spacer()

                        if profile.user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                        Text(profile.viewedAt.timeAgoDisplay())
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
            }
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Saved Profile Model

struct SavedProfile: Identifiable, Equatable {
    let id: String
    let user: User
    let savedAt: Date
    let note: String?

    init(id: String, user: User, savedAt: Date, note: String?) {
        self.id = id
        self.user = user
        self.savedAt = savedAt
        self.note = note
    }
}

// MARK: - View Model

@MainActor
class SavedProfilesViewModel: ObservableObject {
    // Singleton instance for shared state across views
    static let shared = SavedProfilesViewModel()

    @Published var savedProfiles: [SavedProfile] = []
    @Published var savedYouProfiles: [SavedYouProfile] = []
    @Published var viewedProfiles: [ViewedProfile] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var unsavingProfileId: String?

    private let db = Firestore.firestore()

    // PERFORMANCE: Cache management to reduce database reads
    private var lastFetchTime: Date?
    private var lastViewedFetchTime: Date?
    private let cacheDuration: TimeInterval = 300 // 5 minutes
    private var cachedForUserId: String?

    // Private initializer for singleton pattern
    private init() {}

    func loadSavedProfiles(forceRefresh: Bool = false) async {
        guard let currentUserId = AuthService.shared.currentUser?.effectiveId else { return }

        // PERFORMANCE FIX: Check cache first (5-minute TTL)
        // Prevents 6+ database reads every time view appears
        if !forceRefresh,
           let lastFetch = lastFetchTime,
           cachedForUserId == currentUserId,
           !savedProfiles.isEmpty,
           Date().timeIntervalSince(lastFetch) < cacheDuration {
            Logger.shared.debug("SavedProfiles cache HIT - using cached data", category: .performance)
            let cacheAge = Date().timeIntervalSince(lastFetch)
            AnalyticsManager.shared.logEvent(.performance, parameters: [
                "type": "saved_profiles_cache_hit",
                "cache_age_seconds": cacheAge,
                "profiles_count": savedProfiles.count
            ])
            return // Use cached data
        }

        Logger.shared.debug("SavedProfiles cache MISS - fetching from database", category: .performance)

        // Only show loading skeleton if we have no existing data to display
        // This prevents flickering when refreshing with cached data already visible
        let shouldShowLoading = savedProfiles.isEmpty
        if shouldShowLoading {
            isLoading = true
        }
        errorMessage = ""
        defer {
            if shouldShowLoading {
                isLoading = false
            }
        }

        do {
            // Step 1: Fetch all saved profile references
            let savedSnapshot = try await db.collection("saved_profiles")
                .whereField("userId", isEqualTo: currentUserId)
                .order(by: "savedAt", descending: true)
                .getDocuments()

            // Step 2: Extract user IDs and metadata
            var savedMetadata: [(id: String, userId: String, savedAt: Date, note: String?)] = []
            for doc in savedSnapshot.documents {
                let data = doc.data()
                if let savedUserId = data["savedUserId"] as? String,
                   let savedAt = (data["savedAt"] as? Timestamp)?.dateValue() {
                    savedMetadata.append((
                        id: doc.documentID,
                        userId: savedUserId,
                        savedAt: savedAt,
                        note: data["note"] as? String
                    ))
                }
            }

            guard !savedMetadata.isEmpty else {
                savedProfiles = []
                Logger.shared.info("No saved profiles found", category: .general)
                return
            }

            // Step 3: Batch fetch users (Firestore whereIn limit is 10, so chunk requests)
            let userIds = savedMetadata.map { $0.userId }
            var fetchedUsers: [String: User] = [:]

            // Chunk user IDs into groups of 10 (Firestore whereIn limit)
            let chunkedUserIds = userIds.chunked(into: 10)

            // Only query Firestore if there are remaining user IDs to fetch
            for chunk in chunkedUserIds where !chunk.isEmpty {
                let usersSnapshot = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()

                for doc in usersSnapshot.documents {
                    if let user = try? doc.data(as: User.self), let userId = user.id {
                        fetchedUsers[userId] = user
                    }
                }
            }

            // Step 4: Combine metadata with fetched users
            var profiles: [SavedProfile] = []
            var skippedCount = 0

            for metadata in savedMetadata {
                if let user = fetchedUsers[metadata.userId] {
                    profiles.append(SavedProfile(
                        id: metadata.id,
                        user: user,
                        savedAt: metadata.savedAt,
                        note: metadata.note
                    ))
                } else {
                    // User no longer exists or failed to fetch
                    skippedCount += 1
                    Logger.shared.warning("Skipped saved profile - user not found: \(metadata.userId)", category: .general)
                }
            }

            savedProfiles = profiles

            // PERFORMANCE: Update cache timestamp after successful fetch
            lastFetchTime = Date()
            cachedForUserId = currentUserId

            if skippedCount > 0 {
                Logger.shared.warning("Loaded \(profiles.count) saved profiles (\(skippedCount) skipped) - cached for 5 min", category: .general)
            } else {
                Logger.shared.info("Loaded \(profiles.count) saved profiles - cached for 5 min", category: .general)
            }
        } catch {
            errorMessage = error.localizedDescription
            Logger.shared.error("Error loading saved profiles", category: .general, error: error)
        }
    }

    /// Clear cache and force reload
    func clearCache() {
        lastFetchTime = nil
        lastViewedFetchTime = nil
        cachedForUserId = nil
        Logger.shared.info("SavedProfiles cache cleared", category: .performance)
    }

    /// Load profiles of people who saved your profile
    func loadSavedYouProfiles() async {
        guard let currentUserId = AuthService.shared.currentUser?.effectiveId else {
            return
        }

        do {
            // Query for profiles where savedUserId is the current user (others saved you)
            let snapshot = try await db.collection("saved_profiles")
                .whereField("savedUserId", isEqualTo: currentUserId)
                .order(by: "savedAt", descending: true)
                .getDocuments()

            var metadata: [(id: String, userId: String, savedAt: Date)] = []
            for doc in snapshot.documents {
                let data = doc.data()
                if let userId = data["userId"] as? String,
                   let savedAt = (data["savedAt"] as? Timestamp)?.dateValue() {
                    metadata.append((id: doc.documentID, userId: userId, savedAt: savedAt))
                }
            }

            guard !metadata.isEmpty else {
                savedYouProfiles = []
                return
            }

            // Batch fetch users
            let userIds = metadata.map { $0.userId }
            var fetchedUsers: [String: User] = [:]

            for chunk in userIds.chunked(into: 10) {
                let usersSnapshot = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()

                for userDoc in usersSnapshot.documents {
                    if let user = try? userDoc.data(as: User.self), let userId = user.id {
                        fetchedUsers[userId] = user
                    }
                }
            }

            var profiles: [SavedYouProfile] = []
            for meta in metadata {
                if let user = fetchedUsers[meta.userId] {
                    profiles.append(SavedYouProfile(id: meta.id, user: user, savedAt: meta.savedAt))
                }
            }

            savedYouProfiles = profiles
            Logger.shared.info("Loaded \(profiles.count) users who saved your profile", category: .general)
        } catch {
            Logger.shared.error("Error loading saved you profiles", category: .general, error: error)
        }
    }

    /// Load profiles of people who viewed your profile
    func loadViewedProfiles() async {
        guard let currentUserId = AuthService.shared.currentUser?.effectiveId else {
            return
        }

        // Check cache first
        if let lastFetch = lastViewedFetchTime,
           !viewedProfiles.isEmpty,
           Date().timeIntervalSince(lastFetch) < cacheDuration {
            Logger.shared.debug("ViewedProfiles cache HIT - using cached data", category: .performance)
            return
        }

        do {
            // Query for profiles where others viewed the current user
            let snapshot = try await db.collection("profileViews")
                .whereField("viewedUserId", isEqualTo: currentUserId)
                .order(by: "timestamp", descending: true)
                .limit(to: 50)
                .getDocuments()

            var metadata: [(id: String, viewerUserId: String, viewedAt: Date)] = []
            var seenUserIds = Set<String>()

            for doc in snapshot.documents {
                let data = doc.data()
                if let viewerUserId = data["viewerUserId"] as? String,
                   let timestamp = (data["timestamp"] as? Timestamp)?.dateValue(),
                   !seenUserIds.contains(viewerUserId) {
                    // Only keep the most recent view from each viewer
                    seenUserIds.insert(viewerUserId)
                    metadata.append((id: doc.documentID, viewerUserId: viewerUserId, viewedAt: timestamp))
                }
            }

            guard !metadata.isEmpty else {
                viewedProfiles = []
                lastViewedFetchTime = Date()
                return
            }

            // Batch fetch users who viewed your profile
            let userIds = metadata.map { $0.viewerUserId }
            var fetchedUsers: [String: User] = [:]

            for chunk in userIds.chunked(into: 10) {
                let usersSnapshot = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()

                for userDoc in usersSnapshot.documents {
                    if let user = try? userDoc.data(as: User.self), let userId = user.id {
                        fetchedUsers[userId] = user
                    }
                }
            }

            var profiles: [ViewedProfile] = []
            for meta in metadata {
                if let user = fetchedUsers[meta.viewerUserId] {
                    profiles.append(ViewedProfile(id: meta.id, user: user, viewedAt: meta.viewedAt))
                }
            }

            viewedProfiles = profiles
            lastViewedFetchTime = Date()
            Logger.shared.info("Loaded \(profiles.count) users who viewed your profile - cached for 5 min", category: .general)
        } catch {
            Logger.shared.error("Error loading viewed profiles", category: .general, error: error)
        }
    }

    func unsaveProfile(_ profile: SavedProfile) {
        guard let currentUserId = AuthService.shared.currentUser?.effectiveId else { return }

        // Set loading state
        unsavingProfileId = profile.id

        Task {
            do {
                // Remove from Firestore
                try await db.collection("saved_profiles").document(profile.id).delete()

                // Update local state
                await MainActor.run {
                    savedProfiles.removeAll { $0.id == profile.id }
                    unsavingProfileId = nil
                    // PERFORMANCE: Invalidate cache so next load gets fresh data
                    lastFetchTime = nil
                }

                Logger.shared.info("Unsaved profile: \(profile.user.fullName)", category: .general)

                // Track analytics
                AnalyticsServiceEnhanced.shared.trackEvent(
                    .profileUnsaved,
                    properties: [
                        "unsavedUserId": profile.user.id,
                        "savedDuration": Date().timeIntervalSince(profile.savedAt)
                    ]
                )
            } catch {
                await MainActor.run {
                    unsavingProfileId = nil
                    errorMessage = "Failed to unsave profile. Please try again."
                }
                Logger.shared.error("Error unsaving profile", category: .general, error: error)

                // Auto-clear error after 3 seconds
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    await MainActor.run {
                        if errorMessage == "Failed to unsave profile. Please try again." {
                            errorMessage = ""
                        }
                    }
                }
            }
        }
    }

    func clearAllSaved() {
        guard let currentUserId = AuthService.shared.currentUser?.effectiveId else { return }

        Task {
            do {
                let snapshot = try await db.collection("saved_profiles")
                    .whereField("userId", isEqualTo: currentUserId)
                    .getDocuments()

                guard !snapshot.documents.isEmpty else {
                    savedProfiles = []
                    return
                }

                // BATCH FIX: Firestore batch limit is 500 documents
                // Chunk large deletions to avoid exceeding the limit
                let batchSize = 500
                let totalCount = snapshot.documents.count
                var deletedCount = 0

                for chunk in snapshot.documents.chunked(into: batchSize) {
                    let batch = db.batch()
                    for doc in chunk {
                        batch.deleteDocument(doc.reference)
                    }
                    try await batch.commit()
                    deletedCount += chunk.count

                    Logger.shared.debug("Deleted batch of \(chunk.count) saved profiles, total: \(deletedCount)/\(totalCount)", category: .general)
                }

                // ATOMICITY FIX: Only clear local state after ALL batches succeed
                savedProfiles = []

                // PERFORMANCE: Invalidate cache
                lastFetchTime = nil

                Logger.shared.info("Cleared all \(totalCount) saved profiles", category: .general)

                // Track analytics
                AnalyticsServiceEnhanced.shared.trackEvent(
                    .savedProfilesCleared,
                    properties: ["count": totalCount]
                )
            } catch {
                // ERROR HANDLING: Show user feedback on failure
                errorMessage = "Failed to clear saved profiles. Please try again."
                Logger.shared.error("Error clearing saved profiles", category: .general, error: error)

                // Auto-clear error after 3 seconds
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    await MainActor.run {
                        if errorMessage == "Failed to clear saved profiles. Please try again." {
                            errorMessage = ""
                        }
                    }
                }
            }
        }
    }

    func saveProfile(user: User, note: String? = nil) async {
        guard let currentUserId = AuthService.shared.currentUser?.effectiveId,
              let savedUserId = user.effectiveId else {
            let currentUser = AuthService.shared.currentUser
            Logger.shared.error("Cannot save profile: Missing user ID (currentUser.id=\(currentUser?.id ?? "nil"), currentUser.effectiveId=\(currentUser?.effectiveId ?? "nil"), savedUser.id=\(user.id ?? "nil"), savedUser.effectiveId=\(user.effectiveId ?? "nil"))", category: .general)
            return
        }

        // Check if already saved to prevent duplicates
        if savedProfiles.contains(where: { $0.user.effectiveId == savedUserId }) {
            Logger.shared.info("Profile already saved: \(user.fullName)", category: .general)
            return
        }

        do {
            let saveData: [String: Any] = [
                "userId": currentUserId,
                "savedUserId": savedUserId,
                "savedAt": Timestamp(date: Date()),
                "note": note ?? ""
            ]

            let docRef = try await db.collection("saved_profiles").addDocument(data: saveData)

            // Update local state immediately
            await MainActor.run {
                let newSaved = SavedProfile(
                    id: docRef.documentID,
                    user: user,
                    savedAt: Date(),
                    note: note
                )
                savedProfiles.insert(newSaved, at: 0)

                // PERFORMANCE: Update cache timestamp to keep it fresh
                lastFetchTime = Date()
                cachedForUserId = currentUserId
            }

            Logger.shared.info("Saved profile: \(user.fullName) (\(docRef.documentID))", category: .general)

            // Track analytics
            AnalyticsServiceEnhanced.shared.trackEvent(
                .profileSaved,
                properties: ["savedUserId": savedUserId]
            )
        } catch {
            Logger.shared.error("Error saving profile to Firestore", category: .general, error: error)
        }
    }
}

#Preview {
    SavedProfilesView()
        .environmentObject(AuthService.shared)
}
