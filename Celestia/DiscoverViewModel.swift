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
                print("Error sending interest: \(error)")
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
        guard let currentUserId = AuthService.shared.currentUser?.id,
              let likedUserId = likedUser.id else {
            isProcessingAction = false
            return
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

            if isMatch {
                // Show match animation
                await MainActor.run {
                    self.matchedUser = likedUser
                    self.showingMatchAnimation = true
                    HapticManager.shared.notification(.success)
                }
                print("💕 It's a match with \(likedUser.fullName)!")
            } else {
                print("✅ Like sent to \(likedUser.fullName)")
            }
        } catch {
            print("❌ Error sending like: \(error.localizedDescription)")
            // Still move forward even if like fails
        }

        isProcessingAction = false
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
            print("✅ Pass recorded for \(passedUser.fullName)")
        } catch {
            print("❌ Error recording pass: \(error.localizedDescription)")
            // Still move forward even if pass fails
        }

        isProcessingAction = false
    }

    /// Handle super like action
    func handleSuperLike() async {
        guard currentIndex < users.count, !isProcessingAction else { return }
        isProcessingAction = true

        let superLikedUser = users[currentIndex]
        guard let currentUserId = AuthService.shared.currentUser?.id,
              let superLikedUserId = superLikedUser.id else {
            isProcessingAction = false
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

            if isMatch {
                // Show match animation
                await MainActor.run {
                    self.matchedUser = superLikedUser
                    self.showingMatchAnimation = true
                    HapticManager.shared.notification(.success)
                }
                print("💕 Super Like resulted in a match with \(superLikedUser.fullName)!")
            } else {
                print("⭐ Super Like sent to \(superLikedUser.fullName)")
            }

            // TODO: Deduct super like from user's balance when consumables are implemented
        } catch {
            print("❌ Error sending super like: \(error.localizedDescription)")
            // Still move forward even if super like fails
        }

        isProcessingAction = false
    }

    /// Apply filters
    func applyFilters() {
        // TODO: Implement filter logic
        currentIndex = 0
        users.removeAll()
        // Re-load users with filters
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
        // TODO: Get current user from AuthService and call loadUsers(currentUser:)
        // For now, just stub
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
