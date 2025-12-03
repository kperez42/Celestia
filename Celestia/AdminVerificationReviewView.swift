//
//  AdminVerificationReviewView.swift
//  Celestia
//
//  Admin dashboard to review and approve/reject ID verification submissions
//  For small apps - manual review before scaling to Stripe Identity
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import FirebaseFunctions

// MARK: - Pending Verification Model

struct PendingVerification: Identifiable {
    let id: String
    let userId: String
    let userName: String
    let userEmail: String
    let idType: String
    let idPhotoURL: String
    let selfiePhotoURL: String
    let status: String
    let submittedAt: Date?
    let notes: String

    init(id: String, data: [String: Any]) {
        self.id = id
        self.userId = data["userId"] as? String ?? ""
        self.userName = data["userName"] as? String ?? "Unknown"
        self.userEmail = data["userEmail"] as? String ?? ""
        self.idType = data["idType"] as? String ?? "Unknown"
        self.idPhotoURL = data["idPhotoURL"] as? String ?? ""
        self.selfiePhotoURL = data["selfiePhotoURL"] as? String ?? ""
        self.status = data["status"] as? String ?? "pending"
        self.notes = data["notes"] as? String ?? ""

        if let timestamp = data["submittedAt"] as? Timestamp {
            self.submittedAt = timestamp.dateValue()
        } else {
            self.submittedAt = nil
        }
    }

    var idTypeIcon: String {
        switch idType {
        case "Driver's License": return "car.fill"
        case "Passport": return "globe"
        case "National ID": return "person.text.rectangle.fill"
        case "State ID": return "building.columns.fill"
        default: return "doc.fill"
        }
    }
}

// MARK: - Admin Verification Review View

