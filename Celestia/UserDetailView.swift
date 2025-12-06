//
//  UserDetailView.swift
//  Celestia
//
//  Detailed view of a user's profile
//

import SwiftUI

struct UserDetailView: View {
    let user: User
    let initialIsLiked: Bool
    var onLikeChanged: ((Bool) -> Void)?  // Callback to sync like state with parent

    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss

    @State private var showingInterestSent = false
    @State private var showingMatched = false
    @State private var showingUnliked = false
    @State private var isProcessing = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaved = false
    @State private var isSavingProfile = false  // Prevents rapid-tap duplicates
    @State private var isLiked = false
    @State private var showingChat = false
    @State private var chatMatch: Match?
    @State private var showPremiumUpgrade = false
    @State private var upgradeContextMessage = ""
    @ObservedObject private var savedProfilesVM = SavedProfilesViewModel.shared

    // Photo viewer state
    @State private var selectedPhotoIndex: Int = 0
    @State private var showFullScreenPhotos = false

    init(user: User, initialIsLiked: Bool = false, onLikeChanged: ((Bool) -> Void)? = nil) {
        self.user = user
        self.initialIsLiked = initialIsLiked
        self.onLikeChanged = onLikeChanged
    }

    // Filter out empty photo URLs
    private var validPhotos: [String] {
        let photos = user.photos.isEmpty ? [user.profileImageURL] : user.photos
        return photos.filter { !$0.isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                photosCarousel
                profileContent
            }
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .bottom) {
            actionButtons
        }
        .task {
            // PERFORMANCE: Start prefetching immediately in parallel with view load
            ImageCache.shared.prefetchAdjacentPhotos(photos: validPhotos, currentIndex: selectedPhotoIndex)
        }
        .onAppear(perform: handleOnAppear)
        .onChange(of: savedProfilesVM.savedProfiles) { _ in
            // BUGFIX: Use effectiveId for reliable user identification (handles @DocumentID edge cases)
            isSaved = savedProfilesVM.savedProfiles.contains(where: { $0.user.effectiveId == user.effectiveId })
        }
        .alert("Like Sent! 💫", isPresented: $showingInterestSent) {
            Button("OK") { dismiss() }
        } message: {
            Text("If \(user.fullName) likes you back, you'll be matched!")
        }
        .alert("It's a Match! 🎉", isPresented: $showingMatched) {
            Button("Send Message") {
                NotificationCenter.default.post(
                    name: .navigateToMessages,
                    object: nil,
                    userInfo: ["matchedUserId": user.id as Any]
                )
                dismiss()
            }
            Button("Keep Browsing") { dismiss() }
        } message: {
            Text("You and \(user.fullName) liked each other!")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage.isEmpty ? "Failed to send like. Please try again." : errorMessage)
        }
        .alert("Unliked", isPresented: $showingUnliked) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You unliked \(user.fullName)")
        }
        .sheet(isPresented: $showingChat) {
            if let match = chatMatch {
                NavigationStack {
                    ChatView(match: match, otherUser: user)
                        .environmentObject(authService)
                }
            }
        }
        .sheet(isPresented: $showPremiumUpgrade) {
            PremiumUpgradeView(contextMessage: upgradeContextMessage)
                .environmentObject(authService)
        }
    }

    // MARK: - Photos Carousel

    private var photosCarousel: some View {
        TabView(selection: $selectedPhotoIndex) {
            ForEach(Array(validPhotos.enumerated()), id: \.offset) { index, photoURL in
                // PERFORMANCE: Immediate priority - images already cached from aggressive prefetch
                CachedCardImage(
                    url: URL(string: photoURL),
                    priority: .immediate
                )
                .frame(height: 400)
                .frame(maxWidth: .infinity)
                .clipped()
                .onTapGesture {
                    selectedPhotoIndex = index
                    showFullScreenPhotos = true
                    HapticManager.shared.impact(.light)
                }
                .tag(index)
            }
        }
        .frame(height: 400)
        .tabViewStyle(.page)
        // PERFORMANCE: Preload adjacent photos when swiping
        .onChange(of: selectedPhotoIndex) { _, newIndex in
            ImageCache.shared.prefetchAdjacentPhotos(photos: validPhotos, currentIndex: newIndex)
        }
        .fullScreenCover(isPresented: $showFullScreenPhotos) {
            FullScreenPhotoViewer(
                photos: validPhotos,
                selectedIndex: $selectedPhotoIndex,
                isPresented: $showFullScreenPhotos
            )
        }
    }

    // MARK: - Profile Content

    private var profileContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            headerSection
            bioSection
            languagesSection
            interestsSection
            promptsSection
            detailsSection
            lifestyleSection
            lookingForSection
        }
        .padding(20)
        .padding(.bottom, 80)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(user.fullName)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("\(user.age)")
                    .font(.title2)
                    .foregroundColor(.secondary)

                if user.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.purple)
                Text("\(user.location), \(user.country)")
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)

            lastActiveView
        }
    }

    private var lastActiveView: some View {
        HStack(spacing: 6) {
            let interval = Date().timeIntervalSince(user.lastActive)
            let isActive = user.isOnline || interval < 300

            if isActive {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text(user.isOnline ? "Online" : "Active now")
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
                Text("Active \(user.lastActive.timeAgoShort()) ago")
                    .foregroundColor(.secondary)
            }
        }
        .font(.caption)
    }

    // MARK: - Bio Section

    @ViewBuilder
    private var bioSection: some View {
        if !user.bio.isEmpty {
            ProfileSectionCard(
                icon: "quote.bubble.fill",
                title: "About",
                iconColors: [.purple, .pink],
                borderColor: .purple
            ) {
                Text(user.bio)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
            }
        }
    }

    // MARK: - Languages Section

    @ViewBuilder
    private var languagesSection: some View {
        if !user.languages.isEmpty {
            ProfileSectionCard(
                icon: "globe",
                title: "Languages",
                iconColors: [.blue, .cyan],
                borderColor: .blue
            ) {
                FlowLayout2(spacing: 10) {
                    ForEach(user.languages, id: \.self) { language in
                        ProfileTagView(text: language, colors: [.blue, .cyan], textColor: .blue)
                    }
                }
            }
        }
    }

    // MARK: - Interests Section

    @ViewBuilder
    private var interestsSection: some View {
        if !user.interests.isEmpty {
            ProfileSectionCard(
                icon: "sparkles",
                title: "Interests",
                iconColors: [.orange, .pink],
                borderColor: .orange
            ) {
                FlowLayout2(spacing: 10) {
                    ForEach(user.interests, id: \.self) { interest in
                        ProfileTagView(text: interest, colors: [.orange, .pink], textColor: .orange)
                    }
                }
            }
        }
    }

    // MARK: - Prompts Section

    @ViewBuilder
    private var promptsSection: some View {
        if !user.prompts.isEmpty {
            ProfileSectionCard(
                icon: "quote.bubble.fill",
                title: "Get to Know Me",
                iconColors: [.purple, .pink],
                borderColor: .purple
            ) {
                VStack(spacing: 12) {
                    ForEach(user.prompts) { prompt in
                        PromptCard(prompt: prompt)
                    }
                }
            }
        }
    }

    // MARK: - Details Section

    @ViewBuilder
    private var detailsSection: some View {
        if hasAdvancedDetails {
            ProfileSectionCard(
                icon: "person.text.rectangle",
                title: "Details",
                iconColors: [.indigo, .purple],
                borderColor: .indigo
            ) {
                VStack(spacing: 12) {
                    if let height = user.height {
                        DetailRow(icon: "ruler", label: "Height", value: "\(height) cm (\(heightToFeetInches(height)))")
                    }
                    if let education = user.educationLevel, education != "Prefer not to say" {
                        DetailRow(icon: "graduationcap.fill", label: "Education", value: education)
                    }
                    if let goal = user.relationshipGoal, goal != "Prefer not to say" {
                        DetailRow(icon: "heart.circle", label: "Looking for", value: goal)
                    }
                    if let religion = user.religion, religion != "Prefer not to say" {
                        DetailRow(icon: "sparkles", label: "Religion", value: religion)
                    }
                }
            }
        }
    }

    // MARK: - Lifestyle Section

    @ViewBuilder
    private var lifestyleSection: some View {
        if hasLifestyleDetails {
            ProfileSectionCard(
                icon: "leaf.fill",
                title: "Lifestyle",
                iconColors: [.green, .mint],
                borderColor: .green
            ) {
                VStack(spacing: 12) {
                    if let smoking = user.smoking, smoking != "Prefer not to say" {
                        DetailRow(icon: "smoke", label: "Smoking", value: smoking)
                    }
                    if let drinking = user.drinking, drinking != "Prefer not to say" {
                        DetailRow(icon: "wineglass", label: "Drinking", value: drinking)
                    }
                    if let exercise = user.exercise, exercise != "Prefer not to say" {
                        DetailRow(icon: "figure.run", label: "Exercise", value: exercise)
                    }
                    if let diet = user.diet, diet != "Prefer not to say" {
                        DetailRow(icon: "fork.knife", label: "Diet", value: diet)
                    }
                    if let pets = user.pets, pets != "Prefer not to say" {
                        DetailRow(icon: "pawprint.fill", label: "Pets", value: pets)
                    }
                }
            }
        }
    }

    // MARK: - Looking For Section

    private var lookingForSection: some View {
        ProfileSectionCard(
            icon: "heart.fill",
            title: "Looking for",
            iconColors: [.purple, .pink],
            borderColor: .purple
        ) {
            Text(user.lookingFor)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 16) {
            dismissButton
            saveButton
            messageButton
            likeButton
        }
        .padding(.bottom, 30)
    }

    private var dismissButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.title2)
                .foregroundColor(.gray)
                .frame(width: 60, height: 60)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.1), radius: 5)
        }
        .accessibilityLabel("Pass")
        .accessibilityHint("Skip this profile and return to browsing")
    }

    private var saveButton: some View {
        Button {
            // DUPLICATE PREVENTION: Block rapid taps while operation is in progress
            guard !isSavingProfile else { return }

            HapticManager.shared.impact(.light)
            let wasAlreadySaved = isSaved
            isSaved.toggle()
            isSavingProfile = true

            Task {
                defer {
                    Task { @MainActor in
                        isSavingProfile = false
                    }
                }

                if isSaved {
                    // Saving - check for success and revert on failure
                    let success = await savedProfilesVM.saveProfile(user: user)
                    if !success {
                        await MainActor.run {
                            isSaved = wasAlreadySaved  // Revert on failure
                            HapticManager.shared.notification(.error)
                        }
                    }
                } else {
                    // Unsave using deterministic ID
                    if let userId = user.effectiveId {
                        savedProfilesVM.unsaveByUserId(userId)
                    }
                }
            }
        } label: {
            ZStack {
                if isSavingProfile {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.title2)
                        .foregroundColor(.orange)
                }
            }
            .frame(width: 60, height: 60)
            .background(Color.white)
            .clipShape(Circle())
            .shadow(color: Color.black.opacity(0.1), radius: 5)
        }
        .disabled(isSavingProfile)
        .accessibilityLabel(isSaved ? "Remove from saved" : "Save profile")
        .accessibilityHint("Bookmark this profile for later")
    }

    private var messageButton: some View {
        Button {
            openChat()
        } label: {
            Image(systemName: "message.fill")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 60, height: 60)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.1), radius: 5)
        }
        .accessibilityLabel("Message")
        .accessibilityHint("Start a conversation with \(user.fullName)")
    }

    private var likeButton: some View {
        Button {
            toggleLike()
        } label: {
            ZStack {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: isLiked ? .pink : .white))
                        .scaleEffect(1.0)
                } else {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundColor(isLiked ? .pink : .white)
                }
            }
            .frame(width: 60, height: 60)
            .background(
                Group {
                    if isLiked {
                        Color.white
                    } else {
                        LinearGradient(
                            colors: [Color.purple, Color.pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
            )
            .clipShape(Circle())
            .shadow(color: Color.black.opacity(0.1), radius: 5)
        }
        .disabled(isProcessing)
        .accessibilityLabel(isLiked ? "Unlike" : "Like")
        .accessibilityHint(isLiked ? "Remove like from \(user.fullName)" : "Send interest to \(user.fullName)")
    }

    // MARK: - Helper Properties

    private var hasAdvancedDetails: Bool {
        user.height != nil ||
        (user.educationLevel != nil && user.educationLevel != "Prefer not to say") ||
        (user.relationshipGoal != nil && user.relationshipGoal != "Prefer not to say") ||
        (user.religion != nil && user.religion != "Prefer not to say")
    }

    private var hasLifestyleDetails: Bool {
        (user.smoking != nil && user.smoking != "Prefer not to say") ||
        (user.drinking != nil && user.drinking != "Prefer not to say") ||
        (user.exercise != nil && user.exercise != "Prefer not to say") ||
        (user.diet != nil && user.diet != "Prefer not to say") ||
        (user.pets != nil && user.pets != "Prefer not to say")
    }

    // MARK: - Helper Functions

    private func heightToFeetInches(_ cm: Int) -> String {
        let totalInches = Double(cm) / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
        return "\(feet)'\(inches)\""
    }

    private func handleOnAppear() {
        // BUGFIX: Use effectiveId for reliable user identification (handles @DocumentID edge cases)
        isSaved = savedProfilesVM.savedProfiles.contains(where: { $0.user.effectiveId == user.effectiveId })

        // Use initial like state from parent if callback is provided (synced)
        // Otherwise fetch from backend
        if onLikeChanged != nil {
            isLiked = initialIsLiked
        }

        Task {
            // BUGFIX: Use effectiveId for reliable user identification
            guard let currentUserId = authService.currentUser?.effectiveId,
                  let viewedUserId = user.effectiveId else { return }

            // If no callback provided, fetch like status from backend
            if onLikeChanged == nil {
                do {
                    let alreadyLiked = try await SwipeService.shared.checkIfLiked(
                        fromUserId: currentUserId,
                        toUserId: viewedUserId
                    )
                    await MainActor.run {
                        isLiked = alreadyLiked
                    }
                } catch {
                    Logger.shared.error("Error checking like status", category: .matching, error: error)
                }
            }

            // Record profile view to database (for "Viewed Me" feature)
            do {
                try await ProfileStatsService.shared.recordProfileView(
                    viewerId: currentUserId,
                    viewedUserId: viewedUserId
                )
            } catch {
                Logger.shared.error("Error recording profile view", category: .general, error: error)
            }

            // Track analytics separately
            do {
                try await AnalyticsManager.shared.trackProfileView(
                    viewedUserId: viewedUserId,
                    viewerUserId: currentUserId
                )
            } catch {
                Logger.shared.error("Error tracking profile view analytics", category: .general, error: error)
            }
        }
    }

    // MARK: - Actions

    func sendInterest() {
        // BUGFIX: Use effectiveId for reliable user identification
        guard let currentUserID = authService.currentUser?.effectiveId,
              let targetUserID = user.effectiveId,
              !isProcessing else { return }

        guard currentUserID != targetUserID else {
            errorMessage = "You can't like your own profile!"
            showingError = true
            return
        }

        isProcessing = true

        Task {
            do {
                let isMatch = try await SwipeService.shared.likeUser(
                    fromUserId: currentUserID,
                    toUserId: targetUserID,
                    isSuperLike: false
                )

                await MainActor.run {
                    isProcessing = false

                    if isMatch {
                        showingMatched = true
                        HapticManager.shared.notification(.success)
                        Logger.shared.info("Match created with \(user.fullName) from detail view", category: .matching)
                    } else {
                        showingInterestSent = true
                        HapticManager.shared.impact(.medium)
                        Logger.shared.info("Like sent to \(user.fullName) from detail view", category: .matching)
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
                Logger.shared.error("Error sending like from detail view", category: .matching, error: error)
            }
        }
    }

    func toggleLike() {
        // BUGFIX: Use effectiveId for reliable user identification
        guard let currentUserID = authService.currentUser?.effectiveId,
              let targetUserID = user.effectiveId,
              !isProcessing else { return }

        guard currentUserID != targetUserID else {
            errorMessage = "You can't like your own profile!"
            showingError = true
            return
        }

        HapticManager.shared.impact(.medium)

        // Check daily like limit for free users when liking (not unliking)
        if !isLiked {
            let isPremium = authService.currentUser?.isPremium ?? false
            if !isPremium {
                guard RateLimiter.shared.canSendLike() else {
                    // Show upgrade sheet with context message
                    upgradeContextMessage = "You've reached your daily like limit. Subscribe to continue liking!"
                    showPremiumUpgrade = true
                    return
                }
            }
        }

        if isLiked {
            // Unlike the user
            isProcessing = true
            isLiked = false // Optimistic update
            onLikeChanged?(false) // Sync with parent

            Task {
                do {
                    try await SwipeService.shared.unlikeUser(
                        fromUserId: currentUserID,
                        toUserId: targetUserID
                    )

                    await MainActor.run {
                        isProcessing = false
                        showingUnliked = true
                        Logger.shared.info("Unliked \(user.fullName) from detail view", category: .matching)
                    }
                } catch {
                    await MainActor.run {
                        isProcessing = false
                        isLiked = true // Revert on error
                        onLikeChanged?(true) // Revert parent state
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                    Logger.shared.error("Error unliking from detail view", category: .matching, error: error)
                }
            }
        } else {
            // Like the user
            isProcessing = true
            isLiked = true // Optimistic update
            onLikeChanged?(true) // Sync with parent

            Task {
                do {
                    let isMatch = try await SwipeService.shared.likeUser(
                        fromUserId: currentUserID,
                        toUserId: targetUserID,
                        isSuperLike: false
                    )

                    await MainActor.run {
                        isProcessing = false

                        if isMatch {
                            showingMatched = true
                            HapticManager.shared.notification(.success)
                            Logger.shared.info("Match created with \(user.fullName) from detail view", category: .matching)
                        } else {
                            showingInterestSent = true
                            Logger.shared.info("Like sent to \(user.fullName) from detail view", category: .matching)
                        }
                    }
                } catch {
                    await MainActor.run {
                        isProcessing = false
                        isLiked = false // Revert on error
                        onLikeChanged?(false) // Revert parent state
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                    Logger.shared.error("Error sending like from detail view", category: .matching, error: error)
                }
            }
        }
    }

    func openChat() {
        // BUGFIX: Use effectiveId for reliable user identification
        guard let currentUserId = authService.currentUser?.effectiveId,
              let targetUserId = user.effectiveId else { return }

        // Prevent messaging yourself
        guard currentUserId != targetUserId else {
            errorMessage = "You can't message yourself!"
            showingError = true
            return
        }

        HapticManager.shared.impact(.medium)

        Task {
            do {
                // Check if a match already exists
                var existingMatch = try await MatchService.shared.fetchMatch(user1Id: currentUserId, user2Id: targetUserId)

                if existingMatch == nil {
                    // No match exists - create one to enable messaging
                    Logger.shared.info("Creating conversation with \(user.fullName)", category: .messaging)
                    await MatchService.shared.createMatch(user1Id: currentUserId, user2Id: targetUserId)

                    // Small delay to ensure Firestore consistency
                    try await Task.sleep(nanoseconds: 300_000_000) // 300ms

                    // Fetch the newly created match with retry
                    for attempt in 1...3 {
                        existingMatch = try await MatchService.shared.fetchMatch(user1Id: currentUserId, user2Id: targetUserId)
                        if existingMatch != nil { break }
                        if attempt < 3 {
                            try await Task.sleep(nanoseconds: 200_000_000) // 200ms between retries
                        }
                    }
                }

                await MainActor.run {
                    if let match = existingMatch {
                        chatMatch = match
                        showingChat = true
                        Logger.shared.info("Opening chat with \(user.fullName) from detail view", category: .messaging)
                    } else {
                        errorMessage = "Unable to start conversation. Please try again."
                        showingError = true
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Unable to start conversation. Please check your connection."
                    showingError = true
                }
                Logger.shared.error("Error starting conversation from detail view", category: .messaging, error: error)
            }
        }
    }
}

// MARK: - Reusable Components

struct ProfileSectionCard<Content: View>: View {
    let icon: String
    let title: String
    let iconColors: [Color]
    let borderColor: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: iconColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor.opacity(0.1), lineWidth: 1)
        )
    }
}

struct ProfileTagView: View {
    let text: String
    let colors: [Color]
    let textColor: Color

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [colors[0].opacity(0.15), colors[1].opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundColor(textColor)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(textColor.opacity(0.2), lineWidth: 1)
            )
    }
}

struct PromptCard: View {
    let prompt: ProfilePrompt

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(prompt.question)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.purple)

            Text(prompt.answer)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.05), Color.pink.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

// Simple FlowLayout for tags
struct FlowLayout2: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                     y: bounds.minY + result.frames[index].minY),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Full Screen Photo Viewer

