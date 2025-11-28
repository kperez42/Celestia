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
            .task {
                await viewModel.loadPendingVerifications()
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

            // Side-by-side photo previews
            HStack(spacing: 12) {
                // ID Photo
                VStack(spacing: 4) {
                    AsyncImage(url: URL(string: verification.idPhotoURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.7)
                            )
                    }
                    .frame(width: 120, height: 80)
                    .cornerRadius(8)
                    .clipped()

                    Text(verification.idType)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Selfie Photo
                VStack(spacing: 4) {
                    AsyncImage(url: URL(string: verification.selfiePhotoURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.7)
                            )
                    }
                    .frame(width: 120, height: 80)
                    .cornerRadius(8)
                    .clipped()

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
            FullScreenImageView(imageURL: url)
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
            Text("Submitted Documents")
                .font(.headline)

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
                        .onTapGesture {
                            selectedImageURL = verification.idPhotoURL
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

                Text("Tap to view full size")
                    .font(.caption2)
                    .foregroundColor(.secondary)
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
                        .onTapGesture {
                            selectedImageURL = verification.selfiePhotoURL
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

                Text("Tap to view full size")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Comparison hint
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Compare the selfie with the ID photo to verify identity")
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

// MARK: - Full Screen Image View

struct FullScreenImageView: View {
    let imageURL: String
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AsyncImage(url: URL(string: imageURL)) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = value
                            }
                            .onEnded { _ in
                                withAnimation {
                                    scale = max(1.0, min(scale, 3.0))
                                }
                            }
                    )
            } placeholder: {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }

            // Close button
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

    // MARK: - Load Pending Verifications

    func loadPendingVerifications() async {
        isLoading = true

        do {
            let snapshot = try await db.collection("pendingVerifications")
                .whereField("status", isEqualTo: "pending")
                .order(by: "submittedAt", descending: false)
                .getDocuments()

            pendingVerifications = snapshot.documents.map { doc in
                PendingVerification(id: doc.documentID, data: doc.data())
            }

            Logger.shared.info("Loaded \(pendingVerifications.count) pending verifications", category: .general)

        } catch {
            Logger.shared.error("Failed to load pending verifications", category: .general, error: error)
            errorMessage = "Failed to load verifications: \(error.localizedDescription)"
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

            // Remove from local list
            pendingVerifications.removeAll { $0.id == verification.id }

            Logger.shared.info("Rejected verification for user: \(verification.userId), reason: \(reason) - photos deleted", category: .general)

        } catch {
            Logger.shared.error("Failed to reject verification", category: .general, error: error)
            errorMessage = "Failed to reject: \(error.localizedDescription)"
            showingError = true
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
        .task {
            await viewModel.loadPendingVerifications()
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

            // Photos - side by side comparison
            HStack(spacing: 2) {
                // ID Photo
                Button(action: {
                    selectedPhotoURL = verification.idPhotoURL
                    showingFullPhoto = true
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
                        .frame(height: 150)
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

                // Selfie Photo
                Button(action: {
                    selectedPhotoURL = verification.selfiePhotoURL
                    showingFullPhoto = true
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
                        .frame(height: 150)
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
            FullScreenImageView(imageURL: selectedPhotoURL)
        }
    }
}

// MARK: - Preview

#Preview {
    AdminVerificationReviewView()
}
