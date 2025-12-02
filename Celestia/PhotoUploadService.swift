//
//  PhotoUploadService.swift
//  Celestia
//
//  Photo upload service for gallery and profile photos
//

import Foundation
import UIKit

enum ImageType {
    case profile
    case gallery
    case chat
}

class PhotoUploadService {
    static let shared = PhotoUploadService()

    private init() {}

    func uploadPhoto(_ image: UIImage, userId: String, imageType: ImageType) async throws -> String {
        guard !userId.isEmpty else {
            throw CelestiaError.invalidData
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
}
