//
//  EditProfileView.swift
//  Celestia
//
//  Enhanced profile editing with beautiful UI and better UX
//

import SwiftUI
import PhotosUI
import FirebaseAuth
import UniformTypeIdentifiers

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
    @State private var isUploadingProfilePhoto = false
    @State private var uploadingPhotoCount = 0
    @State private var draggingPhotoURL: String?

    // Store user ID to ensure it's available during uploads
    @State private var userId: String = ""

    // Network monitoring for upload operations
    @ObservedObject var networkMonitor = NetworkMonitor.shared

    // Advanced profile fields
    @State private var educationLevel: String?
    @State private var height: Int?
    @State private var religion: String?
    @State private var relationshipGoal: String?
    @State private var smoking: String?
    @State private var drinking: String?
    @State private var pets: String?
    @State private var exercise: String?
    @State private var diet: String?

    // Preference fields
    @State private var ageRangeMin: Int
    @State private var ageRangeMax: Int
    @State private var maxDistance: Int

    let genderOptions = ["Male", "Female", "Non-binary", "Other"]
    let lookingForOptions = ["Men", "Women", "Everyone"]
    let educationOptions = ["Prefer not to say", "High School", "Some College", "Associate's", "Bachelor's", "Master's", "Doctorate", "Trade School"]
    let religionOptions = ["Prefer not to say", "Agnostic", "Atheist", "Buddhist", "Catholic", "Christian", "Hindu", "Jewish", "Muslim", "Spiritual", "Other"]
    let relationshipGoalOptions = ["Prefer not to say", "Casual Dating", "Long-term Relationship", "Marriage", "Friendship", "Not Sure Yet"]
    let smokingOptions = ["Prefer not to say", "Never", "Socially", "Regularly", "Trying to Quit"]
    let drinkingOptions = ["Prefer not to say", "Never", "Rarely", "Socially", "Regularly"]
    let petsOptions = ["Prefer not to say", "No Pets", "Dog", "Cat", "Both", "Other Pets", "Want Pets"]

    // Height options from 4'8" to 7'0" with cm values
    var heightOptionsForPicker: [(cm: Int, display: String)] {
        var options: [(cm: Int, display: String)] = []
        for feet in 4...7 {
            let maxInches = feet == 7 ? 0 : 11
            let minInches = feet == 4 ? 8 : 0
            for inches in minInches...maxInches {
                let totalInches = feet * 12 + inches
                let cm = Int(Double(totalInches) * 2.54)
                options.append((cm: cm, display: "\(feet)'\(inches)\""))
            }
        }
        return options
    }
    let exerciseOptions = ["Prefer not to say", "Never", "Rarely", "Sometimes", "Often", "Daily"]
    let dietOptions = ["Prefer not to say", "No Restrictions", "Vegan", "Vegetarian", "Pescatarian", "Kosher", "Halal"]
    let availableCountries = [
        "United States",
        "Canada",
        "Mexico",
        "United Kingdom",
        "Australia",
        "Germany",
        "France",
        "Spain",
        "Italy",
        "Brazil",
        "Argentina",
        "Japan",
        "South Korea",
        "China",
        "India",
        "Philippines",
        "Vietnam",
        "Thailand",
        "Netherlands",
        "Sweden",
        "Norway",
        "Denmark",
        "Switzerland",
        "Ireland",
        "New Zealand",
        "Singapore",
        "Other"
    ]
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

        // CRITICAL: Store user ID for uploads
        _userId = State(initialValue: user?.id ?? "")

        print("🔍 EditProfileView init - User ID: \(user?.id ?? "NIL")")
        print("🔍 EditProfileView init - Photos count: \(user?.photos.count ?? 0)")

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
        _educationLevel = State(initialValue: user?.educationLevel)
        _height = State(initialValue: user?.height)
        _religion = State(initialValue: user?.religion)
        _relationshipGoal = State(initialValue: user?.relationshipGoal)
        _smoking = State(initialValue: user?.smoking)
        _drinking = State(initialValue: user?.drinking)
        _pets = State(initialValue: user?.pets)
        _exercise = State(initialValue: user?.exercise)
        _diet = State(initialValue: user?.diet)

        // Initialize preference fields
        _ageRangeMin = State(initialValue: user?.ageRangeMin ?? 18)
        _ageRangeMax = State(initialValue: user?.ageRangeMax ?? 99)
        _maxDistance = State(initialValue: user?.maxDistance ?? 50)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // SECTION 1: Photos
                        // Hero Profile Photo + Discovery Photos combined
                        photosSection

                        // Progress Indicator - motivates users
                        profileCompletionProgress

                        // SECTION 2: Basic Info
                        // Name, Age, Gender, Location - essentials
                        basicInfoSection

                        // SECTION 3: About Me
                        // Bio - self expression
                        aboutMeSection

                        // SECTION 4: Dating Preferences
                        // Looking For, Age Range - what they want
                        preferencesSection

                        // SECTION 5: Personal Details
                        // Height, Education, Religion, Relationship Goal
                        personalDetailsSection

                        // SECTION 6: Lifestyle Habits
                        // Smoking, Drinking, Exercise, Diet, Pets
                        lifestyleHabitsSection

                        // SECTION 7: Express Yourself
                        // Languages & Interests combined
                        expressYourselfSection

                        // SECTION 8: Profile Prompts
                        // Personality showcase
                        promptsSection
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

                // SAVE BUTTON IN TOOLBAR
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveProfile()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .tint(.purple)
                        } else {
                            HStack(spacing: 4) {
                                Text("Save")
                                    .fontWeight(.semibold)
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
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
                    .disabled(isLoading || !isFormValid)
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
            .onAppear {
                // CRITICAL FIX: Refresh user ID when view appears
                // This ensures we have the latest user ID even if init happened before user data loaded
                if let currentUser = authService.currentUser,
                   let userIdValue = currentUser.id {
                    Logger.shared.info("✅ Refreshing user ID on appear: \(userIdValue)", category: .general)
                    userId = userIdValue
                    photos = currentUser.photos
                } else if let firebaseAuthId = Auth.auth().currentUser?.uid {
                    // Fallback: Use Firebase Auth UID directly
                    Logger.shared.info("✅ Using Firebase Auth UID: \(firebaseAuthId)", category: .general)
                    userId = firebaseAuthId
                } else {
                    Logger.shared.error("❌ No user ID available in onAppear!", category: .general)
                }

                Logger.shared.info("🔍 onAppear - Final userId: \(userId)", category: .general)
                Logger.shared.info("🔍 onAppear - Photos count: \(photos.count)", category: .general)
            }
        }
        .networkStatusBanner() // UX: Show offline status for photo uploads
    }

    // MARK: - Combined Photos Section

    private var photosSection: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                SectionHeader(icon: "camera.fill", title: "Your Photos", color: .purple)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Profile Photo - Main display photo
            VStack(spacing: 12) {
                HStack {
                    Text("Profile Photo")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Main display")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 20)

                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let profileImage = profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .scaledToFill()
                        } else if let currentUser = authService.currentUser,
                                  let imageURL = URL(string: currentUser.profileImageURL),
                                  !currentUser.profileImageURL.isEmpty {
                            CachedAsyncImage(
                                url: imageURL,
                                content: { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                },
                                placeholder: {
                                    profilePlaceholderImage
                                }
                            )
                        } else {
                            profilePlaceholderImage
                        }
                    }
                    .frame(width: 120, height: 120)
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
                    .shadow(color: .purple.opacity(0.25), radius: 12, y: 6)

                    PhotosPicker(selection: $selectedImage, matching: .images) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 38, height: 38)
                                .shadow(color: .black.opacity(0.15), radius: 4)

                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 34, height: 34)

                            if isUploadingProfilePhoto {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .disabled(isUploadingProfilePhoto)
                    .offset(x: 4, y: 4)
                }
            }

            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

            // Discovery Photos Grid
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Discovery Photos")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Text("Shown on your card in Discover")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    if isUploadingPhotos {
                        uploadProgressBadge
                    } else {
                        Text("\(photos.count)/6")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)

                // Photo Grid or Empty State
                if photos.isEmpty && uploadingPhotoCount == 0 {
                    emptyPhotosState
                        .padding(.horizontal, 20)
                } else {
                    discoveryPhotosGrid
                        .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        .onChange(of: selectedPhotoItems) { oldItems, newItems in
            Logger.shared.info("📸 Photo picker changed: \(oldItems.count) → \(newItems.count) items", category: .general)
            guard !newItems.isEmpty else { return }
            Task {
                await uploadNewPhotos(newItems)
            }
        }
    }

    private var profilePlaceholderImage: some View {
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
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
    }

    private var uploadProgressBadge: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.purple.opacity(0.2), lineWidth: 2)
                    .frame(width: 20, height: 20)
                Circle()
                    .trim(from: 0, to: uploadProgress)
                    .stroke(Color.purple, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(-90))
            }
            Text("\(Int(uploadProgress * 100))%")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.purple)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
    }

    private var emptyPhotosState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple.opacity(0.5), .pink.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Add photos to get more matches!")
                .font(.subheadline)
                .foregroundColor(.secondary)

            PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 6, matching: .images) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.subheadline)
                    Text("Add Photos")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var discoveryPhotosGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(Array(photos.enumerated()), id: \.element) { index, photoURL in
                DraggablePhotoGridItem(
                    photoURL: photoURL,
                    isDragging: draggingPhotoURL == photoURL,
                    onDelete: { deletePhoto(at: index) }
                )
                .id(photoURL)
                .onDrag {
                    draggingPhotoURL = photoURL
                    HapticManager.shared.impact(.medium)
                    return NSItemProvider(object: photoURL as NSString)
                }
                .onDrop(of: [.text], delegate: PhotoDropDelegate(
                    item: photoURL,
                    items: $photos,
                    draggingItem: $draggingPhotoURL,
                    onReorder: { savePhotoOrder() }
                ))
            }

            ForEach(0..<uploadingPhotoCount, id: \.self) { index in
                UploadingPhotoPlaceholder(index: index)
                    .transition(.opacity)
            }

            if photos.count + uploadingPhotoCount < 6 {
                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 6 - photos.count - uploadingPhotoCount, matching: .images) {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.purple.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .frame(height: 100)
                        .overlay {
                            VStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.title2)
                                    .foregroundColor(.purple.opacity(0.6))
                            }
                        }
                }
                .disabled(isUploadingPhotos)
                .opacity(isUploadingPhotos ? 0.5 : 1.0)
            }
        }
    }

    // MARK: - Profile Photo Section (Legacy - kept for reference)

    private var profilePhotoSection: some View {
        VStack(spacing: 15) {
            ZStack(alignment: .bottomTrailing) {
                // Profile Image - PERFORMANCE: Use CachedAsyncImage
                Group {
                    if let profileImage = profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFill()
                    } else if let currentUser = authService.currentUser,
                              let imageURL = URL(string: currentUser.profileImageURL),
                              !currentUser.profileImageURL.isEmpty {
                        CachedAsyncImage(
                            url: imageURL,
                            content: { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            },
                            placeholder: {
                                placeholderImage
                            }
                        )
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

                // Camera button with loading indicator
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

                        if isUploadingProfilePhoto {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(isUploadingProfilePhoto)
                .offset(x: 5, y: 5)
                .accessibilityLabel("Change profile photo")
                .accessibilityHint("Tap to select a new profile photo from your photo library")
            }
            .onChange(of: selectedImage) { _, newValue in
                Task {
                    await MainActor.run {
                        isUploadingProfilePhoto = true
                    }

                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await MainActor.run {
                            profileImage = uiImage
                            isUploadingProfilePhoto = false
                            HapticManager.shared.notification(.success)
                        }
                    } else {
                        await MainActor.run {
                            isUploadingProfilePhoto = false
                            HapticManager.shared.notification(.error)
                        }
                    }
                }
            }
            
            VStack(spacing: 4) {
                Text("Profile Photo")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("Shown on your Profile page")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
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
                    Text("Discovery Photos")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("These photos appear on your card in Discover, Likes & Saved")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Enhanced upload progress indicator with circular animation
                if isUploadingPhotos {
                    HStack(spacing: 12) {
                        // Circular progress indicator
                        ZStack {
                            // Background circle
                            Circle()
                                .stroke(Color.purple.opacity(0.2), lineWidth: 4)
                                .frame(width: 44, height: 44)

                            // Progress circle
                            Circle()
                                .trim(from: 0, to: uploadProgress)
                                .stroke(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                )
                                .frame(width: 44, height: 44)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 0.5), value: uploadProgress)

                            // Spinning animation while uploading
                            if uploadProgress < 1.0 {
                                Circle()
                                    .trim(from: 0, to: 0.2)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 4)
                                    .frame(width: 44, height: 44)
                                    .rotationEffect(.degrees(uploadProgress * 360))
                            }

                            // Percentage text
                            Text("\(Int(uploadProgress * 100))%")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.purple)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 4) {
                                // Animated dots
                                Text("Uploading")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.purple)

                                ForEach(0..<3, id: \.self) { index in
                                    Circle()
                                        .fill(Color.purple)
                                        .frame(width: 3, height: 3)
                                        .opacity(uploadProgress * 3 > Double(index) ? 1.0 : 0.3)
                                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(Double(index) * 0.2), value: uploadProgress)
                                }
                            }

                            Text("\(photos.count)/\(photos.count + uploadingPhotoCount) uploaded")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.purple.opacity(0.15))
                            .shadow(color: .purple.opacity(0.2), radius: 8, x: 0, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                LinearGradient(
                                    colors: [.purple.opacity(0.3), .pink.opacity(0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .transition(.opacity)
                    .animation(.quick, value: isUploadingPhotos)
                }
            }

            // Empty state or photo grid
            if photos.isEmpty && uploadingPhotoCount == 0 {
                // Empty state with helpful message
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple.opacity(0.6), .pink.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    VStack(spacing: 6) {
                        Text("No Photos Yet")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("Add up to 6 photos to showcase yourself.\nPhotos help you get more matches!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 6, matching: .images) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Your First Photo")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Photo grid with long-press drag-and-drop reordering
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Array(photos.enumerated()), id: \.element) { index, photoURL in
                        DraggablePhotoGridItem(
                            photoURL: photoURL,
                            isDragging: draggingPhotoURL == photoURL,
                            onDelete: {
                                deletePhoto(at: index)
                            }
                        )
                        .id(photoURL)
                        .onDrag {
                            draggingPhotoURL = photoURL
                            HapticManager.shared.impact(.medium)
                            return NSItemProvider(object: photoURL as NSString)
                        }
                        .onDrop(of: [.text], delegate: PhotoDropDelegate(
                            item: photoURL,
                            items: $photos,
                            draggingItem: $draggingPhotoURL,
                            onReorder: { savePhotoOrder() }
                        ))
                    }

                    // Show uploading placeholders with instant appearance
                    ForEach(0..<uploadingPhotoCount, id: \.self) { index in
                        UploadingPhotoPlaceholder(index: index)
                            .transition(.opacity)
                    }

                    // Add photo button
                    if photos.count + uploadingPhotoCount < 6 {
                        PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 6 - photos.count - uploadingPhotoCount, matching: .images) {
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
                        .accessibilityLabel("Add gallery photo")
                        .accessibilityHint("Tap to add up to \(6 - photos.count - uploadingPhotoCount) more photos to your gallery")
                        .disabled(isUploadingPhotos)
                        .opacity(isUploadingPhotos ? 0.6 : 1.0)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        .onChange(of: selectedPhotoItems) { oldItems, newItems in
            Logger.shared.info("📸 Photo picker changed: \(oldItems.count) → \(newItems.count) items", category: .general)

            guard !newItems.isEmpty else {
                Logger.shared.warning("No photos selected", category: .general)
                return
            }

            Logger.shared.info("🚀 Triggering upload for \(newItems.count) photos", category: .general)

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
                    Menu {
                        ForEach(availableCountries, id: \.self) { countryOption in
                            Button(countryOption) {
                                country = countryOption
                            }
                        }
                    } label: {
                        HStack {
                            Text(country.isEmpty ? "Select Country" : country)
                                .foregroundColor(country.isEmpty ? .gray : .primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
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
        VStack(spacing: 20) {
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

            // Age Range Preference
            VStack(spacing: 16) {
                // Header with icon
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.pink.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "heart.circle.fill")
                            .font(.title3)
                            .foregroundColor(.pink)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Age Preference")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Who would you like to meet?")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Age range badge
                    Text("\(ageRangeMin) - \(ageRangeMax)")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [.pink, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                }

                // Age pickers
                HStack(spacing: 20) {
                    // Min age
                    VStack(spacing: 8) {
                        Text("From")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("Min Age", selection: $ageRangeMin) {
                            ForEach(18..<99, id: \.self) { age in
                                Text("\(age)").tag(age)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height: 100)
                        .clipped()
                        .onChange(of: ageRangeMin) { _, newValue in
                            if newValue >= ageRangeMax {
                                ageRangeMax = newValue + 1
                            }
                        }
                    }

                    // Divider
                    Text("to")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // Max age
                    VStack(spacing: 8) {
                        Text("To")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("Max Age", selection: $ageRangeMax) {
                            ForEach(19..<100, id: \.self) { age in
                                Text("\(age)").tag(age)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height: 100)
                        .clipped()
                        .onChange(of: ageRangeMax) { _, newValue in
                            if newValue <= ageRangeMin {
                                ageRangeMin = newValue - 1
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Personal Details Section

    private var personalDetailsSection: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                SectionHeader(icon: "person.text.rectangle", title: "Personal Details", color: .blue)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            VStack(spacing: 16) {
                // Height with picker
                VStack(alignment: .leading, spacing: 8) {
                    Label("Height", systemImage: "ruler")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Menu {
                        Button("Not specified") {
                            height = nil
                        }
                        ForEach(heightOptionsForPicker, id: \.cm) { option in
                            Button(option.display) {
                                height = option.cm
                            }
                        }
                    } label: {
                        HStack {
                            if let h = height {
                                Text(heightToFeetInches(h))
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            } else {
                                Text("Select height")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            if let h = height {
                                Text("\(h) cm")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)

                // Two column grid for related fields
                HStack(spacing: 12) {
                    // Education
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Education", systemImage: "graduationcap")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        Menu {
                            ForEach(educationOptions, id: \.self) { option in
                                Button(option) {
                                    educationLevel = option == "Prefer not to say" ? nil : option
                                }
                            }
                        } label: {
                            HStack {
                                Text(educationLevel ?? "Select")
                                    .font(.subheadline)
                                    .foregroundColor(educationLevel == nil ? .gray : .primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }

                    // Relationship Goal
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Looking For", systemImage: "heart.circle")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        Menu {
                            ForEach(relationshipGoalOptions, id: \.self) { option in
                                Button(option) {
                                    relationshipGoal = option == "Prefer not to say" ? nil : option
                                }
                            }
                        } label: {
                            HStack {
                                Text(relationshipGoal ?? "Select")
                                    .font(.subheadline)
                                    .foregroundColor(relationshipGoal == nil ? .gray : .primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Religion - Full width
                VStack(alignment: .leading, spacing: 8) {
                    Label("Religion / Spirituality", systemImage: "sparkles")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Menu {
                        ForEach(religionOptions, id: \.self) { option in
                            Button(option) {
                                religion = option == "Prefer not to say" ? nil : option
                            }
                        }
                    } label: {
                        HStack {
                            Text(religion ?? "Select")
                                .font(.subheadline)
                                .foregroundColor(religion == nil ? .gray : .primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Lifestyle Habits Section

    private var lifestyleHabitsSection: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                SectionHeader(icon: "leaf.fill", title: "Lifestyle", color: .green)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            VStack(spacing: 12) {
                // Row 1: Smoking & Drinking
                HStack(spacing: 12) {
                    lifestylePickerItem(
                        icon: "smoke",
                        label: "Smoking",
                        value: $smoking,
                        options: smokingOptions,
                        color: .orange
                    )

                    lifestylePickerItem(
                        icon: "wineglass",
                        label: "Drinking",
                        value: $drinking,
                        options: drinkingOptions,
                        color: .purple
                    )
                }

                // Row 2: Exercise & Diet
                HStack(spacing: 12) {
                    lifestylePickerItem(
                        icon: "figure.run",
                        label: "Exercise",
                        value: $exercise,
                        options: exerciseOptions,
                        color: .blue
                    )

                    lifestylePickerItem(
                        icon: "fork.knife",
                        label: "Diet",
                        value: $diet,
                        options: dietOptions,
                        color: .green
                    )
                }

                // Row 3: Pets - Full width with special treatment
                VStack(alignment: .leading, spacing: 8) {
                    Label("Pets", systemImage: "pawprint.fill")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Menu {
                        ForEach(petsOptions, id: \.self) { option in
                            Button(option) {
                                pets = option == "Prefer not to say" ? nil : option
                            }
                        }
                    } label: {
                        HStack {
                            if let petsValue = pets {
                                HStack(spacing: 6) {
                                    Image(systemName: getPetIcon(petsValue))
                                        .foregroundColor(.orange)
                                    Text(petsValue)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                            } else {
                                Text("Select")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    private func lifestylePickerItem(
        icon: String,
        label: String,
        value: Binding<String?>,
        options: [String],
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        value.wrappedValue = option == "Prefer not to say" ? nil : option
                    }
                }
            } label: {
                HStack {
                    Text(value.wrappedValue ?? "Select")
                        .font(.subheadline)
                        .foregroundColor(value.wrappedValue == nil ? .gray : .primary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
        }
    }

    private func getPetIcon(_ pet: String) -> String {
        switch pet.lowercased() {
        case "dog": return "dog.fill"
        case "cat": return "cat.fill"
        case "both": return "pawprint.fill"
        case "other pets": return "hare.fill"
        case "want pets": return "heart.fill"
        case "no pets": return "xmark.circle"
        default: return "pawprint"
        }
    }

    // MARK: - Express Yourself Section (Languages & Interests)

    private var expressYourselfSection: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                SectionHeader(icon: "sparkles", title: "Express Yourself", color: .purple)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            VStack(spacing: 20) {
                // Languages subsection
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                                .font(.subheadline)
                                .foregroundColor(.purple)
                            Text("Languages")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button {
                            showLanguagePicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.caption)
                                Text("Add")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.purple)
                        }
                    }

                    if languages.isEmpty {
                        Button {
                            showLanguagePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "globe")
                                    .foregroundColor(.gray.opacity(0.5))
                                Text("Add languages you speak")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                    } else {
                        FlowLayoutImproved(spacing: 8) {
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
                .padding(.horizontal, 20)

                // Divider
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 1)
                    .padding(.horizontal, 20)

                // Interests subsection
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.subheadline)
                                .foregroundColor(.pink)
                            Text("Interests")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button {
                            showInterestPicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.caption)
                                Text("Add")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.pink)
                        }
                    }

                    if interests.isEmpty {
                        Button {
                            showInterestPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.gray.opacity(0.5))
                                Text("Add your interests")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                    } else {
                        FlowLayoutImproved(spacing: 8) {
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
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Lifestyle Section (Legacy - kept for reference)

    private var lifestyleSection: some View {
        VStack(spacing: 20) {
            SectionHeader(icon: "person.crop.circle.fill", title: "Lifestyle & More", color: .orange)

            // Height with picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Height")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Menu {
                    Button("Not specified") {
                        height = nil
                    }
                    ForEach(heightOptionsForPicker, id: \.cm) { option in
                        Button(option.display) {
                            height = option.cm
                        }
                    }
                } label: {
                    HStack {
                        if let h = height {
                            Text("\(heightToFeetInches(h)) (\(h) cm)")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        } else {
                            Text("Select height")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }

            // Education
            VStack(alignment: .leading, spacing: 8) {
                Text("Education")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Picker("Education", selection: Binding(
                    get: { educationLevel ?? "Prefer not to say" },
                    set: { educationLevel = $0 == "Prefer not to say" ? nil : $0 }
                )) {
                    ForEach(educationOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
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
                AddItemButton(
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
                AddItemButton(
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
                AddItemButton(
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
        // CODE QUALITY FIX: Removed force unwrapping - use optional chaining
        !fullName.isEmpty &&
        (Int(age) ?? 0) >= 18 &&
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
        let roundedInches = Int(round(totalInches))
        let feet = roundedInches / 12
        let inches = roundedInches % 12
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
                    // CACHE FIX: Clear old cached image before uploading new one
                    if let oldURL = URL(string: user.profileImageURL) {
                        await MainActor.run {
                            ImageCache.shared.removeImage(for: oldURL.absoluteString)
                        }
                    }

                    // Use PhotoUploadService for proper network check
                    let imageURL = try await PhotoUploadService.shared.uploadPhoto(profileImage, userId: userId, imageType: .profile)
                    user.profileImageURL = imageURL

                    // CACHE FIX: Cache the newly uploaded image immediately for instant display across all views
                    await MainActor.run {
                        ImageCache.shared.setImage(profileImage, for: imageURL)
                    }
                }
                
                // Update user data with sanitized input
                user.fullName = InputSanitizer.strict(fullName)
                user.age = ageInt
                user.bio = InputSanitizer.standard(bio)
                user.location = InputSanitizer.standard(location)
                user.country = InputSanitizer.basic(country)
                user.gender = gender
                user.lookingFor = lookingFor
                user.languages = languages
                user.interests = interests
                user.prompts = prompts
                user.photos = photos

                // Update advanced profile fields
                user.educationLevel = educationLevel
                user.height = height
                user.religion = religion
                user.relationshipGoal = relationshipGoal
                user.smoking = smoking
                user.drinking = drinking
                user.pets = pets
                user.exercise = exercise
                user.diet = diet

                // Update preference fields
                user.ageRangeMin = ageRangeMin
                user.ageRangeMax = ageRangeMax
                user.maxDistance = maxDistance

                try await authService.updateUser(user)
                
                await MainActor.run {
                    isLoading = false
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    // Provide specific error messages based on error type
                    if let photoError = error as? PhotoUploadError {
                        switch photoError {
                        case .noNetwork:
                            errorMessage = "No internet connection. Please check your WiFi or cellular data and try again."
                        case .wifiConnectedNoInternet:
                            errorMessage = "WiFi connected but no internet access. Please check your network and try again."
                        case .poorConnection:
                            errorMessage = "Your connection is too weak. Please move to a stronger signal and try again."
                        case .uploadFailed(let reason):
                            errorMessage = "Photo upload failed: \(reason)"
                        case .uploadTimeout:
                            errorMessage = "Upload timed out. Please check your connection and try again."
                        }
                    } else if let celestiaError = error as? CelestiaError {
                        switch celestiaError {
                        case .networkError:
                            errorMessage = "Network error. Please check your connection and try again."
                        case .imageUploadFailed:
                            errorMessage = "Failed to upload photo. Please try again."
                        case .imageTooBig:
                            errorMessage = "Photo is too large. Please choose a smaller image."
                        default:
                            errorMessage = "Failed to save changes. Please try again."
                        }
                    } else {
                        errorMessage = "Failed to save changes. Please try again."
                    }
                    showErrorAlert = true
                    HapticManager.shared.notification(.error)
                }
            }
        }
    }

    // MARK: - Photo Management Functions

    private func deletePhoto(at index: Int) {
        withAnimation {
            _ = photos.remove(at: index)
        }
        HapticManager.shared.impact(.medium)

        // Immediately save to Firestore so deletion persists
        // Also sync profileImageURL: first photo in array is always the profile image
        Task {
            guard var user = authService.currentUser else { return }
            user.photos = photos

            // Sync profileImageURL with first photo in array
            // If photos array is empty, clear profileImageURL
            // Otherwise, set profileImageURL to the new first photo
            if photos.isEmpty {
                user.profileImageURL = ""
                // Clear local profile image as well
                await MainActor.run {
                    profileImage = nil
                }
                Logger.shared.info("All photos deleted - cleared profileImageURL", category: .general)
            } else if let firstPhoto = photos.first {
                user.profileImageURL = firstPhoto
                Logger.shared.info("Updated profileImageURL to new first photo", category: .general)
            }

            do {
                try await authService.updateUser(user)
                Logger.shared.info("Photo deleted from profile successfully", category: .general)
            } catch {
                Logger.shared.error("Failed to delete photo from profile", category: .general, error: error)
                await MainActor.run {
                    errorMessage = "Failed to delete photo. Please try again."
                    showErrorAlert = true
                }
            }
        }
    }

    private func movePhoto(from source: Int, to destination: Int) {
        withAnimation {
            let photo = photos.remove(at: source)
            photos.insert(photo, at: destination)
        }
        HapticManager.shared.impact(.light)
        savePhotoOrder()
    }

    private func savePhotoOrder() {
        // Save photo order to Firestore so reordering persists
        // Also sync profileImageURL: first photo in array is always the profile image
        Task {
            guard var user = authService.currentUser else { return }
            user.photos = photos

            // Sync profileImageURL with first photo in array after reorder
            if let firstPhoto = photos.first {
                user.profileImageURL = firstPhoto
                Logger.shared.info("Updated profileImageURL to match new first photo after reorder", category: .general)
            }

            do {
                try await authService.updateUser(user)
                Logger.shared.info("Photo order updated successfully", category: .general)
            } catch {
                Logger.shared.error("Failed to update photo order", category: .general, error: error)
            }
        }
    }

    private func uploadNewPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else {
            Logger.shared.warning("Upload cancelled: No items selected", category: .general)
            return
        }

        // NETWORK CHECK: Ensure we have connectivity before attempting upload
        guard networkMonitor.isConnected else {
            Logger.shared.warning("Upload cancelled: No network connection", category: .networking)
            await MainActor.run {
                errorMessage = "No internet connection. Please check your WiFi or cellular data and try again."
                showErrorAlert = true
                HapticManager.shared.notification(.error)
            }
            return
        }

        // CRITICAL FIX: Use stored userId instead of authService.currentUser
        guard !userId.isEmpty else {
            Logger.shared.error("❌ CRITICAL: Upload cancelled - No user ID found!", category: .general)
            Logger.shared.error("AuthService.currentUser: \(authService.currentUser?.id ?? "NIL")", category: .general)
            Logger.shared.error("Stored userId: \(userId)", category: .general)

            await MainActor.run {
                errorMessage = "Cannot upload photos: User not logged in. Please try logging out and back in."
                showErrorAlert = true
            }
            return
        }

        Logger.shared.info("✅ Using user ID: \(userId)", category: .general)

        Logger.shared.info("📸 Starting upload of \(items.count) photo(s)", category: .general)
        Logger.shared.info("Current photos count: \(photos.count)", category: .general)

        await MainActor.run {
            isUploadingPhotos = true
            uploadProgress = 0.0
            uploadingPhotoCount = items.count
            HapticManager.shared.impact(.light)

            Logger.shared.info("🎬 Upload UI activated - isUploadingPhotos: true", category: .general)
            Logger.shared.info("🎬 Upload progress: 0%, uploading count: \(items.count)", category: .general)
        }

        // PERFORMANCE: Upload photos in parallel using TaskGroup for maximum speed
        let uploadedURLs = await withTaskGroup(of: (index: Int, url: String?)?.self) { group in
            var results: [(Int, String?)] = []

            // Add all upload tasks to the group (parallel execution)
            for (index, item) in items.enumerated() {
                group.addTask {
                    Logger.shared.info("📤 Uploading photo \(index + 1)/\(items.count)...", category: .general)

                    do {
                        // Load and optimize image
                        guard let data = try await item.loadTransferable(type: Data.self),
                              let originalImage = UIImage(data: data) else {
                            Logger.shared.error("❌ Failed to load image data for photo \(index + 1)", category: .general)
                            return nil
                        }

                        Logger.shared.info("Image loaded: \(originalImage.size.width)x\(originalImage.size.height)", category: .general)

                        // OPTIMIZATION: Compress image for faster upload (max 1024px, 75% quality)
                        let optimizedImage = self.optimizeImageForUpload(originalImage)
                        Logger.shared.info("Image optimized: \(optimizedImage.size.width)x\(optimizedImage.size.height)", category: .general)

                        // Upload with retry logic (3 attempts)
                        var lastError: Error?
                        for attempt in 0..<3 {
                            do {
                                Logger.shared.info("🔄 Upload attempt \(attempt + 1)/3 for photo \(index + 1)", category: .general)

                                let photoURL = try await PhotoUploadService.shared.uploadPhoto(
                                    optimizedImage,
                                    userId: userId,
                                    imageType: .gallery
                                )

                                Logger.shared.info("✅ Photo \(index + 1) uploaded successfully: \(photoURL)", category: .general)

                                // Success - update UI immediately and cache for instant display
                                await MainActor.run {
                                    // Cache the uploaded image immediately for instant display across all views
                                    ImageCache.shared.setImage(optimizedImage, for: photoURL)

                                    self.photos.append(photoURL)
                                    self.uploadingPhotoCount -= 1
                                    let progress = Double(items.count - self.uploadingPhotoCount) / Double(items.count)
                                    self.uploadProgress = progress
                                    HapticManager.shared.impact(.light)
                                    Logger.shared.info("UI updated: photos.count = \(self.photos.count), progress = \(Int(progress * 100))%", category: .general)
                                }

                                return (index, photoURL)
                            } catch {
                                lastError = error
                                Logger.shared.error("❌ Upload attempt \(attempt + 1) failed for photo \(index + 1)", category: .general, error: error)

                                if attempt < 2 {
                                    // Wait before retry (exponential backoff)
                                    let delay = UInt64(pow(2.0, Double(attempt)) * 500_000_000)
                                    Logger.shared.warning("⏳ Waiting before retry...", category: .general)
                                    try? await Task.sleep(nanoseconds: delay)
                                }
                            }
                        }

                        // All retries failed
                        await MainActor.run {
                            self.uploadingPhotoCount -= 1
                        }
                        Logger.shared.error("❌ Photo \(index + 1) failed after all retries", category: .general, error: lastError)
                        return nil

                    } catch {
                        await MainActor.run {
                            self.uploadingPhotoCount -= 1
                        }
                        Logger.shared.error("❌ Photo \(index + 1) processing failed", category: .general, error: error)
                        return nil
                    }
                }
            }

            // Collect results
            for await result in group {
                if let result = result {
                    results.append((result.index, result.url))
                }
            }

            return results
        }

        // Count successful uploads
        let successCount = uploadedURLs.compactMap { $0.1 }.count
        let failedCount = items.count - successCount

        Logger.shared.info("📊 Upload complete: \(successCount) succeeded, \(failedCount) failed", category: .general)
        Logger.shared.info("Total photos now: \(photos.count)", category: .general)

        // CRITICAL: Save photos to Firebase immediately after upload
        if successCount > 0, var user = authService.currentUser {
            Logger.shared.info("💾 Saving \(photos.count) photos to Firebase...", category: .general)
            Logger.shared.info("Photos array: \(photos)", category: .general)

            do {
                user.photos = photos

                // Auto-set profileImageURL to first photo if empty
                if user.profileImageURL.isEmpty, let firstPhoto = photos.first, !firstPhoto.isEmpty {
                    user.profileImageURL = firstPhoto
                    Logger.shared.info("📸 Auto-set profileImageURL to first uploaded photo", category: .general)
                }

                try await authService.updateUser(user)

                Logger.shared.info("✅ Successfully saved \(successCount) photos to Firebase!", category: .general)
                Logger.shared.info("User photos in Firebase: \(user.photos)", category: .general)

                // CRITICAL FIX: Force refresh current user from Firebase to get latest data
                if user.id != nil {
                    Logger.shared.info("🔄 Refreshing user data from Firebase...", category: .general)
                    await authService.fetchUser()

                    // Verify the refresh worked
                    if let refreshedUser = authService.currentUser {
                        Logger.shared.info("🔍 Verification - User now has \(refreshedUser.photos.count) photos", category: .general)

                        // Update local photos array to match
                        await MainActor.run {
                            self.photos = refreshedUser.photos
                        }
                    }
                } else {
                    Logger.shared.warning("⚠️ Could not refresh - no user ID", category: .general)
                }
            } catch {
                Logger.shared.error("❌ CRITICAL: Failed to save photos to Firebase!", category: .general, error: error)
                await MainActor.run {
                    errorMessage = "Photos uploaded but failed to save to profile. Please try again."
                    showErrorAlert = true
                }
            }
        } else if successCount == 0 {
            Logger.shared.warning("⚠️ No successful uploads to save", category: .general)
        } else {
            Logger.shared.error("❌ No current user found, cannot save photos", category: .general)
        }

        await MainActor.run {
            uploadProgress = 1.0
            isUploadingPhotos = false
            uploadingPhotoCount = 0
            selectedPhotoItems = []

            Logger.shared.info("🏁 Upload process finished. Final photos count: \(photos.count)", category: .general)

            // Success feedback
            if successCount > 0 {
                HapticManager.shared.notification(.success)

                // Show error if some failed
                if failedCount > 0 {
                    errorMessage = "Uploaded \(successCount) photo\(successCount > 1 ? "s" : ""). \(failedCount) failed - please try again."
                    showErrorAlert = true
                } else {
                    // All succeeded - show success message
                    errorMessage = "Successfully uploaded \(successCount) photo\(successCount > 1 ? "s" : "")! 🎉"
                    showErrorAlert = true
                }
            } else if failedCount > 0 {
                HapticManager.shared.notification(.error)
                // Check if it's likely a network issue
                if !networkMonitor.isConnected {
                    errorMessage = "No internet connection. Check your WiFi or cellular data and try again."
                } else {
                    errorMessage = "Failed to upload photos. Please check your connection and try again."
                }
                showErrorAlert = true
            }
        }
    }

    // MARK: - Image Optimization

    /// Optimizes an image for upload: crops to 3:4 portrait ratio, resizes to max 2000px
    /// This ensures images display perfectly in cards without distortion or unexpected cropping
    private func optimizeImageForUpload(_ image: UIImage) -> UIImage {
        // QUALITY: Higher settings for crisp photos on all card sizes
        let maxDimension: CGFloat = 2000  // High resolution for crisp display on all devices
        let targetAspectRatio: CGFloat = 3.0 / 4.0  // Portrait ratio (0.75) - perfect for profile cards

        let originalSize = image.size
        let originalAspectRatio = originalSize.width / originalSize.height

        var croppedImage = image

        // STEP 1: Crop to target aspect ratio (3:4 portrait) for consistent card display
        // This ensures images always fill cards without unexpected cropping
        if abs(originalAspectRatio - targetAspectRatio) > 0.01 {
            let cropRect: CGRect

            if originalAspectRatio > targetAspectRatio {
                // Image is wider than target - crop sides (center horizontally)
                let targetWidth = originalSize.height * targetAspectRatio
                let xOffset = (originalSize.width - targetWidth) / 2
                cropRect = CGRect(x: xOffset, y: 0, width: targetWidth, height: originalSize.height)
            } else {
                // Image is taller than target - crop top/bottom (center vertically, favor upper portion for faces)
                let targetHeight = originalSize.width / targetAspectRatio
                // Favor upper 40% of image to capture faces better
                let yOffset = max(0, (originalSize.height - targetHeight) * 0.4)
                cropRect = CGRect(x: 0, y: yOffset, width: originalSize.width, height: targetHeight)
            }

            // Perform the crop using CGImage for best quality
            if let cgImage = image.cgImage,
               let croppedCGImage = cgImage.cropping(to: cropRect) {
                croppedImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
            }
        }

        // STEP 2: Resize if needed (maintain high quality)
        let croppedSize = croppedImage.size
        let ratio = min(maxDimension / croppedSize.width, maxDimension / croppedSize.height)

        if ratio >= 1.0 {
            // Image is already smaller than max - return cropped version
            return croppedImage
        }

        let newSize = CGSize(width: croppedSize.width * ratio, height: croppedSize.height * ratio)

        // QUALITY: Use high-fidelity rendering format
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0  // 1x scale for optimal file size
        format.opaque = true  // Opaque for better JPEG compression
        format.preferredRange = .standard  // Standard color range for compatibility

        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resizedImage = renderer.image { context in
            // Fill background with white for clean JPEG edges
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: newSize))

            // Draw with high-quality interpolation
            context.cgContext.interpolationQuality = .high
            croppedImage.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resizedImage
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

struct AddItemButton: View {
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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with count
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Select Languages")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("\(selectedLanguages.count) selected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button("Done") {
                            HapticManager.shared.impact(.light)
                            dismiss()
                        }
                        .font(.headline)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Grid of language tags
                    FlowLayoutImproved(spacing: 12) {
                        ForEach(availableLanguages, id: \.self) { language in
                            LanguageTagButton(
                                language: language,
                                isSelected: selectedLanguages.contains(language)
                            ) {
                                HapticManager.shared.impact(.light)
                                if selectedLanguages.contains(language) {
                                    selectedLanguages.removeAll { $0 == language }
                                } else {
                                    selectedLanguages.append(language)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

struct LanguageTagButton: View {
    let language: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(language)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .opacity(0.15)
                    } else {
                        Color(.systemGray6)
                    }
                }
            )
            .foregroundColor(isSelected ? .purple : .primary)
            .cornerRadius(25)
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(
                        isSelected ?
                        AnyShapeStyle(LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )) :
                        AnyShapeStyle(LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)),
                        lineWidth: 2
                    )
            )
            .shadow(color: isSelected ? .purple.opacity(0.2) : .clear, radius: 8, y: 4)
        }
        .scaleButton()
    }
}

// MARK: - Interest Picker Sheet

struct InterestPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedInterests: [String]
    let availableInterests: [String]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with count
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Select Interests")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("\(selectedInterests.count) selected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button("Done") {
                            HapticManager.shared.impact(.light)
                            dismiss()
                        }
                        .font(.headline)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.pink, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Grid of interest tags
                    FlowLayoutImproved(spacing: 12) {
                        ForEach(availableInterests, id: \.self) { interest in
                            InterestTagButton(
                                interest: interest,
                                isSelected: selectedInterests.contains(interest)
                            ) {
                                HapticManager.shared.impact(.light)
                                if selectedInterests.contains(interest) {
                                    selectedInterests.removeAll { $0 == interest }
                                } else {
                                    selectedInterests.append(interest)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

struct InterestTagButton: View {
    let interest: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(interest)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            colors: [.pink, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .opacity(0.15)
                    } else {
                        Color(.systemGray6)
                    }
                }
            )
            .foregroundColor(isSelected ? .pink : .primary)
            .cornerRadius(25)
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(
                        isSelected ?
                        AnyShapeStyle(LinearGradient(
                            colors: [.pink, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )) :
                        AnyShapeStyle(LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)),
                        lineWidth: 2
                    )
            )
            .shadow(color: isSelected ? .pink.opacity(0.2) : .clear, radius: 8, y: 4)
        }
        .scaleButton()
    }
}

// MARK: - Uploading Photo Placeholder

struct UploadingPhotoPlaceholder: View {
    let index: Int
    @State private var isPulsing = false

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [
                        Color.purple.opacity(isPulsing ? 0.15 : 0.08),
                        Color.pink.opacity(isPulsing ? 0.12 : 0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 120)
            .overlay {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .stroke(Color.purple.opacity(0.2), lineWidth: 3)
                            .frame(width: 40, height: 40)

                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(isPulsing ? 360 : 0))
                    }

                    Text("Uploading...")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.purple)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [.purple.opacity(0.3), .pink.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - Draggable Photo Grid Item

struct DraggablePhotoGridItem: View {
    let photoURL: String
    let isDragging: Bool
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Photo container with fixed dimensions
            GeometryReader { geometry in
                CachedAsyncImage(
                    url: URL(string: photoURL),
                    content: { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    },
                    placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .overlay {
                                ProgressView()
                            }
                    }
                )
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: isDragging ? [.purple, .pink] : [.clear, .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isDragging ? 3 : 0
                    )
            )

            // Delete button - hide when dragging for cleaner look
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
            .padding(6)
            .opacity(isDragging ? 0 : 1)

            // Drag hint overlay (shows on long press)
            if isDragging {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 120)
            }
        }
        .scaleEffect(isDragging ? 1.08 : 1.0)
        .rotation3DEffect(.degrees(isDragging ? 2 : 0), axis: (x: 0, y: 1, z: 0))
        .shadow(color: isDragging ? .purple.opacity(0.5) : .black.opacity(0.08), radius: isDragging ? 16 : 4, y: isDragging ? 8 : 2)
        .animation(.interpolatingSpring(stiffness: 350, damping: 18), value: isDragging)
        .confirmationDialog("Delete this photo?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Photo Drop Delegate

struct PhotoDropDelegate: DropDelegate {
    let item: String
    @Binding var items: [String]
    @Binding var draggingItem: String?
    let onReorder: () -> Void

    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        onReorder()
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem,
              draggingItem != item,
              let fromIndex = items.firstIndex(of: draggingItem),
              let toIndex = items.firstIndex(of: item) else {
            return
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
        HapticManager.shared.impact(.light)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        // Optional: Add any cleanup when drag exits
    }

    func validateDrop(info: DropInfo) -> Bool {
        return draggingItem != nil
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
