//
//  CameraView.swift
//  Celestia
//
//  Camera view for selfie capture with verification
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    let onPhotoCaptured: (UIImage) -> Void
    let onCancel: () -> Void

    @StateObject private var cameraManager = CameraManager()
    @State private var showingPermissionAlert = false
    @State private var isCapturing = false

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(session: cameraManager.session)
                .ignoresSafeArea()

            // Overlay UI
            VStack {
                // Top bar
                HStack {
                    Button {
                        HapticManager.shared.impact(.light)
                        onCancel()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    .padding()

                    Spacer()
                }

                Spacer()

                // Instructions
                VStack(spacing: 12) {
                    Text("Position your face in the circle")
                        .font(.headline)
                        .foregroundColor(.white)
                        .shadow(radius: 4)

                    Text("Make sure you're well lit and looking at the camera")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .shadow(radius: 4)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)

                // Capture button
                Button {
                    capturePhoto()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 80, height: 80)

                        Circle()
                            .fill(Color.white)
                            .frame(width: 64, height: 64)

                        if isCapturing {
                            ProgressView()
                                .tint(.purple)
                        }
                    }
                }
                .disabled(isCapturing)
                .scaleEffect(isCapturing ? 0.9 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isCapturing)
                .padding(.bottom, 40)
            }

            // Face guide circle
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.purple.opacity(0.6), .pink.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 280, height: 280)
                .shadow(color: .purple.opacity(0.3), radius: 8)
        }
        .background(Color.black)
        .onAppear {
            setupCamera()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .alert("Camera Access Required", isPresented: $showingPermissionAlert) {
            Button("Cancel", role: .cancel) {
                onCancel()
            }
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
        } message: {
            Text("Please allow camera access in Settings to take your verification photo.")
        }
    }

    private func setupCamera() {
        Task {
            let authorized = await cameraManager.requestPermission()
            if authorized {
                await cameraManager.startSession()
            } else {
                showingPermissionAlert = true
            }
        }
    }

    private func capturePhoto() {
        guard !isCapturing else { return }

        isCapturing = true
        HapticManager.shared.impact(.medium)

        Task {
            if let image = await cameraManager.capturePhoto() {
                await MainActor.run {
                    onPhotoCaptured(image)
                }
            }
            isCapturing = false
        }
    }
}

// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        context.coordinator.previewLayer = previewLayer

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Camera Manager

@MainActor
class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var captureCompletion: ((UIImage?) -> Void)?

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startSession() async {
        session.beginConfiguration()
        session.sessionPreset = .photo

        // Add front camera input
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: frontCamera),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)

        // Add photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
        }

        session.commitConfiguration()

        // Start session on background thread
        Task.detached { [weak self] in
            self?.session.startRunning()
        }
    }

    func stopSession() {
        Task.detached { [weak self] in
            self?.session.stopRunning()
        }
    }

    func capturePhoto() async -> UIImage? {
        await withCheckedContinuation { continuation in
            captureCompletion = { image in
                continuation.resume(returning: image)
            }

            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off

            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

// MARK: - Photo Capture Delegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            Task { @MainActor in
                captureCompletion?(nil)
            }
            return
        }

        Task { @MainActor in
            captureCompletion?(image)
        }
    }
}

#Preview {
    CameraView(
        onPhotoCaptured: { image in
            Logger.shared.debug("Photo captured: \(image.size)", category: .ui)
        },
        onCancel: {
            Logger.shared.debug("Cancelled", category: .ui)
        }
    )
}