struct FullScreenPhotoViewer: View {
    let photos: [String]
    @Binding var selectedIndex: Int
    @Binding var isPresented: Bool

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero

    // Swipe-down to dismiss state
    @State private var dismissDragOffset: CGFloat = 0
    @State private var isDismissing = false

    // Threshold for dismissing (150 points down)
    private let dismissThreshold: CGFloat = 150

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Black background with opacity based on drag
                Color.black
                    .opacity(backgroundOpacity)
                    .ignoresSafeArea()

                // PERFORMANCE: Photo carousel with smooth swiping
                TabView(selection: $selectedIndex) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, photoURL in
                        ZoomablePhotoView(
                            url: URL(string: photoURL),
                            isCurrentPhoto: index == selectedIndex
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                // Apply dismiss offset and scale
                .offset(y: dismissDragOffset)
                .scaleEffect(dismissScale)
                // PERFORMANCE: Preload adjacent photos when index changes
                .onChange(of: selectedIndex) { newIndex in
                    ImageCache.shared.prefetchAdjacentPhotos(photos: photos, currentIndex: newIndex)
                }

                // Close button and counter overlay
                VStack {
                    HStack {
                        // Close button with blur background
                        Button {
                            HapticManager.shared.impact(.light)
                            isPresented = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
                        }

                        Spacer()

                        // Photo counter with blur background
                        Text("\(selectedIndex + 1) / \(photos.count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)

                    Spacer()
                }
                .opacity(controlsOpacity)
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
                            isDismissing = true
                            HapticManager.shared.impact(.light)
                            withAnimation(.easeOut(duration: 0.2)) {
                                dismissDragOffset = geometry.size.height
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                isPresented = false
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
        .statusBarHidden()
        // PERFORMANCE: Preload adjacent photos on appear
        .onAppear {
            ImageCache.shared.prefetchAdjacentPhotos(photos: photos, currentIndex: selectedIndex)
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

// MARK: - Zoomable Photo View

struct ZoomablePhotoView: View {
    let url: URL?
    let isCurrentPhoto: Bool

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    init(url: URL?, isCurrentPhoto: Bool = true) {
        self.url = url
        self.isCurrentPhoto = isCurrentPhoto
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Subtle background for better image presentation
                Color.black

                // PERFORMANCE: Use immediate priority for current photo, high for others
                CachedCardImage(url: url, priority: isCurrentPhoto ? .immediate : .high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(scale)
                    .offset(offset)
                    // Add subtle shadow for depth
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale = min(max(scale * delta, 1), 4)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                if scale < 1 {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        scale = 1
                                        offset = .zero
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        scale > 1 ?
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                        : nil
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            if scale > 1 {
                                scale = 1
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2
                            }
                        }
                        HapticManager.shared.impact(.light)
                    }
            }
        }
    }
}

#Preview {
    UserDetailView(user: User(
        email: "test@test.com",
        fullName: "Sofia",
        age: 25,
        gender: "Female",
        lookingFor: "Men",
        bio: "Love to travel and learn new languages. Looking for someone to explore the world with!",
        location: "Barcelona",
        country: "Spain",
        languages: ["Spanish", "English", "French"],
        interests: ["Travel", "Photography", "Cooking", "Music"]
    ))
}
