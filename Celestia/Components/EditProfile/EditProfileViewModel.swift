//
//  EditProfileViewModel.swift
//  Celestia
//
//  ViewModel for Edit Profile - centralizes state and business logic
//  Extracted from EditProfileView.swift to reduce file size and improve testability
//

import SwiftUI
import PhotosUI

@MainActor
class EditProfileViewModel: ObservableObject {
    // MARK: - Published Properties

    // Basic Info
    @Published var fullName: String
    @Published var age: String
    @Published var bio: String
    @Published var location: String
    @Published var country: String
    @Published var gender: String
    @Published var lookingFor: String

    // Collections
    @Published var languages: [String]
    @Published var interests: [String]
    @Published var prompts: [ProfilePrompt]
    @Published var photos: [String]

    // Advanced Profile Fields
    @Published var height: Int?
    @Published var religion: String?
    @Published var relationshipGoal: String?
    @Published var smoking: String?
    @Published var drinking: String?
    @Published var pets: String?
    @Published var exercise: String?
    @Published var diet: String?

    // UI State
    @Published var newLanguage = ""
    @Published var newInterest = ""
    @Published var isLoading = false
    @Published var showImagePicker = false
    @Published var selectedImage: PhotosPickerItem?
    @Published var profileImage: UIImage?
    @Published var showSuccessAlert = false
    @Published var showErrorAlert = false
    @Published var errorMessage = ""
    @Published var showLanguagePicker = false
    @Published var showInterestPicker = false
    @Published var showPromptsEditor = false
    @Published var selectedPhotoItems: [PhotosPickerItem] = []
    @Published var isUploadingPhotos = false
    @Published var uploadProgress: Double = 0.0

    // MARK: - Constants

    let genderOptions = ["Male", "Female", "Non-binary", "Other"]
    let lookingForOptions = ["Men", "Women", "Everyone"]
    let religionOptions = ["Prefer not to say", "Agnostic", "Atheist", "Buddhist", "Catholic", "Christian", "Hindu", "Jewish", "Muslim", "Spiritual", "Other"]
    let relationshipGoalOptions = ["Prefer not to say", "Casual dating", "Relationship", "Long-term partner", "Marriage", "Open to anything"]
    let smokingOptions = ["Prefer not to say", "Non-smoker", "Social smoker", "Regular smoker", "Trying to quit"]
    let drinkingOptions = ["Prefer not to say", "Non-drinker", "Social drinker", "Regular drinker"]
    let petsOptions = ["Prefer not to say", "No pets", "Dog", "Cat", "Dog & Cat", "Other pets"]
    let exerciseOptions = ["Prefer not to say", "Never", "Sometimes", "Often", "Daily"]
    let dietOptions = ["Prefer not to say", "Anything", "Vegetarian", "Vegan", "Pescatarian", "Halal", "Kosher", "Other"]
    let predefinedLanguages = [
        "English", "Spanish", "French", "German", "Italian", "Portuguese",
        "Russian", "Chinese", "Japanese", "Korean", "Arabic", "Hindi"
    ]
    let predefinedInterests = [
        "Travel", "Music", "Movies", "Sports", "Food", "Art",
        "Photography", "Reading", "Gaming", "Fitness", "Cooking",
        "Dancing", "Nature", "Technology", "Fashion", "Yoga"
    ]

    // MARK: - Initialization

    init(user: User? = nil) {
        let currentUser = user ?? AuthService.shared.currentUser

        // Initialize basic info
        self.fullName = currentUser?.fullName ?? ""
        self.age = "\(currentUser?.age ?? 18)"
        self.bio = currentUser?.bio ?? ""
        self.location = currentUser?.location ?? ""
        self.country = currentUser?.country ?? ""
        self.gender = currentUser?.gender ?? "Other"
        self.lookingFor = currentUser?.lookingFor ?? "Everyone"

        // Initialize collections
        self.languages = currentUser?.languages ?? []
        self.interests = currentUser?.interests ?? []
        self.prompts = currentUser?.prompts ?? []
        self.photos = currentUser?.photos ?? []

        // Initialize advanced fields
        self.height = currentUser?.height
        self.religion = currentUser?.religion
        self.relationshipGoal = currentUser?.relationshipGoal
        self.smoking = currentUser?.smoking
        self.drinking = currentUser?.drinking
        self.pets = currentUser?.pets
        self.exercise = currentUser?.exercise
        self.diet = currentUser?.diet
    }

