//
//  PhotoUploadService.swift
//  Celestia
//
//  Photo upload service for gallery and profile photos
//  Includes network connectivity checks for reliable uploads
//

import Foundation
import UIKit
import FirebaseAuth

enum ImageType {
    case profile
    case gallery
    case chat
}

/// Error types specific to photo uploads
enum PhotoUploadError: LocalizedError {
    case noNetwork
    case wifiConnectedNoInternet
    case poorConnection
    case uploadFailed(String)
    case uploadTimeout

    var errorDescription: String? {
        switch self {
        case .noNetwork:
            return "No internet connection. Please check your WiFi or cellular data and try again."
        case .wifiConnectedNoInternet:
            return "WiFi connected but no internet access. Please check if you need to sign into the WiFi network, or try a different network."
        case .poorConnection:
            return "Your connection is too slow for photo uploads. Please try again with a stronger signal."
        case .uploadFailed(let reason):
            return "Upload failed: \(reason)"
        case .uploadTimeout:
            return "Upload timed out. Please check your connection and try again."
        }
    }
}

class PhotoUploadService {
    static let shared = PhotoUploadService()

    private let networkMonitor = NetworkMonitor.shared

    private init() {}

    /// Upload a photo with network connectivity check
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - userId: User ID for the upload path
    ///   - imageType: Type of image (profile, gallery, chat)
    /// - Returns: URL string of the uploaded image
    func uploadPhoto(_ image: UIImage, userId: String, imageType: ImageType) async throws -> String {
        Logger.shared.info("📸 PhotoUploadService.uploadPhoto() called - imageType: \(imageType), userId: \(userId.prefix(8))...", category: .networking)

        // CRITICAL: Check Firebase Auth state
        let firebaseUser = Auth.auth().currentUser
        if let user = firebaseUser {
            Logger.shared.info("🔐 Firebase Auth: User authenticated - uid: \(user.uid.prefix(8))...", category: .networking)
        } else {
            Logger.shared.error("🔐 Firebase Auth: NO USER AUTHENTICATED - uploads will fail!", category: .networking)
            // Don't throw here, let Firebase return proper error
        }

        guard !userId.isEmpty else {
            Logger.shared.error("📸 Upload failed: Empty userId", category: .networking)
            throw CelestiaError.invalidData
        }

        // Log image details
        Logger.shared.info("📸 Image size: \(image.size.width)x\(image.size.height), scale: \(image.scale)", category: .networking)

        // Get network status from main actor
        let networkStatus = await MainActor.run {
            (connected: networkMonitor.isConnected,
             type: networkMonitor.connectionType,
             quality: networkMonitor.quality)
        }

        Logger.shared.info("📶 Network check - connected: \(networkStatus.connected), type: \(networkStatus.type.description), quality: \(networkStatus.quality.description)", category: .networking)

        // Verify connectivity (now tests actual internet access for ALL connection types including WiFi)
        let actuallyConnected = await networkMonitor.verifyConnectivity()
        Logger.shared.info("📶 verifyConnectivity() returned: \(actuallyConnected)", category: .networking)

        if !actuallyConnected {
            // Provide specific error message based on connection type
            let connectionType = await MainActor.run { networkMonitor.connectionType }
            if connectionType == .wifi && networkStatus.connected {
                // WiFi is connected but no internet - common issue
                Logger.shared.warning("❌ Photo upload blocked: WiFi connected but NO INTERNET ACCESS", category: .networking)
                Logger.shared.warning("❌ User should check: captive portal login, weak signal, or network issues", category: .networking)
                throw PhotoUploadError.wifiConnectedNoInternet
            } else {
                Logger.shared.warning("❌ Photo upload blocked: Network verification failed", category: .networking)
                throw PhotoUploadError.noNetwork
            }
        }

        Logger.shared.info("✅ Network OK - Proceeding with \(imageType) upload...", category: .networking)

        // Use high-quality upload for profile and gallery photos (these appear on cards)
        do {
            let url: String
            let startTime = Date()

            switch imageType {
            case .profile:
                Logger.shared.info("📸 Calling ImageUploadService.uploadProfileImage()...", category: .networking)
                url = try await ImageUploadService.shared.uploadProfileImage(image, userId: userId)
            case .gallery:
                Logger.shared.info("📸 Calling ImageUploadService.uploadProfileImage() for gallery...", category: .networking)
                url = try await ImageUploadService.shared.uploadProfileImage(image, userId: userId)
            case .chat:
                Logger.shared.info("📸 Calling ImageUploadService.uploadChatImage()...", category: .networking)
                url = try await ImageUploadService.shared.uploadChatImage(image, matchId: userId)
            }

            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.info("✅ Photo upload SUCCESS in \(String(format: "%.1f", duration))s - URL: \(url.prefix(60))...", category: .networking)
            return url
        } catch {
            Logger.shared.error("❌ Photo upload FAILED - Error: \(error.localizedDescription)", category: .networking, error: error)

            // Provide more context about the failure
            if let celestiaError = error as? CelestiaError {
                Logger.shared.error("❌ CelestiaError type: \(celestiaError)", category: .networking)
            }
            if let nsError = error as NSError? {
                Logger.shared.error("❌ NSError domain: \(nsError.domain), code: \(nsError.code)", category: .networking)
            }

            throw error
        }
    }

