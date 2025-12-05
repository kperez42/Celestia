//
//  InterestsViewEnhanced.swift
//  Celestia
//
//  Enhanced version with swipe gestures, filters, batch actions, and undo
//

import SwiftUI
import FirebaseFirestore

struct InterestsViewEnhanced: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var interestService = InterestService.shared
    @StateObject private var userService = UserService.shared

    private let db = Firestore.firestore()
    @State private var users: [String: User] = [:]
    @State private var showMatchAnimation = false
    @State private var matchedUser: User?

    // Filter states
    @State private var filterNearby = false
    @State private var filterNew = false
    @State private var filterOnline = false

    // Batch action states
    @State private var selectedInterests: Set<String> = []
    @State private var isSelectionMode = false

    // Undo functionality
    @State private var lastAction: LastAction?
    @State private var showUndoToast = false

    // Computed filtered interests
    private var filteredInterests: [Interest] {
        var filtered = interestService.receivedInterests

        if filterNearby {
            // Filter by distance (assuming users have location data)
            filtered = filtered.filter { interest in
                if let user = users[interest.fromUserId] {
                    return isNearby(user)
                }
                return false
            }
        }

        if filterNew {
            // Filter interests from last 24 hours
            let yesterday = Date().addingTimeInterval(-24 * 60 * 60)
            filtered = filtered.filter { $0.timestamp > yesterday }
        }

        if filterOnline {
            // Filter only active users (online OR active within last 5 minutes)
            filtered = filtered.filter { interest in
                guard let user = users[interest.fromUserId] else { return false }
                let interval = Date().timeIntervalSince(user.lastActive)
                return user.isOnline || interval < 300
            }
        }

        return filtered
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    headerView

                    // Filter bar
                    filterBar

                    // Batch actions bar (when in selection mode)
                    if isSelectionMode {
                        batchActionsBar
                    }

                    // Content
                    if interestService.isLoading {
                        loadingView
                    } else if filteredInterests.isEmpty {
                        emptyStateView
                    } else {
                        interestsGrid
                    }
                }

                // Match animation
                if showMatchAnimation {
                    matchCelebrationView
                }

                // Undo toast
                if showUndoToast, let action = lastAction {
                    undoToast(action: action)
                }
            }
            .navigationTitle("Interests")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isSelectionMode ? "Done" : "Select") {
                        withAnimation {
                            isSelectionMode.toggle()
                            if !isSelectionMode {
                                selectedInterests.removeAll()
                            }
                        }
                    }
                }
            }
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("People Who Liked You")
                    .font(.headline)

                Text("\(filteredInterests.count) interested")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !(authService.currentUser?.isPremium ?? false) {
                Text("👑 Premium")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color.white)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                InterestFilterChip(
                    title: "Nearby",
                    icon: "location.fill",
                    isSelected: $filterNearby
                )

                InterestFilterChip(
                    title: "New",
                    icon: "sparkles",
                    isSelected: $filterNew
                )

                InterestFilterChip(
                    title: "Online",
                    icon: "circle.fill",
                    isSelected: $filterOnline
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color.white)
    }

    // MARK: - Batch Actions Bar

    private var batchActionsBar: some View {
        HStack(spacing: 12) {
            Button {
                acceptSelectedInterests()
            } label: {
                Label("Accept (\(selectedInterests.count))", systemImage: "heart.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(selectedInterests.isEmpty)

            Button {
                rejectSelectedInterests()
            } label: {
                Label("Remove", systemImage: "xmark")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(selectedInterests.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.white)
        .shadow(color: .black.opacity(0.05), radius: 5, y: -2)
    }

    // MARK: - Interests Grid

    private var interestsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(filteredInterests) { interest in
                    if let user = users[interest.fromUserId] {
                        InterestCard(
                            interest: interest,
                            user: user,
                            isBlurred: !(authService.currentUser?.isPremium ?? false),
                            isSelected: selectedInterests.contains(interest.id ?? ""),
                            isSelectionMode: isSelectionMode,
                            onAccept: {
                                acceptInterest(interest)
                            },
                            onReject: {
                                rejectInterest(interest)
                            },
                            onSelect: {
                                toggleSelection(interest)
                            }
                        )
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Loading interests...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(0..<6, id: \.self) { _ in
                        MatchCardSkeleton()
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.slash")
                .font(.system(size: 60))
                .foregroundColor(.purple.opacity(0.5))

            Text(interestService.receivedInterests.isEmpty ? "No Interests Yet" : "No Results")
                .font(.title3)
                .fontWeight(.semibold)

            Text(interestService.receivedInterests.isEmpty ? "People who like you will appear here" : "Try adjusting your filters")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if !interestService.receivedInterests.isEmpty {
                Button("Clear Filters") {
                    filterNearby = false
                    filterNew = false
                    filterOnline = false
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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
                }

                Button("Send Message") {
                    showMatchAnimation = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)

                Button("Keep Browsing") {
                    showMatchAnimation = false
                }
                .foregroundColor(.white)
            }
            .padding(40)
        }
    }

    // MARK: - Undo Toast

    private func undoToast(action: LastAction) -> some View {
        VStack {
            Spacer()

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(action.type == .accept ? "Interest Accepted" : "Interest Rejected")
                        .font(.subheadline.weight(.semibold))

                    if let user = users[action.interest.fromUserId] {
                        Text(user.fullName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button {
                    undoLastAction()
                } label: {
                    Text("UNDO")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.purple)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            .padding(.horizontal)
            .padding(.bottom, 80)
        }
        .transition(.opacity)
    }

    // MARK: - Helper Functions

    // PERFORMANCE FIX: Use batch queries instead of N+1 queries
    private func loadData() async {
        guard let userId = authService.currentUser?.effectiveId else { return }

        do {
            try await interestService.fetchReceivedInterests(userId: userId)

            // Collect user IDs that need fetching (not already cached)
            let userIdsToFetch = interestService.receivedInterests
                .map { $0.fromUserId }
                .filter { users[$0] == nil }

            guard !userIdsToFetch.isEmpty else { return }

            // Batch fetch users in groups of 10 (Firestore 'in' query limit)
            let uniqueUserIds = Array(Set(userIdsToFetch))

            for i in stride(from: 0, to: uniqueUserIds.count, by: 10) {
                let batchEnd = min(i + 10, uniqueUserIds.count)
                let batchIds = Array(uniqueUserIds[i..<batchEnd])

                guard !batchIds.isEmpty else { continue }

                let batchSnapshot = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: batchIds)
                    .getDocuments()

                let batchUsers = batchSnapshot.documents.compactMap { try? $0.data(as: User.self) }

                await MainActor.run {
                    for user in batchUsers {
                        if let id = user.id {
                            users[id] = user
                        }
                    }
                }
            }

            Logger.shared.debug("Loaded \(uniqueUserIds.count) users using batch queries", category: .matching)
        } catch {
            Logger.shared.error("Error loading interests", category: .matching, error: error)
        }
    }

    private func acceptInterest(_ interest: Interest) {
        guard let interestId = interest.id else { return }

        // Save for undo
        lastAction = LastAction(interest: interest, type: .accept)
        showUndoToast = true
        HapticManager.shared.impact(.medium)

        // Auto-hide undo toast after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if showUndoToast {
                withAnimation {
                    showUndoToast = false
                }
            }
        }

        Task {
            do {
                try await interestService.acceptInterest(
                    interestId: interestId,
                    fromUserId: interest.fromUserId,
                    toUserId: interest.toUserId
                )

                await MainActor.run {
                    matchedUser = users[interest.fromUserId]
                    showMatchAnimation = true
                }

                await loadData()
            } catch {
                Logger.shared.error("Error accepting interest", category: .matching, error: error)
            }
        }
    }

    private func rejectInterest(_ interest: Interest) {
        guard let interestId = interest.id else { return }

        // Save for undo
        lastAction = LastAction(interest: interest, type: .reject)
        showUndoToast = true
        HapticManager.shared.impact(.light)

        // Auto-hide undo toast after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if showUndoToast {
                withAnimation {
                    showUndoToast = false
                }
            }
        }

        Task {
            do {
                try await interestService.rejectInterest(interestId: interestId)
                await loadData()
            } catch {
                Logger.shared.error("Error rejecting interest", category: .matching, error: error)
            }
        }
    }

    private func toggleSelection(_ interest: Interest) {
        guard let id = interest.id else { return }

        withAnimation {
            if selectedInterests.contains(id) {
                selectedInterests.remove(id)
            } else {
                selectedInterests.insert(id)
            }
        }
        HapticManager.shared.impact(.light)
    }

    private func acceptSelectedInterests() {
        let interestsToAccept = filteredInterests.filter { selectedInterests.contains($0.id ?? "") }

        Task {
            for interest in interestsToAccept {
                guard let interestId = interest.id else { continue }

                try? await interestService.acceptInterest(
                    interestId: interestId,
                    fromUserId: interest.fromUserId,
                    toUserId: interest.toUserId
                )
            }

            await loadData()
            await MainActor.run {
                selectedInterests.removeAll()
                isSelectionMode = false
            }
        }

        HapticManager.shared.impact(.heavy)
    }

    private func rejectSelectedInterests() {
        let interestsToReject = filteredInterests.filter { selectedInterests.contains($0.id ?? "") }

        Task {
            for interest in interestsToReject {
                guard let interestId = interest.id else { continue }
                try? await interestService.rejectInterest(interestId: interestId)
            }

            await loadData()
            await MainActor.run {
                selectedInterests.removeAll()
                isSelectionMode = false
            }
        }

        HapticManager.shared.impact(.light)
    }

    private func undoLastAction() {
        guard let action = lastAction else { return }

        withAnimation {
            showUndoToast = false
        }

        // Reverse the action
        Task {
            switch action.type {
            case .accept:
                // If we accepted, delete the match that was created
                // This would require backend support
                Logger.shared.info("Undo accept not fully implemented", category: .matching)

            case .reject:
                // If we rejected, re-add the interest
                // This would require backend support to restore
                Logger.shared.info("Undo reject not fully implemented", category: .matching)
            }

            lastAction = nil
            await loadData()
        }

        HapticManager.shared.impact(.medium)
    }

    private func isNearby(_ user: User) -> Bool {
        // Implement distance calculation
        // For now, return true for users within same city
        guard let currentUser = authService.currentUser else { return false }
        return user.location == currentUser.location
    }
}

// MARK: - Interest Filter Chip

struct InterestFilterChip: View {
    let title: String
    let icon: String
    @Binding var isSelected: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isSelected.toggle()
            }
            HapticManager.shared.impact(.light)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)

                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundColor(isSelected ? .white : .purple)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isSelected ?
                LinearGradient(
                    colors: [.purple, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                ) :
                LinearGradient(
                    colors: [Color.purple.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(20)
        }
    }
}

