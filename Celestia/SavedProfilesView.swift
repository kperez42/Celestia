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
    @StateObject private var viewModel = SavedProfilesViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var selectedUser: User?
    @State private var showUserDetail = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    loadingView
                } else if viewModel.savedProfiles.isEmpty {
                    emptyStateView
                } else {
                    profilesGrid
                }
            }
            .navigationTitle("Saved Profiles")
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

                if !viewModel.savedProfiles.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                viewModel.clearAllSaved()
                            } label: {
                                Label("Clear All", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .task {
                await viewModel.loadSavedProfiles()
            }
            .refreshable {
                await viewModel.loadSavedProfiles()
            }
            .sheet(item: $selectedUser) { user in
                UserDetailView(user: user)
            }
        }
    }

    // MARK: - Profiles Grid

    private var profilesGrid: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Stats header
                statsHeader

                // Saved profiles grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(viewModel.savedProfiles) { saved in
                        SavedProfileCard(
                            savedProfile: saved,
                            onTap: {
                                selectedUser = saved.user
                                HapticManager.shared.impact(.light)
                            },
                            onUnsave: {
                                viewModel.unsaveProfile(saved)
                                HapticManager.shared.impact(.medium)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top)
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.savedProfiles.count)")
                    .font(.title.bold())
                    .foregroundColor(.purple)

                Text("Saved Profiles")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(viewModel.savedThisWeek)")
                    .font(.title3.bold())
                    .foregroundColor(.blue)

                Text("This Week")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        .padding(.horizontal)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading saved profiles...")
                .font(.subheadline)
                .foregroundColor(.secondary)
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Saved Profile Card

struct SavedProfileCard: View {
    let savedProfile: SavedProfile
    let onTap: () -> Void
    let onUnsave: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    // Profile image
                    if let imageURL = savedProfile.user.photos.first, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                    } else {
                        LinearGradient(
                            colors: [.purple.opacity(0.6), .pink.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                    .frame(height: 200)
                    .clipped()

                    // User info
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(savedProfile.user.fullName)
                                .font(.headline)
                                .lineLimit(1)

                            Text("\(savedProfile.user.age)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Spacer()
                        }

                        Text(savedProfile.user.location)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        Text("Saved \(savedProfile.savedAt.timeAgo())")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                    .padding(12)
                }

                // Unsave button
                Button(action: onUnsave) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.purple)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                }
                .buttonStyle(ScaleButtonStyle(scaleEffect: 0.85))
                .padding(8)
            }
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Saved Profile Model

struct SavedProfile: Identifiable {
    let id: String
    let user: User
    let savedAt: Date
    let note: String?
}

// MARK: - View Model

@MainActor
class SavedProfilesViewModel: ObservableObject {
    @Published var savedProfiles: [SavedProfile] = []
    @Published var isLoading = false

    var savedThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return savedProfiles.filter { $0.savedAt >= weekAgo }.count
    }

    private let db = Firestore.firestore()

    func loadSavedProfiles() async {
        guard let currentUserId = AuthService.shared.currentUser?.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let savedSnapshot = try await db.collection("saved_profiles")
                .whereField("userId", isEqualTo: currentUserId)
                .order(by: "savedAt", descending: true)
                .getDocuments()

            var profiles: [SavedProfile] = []

            for doc in savedSnapshot.documents {
                let data = doc.data()
                if let savedUserId = data["savedUserId"] as? String,
                   let savedAt = (data["savedAt"] as? Timestamp)?.dateValue() {

                    // Fetch saved user details
                    let userDoc = try await db.collection("users").document(savedUserId).getDocument()
                    if let user = try? userDoc.data(as: User.self) {
                        profiles.append(SavedProfile(
                            id: doc.documentID,
                            user: user,
                            savedAt: savedAt,
                            note: data["note"] as? String
                        ))
                    }
                }
            }

            savedProfiles = profiles
            Logger.shared.info("Loaded \(profiles.count) saved profiles", category: .general)
        } catch {
            Logger.shared.error("Error loading saved profiles", category: .general, error: error)
        }
    }

    func unsaveProfile(_ profile: SavedProfile) {
        guard let currentUserId = AuthService.shared.currentUser?.id else { return }

        Task {
            do {
                // Remove from Firestore
                try await db.collection("saved_profiles").document(profile.id).delete()

                // Update local state
                savedProfiles.removeAll { $0.id == profile.id }

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
                Logger.shared.error("Error unsaving profile", category: .general, error: error)
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
        guard let currentUserId = AuthService.shared.currentUser?.id else { return }

        do {
            let saveData: [String: Any] = [
                "userId": currentUserId,
                "savedUserId": user.id,
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

            Logger.shared.info("Saved profile: \(user.fullName)", category: .general)

            // Track analytics
            AnalyticsServiceEnhanced.shared.trackEvent(
                .profileSaved,
                properties: ["savedUserId": user.id]
            )
        } catch {
            Logger.shared.error("Error saving profile", category: .general, error: error)
        }
    }
}

// MARK: - Analytics Events Extension

extension AnalyticsEvent {
    static let profileSaved = AnalyticsEvent(name: "profile_saved")
    static let profileUnsaved = AnalyticsEvent(name: "profile_unsaved")
    static let savedProfilesCleared = AnalyticsEvent(name: "saved_profiles_cleared")
}

#Preview {
    SavedProfilesView()
        .environmentObject(AuthService.shared)
}
