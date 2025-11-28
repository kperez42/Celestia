//
//  LiveFaceVerification.swift
//  Celestia
//
//  Advanced face verification with real-time tracking and liveness detection
//  Similar to Apple's Face ID enrollment - requires head movement for verification
//

import Foundation
import UIKit
import Vision
import AVFoundation
import FirebaseFirestore

// MARK: - Face Pose Direction

enum FacePoseDirection: String, CaseIterable {
    case center = "Look straight ahead"
    case left = "Turn your head left"
    case right = "Turn your head right"
    case up = "Tilt your head up slightly"
    case down = "Tilt your head down slightly"

    var icon: String {
        switch self {
        case .center: return "face.smiling"
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        }
    }

    var yawRange: ClosedRange<Float> {
        switch self {
        case .center: return -0.15...0.15
        case .left: return -0.6...(-0.25)
        case .right: return 0.25...0.6
        case .up, .down: return -0.25...0.25
        }
    }

    var pitchRange: ClosedRange<Float> {
        switch self {
        case .center: return -0.15...0.15
        case .left, .right: return -0.25...0.25
        case .up: return 0.2...0.5
        case .down: return -0.5...(-0.2)
        }
    }
}

// MARK: - Liveness Challenge

enum LivenessChallenge: String, CaseIterable {
    case blink = "Blink your eyes"
    case smile = "Smile naturally"
    case turnLeft = "Turn head slowly left"
    case turnRight = "Turn head slowly right"

    var icon: String {
        switch self {
        case .blink: return "eye"
        case .smile: return "face.smiling"
        case .turnLeft: return "arrow.left.circle"
        case .turnRight: return "arrow.right.circle"
        }
    }

    var completionIcon: String {
        switch self {
        case .blink: return "eye.fill"
        case .smile: return "face.smiling.fill"
        case .turnLeft: return "arrow.left.circle.fill"
        case .turnRight: return "arrow.right.circle.fill"
        }
    }
}

// MARK: - Verification Session State

enum LiveVerificationState: Equatable {
    case initializing
    case positioning      // Getting face in frame
    case capturingPoses   // Multi-angle capture
    case livenessCheck    // Liveness challenges
    case processing       // Comparing with profile
    case success
    case failure(String)

