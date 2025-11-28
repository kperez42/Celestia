//
//  LiveFaceVerificationView.swift
//  Celestia
//
//  Apple Face ID-style verification UI with real-time face tracking,
//  multi-pose capture, and liveness detection
//

import SwiftUI
import AVFoundation
import Vision

struct LiveFaceVerificationView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var verificationManager = LiveFaceVerificationManager.shared
    @StateObject private var cameraController = LiveCameraController()

    let userId: String
    var onVerificationComplete: ((Bool) -> Void)?

    @State private var showingSuccess = false
    @State private var pulseAnimation = false
    @State private var rotationAngle: Double = 0

    var body: some View {
        ZStack {
            // Camera preview
            LiveCameraPreview(controller: cameraController)
                .ignoresSafeArea()

            // Dark overlay with face cutout
            FaceGuideMask(
                faceDetected: verificationManager.faceDetected,
                faceInPosition: verificationManager.faceInPosition,
                progress: verificationManager.progress
            )
            .ignoresSafeArea()

            // UI Overlay
            VStack {
                // Top bar with close button
                topBar

                Spacer()

                // Central face guide and status
                centralGuide

                Spacer()

                // Bottom instruction panel
                bottomPanel
            }

            // Success overlay
            if case .success = verificationManager.state {
                successOverlay
            }

            // Failure overlay
            if case .failure(let message) = verificationManager.state {
                failureOverlay(message: message)
            }
        }
        .onAppear {
            startVerification()
        }
        .onDisappear {
            cameraController.stopSession()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                HapticManager.shared.impact(.light)
                cameraController.stopSession()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4)
            }
            .padding()

            Spacer()

            // Debug info (can be removed in production)
            if !verificationManager.debugInfo.isEmpty {
                Text(verificationManager.debugInfo)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Central Guide

    private var centralGuide: some View {
        ZStack {
            // Progress ring
            Circle()
                .trim(from: 0, to: verificationManager.progress)
                .stroke(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 300, height: 300)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: verificationManager.progress)

            // Face detection indicator
            if verificationManager.faceDetected && !verificationManager.faceInPosition {
                // Show where the face is detected
                faceBoundingBoxIndicator
            }

            // Pose indicators (around the circle)
            poseIndicators

            // Liveness challenge indicator
            if case .livenessCheck = verificationManager.state {
                livenessIndicator
            }
        }
        .frame(width: 320, height: 320)
    }

    private var faceBoundingBoxIndicator: some View {
        // Visual feedback for face position
        GeometryReader { geo in
            let bbox = verificationManager.faceBoundingBox
            let rect = CGRect(
                x: (1 - bbox.origin.x - bbox.width) * geo.size.width,
                y: (1 - bbox.origin.y - bbox.height) * geo.size.height,
                width: bbox.width * geo.size.width,
                height: bbox.height * geo.size.height
            )

            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.yellow, lineWidth: 2)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        }
    }

    private var poseIndicators: some View {
        ZStack {
            // Center indicator
            PoseCompletionIndicator(
                pose: .center,
                isCompleted: verificationManager.completedPoses.contains(.center),
                isActive: verificationManager.currentPose == .center && verificationManager.state == .capturingPoses
            )
            .offset(y: 0)

            // Left indicator
            PoseCompletionIndicator(
                pose: .left,
                isCompleted: verificationManager.completedPoses.contains(.left),
                isActive: verificationManager.currentPose == .left && verificationManager.state == .capturingPoses
            )
            .offset(x: -130, y: 0)

            // Right indicator
            PoseCompletionIndicator(
                pose: .right,
                isCompleted: verificationManager.completedPoses.contains(.right),
                isActive: verificationManager.currentPose == .right && verificationManager.state == .capturingPoses
            )
            .offset(x: 130, y: 0)
        }
    }

    private var livenessIndicator: some View {
        VStack(spacing: 16) {
            if let challenge = verificationManager.currentChallenge {
                Image(systemName: verificationManager.completedChallenges.contains(challenge) ? challenge.completionIcon : challenge.icon)
                    .font(.system(size: 50))
                    .foregroundColor(.white)
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseAnimation)
                    .onAppear { pulseAnimation = true }
            }
        }
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        VStack(spacing: 16) {
            // Main instruction
            Text(verificationManager.currentInstruction)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.3), radius: 4)
                .animation(.easeInOut(duration: 0.2), value: verificationManager.currentInstruction)

            // State-specific UI
            stateSpecificUI

            // Completed items
            completedItemsBar
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 50)
    }

    @ViewBuilder
    private var stateSpecificUI: some View {
        switch verificationManager.state {
        case .positioning:
            Text("Center your face in the circle")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))

        case .capturingPoses:
            HStack(spacing: 24) {
                ForEach(Array([FacePoseDirection.center, .left, .right]), id: \.self) { pose in
                    VStack(spacing: 4) {
                        Image(systemName: verificationManager.completedPoses.contains(pose) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(verificationManager.completedPoses.contains(pose) ? .green : .white.opacity(0.5))
                        Text(pose == .center ? "Front" : (pose == .left ? "Left" : "Right"))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }

        case .livenessCheck:
            HStack(spacing: 24) {
                ForEach(LivenessChallenge.allCases.prefix(2), id: \.self) { challenge in
                    VStack(spacing: 4) {
                        Image(systemName: verificationManager.completedChallenges.contains(challenge) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(verificationManager.completedChallenges.contains(challenge) ? .green : .white.opacity(0.5))
                        Text(challenge == .blink ? "Blink" : "Smile")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }

        case .processing:
            HStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                Text("Verifying...")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }

        default:
            EmptyView()
        }
    }

    private var completedItemsBar: some View {
        HStack(spacing: 8) {
            // Poses completed
            if !verificationManager.completedPoses.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "faceid")
                        .font(.caption)
                    Text("\(verificationManager.completedPoses.count)/3")
                        .font(.caption)
                }
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.2))
                .cornerRadius(8)
            }

            // Challenges completed
            if !verificationManager.completedChallenges.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield")
                        .font(.caption)
                    Text("\(verificationManager.completedChallenges.count)/2")
                        .font(.caption)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.green.opacity(0.3), .mint.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 160, height: 160)

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 90))
                        .foregroundColor(.green)
                }
                .scaleEffect(showingSuccess ? 1 : 0.5)
                .opacity(showingSuccess ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2), value: showingSuccess)

                VStack(spacing: 12) {
                    Text("Verification Complete!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Your profile is now verified")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .opacity(showingSuccess ? 1 : 0)
                .animation(.easeInOut(duration: 0.3).delay(0.5), value: showingSuccess)

                Spacer()

                Button {
                    HapticManager.shared.impact(.medium)
                    onVerificationComplete?(true)
                    dismiss()
                } label: {
                    Text("Done")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundColor(.white)
                        .background(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .opacity(showingSuccess ? 1 : 0)
                .animation(.easeInOut(duration: 0.3).delay(0.8), value: showingSuccess)
            }
        }
        .onAppear {
            withAnimation {
                showingSuccess = true
            }
        }
    }

    // MARK: - Failure Overlay

    private func failureOverlay(message: String) -> some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 140, height: 140)

                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.red)
                }

                VStack(spacing: 12) {
                    Text("Verification Failed")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        HapticManager.shared.impact(.medium)
                        verificationManager.reset()
                        verificationManager.startVerification(for: userId)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.clockwise")
                            Text("Try Again")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundColor(.white)
                        .background(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                    }

                    Button {
                        onVerificationComplete?(false)
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Methods

    private func startVerification() {
        Task {
            do {
                try await cameraController.startSession { observation, image in
                    Task { @MainActor in
                        if let observation = observation {
                            verificationManager.processFaceObservation(observation, in: image)
                        } else {
                            verificationManager.noFaceDetected()
                        }
                    }
                }
                await MainActor.run {
                    verificationManager.startVerification(for: userId)
                }
            } catch {
                Logger.shared.error("Failed to start camera: \(error.localizedDescription)", category: .general)
            }
        }
    }
}

// MARK: - Face Guide Mask

struct FaceGuideMask: View {
    let faceDetected: Bool
    let faceInPosition: Bool
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dark overlay
                Rectangle()
                    .fill(Color.black.opacity(0.5))

                // Cutout circle for face
                Circle()
                    .fill(Color.black)
                    .frame(width: 280, height: 280)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2 - 30)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()

            // Circle border
            Circle()
                .stroke(
                    faceInPosition ? Color.green :
                        (faceDetected ? Color.yellow : Color.white.opacity(0.5)),
                    lineWidth: 3
                )
                .frame(width: 280, height: 280)
                .position(x: geo.size.width / 2, y: geo.size.height / 2 - 30)
                .animation(.easeInOut(duration: 0.2), value: faceDetected)
                .animation(.easeInOut(duration: 0.2), value: faceInPosition)
        }
    }
}

