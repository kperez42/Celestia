//
//  FeedDiscoverView.swift
//  Celestia
//
//  Feed-style discovery view with vertical scrolling and pagination
//

import SwiftUI
import FirebaseFirestore

struct FeedDiscoverView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var filters = DiscoveryFilters.shared
    @ObservedObject private var savedProfilesViewModel = SavedProfilesViewModel.shared
    @ObservedObject private var likesViewModel = LikesViewModel.shared
    @Binding var selectedTab: Int

    @State private var users: [User] = []
    @State private var displayedUsers: [User] = []
    @State private var currentPage = 0
    @State private var isLoading = false
    @State private var isInitialLoad = true
    @State private var showFilters = false
    @State private var selectedUserForDetail: User?
    @State private var selectedUserForPhotos: User?
    @State private var showMatchAnimation = false
    @State private var matchedUser: User?
    @State private var favorites: Set<String> = []
    @State private var likedUsers: Set<String> = []
    @State private var errorMessage: String = ""
    @State private var showOwnProfileDetail = false
    @State private var showEditProfile = false

    // Direct messaging state - using dedicated struct for item-based presentation
    @State private var chatPresentation: ChatPresentation?
    @State private var showPremiumUpgrade = false
    @State private var upgradeContextMessage = ""

    struct ChatPresentation: Identifiable {
        let id = UUID()
        let match: Match
        let user: User
    }

    // Action feedback toast
    @State private var showActionToast = false
    @State private var toastMessage = ""
    @State private var toastIcon = ""
    @State private var toastColor: Color = .green

    private let usersPerPage = 10
    private let preloadThreshold = 3 // Load more when 3 items from bottom

    // Helper gradient for buttons
    private var buttonGradient: LinearGradient {
        LinearGradient(
            colors: [.purple, .pink],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        NavigationStack {
            mainContent
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
                .sheet(item: $selectedUserForDetail) { user in
                    UserDetailView(
                        user: user,
                        initialIsLiked: likedUsers.contains(user.effectiveId ?? ""),
                        onLikeChanged: { isLiked in
                            // Sync like state with feed cards
                            if let userId = user.effectiveId {
                                if isLiked {
                                    likedUsers.insert(userId)
                                } else {
                                    likedUsers.remove(userId)
                                }
                            }
                        }
                    )
                    .environmentObject(authService)
                }
                .sheet(item: $selectedUserForPhotos) { user in
                    PhotoGalleryView(user: user)
                }
                .onAppear {
                    Logger.shared.debug("FeedDiscoverView appeared - users.count: \(users.count), currentUser.lookingFor: \(authService.currentUser?.lookingFor ?? "nil")", category: .general)

                    // BUGFIX: Always sync favorites when view appears
                    // This ensures save state is correct after navigating from other tabs
                    syncFavorites()
                    loadLikedUsers()

                    if users.isEmpty {
                        Task {
                            await loadUsers()
                            await savedProfilesViewModel.loadSavedProfiles()
                            syncFavorites()
                        }
                    }
                }
                .onChange(of: filters.hasActiveFilters) { _ in
                    Logger.shared.debug("Filters changed - reloading users", category: .general)
                    Task {
                        await reloadWithFilters()
                    }
                }
                .onChange(of: authService.currentUser?.lookingFor) { oldValue, newValue in
                    Logger.shared.debug("lookingFor changed from \(oldValue ?? "nil") to \(newValue ?? "nil") - reloading users", category: .general)
                    Task {
                        await reloadWithFilters()
                    }
                }
                .onChange(of: savedProfilesViewModel.savedProfiles) { oldProfiles, newProfiles in
                    // PERFORMANCE: Only sync if the actual user IDs changed
                    // This prevents unnecessary re-renders when only metadata changes
                    let oldIds = Set(oldProfiles.compactMap { $0.user.effectiveId })
                    let newIds = Set(newProfiles.compactMap { $0.user.effectiveId })
                    if oldIds != newIds {
                        syncFavorites()
                    }
                }
                .sheet(isPresented: $showOwnProfileDetail) {
                    if let currentUser = authService.currentUser {
                        CurrentUserDetailView(
                            user: currentUser,
                            onEditProfile: {
                                showEditProfile = true
                            }
                        )
                    }
                }
                .sheet(isPresented: $showEditProfile) {
                    EditProfileView()
                        .environmentObject(authService)
                }
                .sheet(item: $chatPresentation) { presentation in
                    NavigationStack {
                        ChatView(match: presentation.match, otherUser: presentation.user)
                            .environmentObject(authService)
                    }
                }
                .sheet(isPresented: $showPremiumUpgrade) {
                    PremiumUpgradeView(contextMessage: upgradeContextMessage)
                        .environmentObject(authService)
                }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
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
                scrollContent
            }

            // Match animation overlay
            if showMatchAnimation {
                matchCelebrationView
                    .zIndex(1)
            }

            // Action feedback toast - highest z-index to ensure visibility
            if showActionToast {
                toastView
                    .zIndex(2)
            }
        }
    }

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16, pinnedViews: []) {
                // Current user's profile card
                if let currentUser = authService.currentUser {
                    CurrentUserProfileCard(user: currentUser) {
                        showOwnProfileDetail = true
                    }
                    .transition(.opacity)
                    .animation(.quick, value: authService.currentUser)
                }

                ForEach(Array(displayedUsers.enumerated()), id: \.element.effectiveId) { index, user in
                    ProfileFeedCard(
                        user: user,
                        currentUser: authService.currentUser,  // NEW: Pass current user for shared interests
                        initialIsFavorited: favorites.contains(user.effectiveId ?? ""),
                        initialIsLiked: likedUsers.contains(user.effectiveId ?? ""),
                        onLike: { completion in
                            handleLike(user: user, completion: completion)
                        },
                        onUnlike: { completion in
                            handleUnlike(user: user, completion: completion)
                        },
                        onFavorite: {
                            handleFavorite(user: user)
                        },
                        onMessage: {
                            handleMessage(user: user)
                        },
                        onViewPhotos: {
                            selectedUserForPhotos = user
                        },
                        onViewProfile: {
                            HapticManager.shared.impact(.light)
                            selectedUserForDetail = user
                        }
                    )
                    .onAppear {
                        // PERFORMANCE: Prefetch images as cards appear in viewport
                        ImageCache.shared.prefetchUserPhotosHighPriority(user: user)

                        if index == displayedUsers.count - preloadThreshold {
                            loadMoreUsers()
                        }
                    }
                    // Butter-smooth card appearance
                    .transition(.opacity)
                    .animation(.butterSmooth, value: displayedUsers.count)
                    .smoothScrollOptimized()
                }

                // Loading indicator with instant appearance
                if isLoading {
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(.purple)

                        Text("Finding more people...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 8)
                    )
                    .transition(.opacity)
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
            .padding(.bottom, 80) // Account for tab bar height
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .refreshable {
            HapticManager.shared.impact(.light)
            await refreshFeed()
            HapticManager.shared.notification(.success)
        }
    }

    private var toastView: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: toastIcon)
                    .font(.title3)
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text(toastMessage)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    // Show navigation hint for save toasts
                    if toastIcon == "star.fill" && toastColor == .orange {
                        Text("Tap to view saved profiles")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }

                Spacer()

                // Show arrow for save toasts to indicate it's tappable
                if toastIcon == "star.fill" && toastColor == .orange {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(toastColor)
            .cornerRadius(12)
            .shadow(color: toastColor.opacity(0.4), radius: 12, y: 6)
            .padding(.top, 16)
            .contentShape(Rectangle())
            .onTapGesture {
                // Navigate to Saved tab when tapping save toast
                if toastIcon == "star.fill" && toastColor == .orange {
                    HapticManager.shared.impact(.medium)
                    selectedTab = 3
                    withAnimation(.butterSmooth) {
                        showActionToast = false
                    }
                }
            }

            Spacer()
        }
        .transition(.opacity)
    }

    // MARK: - Helper Methods

    private func syncFavorites() {
        let userIds = savedProfilesViewModel.savedProfiles.compactMap { $0.user.effectiveId }
        favorites = Set(userIds)
        Logger.shared.debug("Favorites set synced: \(favorites.count) profiles", category: .general)
    }

    private func loadLikedUsers() {
        guard let currentUserId = authService.currentUser?.effectiveId else { return }

        Task {
            do {
                let likesSent = try await SwipeService.shared.getLikesSent(userId: currentUserId)
                await MainActor.run {
                    likedUsers = Set(likesSent)
                    Logger.shared.debug("Loaded \(likedUsers.count) liked users", category: .matching)
                }
            } catch {
                Logger.shared.error("Error loading liked users", category: .matching, error: error)
            }
        }
    }

    // MARK: - Initial Loading View

    private var initialLoadingView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { index in
                    ProfileFeedCardSkeleton()
                        // Instant skeleton appearance
                        .transition(.opacity)
                        .animation(.quick, value: isInitialLoad)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // Only show rejected view if profile was rejected
            // Pending users can still browse - they're just invisible to others
            if authService.currentUser?.profileStatus == "rejected" {
                rejectedProfileView
            } else {
                regularEmptyStateView
            }
        }
        .padding(40)
    }

    private var pendingApprovalView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Profile Under Review")
                .font(.title2)
                .fontWeight(.bold)

            Text("Your profile is being reviewed by our team to ensure a safe community. Once approved, you'll be able to discover and connect with others.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Profile created")
                        .font(.subheadline)
                }

                HStack(spacing: 8) {
                    Image(systemName: "hourglass.circle.fill")
                        .foregroundColor(.orange)
                    Text("Waiting for approval")
                        .font(.subheadline)
                }

                HStack(spacing: 8) {
                    Image(systemName: "circle")
                        .foregroundColor(.gray.opacity(0.5))
                    Text("Start discovering")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 12)

            Text("This usually takes less than 24 hours")
                .font(.caption)
                .foregroundColor(.secondary)

            Button {
                Task {
                    await refreshFeed()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Check Status")
                }
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
    }

    private var rejectedProfileView: some View {
        VStack(spacing: 20) {
            // Rejection icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.red, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Profile Needs Updates")
                .font(.title2)
                .fontWeight(.bold)

            // Show the reason
            if let reason = authService.currentUser?.profileStatusReason {
                Text(reason)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Fix instructions card
            if let instructions = authService.currentUser?.profileStatusFixInstructions {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundColor(.blue)
                        Text("How to Fix")
                            .font(.headline)
                    }

                    Text(instructions)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }

            // Action buttons
            VStack(spacing: 12) {
                Button {
                    showEditProfile = true
                } label: {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Edit Profile")
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
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

                Button {
                    Task {
                        // Re-submit profile for review
                        await resubmitForReview()
                    }
                } label: {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Submit for Review")
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(12)
                }
            }

            Text("After making changes, submit your profile for review. Our team typically responds within 24 hours.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func resubmitForReview() async {
        guard let userId = authService.currentUser?.effectiveId else { return }

        do {
            try await Firestore.firestore().collection("users").document(userId).updateData([
                "profileStatus": "pending",
                "profileStatusReason": FieldValue.delete(),
                "profileStatusReasonCode": FieldValue.delete(),
                "profileStatusFixInstructions": FieldValue.delete(),
                "profileStatusUpdatedAt": FieldValue.serverTimestamp()
            ])

            // Refresh user data
            await authService.fetchUser()

            HapticManager.shared.notification(.success)
        } catch {
            Logger.shared.error("Failed to resubmit profile", category: .general, error: error)
            HapticManager.shared.notification(.error)
        }
    }

    private var regularEmptyStateView: some View {
        VStack(spacing: 20) {
            // Check if user is pending approval
            if authService.currentUser?.profileStatus == "pending" {
                // Friendly pending message
                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Welcome to Celestia!")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Your profile is being reviewed by our team. This usually takes just a few hours. Once approved, you'll be visible to others and can start making connections!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Status indicator
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Account created")
                            .font(.subheadline)
                        Spacer()
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                        Text("Profile under review")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "heart.circle")
                            .foregroundColor(.gray.opacity(0.4))
                        Text("Start matching")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 5)
                .padding(.horizontal)

                Text("We'll notify you when your profile is approved")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)

            } else {
                // Regular empty state for approved users
                Image(systemName: "person.2.slash")
                    .font(.system(size: 60))
                    .foregroundColor(.gray.opacity(0.5))

                Text("No Profiles Found")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Check back later for new people in your area")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    Task {
                        await refreshFeed()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(buttonGradient)
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Error State

    private var errorStateView: some View {
        VStack(spacing: 24) {
            // Check if user is pending - show friendly message instead of error
            if authService.currentUser?.profileStatus == "pending" {
                Image(systemName: "sparkles")
                    .font(.system(size: 70))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 12) {
                    Text("Welcome to Celestia!")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Your profile is being reviewed. Once approved, you'll see other profiles here and can start connecting!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                        Text("Usually takes a few hours")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
            } else {
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
                    .background(buttonGradient)
                    .cornerRadius(12)
                }
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
                    // Navigate to Messages tab and open chat with matched user
                    if let matchedUser = matchedUser, let matchedUserId = matchedUser.id {
                        selectedTab = 2
                        showMatchAnimation = false
                        HapticManager.shared.notification(.success)

                        // Small delay to ensure Messages tab loads before opening chat
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            NotificationCenter.default.post(
                                name: .openChatWithUser,
                                object: nil,
                                userInfo: ["userId": matchedUserId, "user": matchedUser]
                            )
                        }

                        Logger.shared.info("Navigating to messages for match: \(matchedUserId)", category: .ui)
                    }
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
        guard let currentUserId = authService.currentUser?.effectiveId else {
            Logger.shared.error("loadUsers called but no currentUser", category: .database)
            await MainActor.run {
                isInitialLoad = false
            }
            return
        }

        isLoading = true

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

            let lookingForValue = authService.currentUser?.lookingFor
            Logger.shared.info("FeedDiscoverView: Loading users with filters - lookingFor: \(lookingForValue ?? "nil"), ageRange: \(ageRange?.description ?? "nil")", category: .database)

            // Fetch users from Firestore using UserService
            try await UserService.shared.fetchUsers(
                excludingUserId: currentUserId,
                lookingFor: lookingForValue,
                ageRange: ageRange ?? 18...99,
                limit: 50,
                reset: true
            )

            // FALLBACK: If no users found with strict filters, try with expanded age range
            if UserService.shared.users.isEmpty, let ageRange = ageRange {
                Logger.shared.info("FeedDiscoverView: No users with age \(ageRange). Trying expanded range...", category: .database)

                // Try with ±10 years expanded range
                let expandedMin = max(18, ageRange.lowerBound - 10)
                let expandedMax = min(99, ageRange.upperBound + 10)

                try await UserService.shared.fetchUsers(
                    excludingUserId: currentUserId,
                    lookingFor: lookingForValue,
                    ageRange: expandedMin...expandedMax,
                    limit: 50,
                    reset: true
                )

                if UserService.shared.users.isEmpty {
                    Logger.shared.info("FeedDiscoverView: Still no users. Trying without age filter...", category: .database)

                    // Last resort: try without any age filter
                    try await UserService.shared.fetchUsers(
                        excludingUserId: currentUserId,
                        lookingFor: lookingForValue,
                        ageRange: nil,
                        limit: 50,
                        reset: true
                    )
                }
            }

            await MainActor.run {
                users = UserService.shared.users
                Logger.shared.info("FeedDiscoverView: Loaded \(users.count) users", category: .database)
                errorMessage = ""  // Clear any previous errors
                isInitialLoad = false  // Hide skeleton and show content
                isLoading = false  // BUGFIX: Set to false before calling loadMoreUsers()
                loadMoreUsers()

                // Prefetch images for smooth scrolling
                ImageCache.shared.prefetchUserImages(users: Array(users.prefix(10)))
            }
        } catch {
            Logger.shared.error("Error loading users", category: .database, error: error)
            await MainActor.run {
                errorMessage = "Failed to load users. Please check your connection and try again."
                isInitialLoad = false  // Show error state instead of skeleton
                isLoading = false
            }
        }
    }

    private func loadMoreUsers() {
        guard !isLoading else {
            Logger.shared.debug("loadMoreUsers: Skipped - already loading", category: .general)
            return
        }

        let startIndex = currentPage * usersPerPage
        let endIndex = min(startIndex + usersPerPage, users.count)

        Logger.shared.debug("loadMoreUsers: currentPage=\(currentPage), startIndex=\(startIndex), endIndex=\(endIndex), users.count=\(users.count)", category: .general)

        guard startIndex < users.count else {
            Logger.shared.debug("loadMoreUsers: No more users to load", category: .general)
            return
        }

        let newUsers = Array(users[startIndex..<endIndex])
        displayedUsers.append(contentsOf: newUsers)
        currentPage += 1

        Logger.shared.info("loadMoreUsers: Added \(newUsers.count) users to display. Total displayed: \(displayedUsers.count). Users: \(newUsers.map { $0.fullName }.joined(separator: ", "))", category: .general)

        // PERFORMANCE: Eagerly prefetch images for newly displayed users BEFORE they appear on screen
        // This ensures images are cached when users tap cards
        Task {
            for user in newUsers {
                ImageCache.shared.prefetchUserPhotosHighPriority(user: user)
            }
        }

        // Prefetch images for next batch to ensure smooth scrolling
        let nextBatchStart = endIndex
        let nextBatchEnd = min(nextBatchStart + usersPerPage, users.count)
        if nextBatchStart < users.count {
            let upcomingUsers = Array(users[nextBatchStart..<nextBatchEnd])
            ImageCache.shared.prefetchUserImages(users: upcomingUsers)
        }
    }

    private func refreshFeed() async {
        currentPage = 0
        displayedUsers = []
        await loadUsers()
        HapticManager.shared.notification(.success)
    }

    private func reloadWithFilters() async {
        Logger.shared.info("reloadWithFilters: Clearing displayedUsers and reloading", category: .general)
        currentPage = 0
        displayedUsers = []
        await loadUsers()
    }

    // MARK: - Actions

    private func showToast(message: String, icon: String, color: Color) {
        toastMessage = message
        toastIcon = icon
        toastColor = color

        withAnimation(.butterSmooth) {
            showActionToast = true
        }

        // Auto-hide after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.butterSmooth) {
                showActionToast = false
            }
        }
    }

    private func handleLike(user: User, completion: @escaping (Bool) -> Void) {
        guard let currentUserId = authService.currentUser?.effectiveId,
              let userId = user.effectiveId else {
            showToast(
                message: "Unable to like. Please try again.",
                icon: "exclamationmark.triangle.fill",
                color: .red
            )
            completion(false)
            return
        }

        // Prevent liking yourself
        guard currentUserId != userId else {
            showToast(
                message: "You can't like your own profile!",
                icon: "exclamationmark.triangle.fill",
                color: .orange
            )
            completion(false)
            return
        }

        // Check daily like limit for free users (premium gets unlimited)
        let isPremium = authService.currentUser?.isPremium ?? false
        if !isPremium {
            guard RateLimiter.shared.canSendLike() else {
                // Show upgrade sheet with context message instead of toast
                upgradeContextMessage = "You've reached your daily like limit. Subscribe to continue liking!"
                showPremiumUpgrade = true
                completion(false)
                return
            }
        }

        // Optimistic update - add to liked users
        likedUsers.insert(userId)

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

                // INSTANT SYNC: Update LikesViewModel immediately so Likes page reflects changes
                await MainActor.run {
                    likesViewModel.addLikedUser(user, isMatch: isMatch)
                    // BUGFIX: Call completion with success
                    completion(true)
                }

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
                            message: "You like \(truncatedName)!",
                            icon: "heart.fill",
                            color: .pink
                        )
                    }
                }
            } catch {
                Logger.shared.error("Error sending like", category: .matching, error: error)
                await MainActor.run {
                    // Revert optimistic update on error
                    likedUsers.remove(userId)
                    showToast(
                        message: "Failed to send like. Try again.",
                        icon: "exclamationmark.triangle.fill",
                        color: .red
                    )
                    // BUGFIX: Call completion with failure
                    completion(false)
                }
            }
        }
    }

    private func handleFavorite(user: User) {
        guard let userId = user.effectiveId else {
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

            // Remove from SavedProfilesViewModel using deterministic ID
            savedProfilesViewModel.unsaveByUserId(userId)
        } else {
            // Add to favorites (optimistic update)
            favorites.insert(userId)
            let truncatedName = user.fullName.count > 20 ? String(user.fullName.prefix(20)) + "..." : user.fullName
            showToast(
                message: "Saved \(truncatedName)",
                icon: "star.fill",
                color: .orange
            )

            // Save to SavedProfilesViewModel with error handling
            Task {
                let success = await savedProfilesViewModel.saveProfile(user: user)
                if !success {
                    // Revert optimistic update on failure
                    await MainActor.run {
                        favorites.remove(userId)
                        showToast(
                            message: "Failed to save. Try again.",
                            icon: "exclamationmark.triangle.fill",
                            color: .red
                        )
                        HapticManager.shared.notification(.error)
                    }
                }
            }
        }

        HapticManager.shared.impact(.light)
    }

    private func handleUnlike(user: User, completion: @escaping (Bool) -> Void) {
        guard let currentUserId = authService.currentUser?.effectiveId,
              let userId = user.effectiveId else {
            showToast(
                message: "Unable to unlike. Please try again.",
                icon: "exclamationmark.triangle.fill",
                color: .red
            )
            completion(false)
            return
        }

        // Optimistic update - remove from liked users
        likedUsers.remove(userId)

        // INSTANT SYNC: Update LikesViewModel immediately so Likes page reflects changes
        likesViewModel.removeLikedUser(userId)

        Task {
            do {
                try await SwipeService.shared.unlikeUser(
                    fromUserId: currentUserId,
                    toUserId: userId
                )

                await MainActor.run {
                    let truncatedName = user.fullName.count > 20 ? String(user.fullName.prefix(20)) + "..." : user.fullName
                    showToast(
                        message: "Unliked \(truncatedName)",
                        icon: "heart.slash",
                        color: .gray
                    )
                    // BUGFIX: Call completion with success
                    completion(true)
                }

                Logger.shared.info("Unliked user \(userId)", category: .matching)
            } catch {
                // Revert optimistic update on error
                await MainActor.run {
                    likedUsers.insert(userId)
                    // Also revert LikesViewModel
                    likesViewModel.addLikedUser(user)
                    showToast(
                        message: "Failed to unlike. Try again.",
                        icon: "exclamationmark.triangle.fill",
                        color: .red
                    )
                    // BUGFIX: Call completion with failure
                    completion(false)
                }
                Logger.shared.error("Error unliking user", category: .matching, error: error)
            }
        }
    }

    private func handleMessage(user: User) {
        // TODO: Uncomment to enable premium-only messaging
        // guard authService.currentUser?.isPremium == true else {
        //     HapticManager.shared.impact(.medium)
        //     showPremiumUpgrade = true
        //     return
        // }

        guard let currentUserId = authService.currentUser?.effectiveId,
              let userId = user.effectiveId else {
            showToast(
                message: "Unable to send message. Please try again.",
                icon: "exclamationmark.triangle.fill",
                color: .red
            )
            return
        }

        // Prevent messaging yourself
        guard currentUserId != userId else {
            showToast(
                message: "You can't message yourself!",
                icon: "exclamationmark.triangle.fill",
                color: .orange
            )
            return
        }

        HapticManager.shared.impact(.medium)

        Task {
            do {
                // Check if a match already exists
                var existingMatch = try await MatchService.shared.fetchMatch(user1Id: currentUserId, user2Id: userId)

                if existingMatch == nil {
                    // No match exists - create one to enable messaging
                    Logger.shared.info("Creating conversation with \(user.fullName)", category: .messaging)

                    // Create the match
                    await MatchService.shared.createMatch(user1Id: currentUserId, user2Id: userId)

                    // Small delay to ensure Firestore consistency
                    try await Task.sleep(nanoseconds: 300_000_000) // 300ms

                    // Fetch the newly created match with retry
                    for attempt in 1...3 {
                        existingMatch = try await MatchService.shared.fetchMatch(user1Id: currentUserId, user2Id: userId)
                        if existingMatch != nil { break }
                        if attempt < 3 {
                            try await Task.sleep(nanoseconds: 200_000_000) // 200ms between retries
                        }
                    }
                }

                await MainActor.run {
                    if let match = existingMatch {
                        // Open chat directly using item-based presentation
                        chatPresentation = ChatPresentation(match: match, user: user)

                        let truncatedName = user.fullName.count > 20 ? String(user.fullName.prefix(20)) + "..." : user.fullName
                        Logger.shared.info("Opening chat with \(truncatedName)", category: .messaging)
                    } else {
                        // Show error after retries failed
                        showToast(
                            message: "Unable to start conversation. Please try again.",
                            icon: "exclamationmark.triangle.fill",
                            color: .red
                        )
                        Logger.shared.error("Failed to create or fetch match for messaging after retries", category: .messaging)
                    }
                }
            } catch {
                Logger.shared.error("Error starting conversation", category: .messaging, error: error)
                await MainActor.run {
                    showToast(
                        message: "Unable to start conversation. Please check your connection.",
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

    // Swipe-down to dismiss state
    @State private var dismissDragOffset: CGFloat = 0
    private let dismissThreshold: CGFloat = 150

    // Filter out empty photo URLs
    private var validPhotos: [String] {
        let photos = user.photos.filter { !$0.isEmpty }
        return photos.isEmpty ? [user.profileImageURL].filter { !$0.isEmpty } : photos
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black
                        .opacity(backgroundOpacity)
                        .ignoresSafeArea()

                    if validPhotos.isEmpty {
                        // No photos available
                        VStack(spacing: 16) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.5))

                            Text("No photos available")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    } else {
                        // PERFORMANCE: Photo gallery with smooth swiping and high-quality images
                        TabView(selection: $selectedPhotoIndex) {
                            ForEach(validPhotos.indices, id: \.self) { index in
                                // QUALITY: High-quality image with immediate priority for smooth viewing
                                // Images fill the available space while maintaining aspect ratio
                                GeometryReader { imageGeometry in
                                    CachedCardImage(
                                        url: URL(string: validPhotos[index]),
                                        priority: .immediate,
                                        fixedHeight: imageGeometry.size.height
                                    )
                                    .frame(width: imageGeometry.size.width, height: imageGeometry.size.height)
                                    .allowsHitTesting(false)
                                }
                                .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .always))
                        .indexViewStyle(.page(backgroundDisplayMode: .always))
                        // Apply dismiss offset and scale
                        .offset(y: dismissDragOffset)
                        .scaleEffect(dismissScale)
                        .task {
                            // PERFORMANCE: Ensure all photos cached on open
                            ImageCache.shared.prefetchAdjacentPhotos(photos: validPhotos, currentIndex: selectedPhotoIndex)
                        }
                        // PERFORMANCE: Preload adjacent photos when swiping
                        .onChange(of: selectedPhotoIndex) { _, newIndex in
                            ImageCache.shared.prefetchAdjacentPhotos(photos: validPhotos, currentIndex: newIndex)
                        }

                        // Photo counter overlay
                        VStack {
                            Spacer()
                            Text("\(selectedPhotoIndex + 1) / \(validPhotos.count)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(20)
                                .padding(.bottom, 60)
                        }
                        .opacity(controlsOpacity)
                    }
                }
                // Swipe-down to dismiss gesture
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Only allow downward drag for dismiss
                            if value.translation.height > 0 {
                                dismissDragOffset = value.translation.height
                            }
                        }
                        .onEnded { value in
                            if value.translation.height > dismissThreshold {
                                // Dismiss with animation
                                HapticManager.shared.impact(.light)
                                withAnimation(.easeOut(duration: 0.2)) {
                                    dismissDragOffset = geometry.size.height
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    dismiss()
                                }
                            } else {
                                // Snap back
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    dismissDragOffset = 0
                                }
                            }
                        }
                )
            }
            .navigationTitle("\(user.fullName)'s Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticManager.shared.impact(.light)
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .opacity(controlsOpacity)
                }
            }
        }
        // PERFORMANCE: Preload adjacent photos on appear
        .onAppear {
            ImageCache.shared.prefetchAdjacentPhotos(photos: validPhotos, currentIndex: selectedPhotoIndex)
        }
    }

    // Computed properties for smooth dismiss animation
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

#Preview {
    FeedDiscoverView(selectedTab: .constant(0))
        .environmentObject(AuthService.shared)
}