    static func == (lhs: LiveVerificationState, rhs: LiveVerificationState) -> Bool {
        switch (lhs, rhs) {
        case (.initializing, .initializing),
             (.positioning, .positioning),
             (.capturingPoses, .capturingPoses),
             (.livenessCheck, .livenessCheck),
             (.processing, .processing),
             (.success, .success):
            return true
        case (.failure(let lhsMessage), .failure(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

// MARK: - Face Capture Data

struct FaceCaptureData {
    let image: UIImage
    let pose: FacePoseDirection
    let observation: VNFaceObservation
    let signature: [Float]
    let timestamp: Date
}

// MARK: - Live Face Verification Manager

@MainActor
class LiveFaceVerificationManager: NSObject, ObservableObject {
    static let shared = LiveFaceVerificationManager()

    // Published state
    @Published var state: LiveVerificationState = .initializing
    @Published var currentInstruction: String = "Position your face in the circle"
    @Published var progress: Double = 0.0
    @Published var faceDetected: Bool = false
    @Published var faceInPosition: Bool = false
    @Published var currentPose: FacePoseDirection = .center
    @Published var completedPoses: Set<FacePoseDirection> = []
    @Published var currentChallenge: LivenessChallenge?
    @Published var completedChallenges: Set<LivenessChallenge> = []
    @Published var faceQualityScore: Float = 0.0
    @Published var debugInfo: String = ""

    // Face tracking data
    @Published var faceBoundingBox: CGRect = .zero
    @Published var faceYaw: Float = 0.0
    @Published var facePitch: Float = 0.0
    @Published var faceRoll: Float = 0.0

    // Liveness detection
    @Published var leftEyeOpen: Bool = true
    @Published var rightEyeOpen: Bool = true
    @Published var smileDetected: Bool = false

    // Captured data
    private var capturedFaces: [FaceCaptureData] = []
    private var livenessFrameCount: Int = 0
    private var blinkDetectedCount: Int = 0
    private var smileDetectedCount: Int = 0
    private var eyeClosedFrames: Int = 0
    private var lastEyeState: Bool = true

    // Configuration
    private let requiredPoses: [FacePoseDirection] = [.center, .left, .right]
    private let requiredChallenges: [LivenessChallenge] = [.blink, .smile]
    private let minCapturesPerPose: Int = 3
    private let matchThreshold: Float = 0.70

    // Session management
    private var verificationStartTime: Date?
    private var userId: String = ""

    private override init() {
        super.init()
    }

    // MARK: - Public Methods

    func startVerification(for userId: String) {
        self.userId = userId
        self.verificationStartTime = Date()

        reset()
        state = .positioning
        currentInstruction = "Position your face in the circle"

        Logger.shared.info("Starting live face verification for user: \(userId)", category: .general)
    }

    func reset() {
        state = .initializing
        progress = 0.0
        faceDetected = false
        faceInPosition = false
        currentPose = .center
        completedPoses = []
        currentChallenge = nil
        completedChallenges = []
        capturedFaces = []
        faceQualityScore = 0.0
        livenessFrameCount = 0
        blinkDetectedCount = 0
        smileDetectedCount = 0
        eyeClosedFrames = 0
        lastEyeState = true
        debugInfo = ""
    }

    // MARK: - Face Processing (called from video frames)

    func processFaceObservation(_ observation: VNFaceObservation, in image: UIImage) {
        guard state != .success && state != .processing else { return }

        faceDetected = true
        faceBoundingBox = observation.boundingBox

        // Extract face angles
        if let yaw = observation.yaw?.floatValue {
            faceYaw = yaw
        }
        if let pitch = observation.pitch?.floatValue {
            facePitch = pitch
        }
        if let roll = observation.roll?.floatValue {
            faceRoll = roll
        }

        // Check face quality
        if #available(iOS 15.0, *) {
            faceQualityScore = observation.faceCaptureQuality ?? 0.0
        }

        // Process landmarks for liveness
        if let landmarks = observation.landmarks {
            processLandmarks(landmarks)
        }

        // Update debug info
        debugInfo = String(format: "Yaw: %.2f, Pitch: %.2f, Roll: %.2f", faceYaw, facePitch, faceRoll)

        // Process based on current state
        switch state {
        case .positioning:
            handlePositioningState(observation, image: image)
        case .capturingPoses:
            handleCapturingState(observation, image: image)
        case .livenessCheck:
            handleLivenessState(observation, image: image)
        default:
            break
        }
    }

    func noFaceDetected() {
        faceDetected = false
        faceInPosition = false

        if state == .positioning || state == .capturingPoses {
            currentInstruction = "Position your face in the circle"
        }
    }

    // MARK: - State Handlers

    private func handlePositioningState(_ observation: VNFaceObservation, image: UIImage) {
        // Check if face is properly positioned (centered and correct size)
        let isProperlyPositioned = checkFacePosition(observation)
        faceInPosition = isProperlyPositioned

        if isProperlyPositioned {
            // Face is in position, move to capturing
            HapticManager.shared.impact(.light)
            state = .capturingPoses
            currentPose = .center
            currentInstruction = "Hold still - \(currentPose.rawValue)"
            progress = 0.1

            Logger.shared.debug("Face positioned, starting capture", category: .general)
        } else {
            currentInstruction = getFacePositioningInstruction(observation)
        }
    }

    private func handleCapturingState(_ observation: VNFaceObservation, image: UIImage) {
        // Check if current pose matches required pose
        let poseMatches = checkPoseMatch(observation, targetPose: currentPose)

        if poseMatches {
            // Capture this frame
            if let signature = generateFaceSignature(observation) {
                let capture = FaceCaptureData(
                    image: image,
                    pose: currentPose,
                    observation: observation,
                    signature: signature,
                    timestamp: Date()
                )
                capturedFaces.append(capture)

                let capturesForPose = capturedFaces.filter { $0.pose == currentPose }.count

                if capturesForPose >= minCapturesPerPose {
                    // Pose captured successfully
                    completedPoses.insert(currentPose)
                    HapticManager.shared.notification(.success)

                    // Move to next pose or liveness check
                    if let nextPose = getNextPose() {
                        currentPose = nextPose
                        currentInstruction = nextPose.rawValue
                        progress = Double(completedPoses.count) / Double(requiredPoses.count) * 0.5
                    } else {
                        // All poses captured, start liveness check
                        startLivenessCheck()
                    }
                } else {
                    currentInstruction = "Hold still... \(capturesForPose)/\(minCapturesPerPose)"
                }
            }
        } else {
            currentInstruction = currentPose.rawValue
        }
    }

    private func handleLivenessState(_ observation: VNFaceObservation, image: UIImage) {
        guard let challenge = currentChallenge else {
            advanceToNextChallenge()
            return
        }

        livenessFrameCount += 1

        switch challenge {
        case .blink:
            checkBlinkChallenge()
        case .smile:
            checkSmileChallenge()
        case .turnLeft:
            checkTurnChallenge(targetYaw: -0.35)
        case .turnRight:
            checkTurnChallenge(targetYaw: 0.35)
        }
    }

    // MARK: - Liveness Detection

    private func processLandmarks(_ landmarks: VNFaceLandmarks2D) {
        // Check eye openness
        if let leftEye = landmarks.leftEye, let rightEye = landmarks.rightEye {
            let leftOpen = isEyeOpen(leftEye.normalizedPoints)
            let rightOpen = isEyeOpen(rightEye.normalizedPoints)

            leftEyeOpen = leftOpen
            rightEyeOpen = rightOpen

            // Track blink (both eyes closed then open)
            let eyesClosed = !leftOpen && !rightOpen
            if eyesClosed && lastEyeState {
                eyeClosedFrames += 1
            } else if !eyesClosed && eyeClosedFrames > 2 && eyeClosedFrames < 15 {
                // Valid blink detected (closed for 2-15 frames)
                blinkDetectedCount += 1
                Logger.shared.debug("Blink detected! Count: \(blinkDetectedCount)", category: .general)
            }

            if !eyesClosed {
                eyeClosedFrames = 0
            }

            lastEyeState = !eyesClosed
        }

        // Check smile
        if let outerLips = landmarks.outerLips, let innerLips = landmarks.innerLips {
            let isSmiling = detectSmile(outerLips: outerLips.normalizedPoints, innerLips: innerLips.normalizedPoints)
            smileDetected = isSmiling

            if isSmiling {
                smileDetectedCount += 1
            }
        }
    }

    private func isEyeOpen(_ eyePoints: [CGPoint]) -> Bool {
        guard eyePoints.count >= 6 else { return true }

        // Calculate eye aspect ratio (EAR)
        let eyeHeight = abs(eyePoints[1].y - eyePoints[5].y) + abs(eyePoints[2].y - eyePoints[4].y)
        let eyeWidth = abs(eyePoints[3].x - eyePoints[0].x)

        guard eyeWidth > 0 else { return true }

        let ear = eyeHeight / (2.0 * eyeWidth)

        // Eye is considered open if EAR > 0.2
        return ear > 0.18
    }

    private func detectSmile(outerLips: [CGPoint], innerLips: [CGPoint]) -> Bool {
        guard outerLips.count >= 6 else { return false }

        // Calculate mouth aspect ratio
        let mouthWidth = abs(outerLips[0].x - outerLips[6].x)
        let mouthHeight = abs(outerLips[3].y - outerLips[9].y)

        guard mouthHeight > 0 else { return false }

        let aspectRatio = mouthWidth / mouthHeight

        // Smiling typically has higher width-to-height ratio
        return aspectRatio > 3.0
    }

    private func startLivenessCheck() {
        state = .livenessCheck
        livenessFrameCount = 0
        blinkDetectedCount = 0
        smileDetectedCount = 0
        progress = 0.5
        advanceToNextChallenge()

        Logger.shared.debug("Starting liveness check", category: .general)
    }

    private func advanceToNextChallenge() {
        if let nextChallenge = requiredChallenges.first(where: { !completedChallenges.contains($0) }) {
            currentChallenge = nextChallenge
            currentInstruction = nextChallenge.rawValue
            livenessFrameCount = 0

            // Reset counters for new challenge
            if nextChallenge == .blink {
                blinkDetectedCount = 0
                eyeClosedFrames = 0
            } else if nextChallenge == .smile {
                smileDetectedCount = 0
            }
        } else {
            // All challenges completed
            completeVerification()
        }
    }

    private func checkBlinkChallenge() {
        if blinkDetectedCount >= 2 {
            completedChallenges.insert(.blink)
            HapticManager.shared.notification(.success)
            currentInstruction = "Great!"

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.advanceToNextChallenge()
            }

            progress = 0.5 + Double(completedChallenges.count) / Double(requiredChallenges.count) * 0.3
        } else if livenessFrameCount > 150 {
            // Timeout - ask again
            currentInstruction = "Please blink your eyes twice"
            livenessFrameCount = 0
        }
    }

    private func checkSmileChallenge() {
        if smileDetectedCount >= 10 {
            completedChallenges.insert(.smile)
            HapticManager.shared.notification(.success)
            currentInstruction = "Perfect!"

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.advanceToNextChallenge()
            }

            progress = 0.5 + Double(completedChallenges.count) / Double(requiredChallenges.count) * 0.3
        } else if livenessFrameCount > 150 {
            currentInstruction = "Give us a natural smile"
            livenessFrameCount = 0
            smileDetectedCount = 0
        }
    }

    private func checkTurnChallenge(targetYaw: Float) {
        let tolerance: Float = 0.15

        if abs(faceYaw - targetYaw) < tolerance {
            if targetYaw < 0 {
                completedChallenges.insert(.turnLeft)
            } else {
                completedChallenges.insert(.turnRight)
            }

            HapticManager.shared.notification(.success)
            advanceToNextChallenge()
            progress = 0.5 + Double(completedChallenges.count) / Double(requiredChallenges.count) * 0.3
        }
    }

    // MARK: - Verification Completion

    private func completeVerification() {
        state = .processing
        currentInstruction = "Verifying your identity..."
        progress = 0.85

        Task {
            do {
                let result = try await performFaceMatching()

                await MainActor.run {
                    if result.success {
                        state = .success
                        progress = 1.0
                        currentInstruction = "Verification complete!"
                        HapticManager.shared.notification(.success)
                    } else {
                        state = .failure(result.message)
                        currentInstruction = result.message
                        HapticManager.shared.notification(.error)
                    }
                }
            } catch {
                await MainActor.run {
                    state = .failure(error.localizedDescription)
                    currentInstruction = "Verification failed. Please try again."
                    HapticManager.shared.notification(.error)
                }
            }
        }
    }

    private func performFaceMatching() async throws -> (success: Bool, message: String, confidence: Double) {
        guard !capturedFaces.isEmpty else {
            return (false, "No face captures available", 0)
        }

        // Get profile photos
        let profilePhotos = try await fetchProfilePhotos(userId: userId)

        guard !profilePhotos.isEmpty else {
            return (false, "No profile photos found. Please add photos first.", 0)
        }

        // Calculate average signature from captured poses
        let centerCaptures = capturedFaces.filter { $0.pose == .center }
        guard !centerCaptures.isEmpty else {
            return (false, "Center face capture required", 0)
        }

        // Use the best quality center capture
        let bestCapture = centerCaptures.max { c1, c2 in
            let q1 = c1.observation.faceCaptureQuality ?? 0
            let q2 = c2.observation.faceCaptureQuality ?? 0
            return q1 < q2
        }!

        let selfieSignature = bestCapture.signature

        // Compare with each profile photo
        var bestMatch: Float = 0.0

        for photoURL in profilePhotos {
            if let profileImage = await downloadImage(from: photoURL),
               let profileSignature = await extractFaceSignature(from: profileImage) {
                let similarity = calculateCosineSimilarity(selfieSignature, profileSignature)
                Logger.shared.debug("Profile photo similarity: \(similarity)", category: .general)

                if similarity > bestMatch {
                    bestMatch = similarity
                }
            }
        }

        let confidence = Double(bestMatch)

        if bestMatch >= matchThreshold {
            // Update verification status
            try await updateUserVerification(userId: userId, confidence: confidence)
            return (true, "Face verified successfully!", confidence)
        } else {
            return (false, "Face doesn't match your profile photos.", confidence)
        }
    }

    // MARK: - Helper Methods

    private func checkFacePosition(_ observation: VNFaceObservation) -> Bool {
        // Face should be:
        // 1. Large enough (at least 20% of frame)
        // 2. Centered (within middle 60% of frame)
        // 3. Front-facing (low yaw and roll)

        let faceArea = observation.boundingBox.width * observation.boundingBox.height
        let centerX = observation.boundingBox.midX
        let centerY = observation.boundingBox.midY

        let isBigEnough = faceArea >= 0.15
        let isCentered = centerX > 0.2 && centerX < 0.8 && centerY > 0.2 && centerY < 0.8
        let isFrontFacing = abs(faceYaw) < 0.2 && abs(faceRoll) < 0.2

        return isBigEnough && isCentered && isFrontFacing
    }

    private func getFacePositioningInstruction(_ observation: VNFaceObservation) -> String {
        let faceArea = observation.boundingBox.width * observation.boundingBox.height
        let centerX = observation.boundingBox.midX

        if faceArea < 0.15 {
            return "Move closer to the camera"
        } else if faceArea > 0.5 {
            return "Move back from the camera"
        } else if centerX < 0.3 {
            return "Move your face to the right"
        } else if centerX > 0.7 {
            return "Move your face to the left"
        } else if abs(faceYaw) > 0.2 {
            return "Face the camera directly"
        }

        return "Position your face in the circle"
    }

    private func checkPoseMatch(_ observation: VNFaceObservation, targetPose: FacePoseDirection) -> Bool {
        let yawInRange = targetPose.yawRange.contains(faceYaw)
        let pitchInRange = targetPose.pitchRange.contains(facePitch)
        let rollOK = abs(faceRoll) < 0.3

        // Also check face quality
        var qualityOK = true
        if #available(iOS 15.0, *) {
            qualityOK = (observation.faceCaptureQuality ?? 0) >= 0.3
        }

        return yawInRange && pitchInRange && rollOK && qualityOK
    }

    private func getNextPose() -> FacePoseDirection? {
        return requiredPoses.first { !completedPoses.contains($0) }
    }

    private func generateFaceSignature(_ observation: VNFaceObservation) -> [Float]? {
        guard let landmarks = observation.landmarks else { return nil }

        var signature: [Float] = []

        // Get key landmark points
        guard let leftEyePoints = landmarks.leftEye?.normalizedPoints,
              let rightEyePoints = landmarks.rightEye?.normalizedPoints,
              let nosePoints = landmarks.nose?.normalizedPoints,
              let outerLipsPoints = landmarks.outerLips?.normalizedPoints,
              let faceContourPoints = landmarks.faceContour?.normalizedPoints else {
            return nil
        }

        // Calculate center points
        let leftEyeCenter = centerPoint(of: leftEyePoints)
        let rightEyeCenter = centerPoint(of: rightEyePoints)
        let noseCenter = centerPoint(of: nosePoints)
        let mouthCenter = centerPoint(of: outerLipsPoints)

        // Reference distance: inter-pupillary distance
        let ipd = distance(from: leftEyeCenter, to: rightEyeCenter)
        guard ipd > 0.01 else { return nil }

        // Face dimensions
        let faceWidth = faceContourPoints.map { Float($0.x) }.max()! - faceContourPoints.map { Float($0.x) }.min()!
        let faceHeight = faceContourPoints.map { Float($0.y) }.max()! - faceContourPoints.map { Float($0.y) }.min()!

        // === GEOMETRIC RATIOS ===
        signature.append(ipd / faceWidth)

        let eyeMidpoint = CGPoint(
            x: (leftEyeCenter.x + rightEyeCenter.x) / 2,
            y: (leftEyeCenter.y + rightEyeCenter.y) / 2
        )

        signature.append(distance(from: eyeMidpoint, to: noseCenter) / ipd)
        signature.append(distance(from: noseCenter, to: mouthCenter) / ipd)
        signature.append(distance(from: eyeMidpoint, to: mouthCenter) / ipd)
        signature.append(faceHeight / faceWidth)
        signature.append(distance(from: leftEyeCenter, to: noseCenter) / ipd)
        signature.append(distance(from: rightEyeCenter, to: noseCenter) / ipd)

        // Mouth width ratio
        let mouthWidth = outerLipsPoints.map { Float($0.x) }.max()! - outerLipsPoints.map { Float($0.x) }.min()!
        signature.append(mouthWidth / ipd)

        // Nose width ratio
        let noseWidth = nosePoints.map { Float($0.x) }.max()! - nosePoints.map { Float($0.x) }.min()!
        signature.append(noseWidth / ipd)

        // Eye symmetry
        signature.append(abs(Float(leftEyeCenter.y - rightEyeCenter.y)) / ipd)

        // === ANGULAR FEATURES ===
        signature.append(atan2(Float(rightEyeCenter.y - leftEyeCenter.y), Float(rightEyeCenter.x - leftEyeCenter.x)))
        signature.append(atan2(Float(noseCenter.y - eyeMidpoint.y), Float(noseCenter.x - eyeMidpoint.x)))
        signature.append(atan2(Float(mouthCenter.y - noseCenter.y), Float(mouthCenter.x - noseCenter.x)))

        // === SHAPE FEATURES ===
        let leftEyeWidth = leftEyePoints.map { Float($0.x) }.max()! - leftEyePoints.map { Float($0.x) }.min()!
        let leftEyeHeight = leftEyePoints.map { Float($0.y) }.max()! - leftEyePoints.map { Float($0.y) }.min()!
        signature.append(leftEyeHeight / max(leftEyeWidth, 0.001))

        let rightEyeWidth = rightEyePoints.map { Float($0.x) }.max()! - rightEyePoints.map { Float($0.x) }.min()!
        let rightEyeHeight = rightEyePoints.map { Float($0.y) }.max()! - rightEyePoints.map { Float($0.y) }.min()!
        signature.append(rightEyeHeight / max(rightEyeWidth, 0.001))

        let noseLength = nosePoints.map { Float($0.y) }.max()! - nosePoints.map { Float($0.y) }.min()!
        signature.append(noseLength / ipd)

        let mouthHeight = outerLipsPoints.map { Float($0.y) }.max()! - outerLipsPoints.map { Float($0.y) }.min()!
        signature.append(mouthHeight / ipd)

        // === EYEBROW FEATURES ===
        if let leftBrowPoints = landmarks.leftEyebrow?.normalizedPoints,
           let rightBrowPoints = landmarks.rightEyebrow?.normalizedPoints {
            let leftBrowCenter = centerPoint(of: leftBrowPoints)
            let rightBrowCenter = centerPoint(of: rightBrowPoints)

            signature.append(distance(from: leftBrowCenter, to: leftEyeCenter) / ipd)
            signature.append(distance(from: rightBrowCenter, to: rightEyeCenter) / ipd)
            signature.append(atan2(Float(rightBrowCenter.y - leftBrowCenter.y), Float(rightBrowCenter.x - leftBrowCenter.x)))
        } else {
            signature.append(contentsOf: [0, 0, 0])
        }

        // === JAW SHAPE ===
        if faceContourPoints.count >= 10 {
            let sortedByY = faceContourPoints.sorted { $0.y < $1.y }
            let lowerJawPoints = Array(sortedByY.prefix(faceContourPoints.count / 3))
            let midJawPoints = Array(sortedByY.dropFirst(faceContourPoints.count / 3).prefix(faceContourPoints.count / 3))

            let lowerJawWidth = lowerJawPoints.map { Float($0.x) }.max()! - lowerJawPoints.map { Float($0.x) }.min()!
            let midJawWidth = midJawPoints.map { Float($0.x) }.max()! - midJawPoints.map { Float($0.x) }.min()!

            signature.append(lowerJawWidth / faceWidth)
            signature.append(midJawWidth / faceWidth)
            signature.append(lowerJawWidth / max(midJawWidth, 0.001))
        } else {
            signature.append(contentsOf: [0, 0, 0])
        }

        // === NORMALIZED POSITIONS ===
        let faceCenter = CGPoint(
            x: CGFloat(faceContourPoints.map { Float($0.x) }.reduce(0, +)) / CGFloat(faceContourPoints.count),
            y: CGFloat(faceContourPoints.map { Float($0.y) }.reduce(0, +)) / CGFloat(faceContourPoints.count)
        )

        signature.append(Float(leftEyeCenter.x - faceCenter.x) / ipd)
        signature.append(Float(leftEyeCenter.y - faceCenter.y) / ipd)
        signature.append(Float(rightEyeCenter.x - faceCenter.x) / ipd)
        signature.append(Float(rightEyeCenter.y - faceCenter.y) / ipd)
        signature.append(Float(noseCenter.x - faceCenter.x) / ipd)
        signature.append(Float(noseCenter.y - faceCenter.y) / ipd)
        signature.append(Float(mouthCenter.x - faceCenter.x) / ipd)
        signature.append(Float(mouthCenter.y - faceCenter.y) / ipd)

        // Normalize
        let magnitude = sqrt(signature.reduce(0) { $0 + $1 * $1 })
        if magnitude > 0 {
            signature = signature.map { $0 / magnitude }
        }

        return signature
    }

    private func extractFaceSignature(from image: UIImage) async -> [Float]? {
        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNDetectFaceLandmarksRequest { request, error in
                guard let results = request.results as? [VNFaceObservation],
                      let face = results.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) else {
                    continuation.resume(returning: nil)
                    return
                }

                let signature = self.generateFaceSignature(face)
                continuation.resume(returning: signature)
            }

            request.revision = VNDetectFaceLandmarksRequestRevision3

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Utility Methods

    private func centerPoint(of points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let sumX = points.reduce(0) { $0 + $1.x }
        let sumY = points.reduce(0) { $0 + $1.y }
        return CGPoint(x: sumX / CGFloat(points.count), y: sumY / CGFloat(points.count))
    }

    private func distance(from p1: CGPoint, to p2: CGPoint) -> Float {
        return sqrt(Float(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2)))
    }

