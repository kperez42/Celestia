//
//  SavedProfilesView.swift
//  Celestia
//
//  Shows bookmarked/saved profiles for later viewing
//

import SwiftUI
import FirebaseFirestore

struct SavedProfilesView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var viewModel = SavedProfilesViewModel.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedUser: User?
    @State private var showUserDetail = false
    @State private var showClearAllConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Enhanced background gradient
                LinearGradient(
                    colors: [
                        Color(.systemGroupedBackground),
                        Color.purple.opacity(0.03)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if viewModel.isLoading {
                    loadingView
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else if !viewModel.errorMessage.isEmpty {
                    errorStateView
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else if viewModel.savedProfiles.isEmpty {
                    emptyStateView
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    profilesGrid
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.isLoading)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.savedProfiles.isEmpty)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.errorMessage.isEmpty)
            .navigationTitle("Saved Profiles")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        HapticManager.shared.impact(.light)
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }

                if !viewModel.savedProfiles.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                showClearAllConfirmation = true
                            } label: {
                                Label("Clear All", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.title3)
                                .foregroundColor(.purple)
                        }
                    }
                }
            }
            .task {
                await viewModel.loadSavedProfiles()
                // Success haptic when profiles load
                if !viewModel.savedProfiles.isEmpty {
                    HapticManager.shared.notification(.success)
                }
            }
            .refreshable {
                HapticManager.shared.impact(.light)
                await viewModel.loadSavedProfiles(forceRefresh: true)
                HapticManager.shared.notification(.success)
            }
            .sheet(item: $selectedUser) { user in
                UserDetailView(user: user)
                    .environmentObject(authService)
            }
            .confirmationDialog(
                "Clear All Saved Profiles?",
                isPresented: $showClearAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All (\(viewModel.savedProfiles.count))", role: .destructive) {
                    HapticManager.shared.notification(.warning)
                    viewModel.clearAllSaved()
                }
                Button("Cancel", role: .cancel) {
                    HapticManager.shared.impact(.light)
                }
            } message: {
                Text("This will permanently remove all \(viewModel.savedProfiles.count) saved profiles. This action cannot be undone.")
            }
        }
    }

    // MARK: - Profiles Grid

    private var profilesGrid: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Stats header with animation
                statsHeader
                    .transition(.move(edge: .top).combined(with: .opacity))

                // Saved profiles grid with staggered animation
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(Array(viewModel.savedProfiles.enumerated()), id: \.element.id) { index, saved in
                        SavedProfileCard(
                            savedProfile: saved,
                            isUnsaving: viewModel.unsavingProfileId == saved.id,
                            onTap: {
                                selectedUser = saved.user
                                HapticManager.shared.impact(.light)
                            },
                            onUnsave: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    viewModel.unsaveProfile(saved)
                                }
                                HapticManager.shared.impact(.medium)
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.7)
                            .delay(Double(index) * 0.05),
                            value: viewModel.savedProfiles.count
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        HStack(spacing: 20) {
            // Total saved count
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "bookmark.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("\(viewModel.savedProfiles.count)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .contentTransition(.numericText())
                }

                Text("Saved Profiles")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // This week count
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 6) {
                    Text("\(viewModel.savedThisWeek)")
                        .font(.title2.bold())
                        .foregroundColor(.blue)
                        .contentTransition(.numericText())

                    Image(systemName: "calendar")
                        .font(.title3)
                        .foregroundColor(.blue)
                }

                Text("This Week")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .purple.opacity(0.1), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [.purple.opacity(0.1), .pink.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .padding(.horizontal)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Stats header skeleton
                HStack(spacing: 20) {
                    SkeletonView()
                        .frame(height: 80)
                        .cornerRadius(12)

                    SkeletonView()
                        .frame(height: 80)
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                // Skeleton grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(0..<6, id: \.self) { _ in
                        SavedProfileCardSkeleton()
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top)
        }
    }

    // MARK: - Error State

    private var errorStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.red.opacity(0.6), .orange.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 12) {
                Text("Oops! Something Went Wrong")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(viewModel.errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                Task {
                    await viewModel.loadSavedProfiles()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.body.weight(.semibold))
                    Text("Try Again")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundColor(.white)
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))

            VStack(spacing: 8) {
                Text("No Saved Profiles")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Profiles you bookmark will appear here for easy access later")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Text("💡 Tip: Tap the bookmark icon on any profile to save it")
                .font(.caption)
                .foregroundColor(.purple)
                .padding(.horizontal, 40)
                .multilineTextAlignment(.center)

            // CTA button to go back to discovering
            Button {
                dismiss()
                HapticManager.shared.impact(.light)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.body.weight(.semibold))
                    Text("Start Discovering")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundColor(.white)
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Saved Profile Card

struct SavedProfileCard: View {
    let savedProfile: SavedProfile
    let isUnsaving: Bool
    let onTap: () -> Void
    let onUnsave: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    // Profile image with smooth loading
                    Group {
                        if let imageURL = savedProfile.user.photos.first, let url = URL(string: imageURL) {
                            CachedCardImage(url: url)
                        } else {
                            LinearGradient(
                                colors: [.purple.opacity(0.6), .pink.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                    .frame(height: 200)
                    .clipped()
                    .overlay {
                        if isUnsaving {
                            ZStack {
                                Color.black.opacity(0.6)

                                VStack(spacing: 12) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.3)

                                    Text("Removing...")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                }
                            }
                            .transition(.opacity)
                        }
                    }

                    // User info with enhanced styling
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text(savedProfile.user.fullName)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Text("\(savedProfile.user.age)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            if savedProfile.user.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.purple)

                            Text(savedProfile.user.location)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)

                            Text("Saved \(savedProfile.savedAt.timeAgo())")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .fontWeight(.medium)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .opacity(isUnsaving ? 0.5 : 1.0)
                }

                // Enhanced unsave button with animation
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    onUnsave()
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                            .shadow(color: .purple.opacity(0.4), radius: 8, y: 4)

                        if isUnsaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "bookmark.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isUnsaving)
                .scaleEffect(isPressed ? 0.85 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
                .padding(10)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.08), radius: 15, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [.purple.opacity(0.1), .pink.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .disabled(isUnsaving)
    }
}

// MARK: - Saved Profile Card Skeleton

struct SavedProfileCardSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            // Image area skeleton
            SkeletonView()
                .frame(height: 200)
                .clipped()

            // User info skeleton
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    SkeletonView()
                        .frame(width: 90, height: 18)
                        .cornerRadius(6)

                    SkeletonView()
                        .frame(width: 30, height: 18)
                        .cornerRadius(6)

                    Spacer()
                }

                SkeletonView()
                    .frame(width: 110, height: 14)
                    .cornerRadius(6)

                SkeletonView()
                    .frame(width: 100, height: 14)
                    .cornerRadius(6)
            }
            .padding(12)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
    }
}

