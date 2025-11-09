//
//  ImageUploadService.swift
//  Celestia
//
//  Enhanced with comprehensive error handling and retry logic
//

import Foundation
import UIKit
import Firebase
import FirebaseStorage

@MainActor
class ImageUploadService {
    static let shared = ImageUploadService()

    // Image constraints
    private let maxImageSize: Int = 10 * 1024 * 1024 // 10 MB
    private let maxDimension: CGFloat = 2048
    private let compressionQuality: CGFloat = 0.7

    private init() {}

    // MARK: - Upload with Validation and Retry

    func uploadImage(_ image: UIImage, path: String) async throws -> String {
        // Validate image
        try validateImage(image)

        // Optimize image
        guard let optimizedImage = optimizeImage(image) else {
            throw CelestiaError.invalidImageFormat
        }

        // Convert to data
        guard let imageData = optimizedImage.jpegData(compressionQuality: compressionQuality) else {
            throw CelestiaError.invalidImageFormat
        }

        // Validate size
        if imageData.count > maxImageSize {
            throw CelestiaError.imageTooBig
        }

        // Upload with retry logic
        return try await RetryManager.shared.retryUploadOperation {
            try await self.performUpload(imageData: imageData, path: path)
        }
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
            print("✅ Image uploaded successfully: \(url.absoluteString)")
            return url.absoluteString
        } catch let error as NSError {
            // Convert to CelestiaError
            if error.domain == "FIRStorageErrorDomain" {
                switch error.code {
                case StorageErrorCode.objectNotFound.rawValue:
                    throw CelestiaError.invalidData
                case StorageErrorCode.unauthorized.rawValue:
                    throw CelestiaError.permissionDenied
                case StorageErrorCode.quotaExceeded.rawValue:
                    throw CelestiaError.imageTooBig
                default:
                    throw CelestiaError.imageUploadFailed
                }
            }
            throw CelestiaError.imageUploadFailed
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
        let aspectRatio = image.size.width / image.size.height
        if aspectRatio < 0.5 || aspectRatio > 2.0 {
            throw CelestiaError.invalidImageFormat
        }
    }

    // MARK: - Image Optimization

    private func optimizeImage(_ image: UIImage) -> UIImage? {
        let size = image.size

        // Calculate new size if needed
        var newSize = size
        if size.width > maxDimension || size.height > maxDimension {
            let scale = min(maxDimension / size.width, maxDimension / size.height)
            newSize = CGSize(width: size.width * scale, height: size.height * scale)
        }

        // Resize if needed
        if newSize != size {
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return resizedImage
        }

        return image
    }
    
    // MARK: - Delete Image

    func deleteImage(urlString: String) async throws {
        guard !urlString.isEmpty, let url = URL(string: urlString) else {
            throw CelestiaError.invalidData
        }

        // Use retry logic for deletion
        try await RetryManager.shared.retryDatabaseOperation {
            let ref = Storage.storage().reference(forURL: urlString)
            try await ref.delete()
            print("✅ Image deleted successfully: \(urlString)")
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

        for (index, image) in images.enumerated() {
            do {
                let url = try await uploadImage(image, path: "\(path)/photo\(index)")
                uploadedURLs.append(url)
            } catch {
                // If upload fails, delete already uploaded images
                for uploadedURL in uploadedURLs {
                    try? await deleteImage(urlString: uploadedURL)
                }
                throw error
            }
        }

        return uploadedURLs
    }
}

