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

    // Image constraints - optimized for high quality profile photos
    private let maxImageSize: Int = 20 * 1024 * 1024 // 20 MB for higher quality
    private let maxDimension: CGFloat = 4096 // 4K resolution for sharp, crisp images
    private let compressionQuality: CGFloat = 0.95 // Premium quality to prevent any blurriness

    // Profile-specific settings for maximum quality on cards
    private let profileMaxDimension: CGFloat = 2048 // Optimal for profile cards
    private let profileCompressionQuality: CGFloat = 0.97 // Near-lossless for profile photos

    // Content moderation
    private let moderationService = ContentModerationService.shared

    // Network monitoring for upload reliability
    private let networkMonitor = NetworkMonitor.shared

    // Whether to pre-check content before upload (can be disabled for performance)
    var enablePreModeration = true

    private init() {}

    // MARK: - Network Check

    /// Check if network is available for upload
    @MainActor
    private func isNetworkAvailable() -> Bool {
        return networkMonitor.isConnected
    }

    // MARK: - Upload with Validation, Moderation, and Retry

    func uploadImage(_ image: UIImage, path: String, skipModeration: Bool = false) async throws -> String {
        // NETWORK CHECK: Verify connectivity before starting upload process
        let connected = await MainActor.run { isNetworkAvailable() }
        guard connected else {
            Logger.shared.warning("Image upload blocked: No network connection", category: .networking)
            throw CelestiaError.networkError
        }

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
        // Use high-quality upload for profile images (these appear on cards)
        return try await uploadHighQualityImage(image, path: "profile_images/\(userId)")
    }

    // MARK: - High Quality Upload (for profile photos)

    /// Upload image with maximum quality settings for profile photos
    /// These images appear on cards and need to look crisp and sharp
    private func uploadHighQualityImage(_ image: UIImage, path: String, skipModeration: Bool = false) async throws -> String {
        // NETWORK CHECK: Verify connectivity before starting upload process
        let connected = await MainActor.run { isNetworkAvailable() }
        guard connected else {
            Logger.shared.warning("High quality image upload blocked: No network connection", category: .networking)
            throw CelestiaError.networkError
        }

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

        // Optimize image with HIGH QUALITY settings on background thread
        let imageData = try await optimizeProfileImageAsync(image)

        // Validate size
        if imageData.count > maxImageSize {
            throw CelestiaError.imageTooBig
        }

        // Upload with retry logic (network operation)
        return try await RetryManager.shared.retryUploadOperation {
            try await self.performUpload(imageData: imageData, path: path)
        }
    }

    /// Optimize profile images with maximum quality settings
    private func optimizeProfileImageAsync(_ image: UIImage) async throws -> Data {
        return try await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else {
                throw CelestiaError.invalidImageFormat
            }

            // Optimize image using HIGH QUALITY settings
            guard let optimizedImage = self.optimizeProfileImage(image) else {
                throw CelestiaError.invalidImageFormat
            }

            // Convert to data with MAXIMUM quality for profile photos
            guard let imageData = optimizedImage.jpegData(compressionQuality: self.profileCompressionQuality) else {
                throw CelestiaError.invalidImageFormat
            }

            return imageData
        }.value
    }

    /// Optimize profile image with high-quality interpolation
    private func optimizeProfileImage(_ image: UIImage) -> UIImage? {
        let size = image.size

        // Calculate new size if needed (use profile-specific max dimension)
        var newSize = size
        if size.width > profileMaxDimension || size.height > profileMaxDimension {
            let scale = min(profileMaxDimension / size.width, profileMaxDimension / size.height)
            newSize = CGSize(width: size.width * scale, height: size.height * scale)
        }

        // Resize if needed using high-quality renderer
        if newSize != size {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0 // Use actual pixel dimensions
            format.preferredRange = .standard

            let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
            let resizedImage = renderer.image { context in
                // Use high-quality interpolation for sharp results
                context.cgContext.interpolationQuality = .high
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
            return resizedImage
        }

        return image
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
