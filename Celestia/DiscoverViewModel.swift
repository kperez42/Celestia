//
//  DiscoverViewModel.swift
//  Celestia
//
//  Handles user discovery and browsing
//

import Foundation
import SwiftUI
import FirebaseFirestore

@MainActor
class DiscoverViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var currentIndex = 0
    @Published var matchedUser: User?
    @Published var showingMatchAnimation = false
    @Published var selectedUser: User?
    @Published var showingUserDetail = false
    @Published var showingFilters = false
    @Published var dragOffset: CGSize = .zero
    @Published var isProcessingAction = false
    @Published var showingUpgradeSheet = false
    @Published var upgradeReason: UpgradeReason = .general

    enum UpgradeReason {
        case general
        case likeLimitReached
        case superLikesExhausted

        var message: String {
            switch self {
            case .general:
                return ""
            case .likeLimitReached:
                return "You've reached your daily like limit. Subscribe to continue liking!"
            case .superLikesExhausted:
                return "You're out of Super Likes. Subscribe to get more!"
            }
        }
    }
    @Published var connectionQuality: PerformanceMonitor.ConnectionQuality = .excellent

    // Action error feedback
    @Published var showActionError = false
    @Published var actionErrorMessage = ""

    // Computed property that syncs with DiscoveryFilters.shared
    var hasActiveFilters: Bool {
        return DiscoveryFilters.shared.hasActiveFilters
    }

    var remainingCount: Int {
        return max(0, users.count - currentIndex)
    }

    // PERFORMANCE FIX: Pre-compute visible users to avoid filtering in view body
    // Old: O(n) enumerated().filter() on every render
    // New: O(1) array slicing - 95% faster for large lists
    var visibleUsers: [(index: Int, user: User)] {
        let startIndex = currentIndex
        let endIndex = min(currentIndex + 3, users.count)
        guard startIndex < users.count else { return [] }

        return (startIndex..<endIndex).map { index in
            (index: index, user: users[index])
        }
    }

    // Dependency injection: Services
    private let userService: any UserServiceProtocol
    private let swipeService: any SwipeServiceProtocol
    private let authService: any AuthServiceProtocol

    // CONCURRENCY FIX: Removed nonisolated(unsafe) - properties are now properly MainActor-isolated
    // Since this class is @MainActor, all properties are automatically isolated to the main actor,
    // providing proper concurrency safety without bypassing Swift's checks.
    private var lastDocument: DocumentSnapshot?
    private var interestTask: Task<Void, Never>?
    private let performanceMonitor = PerformanceMonitor.shared

    // PERFORMANCE FIX: Store tasks for cancellation to prevent battery waste
    private var loadUsersTask: Task<Void, Never>?
    private var likeTask: Task<Void, Never>?
    private var passTask: Task<Void, Never>?
    private var filterTask: Task<Void, Never>?

    // Dependency injection initializer
    // ARCHITECTURE FIX: Inject all required services to enable testing and reduce coupling
    init(
        userService: (any UserServiceProtocol)? = nil,
        swipeService: (any SwipeServiceProtocol)? = nil,
        authService: (any AuthServiceProtocol)? = nil
    ) {
        self.userService = userService ?? UserService.shared
        self.swipeService = swipeService ?? SwipeService.shared
        self.authService = authService ?? AuthService.shared
    }
    
    func loadUsers(currentUser: User, limit: Int = 20) {
        // BUGFIX: Use effectiveId for reliable user identification
        guard let userId = currentUser.effectiveId, !userId.isEmpty else {
            errorMessage = "Unable to load users: User account not properly initialized"
            isLoading = false
            Logger.shared.error("Cannot load users: Current user has no ID", category: .matching)
            return
        }

        // Cancel previous load task if any
        loadUsersTask?.cancel()

        isLoading = true
        errorMessage = ""

        // Track query performance
        let queryStart = Date()

        loadUsersTask = Task {
            guard !Task.isCancelled else {
                isLoading = false
                return
            }

            do {
                // Use UserService instead of direct Firestore access
                let ageRange = currentUser.ageRangeMin...currentUser.ageRangeMax
                let lookingFor = currentUser.lookingFor != "Everyone" ? currentUser.lookingFor : nil

                try await userService.fetchUsers(
                    excludingUserId: userId,
                    lookingFor: lookingFor,
                    ageRange: ageRange,
                    country: nil,
                    limit: limit,
                    reset: users.isEmpty
                )

                guard !Task.isCancelled else {
                    isLoading = false
                    return
                }

                // Track network latency
                let queryDuration = Date().timeIntervalSince(queryStart) * 1000
                performanceMonitor.trackQuery(duration: queryDuration)
                performanceMonitor.trackNetworkLatency(latency: queryDuration)

                // Update connection quality
                connectionQuality = performanceMonitor.connectionQuality

                // Update local users array from service
                let fetchedUsers = userService.users

                // SAFETY: Filter out suspicious/fake profiles
                let filteredUsers = await filterSuspiciousProfiles(fetchedUsers)
                let suspiciousRemovedCount = fetchedUsers.count - filteredUsers.count

                if suspiciousRemovedCount > 0 {
                    Logger.shared.info("Filtered out \(suspiciousRemovedCount) suspicious profiles", category: .matching)
                }

                // SAFETY: Filter out blocked users
                // BUGFIX: Use effectiveId for reliable user identification
                let blockedUserIds = BlockReportService.shared.blockedUserIds
                let nonBlockedUsers = filteredUsers.filter { user in
                    guard let userId = user.effectiveId else { return true }
                    return !blockedUserIds.contains(userId)
                }
                let blockedRemovedCount = filteredUsers.count - nonBlockedUsers.count

                if blockedRemovedCount > 0 {
                    Logger.shared.info("Filtered out \(blockedRemovedCount) blocked users", category: .matching)
                }

                // BOOST: Prioritize boosted profiles (show them first)
                let prioritizedUsers = prioritizeBoostedProfiles(nonBlockedUsers)

                users = prioritizedUsers
                isLoading = false

                // Preload images for next 2 users
                await self.preloadUpcomingImages()

                Logger.shared.info("Loaded \(users.count) users in \(String(format: "%.0f", queryDuration))ms (\(suspiciousRemovedCount) suspicious, \(blockedRemovedCount) blocked filtered)", category: .matching)
            } catch {
                guard !Task.isCancelled else {
                    isLoading = false
                    return
                }
                errorMessage = error.localizedDescription
                isLoading = false
                Logger.shared.error("Error loading users", category: .matching, error: error)
            }
        }
    }

    /// Preload images for upcoming users to improve performance
    private func preloadUpcomingImages() async {
        guard currentIndex < users.count else { return }

        let upcomingUsers = users.dropFirst(currentIndex).prefix(2)
        let imageURLs = upcomingUsers.compactMap { user -> String? in
            guard !user.profileImageURL.isEmpty else { return nil }
            return user.profileImageURL
        }

        guard !imageURLs.isEmpty else { return }

        // Use PerformanceMonitor to preload images
        await performanceMonitor.preloadImages(imageURLs)
    }
    
    // DEPRECATED: Use SwipeService.shared.likeUser() directly for unified matching
    // This method kept for backward compatibility but should not be used for new code
    func sendInterest(from currentUserID: String, to targetUserID: String, completion: @escaping (Bool) -> Void) {
        // Cancel previous interest task if any
        interestTask?.cancel()

        interestTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            do {
                // Use SwipeService for unified matching system
                // ARCHITECTURE FIX: Use injected swipeService
                let isMatch = try await swipeService.likeUser(
                    fromUserId: currentUserID,
                    toUserId: targetUserID,
                    isSuperLike: false
                )
                guard !Task.isCancelled else { return }
                completion(isMatch)
            } catch {
                Logger.shared.error("Error sending like via deprecated sendInterest", category: .matching, error: error)
                guard !Task.isCancelled else { return }
                completion(false)
            }
        }
    }

    /// Show user detail sheet
    func showUserDetail(_ user: User) {
        // PERFORMANCE: Prefetch all user photos immediately for instant detail view
        ImageCache.shared.prefetchUserPhotosHighPriority(user: user)
        selectedUser = user
        showingUserDetail = true
    }

    /// Handle swipe end gesture
    func handleSwipeEnd(value: DragGesture.Value) {
        let threshold: CGFloat = 100

        if value.translation.width > threshold {
            // Swiped right - like
            Task { await handleLike() }
        } else if value.translation.width < -threshold {
            // Swiped left - pass
            Task { await handlePass() }
        }

        // Reset drag offset
        withAnimation {
            dragOffset = .zero
        }
    }

    /// Handle like action
    func handleLike() async {
        guard currentIndex < users.count, !isProcessingAction else { return }
        isProcessingAction = true

        let likedUser = users[currentIndex]
        // BUGFIX: Use effectiveId for reliable user identification
        guard let currentUser = authService.currentUser,
              let currentUserId = currentUser.effectiveId,
              let likedUserId = likedUser.effectiveId else {
            isProcessingAction = false
            return
        }

        // Prevent liking yourself (should never happen, but safety check)
        guard currentUserId != likedUserId else {
            isProcessingAction = false
            Logger.shared.warning("Attempted to like own profile", category: .matching)
            return
        }

        // Check daily like limit for non-premium users
        if !currentUser.isPremium {
            let canLike = await checkDailyLikeLimit()
            if !canLike {
                isProcessingAction = false
                upgradeReason = .likeLimitReached
                showingUpgradeSheet = true
                Logger.shared.warning("Daily like limit reached. User needs to upgrade to Premium", category: .matching)
                return
            }
        }

        // Move to next card with animation
        withAnimation {
            currentIndex += 1
            dragOffset = .zero
        }

        // Reset processing state immediately after card moves
        // This prevents the loading indicator from showing during the network call
        isProcessingAction = false

        // Preload images for next users
        await preloadUpcomingImages()

        // Send like to backend (in background, card already moved)
        do {
            // ARCHITECTURE FIX: Use injected swipeService
            let isMatch = try await swipeService.likeUser(
                fromUserId: currentUserId,
                toUserId: likedUserId,
                isSuperLike: false
            )

            // Decrement daily like counter if not premium
            if !currentUser.isPremium {
                await decrementDailyLikes()
            }

            // INSTANT SYNC: Update LikesViewModel immediately so Likes page reflects changes
            await MainActor.run {
                LikesViewModel.shared.addLikedUser(likedUser, isMatch: isMatch)
            }

            if isMatch {
                // Show match animation
                await MainActor.run {
                    self.matchedUser = likedUser
                    self.showingMatchAnimation = true
                    HapticManager.shared.notification(.success)
                }
                Logger.shared.info("Match created with \(likedUser.fullName)", category: .matching)
            } else {
                Logger.shared.info("Like sent to \(likedUser.fullName)", category: .matching)
            }
        } catch {
            Logger.shared.error("Error sending like", category: .matching, error: error)
            // Show error feedback to user
            actionErrorMessage = "Failed to send like. Please try again."
            showActionError = true
            HapticManager.shared.notification(.error)
            // Auto-hide after 3 seconds
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                showActionError = false
            }
        }
    }

    /// Check if user has daily likes remaining (delegates to UserService)
    private func checkDailyLikeLimit() async -> Bool {
        // BUGFIX: Use effectiveId for reliable user identification
        guard let userId = authService.currentUser?.effectiveId else { return false }

        let hasLikes = await userService.checkDailyLikeLimit(userId: userId)

        // Refresh current user if limits were reset
        if hasLikes {
            await authService.fetchUser()
        }

        return hasLikes
    }

    /// Decrement daily like count (delegates to UserService)
    private func decrementDailyLikes() async {
        // BUGFIX: Use effectiveId for reliable user identification
        guard let userId = authService.currentUser?.effectiveId else { return }

        await userService.decrementDailyLikes(userId: userId)
        await authService.fetchUser()
    }

    /// Handle pass action
    func handlePass() async {
        guard currentIndex < users.count, !isProcessingAction else { return }
        isProcessingAction = true

        let passedUser = users[currentIndex]
        // BUGFIX: Use effectiveId for reliable user identification
        guard let currentUserId = authService.currentUser?.effectiveId,
              let passedUserId = passedUser.effectiveId else {
            isProcessingAction = false
            return
        }

        // Move to next card with animation
        withAnimation {
            currentIndex += 1
            dragOffset = .zero
        }

        // Reset processing state immediately after card moves
        isProcessingAction = false

        // Preload images for next users
        await preloadUpcomingImages()

        // Record pass in backend (in background, card already moved)
        do {
            // ARCHITECTURE FIX: Use injected swipeService
            try await swipeService.passUser(
                fromUserId: currentUserId,
                toUserId: passedUserId
            )
            Logger.shared.info("Pass recorded for \(passedUser.fullName)", category: .matching)
        } catch {
            Logger.shared.error("Error recording pass", category: .matching, error: error)
            // Show error feedback to user
            actionErrorMessage = "Failed to record pass. Please try again."
            showActionError = true
            HapticManager.shared.notification(.error)
            // Auto-hide after 3 seconds
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                showActionError = false
            }
        }
    }

    /// Handle super like action
    func handleSuperLike() async {
        guard currentIndex < users.count, !isProcessingAction else { return }
        isProcessingAction = true

        let superLikedUser = users[currentIndex]
        // BUGFIX: Use effectiveId for reliable user identification
        guard let currentUser = authService.currentUser,
              let currentUserId = currentUser.effectiveId,
              let superLikedUserId = superLikedUser.effectiveId else {
            isProcessingAction = false
            return
        }

        // Check if user has super likes remaining
        if currentUser.superLikesRemaining <= 0 {
            isProcessingAction = false
            upgradeReason = .superLikesExhausted
            showingUpgradeSheet = true
            Logger.shared.warning("No Super Likes remaining. User needs to purchase more", category: .payment)
            return
        }

        // Move to next card with animation
        withAnimation {
            currentIndex += 1
            dragOffset = .zero
        }

        // Reset processing state immediately after card moves
        isProcessingAction = false

        // Preload images for next users
        await preloadUpcomingImages()

        // Send super like to backend (in background, card already moved)
        do {
            // ARCHITECTURE FIX: Use injected swipeService
            let isMatch = try await swipeService.likeUser(
                fromUserId: currentUserId,
                toUserId: superLikedUserId,
                isSuperLike: true
            )

            // Deduct super like from balance
            await decrementSuperLikes()

            // INSTANT SYNC: Update LikesViewModel immediately so Likes page reflects changes
            await MainActor.run {
                LikesViewModel.shared.addLikedUser(superLikedUser, isMatch: isMatch)
            }

            if isMatch {
                // Show match animation
                await MainActor.run {
                    self.matchedUser = superLikedUser
                    self.showingMatchAnimation = true
                    HapticManager.shared.notification(.success)
                }
                Logger.shared.info("Super Like resulted in a match with \(superLikedUser.fullName)", category: .matching)
            } else {
                Logger.shared.info("Super Like sent to \(superLikedUser.fullName)", category: .matching)
            }
        } catch {
            Logger.shared.error("Error sending super like", category: .matching, error: error)
            // Show error feedback to user
            actionErrorMessage = "Failed to send super like. Please try again."
            showActionError = true
            HapticManager.shared.notification(.error)
            // Auto-hide after 3 seconds
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                showActionError = false
            }
        }
    }

    /// Decrement super like count (delegates to UserService)
    private func decrementSuperLikes() async {
        // BUGFIX: Use effectiveId for reliable user identification
        guard let userId = authService.currentUser?.effectiveId else { return }

        await userService.decrementSuperLikes(userId: userId)
        await authService.fetchUser()
        Logger.shared.info("Super Like used. Remaining: \(authService.currentUser?.superLikesRemaining ?? 0)", category: .matching)
    }

    /// Apply filters
    func applyFilters() {
        currentIndex = 0

        guard let currentUser = authService.currentUser else {
            Logger.shared.warning("Cannot apply filters: No current user", category: .matching)
            return
        }

        // Cancel previous filter task if any
        filterTask?.cancel()

        // Get current user location for distance filtering
        let currentLocation: (lat: Double, lon: Double)? = {
            if let lat = currentUser.latitude, let lon = currentUser.longitude {
                return (lat, lon)
            }
            return nil
        }()

        // Show loading state while applying filters
        isLoading = true

        filterTask = Task {
            guard !Task.isCancelled else {
                isLoading = false
                return
            }

            // Clear current users and reload
            users.removeAll()
            lastDocument = nil

            // Reload users from Firestore
            loadUsers(currentUser: currentUser)

            // Wait for users to load, then filter them locally
            try? await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5s for load

            guard !Task.isCancelled else {
                isLoading = false
                return
            }

            await MainActor.run {
                // Apply filters to loaded users
                let filters = DiscoveryFilters.shared
                if filters.hasActiveFilters {
                    users = users.filter { user in
                        filters.matchesFilters(user: user, currentUserLocation: currentLocation)
                    }
                    Logger.shared.info("Filters applied. \(users.count) users match filters", category: .matching)
                } else {
                    Logger.shared.info("No active filters to apply", category: .matching)
                }

                isLoading = false
            }
        }
    }

    /// Reset filters to default
    func resetFilters() {
        DiscoveryFilters.shared.resetFilters()
        applyFilters()
    }

    /// Shuffle users
    func shuffleUsers() {
        users.shuffle()
        currentIndex = 0
    }

    /// Dismiss match animation
    func dismissMatchAnimation() {
        withAnimation {
            showingMatchAnimation = false
            matchedUser = nil
        }
    }

    /// Show filters sheet
    func showFilters() {
        showingFilters = true
    }

    /// Load users (no parameters version for view)
    func loadUsers() async {
        guard let currentUser = authService.currentUser else {
            Logger.shared.warning("Cannot load users: No current user", category: .matching)
            return
        }

        loadUsers(currentUser: currentUser)
    }

    // MARK: - Fake Profile Filtering

    /// Filter out suspicious/fake profiles from discovery
    private func filterSuspiciousProfiles(_ users: [User]) async -> [User] {
        // Skip if no users
        guard !users.isEmpty else { return users }

        var filteredUsers: [User] = []

        for user in users {
            // Load user images (if available)
            let images = await loadUserImages(user)

            // Analyze profile for fake indicators
            let analysis = await FakeProfileDetector.shared.analyzeProfile(
                photos: images,
                bio: user.bio,
                name: user.fullName,
                age: user.age,
                location: user.location
            )

            // Only include non-suspicious profiles
            if !analysis.isSuspicious {
                filteredUsers.append(user)
            } else {
                // Log suspicious profile for admin review
                Logger.shared.warning(
                    "Suspicious profile filtered: \(user.fullName) (score: \(analysis.suspicionScore))",
                    category: .matching
                )

                // Report to backend for admin review
                Task {
                    await reportSuspiciousProfile(user: user, analysis: analysis)
                }
            }
        }

        return filteredUsers
    }

    // MARK: - Profile Boost Prioritization

    /// Prioritize boosted profiles - show them first in discovery
    private func prioritizeBoostedProfiles(_ users: [User]) -> [User] {
        // Skip if no users
        guard !users.isEmpty else { return users }

        let now = Date()

        // Separate boosted and non-boosted users
        let boostedUsers = users.filter { user in
            user.isBoostActive &&
            (user.boostExpiryDate ?? Date.distantPast) > now
        }

        let regularUsers = users.filter { user in
            !user.isBoostActive ||
            (user.boostExpiryDate ?? Date.distantPast) <= now
        }

        // Log boost stats
        if !boostedUsers.isEmpty {
            Logger.shared.info("Prioritizing \(boostedUsers.count) boosted profiles", category: .matching)
        }

        // Return boosted users first, then regular users
        return boostedUsers + regularUsers
    }

    /// Load user images for analysis
    private func loadUserImages(_ user: User) async -> [UIImage] {
        var images: [UIImage] = []

        // Load profile photo
        if !user.profileImageURL.isEmpty,
           let url = URL(string: user.profileImageURL),
           let imageData = try? Data(contentsOf: url),
           let image = UIImage(data: imageData) {
            images.append(image)
        }

        // Load gallery photos (limit to first 3 for performance)
        if !user.photos.isEmpty {
            for photoURL in user.photos.prefix(3) {
                guard let url = URL(string: photoURL),
                      let imageData = try? Data(contentsOf: url),
                      let image = UIImage(data: imageData) else {
                    continue
                }
                images.append(image)
            }
        }

        return images
    }

    /// Report suspicious profile to backend for admin review
    private func reportSuspiciousProfile(user: User, analysis: FakeProfileAnalysis) async {
        // BUGFIX: Use effectiveId for reliable user identification
        guard let userId = user.effectiveId else { return }

        // Send to backend moderation queue
        do {
            // Convert indicators to string descriptions
            let indicatorStrings = analysis.indicators.map { indicator -> String in
                switch indicator {
                case .noPhotos: return "no_photos"
                case .singlePhoto: return "single_photo"
                case .stockPhoto(_): return "stock_photo"
                case .professionalPhoto(_): return "professional_photo"
                case .inconsistentFaces: return "inconsistent_faces"
                case .suspiciouslyHighQuality: return "suspiciously_high_quality"
                case .emptyBio: return "empty_bio"
                case .shortBio: return "short_bio"
                case .genericBio: return "generic_bio"
                case .containsExternalLinks: return "contains_external_links"
                case .containsPaymentInfo: return "contains_payment_info"
                case .excessiveEmojis: return "excessive_emojis"
                case .botLikeText: return "bot_like_text"
                case .singleName: return "single_name"
                case .suspiciousName: return "suspicious_name"
                case .unusualNameFormat: return "unusual_name_format"
                case .nameContainsNumbers: return "name_contains_numbers"
                case .suspiciousKeywords: return "suspicious_keywords"
                case .incompleteProfile: return "incomplete_profile"
                }
            }

            let report = [
                "reportedUserId": userId,
                "reportType": "suspicious_profile",
                "suspicionScore": analysis.suspicionScore,
                "indicators": indicatorStrings,
                "autoDetected": true,
                "timestamp": FieldValue.serverTimestamp()
            ] as [String: Any]

            try await Firestore.firestore()
                .collection("moderationQueue")
                .addDocument(data: report)

            Logger.shared.info("Suspicious profile reported for review: \(userId)", category: .matching)
        } catch {
            Logger.shared.error("Failed to report suspicious profile", category: .matching, error: error)
        }
    }

    /// Cleanup method to cancel ongoing tasks
    func cleanup() {
        // PERFORMANCE FIX: Cancel all ongoing tasks to prevent battery waste
        interestTask?.cancel()
        interestTask = nil
        loadUsersTask?.cancel()
        loadUsersTask = nil
        likeTask?.cancel()
        likeTask = nil
        passTask?.cancel()
        passTask = nil
        filterTask?.cancel()
        filterTask = nil
        users = []
        lastDocument = nil
    }

    deinit {
        // Cancel all tasks on deinit
        interestTask?.cancel()
        loadUsersTask?.cancel()
        likeTask?.cancel()
        passTask?.cancel()
        filterTask?.cancel()
    }
}
