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

        // ImageUploadService.uploadImage expects a directory path
        // It will append its own UUID filename to the path
        let path: String
        switch imageType {
        case .profile:
            path = "profile_images/\(userId)"
        case .gallery:
            path = "gallery_photos/\(userId)"
        case .chat:
            path = "chat_images/\(userId)"
        }

        return try await ImageUploadService.shared.uploadImage(image, path: path)
    }
}
