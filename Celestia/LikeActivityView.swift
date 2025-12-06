//
//  LikeActivityView.swift
//  Celestia
//
//  Timeline of like activity (received and sent)
//

import SwiftUI
import FirebaseFirestore

struct LikeActivityView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = LikeActivityViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    loadingView
                } else if viewModel.todayActivity.isEmpty && viewModel.weekActivity.isEmpty {
                    emptyStateView
                } else {
                    activityList
                }
            }
            .navigationTitle("Like Activity")
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
                await viewModel.loadActivity()
            }
            .refreshable {
                await viewModel.loadActivity()
            }
        }
    }

    // MARK: - Activity List

    private var activityList: some View {
        List {
            if !viewModel.todayActivity.isEmpty {
                Section("Today") {
                    ForEach(viewModel.todayActivity) { activity in
                        ActivityRow(activity: activity, user: viewModel.users[activity.userId])
                    }
                }
            }

            if !viewModel.weekActivity.isEmpty {
                Section("This Week") {
                    ForEach(viewModel.weekActivity) { activity in
                        ActivityRow(activity: activity, user: viewModel.users[activity.userId])
                    }
                }
            }

            if !viewModel.olderActivity.isEmpty {
                Section("Older") {
                    ForEach(viewModel.olderActivity) { activity in
                        ActivityRow(activity: activity, user: viewModel.users[activity.userId])
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading activity...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))

            VStack(spacing: 8) {
                Text("No Activity Yet")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Your like activity will appear here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Activity Row

struct ActivityRow: View {
    let activity: LikeActivity
    let user: User?  // PERFORMANCE FIX: Receive user data from parent instead of fetching
    @State private var showUserDetail = false

    var body: some View {
        Button {
            if let user = user {
                // PERFORMANCE: Prefetch images for instant detail view
                ImageCache.shared.prefetchUserPhotosHighPriority(user: user)
                showUserDetail = true
                HapticManager.shared.impact(.light)
            }
        } label: {
            HStack(spacing: 12) {
                // Activity icon
                Image(systemName: activity.type.icon)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(activity.type.color)
                    .clipShape(Circle())

                // Activity details
                VStack(alignment: .leading, spacing: 4) {
                    if let user = user {
                        Text(user.fullName)
                            .font(.headline)

                        Text(activity.type.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text(activity.type.description)
                            .font(.headline)
                            .redacted(reason: .placeholder)
                    }

                    Text(activity.timestamp.timeAgo())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showUserDetail) {
            if let user = user {
                UserDetailView(user: user)
            }
        }
    }
}

// MARK: - Like Activity Model

struct LikeActivity: Identifiable {
    let id: String
    let userId: String
    let type: ActivityType
    let timestamp: Date

    enum ActivityType {
        case received(isSuperLike: Bool)
        case sent(isSuperLike: Bool)
        case mutual
        case matched

        var icon: String {
            switch self {
            case .received: return "heart.fill"
            case .sent: return "paperplane.fill"
            case .mutual: return "heart.circle.fill"
            case .matched: return "sparkles"
            }
        }

        var color: Color {
            switch self {
            case .received: return .pink
            case .sent: return .purple
            case .mutual: return .orange
            case .matched: return .green
            }
        }

        var description: String {
            switch self {
            case .received(let isSuperLike):
                return isSuperLike ? "Super liked you" : "Liked you"
            case .sent(let isSuperLike):
                return isSuperLike ? "You super liked" : "You liked"
            case .mutual:
                return "Mutual like!"
            case .matched:
                return "It's a match!"
            }
        }
    }
}

// MARK: - View Model

@MainActor
class LikeActivityViewModel: ObservableObject {
    @Published var todayActivity: [LikeActivity] = []
    @Published var weekActivity: [LikeActivity] = []
    @Published var olderActivity: [LikeActivity] = []
    @Published var isLoading = false
    @Published var users: [String: User] = [:]  // PERFORMANCE FIX: Cache users for batch fetching

    private let db = Firestore.firestore()

    func loadActivity() async {
        guard let currentUserId = AuthService.shared.currentUser?.effectiveId else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            var allActivity: [LikeActivity] = []

            // Get received likes (likes where current user is the target)
            let receivedSnapshot = try await db.collection("likes")
                .whereField("toUserId", isEqualTo: currentUserId)
                .order(by: "timestamp", descending: true)
                .limit(to: 50)
                .getDocuments()

            for doc in receivedSnapshot.documents {
                let data = doc.data()
                if let fromUserId = data["fromUserId"] as? String,
                   let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() {
                    let isSuperLike = data["isSuperLike"] as? Bool ?? false

                    allActivity.append(LikeActivity(
                        id: doc.documentID,
                        userId: fromUserId,
                        type: .received(isSuperLike: isSuperLike),
                        timestamp: timestamp
                    ))
                }
            }

            // Get sent likes (likes sent by current user)
            let sentSnapshot = try await db.collection("likes")
                .whereField("fromUserId", isEqualTo: currentUserId)
                .order(by: "timestamp", descending: true)
                .limit(to: 50)
                .getDocuments()

            for doc in sentSnapshot.documents {
                let data = doc.data()
                if let toUserId = data["toUserId"] as? String,
                   let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() {
                    let isSuperLike = data["isSuperLike"] as? Bool ?? false

                    allActivity.append(LikeActivity(
                        id: doc.documentID + "_sent",
                        userId: toUserId,
                        type: .sent(isSuperLike: isSuperLike),
                        timestamp: timestamp
                    ))
                }
            }

            // Get matches
            let matchesSnapshot = try await db.collection("matches")
                .whereField("user1Id", isEqualTo: currentUserId)
                .order(by: "timestamp", descending: true)
                .limit(to: 30)
                .getDocuments()

            for doc in matchesSnapshot.documents {
                let data = doc.data()
                if let user2Id = data["user2Id"] as? String,
                   let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() {
                    allActivity.append(LikeActivity(
                        id: doc.documentID + "_match",
                        userId: user2Id,
                        type: .matched,
                        timestamp: timestamp
                    ))
                }
            }

            // Sort by timestamp
            allActivity.sort { $0.timestamp > $1.timestamp }

            // Categorize by time
            let now = Date()
            let todayStart = Calendar.current.startOfDay(for: now)
            // CODE QUALITY FIX: Removed force unwrapping - handle date calculation failure safely
            guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) else {
                // If date calculation fails, treat all non-today activity as "week"
                todayActivity = allActivity.filter { $0.timestamp >= todayStart }
                weekActivity = allActivity.filter { $0.timestamp < todayStart }
                olderActivity = []
                return
            }

            todayActivity = allActivity.filter { $0.timestamp >= todayStart }
            weekActivity = allActivity.filter { $0.timestamp < todayStart && $0.timestamp >= weekAgo }
            olderActivity = allActivity.filter { $0.timestamp < weekAgo }

            // PERFORMANCE FIX: Batch fetch all users
            // Old approach: Each ActivityRow fetches its user individually = 130+ queries
            // New approach: Batch fetch all unique users = ~13 queries (10 users per batch)
            await fetchUsersForActivities(allActivity)

            Logger.shared.info("Loaded like activity - today: \(todayActivity.count), week: \(weekActivity.count)", category: .matching)
        } catch {
            Logger.shared.error("Error loading like activity", category: .matching, error: error)
        }
    }

    /// PERFORMANCE FIX: Batch fetch users for all activities
    private func fetchUsersForActivities(_ activities: [LikeActivity]) async {
        // Collect unique user IDs
        let userIds = Array(Set(activities.map { $0.userId }))

        guard !userIds.isEmpty else { return }

        // Clear existing users
        users = [:]

        // Firestore 'in' queries support up to 10 items, so batch by 10
        let chunkSize = 10
        for i in stride(from: 0, to: userIds.count, by: chunkSize) {
            let chunk = Array(userIds[i..<min(i + chunkSize, userIds.count)])

            do {
                let usersSnapshot = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()

                for userDoc in usersSnapshot.documents {
                    if let user = try? userDoc.data(as: User.self),
                       let userId = user.id {
                        users[userId] = user
                    }
                }
            } catch {
                Logger.shared.error("Error batch fetching users for activity", category: .matching, error: error)
            }
        }

        Logger.shared.info("Batch fetched \(users.count) users for \(activities.count) activities", category: .matching)
    }
}

#Preview {
    LikeActivityView()
        .environmentObject(AuthService.shared)
}
