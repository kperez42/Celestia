//
//  DiscoverViewModel.swift
//  Celestia
//
//  ViewModel for DiscoverView - Manages card stack state and swipe logic
//

import Foundation
import SwiftUI

@MainActor
class DiscoverViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var currentIndex = 0
    @Published var users: [User] = []
    @Published var allUsers: [User] = [] // Unfiltered list
    @Published var isLoading = false
    @Published var dragOffset: CGSize = .zero
    @Published var showingMatchAnimation = false
    @Published var matchedUser: User?
    @Published var swipeHistory: [SwipeAction] = []
    @Published var showUndoButton = false
    @Published var selectedUser: User?
    @Published var showingUserDetail = false
    @Published var showingFilters = false

    // MARK: - Dependencies

    private let userService: UserService
    private let matchService: MatchService
    private let swipeService: SwipeService
    private let filters: DiscoveryFilters
    private let authService: AuthService

    // MARK: - Initialization

    init(
        userService: UserService = UserService.shared,
        matchService: MatchService = MatchService.shared,
        swipeService: SwipeService = SwipeService.shared,
        filters: DiscoveryFilters = DiscoveryFilters.shared,
        authService: AuthService = AuthService.shared
    ) {
        self.userService = userService
        self.matchService = matchService
        self.swipeService = swipeService
        self.filters = filters
        self.authService = authService
    }

    // MARK: - Computed Properties

    var hasActiveFilters: Bool {
        filters.hasActiveFilters
    }

    var currentUser: User? {
        guard currentIndex < users.count else { return nil }
        return users[currentIndex]
    }

    var remainingCount: Int {
        users.count - currentIndex
    }

    // MARK: - Public Methods

    func loadUsers() async {
        #if DEBUG
        // Use test data in debug builds for easier testing
        allUsers = TestData.discoverUsers
        applyFilters()
        currentIndex = 0
        isLoading = false
        return
        #endif

        guard let currentUserId = authService.currentUser?.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            try await userService.fetchUsers(
                excludingUserId: currentUserId,
                limit: 50,
                reset: true
            )
            allUsers = userService.users
            applyFilters()
            currentIndex = 0
        } catch {
            Logger.shared.error("Error loading users: \(error)", category: .general)
        }
    }

    func applyFilters() {
        let currentLocation: (lat: Double, lon: Double)? = {
            if let user = authService.currentUser,
               let lat = user.latitude,
               let lon = user.longitude {
                return (lat, lon)
            }
            return nil
        }()

        users = allUsers.filter { user in
            filters.matchesFilters(user: user, currentUserLocation: currentLocation)
        }

        // Reset index if needed
        if currentIndex >= users.count {
            currentIndex = 0
        }
    }

    func shuffleUsers() {
        HapticManager.shared.impact(.medium)
        withAnimation {
            users.shuffle()
            currentIndex = 0
        }
    }

    func resetFilters() {
        HapticManager.shared.impact(.medium)
        filters.resetFilters()
        applyFilters()
    }

    func showUserDetail(_ user: User) {
        selectedUser = user
        showingUserDetail = true
        HapticManager.shared.impact(.medium)
    }

    func showFilters() {
        showingFilters = true
    }

    // MARK: - Swipe Handling

    func handleSwipeEnd(value: DragGesture.Value) {
        guard let user = currentUser else { return }

        let threshold: CGFloat = 100

        withAnimation {
            if value.translation.width > threshold {
                // Like
                dragOffset = CGSize(width: 500, height: 0)
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                    await handleLike()
                    dragOffset = .zero
                }
            } else if value.translation.width < -threshold {
                // Pass
                dragOffset = CGSize(width: -500, height: 0)
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                    await handlePass()
                    dragOffset = .zero
                }
            } else {
                dragOffset = .zero
            }
        }
    }

    func handleLike(isSuperLike: Bool = false) async {
        guard let user = currentUser else { return }

        // Save to history for undo
        swipeHistory.append(SwipeAction(user: user, index: currentIndex, wasLike: true))
        showUndoButton = true

        // Haptic feedback
        if isSuperLike {
            HapticManager.shared.superLike()
        } else {
            HapticManager.shared.swipeRight()
        }

        guard let currentUserId = authService.currentUser?.id,
              let userId = user.id else {
            withAnimation {
                currentIndex += 1
            }
            return
        }

        // Track swipe analytics
        do {
            try await AnalyticsManager.shared.trackSwipe(
                swipedUserId: userId,
                swiperUserId: currentUserId,
                direction: AnalyticsSwipeDirection.right
            )
        } catch {
            Logger.shared.error("Error tracking swipe: \(error)", category: .analytics)
        }

        // Create like and check for mutual match
        do {
            let isMatch = try await swipeService.likeUser(
                fromUserId: currentUserId,
                toUserId: userId,
                isSuperLike: isSuperLike
            )

            if isMatch {
                matchedUser = user
                showingMatchAnimation = true
                HapticManager.shared.match()
                Logger.shared.info("🎉 Match with \(user.fullName)", category: .general)

                // Track match
                try await AnalyticsManager.shared.trackMatch(user1Id: currentUserId, user2Id: userId)
            }
        } catch {
            Logger.shared.error("Error creating like: \(error)", category: .general)
        }

        withAnimation {
            currentIndex += 1
        }
    }

    func handlePass() async {
        guard let user = currentUser else { return }

        // Save to history for undo
        swipeHistory.append(SwipeAction(user: user, index: currentIndex, wasLike: false))
        showUndoButton = true

        // Haptic feedback
        HapticManager.shared.swipeLeft()

        guard let currentUserId = authService.currentUser?.id,
              let userId = user.id else {
            withAnimation {
                currentIndex += 1
            }
            return
        }

        // Track swipe analytics
        do {
            try await AnalyticsManager.shared.trackSwipe(
                swipedUserId: userId,
                swiperUserId: currentUserId,
                direction: AnalyticsSwipeDirection.left
            )
        } catch {
            Logger.shared.error("Error tracking swipe: \(error)", category: .analytics)
        }

        // Record the pass
        do {
            try await swipeService.passUser(fromUserId: currentUserId, toUserId: userId)
        } catch {
            Logger.shared.error("Error recording pass: \(error)", category: .general)
        }

        withAnimation {
            currentIndex += 1
        }
    }

    func handleSuperLike() async {
        guard currentUser != nil else { return }

        // Check if user is premium
        if authService.currentUser?.isPremium == true {
            await handleLike(isSuperLike: true)
        } else {
            // Show premium upgrade prompt
            // For now, just treat as regular like
            await handleLike(isSuperLike: false)
        }
    }

    func handleUndo() {
        guard !swipeHistory.isEmpty else { return }

        // Check if user has premium for unlimited undo, otherwise allow 1 free undo
        let isPremium = authService.currentUser?.isPremium ?? false
        let freeUndoCount = 1

        if isPremium || swipeHistory.count <= freeUndoCount {
            let lastAction = swipeHistory.removeLast()

            withAnimation(.spring(response: 0.3)) {
                currentIndex = lastAction.index
                showUndoButton = !swipeHistory.isEmpty
            }

            HapticManager.shared.impact(.medium)
        }
    }

    func dismissMatchAnimation() {
        showingMatchAnimation = false
    }
}
