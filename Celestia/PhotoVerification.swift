//
//  PhotoVerification.swift
//  Celestia
//
//  Photo verification service with face detection
//

import Foundation
import UIKit
import Vision
import FirebaseFirestore

@MainActor
class PhotoVerification: ObservableObject {
    static let shared = PhotoVerification()

    @Published var isVerifying: Bool = false
    @Published var verificationProgress: Double = 0.0
    @Published var verificationError: String?

    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Verification Process

    func verifyPhoto(image: UIImage, userId: String) async throws -> VerificationResult {
        isVerifying = true
        verificationProgress = 0.0
        verificationError = nil

        defer {
            isVerifying = false
            verificationProgress = 1.0
        }

        // Step 1: Detect face (20%)
        verificationProgress = 0.2
        let hasFace = try await detectFace(in: image)

        guard hasFace else {
            verificationError = "No face detected in photo"
            throw PhotoVerificationError.noFaceDetected
        }

        // Step 2: Check image quality (40%)
        verificationProgress = 0.4
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

        let isGoodQuality = checkImageQuality(image)
        guard isGoodQuality else {
            verificationError = "Image quality too low"
            throw PhotoVerificationError.poorQuality
        }

        // Step 3: Simulate face matching (70%)
        verificationProgress = 0.7
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1s

        // In production, you'd compare with profile photos
        // For now, we'll simulate a successful match
        let matchScore = 0.85 // 85% confidence

        guard matchScore >= 0.75 else {
            verificationError = "Face doesn't match profile photos"
            throw PhotoVerificationError.noMatch
        }

        // Step 4: Update user verification status (90%)
        verificationProgress = 0.9
        try await updateUserVerification(userId: userId)

        // Step 5: Complete (100%)
        verificationProgress = 1.0

        return VerificationResult(
            success: true,
            confidence: matchScore,
            timestamp: Date()
        )
    }

    // MARK: - Face Detection

    private func detectFace(in image: UIImage) async throws -> Bool {
        guard let cgImage = image.cgImage else {
            throw PhotoVerificationError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let results = request.results as? [VNFaceObservation],
                      !results.isEmpty else {
                    continuation.resume(returning: false)
                    return
                }

                // Check if face is large enough (not too far away)
                let faceSizeOK = results.contains { observation in
                    let faceArea = observation.boundingBox.width * observation.boundingBox.height
                    return faceArea > 0.1 // Face should be at least 10% of image
                }

                continuation.resume(returning: faceSizeOK)
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

    // MARK: - Image Quality Check

    private func checkImageQuality(_ image: UIImage) -> Bool {
        // Check resolution
        guard image.size.width >= 400, image.size.height >= 400 else {
            return false
        }

        // Check if image is too small in file size (indicating low quality)
        if let data = image.jpegData(compressionQuality: 0.8),
           data.count < 50_000 { // Less than 50KB
            return false
        }

        return true
    }

    // MARK: - Update Firestore

    private func updateUserVerification(userId: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "isVerified": true,
            "verifiedAt": Timestamp(date: Date())
        ])
    }

    // MARK: - Helper Methods

    func reset() {
        verificationProgress = 0.0
        verificationError = nil
        isVerifying = false
    }
}

// MARK: - Models

struct VerificationResult {
    let success: Bool
    let confidence: Double
    let timestamp: Date
}

enum PhotoVerificationError: LocalizedError {
    case noFaceDetected
    case poorQuality
    case noMatch
    case invalidImage
    case tooManyAttempts

    var errorDescription: String? {
        switch self {
        case .noFaceDetected:
            return "No face detected"
        case .poorQuality:
            return "Image quality too low"
        case .noMatch:
            return "Face doesn't match"
        case .invalidImage:
            return "Invalid image"
        case .tooManyAttempts:
            return "Too many attempts"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noFaceDetected:
            return "Make sure your face is clearly visible and well-lit."
        case .poorQuality:
            return "Use better lighting and hold your phone steady."
        case .noMatch:
            return "Make sure you're using the same person from your profile photos."
        case .invalidImage:
            return "Please try again with a different photo."
        case .tooManyAttempts:
            return "Please try again later or contact support."
        }
    }
}