    /// Upload with network quality awareness - adjusts quality based on connection
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - userId: User ID for the upload path
    ///   - imageType: Type of image
    ///   - requireHighQuality: If true, only upload on good connections
    /// - Returns: URL string of the uploaded image
    func uploadPhotoWithQualityCheck(_ image: UIImage, userId: String, imageType: ImageType, requireHighQuality: Bool = false) async throws -> String {
        guard !userId.isEmpty else {
            throw CelestiaError.invalidData
        }

        // Check network status
        let isConnected = await MainActor.run { networkMonitor.isConnected }
        guard isConnected else {
            throw PhotoUploadError.noNetwork
        }

        // For high-quality requirement, check connection quality
        if requireHighQuality {
            let quality = await MainActor.run { networkMonitor.quality }
            if quality == .poor {
                Logger.shared.warning("Photo upload blocked: Poor connection quality", category: .networking)
                throw PhotoUploadError.poorConnection
            }
        }

        return try await uploadPhoto(image, userId: userId, imageType: imageType)
    }

    // MARK: - Resilient Upload with Offline Queueing

    /// Upload with automatic offline queueing if it fails
    /// Returns immediately with queued status if network is down
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - userId: User ID for the upload path
    ///   - imageType: Type of image (profile, gallery, chat)
    /// - Returns: Result with URL on success, or queued status on failure
    func uploadPhotoWithOfflineSupport(_ image: UIImage, userId: String, imageType: ImageType) async -> Result<String, PhotoUploadError> {
        Logger.shared.info("📸 uploadPhotoWithOfflineSupport() called", category: .networking)

        do {
            let url = try await uploadPhoto(image, userId: userId, imageType: imageType)
            return .success(url)
        } catch {
            Logger.shared.warning("📸 Upload failed, attempting to queue for offline sync...", category: .networking)

            // Try to queue for offline upload
            let queued = await MainActor.run {
                OfflineOperationQueue.shared.queuePhotoUpload(image, userId: userId, imageType: imageType)
            }

            if queued {
                Logger.shared.info("📸 Photo queued for upload when network is restored", category: .networking)
                return .failure(.uploadFailed("Photo queued for upload when connection improves"))
            } else {
                Logger.shared.error("📸 Failed to queue photo for offline upload", category: .networking)
                if let photoError = error as? PhotoUploadError {
                    return .failure(photoError)
                }
                return .failure(.uploadFailed(error.localizedDescription))
            }
        }
    }

    // MARK: - Network Helpers

    /// Check network quality for large uploads
    @MainActor
    func isNetworkSuitableForUpload() -> Bool {
        guard networkMonitor.isConnected else { return false }
        return true
    }

    /// Get current network status for UI feedback
    @MainActor
    func getNetworkStatus() -> (connected: Bool, type: String, quality: String) {
        return (
            connected: networkMonitor.isConnected,
            type: networkMonitor.connectionType.description,
            quality: networkMonitor.quality.description
        )
    }
}
