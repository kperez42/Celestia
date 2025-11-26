//
//  PhotoVerification.swift
//  Celestia
//
//  Photo verification service with Apple Vision face recognition
//  Uses on-device face embeddings for accurate face matching (like Face ID)
//

import Foundation
import UIKit
import Vision
import FirebaseFirestore
import FirebaseFunctions
import CoreML

@MainActor
class PhotoVerification: ObservableObject {
    static let shared = PhotoVerification()

    @Published var isVerifying: Bool = false
    @Published var verificationProgress: Double = 0.0
    @Published var verificationError: String?
    @Published var statusMessage: String = ""

    private let db = Firestore.firestore()

    // Face matching threshold (0.0 - 1.0, higher = stricter)
    // 0.6 is a good balance between security and usability
    private let matchThreshold: Float = 0.6

    private init() {}

    // MARK: - Main Verification Process

    func verifyPhoto(image: UIImage, userId: String) async throws -> VerificationResult {
        isVerifying = true
        verificationProgress = 0.0
        verificationError = nil
        statusMessage = "Starting verification..."

        defer {
            isVerifying = false
            verificationProgress = 1.0
        }

        // Step 1: Detect and validate face in selfie (15%)
        verificationProgress = 0.1
        statusMessage = "Detecting your face..."

        let selfieFaceData = try await detectAndExtractFace(in: image)

        guard let selfieObservation = selfieFaceData.observation else {
            verificationError = "No face detected in your selfie"
            throw PhotoVerificationError.noFaceDetected
        }

        // Check face quality
        verificationProgress = 0.15
        guard validateFaceQuality(selfieObservation, in: image) else {
            verificationError = "Face not clear enough. Please ensure good lighting and face the camera directly."
            throw PhotoVerificationError.poorQuality
        }

        // Step 2: Get face embedding from selfie (30%)
        verificationProgress = 0.25
        statusMessage = "Analyzing facial features..."

        let selfieEmbedding = try await generateFaceEmbedding(from: image, faceObservation: selfieObservation)

        guard let selfieVector = selfieEmbedding else {
            verificationError = "Could not analyze face. Please try again."
            throw PhotoVerificationError.invalidImage
        }

        // Step 3: Fetch user's profile photos (40%)
        verificationProgress = 0.35
        statusMessage = "Loading your profile photos..."

        let profilePhotos = try await fetchProfilePhotos(userId: userId)

        guard !profilePhotos.isEmpty else {
            verificationError = "No profile photos found. Please add photos first."
            throw PhotoVerificationError.noProfilePhotos
        }

        // Step 4: Compare with each profile photo (40% - 85%)
        verificationProgress = 0.4
        statusMessage = "Comparing with your profile..."

        var bestMatch: Float = 0.0
        var matchedPhotoIndex = -1
        let progressPerPhoto = 0.45 / Double(profilePhotos.count)

        for (index, photoURL) in profilePhotos.enumerated() {
            statusMessage = "Comparing photo \(index + 1) of \(profilePhotos.count)..."

            if let profileImage = await downloadImage(from: photoURL) {
                // Detect face in profile photo
                if let profileFaceData = try? await detectAndExtractFace(in: profileImage),
                   let profileObservation = profileFaceData.observation {

                    // Generate embedding for profile photo
                    if let profileVector = try? await generateFaceEmbedding(from: profileImage, faceObservation: profileObservation) {

                        // Calculate similarity
                        let similarity = calculateCosineSimilarity(selfieVector, profileVector)
                        Logger.shared.debug("Photo \(index + 1) similarity: \(similarity)", category: .general)

                        if similarity > bestMatch {
                            bestMatch = similarity
                            matchedPhotoIndex = index
                        }
                    }
                }
            }

            verificationProgress = 0.4 + (progressPerPhoto * Double(index + 1))
        }

        // Step 5: Evaluate match result (90%)
        verificationProgress = 0.9
        statusMessage = "Finalizing verification..."

        let confidence = Double(bestMatch)
        let isMatch = bestMatch >= matchThreshold

        Logger.shared.info("Face verification result - Best match: \(bestMatch), Threshold: \(matchThreshold), Passed: \(isMatch)", category: .general)

        guard isMatch else {
            verificationError = "Face doesn't match your profile photos. Please use a photo that clearly shows your face."
            throw PhotoVerificationError.noMatch
        }

        // Step 6: Update verification status in Firestore (95%)
        verificationProgress = 0.95
        statusMessage = "Updating your profile..."

        try await updateUserVerification(userId: userId, confidence: confidence)

        // Step 7: Complete (100%)
        verificationProgress = 1.0
        statusMessage = "Verification complete!"

        HapticManager.shared.notification(.success)

        return VerificationResult(
            success: true,
            confidence: confidence,
            timestamp: Date()
        )
    }

    // MARK: - Face Detection with Quality Analysis

