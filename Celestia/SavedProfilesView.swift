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
    @State private var showPremiumUpgrade = false
    @State private var upgradeContextMessage = ""

    // PERFORMANCE: Track if initial load completed to prevent loading flash on tab switches
    @State private var hasCompletedInitialLoad = false

    // Note editing state
    @State private var editingNoteForProfile: SavedProfile?
    @State private var noteText = ""
    @State private var showNoteSheet = false

    // Chat presentation
    @State private var chatPresentation: SavedChatPresentation?

    // BUGFIX: Track which user is being liked to prevent rapid-tap issues
    @State private var processingLikeUserId: String?

    struct SavedChatPresentation: Identifiable {
        let id = UUID()
        let match: Match
        let user: User
    }

    private let tabs = ["My Saves", "Viewed", "Saved"]

    private var isPremium: Bool {
        authService.currentUser?.isPremium ?? false
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom gradient header (like Messages and Matches)
            headerView

            // Tab selector
            tabSelector

            // Main content - use ZStack with explicit identity to prevent re-creation
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                // PERFORMANCE: Only show loading skeleton on first load when we have no cached data
                // After initial load, show cached data instantly (no skeleton flash)
                let hasAnyData = !viewModel.savedProfiles.isEmpty || !viewModel.viewedProfiles.isEmpty || !viewModel.savedYouProfiles.isEmpty
                if viewModel.isLoading && !hasCompletedInitialLoad && !hasAnyData {
                    loadingView
                } else if !viewModel.errorMessage.isEmpty {
                    errorStateView
                } else {
                    // PERFORMANCE FIX: Use ZStack with opacity instead of TabView
                    // TabView with .page style causes animation/jitter on tab switches
                    // This approach shows content instantly without page-swiping animation
                    ZStack {
                        allSavedTab
                            .opacity(selectedTab == 0 ? 1 : 0)
                            .zIndex(selectedTab == 0 ? 1 : 0)
                        viewedTab
                            .opacity(selectedTab == 1 ? 1 : 0)
                            .zIndex(selectedTab == 1 ? 1 : 0)
                        savedYouTab
                            .opacity(selectedTab == 2 ? 1 : 0)
                            .zIndex(selectedTab == 2 ? 1 : 0)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .task(id: hasCompletedInitialLoad) {
            // PERFORMANCE: Only load data once on first appearance
            // Skip if already loaded to prevent re-fetching on tab switches
            guard !hasCompletedInitialLoad else { return }

            // Load data in parallel for faster initial load
            async let savedTask: () = viewModel.loadSavedProfiles()
            async let viewedTask: () = viewModel.loadViewedProfiles()
            async let savedYouTask: () = viewModel.loadSavedYouProfiles()

            _ = await (savedTask, viewedTask, savedYouTask)
            hasCompletedInitialLoad = true
        }
        .sheet(item: $selectedUser) { user in
            UserDetailView(user: user)
                .environmentObject(authService)
        }
        .sheet(isPresented: $showPremiumUpgrade) {
            PremiumUpgradeView(contextMessage: upgradeContextMessage)
                .environmentObject(authService)
        }
        .sheet(isPresented: $showNoteSheet) {
            noteEditSheet
        }
        .sheet(item: $chatPresentation) { presentation in
            NavigationStack {
                ChatView(match: presentation.match, otherUser: presentation.user)
                    .environmentObject(authService)
            }
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
                            let count = countForTab(index)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        selectedTab == index ?
                                        Color.orange : Color.gray.opacity(0.5)
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                        .foregroundColor(selectedTab == index ? .orange : .gray)

                        Rectangle()
                            .fill(selectedTab == index ? Color.orange : Color.clear)
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
                HStack(alignment: .top) {
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
                            HStack {
                                Text("Saved")
                                    .font(.largeTitle.weight(.bold))
                                    .foregroundColor(.white)

                                Spacer()

                                // Clear all button - moved up to align with title
                                if !viewModel.savedProfiles.isEmpty {
                                    Button {
                                        showClearAllConfirmation = true
                                        HapticManager.shared.impact(.light)
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "trash")
                                                .font(.caption)
                                            Text("Clear")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(.white.opacity(0.8))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.red.opacity(0.3))
                                        .cornerRadius(20)
                                    }
                                }
                            }

                            HStack(spacing: 6) {
                                HStack(spacing: 3) {
                                    Image(systemName: "bookmark.fill")
                                        .font(.caption2)
                                    Text("\(viewModel.savedProfiles.count)")
                                        .fontWeight(.semibold)
                                }

                                if viewModel.viewedProfiles.count > 0 {
                                    Circle()
                                        .fill(Color.white.opacity(0.5))
                                        .frame(width: 3, height: 3)

                                    HStack(spacing: 2) {
                                        Image(systemName: "eye")
                                            .font(.caption2)
                                        Text("\(viewModel.viewedProfiles.count) viewed you")
                                            .fontWeight(.semibold)
                                    }
                                }

                                if viewModel.savedYouProfiles.count > 0 {
                                    Circle()
                                        .fill(Color.white.opacity(0.5))
                                        .frame(width: 3, height: 3)

                                    HStack(spacing: 2) {
                                        Image(systemName: "person.2.fill")
                                            .font(.caption2)
                                        Text("\(viewModel.savedYouProfiles.count) saved you")
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.95))
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
            VStack(spacing: 16) {
                // Saved profiles grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(profiles) { saved in
                        SwipeableSavedCard(
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
            .padding(.bottom, 80)
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
                                HapticManager.shared.impact(.light)
                                if isPremium {
                                    selectedUser = profile.user
                                } else {
                                    showPremiumUpgrade = true
                                }
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
            .padding(.bottom, 80) // Account for tab bar height
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
                                HapticManager.shared.impact(.light)
                                if isPremium {
                                    selectedUser = profile.user
                                } else {
                                    showPremiumUpgrade = true
                                }
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
            .padding(.bottom, 80) // Account for tab bar height
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

    // MARK: - Note Edit Sheet

    private var noteEditSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let profile = editingNoteForProfile {
                    // Profile preview
                    HStack(spacing: 12) {
                        if let imageURL = profile.user.photos.first, let url = URL(string: imageURL) {
                            CachedAsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 50, height: 50)
                            }
                        } else {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Text(profile.user.fullName.prefix(1))
                                        .font(.title2.weight(.bold))
                                        .foregroundColor(.white)
                                )
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.user.fullName)
                                .font(.headline)
                            Text("Saved \(profile.savedAt.timeAgoDisplay())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Personal Note")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    TextEditor(text: $noteText)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )

                    Text("Add a personal note to remember why you saved this profile")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showNoteSheet = false
                        editingNoteForProfile = nil
                        noteText = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNote()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helper Functions

    private func saveNote() {
        guard let profile = editingNoteForProfile else { return }

        Task {
            await viewModel.updateNote(for: profile, note: noteText.isEmpty ? nil : noteText)
            HapticManager.shared.notification(.success)
        }

        showNoteSheet = false
        editingNoteForProfile = nil
        noteText = ""
    }

    private func startEditingNote(for profile: SavedProfile) {
        editingNoteForProfile = profile
        noteText = profile.note ?? ""
        showNoteSheet = true
        HapticManager.shared.impact(.light)
    }

    private func handleMessage(user: User) {
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
                    Logger.shared.info("Creating conversation with \(user.fullName) from SavedProfilesView", category: .messaging)
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
                        chatPresentation = SavedChatPresentation(match: match, user: user)
                        Logger.shared.info("Opening chat with \(user.fullName)", category: .messaging)
                    } else {
                        // Show error feedback when match creation fails
                        HapticManager.shared.notification(.error)
                        Logger.shared.error("Failed to create or fetch match for messaging from SavedProfilesView", category: .messaging)
                    }
                }
            } catch {
                Logger.shared.error("Error starting conversation from SavedProfilesView", category: .messaging, error: error)
                await MainActor.run {
                    HapticManager.shared.notification(.error)
                }
            }
        }
    }

    private func handleLike(user: User) {
        guard let currentUserId = authService.currentUser?.effectiveId,
              let targetUserId = user.effectiveId else {
            return
        }

        // BUGFIX: Prevent rapid-tap duplicate likes
        guard processingLikeUserId == nil else {
            Logger.shared.debug("Like already in progress, ignoring tap", category: .matching)
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
        processingLikeUserId = targetUserId

        Task {
            defer {
                // BUGFIX: Always reset processing state when done
                Task { @MainActor in
                    processingLikeUserId = nil
                }
            }

            do {
                let isMatch = try await SwipeService.shared.likeUser(
                    fromUserId: currentUserId,
                    toUserId: targetUserId,
                    isSuperLike: false
                )

                await MainActor.run {
                    if isMatch {
                        HapticManager.shared.notification(.success)
                        Logger.shared.info("Liked saved profile - it's a match!", category: .matching)
                    } else {
                        HapticManager.shared.impact(.medium)
                        Logger.shared.info("Liked saved profile", category: .matching)
                    }
                }
            } catch let error as CelestiaError {
                Logger.shared.error("Error liking saved profile", category: .matching, error: error)
                await MainActor.run {
                    HapticManager.shared.notification(.error)
                    viewModel.errorMessage = error.localizedDescription
                }
            } catch {
                Logger.shared.error("Error liking saved profile", category: .matching, error: error)
                await MainActor.run {
                    HapticManager.shared.notification(.error)
                    viewModel.errorMessage = "Failed to send like. Please try again."
                }
            }
        }
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
                                colors: [.purple.opacity(0.7), .pink.opacity(0.6)],
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
                            .foregroundColor(.purple)
                        Text(savedProfile.user.location)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .opacity(isUnsaving ? 0.5 : 1.0)
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isUnsaving)
    }
}

