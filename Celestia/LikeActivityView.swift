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
                        ActivityRow(activity: activity)
                    }
                }
            }

            if !viewModel.weekActivity.isEmpty {
                Section("This Week") {
                    ForEach(viewModel.weekActivity) { activity in
                        ActivityRow(activity: activity)
                    }
                }
            }

            if !viewModel.olderActivity.isEmpty {
                Section("Older") {
                    ForEach(viewModel.olderActivity) { activity in
                        ActivityRow(activity: activity)
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
    @State private var user: User?
    @State private var showUserDetail = false

    var body: some View {
        Button {
            if user != nil {
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
        .task {
            await loadUser()
        }
        .sheet(isPresented: $showUserDetail) {
            if let user = user {
                UserDetailView(user: user)
            }
        }
    }

    private func loadUser() async {
        do {
            let userDoc = try await Firestore.firestore()
                .collection("users")
                .document(activity.userId)
                .getDocument()

            if let fetchedUser = try? userDoc.data(as: User.self) {
                await MainActor.run {
                    user = fetchedUser
                }
            }
        } catch {
            Logger.shared.error("Error loading user for activity", category: .matching, error: error)
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

    private let db = Firestore.firestore()

    func loadActivity() async {
        guard let currentUserId = AuthService.shared.currentUser?.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            var allActivity: [LikeActivity] = []

            // Get received likes
            let receivedSnapshot = try await db.collection("likes")
                .whereField("targetUserId", isEqualTo: currentUserId)
                .order(by: "timestamp", descending: true)
                .limit(to: 50)
                .getDocuments()

            for doc in receivedSnapshot.documents {
                let data = doc.data()
                if let userId = data["userId"] as? String,
                   let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() {
                    let isSuperLike = data["isSuperLike"] as? Bool ?? false

                    allActivity.append(LikeActivity(
                        id: doc.documentID,
                        userId: userId,
                        type: .received(isSuperLike: isSuperLike),
                        timestamp: timestamp
                    ))
                }
            }

            // Get sent likes
            let sentSnapshot = try await db.collection("likes")
                .whereField("userId", isEqualTo: currentUserId)
                .order(by: "timestamp", descending: true)
                .limit(to: 50)
                .getDocuments()

            for doc in sentSnapshot.documents {
                let data = doc.data()
                if let targetUserId = data["targetUserId"] as? String,
                   let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() {
                    let isSuperLike = data["isSuperLike"] as? Bool ?? false

                    allActivity.append(LikeActivity(
                        id: doc.documentID + "_sent",
                        userId: targetUserId,
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

            Logger.shared.info("Loaded like activity - today: \(todayActivity.count), week: \(weekActivity.count)", category: .matching)
        } catch {
            Logger.shared.error("Error loading like activity", category: .matching, error: error)
        }
    }
}

#Preview {
    LikeActivityView()
        .environmentObject(AuthService.shared)
}
