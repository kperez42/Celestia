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
    @State private var selectedUserForDetail: PendingUserForApproval?
    @State private var showingUserDetail = false

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
                                    },
                                    onViewProfile: {
                                        selectedUserForDetail = user
                                        showingUserDetail = true
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
            .sheet(isPresented: $showingUserDetail) {
                if let user = selectedUserForDetail {
                    AdminPendingUserDetailView(
                        user: user,
                        onApprove: {
                            showingUserDetail = false
                            Task {
                                await viewModel.approveUser(user)
                            }
                        },
                        onReject: {
                            showingUserDetail = false
                            Task {
                                await viewModel.rejectUser(user)
                            }
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
    let onViewProfile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User info header - tappable to view full profile
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.fullName)
                        .font(.headline)

                    Text("\(user.age) • \(user.gender) • \(user.location)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // View profile button
                Button {
                    onViewProfile()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "person.circle")
                        Text("View")
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }

                Text("\(user.photos.count) photos")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.purple.opacity(0.1))
                    .foregroundColor(.purple)
                    .cornerRadius(8)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onViewProfile()
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
                    gender: data["gender"] as? String ?? "",
                    location: data["location"] as? String ?? "Unknown",
                    country: data["country"] as? String ?? "",
                    bio: data["bio"] as? String ?? "",
                    photos: photos,
                    interests: data["interests"] as? [String] ?? [],
                    languages: data["languages"] as? [String] ?? [],
                    lookingFor: data["lookingFor"] as? String ?? "",
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    height: data["height"] as? Int,
                    educationLevel: data["educationLevel"] as? String,
                    religion: data["religion"] as? String,
                    relationshipGoal: data["relationshipGoal"] as? String,
                    smoking: data["smoking"] as? String,
                    drinking: data["drinking"] as? String,
                    exercise: data["exercise"] as? String,
                    pets: data["pets"] as? String,
                    diet: data["diet"] as? String
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
    let gender: String
    let location: String
    let country: String
    let bio: String
    let photos: [String]
    let interests: [String]
    let languages: [String]
    let lookingFor: String
    let createdAt: Date

    // Lifestyle fields
    let height: Int?
    let educationLevel: String?
    let religion: String?
    let relationshipGoal: String?
    let smoking: String?
    let drinking: String?
    let exercise: String?
    let pets: String?
    let diet: String?
}

// MARK: - Admin Pending User Detail View

struct AdminPendingUserDetailView: View {
    let user: PendingUserForApproval
    let onApprove: () -> Void
    let onReject: () -> Void

    @Environment(\.dismiss) var dismiss
    @State private var selectedPhotoIndex = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Photos carousel
                    TabView(selection: $selectedPhotoIndex) {
                        ForEach(Array(user.photos.enumerated()), id: \.offset) { index, photoURL in
                            CachedAsyncImage(url: URL(string: photoURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            }
                            .frame(height: 400)
                            .clipped()
                            .tag(index)
                        }
                    }
                    .frame(height: 400)
                    .tabViewStyle(.page)

                    // Profile content
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        headerSection

                        // Bio
                        if !user.bio.isEmpty {
                            bioSection
                        }

                        // Languages
                        if !user.languages.isEmpty {
                            languagesSection
                        }

                        // Interests
                        if !user.interests.isEmpty {
                            interestsSection
                        }

                        // Details
                        if hasDetails {
                            detailsSection
                        }

                        // Lifestyle
                        if hasLifestyle {
                            lifestyleSection
                        }

                        // Looking for
                        lookingForSection
                    }
                    .padding(20)
                    .padding(.bottom, 80)
                }
            }
            .background(Color(.systemGroupedBackground))
            .ignoresSafeArea(edges: .top)
            .overlay(alignment: .bottom) {
                actionButtons
            }
            .navigationTitle("Profile Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(user.fullName)
                    .font(.system(size: 28, weight: .bold))

                Text("\(user.age)")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.purple)
                Text("\(user.location), \(user.country)")
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)

            HStack(spacing: 8) {
                Label(user.gender, systemImage: "person.fill")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)

                Text("Joined \(user.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Bio Section

    private var bioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("About", systemImage: "text.quote")
                .font(.headline)
                .foregroundColor(.purple)

            Text(user.bio)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Languages Section

    private var languagesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Languages", systemImage: "globe")
                .font(.headline)
                .foregroundColor(.green)

            FlowLayout(spacing: 8) {
                ForEach(user.languages, id: \.self) { language in
                    Text(language)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(16)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Interests Section

    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Interests", systemImage: "heart.fill")
                .font(.headline)
                .foregroundColor(.pink)

            FlowLayout(spacing: 8) {
                ForEach(user.interests, id: \.self) { interest in
                    Text(interest)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.pink.opacity(0.1))
                        .foregroundColor(.pink)
                        .cornerRadius(16)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Details Section

    private var hasDetails: Bool {
        user.height != nil ||
        (user.educationLevel != nil && user.educationLevel != "Prefer not to say") ||
        (user.religion != nil && user.religion != "Prefer not to say") ||
        (user.relationshipGoal != nil && user.relationshipGoal != "Prefer not to say")
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Details", systemImage: "person.text.rectangle")
                .font(.headline)
                .foregroundColor(.indigo)

            VStack(spacing: 10) {
                if let height = user.height {
                    DetailRowView(icon: "ruler", label: "Height", value: "\(height) cm")
                }
                if let education = user.educationLevel, education != "Prefer not to say", !education.isEmpty {
                    DetailRowView(icon: "graduationcap.fill", label: "Education", value: education)
                }
                if let religion = user.religion, religion != "Prefer not to say", !religion.isEmpty {
                    DetailRowView(icon: "sparkles", label: "Religion", value: religion)
                }
                if let goal = user.relationshipGoal, goal != "Prefer not to say", !goal.isEmpty {
                    DetailRowView(icon: "heart.circle", label: "Looking for", value: goal)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Lifestyle Section

    private var hasLifestyle: Bool {
        (user.smoking != nil && user.smoking != "Prefer not to say") ||
        (user.drinking != nil && user.drinking != "Prefer not to say") ||
        (user.exercise != nil && user.exercise != "Prefer not to say") ||
        (user.diet != nil && user.diet != "Prefer not to say") ||
        (user.pets != nil && user.pets != "Prefer not to say")
    }

    private var lifestyleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Lifestyle", systemImage: "leaf.fill")
                .font(.headline)
                .foregroundColor(.green)

            VStack(spacing: 10) {
                if let smoking = user.smoking, smoking != "Prefer not to say", !smoking.isEmpty {
                    DetailRowView(icon: "smoke", label: "Smoking", value: smoking)
                }
                if let drinking = user.drinking, drinking != "Prefer not to say", !drinking.isEmpty {
                    DetailRowView(icon: "wineglass", label: "Drinking", value: drinking)
                }
                if let exercise = user.exercise, exercise != "Prefer not to say", !exercise.isEmpty {
                    DetailRowView(icon: "figure.run", label: "Exercise", value: exercise)
                }
                if let diet = user.diet, diet != "Prefer not to say", !diet.isEmpty {
                    DetailRowView(icon: "fork.knife", label: "Diet", value: diet)
                }
                if let pets = user.pets, pets != "Prefer not to say", !pets.isEmpty {
                    DetailRowView(icon: "pawprint.fill", label: "Pets", value: pets)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Looking For Section

    private var lookingForSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Interested In", systemImage: "heart.text.square")
                .font(.headline)
                .foregroundColor(.orange)

            Text(user.lookingFor.isEmpty ? "Everyone" : user.lookingFor)
                .font(.body)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button {
                HapticManager.shared.notification(.error)
                onReject()
            } label: {
                HStack {
                    Image(systemName: "xmark")
                    Text("Reject")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.red)
                .cornerRadius(16)
            }

            Button {
                HapticManager.shared.notification(.success)
                onApprove()
            } label: {
                HStack {
                    Image(systemName: "checkmark")
                    Text("Approve")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.green)
                .cornerRadius(16)
            }
        }
        .padding()
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
        )
    }
}

// MARK: - Detail Row View (for admin detail view)

private struct DetailRowView: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)

            Text(label)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

#Preview {
    AdminImageApprovalView()
        .environmentObject(AuthService.shared)
}