struct AdminVerificationReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AdminVerificationReviewViewModel()

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading verifications...")
                } else if viewModel.pendingVerifications.isEmpty {
                    emptyStateView
                } else {
                    verificationListView
                }
            }
            .navigationTitle("ID Verifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { Task { await viewModel.loadPendingVerifications() } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .onAppear {
                viewModel.startListening()
            }
            .onDisappear {
                viewModel.stopListening()
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("All Caught Up!")
                .font(.title2)
                .fontWeight(.bold)

            Text("No pending ID verifications to review")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    // MARK: - Verification List

    private var verificationListView: some View {
        List {
            Section {
                Text("\(viewModel.pendingVerifications.count) pending review")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            ForEach(viewModel.pendingVerifications) { verification in
                NavigationLink(destination: VerificationDetailView(
                    verification: verification,
                    onApprove: { await viewModel.approveVerification(verification) },
                    onReject: { reason in await viewModel.rejectVerification(verification, reason: reason) }
                )) {
                    VerificationRowView(verification: verification)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Verification Row View (Enhanced with inline photos)

struct VerificationRowView: View {
    let verification: PendingVerification
    var onQuickApprove: (() -> Void)? = nil
    var onQuickReject: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User info header
            HStack(spacing: 10) {
                Text(verification.userName)
                    .font(.headline)

                Spacer()

                // ID Type badge
                HStack(spacing: 4) {
                    Image(systemName: verification.idTypeIcon)
                        .font(.caption2)
                    Text(verification.idType)
                        .font(.caption)
                }
                .foregroundColor(.purple)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(6)

                if let date = verification.submittedAt {
                    Text(date.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Side-by-side photo previews (fixed size containers)
            HStack(spacing: 12) {
                // ID Photo - fixed 120x80 container
                VStack(spacing: 4) {
                    AsyncImage(url: URL(string: verification.idPhotoURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 80)
                            .clipped()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 120, height: 80)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.7)
                            )
                    }
                    .frame(width: 120, height: 80)
                    .cornerRadius(8)

                    Text(verification.idType)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Selfie Photo - fixed 120x80 container
                VStack(spacing: 4) {
                    AsyncImage(url: URL(string: verification.selfiePhotoURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 80)
                            .clipped()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 120, height: 80)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.7)
                            )
                    }
                    .frame(width: 120, height: 80)
                    .cornerRadius(8)

                    Text("Selfie")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Quick action buttons (if callbacks provided)
            if onQuickApprove != nil || onQuickReject != nil {
                HStack(spacing: 12) {
                    // Approve button
                    if let approve = onQuickApprove {
                        Button(action: approve) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Approve")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }

                    // Reject button
                    if let reject = onQuickReject {
                        Button(action: reject) {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle.fill")
                                Text("Reject")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.red)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Verification Detail View

struct VerificationDetailView: View {
    let verification: PendingVerification
    let onApprove: () async -> Void
    let onReject: (String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = false
    @State private var showingRejectSheet = false
    @State private var rejectReason = ""
    @State private var selectedImageURL: String?

    // Both photos for gallery navigation
    private var allPhotos: [String] {
        [verification.idPhotoURL, verification.selfiePhotoURL]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // User Info
                userInfoSection

                // Photos
                photosSection

                // Actions (only for pending)
                if verification.status == "pending" {
                    actionButtons
                }
            }
            .padding()
        }
        .navigationTitle("Review Verification")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingRejectSheet) {
            rejectReasonSheet
        }
        .fullScreenCover(item: $selectedImageURL) { url in
            FullScreenImageView(imageURL: url, allImageURLs: allPhotos)
        }
    }

    // MARK: - User Info Section

    private var userInfoSection: some View {
        VStack(spacing: 12) {
            AsyncImage(url: URL(string: verification.selfiePhotoURL)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.gray)
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())

            Text(verification.userName)
                .font(.title2)
                .fontWeight(.bold)

            Text(verification.userEmail)
                .font(.subheadline)
                .foregroundColor(.secondary)

            // ID Type badge
            HStack(spacing: 6) {
                Image(systemName: verification.idTypeIcon)
                Text(verification.idType)
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(8)

            if let date = verification.submittedAt {
                Text("Submitted: \(date.formatted())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Photos Section

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Submitted Documents")
                    .font(.headline)
                Spacer()
                // Gallery hint
                HStack(spacing: 4) {
                    Image(systemName: "hand.tap")
                    Text("Tap to view")
                }
                .font(.caption2)
                .foregroundColor(.blue)
            }

            // ID Photo
            VStack(alignment: .leading, spacing: 8) {
                Label(verification.idType, systemImage: verification.idTypeIcon)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                AsyncImage(url: URL(string: verification.idPhotoURL)) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                        )
                        .onTapGesture {
                            selectedImageURL = verification.idPhotoURL
                            HapticManager.shared.impact(.light)
                        }
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                        .cornerRadius(12)
                        .overlay(
                            ProgressView()
                        )
                }
                .frame(maxHeight: 250)

                Text("Tap to view full size • Swipe to compare")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }

            // Selfie Photo
            VStack(alignment: .leading, spacing: 8) {
                Label("Selfie Photo", systemImage: "person.crop.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                AsyncImage(url: URL(string: verification.selfiePhotoURL)) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                        )
                        .onTapGesture {
                            selectedImageURL = verification.selfiePhotoURL
                            HapticManager.shared.impact(.light)
                        }
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                        .cornerRadius(12)
                        .overlay(
                            ProgressView()
                        )
                }
                .frame(maxHeight: 250)

                Text("Tap to view full size • Swipe to compare")
                    .font(.caption2)
                    .foregroundColor(.purple)
            }

            // Comparison hint
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Tap any photo to open full-screen gallery. Swipe left/right to compare ID and selfie.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Approve Button
            Button(action: {
                Task {
                    isProcessing = true
                    await onApprove()
                    isProcessing = false
                    dismiss()
                }
            }) {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Approve Verification")
                    }
                }
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(12)
            }
            .disabled(isProcessing)

            // Reject Button
            Button(action: {
                showingRejectSheet = true
            }) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    Text("Reject Verification")
                }
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(12)
            }
            .disabled(isProcessing)
        }
    }

    // MARK: - Reject Reason Sheet

    private var rejectReasonSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Why are you rejecting this verification?")
                    .font(.headline)

                // Quick reasons
                VStack(spacing: 8) {
                    ForEach(rejectionReasons, id: \.self) { reason in
                        Button(action: { rejectReason = reason }) {
                            HStack {
                                Text(reason)
                                    .foregroundColor(.primary)
                                Spacer()
                                if rejectReason == reason {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                    }
                }

                // Custom reason
                TextField("Or enter custom reason...", text: $rejectReason)
                    .textFieldStyle(.roundedBorder)

                Spacer()

                Button(action: {
                    Task {
                        showingRejectSheet = false
                        isProcessing = true
                        await onReject(rejectReason)
                        isProcessing = false
                        dismiss()
                    }
                }) {
                    Text("Confirm Rejection")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(rejectReason.isEmpty ? Color.gray : Color.red)
                        .cornerRadius(12)
                }
                .disabled(rejectReason.isEmpty)
            }
            .padding()
            .navigationTitle("Reject Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showingRejectSheet = false }
                }
            }
        }
    }

    private var rejectionReasons: [String] {
        [
            "ID photo is blurry or unreadable",
            "Selfie doesn't match ID photo",
            "ID appears to be expired",
            "ID appears to be fake or altered",
            "Face not clearly visible in selfie"
        ]
    }
}

// MARK: - Full Screen Image View (Enhanced with Swipe Navigation)

struct FullScreenImageView: View {
    let imageURL: String
    var allImageURLs: [String]? = nil  // Optional array for gallery mode
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var currentIndex: Int = 0
    @State private var dismissDragOffset: CGFloat = 0

    private let dismissThreshold: CGFloat = 150

    init(imageURL: String, allImageURLs: [String]? = nil) {
        self.imageURL = imageURL
        self.allImageURLs = allImageURLs
        // Find initial index if in gallery mode
        if let urls = allImageURLs, let index = urls.firstIndex(of: imageURL) {
            _currentIndex = State(initialValue: index)
        }
    }

    private var photos: [String] {
        allImageURLs ?? [imageURL]
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .opacity(backgroundOpacity)
                    .ignoresSafeArea()

                if photos.count > 1 {
                    // Gallery mode with swipe navigation
                    TabView(selection: $currentIndex) {
                        ForEach(Array(photos.enumerated()), id: \.offset) { index, url in
                            ZoomableIDPhotoView(url: URL(string: url))
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                    .offset(y: dismissDragOffset)
                    .scaleEffect(dismissScale)
                } else {
                    // Single image mode
                    ZoomableIDPhotoView(url: URL(string: imageURL))
                        .offset(y: dismissDragOffset)
                        .scaleEffect(dismissScale)
                }

                // Controls overlay
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .padding()
                        }
                    }

                    Spacer()

                    // Photo counter and label
                    VStack(spacing: 8) {
                        if photos.count > 1 {
                            Text("\(currentIndex + 1) / \(photos.count)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(20)

                            // Label for current photo
                            Text(currentIndex == 0 ? "ID Document" : "Selfie Photo")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(currentIndex == 0 ? Color.blue : Color.purple)
                                .cornerRadius(12)
                        }

                        Text("Swipe left/right • Pinch to zoom • Swipe down to close")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.bottom, 40)
                }
                .opacity(controlsOpacity)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dismissDragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > dismissThreshold {
                            HapticManager.shared.impact(.light)
                            withAnimation(.easeOut(duration: 0.2)) {
                                dismissDragOffset = geometry.size.height
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                dismiss()
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dismissDragOffset = 0
                            }
                        }
                    }
            )
        }
        .statusBarHidden()
    }

    private var backgroundOpacity: Double {
        let progress = min(dismissDragOffset / dismissThreshold, 1.0)
        return 1.0 - (progress * 0.5)
    }

    private var dismissScale: CGFloat {
        let progress = min(dismissDragOffset / dismissThreshold, 1.0)
        return 1.0 - (progress * 0.1)
    }

    private var controlsOpacity: Double {
        let progress = min(dismissDragOffset / dismissThreshold, 1.0)
        return 1.0 - progress
    }
}

