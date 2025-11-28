//
//  ManualIDVerificationView.swift
//  Celestia
//
//  Manual ID verification - user submits photos for admin review
//  Simple alternative to Stripe Identity for small apps
//

import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

// MARK: - Manual ID Verification View (User Submission)

struct ManualIDVerificationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ManualIDVerificationViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Status check
                    if viewModel.pendingVerification {
                        pendingStatusSection
                    } else if viewModel.isVerified {
                        verifiedStatusSection
                    } else {
                        // Photo upload sections
                        idPhotoSection
                        selfiePhotoSection

                        // Submit button
                        submitButton
                    }

                    // Instructions
                    instructionsSection
                }
                .padding()
            }
            .navigationTitle("ID Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Verification Submitted", isPresented: $viewModel.showingSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your ID verification is pending review. You'll be notified once approved.")
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .task {
                await viewModel.checkVerificationStatus()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.text.rectangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.purple)

            Text("Verify Your Identity")
                .font(.title2)
                .fontWeight(.bold)

            Text("Upload a photo of your ID and a selfie for manual review")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Pending Status

    private var pendingStatusSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Verification Pending")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Your verification is being reviewed. This usually takes 24-48 hours.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let submittedAt = viewModel.submittedAt {
                Text("Submitted: \(submittedAt.formatted())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Verified Status

    private var verifiedStatusSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)

            Text("You're Verified!")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.green)

            Text("Your identity has been verified. You have a verified badge on your profile.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - ID Photo Section

    private var idPhotoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Government ID", systemImage: "creditcard.fill")
                .font(.headline)

            PhotosPicker(selection: $viewModel.idPhotoItem, matching: .images) {
                if let idImage = viewModel.idImage {
                    Image(uiImage: idImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .clipped()
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green, lineWidth: 2)
                        )
                } else {
                    photoPlaceholder(
                        icon: "creditcard",
                        text: "Tap to upload ID photo"
                    )
                }
            }
            .onChange(of: viewModel.idPhotoItem) { _ in
                Task { await viewModel.loadIDPhoto() }
            }

            Text("Driver's license, passport, or national ID")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Selfie Section

    private var selfiePhotoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Selfie Photo", systemImage: "person.crop.circle.fill")
                .font(.headline)

            PhotosPicker(selection: $viewModel.selfiePhotoItem, matching: .images) {
                if let selfieImage = viewModel.selfieImage {
                    Image(uiImage: selfieImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .clipped()
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green, lineWidth: 2)
                        )
                } else {
                    photoPlaceholder(
                        icon: "person.crop.circle",
                        text: "Tap to upload selfie"
                    )
                }
            }
            .onChange(of: viewModel.selfiePhotoItem) { _ in
                Task { await viewModel.loadSelfiePhoto() }
            }

            Text("Clear photo of your face matching the ID")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func photoPlaceholder(icon: String, text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [8]))
                .foregroundColor(.gray.opacity(0.5))
        )
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button(action: {
            Task { await viewModel.submitVerification() }
        }) {
            HStack {
                if viewModel.isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "paperplane.fill")
                    Text("Submit for Review")
                }
            }
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.canSubmit ? Color.purple : Color.gray)
            .cornerRadius(12)
        }
        .disabled(!viewModel.canSubmit || viewModel.isSubmitting)
    }

    // MARK: - Instructions

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Requirements")
                .font(.headline)

            instructionRow(icon: "doc.text.fill", text: "ID must be valid and not expired")
            instructionRow(icon: "eye.fill", text: "All text must be clearly readable")
            instructionRow(icon: "person.fill", text: "Selfie must clearly show your face")
            instructionRow(icon: "light.max", text: "Good lighting, no glare")

            Divider()

            HStack {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.green)
                Text("Your photos are stored securely and only used for verification.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func instructionRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - View Model

@MainActor
class ManualIDVerificationViewModel: ObservableObject {
    @Published var idPhotoItem: PhotosPickerItem?
    @Published var selfiePhotoItem: PhotosPickerItem?
    @Published var idImage: UIImage?
    @Published var selfieImage: UIImage?

    @Published var isSubmitting = false
    @Published var showingSuccess = false
    @Published var showingError = false
    @Published var errorMessage = ""

    @Published var pendingVerification = false
    @Published var isVerified = false
    @Published var submittedAt: Date?

    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    var canSubmit: Bool {
        idImage != nil && selfieImage != nil && !isSubmitting
    }

    // MARK: - Check Status

    func checkVerificationStatus() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            let data = doc.data() ?? [:]

            isVerified = data["idVerified"] as? Bool ?? false

            // Check for pending verification
            let verificationDoc = try await db.collection("pendingVerifications").document(userId).getDocument()
            if verificationDoc.exists {
                let verificationData = verificationDoc.data() ?? [:]
                let status = verificationData["status"] as? String ?? ""
                pendingVerification = (status == "pending")
                if let timestamp = verificationData["submittedAt"] as? Timestamp {
                    submittedAt = timestamp.dateValue()
                }
            }
        } catch {
            Logger.shared.error("Failed to check verification status", category: .general, error: error)
        }
    }

    // MARK: - Load Photos

    func loadIDPhoto() async {
        guard let item = idPhotoItem else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                idImage = image
            }
        } catch {
            Logger.shared.error("Failed to load ID photo", category: .general, error: error)
        }
    }

    func loadSelfiePhoto() async {
        guard let item = selfiePhotoItem else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                selfieImage = image
            }
        } catch {
            Logger.shared.error("Failed to load selfie photo", category: .general, error: error)
        }
    }

    // MARK: - Submit

    func submitVerification() async {
        guard let userId = Auth.auth().currentUser?.uid,
              let idImage = idImage,
              let selfieImage = selfieImage else {
            errorMessage = "Please upload both photos"
            showingError = true
            return
        }

        isSubmitting = true

        do {
            // Upload ID photo
            let idPhotoURL = try await uploadImage(idImage, path: "verification/\(userId)/id_photo.jpg")

            // Upload selfie photo
            let selfiePhotoURL = try await uploadImage(selfieImage, path: "verification/\(userId)/selfie.jpg")

            // Get user info for review
            let userDoc = try await db.collection("users").document(userId).getDocument()
            let userData = userDoc.data() ?? [:]

            // Create pending verification record
            try await db.collection("pendingVerifications").document(userId).setData([
                "userId": userId,
                "userName": userData["name"] as? String ?? "Unknown",
                "userEmail": Auth.auth().currentUser?.email ?? "",
                "idPhotoURL": idPhotoURL,
                "selfiePhotoURL": selfiePhotoURL,
                "status": "pending",
                "submittedAt": FieldValue.serverTimestamp(),
                "reviewedAt": NSNull(),
                "reviewedBy": NSNull(),
                "notes": ""
            ])

            isSubmitting = false
            showingSuccess = true
            pendingVerification = true

            Logger.shared.info("ID verification submitted for review", category: .general)

        } catch {
            isSubmitting = false
            errorMessage = "Failed to submit: \(error.localizedDescription)"
            showingError = true
            Logger.shared.error("Failed to submit verification", category: .general, error: error)
        }
    }

    private func uploadImage(_ image: UIImage, path: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "ImageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
        }

        let ref = storage.reference().child(path)
        _ = try await ref.putDataAsync(imageData)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }
}

// MARK: - Preview

#Preview {
    ManualIDVerificationView()
}
