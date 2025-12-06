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
    @ObservedObject private var viewModel = LikesViewModel.shared
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    @State private var selectedTab = 0
    @State private var selectedUserForDetail: User?
    @State private var showChatWithUser: User?
    @State private var showPremiumUpgrade = false
    @State private var upgradeContextMessage = ""

    // PERFORMANCE: Track if initial load completed to prevent loading flash on tab switches
    @State private var hasCompletedInitialLoad = false

    // Direct messaging state - using dedicated struct for item-based presentation
    @State private var chatPresentation: ChatPresentation?

    // Filter state
    @State private var showFilters = false
    @State private var selectedAgeFilter: AgeFilter = .all
    @State private var selectedSortOption: SortOption = .recent

    // Match celebration state
    @State private var showMatchCelebration = false
    @State private var matchedUser: User?

    // Error handling state
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    // BUGFIX: Track in-progress like back to prevent rapid-tap duplicates
    @State private var processingLikeBackUserId: String?

    struct ChatPresentation: Identifiable {
        let id = UUID()
        let match: Match
        let user: User
    }

    enum AgeFilter: String, CaseIterable {
        case all = "All Ages"
        case under25 = "Under 25"
        case twenties = "25-30"
        case thirties = "30-40"
        case over40 = "40+"

        func matches(age: Int) -> Bool {
            switch self {
            case .all: return true
            case .under25: return age < 25
            case .twenties: return age >= 25 && age <= 30
            case .thirties: return age > 30 && age <= 40
            case .over40: return age > 40
            }
        }
    }

    enum SortOption: String, CaseIterable {
        case recent = "Most Recent"
        case ageYoungest = "Youngest First"
        case ageOldest = "Oldest First"
        case nameAZ = "Name A-Z"
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
                    // PERFORMANCE: Only show loading on first load when we have no data
                    // After initial load, show cached data instantly (no skeleton flash)
                    let hasAnyData = !viewModel.usersWhoLikedMe.isEmpty || !viewModel.usersILiked.isEmpty || !viewModel.mutualLikes.isEmpty
                    if viewModel.isLoading && !hasCompletedInitialLoad && !hasAnyData {
                        loadingView
                    } else {
                        // PERFORMANCE FIX: Use ZStack with opacity instead of TabView
                        // TabView with .page style causes animation/jitter on tab switches
                        // This approach shows content instantly without page-swiping animation
                        ZStack {
                            likedMeTab
                                .opacity(selectedTab == 0 ? 1 : 0)
                                .zIndex(selectedTab == 0 ? 1 : 0)
                            myLikesTab
                                .opacity(selectedTab == 1 ? 1 : 0)
                                .zIndex(selectedTab == 1 ? 1 : 0)
                            mutualLikesTab
                                .opacity(selectedTab == 2 ? 1 : 0)
                                .zIndex(selectedTab == 2 ? 1 : 0)
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .task(id: hasCompletedInitialLoad) {
                // PERFORMANCE: Only load data once on first appearance
                // Skip if already loaded to prevent re-fetching on tab switches
                guard !hasCompletedInitialLoad else { return }
                await viewModel.loadAllLikes()
                hasCompletedInitialLoad = true
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
                PremiumUpgradeView(contextMessage: upgradeContextMessage)
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showFilters) {
                filterSheet
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .overlay {
                // Match celebration overlay
                if showMatchCelebration, let user = matchedUser {
                    MatchCelebrationOverlay(user: user) {
                        withAnimation(.spring()) {
                            showMatchCelebration = false
                            matchedUser = nil
                        }
                    } onMessage: {
                        withAnimation(.spring()) {
                            showMatchCelebration = false
                        }
                        // Slight delay to let animation complete
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            handleMessage(user: user)
                            matchedUser = nil
                        }
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
        }
        .networkStatusBanner()
    }

    // MARK: - Filtered Users

    private var filteredUsersWhoLikedMe: [User] {
        applyFiltersAndSort(to: viewModel.usersWhoLikedMe)
    }

    private var filteredUsersILiked: [User] {
        applyFiltersAndSort(to: viewModel.usersILiked)
    }

    private var filteredMutualLikes: [User] {
        applyFiltersAndSort(to: viewModel.mutualLikes)
    }

    private func applyFiltersAndSort(to users: [User]) -> [User] {
        var result = users

        // Apply age filter
        if selectedAgeFilter != .all {
            result = result.filter { selectedAgeFilter.matches(age: $0.age) }
        }

        // Apply sort
        switch selectedSortOption {
        case .recent:
            break // Already sorted by most recent from backend
        case .ageYoungest:
            result.sort { $0.age < $1.age }
        case .ageOldest:
            result.sort { $0.age > $1.age }
        case .nameAZ:
            result.sort { $0.fullName.localizedCompare($1.fullName) == .orderedAscending }
        }

        return result
    }

    // MARK: - Filter Sheet

    private var filterSheet: some View {
        NavigationStack {
            List {
                Section("Age Range") {
                    ForEach(AgeFilter.allCases, id: \.self) { filter in
                        Button {
                            selectedAgeFilter = filter
                            HapticManager.shared.selection()
                        } label: {
                            HStack {
                                Text(filter.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedAgeFilter == filter {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.pink)
                                }
                            }
                        }
                    }
                }

                Section("Sort By") {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button {
                            selectedSortOption = option
                            HapticManager.shared.selection()
                        } label: {
                            HStack {
                                Text(option.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedSortOption == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.pink)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        selectedAgeFilter = .all
                        selectedSortOption = .recent
                        HapticManager.shared.impact(.light)
                    } label: {
                        Text("Reset Filters")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showFilters = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Message Handling

    private func handleMessage(user: User) {
        // TODO: Uncomment to enable premium-only messaging
        // guard authService.currentUser?.isPremium == true else {
        //     HapticManager.shared.impact(.medium)
        //     showPremiumUpgrade = true
        //     return
        // }

        guard let currentUserId = authService.currentUser?.effectiveId,
              let userId = user.effectiveId else {
            HapticManager.shared.notification(.error)
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
                        Logger.shared.info("Opening chat with \(user.fullName)", category: .messaging)
                    } else {
                        // Show error feedback when match creation fails
                        HapticManager.shared.notification(.error)
                        Logger.shared.error("Failed to create or fetch match for messaging from LikesView", category: .messaging)
                    }
                }
            } catch {
                Logger.shared.error("Error starting conversation from LikesView", category: .messaging, error: error)
                await MainActor.run {
                    HapticManager.shared.notification(.error)
                }
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

                    VStack(alignment: .trailing, spacing: 8) {
                        if authService.currentUser?.isPremium == true {
                            premiumBadge
                        }

                        // Filter button
                        Button {
                            showFilters = true
                            HapticManager.shared.impact(.light)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 14))
                                Text("Filter")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                if selectedAgeFilter != .all || selectedSortOption != .recent {
                                    Circle()
                                        .fill(Color.yellow)
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(20)
                        }
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
                // Premium users see full profiles with filters applied
                likesGrid(users: filteredUsersWhoLikedMe, showLikeBack: true)
            } else {
                // Free users see blurred/locked view with upgrade CTA
                premiumLockedLikesView
            }
        }
    }

    private func handleLikeBack(user: User) {
        guard let targetUserId = user.effectiveId else { return }

        // BUGFIX: Prevent rapid-tap duplicate likes
        guard processingLikeBackUserId == nil else {
            Logger.shared.debug("Like back already in progress, ignoring tap", category: .matching)
            return
        }

        // Check daily like limit for free users (premium gets unlimited)
        let isPremium = authService.currentUser?.isPremium ?? false
        if !isPremium {
            guard RateLimiter.shared.canSendLike() else {
                // Show upgrade sheet with context message
                upgradeContextMessage = "You've reached your daily like limit. Subscribe to continue liking!"
                showPremiumUpgrade = true
                return
            }
        }

        // BUGFIX: Set processing state to prevent rapid taps
        processingLikeBackUserId = targetUserId

        Task {
            let result = await viewModel.likeBackUser(user)
            await MainActor.run {
                // BUGFIX: Clear processing state to allow future likes
                processingLikeBackUserId = nil

                switch result {
                case .match:
                    // Show match celebration
                    matchedUser = user
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showMatchCelebration = true
                    }
                case .liked:
                    // Successfully liked but no match yet
                    HapticManager.shared.impact(.medium)
                case .error(let message):
                    // Show error to user
                    errorMessage = message
                    showErrorAlert = true
                }
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
            .padding(.bottom, 80)
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
                likesGrid(users: filteredUsersILiked, showLikeBack: false)
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
                likesGrid(users: filteredMutualLikes, showMessage: true)
            }
        }
    }

    // MARK: - Likes Grid

    private func likesGrid(users: [User], showLikeBack: Bool = false, showMessage: Bool = false) -> some View {
        ScrollView(showsIndicators: false) {
            // Show filter indicator if filters are active
            if selectedAgeFilter != .all || selectedSortOption != .recent {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.caption)
                        .foregroundColor(.purple)
                    Text("Filtered: \(users.count) results")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Clear") {
                        selectedAgeFilter = .all
                        selectedSortOption = .recent
                        HapticManager.shared.impact(.light)
                    }
                    .font(.caption)
                    .foregroundColor(.pink)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(users, id: \.effectiveId) { user in
                    SwipeableLikeCard(
                        user: user,
                        showLikeBack: showLikeBack,
                        showMessage: showMessage,
                        onTap: {
                            selectedUserForDetail = user
                        },
                        onLikeBack: {
                            handleLikeBack(user: user)
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
            .padding(.bottom, 80)
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

// MARK: - Teaser Like Card (Shows profile, tapping opens subscription)

struct BlurredLikeCard: View {
    let user: User
    let index: Int

    private let imageHeight: CGFloat = 180

    var body: some View {
        VStack(spacing: 0) {
            // Profile image - visible, no blur
            ZStack(alignment: .topTrailing) {
                if let imageURL = URL(string: user.profileImageURL), !user.profileImageURL.isEmpty {
                    CachedCardImage(url: imageURL)
                        .frame(height: imageHeight)
                } else {
                    LinearGradient(
                        colors: [.purple.opacity(0.7), .pink.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: imageHeight)
                    .overlay {
                        Text(user.fullName.prefix(1))
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

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
            .cornerRadius(16, corners: [.topLeft, .topRight])

            // User info - visible
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(user.fullName)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)

                    Text("\(user.age)")
                        .font(.system(size: 17))
                        .foregroundColor(.secondary)

                    Spacer()

                    // Heart indicator showing they liked you
                    Image(systemName: "heart.fill")
                        .foregroundColor(.pink)
                        .font(.caption)
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
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
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

// MARK: - Like Result

enum LikeResult {
    case match
    case liked
    case error(String)
}

// MARK: - View Model

@MainActor
class LikesViewModel: ObservableObject {
    // SINGLETON: Shared instance for state sync across all views
    static let shared = LikesViewModel()

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

    // INSTANT SYNC: Add a user to the liked list immediately without fetching from server
    // Called from FeedDiscoverView when user likes someone
    func addLikedUser(_ user: User, isMatch: Bool = false) {
        guard let userId = user.effectiveId else { return }

        // Check if already in list to avoid duplicates
        guard !usersILiked.contains(where: { $0.effectiveId == userId }) else { return }

        // Add to usersILiked immediately
        usersILiked.insert(user, at: 0) // Insert at beginning for "most recent first"

        // If it's a match, also add to mutualLikes
        if isMatch {
            if !mutualLikes.contains(where: { $0.effectiveId == userId }) {
                mutualLikes.insert(user, at: 0)
            }
        }

        Logger.shared.debug("LikesViewModel instant sync: added \(user.fullName) to usersILiked (isMatch: \(isMatch))", category: .matching)
    }

    // INSTANT SYNC: Remove a user from the liked list immediately
    // Called when user unlikes someone
    func removeLikedUser(_ userId: String) {
        usersILiked.removeAll { $0.effectiveId == userId }
        mutualLikes.removeAll { $0.effectiveId == userId }
        Logger.shared.debug("LikesViewModel instant sync: removed user \(userId) from liked lists", category: .matching)
    }

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

        // Filter out users who are not active (pending, suspended, flagged, banned)
        // Only show users with active profileStatus
        users = users.filter { user in
            let status = user.profileStatus.lowercased()
            return status == "active" || status.isEmpty
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

    func likeBackUser(_ user: User) async -> LikeResult {
        guard let targetUserId = user.effectiveId else {
            return .error("Unable to like this user. Please try again.")
        }
        guard let currentUserId = AuthService.shared.currentUser?.effectiveId else {
            return .error("Please sign in to like profiles.")
        }

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
                Logger.shared.info("Liked back user - now mutual!", category: .matching)
                return .match
            } else {
                await MainActor.run {
                    if !usersILiked.contains(where: { $0.effectiveId == targetUserId }) {
                        usersILiked.append(user)
                    }
                }
                return .liked
            }
        } catch let error as CelestiaError {
            Logger.shared.error("Error liking back user", category: .matching, error: error)
            HapticManager.shared.notification(.error)
            return .error(error.localizedDescription)
        } catch {
            Logger.shared.error("Error liking back user", category: .matching, error: error)
            HapticManager.shared.notification(.error)
            return .error("Failed to send like. Please check your connection and try again.")
        }
    }
}

// MARK: - Swipeable Like Card with Gesture

struct SwipeableLikeCard: View {
    let user: User
    var showLikeBack: Bool = false
    var showMessage: Bool = false
    var onTap: () -> Void
    var onLikeBack: (() -> Void)? = nil
    var onMessage: (() -> Void)? = nil

    @State private var offset: CGFloat = 0
    @State private var showLikeOverlay = false
    @State private var isLiking = false

    private let swipeThreshold: CGFloat = 80
    private let imageHeight: CGFloat = 180

    var body: some View {
        ZStack {
            // Background action indicator
            if showLikeBack {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.title)
                            .foregroundColor(.white)
                        Text("Like")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .frame(width: 80)
                    .opacity(min(1, -offset / swipeThreshold))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: [.pink, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }

            // Main card content
            LikeProfileCard(
                user: user,
                showLikeBack: showLikeBack,
                showMessage: showMessage,
                onTap: onTap,
                onLikeBack: onLikeBack,
                onMessage: onMessage
            )
            .offset(x: offset)
            .gesture(
                showLikeBack ?
                DragGesture()
                    .onChanged { gesture in
                        // Only allow left swipe (negative offset)
                        if gesture.translation.width < 0 {
                            offset = gesture.translation.width
                            showLikeOverlay = -offset > swipeThreshold / 2
                        }
                    }
                    .onEnded { gesture in
                        if -offset > swipeThreshold {
                            // Trigger like action
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                offset = -UIScreen.main.bounds.width
                            }
                            HapticManager.shared.notification(.success)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                onLikeBack?()
                                withAnimation {
                                    offset = 0
                                }
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                offset = 0
                                showLikeOverlay = false
                            }
                        }
                    }
                : nil
            )

            // Like overlay on card
            if showLikeOverlay && showLikeBack {
                VStack {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.pink)
                        .shadow(color: .pink.opacity(0.5), radius: 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.3))
                .cornerRadius(16)
                .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Match Celebration Overlay

struct MatchCelebrationOverlay: View {
    let user: User
    let onDismiss: () -> Void
    let onMessage: () -> Void

    @State private var showConfetti = false
    @State private var heartScale: CGFloat = 0.5
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 24) {
                // Animated hearts
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.pink.opacity(0.4), Color.clear],
                                center: .center,
                                startRadius: 40,
                                endRadius: 120
                            )
                        )
                        .frame(width: 240, height: 240)
                        .scaleEffect(showConfetti ? 1.2 : 0.8)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: showConfetti)

                    // User photos
                    HStack(spacing: -30) {
                        // Your photo placeholder
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            )
                            .overlay(Circle().stroke(Color.white, lineWidth: 4))

                        // Their photo
                        if let imageURL = URL(string: user.profileImageURL), !user.profileImageURL.isEmpty {
                            CachedAsyncImage(url: imageURL) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 100, height: 100)
                            }
                        } else {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.pink, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Text(user.fullName.prefix(1))
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundColor(.white)
                                )
                                .overlay(Circle().stroke(Color.white, lineWidth: 4))
                        }
                    }

                    // Heart in center
                    Image(systemName: "heart.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.pink)
                        .offset(y: 40)
                        .scaleEffect(heartScale)
                }
                .scaleEffect(heartScale)

                // Text
                VStack(spacing: 12) {
                    Text("It's a Match!")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)

                    Text("You and \(user.fullName) liked each other")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .opacity(textOpacity)

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        onMessage()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "message.fill")
                            Text("Send a Message")
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
                        .cornerRadius(30)
                    }

                    Button {
                        onDismiss()
                    } label: {
                        Text("Keep Browsing")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 40)
                .opacity(textOpacity)
            }
        }
        .onAppear {
            // Animate in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                heartScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                textOpacity = 1.0
            }
            withAnimation(.easeInOut(duration: 0.3).delay(0.1)) {
                showConfetti = true
            }
        }
    }
}

#Preview {
    LikesView()
        .environmentObject(AuthService.shared)
}
