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
    @Published var hasActiveFilters = false
    @Published var matchedUser: User?
    @Published var showingMatchAnimation = false
    @Published var selectedUser: User?
    @Published var showingUserDetail = false
    @Published var showingFilters = false
    @Published var dragOffset: CGSize = .zero
    @Published var isProcessingAction = false
    @Published var showingUpgradeSheet = false

    var remainingCount: Int {
        return max(0, users.count - currentIndex)
    }

    private let firestore = Firestore.firestore()
    private var lastDocument: DocumentSnapshot?
    private var interestTask: Task<Void, Never>?
    
    func loadUsers(currentUser: User, limit: Int = 20) {
        isLoading = true
        errorMessage = ""
        
        var query = firestore.collection("users")
            .whereField("age", isGreaterThanOrEqualTo: currentUser.ageRangeMin)
            .whereField("age", isLessThanOrEqualTo: currentUser.ageRangeMax)
            .limit(to: limit)
        
        // Filter by gender preference
        if currentUser.lookingFor != "Everyone" {
            query = query.whereField("gender", isEqualTo: currentUser.lookingFor)
        }
        
        // Start after last document for pagination
        if let lastDoc = lastDocument {
            query = query.start(afterDocument: lastDoc)
        }
        
        query.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }

            Task { @MainActor in
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.isLoading = false
                    return
                }

                self.lastDocument = documents.last

                let fetchedUsers = documents.compactMap { doc -> User? in
                    let data = doc.data()
                    var user = User(dictionary: data)
                    user.id = doc.documentID

                    // Don't show current user
                    if user.id == currentUser.id {
                        return nil
                    }

                    return user
                }

                self.users.append(contentsOf: fetchedUsers)
                self.isLoading = false
            }
        }
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

    /// Check if user has daily likes remaining
    private func checkDailyLikeLimit() async -> Bool {
        guard let userId = AuthService.shared.currentUser?.id else { return false }

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)

        do {
            let document = try await userRef.getDocument()
            guard let data = document.data() else { return false }

            let lastResetDate = (data["lastLikeResetDate"] as? Timestamp)?.dateValue() ?? Date()
            var likesRemaining = data["likesRemainingToday"] as? Int ?? 50

            // Check if we need to reset (new day)
            if !Calendar.current.isDate(lastResetDate, inSameDayAs: Date()) {
                // Reset to 50 likes
                try await userRef.updateData([
                    "likesRemainingToday": 50,
                    "lastLikeResetDate": Timestamp(date: Date())
                ])
                await AuthService.shared.fetchUser()
                return true
            }

            return likesRemaining > 0
        } catch {
            Logger.shared.error("Error checking daily like limit", category: .database, error: error)
            return true // Allow on error
        }
    }

    /// Decrement daily like count
    private func decrementDailyLikes() async {
        guard let userId = AuthService.shared.currentUser?.id else { return }

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)

        do {
            try await userRef.updateData([
                "likesRemainingToday": FieldValue.increment(Int64(-1))
            ])
            await AuthService.shared.fetchUser()
        } catch {
            Logger.shared.error("Error decrementing daily likes", category: .database, error: error)
        }
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

    /// Decrement super like count
    private func decrementSuperLikes() async {
        guard let userId = AuthService.shared.currentUser?.id else { return }

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)

        do {
            try await userRef.updateData([
                "superLikesRemaining": FieldValue.increment(Int64(-1))
            ])
            await AuthService.shared.fetchUser()
            Logger.shared.info("Super Like used. Remaining: \(AuthService.shared.currentUser?.superLikesRemaining ?? 0)", category: .matching)
        } catch {
            Logger.shared.error("Error decrementing super likes", category: .database, error: error)
        }
    }

    /// Apply filters
    func applyFilters() {
        currentIndex = 0

        guard let currentUser = AuthService.shared.currentUser else {
            Logger.shared.warning("Cannot apply filters: No current user", category: .matching)
            return
        }

        // Get current user location
        let currentLocation: (lat: Double, lon: Double)? = {
            if let lat = currentUser.latitude, let lon = currentUser.longitude {
                return (lat, lon)
            }
            return nil
        }()

        // Clear current users and reload with filters
        users.removeAll()
        lastDocument = nil

        // Reload users which will automatically apply filters through loadUsers(currentUser:)
        loadUsers(currentUser: currentUser)

        Logger.shared.info("Filters applied. Active filters: \(DiscoveryFilters.shared.hasActiveFilters)", category: .matching)
    }

    /// Reset filters to default
    func resetFilters() {
        hasActiveFilters = false
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