    private func calculateCosineSimilarity(_ vectorA: [Float], _ vectorB: [Float]) -> Float {
        guard vectorA.count == vectorB.count, !vectorA.isEmpty else { return 0 }

        var dotProduct: Float = 0
        var magnitudeA: Float = 0
        var magnitudeB: Float = 0

        for i in 0..<vectorA.count {
            dotProduct += vectorA[i] * vectorB[i]
            magnitudeA += vectorA[i] * vectorA[i]
            magnitudeB += vectorB[i] * vectorB[i]
        }

        magnitudeA = sqrt(magnitudeA)
        magnitudeB = sqrt(magnitudeB)

        guard magnitudeA > 0, magnitudeB > 0 else { return 0 }

        let similarity = dotProduct / (magnitudeA * magnitudeB)
        return (similarity + 1) / 2
    }

    // MARK: - Network Methods

    private func fetchProfilePhotos(userId: String) async throws -> [String] {
        let db = Firestore.firestore()
        let doc = try await db.collection("users").document(userId).getDocument()

        guard let data = doc.data() else { return [] }

        var photos: [String] = []

        if let profileImageURL = data["profileImageURL"] as? String, !profileImageURL.isEmpty {
            photos.append(profileImageURL)
        }

        if let additionalPhotos = data["photos"] as? [String] {
            photos.append(contentsOf: additionalPhotos.filter { !$0.isEmpty })
        }

        return photos
    }

    private func downloadImage(from urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }

    private func updateUserVerification(userId: String, confidence: Double) async throws {
        let db = Firestore.firestore()
        try await db.collection("users").document(userId).updateData([
            "isVerified": true,
            "photoVerified": true,
            "photoVerifiedAt": Timestamp(date: Date()),
            "verifiedAt": Timestamp(date: Date()),
            "verificationConfidence": confidence,
            "verificationMethod": "live_face_recognition",
            "verificationVersion": 2
        ])
    }
}