// MARK: - Zoomable ID Photo View

struct ZoomableIDPhotoView: View {
    let url: URL?

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
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
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                scale = 1
                                offset = .zero
                            }
                        }
                    }
            )
            .simultaneousGesture(
                scale > 1 ?
                DragGesture()
                    .onChanged { value in
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
                : nil
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    if scale > 1 {
                        scale = 1
                        offset = .zero
                        lastOffset = .zero
                    } else {
                        scale = 2
                    }
                }
                HapticManager.shared.impact(.light)
            }
        }
    }
}

// Make String Identifiable for fullScreenCover
extension String: @retroactive Identifiable {
    public var id: String { self }
}

// MARK: - View Model

@MainActor
class AdminVerificationReviewViewModel: ObservableObject {
    @Published var pendingVerifications: [PendingVerification] = []
    @Published var isLoading = false
    @Published var showingError = false
    @Published var errorMessage = ""

    private let db = Firestore.firestore()
    private let functions = Functions.functions()
    private var verificationListener: ListenerRegistration?
    private var previousCount = 0

    // MARK: - Real-Time Listener

    /// Start listening to pending verifications in real-time
    func startListening() {
        verificationListener?.remove()
        isLoading = true

        verificationListener = db.collection("pendingVerifications")
            .whereField("status", isEqualTo: "pending")
            .order(by: "submittedAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                self.isLoading = false

                if let error = error {
                    Logger.shared.error("Verification listener error", category: .general, error: error)
                    self.errorMessage = "Failed to load: \(error.localizedDescription)"
                    return
                }

                guard let documents = snapshot?.documents else { return }

                let newVerifications = documents.map { doc in
                    PendingVerification(id: doc.documentID, data: doc.data())
                }

                // Detect new verifications and notify
                if newVerifications.count > self.previousCount && self.previousCount > 0 {
                    HapticManager.shared.notification(.warning)
                }
                self.previousCount = newVerifications.count

                withAnimation(.smooth(duration: 0.3)) {
                    self.pendingVerifications = newVerifications
                }

                Logger.shared.info("Real-time update: \(newVerifications.count) pending verifications", category: .general)
            }
    }