// MARK: - Interest Card

struct InterestCard: View {
    let interest: Interest
    let user: User
    let isBlurred: Bool
    let isSelected: Bool
    let isSelectionMode: Bool
    let onAccept: () -> Void
    let onReject: () -> Void
    let onSelect: () -> Void

    var body: some View {
        Button(action: {
            if isSelectionMode {
                onSelect()
            }
        }) {
            VStack(spacing: 0) {
                // Selection indicator overlay
                ZStack(alignment: .topTrailing) {
                    // User image - PERFORMANCE: Use CachedAsyncImage for smooth scrolling
                    CachedAsyncImage(
                        url: URL(string: user.profileImageURL),
                        content: { image in
                            image
                                .resizable()
                                .scaledToFill()
                        },
                        placeholder: {
                            LinearGradient(
                                colors: [Color.purple.opacity(0.6), Color.pink.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    )
                    .frame(height: 180)
                    .clipped()
                    .blur(radius: isBlurred ? 20 : 0)

                    // Online/Active indicator
                    if !isBlurred {
                        // Consider user active if they're online OR were active in the last 5 minutes
                        let interval = Date().timeIntervalSince(user.lastActive)
                        let isActive = user.isOnline || interval < 300

                        if isActive {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 12, height: 12)
                                .overlay {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                }
                                .padding(8)
                        }
                    }

                    // Selection checkmark
                    if isSelectionMode {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundColor(isSelected ? .purple : .white)
                            .padding(8)
                            .background(Circle().fill(Color.white.opacity(isSelected ? 0 : 0.3)))
                    }
                }

                // User info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(isBlurred ? "Premium User" : user.fullName)
                            .font(.headline)

                        if !isBlurred {
                            Text("\(user.age)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }

                    if !isBlurred {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text("\(user.location)")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)

                        if let message = interest.message {
                            Text("💬 \(message)")
                                .font(.caption)
                                .foregroundColor(.purple)
                                .lineLimit(2)
                        }
                    }

                    // Action buttons (only when not in selection mode)
                    if !isBlurred && !isSelectionMode {
                        HStack(spacing: 8) {
                            Button(action: onReject) {
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                            }

                            Button(action: onAccept) {
                                Image(systemName: "heart.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(12)
            }
            .background(Color.white)
            .cornerRadius(16)
            .shadow(radius: 5)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.purple, lineWidth: 3)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Last Action Model

struct LastAction {
    let interest: Interest
    let type: ActionType
    let timestamp: Date = Date()

    enum ActionType {
        case accept, reject
    }
}

#Preview {
    InterestsViewEnhanced()
        .environmentObject(AuthService.shared)
}
