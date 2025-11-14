//
//  OnboardingView.swift
//  Celestia
//
//  ELITE ONBOARDING - First Impressions Matter
//

import SwiftUI
import PhotosUI

struct OnboardingView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss

    private let imageUploadService = ImageUploadService.shared

    @StateObject private var viewModel = OnboardingViewModel()
    @StateObject private var personalizedManager = PersonalizedOnboardingManager.shared
    @StateObject private var profileScorer = ProfileQualityScorer.shared

    @State private var currentStep = 0
    @State private var progress: CGFloat = 0
    @State private var showGoalSelection = true
    @State private var showTutorial = false
    @State private var showCompletionCelebration = false

    // Step 1: Basics
    @State private var fullName = ""
    @State private var birthday = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var gender = "Male"

    // Step 2: Location & About
    @State private var bio = ""
    @State private var location = ""
    @State private var country = ""

    // Step 3: Photos
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoImages: [UIImage] = []
    @State private var isUploadingPhotos = false

    // Step 4: Preferences
    @State private var lookingFor = "Everyone"
    @State private var selectedInterests: [String] = []
    @State private var selectedLanguages: [String] = []

    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var animateContent = false
    @State private var onboardingStartTime = Date()
    
    let genderOptions = ["Male", "Female", "Non-binary", "Other"]
    let lookingForOptions = ["Men", "Women", "Everyone"]
    let totalSteps = 5
    
    let availableInterests = [
        "Travel", "Music", "Movies", "Sports", "Food",
        "Art", "Photography", "Reading", "Gaming", "Fitness",
        "Cooking", "Dancing", "Nature", "Technology", "Fashion"
    ]
    
    let availableLanguages = [
        "English", "Spanish", "French", "German", "Italian",
        "Portuguese", "Chinese", "Japanese", "Korean", "Arabic"
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Animated background gradient
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.1),
                        Color.pink.opacity(0.05),
                        Color.blue.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Animated progress bar
                    progressBar
                    
                    // Content with transitions
                    TabView(selection: $currentStep) {
                        step1View.tag(0)
                        step2View.tag(1)
                        step3View.tag(2)
                        step4View.tag(3)
                        step5View.tag(4)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .accessibleAnimation(.easeInOut, value: currentStep)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Onboarding step \(currentStep + 1) of \(totalSteps)")
                    
                    // Navigation buttons
                    navigationButtons
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                            Text("Cancel")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.purple)
                    }
                    .accessibilityLabel("Cancel onboarding")
                    .accessibilityHint("Exit onboarding and return to previous screen")
                    .accessibilityIdentifier(AccessibilityIdentifier.cancelButton)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("Step \(currentStep + 1)/\(totalSteps)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                onboardingStartTime = Date()
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    animateContent = true
                    progress = CGFloat(currentStep + 1) / CGFloat(totalSteps)
                }
            }
            .onChange(of: currentStep) { _, newStep in
                viewModel.trackStepCompletion(newStep)
                updateProfileQuality()
            }
            .sheet(isPresented: $showGoalSelection) {
                OnboardingGoalSelectionView { goal in
                    showGoalSelection = false
                    // Show tutorial if A/B test says so
                    if viewModel.showTutorialIfNeeded() {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showTutorial = true
                        }
                    }
                }
                .interactiveDismissDisabled()
            }
            .sheet(isPresented: $showTutorial) {
                let tutorials = personalizedManager.getPrioritizedTutorials().compactMap { tutorialId in
                    TutorialManager.getOnboardingTutorials().first { $0.id == tutorialId }
                }
                TutorialView(tutorials: tutorials.isEmpty ? TutorialManager.getOnboardingTutorials() : tutorials) {
                    showTutorial = false
                }
            }
            .sheet(isPresented: $showCompletionCelebration) {
                CompletionCelebrationView(
                    incentive: viewModel.completionIncentive,
                    profileScore: profileScorer.currentScore
                ) {
                    showCompletionCelebration = false
                    dismiss()
                }
            }
            .overlay {
                if viewModel.showMilestoneCelebration, let milestone = viewModel.currentMilestone {
                    MilestoneCelebrationView(milestone: milestone) {
                        viewModel.showMilestoneCelebration = false
                    }
                }
            }
        }
    }

    // MARK: - Profile Quality Update

    private func updateProfileQuality() {
        guard var user = authService.currentUser else { return }

        // Create temporary user with current onboarding data
        user.fullName = fullName
        user.age = calculateAge(from: birthday)
        user.bio = bio
        user.location = location
        user.interests = selectedInterests
        user.languages = selectedLanguages

        viewModel.updateProfileQuality(for: user)
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        VStack(spacing: 16) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 8)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color.purple, Color.pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(currentStep + 1) / CGFloat(totalSteps), height: 8)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentStep)
                }
            }
            .frame(height: 8)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stepTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(stepSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Percentage
                Text("\(Int(CGFloat(currentStep + 1) / CGFloat(totalSteps) * 100))%")
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
        }
        .padding(20)
        .background(Color.white)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
    
    private var stepTitle: String {
        switch currentStep {
        case 0: return "Basic Info"
        case 1: return "About You"
        case 2: return "Your Photos"
        case 3: return "Preferences"
        case 4: return "Finishing Up"
        default: return ""
        }
    }
    
    private var stepSubtitle: String {
        switch currentStep {
        case 0: return "Tell us who you are"
        case 1: return "Share your story"
        case 2: return "Show your best self"
        case 3: return "What you're looking for"
        case 4: return "Almost there!"
        default: return ""
        }
    }
    
    // MARK: - Step 1: Basics
    
    private var step1View: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 30) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .scaleEffect(animateContent ? 1 : 0.5)
                .opacity(animateContent ? 1 : 0)
                
                VStack(spacing: 8) {
                    Text("Let's Get Started")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("We need a few details to create your profile")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 20) {
                    // Full Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Full Name")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter your name", text: $fullName)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                            )
                            .accessibilityLabel("Full name")
                            .accessibilityHint("Enter your full name")
                            .accessibilityIdentifier(AccessibilityIdentifier.nameField)
                    }
                    
                    // Birthday
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Birthday")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        DatePicker(
                            "",
                            selection: $birthday,
                            in: ...Date().addingTimeInterval(-18 * 365 * 24 * 60 * 60),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                        )
                        .accessibilityLabel("Birthday")
                        .accessibilityHint("Select your date of birth. Must be 18 or older")
                        .accessibilityIdentifier("birthday_picker")
                    }
                    
                    // Gender
                    VStack(alignment: .leading, spacing: 12) {
                        Text("I am")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        ForEach(genderOptions, id: \.self) { option in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    gender = option
                                    HapticManager.shared.selection()
                                }
                            } label: {
                                HStack {
                                    Text(option)
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    if gender == option {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.purple)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.gray.opacity(0.3))
                                    }
                                }
                                .padding()
                                .background(
                                    gender == option ?
                                    LinearGradient(
                                        colors: [Color.purple.opacity(0.1), Color.pink.opacity(0.05)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ) :
                                    LinearGradient(colors: [Color.white], startPoint: .leading, endPoint: .trailing)
                                )
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            gender == option ? Color.purple.opacity(0.5) : Color.gray.opacity(0.2),
                                            lineWidth: 1
                                        )
                                )
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
            }
            .padding(20)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Step 2: About & Location

    private var step2View: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 30) {
                // Incentive Banner (if offered)
                if let incentive = viewModel.completionIncentive {
                    IncentiveBanner(incentive: incentive)
                }

                // Icon
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(spacing: 8) {
                    Text("About You")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Share a bit about yourself and where you're from")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Profile Quality Tips (if enabled)
                if viewModel.shouldShowProfileTips, let tip = profileScorer.getPriorityTip() {
                    ProfileQualityTipCard(tip: tip)
                }

                VStack(spacing: 20) {
                    // Bio
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Bio")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(bio.count)/500")
                                .font(.caption)
                                .foregroundColor(bio.count > 500 ? .red : .secondary)
                        }
                        
                        TextEditor(text: $bio)
                            .frame(height: 140)
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                            )
                            .overlay(alignment: .topLeading) {
                                if bio.isEmpty {
                                    Text("Tell others about yourself...")
                                        .foregroundColor(.gray.opacity(0.5))
                                        .padding(.top, 20)
                                        .padding(.leading, 16)
                                        .allowsHitTesting(false)
                                }
                            }
                            .accessibilityLabel("Bio")
                            .accessibilityHint("Write a short bio about yourself. Maximum 500 characters")
                            .accessibilityValue("\(bio.count) of 500 characters")
                            .accessibilityIdentifier(AccessibilityIdentifier.bioField)
                    }
                    
                    // Location
                    VStack(alignment: .leading, spacing: 8) {
                        Text("City")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        TextField("e.g. Los Angeles", text: $location)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                            )
                            .accessibilityLabel("City")
                            .accessibilityHint("Enter your city")
                            .accessibilityIdentifier(AccessibilityIdentifier.locationField)
                    }
                    
                    // Country
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Country")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        TextField("e.g. United States", text: $country)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                            )
                            .accessibilityLabel("Country")
                            .accessibilityHint("Enter your country")
                            .accessibilityIdentifier(AccessibilityIdentifier.countryField)
                    }
                }
            }
            .padding(20)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Step 3: Photos
    
    private var step3View: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 30) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "photo.on.rectangle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(spacing: 8) {
                    Text("Add Your Photos")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Add at least 2 photos to continue")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Photo grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(0..<6, id: \.self) { index in
                        if index < photoImages.count {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: photoImages[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 180)
                                    .clipped()
                                    .cornerRadius(16)
                                
                                Button {
                                    withAnimation {
                                        photoImages.remove(at: index)
                                        HapticManager.shared.impact(.light)
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.5)).padding(4))
                                        .padding(8)
                                }
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .frame(height: 180)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: index == 0 ? "person.crop.circle.badge.plus" : "plus")
                                            .font(.title)
                                            .foregroundColor(.purple.opacity(0.5))
                                        
                                        if index == 0 {
                                            Text("Main Photo")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                        .foregroundColor(.purple.opacity(0.3))
                                )
                        }
                    }
                }
                
                // Add photos button
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 6 - photoImages.count,
                    matching: .images
                ) {
                    HStack(spacing: 10) {
                        if isUploadingPhotos {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "photo.badge.plus")
                            Text("Add Photos")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .purple.opacity(0.3), radius: 10, y: 5)
                }
                .disabled(photoImages.count >= 6 || isUploadingPhotos)
                .onChange(of: selectedPhotos) { _, newValue in
                    Task {
                        isUploadingPhotos = true
                        await loadPhotos(newValue)
                        isUploadingPhotos = false
                    }
                }
            }
            .padding(20)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Step 4: Preferences
    
    private var step4View: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 30) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "heart.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(spacing: 8) {
                    Text("Dating Preferences")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Who are you interested in?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Interested in")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(lookingForOptions, id: \.self) { option in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                lookingFor = option
                                HapticManager.shared.selection()
                            }
                        } label: {
                            HStack {
                                Text(option)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                if lookingFor == option {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.purple)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.gray.opacity(0.3))
                                }
                            }
                            .padding()
                            .background(
                                lookingFor == option ?
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.1), Color.pink.opacity(0.05)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ) :
                                LinearGradient(colors: [Color.white], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        lookingFor == option ? Color.purple.opacity(0.5) : Color.gray.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .padding(20)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Step 5: Interests & Languages
    
    private var step5View: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 30) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "star.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(spacing: 8) {
                    Text("Almost Done!")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Add your interests and languages")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Interests
                VStack(alignment: .leading, spacing: 12) {
                    Text("Interests (Optional)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    FlowLayout3(spacing: 8) {
                        ForEach(availableInterests, id: \.self) { interest in
                            Button {
                                withAnimation {
                                    if selectedInterests.contains(interest) {
                                        selectedInterests.removeAll { $0 == interest }
                                    } else {
                                        selectedInterests.append(interest)
                                    }
                                    HapticManager.shared.selection()
                                }
                            } label: {
                                Text(interest)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(selectedInterests.contains(interest) ? .white : .purple)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedInterests.contains(interest) ?
                                        LinearGradient(
                                            colors: [Color.purple, Color.pink],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ) :
                                        LinearGradient(colors: [Color.purple.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .cornerRadius(20)
                            }
                        }
                    }
                }
                
                // Languages
                VStack(alignment: .leading, spacing: 12) {
                    Text("Languages (Optional)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    FlowLayout3(spacing: 8) {
                        ForEach(availableLanguages, id: \.self) { language in
                            Button {
                                withAnimation {
                                    if selectedLanguages.contains(language) {
                                        selectedLanguages.removeAll { $0 == language }
                                    } else {
                                        selectedLanguages.append(language)
                                    }
                                    HapticManager.shared.selection()
                                }
                            } label: {
                                Text(language)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(selectedLanguages.contains(language) ? .white : .blue)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedLanguages.contains(language) ?
                                        LinearGradient(
                                            colors: [Color.blue, Color.cyan],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ) :
                                        LinearGradient(colors: [Color.blue.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .cornerRadius(20)
                            }
                        }
                    }
                }
            }
            .padding(20)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        currentStep -= 1
                        HapticManager.shared.impact(.light)
                    }
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.purple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.purple, lineWidth: 2)
                    )
                }
                .accessibilityLabel("Back")
                .accessibilityHint("Go back to previous step")
                .accessibilityIdentifier(AccessibilityIdentifier.backButton)
            }
            
            Button {
                if currentStep < totalSteps - 1 {
                    withAnimation(.spring(response: 0.3)) {
                        currentStep += 1
                        HapticManager.shared.impact(.medium)
                    }
                } else {
                    completeOnboarding()
                }
            } label: {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(currentStep < totalSteps - 1 ? "Continue" : "Complete")
                            .fontWeight(.semibold)

                        if currentStep < totalSteps - 1 {
                            Image(systemName: "chevron.right")
                        } else {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    canProceed ?
                    LinearGradient(
                        colors: [Color.purple, Color.pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(colors: [Color.gray.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(16)
                .shadow(color: canProceed ? .purple.opacity(0.3) : .clear, radius: 10, y: 5)
            }
            .disabled(!canProceed || isLoading)
            .accessibilityLabel(currentStep < totalSteps - 1 ? "Continue" : "Complete onboarding")
            .accessibilityHint(currentStep < totalSteps - 1 ? "Continue to next step" : "Finish onboarding and create profile")
            .accessibilityIdentifier(currentStep < totalSteps - 1 ? "continue_button" : "complete_button")
        }
        .padding(20)
        .background(Color.white)
        .shadow(color: .black.opacity(0.05), radius: 5, y: -2)
    }
    
    // MARK: - Helper Functions
    
    private var canProceed: Bool {
        switch currentStep {
        case 0:
            return !fullName.isEmpty && calculateAge(from: birthday) >= 18
        case 1:
            return !bio.isEmpty && !location.isEmpty && !country.isEmpty && bio.count <= 500
        case 2:
            return photoImages.count >= 2
        case 3:
            return true
        case 4:
            return true
        default:
            return false
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
                    if photoImages.count < 6 {
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
                guard let userId = user.id else { return }

                // Upload photos
                var photoURLs: [String] = []
                for image in photoImages {
                    let url = try await imageUploadService.uploadProfileImage(image, userId: userId)
                    photoURLs.append(url)
                }

                // Update user
                user.fullName = fullName
                user.age = calculateAge(from: birthday)
                user.gender = gender
                user.bio = bio
                user.location = location
                user.country = country
                user.lookingFor = lookingFor
                user.photos = photoURLs
                user.profileImageURL = photoURLs.first ?? ""
                user.interests = selectedInterests
                user.languages = selectedLanguages

                try await authService.updateUser(user)

                // Track onboarding completion analytics
                let timeSpent = Date().timeIntervalSince(onboardingStartTime)
                await MainActor.run {
                    viewModel.trackOnboardingCompleted(timeSpent: timeSpent)

                    // Update activation metrics
                    ActivationMetrics.shared.trackProfileUpdate(user: user)

                    isLoading = false
                    HapticManager.shared.notification(.success)

                    // Show completion celebration if profile quality is good
                    if profileScorer.currentScore >= 70 {
                        showCompletionCelebration = true
                    } else {
                        dismiss()
                    }
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

// MARK: - Supporting Views

struct IncentiveBanner: View {
    let incentive: OnboardingViewModel.CompletionIncentive

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: incentive.icon)
                .font(.title2)
                .foregroundColor(.yellow)

            VStack(alignment: .leading, spacing: 4) {
                Text("Complete your profile!")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(incentive.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.1), Color.orange.opacity(0.05)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ProfileQualityTipCard: View {
    let tip: ProfileQualityScorer.ProfileQualityTip

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tip.impact.icon)
                .font(.title3)
                .foregroundColor(tip.impact.color)

            VStack(alignment: .leading, spacing: 4) {
                Text(tip.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(tip.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("+\(tip.points)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.green)
        }
        .padding()
        .background(tip.impact.color.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(tip.impact.color.opacity(0.2), lineWidth: 1)
        )
    }
}

struct CompletionCelebrationView: View {
    let incentive: OnboardingViewModel.CompletionIncentive?
    let profileScore: Int
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var confettiCounter = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 32) {
                // Celebration Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.2), .pink.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)

                    Text("🎉")
                        .font(.system(size: 60))
                }
                .scaleEffect(scale)
                .opacity(opacity)

                VStack(spacing: 12) {
                    Text("Profile Complete!")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("Your profile is looking great!")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    // Profile Score
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                                .frame(width: 60, height: 60)

                            Circle()
                                .trim(from: 0, to: CGFloat(profileScore) / 100)
                                .stroke(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                )
                                .frame(width: 60, height: 60)
                                .rotationEffect(.degrees(-90))

                            Text("\(profileScore)")
                                .font(.headline)
                                .fontWeight(.bold)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Profile Quality")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("Excellent!")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                    }
                }
                .opacity(opacity)

                // Incentive Reward (if any)
                if let incentive = incentive {
                    VStack(spacing: 12) {
                        Divider()

                        HStack(spacing: 12) {
                            Image(systemName: incentive.icon)
                                .font(.title2)
                                .foregroundColor(.yellow)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Reward Unlocked!")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                Text("\(incentive.amount) \(incentive.type.displayName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        .padding()
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .opacity(opacity)
                }

                Button {
                    onDismiss()
                } label: {
                    Text("Start Exploring!")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                }
                .opacity(opacity)
            }
            .padding(32)
            .background(Color.white)
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.2), radius: 20)
            .padding(40)
            .scaleEffect(scale)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }

            // Trigger confetti animation
            for i in 0..<20 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                    confettiCounter += 1
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AuthService.shared)
}

