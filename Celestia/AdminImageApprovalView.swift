//
//  AdminImageApprovalView.swift
//  Celestia
//
//  Admin view for reviewing and approving user profile photos
//

import SwiftUI
import FirebaseFirestore

struct AdminImageApprovalView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = AdminImageApprovalViewModel()

    @State private var selectedUser: PendingUserForApproval?
    @State private var showingPhotoViewer = false
    @State private var selectedPhotoIndex = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView("Loading pending users...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.pendingUsers.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.pendingUsers) { user in
                                PendingUserCard(
                                    user: user,
                                    onPhotoTap: { index in
                                        selectedUser = user
                                        selectedPhotoIndex = index
                                        showingPhotoViewer = true
                                    },
                                    onApprove: {
                                        Task {
                                            await viewModel.approveUser(user)
                                        }
                                    },
                                    onReject: {
                                        Task {
                                            await viewModel.rejectUser(user)
                                        }
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Image Approval")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await viewModel.loadPendingUsers()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .fullScreenCover(isPresented: $showingPhotoViewer) {
                if let user = selectedUser {
                    AdminFullScreenPhotoViewer(
                        photos: user.photos,
                        selectedIndex: $selectedPhotoIndex,
                        userName: user.fullName,
                        onApprove: {
                            showingPhotoViewer = false
                            Task {
                                await viewModel.approveUser(user)
                            }
                        },
                        onReject: {
                            showingPhotoViewer = false
                            Task {
                                await viewModel.rejectUser(user)
                            }
                        },
                        onDismiss: {
                            showingPhotoViewer = false
                        }
                    )
                }
            }
            .task {
                await viewModel.loadPendingUsers()
            }
            .refreshable {
                await viewModel.loadPendingUsers()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            Text("All Caught Up!")
                .font(.title2.bold())

            Text("No pending users to review")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Pending User Card

struct PendingUserCard: View {
    let user: PendingUserForApproval
    let onPhotoTap: (Int) -> Void
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User info header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.fullName)
                        .font(.headline)

                    Text("\(user.age) • \(user.location)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(user.photos.count) photos")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.purple.opacity(0.1))
                    .foregroundColor(.purple)
                    .cornerRadius(8)
            }

            // Photo grid - tap to expand
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(user.photos.enumerated()), id: \.offset) { index, photoURL in
                        Button {
                            onPhotoTap(index)
                        } label: {
                            CachedAsyncImage(url: URL(string: photoURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            }
                            .frame(width: 100, height: 133) // 3:4 ratio
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    onReject()
                } label: {
                    HStack {
                        Image(systemName: "xmark")
                        Text("Reject")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .cornerRadius(12)
                }

                Button {
                    onApprove()
                } label: {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Approve")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
}

// MARK: - Admin Full Screen Photo Viewer

struct AdminFullScreenPhotoViewer: View {
    let photos: [String]
    @Binding var selectedIndex: Int
    let userName: String
    let onApprove: () -> Void
    let onReject: () -> Void
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging = false

    var body: some View {
        ZStack {
            // Dark background
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }

                    Spacer()

                    VStack {
                        Text(userName)
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("\(selectedIndex + 1) of \(photos.count)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()

                    // Spacer for balance
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding()

                // Photo viewer with horizontal scroll
                TabView(selection: $selectedIndex) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, photoURL in
                        AdminApprovalZoomablePhotoView(photoURL: photoURL)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<photos.count, id: \.self) { index in
                        Circle()
                            .fill(index == selectedIndex ? Color.white : Color.white.opacity(0.4))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.vertical, 16)

                // Action buttons
                HStack(spacing: 20) {
                    Button {
                        HapticManager.shared.notification(.error)
                        onReject()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 50))
                            Text("Reject")
                                .font(.caption)
                        }
                        .foregroundColor(.red)
                    }

                    Spacer()

                    Button {
                        HapticManager.shared.notification(.success)
                        onApprove()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                            Text("Approve")
                                .font(.caption)
                        }
                        .foregroundColor(.green)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Admin Approval Zoomable Photo View

struct AdminApprovalZoomablePhotoView: View {
    let photoURL: String

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            CachedAsyncImage(url: URL(string: photoURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale = min(max(scale * delta, 1), 4)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                if scale < 1 {
                                    withAnimation {
                                        scale = 1
                                        offset = .zero
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                if scale > 1 {
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation {
                            if scale > 1 {
                                scale = 1
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2
                            }
                        }
                    }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

// MARK: - View Model

@MainActor
class AdminImageApprovalViewModel: ObservableObject {
    @Published var pendingUsers: [PendingUserForApproval] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    func loadPendingUsers() async {
        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await db.collection("users")
                .whereField("profileStatus", isEqualTo: "pending")
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .getDocuments()

            pendingUsers = snapshot.documents.compactMap { doc -> PendingUserForApproval? in
                let data = doc.data()

                guard let fullName = data["fullName"] as? String,
                      let photos = data["photos"] as? [String],
                      !photos.isEmpty else {
                    return nil
                }

                return PendingUserForApproval(
                    id: doc.documentID,
                    fullName: fullName,
                    age: data["age"] as? Int ?? 0,
                    location: data["location"] as? String ?? "Unknown",
                    photos: photos,
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                )
            }

            Logger.shared.info("Loaded \(pendingUsers.count) pending users for review", category: .admin)
        } catch {
            errorMessage = "Failed to load pending users"
            Logger.shared.error("Failed to load pending users", category: .admin, error: error)
        }

        isLoading = false
    }

    func approveUser(_ user: PendingUserForApproval) async {
        do {
            try await db.collection("users").document(user.id).updateData([
                "profileStatus": "active",
                "profileStatusUpdatedAt": FieldValue.serverTimestamp()
            ])

            // Remove from local list
            pendingUsers.removeAll { $0.id == user.id }

            Logger.shared.info("Approved user: \(user.id)", category: .admin)
            HapticManager.shared.notification(.success)
        } catch {
            Logger.shared.error("Failed to approve user", category: .admin, error: error)
            HapticManager.shared.notification(.error)
        }
    }

    func rejectUser(_ user: PendingUserForApproval) async {
        do {
            try await db.collection("users").document(user.id).updateData([
                "profileStatus": "rejected",
                "profileStatusReason": "Your photos did not meet our community guidelines. Please upload clear, appropriate photos.",
                "profileStatusReasonCode": "photos_rejected",
                "profileStatusFixInstructions": "Please upload new photos that clearly show your face and follow our photo guidelines.",
                "profileStatusUpdatedAt": FieldValue.serverTimestamp()
            ])

            // Remove from local list
            pendingUsers.removeAll { $0.id == user.id }

            Logger.shared.info("Rejected user: \(user.id)", category: .admin)
            HapticManager.shared.notification(.warning)
        } catch {
            Logger.shared.error("Failed to reject user", category: .admin, error: error)
            HapticManager.shared.notification(.error)
        }
    }
}

// MARK: - Model

struct PendingUserForApproval: Identifiable {
    let id: String
    let fullName: String
    let age: Int
    let location: String
    let photos: [String]
    let createdAt: Date
}

#Preview {
    AdminImageApprovalView()
        .environmentObject(AuthService.shared)
}
