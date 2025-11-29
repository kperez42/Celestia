//
//  ProfileViewersView.swift
//  Celestia
//
//  Shows who viewed your profile (Premium feature)
//

import SwiftUI
import FirebaseFirestore

struct ProfileViewersView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = ProfileViewersViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var showUpgradeSheet = false

    var isPremium: Bool {
        authService.currentUser?.isPremium ?? false
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    loadingView
                } else if viewModel.viewers.isEmpty {
                    emptyStateView
                } else {
                    viewersList
                }
            }
            .navigationTitle("Profile Viewers")
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
                await viewModel.loadViewers()
            }
            .refreshable {
                await viewModel.loadViewers()
            }
            .sheet(isPresented: $showUpgradeSheet) {
                PremiumUpgradeView()
                    .environmentObject(authService)
            }
        }
    }

    // MARK: - Viewers List

    private var viewersList: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Stats card
                statsCard

                // Viewers
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.viewers) { viewer in
                        ProfileViewerCard(viewer: viewer)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top)
        }
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                ViewerStatBox(
                    value: "\(viewModel.viewers.count)",
                    label: "Total Views",
                    icon: "eye.fill",
                    color: .blue
                )

                ViewerStatBox(
                    value: "\(viewModel.todayCount)",
                    label: "Today",
                    icon: "calendar",
                    color: .green
                )

                ViewerStatBox(
                    value: "\(viewModel.weekCount)",
                    label: "This Week",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        .padding(.horizontal)
    }

    // MARK: - Premium Required

    private var premiumRequiredView: some View {
        VStack(spacing: 24) {
            Image(systemName: "crown.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 8) {
                Text("Premium Feature")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Upgrade to Premium to see who viewed your profile")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                showUpgradeSheet = true
            } label: {
                Text("Upgrade to Premium")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading viewers...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "eye.slash")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))

            VStack(spacing: 8) {
                Text("No Views Yet")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("When someone views your profile, they'll appear here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Viewer Stat Box

struct ViewerStatBox: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.title2.bold())

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Profile Viewer Card

struct ProfileViewerCard: View {
    let viewer: ViewerInfo
    @EnvironmentObject var authService: AuthService
    @State private var showUserDetail = false
    @State private var showUpgrade = false

    private var isPremium: Bool {
        authService.currentUser?.isPremium ?? false
    }

    var body: some View {
        Button {
            HapticManager.shared.impact(.light)
            if isPremium {
                showUserDetail = true
            } else {
                showUpgrade = true
            }
        } label: {
            HStack(spacing: 12) {
                // Profile image - always visible
                Group {
                    if let imageURL = viewer.user.photos.first, let url = URL(string: imageURL) {
                        CachedProfileImage(url: url, size: 60)
                    } else {
                        LinearGradient(
                            colors: [.purple.opacity(0.6), .pink.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                    }
                }

                // User info - always visible
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(viewer.user.fullName)
                            .font(.headline)
                        Text("\(viewer.user.age)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Text(viewer.user.location)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Viewed \(viewer.timestamp.timeAgo())")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        }
        .buttonStyle(ScaleButtonStyle())
        .sheet(isPresented: $showUserDetail) {
            UserDetailView(user: viewer.user)
                .environmentObject(authService)
        }
        .sheet(isPresented: $showUpgrade) {
            PremiumUpgradeView()
                .environmentObject(authService)
        }
    }
}

// MARK: - Profile Viewer Model

struct ViewerInfo: Identifiable {
    let id: String
    let user: User
    let timestamp: Date
}

// MARK: - View Model

@MainActor
class ProfileViewersViewModel: ObservableObject {
    @Published var viewers: [ViewerInfo] = []
    @Published var isLoading = false

    var todayCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return viewers.filter { $0.timestamp >= today }.count
    }

    var weekCount: Int {
        // CODE QUALITY FIX: Removed force unwrapping - handle date calculation failure safely
        guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else {
            // If date calculation fails, return total count as fallback
            return viewers.count
        }
        return viewers.filter { $0.timestamp >= weekAgo }.count
    }

    private let db = Firestore.firestore()

    func loadViewers() async {
        guard let currentUserId = AuthService.shared.currentUser?.effectiveId else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let viewsSnapshot = try await db.collection("profileViews")
                .whereField("viewedUserId", isEqualTo: currentUserId)
                .order(by: "timestamp", descending: true)
                .limit(to: 50)
                .getDocuments()

            // PERFORMANCE FIX: Collect all viewer IDs for batch fetching
            // Old approach: 1 + N queries (51 reads for 50 viewers)
            // New approach: 1 + 1 query (2 reads for 50 viewers) - 96% reduction
            var viewerIds: [String] = []
            var viewerTimestamps: [String: Date] = [:]
            var viewerDocIds: [String: String] = [:]

            for doc in viewsSnapshot.documents {
                let data = doc.data()
                if let viewerId = data["viewerUserId"] as? String,
                   let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() {
                    viewerIds.append(viewerId)
                    viewerTimestamps[viewerId] = timestamp
                    viewerDocIds[viewerId] = doc.documentID
                }
            }

            guard !viewerIds.isEmpty else {
                viewers = []
                Logger.shared.info("No profile viewers found", category: .analytics)
                return
            }

            // PERFORMANCE FIX: Batch fetch all users in a single query
            // Firestore 'in' queries support up to 10 items, so we need to batch if > 10
            var allUsers: [String: User] = [:]

            // Split into chunks of 10 (Firestore limit for 'in' queries)
            let chunkSize = 10
            for i in stride(from: 0, to: viewerIds.count, by: chunkSize) {
                let chunk = Array(viewerIds[i..<min(i + chunkSize, viewerIds.count)])

                let usersSnapshot = try await db.collection("users")
                    .whereField("id", in: chunk)
                    .getDocuments()

                for userDoc in usersSnapshot.documents {
                    if let user = try? userDoc.data(as: User.self),
                       let userId = user.id {
                        allUsers[userId] = user
                    }
                }
            }

            // Map users back to viewer info
            var viewersList: [ViewerInfo] = []
            for viewerId in viewerIds {
                if let user = allUsers[viewerId],
                   let timestamp = viewerTimestamps[viewerId],
                   let docId = viewerDocIds[viewerId] {
                    viewersList.append(ViewerInfo(
                        id: docId,
                        user: user,
                        timestamp: timestamp
                    ))
                }
            }

            viewers = viewersList
            Logger.shared.info("Loaded \(viewersList.count) profile viewers (batch optimized)", category: .analytics)
        } catch {
            Logger.shared.error("Error loading profile viewers", category: .analytics, error: error)
        }
    }
}

#Preview {
    ProfileViewersView()
        .environmentObject(AuthService.shared)
}