    /// Stop listening to verifications
    func stopListening() {
        verificationListener?.remove()
        verificationListener = nil
    }

    // MARK: - Load Pending Verifications (One-time fallback)

    func loadPendingVerifications() async {
        isLoading = true
        errorMessage = ""

        do {
            Logger.shared.info("Admin loading pending verifications...", category: .general)

            let snapshot = try await db.collection("pendingVerifications")
                .whereField("status", isEqualTo: "pending")
                .order(by: "submittedAt", descending: false)
                .getDocuments()

            pendingVerifications = snapshot.documents.map { doc in
                PendingVerification(id: doc.documentID, data: doc.data())
            }

            Logger.shared.info("Loaded \(pendingVerifications.count) pending verifications", category: .general)

            // If no results, provide more context
            if pendingVerifications.isEmpty {
                Logger.shared.info("No pending verifications found in Firestore", category: .general)
            }

        } catch {
            Logger.shared.error("Failed to load pending verifications", category: .general, error: error)
            errorMessage = "Failed to load: \(error.localizedDescription)"
            showingError = true
        }

        isLoading = false
    }

    // MARK: - Approve Verification

    func approveVerification(_ verification: PendingVerification) async {
        do {
            // Update user document - set both isVerified (for badge) and idVerified (for tracking)
            try await db.collection("users").document(verification.userId).updateData([
                "isVerified": true,  // This makes the badge show on profile
                "idVerified": true,  // This tracks ID verification specifically
                "idVerifiedAt": FieldValue.serverTimestamp(),
                "idVerificationMethod": "manual",
                "verificationMethods": FieldValue.arrayUnion(["manual_id"]),
                "trustScore": FieldValue.increment(Int64(30))
            ])

            // Delete sensitive photos from Storage (privacy protection)
            await deleteVerificationPhotos(userId: verification.userId)

            // Delete the verification record completely (no need to keep sensitive data)
            try await db.collection("pendingVerifications").document(verification.id).delete()

            // Remove from local list
            pendingVerifications.removeAll { $0.id == verification.id }

            Logger.shared.info("Approved verification for user: \(verification.userId) - photos deleted for privacy", category: .general)

        } catch {
            Logger.shared.error("Failed to approve verification", category: .general, error: error)
            errorMessage = "Failed to approve: \(error.localizedDescription)"
            showingError = true
        }
    }

