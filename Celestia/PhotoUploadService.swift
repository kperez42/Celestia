//
//  PhotoUploadService.swift
//  Celestia
//
//  Photo upload service for gallery and profile photos
//  Includes network connectivity checks for reliable uploads
//

import Foundation
import UIKit

enum ImageType {
    case profile
    case gallery
    case chat
}

/// Error types specific to photo uploads
enum PhotoUploadError: LocalizedError {
    case noNetwork
    case poorConnection
    case uploadFailed(String)

    var errorDescription: String? {
        switch self {
        case .noNetwork:
            return "No internet connection. Please check your WiFi or cellular data and try again."
        case .poorConnection:
            return "Your connection is too slow for photo uploads. Please try again with a stronger signal."
        case .uploadFailed(let reason):
            return "Upload failed: \(reason)"
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
        guard !userId.isEmpty else {
            throw CelestiaError.invalidData
        }

        // NETWORK CHECK: Verify connectivity before attempting upload
        guard await checkNetworkForUpload() else {
            Logger.shared.warning("Photo upload blocked: No network connection", category: .networking)
            throw PhotoUploadError.noNetwork
        }

        // Use high-quality upload for profile and gallery photos (these appear on cards)
        switch imageType {
        case .profile:
            // Profile photos use maximum quality settings
            return try await ImageUploadService.shared.uploadProfileImage(image, userId: userId)
        case .gallery:
            // Gallery photos also use high quality (they appear in photo viewers)
            return try await ImageUploadService.shared.uploadProfileImage(image, userId: userId)
        case .chat:
            // Chat images use standard quality (they're smaller and temporary)
            return try await ImageUploadService.shared.uploadChatImage(image, matchId: userId)
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

    // MARK: - Network Helpers

    /// Check if network is suitable for upload
    @MainActor
    private func checkNetworkForUpload() -> Bool {
        return networkMonitor.isConnected
    }

    /// Check network quality for large uploads
    @MainActor
    func isNetworkSuitableForUpload() -> Bool {
        guard networkMonitor.isConnected else { return false }
        // Allow uploads on any connection except when quality is unknown and disconnected
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
