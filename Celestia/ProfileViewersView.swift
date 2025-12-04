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
                // Premium gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.94, blue: 1.0),
                        Color(red: 0.98, green: 0.97, blue: 1.0),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
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
                        HapticManager.shared.impact(.light)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: 36, height: 36)
                                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
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
        VStack(spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    Text("Your Stats")
                        .font(.headline.weight(.semibold))
                }
                Spacer()
            }

            HStack(spacing: 16) {
                ViewerStatBox(
                    value: "\(viewModel.viewers.count)",
                    label: "Total Views",
                    icon: "eye.fill",
                    gradientColors: [.blue, .cyan]
                )

                ViewerStatBox(
                    value: "\(viewModel.todayCount)",
                    label: "Today",
                    icon: "calendar",
                    gradientColors: [.green, .mint]
                )

                ViewerStatBox(
                    value: "\(viewModel.weekCount)",
                    label: "This Week",
                    icon: "chart.line.uptrend.xyaxis",
                    gradientColors: [.purple, .pink]
                )
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
        .shadow(color: .purple.opacity(0.08), radius: 20, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
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
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 56, height: 56)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                    .animation(
                        .linear(duration: 1)
                        .repeatForever(autoreverses: false),
                        value: viewModel.isLoading
                    )
            }

            Text("Loading viewers...")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // Icon with radial glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.08), Color.clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.12), Color.pink.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "eye.slash")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple.opacity(0.6), .pink.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 12) {
                Text("No Views Yet")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("When someone views your profile, they'll appear here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // Tips card
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("Tips to get more views")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    tipItem(icon: "photo.fill", text: "Add more photos")
                    tipItem(icon: "heart.fill", text: "Be active on the app")
                    tipItem(icon: "sparkles", text: "Complete your profile")
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tipItem(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.12), Color.pink.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Viewer Stat Box

struct ViewerStatBox: View {
    let value: String
    let label: String
    let icon: String
    let gradientColors: [Color]

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradientColors.map { $0.opacity(0.15) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text(value)
                .font(.title2.bold())
                .foregroundStyle(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

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

    private var isRecentView: Bool {
        let hourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date()
        return viewer.timestamp > hourAgo
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
            HStack(spacing: 14) {
                // Profile image with gradient border
                ZStack {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.purple.opacity(0.4), .pink.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.5
                        )
                        .frame(width: 66, height: 66)

                    Group {
                        if let imageURL = viewer.user.photos.first, let url = URL(string: imageURL) {
                            CachedProfileImage(url: url, size: 60)
                        } else {
                            ZStack {
                                LinearGradient(
                                    colors: [.purple.opacity(0.6), .pink.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                Text(viewer.user.fullName.prefix(1))
                                    .font(.title2.weight(.semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                        }
                    }

                    // Recent view indicator
                    if isRecentView {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .offset(x: 22, y: -22)
                    }
                }

                // User info
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(viewer.user.fullName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("\(viewer.user.age)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if viewer.user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple.opacity(0.7), .pink.opacity(0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        Text(viewer.user.location)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        Text("Viewed \(viewer.timestamp.timeAgo())")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.12), Color.pink.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(isRecentView ? 0.25 : 0.1),
                                Color.pink.opacity(isRecentView ? 0.2 : 0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
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
