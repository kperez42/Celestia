//
//  ProfileEditViewModel.swift
//  Celestia
//
//  ViewModel for profile editing
//

import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseStorage

@MainActor
class ProfileEditViewModel: ObservableObject {
    // Dependency injection: Services
    private let userService: any UserServiceProtocol

    @Published var isLoading = false
    @Published var errorMessage: String?

    // Dependency injection initializer
    init(userService: any UserServiceProtocol = UserService.shared) {
        self.userService = userService
    }
    
    func uploadProfileImage(_ image: UIImage, userId: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])
        }
        
        let storageRef = storage.reference().child("profile_images/\(userId).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    func updateProfile(
        userId: String,
        name: String,
        age: Int,
        bio: String,
        location: String,
        country: String,
        languages: [String],
        interests: [String],
        profileImageURL: String
    ) async throws {
        let userData: [String: Any] = [
            "fullName": name, // Fixed: Use fullName to match User model
            "age": age,
            "bio": bio,
            "location": location,
            "country": country,
            "languages": languages,
            "interests": interests,
            "profileImageURL": profileImageURL,
            "lastActive": Timestamp(date: Date())
        ]

        // Use UserService instead of direct Firestore access
        try await userService.updateUserFields(userId: userId, fields: userData)
    }
    
    func uploadAdditionalPhotos(_ images: [UIImage], userId: String) async throws -> [String] {
        var photoURLs: [String] = []
        
        for (index, image) in images.enumerated() {
            guard let imageData = image.jpegData(compressionQuality: 0.7) else { continue }
            
            let storageRef = storage.reference().child("user_photos/\(userId)/photo_\(index)_\(UUID().uuidString).jpg")
            
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
            let downloadURL = try await storageRef.downloadURL()
            photoURLs.append(downloadURL.absoluteString)
        }
        
        return photoURLs
    }
}