    // MARK: - Reject Verification

    func rejectVerification(_ verification: PendingVerification, reason: String) async {
        do {
            // Delete sensitive photos from Storage (privacy protection)
            await deleteVerificationPhotos(userId: verification.userId)

            // Delete the verification record completely
            try await db.collection("pendingVerifications").document(verification.id).delete()

            // Notify user of rejection (optional: update user doc with rejection info)
            try await db.collection("users").document(verification.userId).updateData([
                "idVerificationRejected": true,
                "idVerificationRejectedAt": FieldValue.serverTimestamp(),
                "idVerificationRejectionReason": reason
            ])

            // Send push notification to user about rejection
            await sendIDVerificationRejectionNotification(userId: verification.userId, reason: reason)

            // Remove from local list
            pendingVerifications.removeAll { $0.id == verification.id }

            Logger.shared.info("Rejected verification for user: \(verification.userId), reason: \(reason) - photos deleted", category: .general)

        } catch {
            Logger.shared.error("Failed to reject verification", category: .general, error: error)
            errorMessage = "Failed to reject: \(error.localizedDescription)"
            showingError = true
        }
    }

    /// Send ID verification rejection notification via Cloud Function
    private func sendIDVerificationRejectionNotification(userId: String, reason: String) async {
        do {
            let callable = functions.httpsCallable("sendIDVerificationRejectionNotification")
            _ = try await callable.call([
                "userId": userId,
                "reason": reason
            ])
            Logger.shared.info("ID verification rejection notification sent to \(userId)", category: .general)
        } catch {
            Logger.shared.error("Failed to send ID verification rejection notification", category: .general, error: error)
        }
    }

    // MARK: - Delete Verification Photos (Privacy)

    private func deleteVerificationPhotos(userId: String) async {
        let storage = Storage.storage()

        // Delete ID photo
        let idPhotoRef = storage.reference().child("verification/\(userId)/id_photo.jpg")
        do {
            try await idPhotoRef.delete()
            Logger.shared.info("Deleted ID photo for user: \(userId)", category: .general)
        } catch {
            Logger.shared.warning("Could not delete ID photo: \(error.localizedDescription)", category: .general)
        }

        // Delete selfie photo
        let selfieRef = storage.reference().child("verification/\(userId)/selfie.jpg")
        do {
            try await selfieRef.delete()
            Logger.shared.info("Deleted selfie photo for user: \(userId)", category: .general)
        } catch {
            Logger.shared.warning("Could not delete selfie photo: \(error.localizedDescription)", category: .general)
        }
    }
}

// MARK: - Embedded View for Dashboard Tab

