//
//  ProfileEditView.swift
//  Celestia
//
//  Edit profile information
//

import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService  // Changed from AuthViewModel
    @StateObject private var viewModel = ProfileEditViewModel()
    
    @State private var name: String = ""
    @State private var age: String = ""
    @State private var bio: String = ""
    @State private var location: String = ""
    @State private var country: String = ""
    @State private var selectedLanguages: Set<String> = []
    @State private var selectedInterests: Set<String> = []
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var isSaving = false
    
    let availableLanguages = [
        "English", "Spanish", "French", "German", "Italian",
        "Portuguese", "Russian", "Chinese", "Japanese", "Korean",
        "Arabic", "Hindi", "Turkish", "Dutch", "Polish"
    ]
    
    let availableInterests = [
        "Travel", "Music", "Movies", "Sports", "Food",
        "Art", "Photography", "Reading", "Gaming", "Fitness",
        "Cooking", "Dancing", "Nature", "Technology", "Fashion"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                // Profile Photo Section
                Section("Profile Photo") {
                    HStack {
                        Spacer()
                        VStack {
                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                            // PERFORMANCE: Use CachedAsyncImage
                            } else if let profileURL = authService.currentUser?.profileImageURL,
                                      !profileURL.isEmpty {
                                CachedAsyncImage(url: URL(string: profileURL)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 50))
                                            .foregroundColor(.white)
                                    )
                            }
                            
                            Button("Change Photo") {
                                showImagePicker = true
                            }
                            .buttonStyle(.bordered)
                        }
                        Spacer()
                    }
                }
                
                // Basic Info Section
                Section("Basic Information") {
                    TextField("Name", text: $name)
                    TextField("Age", text: $age)
                        .keyboardType(.numberPad)
                    TextField("Location (City)", text: $location)
                    TextField("Country", text: $country)
                }
                
                // Bio Section
                Section("About Me") {
                    TextEditor(text: $bio)
                        .frame(minHeight: 100)
                }
                .listRowBackground(Color.clear)
                
                // Languages Section
                Section("Languages I Speak") {
                    ForEach(availableLanguages, id: \.self) { language in
                        HStack {
                            Text(language)
                            Spacer()
                            if selectedLanguages.contains(language) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedLanguages.contains(language) {
                                selectedLanguages.remove(language)
                            } else {
                                selectedLanguages.insert(language)
                            }
                        }
                    }
                }
                
                // Interests Section
                Section("My Interests") {
                    ForEach(availableInterests, id: \.self) { interest in
                        HStack {
                            Text(interest)
                            Spacer()
                            if selectedInterests.contains(interest) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedInterests.contains(interest) {
                                selectedInterests.remove(interest)
                            } else {
                                selectedInterests.insert(interest)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(isSaving)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
            .onAppear {
                loadCurrentUserData()
            }
        }
    }
    
    private func loadCurrentUserData() {
        guard let user = authService.currentUser else { return }
        
        name = user.fullName
        age = "\(user.age)"
        bio = user.bio
        location = user.location
        country = user.country
        selectedLanguages = Set(user.languages)
        selectedInterests = Set(user.interests)
    }
    
    private func saveProfile() {
        guard let user = authService.currentUser,
              let ageInt = Int(age),
              ageInt >= 18 else {
            return
        }
        
        isSaving = true
        
        Task {
            do {
                // Upload photo if selected
                var profileImageURL = user.profileImageURL
                if let image = selectedImage {
                    profileImageURL = try await viewModel.uploadProfileImage(image, userId: user.id ?? "")
                }
                
                // Update user data
                try await viewModel.updateProfile(
                    userId: user.id ?? "",
                    name: name,
                    age: ageInt,
                    bio: bio,
                    location: location,
                    country: country,
                    languages: Array(selectedLanguages),
                    interests: Array(selectedInterests),
                    profileImageURL: profileImageURL
                )
                
                // Reload user data
                await authService.fetchUser()
                
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                Logger.shared.error("Error saving profile", category: .general, error: error)
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

#Preview {
    ProfileEditView()
        .environmentObject(AuthService.shared)
}