// MARK: - Pose Completion Indicator

struct PoseCompletionIndicator: View {
    let pose: FacePoseDirection
    let isCompleted: Bool
    let isActive: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isCompleted ? Color.green : (isActive ? Color.purple.opacity(0.5) : Color.white.opacity(0.2)))
                .frame(width: 36, height: 36)

            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Image(systemName: pose.icon)
                    .font(.system(size: 14))
                    .foregroundColor(isActive ? .white : .white.opacity(0.5))
            }
        }
        .scaleEffect(isActive ? 1.2 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isActive)
        .animation(.easeInOut(duration: 0.3), value: isCompleted)
    }
}

// MARK: - Live Camera Controller

class LiveCameraController: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private var videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.celestia.live.camera")
    private let processingQueue = DispatchQueue(label: "com.celestia.face.processing")
    private var frameCallback: ((VNFaceObservation?, UIImage) -> Void)?
    private var lastProcessingTime: Date = Date.distantPast
    private let processingInterval: TimeInterval = 0.05 // 20 FPS for face processing

    func startSession(onFrame: @escaping (VNFaceObservation?, UIImage) -> Void) async throws {
        frameCallback = onFrame

        let authorized = await requestPermission()
        guard authorized else {
            throw CameraError.notAuthorized
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: CameraError.setupFailed)
                    return
                }

                self.session.beginConfiguration()
                self.session.sessionPreset = .high

                // Front camera
                guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                      let input = try? AVCaptureDeviceInput(device: camera),
                      self.session.canAddInput(input) else {
                    self.session.commitConfiguration()
                    continuation.resume(throwing: CameraError.setupFailed)
                    return
                }

                self.session.addInput(input)

                // Video output for real-time processing
                self.videoOutput.setSampleBufferDelegate(self, queue: self.processingQueue)
                self.videoOutput.alwaysDiscardsLateVideoFrames = true
                self.videoOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]

                guard self.session.canAddOutput(self.videoOutput) else {
                    self.session.commitConfiguration()
                    continuation.resume(throwing: CameraError.setupFailed)
                    return
                }

                self.session.addOutput(self.videoOutput)

                // Set video orientation
                if let connection = self.videoOutput.connection(with: .video) {
                    connection.videoRotationAngle = 90
                    connection.isVideoMirrored = true
                }

                self.session.commitConfiguration()
                self.session.startRunning()

                continuation.resume(returning: ())
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    private func requestPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
        default:
            return false
        }
    }

    enum CameraError: Error {
        case notAuthorized
        case setupFailed
    }
}

extension LiveCameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Throttle processing
        let now = Date()
        guard now.timeIntervalSince(lastProcessingTime) >= processingInterval else { return }
        lastProcessingTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Create UIImage from buffer
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let image = UIImage(cgImage: cgImage)

        // Run face detection
        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let results = request.results as? [VNFaceObservation] else {
                self?.frameCallback?(nil, image)
                return
            }

            // Get the largest face
            let largestFace = results.max { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }

            self?.frameCallback?(largestFace, image)
        }

        request.revision = VNDetectFaceLandmarksRequestRevision3

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([request])
        } catch {
            frameCallback?(nil, image)
        }
    }
}

// MARK: - Live Camera Preview

struct LiveCameraPreview: UIViewRepresentable {
    @ObservedObject var controller: LiveCameraController

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: controller.session)
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

// MARK: - Preview

#Preview {
    LiveFaceVerificationView(userId: "test-user-id")
}