struct IDVerificationReviewEmbeddedView: View {
    @StateObject private var viewModel = AdminVerificationReviewViewModel()
    @State private var showingQuickRejectAlert = false
    @State private var verificationToReject: PendingVerification?
    @State private var showApprovalSuccess = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading verifications...")
            } else if viewModel.pendingVerifications.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    Text("All Caught Up!")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("No pending ID verifications to review")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if !viewModel.errorMessage.isEmpty {
                        Text("Error: \(viewModel.errorMessage)")
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button(action: {
                        Task { await viewModel.loadPendingVerifications() }
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.subheadline)
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Header
                        HStack {
                            Text("\(viewModel.pendingVerifications.count) pending")
                                .font(.headline)
                            Spacer()
                            Button(action: {
                                Task { await viewModel.loadPendingVerifications() }
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.subheadline)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // Verification cards
                        ForEach(viewModel.pendingVerifications) { verification in
                            VerificationCardView(
                                verification: verification,
                                onApprove: {
                                    HapticManager.shared.notification(.success)
                                    Task {
                                        await viewModel.approveVerification(verification)
                                        showApprovalSuccess = true
                                        // Auto-dismiss after 1.5 seconds
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            showApprovalSuccess = false
                                        }
                                    }
                                },
                                onReject: {
                                    HapticManager.shared.impact(.medium)
                                    verificationToReject = verification
                                    showingQuickRejectAlert = true
                                }
                            )
                            .padding(.horizontal)
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                        }
                        .animation(.spring(response: 0.4), value: viewModel.pendingVerifications.count)
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            // Start real-time listener when view appears
            viewModel.startListening()
        }
        .onDisappear {
            // Stop listener when view disappears
            viewModel.stopListening()
        }
        .overlay {
            // Success toast
            if showApprovalSuccess {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                        Text("Verified! Photos deleted.")
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                    .shadow(radius: 10)
                    .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(), value: showApprovalSuccess)
            }
        }
        .alert("Reject Verification", isPresented: $showingQuickRejectAlert) {
            Button("ID Blurry") {
                HapticManager.shared.notification(.warning)
                if let v = verificationToReject {
                    Task { await viewModel.rejectVerification(v, reason: "ID photo is blurry or unreadable") }
                }
            }
            Button("Doesn't Match") {
                HapticManager.shared.notification(.warning)
                if let v = verificationToReject {
                    Task { await viewModel.rejectVerification(v, reason: "Selfie doesn't match ID photo") }
                }
            }
            Button("Fake/Invalid") {
                HapticManager.shared.notification(.error)
                if let v = verificationToReject {
                    Task { await viewModel.rejectVerification(v, reason: "ID appears to be fake or invalid") }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Select a reason for rejection")
        }
    }
}

// MARK: - Verification Card View (Clean card layout for admin)

struct VerificationCardView: View {
    let verification: PendingVerification
    let onApprove: () -> Void
    let onReject: () -> Void
    @State private var showingFullPhoto = false
    @State private var selectedPhotoURL: String = ""

    // Fixed photo height for consistent card sizing
    private let photoHeight: CGFloat = 140

    // Both photos for gallery navigation
    private var allPhotos: [String] {
        [verification.idPhotoURL, verification.selfiePhotoURL]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verification.userName)
                        .font(.headline)
                    Text(verification.userEmail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // ID Type badge
                HStack(spacing: 4) {
                    Image(systemName: verification.idTypeIcon)
                        .font(.caption2)
                    Text(verification.idType)
                        .font(.caption)
                }
                .foregroundColor(.purple)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(6)

                if let date = verification.submittedAt {
                    Text(date.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(6)
                }
            }
            .padding()

            // Tap hint
            HStack {
                Image(systemName: "hand.tap")
                    .font(.caption2)
                Text("Tap photos to view full screen")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Photos - side by side comparison with fixed height (tap to open gallery)
            HStack(spacing: 2) {
                // ID Photo - fixed size container
                Button(action: {
                    selectedPhotoURL = verification.idPhotoURL
                    showingFullPhoto = true
                    HapticManager.shared.impact(.light)
                }) {
                    VStack(spacing: 0) {
                        AsyncImage(url: URL(string: verification.idPhotoURL)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .overlay(ProgressView())
                        }
                        .frame(height: photoHeight)
                        .frame(maxWidth: .infinity)
                        .clipped()

                        Text(verification.idType)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                    }
                }

                // Selfie Photo - fixed size container
                Button(action: {
                    selectedPhotoURL = verification.selfiePhotoURL
                    showingFullPhoto = true
                    HapticManager.shared.impact(.light)
                }) {
                    VStack(spacing: 0) {
                        AsyncImage(url: URL(string: verification.selfiePhotoURL)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .overlay(ProgressView())
                        }
                        .frame(height: photoHeight)
                        .frame(maxWidth: .infinity)
                        .clipped()

                        Text("Selfie")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.purple)
                    }
                }
            }

            // Action buttons
            HStack(spacing: 0) {
                // Approve
                Button(action: onApprove) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Approve")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green)
                }

                // Reject
                Button(action: onReject) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                        Text("Reject")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .fullScreenCover(isPresented: $showingFullPhoto) {
            FullScreenImageView(imageURL: selectedPhotoURL, allImageURLs: allPhotos)
        }
    }
}

// MARK: - Preview

#Preview {
    AdminVerificationReviewView()
}
