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
import FirebaseAuth
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

    // Whether to pre-check content before upload
    // DISABLED BY DEFAULT: Content moderation was causing upload failures on some networks
    // Server-side moderation still runs, this just skips the pre-check
    var enablePreModeration = false

    private init() {}

    // MARK: - Upload with Validation, Moderation, and Retry

    func uploadImage(_ image: UIImage, path: String, skipModeration: Bool = false) async throws -> String {
        Logger.shared.info("📷 uploadImage() - path: \(path), skipModeration: \(skipModeration)", category: .networking)

        // NOTE: Network check is done by PhotoUploadService before calling this
        // Removing duplicate check here to prevent race conditions

        // Validate image on current thread (fast check)
        Logger.shared.info("📷 Validating image...", category: .networking)
        try validateImage(image)
        Logger.shared.info("📷 Image validation passed", category: .networking)

        // Pre-check content for inappropriate material (if enabled)
        if enablePreModeration && !skipModeration {
            Logger.shared.info("📷 Running content moderation (enablePreModeration=\(enablePreModeration))...", category: .networking)
            let moderationResult = await moderationService.preCheckPhoto(image)
            if !moderationResult.approved {
                Logger.shared.warning("📷 Image rejected by content moderation: \(moderationResult.message)", category: .networking)
                throw CelestiaError.contentNotAllowed(moderationResult.message)
            }
            Logger.shared.info("📷 Content moderation passed", category: .networking)
        } else {
            Logger.shared.info("📷 Skipping content moderation", category: .networking)
        }

        // Optimize image on background thread (CPU-intensive)
        Logger.shared.info("📷 Optimizing image...", category: .networking)
        let imageData = try await optimizeImageAsync(image)
        Logger.shared.info("📷 Image optimized - size: \(imageData.count / 1024) KB", category: .networking)

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
        let fullPath = "\(path)/\(filename).jpg"

        Logger.shared.info("🔥 Firebase Storage: Starting upload to path: \(fullPath)", category: .networking)
        Logger.shared.info("🔥 Firebase Storage: Data size: \(imageData.count) bytes (\(imageData.count / 1024) KB)", category: .networking)

        let ref = Storage.storage().reference(withPath: fullPath)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = [
            "uploadedAt": ISO8601DateFormatter().string(from: Date()),
            "size": "\(imageData.count)"
        ]

        do {
            // Upload with progress tracking capability
            Logger.shared.info("🔥 Firebase Storage: Calling putDataAsync()...", category: .networking)
            let uploadStartTime = Date()

            _ = try await ref.putDataAsync(imageData, metadata: metadata)

            let uploadDuration = Date().timeIntervalSince(uploadStartTime)
            Logger.shared.info("🔥 Firebase Storage: putDataAsync() completed in \(String(format: "%.1f", uploadDuration))s", category: .networking)

            // Get download URL
            Logger.shared.info("🔥 Firebase Storage: Getting download URL...", category: .networking)
            let url = try await ref.downloadURL()

            Logger.shared.info("🔥 Firebase Storage: SUCCESS - URL: \(url.absoluteString.prefix(60))...", category: .networking)
            return url.absoluteString
        } catch let error as NSError {
            Logger.shared.error("🔥 Firebase Storage: FAILED - domain: \(error.domain), code: \(error.code)", category: .networking)
            Logger.shared.error("🔥 Firebase Storage: Error description: \(error.localizedDescription)", category: .networking)

            // Enhanced WiFi diagnostics - log underlying cause if available
            if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                Logger.shared.error("🔥 Firebase Storage: Underlying error - domain: \(underlyingError.domain), code: \(underlyingError.code)", category: .networking)
            }

            // Check for common network-related error codes
            if error.domain == NSURLErrorDomain {
                switch error.code {
                case NSURLErrorNotConnectedToInternet:
                    Logger.shared.error("🔥 Upload failed: Device reports NO INTERNET (WiFi may have disconnected)", category: .networking)
                case NSURLErrorTimedOut:
                    Logger.shared.error("🔥 Upload failed: Request TIMED OUT (possible weak WiFi signal or network congestion)", category: .networking)
                case NSURLErrorNetworkConnectionLost:
                    Logger.shared.error("🔥 Upload failed: CONNECTION LOST during upload (WiFi signal may have dropped)", category: .networking)
                case NSURLErrorCannotConnectToHost:
                    Logger.shared.error("🔥 Upload failed: Cannot connect to Firebase (possible firewall or network issue)", category: .networking)
                case NSURLErrorDNSLookupFailed:
                    Logger.shared.error("🔥 Upload failed: DNS lookup failed (possible captive portal or DNS issue)", category: .networking)
                default:
                    Logger.shared.error("🔥 Upload failed: Network error code \(error.code)", category: .networking)
                }
            }

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
        Logger.shared.info("📷 ImageUploadService.uploadProfileImage() called - userId: \(userId.prefix(8))...", category: .networking)

        guard !userId.isEmpty else {
            Logger.shared.error("📷 uploadProfileImage failed: Empty userId", category: .networking)
            throw CelestiaError.invalidData
        }
        // Use high-quality upload for profile images (these appear on cards)
        return try await uploadHighQualityImage(image, path: "profile_images/\(userId)")
    }

    // MARK: - High Quality Upload (for profile photos)

    /// Upload image with maximum quality settings for profile photos
    /// These images appear on cards and need to look crisp and sharp
    private func uploadHighQualityImage(_ image: UIImage, path: String, skipModeration: Bool = false) async throws -> String {
        Logger.shared.info("📷 uploadHighQualityImage() - path: \(path)", category: .networking)

        // NOTE: Network check is done by PhotoUploadService before calling this
        // Removing duplicate check here to prevent race conditions

        // Validate image on current thread (fast check)
        Logger.shared.info("📷 Validating image...", category: .networking)
        try validateImage(image)
        Logger.shared.info("📷 Image validation passed", category: .networking)

        // Pre-check content for inappropriate material (if enabled)
        if enablePreModeration && !skipModeration {
            Logger.shared.info("📷 Running content moderation...", category: .networking)
            let moderationResult = await moderationService.preCheckPhoto(image)
            if !moderationResult.approved {
                Logger.shared.warning("📷 Image rejected by content moderation: \(moderationResult.message)", category: .networking)
                throw CelestiaError.contentNotAllowed(moderationResult.message)
            }
            Logger.shared.info("📷 Content moderation passed", category: .networking)
        }

        // Optimize image with HIGH QUALITY settings on background thread
        Logger.shared.info("📷 Optimizing image for upload...", category: .networking)
        let imageData = try await optimizeProfileImageAsync(image)
        Logger.shared.info("📷 Image optimized - size: \(imageData.count) bytes (\(imageData.count / 1024) KB)", category: .networking)

        // Validate size
        if imageData.count > maxImageSize {
            Logger.shared.error("📷 Image too large: \(imageData.count) > \(maxImageSize)", category: .networking)
            throw CelestiaError.imageTooBig
        }

        // Upload with retry logic (network operation)
        Logger.shared.info("📷 Starting upload with retry logic...", category: .networking)
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
        Logger.shared.info("📷 ImageUploadService.uploadChatImage() called - matchId: \(matchId.prefix(8))...", category: .networking)

        guard !matchId.isEmpty else {
            Logger.shared.error("📷 uploadChatImage failed: Empty matchId", category: .networking)
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

    // MARK: - Diagnostic Functions

    /// Test Firebase Storage connectivity by uploading a tiny test image
    /// Use this to diagnose upload issues
    func testFirebaseStorageConnectivity() async -> (success: Bool, message: String, duration: TimeInterval) {
        Logger.shared.info("🧪 DIAGNOSTIC: Testing Firebase Storage connectivity...", category: .networking)
        let startTime = Date()

        // Check Firebase Auth first
        guard let user = Auth.auth().currentUser else {
            let message = "Firebase Auth: No user signed in"
            Logger.shared.error("🧪 DIAGNOSTIC FAILED: \(message)", category: .networking)
            return (false, message, Date().timeIntervalSince(startTime))
        }
        Logger.shared.info("🧪 DIAGNOSTIC: Firebase Auth OK - uid: \(user.uid.prefix(8))...", category: .networking)

        // Create a tiny 1x1 pixel test image
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let testImage = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }

        guard let imageData = testImage.jpegData(compressionQuality: 0.1) else {
            let message = "Failed to create test image"
            Logger.shared.error("🧪 DIAGNOSTIC FAILED: \(message)", category: .networking)
            return (false, message, Date().timeIntervalSince(startTime))
        }

        Logger.shared.info("🧪 DIAGNOSTIC: Test image created (\(imageData.count) bytes)", category: .networking)

        // Try to upload to a test path
        let testPath = "diagnostic_tests/\(user.uid)/test_\(UUID().uuidString).jpg"
        let ref = Storage.storage().reference(withPath: testPath)

        do {
            Logger.shared.info("🧪 DIAGNOSTIC: Uploading to \(testPath)...", category: .networking)

            _ = try await ref.putDataAsync(imageData, metadata: nil)
            let duration = Date().timeIntervalSince(startTime)

            Logger.shared.info("🧪 DIAGNOSTIC: Upload succeeded in \(String(format: "%.2f", duration))s", category: .networking)

            // Clean up test file
            try? await ref.delete()
            Logger.shared.info("🧪 DIAGNOSTIC: Test file cleaned up", category: .networking)

            return (true, "Firebase Storage working! Upload took \(String(format: "%.1f", duration))s", duration)

        } catch let error as NSError {
            let duration = Date().timeIntervalSince(startTime)
            let message = "Upload failed: domain=\(error.domain), code=\(error.code), desc=\(error.localizedDescription)"
            Logger.shared.error("🧪 DIAGNOSTIC FAILED: \(message)", category: .networking)
            return (false, message, duration)
        }
    }
}
