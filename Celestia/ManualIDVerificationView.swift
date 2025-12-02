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
    @State private var showingImagePreview = false
    @State private var previewImage: UIImage?

    enum ImageSourceType {
        case id, selfie
    }

    enum IDType: String, CaseIterable {
        case driversLicense = "Driver's License"
        case passport = "Passport"
        case nationalID = "National ID"
        case stateID = "State ID"
        case other = "Other"

        var icon: String {
            switch self {
            case .driversLicense: return "car.fill"
            case .passport: return "globe"
            case .nationalID: return "person.text.rectangle.fill"
            case .stateID: return "building.columns.fill"
            case .other: return "doc.fill"
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.isCheckingStatus {
                    // Loading state while checking verification status
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Checking status...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else if viewModel.isVerified {
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
            .animation(.spring(response: 0.5), value: viewModel.isCheckingStatus)
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
            .alert("Photo Not Accepted", isPresented: $viewModel.showingContentWarning) {
                Button("Choose Different Photo") {
                    HapticManager.shared.impact(.medium)
                }
            } message: {
                Text(viewModel.contentWarningMessage)
            }
            .fullScreenCover(isPresented: $showingImagePreview) {
                if let image = previewImage {
                    IDImagePreviewView(image: image) {
                        showingImagePreview = false
                    }
                }
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

                    // Step 1: ID Type Selection
                    idTypeSelector

                    // Step 2: ID Photo
                    photoUploadCard(
                        step: 2,
                        title: "Government ID Photo",
                        subtitle: viewModel.selectedIDType?.rawValue ?? "Select ID type first",
                        icon: viewModel.selectedIDType?.icon ?? "creditcard.fill",
                        image: viewModel.idImage,
                        isActive: viewModel.selectedIDType != nil,
                        onTap: {
                            imageSourceType = .id
                            showingImageSourcePicker = true
                        },
                        onClear: { viewModel.idImage = nil },
                        onPreview: {
                            if let image = viewModel.idImage {
                                previewImage = image
                                showingImagePreview = true
                            }
                        }
                    )

                    // Step 3: Selfie
                    photoUploadCard(
                        step: 3,
                        title: "Selfie Photo",
                        subtitle: "Clear photo of your face",
                        icon: "person.crop.circle.fill",
                        image: viewModel.selfieImage,
                        isActive: viewModel.idImage != nil,
                        onTap: {
                            imageSourceType = .selfie
                            showingImageSourcePicker = true
                        },
                        onClear: { viewModel.selfieImage = nil },
                        onPreview: {
                            if let image = viewModel.selfieImage {
                                previewImage = image
                                showingImagePreview = true
                            }
                        }
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

    // MARK: - ID Type Selector

    private var idTypeSelector: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                // Step number
                ZStack {
                    Circle()
                        .fill(viewModel.selectedIDType != nil ? Color.green : Color.purple)
                        .frame(width: 28, height: 28)

                    if viewModel.selectedIDType != nil {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    } else {
                        Text("1")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("ID Type")
                        .font(.headline)
                    Text("Select the type of ID you're submitting")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundColor(viewModel.selectedIDType != nil ? .green : .purple)
            }
            .padding()

            // ID Type Options
            VStack(spacing: 8) {
                ForEach(IDType.allCases, id: \.self) { idType in
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        viewModel.selectedIDType = idType
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: idType.icon)
                                .font(.body)
                                .foregroundColor(viewModel.selectedIDType == idType ? .white : .purple)
                                .frame(width: 24)

                            Text(idType.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(viewModel.selectedIDType == idType ? .white : .primary)

                            Spacer()

                            if viewModel.selectedIDType == idType {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(viewModel.selectedIDType == idType ?
                                      LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing) :
                                      LinearGradient(colors: [Color.purple.opacity(0.08), Color.purple.opacity(0.08)], startPoint: .leading, endPoint: .trailing))
                        )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 8) {
            // Step 1 - ID Type
            RoundedRectangle(cornerRadius: 4)
                .fill(viewModel.selectedIDType != nil ? Color.green : Color.gray.opacity(0.3))
                .frame(height: 4)

            // Step 2 - ID Photo
            RoundedRectangle(cornerRadius: 4)
                .fill(viewModel.idImage != nil ? Color.green : Color.gray.opacity(0.3))
                .frame(height: 4)

            // Step 3 - Selfie
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

            Text("Quick 3-step process • Usually approved same day")
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
        onClear: @escaping () -> Void,
        onPreview: @escaping () -> Void
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
                // Show uploaded photo with action buttons
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .clipped()
                        .onTapGesture {
                            HapticManager.shared.impact(.light)
                            onPreview()
                        }

                    // Action buttons row
                    HStack(spacing: 8) {
                        // Replace photo button
                        Button {
                            HapticManager.shared.impact(.light)
                            onTap()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                                .font(.body)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }

                        // Remove button
                        Button(action: onClear) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }
                    }
                    .padding(12)
                }

                // Tap to preview hint
                Text("Tap image to preview full size")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
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

                    if viewModel.isCheckingContent {
                        Text("Checking photos...")
                    } else {
                        Text("Uploading...")
                    }
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
    @Published var selectedIDType: ManualIDVerificationView.IDType?

    @Published var showingIDPicker = false
    @Published var showingSelfiePicker = false
    @Published var showingCamera = false
    var cameraSourceType: ManualIDVerificationView.ImageSourceType = .id

    @Published var isSubmitting = false
    @Published var isCheckingContent = false
    @Published var isCheckingStatus = true  // Start true to prevent flash
    @Published var showingSuccess = false
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published var showingContentWarning = false
    @Published var contentWarningMessage = ""

    @Published var pendingVerification = false
    @Published var isVerified = false
    @Published var wasRejected = false
    @Published var rejectionReason: String?
    @Published var submittedAt: Date?

    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let moderationService = ContentModerationService.shared

    var canSubmit: Bool {
        selectedIDType != nil && idImage != nil && selfieImage != nil && !isSubmitting
    }

    // MARK: - Check Status

    func checkVerificationStatus() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            isCheckingStatus = false
            return
        }

        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            let data = doc.data() ?? [:]

            isVerified = (data["isVerified"] as? Bool ?? false) || (data["idVerified"] as? Bool ?? false)

            // Check for rejection status
            if data["idVerificationRejected"] as? Bool == true {
                wasRejected = true
                rejectionReason = data["idVerificationRejectionReason"] as? String
                isCheckingStatus = false
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
            isCheckingStatus = false
        } catch {
            Logger.shared.error("Failed to check verification status", category: .general, error: error)
            isCheckingStatus = false
        }
    }

    // MARK: - Retry Verification

    func retryVerification() {
        // Clear rejection state and allow user to submit again
        wasRejected = false
        rejectionReason = nil
        selectedIDType = nil
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
              let selfieImage = selfieImage,
              let idType = selectedIDType else {
            errorMessage = "Please complete all steps"
            showingError = true
            return
        }

        isSubmitting = true
        isCheckingContent = true

        do {
            // STEP 1: Pre-check photos for inappropriate content
            Logger.shared.info("Checking photos for appropriate content...", category: .general)

            // Check ID photo
            let idCheckResult = await moderationService.preCheckPhoto(idImage)
            if !idCheckResult.approved {
                isSubmitting = false
                isCheckingContent = false
                contentWarningMessage = idCheckResult.message
                showingContentWarning = true
                HapticManager.shared.notification(.error)
                Logger.shared.warning("ID photo rejected by moderation: \(idCheckResult.message)", category: .general)
                return
            }

            // Check selfie photo
            let selfieCheckResult = await moderationService.preCheckPhoto(selfieImage)
            if !selfieCheckResult.approved {
                isSubmitting = false
                isCheckingContent = false
                contentWarningMessage = selfieCheckResult.message
                showingContentWarning = true
                HapticManager.shared.notification(.error)
                Logger.shared.warning("Selfie photo rejected by moderation: \(selfieCheckResult.message)", category: .general)
                return
            }

            isCheckingContent = false
            Logger.shared.info("Photos passed content check, uploading...", category: .general)

            // STEP 2: Upload photos (they will also be checked server-side automatically)
            let idPhotoURL = try await uploadImage(idImage, path: "verification/\(userId)/id_photo.jpg")
            let selfiePhotoURL = try await uploadImage(selfieImage, path: "verification/\(userId)/selfie.jpg")

            // Get user info for review
            let userDoc = try await db.collection("users").document(userId).getDocument()
            let userData = userDoc.data() ?? [:]

            // Create pending verification record
            try await db.collection("pendingVerifications").document(userId).setData([
                "userId": userId,
                "userName": userData["name"] as? String ?? "Unknown",
                "userEmail": Auth.auth().currentUser?.email ?? "",
                "idType": idType.rawValue,
                "idPhotoURL": idPhotoURL,
                "selfiePhotoURL": selfiePhotoURL,
                "status": "pending",
                "submittedAt": FieldValue.serverTimestamp(),
                "reviewedAt": NSNull(),
                "reviewedBy": NSNull(),
                "notes": "",
                "contentChecked": true
            ])

            isSubmitting = false
            showingSuccess = true
            pendingVerification = true
            HapticManager.shared.notification(.success)

            Logger.shared.info("ID verification submitted for review - ID Type: \(idType.rawValue)", category: .general)

        } catch {
            isSubmitting = false
            isCheckingContent = false
            errorMessage = "Failed to submit: \(error.localizedDescription)"
            showingError = true
            HapticManager.shared.notification(.error)
            Logger.shared.error("Failed to submit verification", category: .general, error: error)
        }
    }

    private func uploadImage(_ image: UIImage, path: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "ImageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
        }

        let ref = storage.reference().child(path)

        // Set metadata with content type - required for storage rules validation
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }
}

// MARK: - ID Image Preview View

struct IDImagePreviewView: View {
    let image: UIImage
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = lastScale * value
                        }
                        .onEnded { _ in
                            lastScale = scale
                            if scale < 1.0 {
                                withAnimation(.spring()) {
                                    scale = 1.0
                                    lastScale = 1.0
                                }
                            }
                        }
                )
                .gesture(
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
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring()) {
                        if scale > 1.0 {
                            scale = 1.0
                            lastScale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2.0
                            lastScale = 2.0
                        }
                    }
                }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        HapticManager.shared.impact(.light)
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()

                // Instructions
                Text("Pinch to zoom • Double-tap to zoom in/out")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ManualIDVerificationView()
}
