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

// MARK: - Pending Verification Model

struct PendingVerification: Identifiable {
    let id: String
    let userId: String
    let userName: String
    let userEmail: String
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

// MARK: - Verification Row View

struct VerificationRowView: View {
    let verification: PendingVerification

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            AsyncImage(url: URL(string: verification.selfiePhotoURL)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(verification.userName)
                    .font(.headline)

                Text(verification.userEmail)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let date = verification.submittedAt {
                    Text("Submitted \(date.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Status badge
            statusBadge
        }
        .padding(.vertical, 4)
    }

    private var statusBadge: some View {
        Text(verification.status.capitalized)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(8)
    }

    private var statusColor: Color {
        switch verification.status {
        case "pending": return .orange
        case "approved": return .green
        case "rejected": return .red
        default: return .gray
        }
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
                Label("Government ID", systemImage: "creditcard.fill")
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
            // Update user document
            try await db.collection("users").document(verification.userId).updateData([
                "idVerified": true,
                "idVerifiedAt": FieldValue.serverTimestamp(),
                "idVerificationMethod": "manual",
                "verificationMethods": FieldValue.arrayUnion(["manual_id"]),
                "trustScore": FieldValue.increment(Int64(30))
            ])

            // Update pending verification status
            try await db.collection("pendingVerifications").document(verification.id).updateData([
                "status": "approved",
                "reviewedAt": FieldValue.serverTimestamp(),
                "reviewedBy": Auth.auth().currentUser?.uid ?? "admin"
            ])

            // Remove from local list
            pendingVerifications.removeAll { $0.id == verification.id }

            Logger.shared.info("Approved verification for user: \(verification.userId)", category: .general)

        } catch {
            Logger.shared.error("Failed to approve verification", category: .general, error: error)
            errorMessage = "Failed to approve: \(error.localizedDescription)"
            showingError = true
        }
    }

    // MARK: - Reject Verification

    func rejectVerification(_ verification: PendingVerification, reason: String) async {
        do {
            // Update pending verification status
            try await db.collection("pendingVerifications").document(verification.id).updateData([
                "status": "rejected",
                "reviewedAt": FieldValue.serverTimestamp(),
                "reviewedBy": Auth.auth().currentUser?.uid ?? "admin",
                "rejectionReason": reason
            ])

            // Remove from local list
            pendingVerifications.removeAll { $0.id == verification.id }

            Logger.shared.info("Rejected verification for user: \(verification.userId), reason: \(reason)", category: .general)

        } catch {
            Logger.shared.error("Failed to reject verification", category: .general, error: error)
            errorMessage = "Failed to reject: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Embedded View for Dashboard Tab

struct IDVerificationReviewEmbeddedView: View {
    @StateObject private var viewModel = AdminVerificationReviewViewModel()

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
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
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
        .task {
            await viewModel.loadPendingVerifications()
        }
    }
}

// MARK: - Preview

#Preview {
    AdminVerificationReviewView()
}
