//
//  ImageUploadService.swift
//  Celestia
//
//  Enhanced with comprehensive error handling, retry logic, background processing,
//  and content moderation to prevent inappropriate uploads
//

import Foundation
import UIKit
import Firebase
import FirebaseStorage

class ImageUploadService {
    static let shared = ImageUploadService()

    // Image constraints
    private let maxImageSize: Int = 15 * 1024 * 1024 // 15 MB for higher quality
    private let maxDimension: CGFloat = 3000 // Higher resolution for sharper images
    private let compressionQuality: CGFloat = 0.92 // High quality to prevent blurry images

    // Content moderation
    private let moderationService = ContentModerationService.shared

    // Whether to pre-check content before upload (can be disabled for performance)
    var enablePreModeration = true

    private init() {}

    // MARK: - Upload with Validation, Moderation, and Retry

    func uploadImage(_ image: UIImage, path: String, skipModeration: Bool = false) async throws -> String {
        // Validate image on current thread (fast check)
        try validateImage(image)

        // Pre-check content for inappropriate material (if enabled)
        if enablePreModeration && !skipModeration {
            let moderationResult = await moderationService.preCheckPhoto(image)
            if !moderationResult.approved {
                Logger.shared.warning("Image rejected by content moderation: \(moderationResult.message)", category: .general)
                throw CelestiaError.contentNotAllowed(moderationResult.message)
            }
        }

        // Optimize image on background thread (CPU-intensive)
        let imageData = try await optimizeImageAsync(image)

        // Validate size
        if imageData.count > maxImageSize {
            throw CelestiaError.imageTooBig
        }

        // Upload with retry logic (network operation)
        return try await RetryManager.shared.retryUploadOperation {
            try await self.performUpload(imageData: imageData, path: path)
        }
    }

    // MARK: - Background Image Processing

    private func optimizeImageAsync(_ image: UIImage) async throws -> Data {
        // Perform image processing on background thread to avoid blocking UI
        return try await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else {
                throw CelestiaError.invalidImageFormat
            }

            // Optimize image using modern UIGraphicsImageRenderer
            guard let optimizedImage = self.optimizeImageOnBackgroundThread(image) else {
                throw CelestiaError.invalidImageFormat
            }

            // Convert to data
            guard let imageData = optimizedImage.jpegData(compressionQuality: self.compressionQuality) else {
                throw CelestiaError.invalidImageFormat
            }

            return imageData
        }.value
    }

    // MARK: - Private Upload Method

    private func performUpload(imageData: Data, path: String) async throws -> String {
        let filename = UUID().uuidString
        let ref = Storage.storage().reference(withPath: "\(path)/\(filename).jpg")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = [
            "uploadedAt": ISO8601DateFormatter().string(from: Date()),
            "size": "\(imageData.count)"
        ]

        do {
            // Upload with progress tracking capability
            _ = try await ref.putDataAsync(imageData, metadata: metadata)

            // Get download URL
            let url = try await ref.downloadURL()
            Logger.shared.info("Image uploaded successfully: \(url.absoluteString)", category: .general)
            return url.absoluteString
        } catch let error as NSError {
            // REFACTORED: Use FirebaseErrorMapper for consistent error handling
            FirebaseErrorMapper.logError(error, context: "Image Upload")

            // Map Firebase error to CelestiaError
            let celestiaError = FirebaseErrorMapper.mapError(error)

            // Convert mapped error to appropriate image upload error
            switch celestiaError {
            case .storageQuotaExceeded:
                throw CelestiaError.imageTooBig
            case .unauthorized, .permissionDenied:
                throw CelestiaError.permissionDenied
            case .invalidData:
                throw CelestiaError.invalidData
            default:
                throw CelestiaError.imageUploadFailed
            }
        }
    }

    // MARK: - Image Validation

    private func validateImage(_ image: UIImage) throws {
        // Check if image is valid
        guard image.size.width > 0, image.size.height > 0 else {
            throw CelestiaError.invalidImageFormat
        }

        // Check minimum dimensions
        let minDimension: CGFloat = 200
        if image.size.width < minDimension || image.size.height < minDimension {
            throw CelestiaError.invalidImageFormat
        }

        // Check aspect ratio (prevent extremely distorted images)
        // Modern phones have tall screens (9:19.5 = 0.46, 9:21 = 0.43)
        // Allow ratios from 1:3 portrait (0.33) to 3:1 landscape (3.0)
        let aspectRatio = image.size.width / image.size.height
        if aspectRatio < 0.33 || aspectRatio > 3.0 {
            throw CelestiaError.invalidImageFormat
        }
    }

    // MARK: - Image Optimization (Background Thread)

    private func optimizeImageOnBackgroundThread(_ image: UIImage) -> UIImage? {
        let size = image.size

        // Calculate new size if needed
        var newSize = size
        if size.width > maxDimension || size.height > maxDimension {
            let scale = min(maxDimension / size.width, maxDimension / size.height)
            newSize = CGSize(width: size.width * scale, height: size.height * scale)
        }

        // Resize if needed using modern UIGraphicsImageRenderer
        if newSize != size {
            let renderer = UIGraphicsImageRenderer(size: newSize)
            let resizedImage = renderer.image { context in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
            return resizedImage
        }

        return image
    }

    // MARK: - Delete Image

    func deleteImage(url: String) async throws {
        guard !url.isEmpty, let urlObj = URL(string: url) else {
            throw CelestiaError.invalidData
        }

        // Use retry logic for deletion
        try await RetryManager.shared.retryDatabaseOperation {
            let ref = Storage.storage().reference(forURL: url)
            try await ref.delete()
            Logger.shared.info("Image deleted successfully: \(url)", category: .general)
        }
    }

    // MARK: - Convenience Methods

    func uploadProfileImage(_ image: UIImage, userId: String) async throws -> String {
        guard !userId.isEmpty else {
            throw CelestiaError.invalidData
        }
        return try await uploadImage(image, path: "profile_images/\(userId)")
    }

    func uploadChatImage(_ image: UIImage, matchId: String) async throws -> String {
        guard !matchId.isEmpty else {
            throw CelestiaError.invalidData
        }
        return try await uploadImage(image, path: "chat_images/\(matchId)")
    }

    // MARK: - Batch Upload

    func uploadMultipleImages(_ images: [UIImage], path: String, maxImages: Int = 6) async throws -> [String] {
        guard images.count <= maxImages else {
            throw CelestiaError.tooManyImages
        }

        var uploadedURLs: [String] = []

        // uploadImage expects a directory path and will append its own UUID filename
        // Each upload will get a unique filename automatically
        for image in images {
            do {
                let url = try await uploadImage(image, path: path)
                uploadedURLs.append(url)
            } catch {
                // If upload fails, delete already uploaded images
                for uploadedURL in uploadedURLs {
                    try? await deleteImage(url: uploadedURL)
                }
                throw error
            }
        }

        return uploadedURLs
    }
}