// MARK: - Swipeable Saved Card with Enhanced Features

struct SwipeableSavedCard: View {
    let savedProfile: SavedProfile
    let isUnsaving: Bool
    let onTap: () -> Void
    let onUnsave: () -> Void

    @State private var offset: CGFloat = 0
    @State private var showDeleteOverlay = false

    private let swipeThreshold: CGFloat = 80
    private let imageHeight: CGFloat = 180

    var body: some View {
        ZStack {
            // Background action indicator (delete/unsave)
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "bookmark.slash.fill")
                        .font(.title)
                        .foregroundColor(.white)
                    Text("Unsave")
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
                    colors: [.red.opacity(0.8), .orange.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)

            // Main card content
            EnhancedSavedProfileCard(
                savedProfile: savedProfile,
                isUnsaving: isUnsaving,
                onTap: onTap
            )
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        // Only allow left swipe (negative offset)
                        if gesture.translation.width < 0 {
                            offset = gesture.translation.width
                            showDeleteOverlay = -offset > swipeThreshold / 2
                        }
                    }
                    .onEnded { gesture in
                        if -offset > swipeThreshold {
                            // Trigger unsave action
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                offset = -UIScreen.main.bounds.width
                            }
                            HapticManager.shared.notification(.warning)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                onUnsave()
                                withAnimation {
                                    offset = 0
                                }
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                offset = 0
                                showDeleteOverlay = false
                            }
                        }
                    }
            )

            // Delete overlay on card
            if showDeleteOverlay {
                VStack {
                    Image(systemName: "bookmark.slash.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                        .shadow(color: .red.opacity(0.5), radius: 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.3))
                .cornerRadius(16)
                .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Enhanced Saved Profile Card

struct EnhancedSavedProfileCard: View {
    let savedProfile: SavedProfile
    let isUnsaving: Bool
    let onTap: () -> Void

    private let imageHeight: CGFloat = 180

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Profile image section
                ZStack(alignment: .topTrailing) {
                    Group {
                        if let imageURL = savedProfile.user.photos.first, let url = URL(string: imageURL) {
                            CachedCardImage(url: url)
                                .frame(height: imageHeight)
                        } else {
                            LinearGradient(
                                colors: [.purple.opacity(0.7), .pink.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .overlay {
                                Text(savedProfile.user.fullName.prefix(1))
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }

                    // Verified badge
                    if savedProfile.user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                            .background(Circle().fill(.white).padding(-2))
                            .padding(8)
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

                // User info section
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(savedProfile.user.fullName)
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(1)

                        Text("\(savedProfile.user.age)")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)

                        Spacer()
                    }

                    // Location
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.purple)
                        Text(savedProfile.user.location)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    // Saved timestamp
                    HStack(spacing: 4) {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        Text("Saved \(savedProfile.savedAt.timeAgoDisplay())")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    // Note preview (if exists)
                    if let note = savedProfile.note, !note.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "note.text")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                            Text(note)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .opacity(isUnsaving ? 0.5 : 1.0)
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isUnsaving)
    }
}

// MARK: - Saved Action Button

struct SavedActionButton: View {
    let icon: String
    let colors: [Color]
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            HapticManager.shared.impact(.light)
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .frame(width: 32, height: 28)
                .background(
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(8)
                .scaleEffect(isPressed ? 0.9 : 1.0)
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
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
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
                            colors: [.purple.opacity(0.7), .pink.opacity(0.6)],
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

                // User info section
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
                            .foregroundColor(.purple)
                        Text(profile.user.location)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
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
                            colors: [.purple.opacity(0.7), .pink.opacity(0.6)],
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

                // User info section
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
                            .foregroundColor(.purple)
                        Text(profile.viewedAt.timeAgoDisplay())
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
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
            // Filter out users who are not active (pending, suspended, flagged, banned)
            var profiles: [SavedProfile] = []
            var skippedCount = 0

            for metadata in savedMetadata {
                if let user = fetchedUsers[metadata.userId] {
                    // Only include users with active profileStatus
                    let status = user.profileStatus.lowercased()
                    if status == "active" || status.isEmpty {
                        profiles.append(SavedProfile(
                            id: metadata.id,
                            user: user,
                            savedAt: metadata.savedAt,
                            note: metadata.note
                        ))
                    } else {
                        // User is pending/suspended/flagged - don't show
                        skippedCount += 1
                        Logger.shared.debug("Skipped saved profile - user not active: \(metadata.userId) (status: \(status))", category: .general)
                    }
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
        guard let savedUserId = profile.user.effectiveId else {
            Logger.shared.error("Cannot unsave profile: Missing user ID", category: .general)
            return
        }

        // Set loading state
        unsavingProfileId = profile.id

        Task {
            do {
                // Remove the specific document by ID
                try await db.collection("saved_profiles").document(profile.id).delete()

                // BUGFIX: Also delete any duplicate entries for the same user pair
                // This cleans up legacy random-ID duplicates
                let duplicatesSnapshot = try await db.collection("saved_profiles")
                    .whereField("userId", isEqualTo: currentUserId)
                    .whereField("savedUserId", isEqualTo: savedUserId)
                    .getDocuments()

                for doc in duplicatesSnapshot.documents {
                    try await doc.reference.delete()
                    Logger.shared.debug("Deleted duplicate saved profile: \(doc.documentID)", category: .general)
                }

                // Update local state - remove ALL entries for this user
                await MainActor.run {
                    savedProfiles.removeAll { $0.id == profile.id || $0.user.effectiveId == savedUserId }
                    unsavingProfileId = nil
                    // PERFORMANCE: Invalidate cache so next load gets fresh data
                    lastFetchTime = nil
                }

                Logger.shared.info("Unsaved profile: \(profile.user.fullName)", category: .general)

                // Track analytics - safely unwrap optional
                AnalyticsServiceEnhanced.shared.trackEvent(
                    .profileUnsaved,
                    properties: [
                        "unsavedUserId": savedUserId,
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

    /// Unsave a profile by user ID (uses deterministic document ID)
    /// This is more reliable than finding the SavedProfile object first
    func unsaveByUserId(_ savedUserId: String) {
        guard let currentUserId = AuthService.shared.currentUser?.effectiveId else { return }

        let docId = "\(currentUserId)_\(savedUserId)"
        unsavingProfileId = docId

        Task {
            do {
                // Delete using deterministic ID
                try await db.collection("saved_profiles").document(docId).delete()

                // Also try to delete any legacy random-ID documents for this user pair
                let legacySnapshot = try await db.collection("saved_profiles")
                    .whereField("userId", isEqualTo: currentUserId)
                    .whereField("savedUserId", isEqualTo: savedUserId)
                    .getDocuments()

                for doc in legacySnapshot.documents where doc.documentID != docId {
                    try await doc.reference.delete()
                    Logger.shared.debug("Deleted legacy saved profile: \(doc.documentID)", category: .general)
                }

                // Update local state
                await MainActor.run {
                    savedProfiles.removeAll { $0.id == docId || $0.user.effectiveId == savedUserId }
                    unsavingProfileId = nil
                    // PERFORMANCE: Invalidate cache so next load gets fresh data
                    lastFetchTime = nil
                }

                Logger.shared.info("Unsaved profile by userId: \(savedUserId)", category: .general)

                // Track analytics
                AnalyticsServiceEnhanced.shared.trackEvent(
                    .profileUnsaved,
                    properties: ["unsavedUserId": savedUserId]
                )
            } catch {
                await MainActor.run {
                    unsavingProfileId = nil
                    errorMessage = "Failed to unsave profile. Please try again."
                }
                Logger.shared.error("Error unsaving profile by userId", category: .general, error: error)

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

    /// Save a profile and return success status for UI revert on failure
    @discardableResult
    func saveProfile(user: User, note: String? = nil) async -> Bool {
        guard let currentUserId = AuthService.shared.currentUser?.effectiveId,
              let savedUserId = user.effectiveId else {
            let currentUser = AuthService.shared.currentUser
            Logger.shared.error("Cannot save profile: Missing user ID (currentUser.id=\(currentUser?.id ?? "nil"), currentUser.effectiveId=\(currentUser?.effectiveId ?? "nil"), savedUser.id=\(user.id ?? "nil"), savedUser.effectiveId=\(user.effectiveId ?? "nil"))", category: .general)
            return false
        }

        // Use deterministic document ID to prevent duplicates (same pattern as likes)
        let docId = "\(currentUserId)_\(savedUserId)"

        // Check if already saved in local state
        if savedProfiles.contains(where: { $0.id == docId }) {
            Logger.shared.info("Profile already saved: \(user.fullName)", category: .general)
            return true  // Already saved is still a success
        }

        do {
            let saveData: [String: Any] = [
                "userId": currentUserId,
                "savedUserId": savedUserId,
                "savedAt": Timestamp(date: Date()),
                "note": note ?? ""
            ]

            // Use setData with deterministic ID to prevent duplicates
            // setData will create if not exists, or update if exists
            try await db.collection("saved_profiles").document(docId).setData(saveData)

            // Update local state immediately
            await MainActor.run {
                // Remove any existing entry first (in case of stale data)
                savedProfiles.removeAll { $0.id == docId || $0.user.effectiveId == savedUserId }

                let newSaved = SavedProfile(
                    id: docId,
                    user: user,
                    savedAt: Date(),
                    note: note
                )
                savedProfiles.insert(newSaved, at: 0)

                // PERFORMANCE: Update cache timestamp to keep it fresh
                lastFetchTime = Date()
                cachedForUserId = currentUserId
            }

            Logger.shared.info("Saved profile: \(user.fullName) (\(docId))", category: .general)

            // Track analytics
            AnalyticsServiceEnhanced.shared.trackEvent(
                .profileSaved,
                properties: ["savedUserId": savedUserId]
            )
            return true
        } catch {
            Logger.shared.error("Error saving profile to Firestore", category: .general, error: error)
            return false
        }
    }

    /// Update the note for a saved profile
    func updateNote(for profile: SavedProfile, note: String?) async {
        do {
            // Update in Firestore
            try await db.collection("saved_profiles").document(profile.id).updateData([
                "note": note ?? ""
            ])

            // Update local state
            await MainActor.run {
                if let index = savedProfiles.firstIndex(where: { $0.id == profile.id }) {
                    // Create new SavedProfile with updated note
                    let updatedProfile = SavedProfile(
                        id: profile.id,
                        user: profile.user,
                        savedAt: profile.savedAt,
                        note: note
                    )
                    savedProfiles[index] = updatedProfile
                }
            }

            Logger.shared.info("Updated note for saved profile: \(profile.user.fullName)", category: .general)
        } catch {
            Logger.shared.error("Error updating note for saved profile", category: .general, error: error)
        }
    }
}

#Preview {
    SavedProfilesView()
        .environmentObject(AuthService.shared)
}
