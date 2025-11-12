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
        guard currentIndex < users.count else { return }
        let user = users[currentIndex]

        // Move to next card
        withAnimation {
            currentIndex += 1
            dragOffset = .zero
        }

        // TODO: Implement like logic (send interest, check for match, etc.)
    }

    /// Handle pass action
    func handlePass() async {
        guard currentIndex < users.count else { return }

        // Move to next card
        withAnimation {
            currentIndex += 1
            dragOffset = .zero
        }

        // TODO: Implement pass logic
    }

    /// Handle super like action
    func handleSuperLike() async {
        guard currentIndex < users.count else { return }
        let user = users[currentIndex]

        // Move to next card
        withAnimation {
            currentIndex += 1
            dragOffset = .zero
        }

        // TODO: Implement super like logic (send super like interest, check for match, etc.)
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
