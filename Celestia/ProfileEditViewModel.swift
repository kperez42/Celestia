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
    init(userService: (any UserServiceProtocol)? = nil) {
        self.userService = userService ?? UserService.shared
    }
    
    func uploadProfileImage(_ image: UIImage, userId: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.92) else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])
        }

        let storageRef = Storage.storage().reference().child("profile_images/\(userId).jpg")
        
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
        // SECURITY FIX: Validate all inputs before saving to Firestore
        // This prevents clients from bypassing UI validation and sending invalid data

        // Validate name
        let nameValidation = ValidationHelper.validateName(name)
        guard nameValidation.isValid else {
            errorMessage = nameValidation.errorMessage
            throw CelestiaError.invalidProfileData
        }

        // Validate age
        let ageValidation = ValidationHelper.validateAge(age)
        guard ageValidation.isValid else {
            errorMessage = ageValidation.errorMessage
            throw CelestiaError.ageRestriction
        }

        // Validate bio length (critical: prevents database bloat)
        let bioValidation = ValidationHelper.validateBio(bio)
        guard bioValidation.isValid else {
            errorMessage = bioValidation.errorMessage
            throw CelestiaError.validationError(field: "bio", reason: bioValidation.errorMessage ?? "Bio is too long")
        }

        // Sanitize inputs using InputSanitizer
        let sanitizedName = InputSanitizer.strict(name)
        let sanitizedBio = InputSanitizer.standard(bio)
        let sanitizedLocation = InputSanitizer.basic(location)
        let sanitizedCountry = InputSanitizer.basic(country)

        let userData: [String: Any] = [
            "fullName": sanitizedName, // Fixed: Use fullName to match User model
            "age": age,
            "bio": sanitizedBio,
            "location": sanitizedLocation,
            "country": sanitizedCountry,
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
            guard let imageData = image.jpegData(compressionQuality: 0.92) else { continue }

            let storageRef = Storage.storage().reference().child("user_photos/\(userId)/photo_\(index)_\(UUID().uuidString).jpg")
            
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
            let downloadURL = try await storageRef.downloadURL()
            photoURLs.append(downloadURL.absoluteString)
        }
        
        return photoURLs
    }
}