// MARK: - Saved Profile Model

struct SavedProfile: Identifiable, Equatable {
    let id: String
    let user: User
    let savedAt: Date
    let note: String?
}

// MARK: - View Model

@MainActor
class SavedProfilesViewModel: ObservableObject {
    // Singleton instance for shared state across views
    static let shared = SavedProfilesViewModel()

    @Published var savedProfiles: [SavedProfile] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var unsavingProfileId: String?

    var savedThisWeek: Int {
        // CODE QUALITY FIX: Removed force unwrapping - handle date calculation failure safely
        guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else {
            // If date calculation fails, return total count as fallback
            return savedProfiles.count
        }
        return savedProfiles.filter { $0.savedAt >= weekAgo }.count
    }

    private let db = Firestore.firestore()

    // PERFORMANCE: Cache management to reduce database reads
    private var lastFetchTime: Date?
    private let cacheDuration: TimeInterval = 300 // 5 minutes
    private var cachedForUserId: String?

    // Private initializer for singleton pattern
    private init() {}

    func loadSavedProfiles(forceRefresh: Bool = false) async {
        guard let currentUserId = AuthService.shared.currentUser?.id else { return }

        // PERFORMANCE FIX: Check cache first (5-minute TTL)
        // Prevents 6+ database reads every time view appears
        if !forceRefresh,
           let lastFetch = lastFetchTime,
           cachedForUserId == currentUserId,
           !savedProfiles.isEmpty,
           Date().timeIntervalSince(lastFetch) < cacheDuration {
            Logger.shared.debug("SavedProfiles cache HIT - using cached data", category: .performance)
            let cacheAge = Date().timeIntervalSince(lastFetch)
            AnalyticsManager.shared.logEvent(.performance, parameters: [
                "type": "saved_profiles_cache_hit",
                "cache_age_seconds": cacheAge,
                "profiles_count": savedProfiles.count
            ])
            return // Use cached data
        }

        Logger.shared.debug("SavedProfiles cache MISS - fetching from database", category: .performance)

        isLoading = true
        errorMessage = ""
        defer { isLoading = false }

        do {
            // Step 1: Fetch all saved profile references
            let savedSnapshot = try await db.collection("saved_profiles")
                .whereField("userId", isEqualTo: currentUserId)
                .order(by: "savedAt", descending: true)
                .getDocuments()

            // Step 2: Extract user IDs and metadata
            var savedMetadata: [(id: String, userId: String, savedAt: Date, note: String?)] = []
            for doc in savedSnapshot.documents {
                let data = doc.data()
                if let savedUserId = data["savedUserId"] as? String,
                   let savedAt = (data["savedAt"] as? Timestamp)?.dateValue() {
                    savedMetadata.append((
                        id: doc.documentID,
                        userId: savedUserId,
                        savedAt: savedAt,
                        note: data["note"] as? String
                    ))
                }
            }

            guard !savedMetadata.isEmpty else {
                savedProfiles = []
                Logger.shared.info("No saved profiles found", category: .general)
                return
            }

            // Step 3: Batch fetch users (Firestore whereIn limit is 10, so chunk requests)
            let userIds = savedMetadata.map { $0.userId }
            var fetchedUsers: [String: User] = [:]

            // Chunk user IDs into groups of 10 (Firestore whereIn limit)
            let chunkedUserIds = userIds.chunked(into: 10)

            for chunk in chunkedUserIds {
                let usersSnapshot = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()

                for doc in usersSnapshot.documents {
                    if let user = try? doc.data(as: User.self), let userId = user.id {
                        fetchedUsers[userId] = user
                    }
                }
            }

            // Step 4: Combine metadata with fetched users
            var profiles: [SavedProfile] = []
            var skippedCount = 0

            for metadata in savedMetadata {
                if let user = fetchedUsers[metadata.userId] {
                    profiles.append(SavedProfile(
                        id: metadata.id,
                        user: user,
                        savedAt: metadata.savedAt,
                        note: metadata.note
                    ))
                } else {
                    // User no longer exists or failed to fetch
                    skippedCount += 1
                    Logger.shared.warning("Skipped saved profile - user not found: \(metadata.userId)", category: .general)
                }
            }

            savedProfiles = profiles

            // PERFORMANCE: Update cache timestamp after successful fetch
            lastFetchTime = Date()
            cachedForUserId = currentUserId

            if skippedCount > 0 {
                Logger.shared.warning("Loaded \(profiles.count) saved profiles (\(skippedCount) skipped) - cached for 5 min", category: .general)
            } else {
                Logger.shared.info("Loaded \(profiles.count) saved profiles - cached for 5 min", category: .general)
            }
        } catch {
            errorMessage = error.localizedDescription
            Logger.shared.error("Error loading saved profiles", category: .general, error: error)
        }
    }