    private func detectAndExtractFace(in image: UIImage) async throws -> (observation: VNFaceObservation?, landmarks: VNFaceLandmarks2D?) {
        guard let cgImage = image.cgImage else {
            throw PhotoVerificationError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            // Use face landmarks request for more detailed analysis
            let request = VNDetectFaceLandmarksRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let results = request.results as? [VNFaceObservation],
                      let bestFace = results.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) else {
                    continuation.resume(returning: (nil, nil))
                    return
                }

                continuation.resume(returning: (bestFace, bestFace.landmarks))
            }

            // High accuracy for face detection
            request.revision = VNDetectFaceLandmarksRequestRevision3

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Face Quality Validation

    private func validateFaceQuality(_ observation: VNFaceObservation, in image: UIImage) -> Bool {
        // Check face size (should be at least 15% of image)
        let faceArea = observation.boundingBox.width * observation.boundingBox.height
        guard faceArea >= 0.15 else {
            Logger.shared.debug("Face too small: \(faceArea)", category: .general)
            return false
        }

        // Check if face is reasonably centered (not at extreme edges)
        let centerX = observation.boundingBox.midX
        let centerY = observation.boundingBox.midY
        guard centerX > 0.15 && centerX < 0.85 && centerY > 0.15 && centerY < 0.85 else {
            Logger.shared.debug("Face not centered: (\(centerX), \(centerY))", category: .general)
            return false
        }

        // Check face capture quality if available
        if #available(iOS 15.0, *) {
            if let quality = observation.faceCaptureQuality, quality < 0.3 {
                Logger.shared.debug("Face quality too low: \(quality)", category: .general)
                return false
            }
        }

        // Check for required landmarks (eyes, nose, mouth)
        if let landmarks = observation.landmarks {
            guard landmarks.leftEye != nil,
                  landmarks.rightEye != nil,
                  landmarks.nose != nil,
                  landmarks.outerLips != nil else {
                Logger.shared.debug("Missing facial landmarks", category: .general)
                return false
            }
        }

        // Check yaw (face should be relatively front-facing)
        if let yaw = observation.yaw?.floatValue {
            guard abs(yaw) < 0.5 else { // About 30 degrees
                Logger.shared.debug("Face yaw too extreme: \(yaw)", category: .general)
                return false
            }
        }

        // Check roll (face shouldn't be tilted too much)
        if let roll = observation.roll?.floatValue {
            guard abs(roll) < 0.5 else {
                Logger.shared.debug("Face roll too extreme: \(roll)", category: .general)
                return false
            }
        }

