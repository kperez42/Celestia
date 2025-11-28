//
//  ManualIDVerificationView.swift
//  Celestia
//
//  Manual ID verification - user submits photos for admin review
//  Clean, smooth step-by-step flow
//

import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

// MARK: - Manual ID Verification View

struct ManualIDVerificationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ManualIDVerificationViewModel()
    @State private var currentStep = 1
    @State private var showingImageSourcePicker = false
    @State private var imageSourceType: ImageSourceType = .id
    @State private var animateProgress = false

    enum ImageSourceType {
        case id, selfie
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.isVerified {
                    verifiedView
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .opacity
                        ))
                } else if viewModel.pendingVerification {
                    pendingView
                        .transition(.opacity)
                } else if viewModel.wasRejected {
                    rejectedView
                        .transition(.opacity)
                } else {
                    mainContent
                }
            }
            .animation(.spring(response: 0.5), value: viewModel.isVerified)
            .animation(.spring(response: 0.5), value: viewModel.pendingVerification)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundColor(.primary)
                    }
                }
            }
            .confirmationDialog("Choose Photo Source", isPresented: $showingImageSourcePicker) {
                Button("Take Photo") {
                    HapticManager.shared.impact(.medium)
                    viewModel.showingCamera = true
                    viewModel.cameraSourceType = imageSourceType
                }
                Button("Choose from Library") {
                    HapticManager.shared.impact(.light)
                    if imageSourceType == .id {
                        viewModel.showingIDPicker = true
                    } else {
                        viewModel.showingSelfiePicker = true
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $viewModel.showingCamera) {
                IDVerificationCameraView(image: viewModel.cameraSourceType == .id ? $viewModel.idImage : $viewModel.selfieImage)
            }
            .photosPicker(isPresented: $viewModel.showingIDPicker, selection: $viewModel.idPhotoItem, matching: .images)
            .photosPicker(isPresented: $viewModel.showingSelfiePicker, selection: $viewModel.selfiePhotoItem, matching: .images)
            .onChange(of: viewModel.idPhotoItem) { _ in
                Task {
                    await viewModel.loadIDPhoto()
                    if viewModel.idImage != nil {
                        HapticManager.shared.notification(.success)
                    }
                }
            }
            .onChange(of: viewModel.selfiePhotoItem) { _ in
                Task {
                    await viewModel.loadSelfiePhoto()
                    if viewModel.selfieImage != nil {
                        HapticManager.shared.notification(.success)
                    }
                }
            }
            .onChange(of: viewModel.idImage) { newValue in
                withAnimation(.spring(response: 0.3)) {
                    animateProgress = newValue != nil
                }
            }
            .onChange(of: viewModel.selfieImage) { newValue in
                withAnimation(.spring(response: 0.3)) {
                    animateProgress = newValue != nil
                }
            }
            .alert("Submitted!", isPresented: $viewModel.showingSuccess) {
                Button("Done") {
                    HapticManager.shared.notification(.success)
                    dismiss()
                }
            } message: {
                Text("Your verification is being reviewed. We'll notify you when approved!")
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

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Progress indicator
            progressBar
                .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Step 1: ID Photo
                    photoUploadCard(
                        step: 1,
                        title: "Government ID",
                        subtitle: "Driver's license, passport, or national ID",
                        icon: "creditcard.fill",
                        image: viewModel.idImage,
                        isActive: currentStep >= 1,
                        onTap: {
                            imageSourceType = .id
                            showingImageSourcePicker = true
                        },
                        onClear: { viewModel.idImage = nil }
                    )

                    // Step 2: Selfie
                    photoUploadCard(
                        step: 2,
                        title: "Selfie Photo",
                        subtitle: "Clear photo of your face",
                        icon: "person.crop.circle.fill",
                        image: viewModel.selfieImage,
                        isActive: currentStep >= 2 || viewModel.idImage != nil,
                        onTap: {
                            imageSourceType = .selfie
                            showingImageSourcePicker = true
                        },
                        onClear: { viewModel.selfieImage = nil }
                    )

                    // Privacy notice
                    privacyNotice

                    // Submit button
                    if viewModel.canSubmit {
                        submitButton
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 8) {
            // Step 1
            RoundedRectangle(cornerRadius: 4)
                .fill(viewModel.idImage != nil ? Color.green : Color.gray.opacity(0.3))
                .frame(height: 4)

            // Step 2
            RoundedRectangle(cornerRadius: 4)
                .fill(viewModel.selfieImage != nil ? Color.green : Color.gray.opacity(0.3))
                .frame(height: 4)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Verify Your Identity")
                .font(.title2)
                .fontWeight(.bold)

            Text("Quick 2-step process • Usually approved same day")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Photo Upload Card

    private func photoUploadCard(
        step: Int,
        title: String,
        subtitle: String,
        icon: String,
        image: UIImage?,
        isActive: Bool,
        onTap: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                // Step number
                ZStack {
                    Circle()
                        .fill(image != nil ? Color.green : (isActive ? Color.purple : Color.gray.opacity(0.3)))
                        .frame(width: 28, height: 28)

                    if image != nil {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    } else {
                        Text("\(step)")
                            .font(.caption.bold())
                            .foregroundColor(isActive ? .white : .gray)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(image != nil ? .green : .purple)
            }
            .padding()

            // Photo area
            if let image = image {
                // Show uploaded photo
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .clipped()

                    // Remove button
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    .padding(12)
                }
                .onTapGesture(perform: onTap)
            } else if isActive {
                // Upload button
                Button(action: onTap) {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.purple)

                        Text("Tap to add photo")
                            .font(.subheadline)
                            .foregroundColor(.purple)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .background(Color.purple.opacity(0.08))
                }
            } else {
                // Inactive state
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)

                    Text("Complete step \(step - 1) first")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .background(Color.gray.opacity(0.1))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Privacy Notice

    private var privacyNotice: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash.circle.fill")
                .font(.title2)
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 4) {
                Text("Photos Auto-Deleted")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("Your photos are deleted immediately after review. We only store your verified status.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button(action: {
            Task { await viewModel.submitVerification() }
        }) {
            HStack(spacing: 10) {
                if viewModel.isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "paperplane.fill")
                    Text("Submit for Review")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [.purple, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
            .shadow(color: .purple.opacity(0.3), radius: 8, y: 4)
        }
        .disabled(viewModel.isSubmitting)
        .scaleEffect(viewModel.isSubmitting ? 0.98 : 1.0)
        .animation(.spring(response: 0.3), value: viewModel.isSubmitting)
    }

    // MARK: - Verified View

    private var verifiedView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("You're Verified!")
                .font(.title)
                .fontWeight(.bold)

            Text("Your identity has been verified.\nYou now have the verified badge!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button("Done") {
                dismiss()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.green)
            .cornerRadius(14)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Pending View

    private var pendingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "clock.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
            }

            Text("Under Review")
                .font(.title)
                .fontWeight(.bold)

            Text("Your verification is being reviewed.\nThis usually takes less than 24 hours.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let date = viewModel.submittedAt {
                Text("Submitted \(date.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }

            Spacer()

            Button("Close") {
                dismiss()
            }
            .font(.headline)
            .foregroundColor(.orange)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.orange.opacity(0.15))
            .cornerRadius(14)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Rejected View (with retry option)

    private var rejectedView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.red)
            }

            Text("Verification Rejected")
                .font(.title)
                .fontWeight(.bold)

            if let reason = viewModel.rejectionReason {
                VStack(spacing: 8) {
                    Text("Reason:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(reason)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
            }

            Text("Please try again with clearer photos.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            VStack(spacing: 12) {
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    viewModel.retryVerification()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                }

                Button("Cancel") {
                    dismiss()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - ID Verification Camera View

struct IDVerificationCameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: IDVerificationCameraView

        init(_ parent: IDVerificationCameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let edited = info[.editedImage] as? UIImage {
                parent.image = edited
            } else if let original = info[.originalImage] as? UIImage {
                parent.image = original
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
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

    @Published var showingIDPicker = false
    @Published var showingSelfiePicker = false
    @Published var showingCamera = false
    var cameraSourceType: ManualIDVerificationView.ImageSourceType = .id

    @Published var isSubmitting = false
    @Published var showingSuccess = false
    @Published var showingError = false
    @Published var errorMessage = ""

    @Published var pendingVerification = false
    @Published var isVerified = false
    @Published var wasRejected = false
    @Published var rejectionReason: String?
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

            isVerified = (data["isVerified"] as? Bool ?? false) || (data["idVerified"] as? Bool ?? false)

            // Check for rejection status
            if data["idVerificationRejected"] as? Bool == true {
                wasRejected = true
                rejectionReason = data["idVerificationRejectionReason"] as? String
                return  // Don't check pending if already rejected
            }

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

    // MARK: - Retry Verification

    func retryVerification() {
        // Clear rejection state and allow user to submit again
        wasRejected = false
        rejectionReason = nil
        idImage = nil
        selfieImage = nil
        idPhotoItem = nil
        selfiePhotoItem = nil

        // Clear rejection flags from user document
        guard let userId = Auth.auth().currentUser?.uid else { return }
        Task {
            do {
                try await db.collection("users").document(userId).updateData([
                    "idVerificationRejected": FieldValue.delete(),
                    "idVerificationRejectedAt": FieldValue.delete(),
                    "idVerificationRejectionReason": FieldValue.delete()
                ])
                Logger.shared.info("Cleared rejection status for retry", category: .general)
            } catch {
                Logger.shared.error("Failed to clear rejection status", category: .general, error: error)
            }
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
