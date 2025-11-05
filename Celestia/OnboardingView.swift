//
//  OnboardingView.swift
//  Celestia
//

import SwiftUI
import PhotosUI

struct OnboardingView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var currentStep = 0
    
    // Step 1: Basics
    @State private var fullName = ""
    @State private var birthday = Date()
    @State private var gender = "Male"
    
    // Step 2: About & Location
    @State private var bio = ""
    @State private var location = ""
    @State private var country = ""
    
    // Step 3: Photos
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoImages: [UIImage] = []
    
    // Step 4: Preferences
    @State private var lookingFor = "Everyone"
    
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    let genderOptions = ["Male", "Female", "Non-binary"]
    let lookingForOptions = ["Men", "Women", "Everyone"]
    let totalSteps = 4
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress bar
                    progressBar
                    
                    // Content
                    TabView(selection: $currentStep) {
                        step1View.tag(0)
                        step2View.tag(1)
                        step3View.tag(2)
                        step4View.tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    
                    // Navigation buttons
                    navigationButtons
                }
            }
            .navigationTitle("Setup Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.purple)
                        .frame(width: geo.size.width * CGFloat(currentStep + 1) / CGFloat(totalSteps), height: 8)
                }
            }
            .frame(height: 8)
            
            Text("Step \(currentStep + 1) of \(totalSteps)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    // MARK: - Step 1: Basics
    
    private var step1View: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "person.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                
                Text("Let's start with the basics")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(spacing: 16) {
                    TextField("Full Name", text: $fullName)
                        .textFieldStyle(.roundedBorder)
                    
                    DatePicker(
                        "Birthday",
                        selection: $birthday,
                        in: ...Date().addingTimeInterval(-18 * 365 * 24 * 60 * 60),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("I am")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        ForEach(genderOptions, id: \.self) { option in
                            Button {
                                gender = option
                            } label: {
                                HStack {
                                    Text(option)
                                    Spacer()
                                    if gender == option {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.purple)
                                    }
                                }
                                .padding()
                                .background(
                                    gender == option ?
                                    Color.purple.opacity(0.1) :
                                    Color(.systemGray6)
                                )
                                .cornerRadius(12)
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Step 2: About & Location
    
    private var step2View: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                
                Text("About you")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bio")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $bio)
                            .frame(height: 120)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        
                        Text("\(bio.count)/500")
                            .font(.caption)
                            .foregroundColor(bio.count > 500 ? .red : .secondary)
                    }
                    
                    TextField("City", text: $location)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Country", text: $country)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Step 3: Photos
    
    private var step3View: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                
                Text("Add photos")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Add at least 2 photos")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(0..<4, id: \.self) { index in
                        if index < photoImages.count {
                            Image(uiImage: photoImages[index])
                                .resizable()
                                .scaledToFill()
                                .frame(height: 150)
                                .clipped()
                                .cornerRadius(12)
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        photoImages.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.white)
                                            .padding(8)
                                    }
                                }
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                                .frame(height: 150)
                                .overlay {
                                    Image(systemName: "plus")
                                        .font(.title)
                                        .foregroundColor(.gray)
                                }
                        }
                    }
                }
                
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 4 - photoImages.count,
                    matching: .images
                ) {
                    Label("Add Photos", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(12)
                }
                .disabled(photoImages.count >= 4)
                .onChange(of: selectedPhotos) { _, newValue in
                    Task {
                        await loadPhotos(newValue)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Step 4: Preferences
    
    private var step4View: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                
                Text("Dating preferences")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Interested in")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(lookingForOptions, id: \.self) { option in
                        Button {
                            lookingFor = option
                        } label: {
                            HStack {
                                Text(option)
                                Spacer()
                                if lookingFor == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.purple)
                                }
                            }
                            .padding()
                            .background(
                                lookingFor == option ?
                                Color.purple.opacity(0.1) :
                                Color(.systemGray6)
                            )
                            .cornerRadius(12)
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button {
                    withAnimation {
                        currentStep -= 1
                    }
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
            }
            
            Button {
                if currentStep < totalSteps - 1 {
                    withAnimation {
                        currentStep += 1
                    }
                } else {
                    completeOnboarding()
                }
            } label: {
                Text(currentStep < totalSteps - 1 ? "Continue" : "Complete")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canProceed ? Color.purple : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(!canProceed)
        }
        .padding()
    }
    
    // MARK: - Helper Functions
    
    private var canProceed: Bool {
        switch currentStep {
        case 0: return !fullName.isEmpty && calculateAge(from: birthday) >= 18
        case 1: return !bio.isEmpty && !location.isEmpty && !country.isEmpty && bio.count <= 500
        case 2: return photoImages.count >= 2
        case 3: return true
        default: return false
        }
    }
    
    private func calculateAge(from birthday: Date) -> Int {
        Calendar.current.dateComponents([.year], from: birthday, to: Date()).year ?? 0
    }
    
    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    if photoImages.count < 4 {
                        photoImages.append(image)
                    }
                }
            }
        }
        selectedPhotos = []
    }
    
    private func completeOnboarding() {
        isLoading = true
        
        Task {
            do {
                guard var user = authService.currentUser else { return }
                
                // Upload photos
                var photoURLs: [String] = []
                if let userId = user.id {
                    for image in photoImages {
                        // You'll need to implement image upload
                        // let url = try await uploadImage(image, userId: userId)
                        // photoURLs.append(url)
                    }
                }
                
                user.fullName = fullName
                user.age = calculateAge(from: birthday)
                user.gender = gender
                user.bio = bio
                user.location = location
                user.country = country
                user.lookingFor = lookingFor
                user.photos = photoURLs
                user.profileImageURL = photoURLs.first ?? ""
                
                try await authService.updateUser(user)
                
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AuthService.shared)
}
