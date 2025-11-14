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
    @Published var connectionQuality: PerformanceMonitor.ConnectionQuality = .excellent

    // Computed property that syncs with DiscoveryFilters.shared
    var hasActiveFilters: Bool {
        return DiscoveryFilters.shared.hasActiveFilters
    }

    var remainingCount: Int {
        return max(0, users.count - currentIndex)
    }

    // Dependency injection: Services
    private let userService: any UserServiceProtocol

    // SWIFT 6 CONCURRENCY: These properties are accessed across async boundaries
    // but are always accessed from MainActor-isolated methods. Marked nonisolated(unsafe)
    // to satisfy Swift 6 strict concurrency while maintaining thread safety through MainActor.
    nonisolated(unsafe) private var lastDocument: DocumentSnapshot?
    nonisolated(unsafe) private var interestTask: Task<Void, Never>?
    private let performanceMonitor = PerformanceMonitor.shared

    // Dependency injection initializer
    init(userService: (any UserServiceProtocol)? = nil) {
        self.userService = userService ?? UserService.shared
    }
    
    func loadUsers(currentUser: User, limit: Int = 20) {
        // Validate current user has an ID
        guard let userId = currentUser.id, !userId.isEmpty else {
            errorMessage = "Unable to load users: User account not properly initialized"
            isLoading = false
            Logger.shared.error("Cannot load users: Current user has no ID", category: .matching)
            return
        }

        isLoading = true
        errorMessage = ""

        // Track query performance
        let queryStart = Date()

        Task {
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

                // Track network latency
                let queryDuration = Date().timeIntervalSince(queryStart) * 1000
                await performanceMonitor.trackQuery(duration: queryDuration)
                await performanceMonitor.trackNetworkLatency(latency: queryDuration)

                // Update connection quality
                connectionQuality = await performanceMonitor.connectionQuality

                // Update local users array from service
                users = userService.users
                isLoading = false

                // Preload images for next 2 users
                await self.preloadUpcomingImages()

                Logger.shared.info("Loaded \(users.count) users in \(String(format: "%.0f", queryDuration))ms", category: .matching)
            } catch {
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
    
    func sendInterest(from currentUserID: String, to targetUserID: String, completion: @escaping (Bool) -> Void) {
        // Cancel previous interest task if any
        interestTask?.cancel()

        interestTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            do {
                try await InterestService.shared.sendInterest(
                    fromUserId: currentUserID,
                    toUserId: targetUserID
                )
                guard !Task.isCancelled else { return }
                completion(true)
            } catch {
                Logger.shared.error("Error sending interest", category: .matching, error: error)
                guard !Task.isCancelled else { return }
                completion(false)
            }
        }
    }

    /// Show user detail sheet
    func showUserDetail(_ user: User) {
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
        guard let currentUser = AuthService.shared.currentUser,
              let currentUserId = currentUser.id,
              let likedUserId = likedUser.id else {
            isProcessingAction = false
            return
        }

        // Check daily like limit for non-premium users
        if !currentUser.isPremium {
            let canLike = await checkDailyLikeLimit()
            if !canLike {
                isProcessingAction = false
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

        // Preload images for next users
        await preloadUpcomingImages()

        // Send like to backend
        do {
            let isMatch = try await SwipeService.shared.likeUser(
                fromUserId: currentUserId,
                toUserId: likedUserId,
                isSuperLike: false
            )

            // Decrement daily like counter if not premium
            if !currentUser.isPremium {
                await decrementDailyLikes()
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
            // Still move forward even if like fails
        }

        isProcessingAction = false
    }

    /// Check if user has daily likes remaining (delegates to UserService)
    private func checkDailyLikeLimit() async -> Bool {
        guard let userId = AuthService.shared.currentUser?.id else { return false }

        let hasLikes = await UserService.shared.checkDailyLikeLimit(userId: userId)

        // Refresh current user if limits were reset
        if hasLikes {
            await AuthService.shared.fetchUser()
        }

        return hasLikes
    }

    /// Decrement daily like count (delegates to UserService)
    private func decrementDailyLikes() async {
        guard let userId = AuthService.shared.currentUser?.id else { return }

        await UserService.shared.decrementDailyLikes(userId: userId)
        await AuthService.shared.fetchUser()
    }

    /// Handle pass action
    func handlePass() async {
        guard currentIndex < users.count, !isProcessingAction else { return }
        isProcessingAction = true

        let passedUser = users[currentIndex]
        guard let currentUserId = AuthService.shared.currentUser?.id,
              let passedUserId = passedUser.id else {
            isProcessingAction = false
            return
        }

        // Move to next card with animation
        withAnimation {
            currentIndex += 1
            dragOffset = .zero
        }

        // Preload images for next users
        await preloadUpcomingImages()

        // Record pass in backend
        do {
            try await SwipeService.shared.passUser(
                fromUserId: currentUserId,
                toUserId: passedUserId
            )
            Logger.shared.info("Pass recorded for \(passedUser.fullName)", category: .matching)
        } catch {
            Logger.shared.error("Error recording pass", category: .matching, error: error)
            // Still move forward even if pass fails
        }

        isProcessingAction = false
    }

    /// Handle super like action
    func handleSuperLike() async {
        guard currentIndex < users.count, !isProcessingAction else { return }
        isProcessingAction = true

        let superLikedUser = users[currentIndex]
        guard let currentUser = AuthService.shared.currentUser,
              let currentUserId = currentUser.id,
              let superLikedUserId = superLikedUser.id else {
            isProcessingAction = false
            return
        }

        // Check if user has super likes remaining
        if currentUser.superLikesRemaining <= 0 {
            isProcessingAction = false
            showingUpgradeSheet = true
            Logger.shared.warning("No Super Likes remaining. User needs to purchase more", category: .payment)
            return
        }

        // Move to next card with animation
        withAnimation {
            currentIndex += 1
            dragOffset = .zero
        }

        // Preload images for next users
        await preloadUpcomingImages()

        // Send super like to backend
        do {
            let isMatch = try await SwipeService.shared.likeUser(
                fromUserId: currentUserId,
                toUserId: superLikedUserId,
                isSuperLike: true
            )

            // Deduct super like from balance
            await decrementSuperLikes()

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
            // Still move forward even if super like fails
        }

        isProcessingAction = false
    }

    /// Decrement super like count (delegates to UserService)
    private func decrementSuperLikes() async {
        guard let userId = AuthService.shared.currentUser?.id else { return }

        await UserService.shared.decrementSuperLikes(userId: userId)
        await AuthService.shared.fetchUser()
        Logger.shared.info("Super Like used. Remaining: \(AuthService.shared.currentUser?.superLikesRemaining ?? 0)", category: .matching)
    }

    /// Apply filters
    func applyFilters() {
        currentIndex = 0

        guard let currentUser = AuthService.shared.currentUser else {
            Logger.shared.warning("Cannot apply filters: No current user", category: .matching)
            return
        }

        // Get current user location for distance filtering
        let currentLocation: (lat: Double, lon: Double)? = {
            if let lat = currentUser.latitude, let lon = currentUser.longitude {
                return (lat, lon)
            }
            return nil
        }()

        // Show loading state while applying filters
        isLoading = true

        Task {
            // Clear current users and reload
            users.removeAll()
            lastDocument = nil

            // Reload users from Firestore
            loadUsers(currentUser: currentUser)

            // Wait for users to load, then filter them locally
            try? await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5s for load

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
        guard let currentUser = AuthService.shared.currentUser else {
            Logger.shared.warning("Cannot load users: No current user", category: .matching)
            return
        }

        loadUsers(currentUser: currentUser)
    }

    /// Cleanup method to cancel ongoing tasks
    func cleanup() {
        interestTask?.cancel()
        interestTask = nil
        users = []
        lastDocument = nil
    }

    deinit {
        interestTask?.cancel()
    }
}
