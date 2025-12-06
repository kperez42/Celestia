//
//  MutualLikesView.swift
//  Celestia
//
//  Shows people you both liked (mutual likes that haven't matched yet)
//

import SwiftUI
import FirebaseFirestore

struct MutualLikesView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = MutualLikesViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    loadingView
                } else if viewModel.mutualLikes.isEmpty {
                    emptyStateView
                } else {
                    mutualLikesGrid
                }
            }
            .navigationTitle("Mutual Likes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
            }
            .task {
                await viewModel.loadMutualLikes()
            }
            .refreshable {
                await viewModel.loadMutualLikes()
            }
        }
    }

    // MARK: - Mutual Likes Grid

    private var mutualLikesGrid: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header info
                headerCard

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(viewModel.mutualLikes) { user in
                        MutualLikeCard(user: user)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top)
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.pink, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("\(viewModel.mutualLikes.count) Mutual Likes")
                .font(.title2.bold())

            Text("You both liked each other!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white)
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading mutual likes...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "heart.slash.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))

            VStack(spacing: 8) {
                Text("No Mutual Likes Yet")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Keep swiping to find people who like you back!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Mutual Like Card

struct MutualLikeCard: View {
    let user: User
    @EnvironmentObject var authService: AuthService
    @State private var showUserDetail = false

    var body: some View {
        Button {
            showUserDetail = true
            HapticManager.shared.impact(.light)
        } label: {
            VStack(spacing: 0) {
                // Profile image
                if let imageURL = user.photos.first, let url = URL(string: imageURL) {
                    CachedCardImage(url: url)
                } else {
                    LinearGradient(
                        colors: [.purple.opacity(0.6), .pink.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }

                // User info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(user.fullName)
                            .font(.headline)
                        Text("\(user.age)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(user.location)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)

                    // Mutual indicator
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                        Text("You both liked!")
                            .font(.caption)
                    }
                    .foregroundColor(.pink)
                }
                .padding(12)
            }
            .frame(height: 250)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
        .sheet(isPresented: $showUserDetail) {
            UserDetailView(user: user)
                .environmentObject(authService)
        }
    }
}

// MARK: - View Model

@MainActor
class MutualLikesViewModel: ObservableObject {
    @Published var mutualLikes: [User] = []
    @Published var isLoading = false

    private let db = Firestore.firestore()

    func loadMutualLikes() async {
        guard let currentUserId = AuthService.shared.currentUser?.effectiveId else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // Get users current user liked (likes sent by current user)
            let myLikesSnapshot = try await db.collection("likes")
                .whereField("fromUserId", isEqualTo: currentUserId)
                .getDocuments()

            let myLikedUserIds = Set(myLikesSnapshot.documents.compactMap { $0.data()["toUserId"] as? String })

            // Get users who liked current user (likes received)
            let likersSnapshot = try await db.collection("likes")
                .whereField("toUserId", isEqualTo: currentUserId)
                .getDocuments()

            let likerIds = Set(likersSnapshot.documents.compactMap { $0.data()["fromUserId"] as? String })

            // Find mutual likes (intersection)
            let mutualLikeIds = myLikedUserIds.intersection(likerIds)

            // Check if they're already matched
            let matchesSnapshot = try await db.collection("matches")
                .whereField("user1Id", isEqualTo: currentUserId)
                .getDocuments()

            let matchedUserIds = Set(matchesSnapshot.documents.compactMap { $0.data()["user2Id"] as? String })

            // Filter out already matched users
            let unmatchedMutualLikes = mutualLikeIds.subtracting(matchedUserIds)

            // PERFORMANCE FIX: Batch fetch user details to prevent N+1 queries
            // Firestore 'in' query has a max of 10 items, so batch in groups of 10
            var users: [User] = []
            let userIdArray = Array(unmatchedMutualLikes)

            for i in stride(from: 0, to: userIdArray.count, by: 10) {
                let batchEnd = min(i + 10, userIdArray.count)
                let batchIds = Array(userIdArray[i..<batchEnd])

                guard !batchIds.isEmpty else { continue }

                let batchSnapshot = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: batchIds)
                    .getDocuments()

                let batchUsers = batchSnapshot.documents.compactMap { try? $0.data(as: User.self) }
                users.append(contentsOf: batchUsers)
            }

            mutualLikes = users
            Logger.shared.info("Loaded \(users.count) mutual likes using batch queries", category: .matching)
        } catch {
            Logger.shared.error("Error loading mutual likes", category: .matching, error: error)
        }
    }
}

#Preview {
    MutualLikesView()
        .environmentObject(AuthService.shared)
}