    /// Clear cache and force reload
    func clearCache() {
        lastFetchTime = nil
        cachedForUserId = nil
        Logger.shared.info("SavedProfiles cache cleared", category: .performance)
    }

    func unsaveProfile(_ profile: SavedProfile) {
        guard let currentUserId = AuthService.shared.currentUser?.id else { return }

        // Set loading state
        unsavingProfileId = profile.id

        Task {
            do {
                // Remove from Firestore
                try await db.collection("saved_profiles").document(profile.id).delete()

                // Update local state
                await MainActor.run {
                    savedProfiles.removeAll { $0.id == profile.id }
                    unsavingProfileId = nil
                    // PERFORMANCE: Invalidate cache so next load gets fresh data
                    lastFetchTime = nil
                }

                Logger.shared.info("Unsaved profile: \(profile.user.fullName)", category: .general)

                // Track analytics
                AnalyticsServiceEnhanced.shared.trackEvent(
                    .profileUnsaved,
                    properties: [
                        "unsavedUserId": profile.user.id,
                        "savedDuration": Date().timeIntervalSince(profile.savedAt)
                    ]
                )
            } catch {
                await MainActor.run {
                    unsavingProfileId = nil
                    errorMessage = "Failed to unsave profile. Please try again."
                }
                Logger.shared.error("Error unsaving profile", category: .general, error: error)

                // Auto-clear error after 3 seconds
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    await MainActor.run {
                        if errorMessage == "Failed to unsave profile. Please try again." {
                            errorMessage = ""
                        }
                    }
                }
            }
        }
    }

    func clearAllSaved() {
        guard let currentUserId = AuthService.shared.currentUser?.id else { return }

        Task {
            do {
                let snapshot = try await db.collection("saved_profiles")
                    .whereField("userId", isEqualTo: currentUserId)
                    .getDocuments()

                // Delete all saved profiles
                let batch = db.batch()
                for doc in snapshot.documents {
                    batch.deleteDocument(doc.reference)
                }
                try await batch.commit()

                // Clear local state
                savedProfiles = []

                Logger.shared.info("Cleared all saved profiles", category: .general)

                // Track analytics
                AnalyticsServiceEnhanced.shared.trackEvent(
                    .savedProfilesCleared,
                    properties: ["count": snapshot.documents.count]
                )
            } catch {
                Logger.shared.error("Error clearing saved profiles", category: .general, error: error)
            }
        }
    }

    func saveProfile(user: User, note: String? = nil) async {
        guard let currentUserId = AuthService.shared.currentUser?.id,
              let savedUserId = user.id else {
            Logger.shared.error("Cannot save profile: Missing user ID", category: .general)
            return
        }

        // Check if already saved to prevent duplicates
        if savedProfiles.contains(where: { $0.user.id == savedUserId }) {
            Logger.shared.info("Profile already saved: \(user.fullName)", category: .general)
            return
        }

        do {
            let saveData: [String: Any] = [
                "userId": currentUserId,
                "savedUserId": savedUserId,
                "savedAt": Timestamp(date: Date()),
                "note": note ?? ""
            ]

            let docRef = try await db.collection("saved_profiles").addDocument(data: saveData)

            // Update local state
            let newSaved = SavedProfile(
                id: docRef.documentID,
                user: user,
                savedAt: Date(),
                note: note
            )
            savedProfiles.insert(newSaved, at: 0)

            Logger.shared.info("Saved profile: \(user.fullName) (\(docRef.documentID))", category: .general)

            // Track analytics
            AnalyticsServiceEnhanced.shared.trackEvent(
                .profileSaved,
                properties: ["savedUserId": savedUserId]
            )
        } catch {
            Logger.shared.error("Error saving profile to Firestore", category: .general, error: error)
        }
    }
}

#Preview {
    SavedProfilesView()
        .environmentObject(AuthService.shared)
}