    // MARK: - Computed Properties

    var isFormValid: Bool {
        // CODE QUALITY FIX: Removed force unwrapping - use optional chaining
        !fullName.isEmpty &&
        (Int(age) ?? 0) >= 18 &&
        !location.isEmpty &&
        !country.isEmpty
    }

    var completionProgress: Double {
        var completed: Double = 0
        let total: Double = 7

        if !fullName.isEmpty { completed += 1 }
        if (Int(age) ?? 0) >= 18 { completed += 1 }
        if !bio.isEmpty { completed += 1 }
        if !interests.isEmpty { completed += 1 }
        if !languages.isEmpty { completed += 1 }
        if !photos.isEmpty { completed += 1 }
        if !prompts.isEmpty { completed += 1 }

        return completed / total
    }

    // MARK: - Actions

    func addLanguage(_ language: String) {
        guard !language.isEmpty, !languages.contains(language) else { return }
        languages.append(language)
        newLanguage = ""
        showLanguagePicker = false
    }

    func removeLanguage(_ language: String) {
        languages.removeAll { $0 == language }
    }

    func addInterest(_ interest: String) {
        guard !interest.isEmpty, !interests.contains(interest), interests.count < 10 else { return }
        interests.append(interest)
        newInterest = ""
        showInterestPicker = false
    }

    func removeInterest(_ interest: String) {
        interests.removeAll { $0 == interest }
    }

    func saveProfile(authService: AuthService, completion: @escaping () -> Void) async {
        guard isFormValid else {
            errorMessage = "Please fill in all required fields"
            showErrorAlert = true
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Upload profile image if selected
            if let image = profileImage {
                let imageURL = try await uploadProfileImage(image, authService: authService)
                await updateUserProfile(authService: authService, profileImageURL: imageURL)
            } else {
                await updateUserProfile(authService: authService, profileImageURL: nil)
            }

            showSuccessAlert = true
            HapticManager.shared.notification(.success)

            // Delay dismissal to show success message
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            completion()

        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
            HapticManager.shared.notification(.error)
        }
    }

    // MARK: - Private Helpers

    private func uploadProfileImage(_ image: UIImage, authService: AuthService) async throws -> String {
        guard let userId = authService.currentUser?.id else {
            throw NSError(domain: "EditProfile", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }

        // ImageUploadService.uploadImage expects a directory path
        // It will append its own UUID filename to the path
        return try await ImageUploadService.shared.uploadImage(
            image,
            path: "profile_images/\(userId)"
        )
    }

    private func updateUserProfile(authService: AuthService, profileImageURL: String?) async {
        guard let userId = authService.currentUser?.id else { return }

        var updateData: [String: Any] = [
            "fullName": fullName,
            "age": Int(age) ?? 18,
            "bio": bio,
            "location": location,
            "country": country,
            "gender": gender,
            "lookingFor": lookingFor,
            "languages": languages,
            "interests": interests,
            "prompts": prompts.map { $0.toDictionary() },
            "photos": photos
        ]

        // Add optional fields if present
        if let profileImageURL = profileImageURL {
            updateData["profileImageURL"] = profileImageURL
        }
        if let height = height {
            updateData["height"] = height
        }
        if let religion = religion {
            updateData["religion"] = religion
        }
        if let relationshipGoal = relationshipGoal {
            updateData["relationshipGoal"] = relationshipGoal
        }
        if let smoking = smoking {
            updateData["smoking"] = smoking
        }
        if let drinking = drinking {
            updateData["drinking"] = drinking
        }
        if let pets = pets {
            updateData["pets"] = pets
        }
        if let exercise = exercise {
            updateData["exercise"] = exercise
        }
        if let diet = diet {
            updateData["diet"] = diet
        }

        do {
            try await UserService.shared.updateUserFields(userId: userId, fields: updateData)
        } catch {
            errorMessage = "Failed to update profile: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }
}
