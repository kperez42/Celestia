//
//  EditProfileView.swift
//  Celestia
//
//  Created by Kevin Perez on 10/29/25.
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    
    @State private var fullName: String
    @State private var age: String
    @State private var bio: String
    @State private var location: String
    @State private var country: String
    // REMOVED: occupation, education, height, relationshipGoal (not in User model)
    @State private var languages: [String]
    @State private var interests: [String]
    
    @State private var newLanguage = ""
    @State private var newInterest = ""
    @State private var isLoading = false
    @State private var showImagePicker = false
    @State private var selectedImage: PhotosPickerItem?
    @State private var profileImage: UIImage?
    
    init() {
        let user = AuthService.shared.currentUser
        _fullName = State(initialValue: user?.fullName ?? "")
        _age = State(initialValue: "\(user?.age ?? 18)")
        _bio = State(initialValue: user?.bio ?? "")
        _location = State(initialValue: user?.location ?? "")
        _country = State(initialValue: user?.country ?? "")
        _languages = State(initialValue: user?.languages ?? [])
        _interests = State(initialValue: user?.interests ?? [])
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
                    // Profile image
                    VStack {
                        if let profileImage = profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                        } else if let imageURL = URL(string: authService.currentUser?.profileImageURL ?? ""), !authService.currentUser!.profileImageURL.isEmpty {
                            AsyncImage(url: imageURL) { image in
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
                                .fill(
                                    LinearGradient(
                                        colors: [.purple.opacity(0.6), .pink.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                                .overlay {
                                    Text(fullName.prefix(1))
                                        .font(.system(size: 50, weight: .bold))
                                        .foregroundColor(.white)
                                }
                        }
                        
                        PhotosPicker(selection: $selectedImage, matching: .images) {
                            Text("Change Photo")
                                .font(.subheadline)
                                .foregroundColor(.purple)
                        }
                        .onChange(of: selectedImage) { _, newValue in
                            Task {
                                if let data = try? await newValue?.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    profileImage = uiImage
                                }
                            }
                        }
                    }
                    .padding(.top, 20)
                    
                    // Form fields
                    VStack(spacing: 20) {
                        // Basic info
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Full Name")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            TextField("Full Name", text: $fullName)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Age")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            TextField("Age", text: $age)
                                .keyboardType(.numberPad)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bio")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            TextEditor(text: $bio)
                                .frame(height: 100)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("City")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            TextField("City", text: $location)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Country")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            TextField("Country", text: $country)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }
                        
                        // Languages
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Languages")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            HStack {
                                TextField("Add language", text: $newLanguage)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                
                                Button {
                                    if !newLanguage.isEmpty {
                                        languages.append(newLanguage)
                                        newLanguage = ""
                                    }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.purple)
                                }
                            }
                            
                            FlowLayout(spacing: 8) {
                                ForEach(languages, id: \.self) { language in
                                    HStack {
                                        Text(language)
                                        Button {
                                            languages.removeAll { $0 == language }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.purple.opacity(0.1))
                                    .foregroundColor(.purple)
                                    .cornerRadius(20)
                                }
                            }
                        }
                        
                        // Interests
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Interests")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            HStack {
                                TextField("Add interest", text: $newInterest)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                
                                Button {
                                    if !newInterest.isEmpty {
                                        interests.append(newInterest)
                                        newInterest = ""
                                    }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.pink)
                                }
                            }
                            
                            FlowLayout(spacing: 8) {
                                ForEach(interests, id: \.self) { interest in
                                    HStack {
                                        Text(interest)
                                        Button {
                                            interests.removeAll { $0 == interest }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.pink.opacity(0.1))
                                    .foregroundColor(.pink)
                                    .cornerRadius(20)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Save button
                    Button {
                        saveProfile()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 55)
                                .background(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(15)
                        } else {
                            Text("Save Changes")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 55)
                                .background(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(15)
                        }
                    }
                    .disabled(isLoading)
                    .padding(.horizontal)
                    .padding(.bottom, 30)
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
            }
        }
    }
    
    private func saveProfile() {
        guard var user = authService.currentUser else { return }
        guard let ageInt = Int(age) else { return }
        
        isLoading = true
        
        Task {
            // Upload profile image if changed
            if let profileImage = profileImage, let userId = user.id {
                do {
                    let imageURL = try await ImageUploadService.shared.uploadProfileImage(profileImage, userId: userId)
                    user.profileImageURL = imageURL
                } catch {
                    print("Error uploading image: \(error)")
                }
            }
            
            // Update user data (only fields that exist in User model)
            user.fullName = fullName
            user.age = ageInt
            user.bio = bio
            user.location = location
            user.country = country
            user.languages = languages
            user.interests = interests
            
            do {
                try await authService.updateUser(user)
                isLoading = false
                dismiss()
            } catch {
                isLoading = false
                print("Error updating profile: \(error)")
            }
        }
    }
}

#Preview {
    EditProfileView()
        .environmentObject(AuthService.shared)
}