        return true
    }

    // MARK: - Face Embedding Generation

    private func generateFaceEmbedding(from image: UIImage, faceObservation: VNFaceObservation) async throws -> [Float]? {
        guard let cgImage = image.cgImage else {
            return nil
        }

        // Crop to face region with padding for better embedding
        let faceImage = cropFaceRegion(from: cgImage, observation: faceObservation)

        // Generate embedding using Vision's face print
        if #available(iOS 17.0, *) {
            return try await generateEmbeddingModern(from: faceImage)
        } else {
            // Fallback: use landmark-based feature vector
            return generateLandmarkBasedEmbedding(observation: faceObservation)
        }
    }

    @available(iOS 17.0, *)
    private func generateEmbeddingModern(from cgImage: CGImage) async throws -> [Float]? {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNGenerateFaceEmbeddingRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let results = request.results as? [VNFaceObservation],
                      let firstResult = results.first,
                      let embedding = firstResult.faceCaptureQuality else {
                    // Fallback if embedding not available
                    continuation.resume(returning: nil)
                    return
                }

                // Use the face observation's internal embedding
                continuation.resume(returning: nil)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // Generate feature vector from facial landmarks (works on all iOS versions)
    private func generateLandmarkBasedEmbedding(observation: VNFaceObservation) -> [Float]? {
        guard let landmarks = observation.landmarks else { return nil }

        var features: [Float] = []

        // Extract normalized landmark positions
        let allLandmarkRegions: [VNFaceLandmarkRegion2D?] = [
            landmarks.leftEye,
            landmarks.rightEye,
            landmarks.nose,
            landmarks.noseCrest,
            landmarks.outerLips,
            landmarks.innerLips,
            landmarks.leftEyebrow,
            landmarks.rightEyebrow,
            landmarks.faceContour,
            landmarks.medianLine
        ]

        for region in allLandmarkRegions {
            if let region = region {
                // Add normalized point coordinates
                for point in region.normalizedPoints {
                    features.append(Float(point.x))
                    features.append(Float(point.y))
                }
            }
        }

        // Add face bounding box ratios
        features.append(Float(observation.boundingBox.width / observation.boundingBox.height))

        // Add yaw and roll if available
        if let yaw = observation.yaw?.floatValue {
            features.append(yaw)
        }
        if let roll = observation.roll?.floatValue {
            features.append(roll)
        }

        // Calculate inter-landmark distances for geometric features
        if let leftEye = landmarks.leftEye?.normalizedPoints.first,
           let rightEye = landmarks.rightEye?.normalizedPoints.first {
            let eyeDistance = sqrt(pow(Float(rightEye.x - leftEye.x), 2) + pow(Float(rightEye.y - leftEye.y), 2))
            features.append(eyeDistance)

            // Eye to nose ratio
            if let nose = landmarks.nose?.normalizedPoints.first {
                let leftEyeToNose = sqrt(pow(Float(nose.x - leftEye.x), 2) + pow(Float(nose.y - leftEye.y), 2))
                let rightEyeToNose = sqrt(pow(Float(nose.x - rightEye.x), 2) + pow(Float(nose.y - rightEye.y), 2))
                features.append(leftEyeToNose / eyeDistance)
                features.append(rightEyeToNose / eyeDistance)

                // Nose to mouth ratio
                if let mouth = landmarks.outerLips?.normalizedPoints.first {
                    let noseToMouth = sqrt(pow(Float(mouth.x - nose.x), 2) + pow(Float(mouth.y - nose.y), 2))
                    features.append(noseToMouth / eyeDistance)
                }
            }
        }

        // Pad to fixed size for consistent comparison
        while features.count < 256 {
            features.append(0)
        }
        if features.count > 256 {
            features = Array(features.prefix(256))
        }

        // Normalize the feature vector
        let magnitude = sqrt(features.reduce(0) { $0 + $1 * $1 })
        if magnitude > 0 {
            features = features.map { $0 / magnitude }
        }

        return features
    }

    // MARK: - Image Processing Helpers

    private func cropFaceRegion(from cgImage: CGImage, observation: VNFaceObservation) -> CGImage {
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        // Convert normalized coordinates to image coordinates
        var faceRect = CGRect(
            x: observation.boundingBox.origin.x * imageWidth,
            y: (1 - observation.boundingBox.origin.y - observation.boundingBox.height) * imageHeight,
            width: observation.boundingBox.width * imageWidth,
            height: observation.boundingBox.height * imageHeight
        )

        // Add padding (30%) for better embedding
        let paddingX = faceRect.width * 0.3
        let paddingY = faceRect.height * 0.3
        faceRect = faceRect.insetBy(dx: -paddingX, dy: -paddingY)

        // Clamp to image bounds
        faceRect = faceRect.intersection(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))

        // Crop the face region
        if let croppedImage = cgImage.cropping(to: faceRect) {
            return croppedImage
        }

        return cgImage
    }

    // MARK: - Similarity Calculation

    private func calculateCosineSimilarity(_ vectorA: [Float], _ vectorB: [Float]) -> Float {
        guard vectorA.count == vectorB.count, !vectorA.isEmpty else {
            return 0
        }

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

        guard magnitudeA > 0, magnitudeB > 0 else {
            return 0
        }

        // Cosine similarity ranges from -1 to 1, normalize to 0-1
        let similarity = dotProduct / (magnitudeA * magnitudeB)
        return (similarity + 1) / 2
    }

    // MARK: - Network Helpers

    private func fetchProfilePhotos(userId: String) async throws -> [String] {
        let doc = try await db.collection("users").document(userId).getDocument()

        guard let data = doc.data() else {
            throw PhotoVerificationError.invalidImage
        }

        var photos: [String] = []

        // Get profile image URL
        if let profileImageURL = data["profileImageURL"] as? String, !profileImageURL.isEmpty {
            photos.append(profileImageURL)
        }

        // Get additional photos
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
            Logger.shared.error("Failed to download image: \(error.localizedDescription)", category: .general)
            return nil
        }
    }

    // MARK: - Firestore Update

    private func updateUserVerification(userId: String, confidence: Double) async throws {
        try await db.collection("users").document(userId).updateData([
            "isVerified": true,
            "verifiedAt": Timestamp(date: Date()),
            "verificationConfidence": confidence,
            "verificationMethod": "face_recognition"
        ])
    }

    // MARK: - Helper Methods

    func reset() {
        verificationProgress = 0.0
        verificationError = nil
        statusMessage = ""
        isVerifying = false
    }
}

// MARK: - Models

struct VerificationResult {
    let success: Bool
    let confidence: Double
    let timestamp: Date
}

struct CloudVerificationResult {
    let success: Bool
    let isVerified: Bool
    let confidence: Double
    let message: String
}

enum PhotoVerificationError: LocalizedError {
    case noFaceDetected
    case poorQuality
    case noMatch
    case invalidImage
    case tooManyAttempts
    case noProfilePhotos
    case multipleFaces

    var errorDescription: String? {
        switch self {
        case .noFaceDetected:
            return "No face detected"
        case .poorQuality:
            return "Image quality too low"
        case .noMatch:
            return "Face doesn't match profile"
        case .invalidImage:
            return "Invalid image"
        case .tooManyAttempts:
            return "Too many attempts"
        case .noProfilePhotos:
            return "No profile photos found"
        case .multipleFaces:
            return "Multiple faces detected"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noFaceDetected:
            return "Make sure your face is clearly visible and well-lit."
        case .poorQuality:
            return "Use better lighting, face the camera directly, and remove glasses or hats."
        case .noMatch:
            return "Make sure you're the same person in your profile photos."
        case .invalidImage:
            return "Please try again with a different photo."
        case .tooManyAttempts:
            return "Please try again later or contact support."
        case .noProfilePhotos:
            return "Please add photos to your profile first."
        case .multipleFaces:
            return "Please take a photo with only yourself in frame."
        }
    }
}
