//
//  ImageUploadService.swift
//  Celestia
//
//  Created by Kevin Perez on 10/29/25.
//

import Foundation
import UIKit
import Firebase
import FirebaseStorage

class ImageUploadService {
    static let shared = ImageUploadService()
    
    private init() {}
    
    func uploadImage(_ image: UIImage, path: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            throw NSError(domain: "ImageUploadService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        let filename = UUID().uuidString
        let ref = Storage.storage().reference(withPath: "\(path)/\(filename)")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        do {
            let _ = try await ref.putDataAsync(imageData, metadata: metadata)
            let url = try await ref.downloadURL()
            return url.absoluteString
        } catch {
            print("Error uploading image: \(error.localizedDescription)")
            throw error
        }
    }
    
    func deleteImage(urlString: String) async throws {
        let ref = Storage.storage().reference(forURL: urlString)
        try await ref.delete()
    }
    
    func uploadProfileImage(_ image: UIImage, userId: String) async throws -> String {
        return try await uploadImage(image, path: "profile_images/\(userId)")
    }
    
    func uploadChatImage(_ image: UIImage, matchId: String) async throws -> String {
        return try await uploadImage(image, path: "chat_images/\(matchId)")
    }
}
