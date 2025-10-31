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
    
    let genderOptions = ["Male", "Female", "Non-binary", "Other"]
    let lookingForOptions = ["Men", "Women", "Everyone"]
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
                        
                        // Progress Indicator
                        profileCompletionProgress
                        
                        // Basic Info Card
                        basicInfoSection
                        
                        // About Me Card
                        aboutMeSection
                        
                        // Preferences Card
                        preferencesSection
                        
                        // Languages Card
                        languagesSection
                        
                        // Interests Card
                        interestsSection
                        
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
                    } else if let imageURL = URL(string: authService.currentUser?.profileImageURL ?? ""),
                              !authService.currentUser!.profileImageURL.isEmpty {
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
            
            FormField(label: "Full Name", placeholder: "Enter your name", text: $fullName)
            
            FormField(
                label: "Age",
                placeholder: "18",
                text: $age,
                keyboardType: .numberPad
            )
            
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
            
            HStack(spacing: 12) {
                FormField(label: "City", placeholder: "Los Angeles", text: $location)
                FormField(label: "Country", placeholder: "USA", text: $country)
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
                    
                    Text("\(bio.count)/500")
                        .font(.caption)
                        .foregroundColor(bio.count > 500 ? .red : .gray)
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
