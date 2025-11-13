//
//  EditProfileView.swift
//  Celestia
//
//  Enhanced profile editing with beautiful UI and better UX
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
    @State private var gender: String
    @State private var lookingFor: String
    @State private var languages: [String]
    @State private var interests: [String]
    @State private var prompts: [ProfilePrompt]

    @State private var newLanguage = ""
    @State private var newInterest = ""
    @State private var isLoading = false
    @State private var showImagePicker = false
    @State private var selectedImage: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showLanguagePicker = false
    @State private var showInterestPicker = false
    @State private var showPromptsEditor = false
    @State private var photos: [String] = []
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isUploadingPhotos = false
    @State private var uploadProgress: Double = 0.0

    // Advanced profile fields
    @State private var height: Int?
    @State private var religion: String?
    @State private var relationshipGoal: String?
    @State private var smoking: String?
    @State private var drinking: String?
    @State private var pets: String?
    @State private var exercise: String?
    @State private var diet: String?

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
    
    init() {
        let user = AuthService.shared.currentUser
        _fullName = State(initialValue: user?.fullName ?? "")
        _age = State(initialValue: "\(user?.age ?? 18)")
        _bio = State(initialValue: user?.bio ?? "")
        _location = State(initialValue: user?.location ?? "")
        _country = State(initialValue: user?.country ?? "")
        _gender = State(initialValue: user?.gender ?? "Other")
        _lookingFor = State(initialValue: user?.lookingFor ?? "Everyone")
        _languages = State(initialValue: user?.languages ?? [])
        _interests = State(initialValue: user?.interests ?? [])
        _prompts = State(initialValue: user?.prompts ?? [])
        _photos = State(initialValue: user?.photos ?? [])

        // Initialize advanced profile fields
        _height = State(initialValue: user?.height)
        _religion = State(initialValue: user?.religion)
        _relationshipGoal = State(initialValue: user?.relationshipGoal)
        _smoking = State(initialValue: user?.smoking)
        _drinking = State(initialValue: user?.drinking)
        _pets = State(initialValue: user?.pets)
        _exercise = State(initialValue: user?.exercise)
        _diet = State(initialValue: user?.diet)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 25) {
                        // Hero Profile Photo Section
                        profilePhotoSection

                        // Photo Gallery Section
                        photoGallerySection

                        // Progress Indicator
                        profileCompletionProgress

                        // Basic Info Card
                        basicInfoSection
                        
                        // About Me Card
                        aboutMeSection
                        
                        // Preferences Card
                        preferencesSection

                        // Lifestyle & More Section
                        lifestyleSection

                        // Languages Card
                        languagesSection
                        
                        // Interests Card
                        interestsSection

                        // Prompts Card
                        promptsSection

                        // Save Button
                        saveButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                            Text("Cancel")
                        }
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    }
                }
            }
            .alert("Success! 🎉", isPresented: $showSuccessAlert) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Your profile has been updated successfully!")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showLanguagePicker) {
                LanguagePickerView(
                    selectedLanguages: $languages,
                    availableLanguages: predefinedLanguages
                )
            }
            .sheet(isPresented: $showInterestPicker) {
                InterestPickerView(
                    selectedInterests: $interests,
                    availableInterests: predefinedInterests
                )
            }
            .sheet(isPresented: $showPromptsEditor) {
                ProfilePromptsEditorView(prompts: $prompts)
            }
        }
    }
    
    // MARK: - Profile Photo Section
    
    private var profilePhotoSection: some View {
        VStack(spacing: 15) {
            ZStack(alignment: .bottomTrailing) {
                // Profile Image
                Group {
                    if let profileImage = profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFill()
                    } else if let currentUser = authService.currentUser,
                              let imageURL = URL(string: currentUser.profileImageURL),
                              !currentUser.profileImageURL.isEmpty {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            default:
                                placeholderImage
                            }
                        }
                    } else {
                        placeholderImage
                    }
                }
                .frame(width: 140, height: 140)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                }
                .shadow(color: .purple.opacity(0.3), radius: 15, y: 8)
                
                // Camera button
                PhotosPicker(selection: $selectedImage, matching: .images) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 44, height: 44)
                            .shadow(color: .black.opacity(0.2), radius: 5)
                        
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                }
                .offset(x: 5, y: 5)
            }
            .onChange(of: selectedImage) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        profileImage = uiImage
                    }
                }
            }
            
            Text("Change Profile Photo")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }
    
    private var placeholderImage: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.purple.opacity(0.6), .pink.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                if !fullName.isEmpty {
                    Text(fullName.prefix(1).uppercased())
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
    }

    // MARK: - Photo Gallery Section

    private var photoGallerySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Photo Gallery")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Add up to 6 photos")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Upload progress indicator
                if isUploadingPhotos {
                    HStack(spacing: 8) {
                        ProgressView(value: uploadProgress)
                            .frame(width: 50)
                        Text("\(Int(uploadProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Photo grid with drag-and-drop reordering
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, photoURL in
                    PhotoGridItem(
                        photoURL: photoURL,
                        onDelete: {
                            deletePhoto(at: index)
                        },
                        onMoveUp: index > 0 ? {
                            movePhoto(from: index, to: index - 1)
                        } : nil,
                        onMoveDown: index < photos.count - 1 ? {
                            movePhoto(from: index, to: index + 1)
                        } : nil
                    )
                }

                // Add photo button
                if photos.count < 6 {
                    PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 6 - photos.count, matching: .images) {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.purple.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
                            .frame(height: 120)
                            .overlay {
                                VStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.purple)
                                    Text("Add Photo")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        .onChange(of: selectedPhotoItems) { _, newItems in
            Task {
                await uploadNewPhotos(newItems)
            }
        }
    }

    // MARK: - Profile Completion Progress
    
    private var profileCompletionProgress: some View {
        let progress = calculateProgress()
        
        return VStack(spacing: 12) {
            HStack {
                Text("Profile Completion")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 8)
                        .animation(.spring(response: 0.5), value: progress)
                }
            }
            .frame(height: 8)
            
            if progress < 1.0 {
                Text(getProgressTip())
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }
    
    // MARK: - Basic Info Section

    private var basicInfoSection: some View {
        VStack(spacing: 20) {
            SectionHeader(icon: "person.fill", title: "Basic Information", color: .purple)

            // Full Name (Required)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text("Full Name")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text("*")
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
                TextField("Enter your name", text: $fullName)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(fullName.isEmpty ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            }

            // Age (Required)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text("Age")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text("*")
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
                TextField("18", text: $age)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke((Int(age) ?? 0) < 18 ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                if !age.isEmpty && (Int(age) ?? 0) < 18 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("You must be at least 18 years old")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Gender Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Gender")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Picker("Gender", selection: $gender) {
                    ForEach(genderOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Location and Country (Required)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Text("City")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Text("*")
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }
                    TextField("Los Angeles", text: $location)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(location.isEmpty ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Text("Country")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Text("*")
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }
                    TextField("USA", text: $country)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(country.isEmpty ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }
    
    // MARK: - About Me Section
    
    private var aboutMeSection: some View {
        VStack(spacing: 15) {
            SectionHeader(icon: "quote.bubble.fill", title: "About Me", color: .blue)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Bio")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Spacer()

                    // Character counter with color coding
                    Text("\(bio.count)/500")
                        .font(.caption)
                        .fontWeight(bio.count >= 400 ? .semibold : .regular)
                        .foregroundColor(
                            bio.count >= 500 ? .red :
                            bio.count >= 450 ? .orange :
                            bio.count >= 400 ? .yellow :
                            .gray
                        )
                }
                
                TextEditor(text: $bio)
                    .frame(minHeight: 120)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .onChange(of: bio) { _, newValue in
                        if newValue.count > 500 {
                            bio = String(newValue.prefix(500))
                        }
                    }
                
                Text("Tell others what makes you unique")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }
    
    // MARK: - Preferences Section

    private var preferencesSection: some View {
        VStack(spacing: 15) {
            SectionHeader(icon: "heart.fill", title: "Dating Preferences", color: .pink)

            VStack(alignment: .leading, spacing: 8) {
                Text("Looking for")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Picker("Looking for", selection: $lookingFor) {
                    ForEach(lookingForOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Lifestyle Section

    private var lifestyleSection: some View {
        VStack(spacing: 20) {
            SectionHeader(icon: "person.crop.circle.fill", title: "Lifestyle & More", color: .orange)

            // Height
            VStack(alignment: .leading, spacing: 8) {
                Text("Height")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                HStack {
                    TextField("e.g., 170", value: $height, format: .number)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                    Text("cm")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                }

                if let h = height {
                    Text("≈ \(heightToFeetInches(h))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            // Relationship Goal
            VStack(alignment: .leading, spacing: 8) {
                Text("Relationship Goal")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Picker("Relationship Goal", selection: Binding(
                    get: { relationshipGoal ?? "Prefer not to say" },
                    set: { relationshipGoal = $0 == "Prefer not to say" ? nil : $0 }
                )) {
                    ForEach(relationshipGoalOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            // Religion
            VStack(alignment: .leading, spacing: 8) {
                Text("Religion")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Picker("Religion", selection: Binding(
                    get: { religion ?? "Prefer not to say" },
                    set: { religion = $0 == "Prefer not to say" ? nil : $0 }
                )) {
                    ForEach(religionOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            // Smoking & Drinking Row
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Smoking")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Picker("Smoking", selection: Binding(
                        get: { smoking ?? "Prefer not to say" },
                        set: { smoking = $0 == "Prefer not to say" ? nil : $0 }
                    )) {
                        ForEach(smokingOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Drinking")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Picker("Drinking", selection: Binding(
                        get: { drinking ?? "Prefer not to say" },
                        set: { drinking = $0 == "Prefer not to say" ? nil : $0 }
                    )) {
                        ForEach(drinkingOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }

            // Exercise & Diet Row
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Exercise")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Picker("Exercise", selection: Binding(
                        get: { exercise ?? "Prefer not to say" },
                        set: { exercise = $0 == "Prefer not to say" ? nil : $0 }
                    )) {
                        ForEach(exerciseOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Diet")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Picker("Diet", selection: Binding(
                        get: { diet ?? "Prefer not to say" },
                        set: { diet = $0 == "Prefer not to say" ? nil : $0 }
                    )) {
                        ForEach(dietOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }

            // Pets
            VStack(alignment: .leading, spacing: 8) {
                Text("Pets")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Picker("Pets", selection: Binding(
                    get: { pets ?? "Prefer not to say" },
                    set: { pets = $0 == "Prefer not to say" ? nil : $0 }
                )) {
                    ForEach(petsOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Languages Section
    
    private var languagesSection: some View {
        VStack(spacing: 15) {
            HStack {
                SectionHeader(icon: "globe", title: "Languages", color: .purple)
                
                Spacer()
                
                Button {
                    showLanguagePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }
            }
            
            if languages.isEmpty {
                EmptyStateView(
                    icon: "globe",
                    message: "Add languages you speak",
                    action: { showLanguagePicker = true }
                )
            } else {
                FlowLayoutImproved(spacing: 10) {
                    ForEach(languages, id: \.self) { language in
                        TagChip(
                            text: language,
                            color: .purple,
                            onRemove: { languages.removeAll { $0 == language } }
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }
    
    // MARK: - Interests Section
    
    private var interestsSection: some View {
        VStack(spacing: 15) {
            HStack {
                SectionHeader(icon: "star.fill", title: "Interests", color: .pink)
                
                Spacer()
                
                Button {
                    showInterestPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }
            }
            
            if interests.isEmpty {
                EmptyStateView(
                    icon: "star.fill",
                    message: "Add your interests",
                    action: { showInterestPicker = true }
                )
            } else {
                FlowLayoutImproved(spacing: 10) {
                    ForEach(interests, id: \.self) { interest in
                        TagChip(
                            text: interest,
                            color: .pink,
                            onRemove: { interests.removeAll { $0 == interest } }
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }
    
    // MARK: - Prompts Section

    private var promptsSection: some View {
        VStack(spacing: 15) {
            HStack {
                SectionHeader(icon: "quote.bubble.fill", title: "Profile Prompts", color: .purple)

                Spacer()

                Button {
                    showPromptsEditor = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: prompts.isEmpty ? "plus.circle.fill" : "pencil.circle.fill")
                        Text(prompts.isEmpty ? "Add" : "Edit")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }
            }

            if prompts.isEmpty {
                EmptyStateView(
                    icon: "quote.bubble.fill",
                    message: "Add prompts to showcase your personality",
                    action: { showPromptsEditor = true }
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(prompts) { prompt in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(prompt.question)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)

                            Text(prompt.answer)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.05), Color.pink.opacity(0.03)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                    }

                    Text("\(prompts.count)/3 prompts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            saveProfile()
        } label: {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                        Text("Save Changes")
                            .font(.headline)
                    }
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [.purple, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: .purple.opacity(0.4), radius: 15, y: 8)
        }
        .disabled(isLoading || !isFormValid)
        .opacity(isFormValid ? 1.0 : 0.6)
        .scaleButton()
        .padding(.bottom, 30)
    }

    // MARK: - Helper Functions
    
    private var isFormValid: Bool {
        !fullName.isEmpty &&
        Int(age) != nil &&
        Int(age)! >= 18 &&
        !location.isEmpty &&
        !country.isEmpty
    }
    
    private func calculateProgress() -> Double {
        var completed: Double = 0
        let total: Double = 7
        
        if !fullName.isEmpty { completed += 1 }
        if Int(age) ?? 0 >= 18 { completed += 1 }
        if !bio.isEmpty { completed += 1 }
        if !location.isEmpty && !country.isEmpty { completed += 1 }
        if !languages.isEmpty { completed += 1 }
        if interests.count >= 3 { completed += 1 }
        if profileImage != nil || !(authService.currentUser?.profileImageURL ?? "").isEmpty { completed += 1 }
        
        return completed / total
    }
    
    private func getProgressTip() -> String {
        if fullName.isEmpty { return "💡 Add your name" }
        if bio.isEmpty { return "💡 Write a bio to stand out" }
        if languages.isEmpty { return "💡 Add languages you speak" }
        if interests.count < 3 { return "💡 Add at least 3 interests" }
        if profileImage == nil && (authService.currentUser?.profileImageURL ?? "").isEmpty {
            return "💡 Add a profile photo"
        }
        return "Almost there!"
    }

    private func heightToFeetInches(_ cm: Int) -> String {
        let totalInches = Double(cm) / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
        return "\(feet)'\(inches)\""
    }
    
    private func saveProfile() {
        guard var user = authService.currentUser else { return }
        guard let ageInt = Int(age), ageInt >= 18 else {
            errorMessage = "Please enter a valid age (18+)"
            showErrorAlert = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // Upload profile image if changed
                if let profileImage = profileImage, let userId = user.id {
                    let imageURL = try await ImageUploadService.shared.uploadProfileImage(profileImage, userId: userId)
                    user.profileImageURL = imageURL
                }
                
                // Update user data
                user.fullName = fullName
                user.age = ageInt
                user.bio = bio
                user.location = location
                user.country = country
                user.gender = gender
                user.lookingFor = lookingFor
                user.languages = languages
                user.interests = interests
                user.prompts = prompts
                user.photos = photos

                // Update advanced profile fields
                user.height = height
                user.religion = religion
                user.relationshipGoal = relationshipGoal
                user.smoking = smoking
                user.drinking = drinking
                user.pets = pets
                user.exercise = exercise
                user.diet = diet

                try await authService.updateUser(user)
                
                await MainActor.run {
                    isLoading = false
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to save changes. Please try again."
                    showErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(title)
                .font(.headline)
            
            Spacer()
        }
    }
}

struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .padding(14)
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
}

struct TagChip: View {
    let text: String
    let color: Color
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(20)
    }
}

struct EmptyStateView: View {
    let icon: String
    let message: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(.gray.opacity(0.5))
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Language Picker Sheet

struct LanguagePickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedLanguages: [String]
    let availableLanguages: [String]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(availableLanguages, id: \.self) { language in
                    Button {
                        if selectedLanguages.contains(language) {
                            selectedLanguages.removeAll { $0 == language }
                        } else {
                            selectedLanguages.append(language)
                        }
                    } label: {
                        HStack {
                            Text(language)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedLanguages.contains(language) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.purple, .pink],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Languages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Interest Picker Sheet

struct InterestPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedInterests: [String]
    let availableInterests: [String]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(availableInterests, id: \.self) { interest in
                    Button {
                        if selectedInterests.contains(interest) {
                            selectedInterests.removeAll { $0 == interest }
                        } else {
                            selectedInterests.append(interest)
                        }
                    } label: {
                        HStack {
                            Text(interest)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedInterests.contains(interest) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.pink, .orange],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Interests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Photo Management Functions

    private func deletePhoto(at index: Int) {
        withAnimation {
            photos.remove(at: index)
        }
        HapticManager.shared.impact(.medium)
    }

    private func movePhoto(from source: Int, to destination: Int) {
        withAnimation {
            let photo = photos.remove(at: source)
            photos.insert(photo, at: destination)
        }
        HapticManager.shared.impact(.light)
    }

    private func uploadNewPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

        await MainActor.run {
            isUploadingPhotos = true
            uploadProgress = 0.0
        }

        for (index, item) in items.enumerated() {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {

                    // Update progress
                    await MainActor.run {
                        uploadProgress = Double(index) / Double(items.count)
                    }

                    // Upload to Firebase Storage
                    if let userId = authService.currentUser?.id {
                        let photoURL = try await PhotoUploadService.shared.uploadPhoto(
                            uiImage,
                            userId: userId,
                            imageType: .gallery
                        )

                        await MainActor.run {
                            photos.append(photoURL)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to upload photo: \(error.localizedDescription)"
                    showErrorAlert = true
                }
                Logger.shared.error("Photo upload failed: \(error.localizedDescription)", category: .general)
            }
        }

        await MainActor.run {
            uploadProgress = 1.0
            isUploadingPhotos = false
            selectedPhotoItems = []
        }
    }
}

// MARK: - Photo Grid Item

struct PhotoGridItem: View {
    let photoURL: String
    let onDelete: () -> Void
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?

    @State private var showDeleteConfirmation = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Photo
            AsyncImage(url: URL(string: photoURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        }
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .overlay {
                            ProgressView()
                        }
                @unknown default:
                    EmptyView()
                }
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Controls overlay
            VStack(spacing: 4) {
                // Delete button
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                        }
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                }

                // Reorder buttons
                if onMoveUp != nil || onMoveDown != nil {
                    VStack(spacing: 2) {
                        if let moveUp = onMoveUp {
                            Button(action: moveUp) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 24, height: 24)
                                    .overlay {
                                        Image(systemName: "chevron.up")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.purple)
                                    }
                                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                            }
                        }

                        if let moveDown = onMoveDown {
                            Button(action: moveDown) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 24, height: 24)
                                    .overlay {
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.purple)
                                    }
                                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                            }
                        }
                    }
                }
            }
            .padding(6)
        }
        .confirmationDialog("Delete this photo?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Improved Flow Layout

struct FlowLayoutImproved: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + result.frames[index].minX,
                    y: bounds.minY + result.frames[index].minY
                ),
                proposal: .unspecified
            )
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

#Preview {
    EditProfileView()
        .environmentObject(AuthService.shared)
}
