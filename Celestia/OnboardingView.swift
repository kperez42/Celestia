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

    // Parameter to skip goal selection for existing users updating their profile
    var isEditingExistingProfile: Bool = false

    @State private var currentStep = 0
    @State private var progress: CGFloat = 0
    @State private var showGoalSelection = true
    @State private var showTutorial = false
    @State private var showCompletionCelebration = false
    @State private var hasLoadedExistingData = false
    @State private var existingPhotoURLs: [String] = [] // Track existing photos to avoid re-upload

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

    // Step 6: Additional Details (Optional)
    @State private var height: Int? = nil
    @State private var relationshipGoal: String = "Prefer not to say"
    @State private var ageRangeMin: Int = 18
    @State private var ageRangeMax: Int = 50
    @State private var maxDistance: Int = 50

    // Step 7: Lifestyle (NEW)
    @State private var educationLevel: String = ""
    @State private var religion: String = ""
    @State private var smoking: String = ""
    @State private var drinking: String = ""

    // Step 8: More About You (NEW)
    @State private var exercise: String = ""
    @State private var pets: String = ""
    @State private var diet: String = ""

    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var animateContent = false
    @State private var onboardingStartTime = Date()
    
    let genderOptions = ["Male", "Female", "Non-binary", "Other"]
    let lookingForOptions = ["Men", "Women", "Everyone"]
    let totalSteps = 8

    // Step 6 options
    let relationshipGoalOptions = ["Prefer not to say", "Casual Dating", "Long-term Relationship", "Marriage", "Friendship", "Not Sure Yet"]
    let heightOptions: [Int] = Array(140...220) // cm range

    // Step 7 & 8 options (Lifestyle)
    let educationOptions = ["", "High School", "Some College", "Associate's Degree", "Bachelor's Degree", "Master's Degree", "Doctorate", "Trade School", "Other"]
    let religionOptions = ["", "Christian", "Catholic", "Jewish", "Muslim", "Hindu", "Buddhist", "Spiritual", "Agnostic", "Atheist", "Other", "Prefer not to say"]
    let smokingOptions = ["", "Never", "Sometimes", "Regularly", "Trying to quit", "Prefer not to say"]
    let drinkingOptions = ["", "Never", "Socially", "Occasionally", "Regularly", "Prefer not to say"]
    let exerciseOptions = ["", "Daily", "Often (3-4x/week)", "Sometimes (1-2x/week)", "Rarely", "Never"]
    let petsOptions = ["", "Dog", "Cat", "Both", "Other pets", "No pets", "Want pets", "Allergic"]
    let dietOptions = ["", "Omnivore", "Vegetarian", "Vegan", "Pescatarian", "Keto", "Halal", "Kosher", "Other"]
    
    let availableInterests = [
        "Travel", "Music", "Movies", "Sports", "Food",
        "Art", "Photography", "Reading", "Gaming", "Fitness",
        "Cooking", "Dancing", "Nature", "Technology", "Fashion"
    ]
    
    let availableLanguages = [
        "English", "Spanish", "French", "German", "Italian",
        "Portuguese", "Chinese", "Japanese", "Korean", "Arabic"
    ]

    let availableCountries = [
        "United States", "Canada", "Mexico", "United Kingdom", "Australia",
        "Germany", "France", "Spain", "Italy", "Brazil", "Argentina",
        "Japan", "South Korea", "China", "India", "Philippines", "Vietnam",
        "Thailand", "Netherlands", "Sweden", "Norway", "Denmark", "Switzerland",
        "Ireland", "New Zealand", "Singapore", "Other"
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
                        step6View.tag(5)
                        step7View.tag(6)
                        step8View.tag(7)
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
                // Show X/Cancel button only on step 0 (when there's no Back button)
                // On steps 1-7, the Back button serves as navigation
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentStep == 0 {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundColor(.purple)
                        }
                        .accessibilityLabel("Close")
                        .accessibilityHint("Cancel onboarding and return to previous screen")
                        .accessibilityIdentifier(AccessibilityIdentifier.closeButton)
                    }
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

                // Skip goal selection for existing users editing their profile
                if isEditingExistingProfile {
                    showGoalSelection = false
                }
            }
            .task {
                // Load existing user data when editing profile
                if isEditingExistingProfile && !hasLoadedExistingData {
                    await loadExistingUserData()
                    hasLoadedExistingData = true
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
            // Step indicator dots with enhanced styling
            HStack(spacing: 12) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    ZStack {
                        // Glow ring for current step
                        if currentStep == step {
                            Circle()
                                .fill(Color.purple.opacity(0.15))
                                .frame(width: 22, height: 22)
                        }

                        Circle()
                            .fill(
                                currentStep >= step ?
                                LinearGradient(
                                    colors: [Color.purple, Color.pink, Color.purple.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.gray.opacity(0.25), Color.gray.opacity(0.2)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: currentStep == step ? 14 : 10, height: currentStep == step ? 14 : 10)
                            .shadow(color: currentStep >= step ? .purple.opacity(0.3) : .clear, radius: 4, y: 2)
                    }
                    .scaleEffect(currentStep == step ? 1.0 : 0.85)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step indicator")
            .accessibilityValue("Step \(currentStep + 1) of \(totalSteps)")

            HStack(spacing: 14) {
                // Icon for current step
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.12), Color.pink.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: stepIcon)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(stepTitle)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(stepSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Percentage badge
                Text("\(Int(CGFloat(currentStep + 1) / CGFloat(totalSteps) * 100))%")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: .purple.opacity(0.3), radius: 4, y: 2)
                    )
            }
        }
        .padding(20)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
                .shadow(color: .purple.opacity(0.04), radius: 20, y: 8)
        )
    }

    private var stepIcon: String {
        switch currentStep {
        case 0: return "person.fill"
        case 1: return "text.alignleft"
        case 2: return "camera.fill"
        case 3: return "heart.fill"
        case 4: return "star.fill"
        case 5: return "slider.horizontal.3"
        case 6: return "leaf.fill"
        case 7: return "checkmark.seal.fill"
        default: return "circle"
        }
    }
    
    private var stepTitle: String {
        switch currentStep {
        case 0: return "Basic Info"
        case 1: return "About You"
        case 2: return "Your Photos"
        case 3: return "Preferences"
        case 4: return "Interests"
        case 5: return "Better Matches"
        case 6: return "Your Lifestyle"
        case 7: return "Final Details"
        default: return ""
        }
    }

    private var stepSubtitle: String {
        switch currentStep {
        case 0: return "Tell us who you are"
        case 1: return "Share your story"
        case 2: return "Show your best self"
        case 3: return "What you're looking for"
        case 4: return "What makes you unique"
        case 5: return "Optional • Skip anytime"
        case 6: return "Your habits & preferences"
        case 7: return "Almost done!"
        default: return ""
        }
    }
    
    // MARK: - Step 1: Basics

    private var step1View: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 30) {
                // Icon with radial glow
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.08), Color.clear],
                                center: .center,
                                startRadius: 30,
                                endRadius: 80
                            )
                        )
                        .frame(width: 140, height: 140)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
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
                        .shadow(color: .purple.opacity(0.3), radius: 8, y: 4)
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
                        HStack(spacing: 8) {
                            Image(systemName: "person.fill")
                                .font(.caption)
                                .foregroundStyle(
                                    LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                                )
                            Text("Full Name")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.secondary)
                        }

                        TextField("Enter your name", text: $fullName)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.purple.opacity(0.2), Color.pink.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .accessibilityLabel("Full name")
                            .accessibilityHint("Enter your full name")
                            .accessibilityIdentifier(AccessibilityIdentifier.nameField)
                    }
                    
                    // Birthday
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundStyle(
                                    LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                                )
                            Text("Birthday")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.secondary)
                        }

                        DatePicker(
                            "",
                            selection: $birthday,
                            in: ...Date().addingTimeInterval(-18 * 365 * 24 * 60 * 60),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.purple.opacity(0.2), Color.pink.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .accessibilityLabel("Birthday")
                        .accessibilityHint("Select your date of birth. Must be 18 or older")
                        .accessibilityIdentifier("birthday_picker")
                    }
                    
                    // Gender
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.2.fill")
                                .font(.caption)
                                .foregroundStyle(
                                    LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                                )
                            Text("I am")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.secondary)
                        }

                        ForEach(genderOptions, id: \.self) { option in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    gender = option
                                    HapticManager.shared.selection()
                                }
                            } label: {
                                HStack {
                                    Text(option)
                                        .fontWeight(.medium)

                                    Spacer()

                                    ZStack {
                                        if gender == option {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [.purple, .pink],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 24, height: 24)
                                                .shadow(color: .purple.opacity(0.3), radius: 4, y: 2)

                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundColor(.white)
                                        } else {
                                            Circle()
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                                .frame(width: 24, height: 24)
                                        }
                                    }
                                }
                                .padding()
                                .background(
                                    gender == option ?
                                    LinearGradient(
                                        colors: [Color.purple.opacity(0.12), Color.pink.opacity(0.06)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ) :
                                    LinearGradient(colors: [Color(.systemBackground)], startPoint: .leading, endPoint: .trailing)
                                )
                                .cornerRadius(16)
                                .shadow(color: gender == option ? .purple.opacity(0.15) : .black.opacity(0.04), radius: 8, y: 2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            gender == option ?
                                            LinearGradient(
                                                colors: [Color.purple.opacity(0.4), Color.pink.opacity(0.3)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ) :
                                            LinearGradient(
                                                colors: [Color.gray.opacity(0.15), Color.gray.opacity(0.1)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                            }
                            .foregroundColor(.primary)
                            .scaleEffect(gender == option ? 1.01 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: gender)
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

                // Icon with radial glow
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.08), Color.clear],
                                center: .center,
                                startRadius: 30,
                                endRadius: 80
                            )
                        )
                        .frame(width: 140, height: 140)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
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
                        .shadow(color: .purple.opacity(0.3), radius: 8, y: 4)
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
                            HStack(spacing: 8) {
                                Image(systemName: "text.alignleft")
                                    .font(.caption)
                                    .foregroundStyle(
                                        LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                                    )
                                Text("Bio")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.secondary)

                                Text("*")
                                    .foregroundColor(.red)
                                    .font(.subheadline)
                            }

                            Spacer()

                            Text("\(bio.count)/500")
                                .font(.caption.weight(.medium))
                                .foregroundColor(bio.count > 500 ? .red : .secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(bio.count > 500 ? Color.red.opacity(0.1) : Color(.systemGray6))
                                )
                        }

                        TextEditor(text: $bio)
                            .frame(height: 140)
                            .padding(12)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        bio.isEmpty ?
                                        LinearGradient(colors: [Color.red.opacity(0.5), Color.orange.opacity(0.3)], startPoint: .leading, endPoint: .trailing) :
                                        LinearGradient(colors: [Color.purple.opacity(0.2), Color.pink.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                        lineWidth: 1
                                    )
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
                            .onChange(of: bio) { _, newValue in
                                // SAFETY: Enforce bio character limit to prevent data overflow
                                if newValue.count > AppConstants.Limits.maxBioLength {
                                    bio = String(newValue.prefix(AppConstants.Limits.maxBioLength))
                                }
                            }
                            .accessibilityLabel("Bio")
                            .accessibilityHint("Write a short bio about yourself. Maximum 500 characters")
                            .accessibilityValue("\(bio.count) of 500 characters")
                            .accessibilityIdentifier(AccessibilityIdentifier.bioField)
                    }

                    // Location
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "building.2.fill")
                                .font(.caption)
                                .foregroundStyle(
                                    LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                                )
                            Text("City")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.secondary)

                            Text("*")
                                .foregroundColor(.red)
                                .font(.subheadline)
                        }

                        TextField("e.g. Los Angeles", text: $location)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        location.isEmpty ?
                                        LinearGradient(colors: [Color.red.opacity(0.5), Color.orange.opacity(0.3)], startPoint: .leading, endPoint: .trailing) :
                                        LinearGradient(colors: [Color.blue.opacity(0.2), Color.cyan.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                        lineWidth: 1
                                    )
                            )
                            .accessibilityLabel("City")
                            .accessibilityHint("Enter your city")
                            .accessibilityIdentifier(AccessibilityIdentifier.locationField)
                    }

                    // Country
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "globe.americas.fill")
                                .font(.caption)
                                .foregroundStyle(
                                    LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                                )
                            Text("Country")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.secondary)

                            Text("*")
                                .foregroundColor(.red)
                                .font(.subheadline)
                        }

                        Menu {
                            ForEach(availableCountries, id: \.self) { countryOption in
                                Button(countryOption) {
                                    country = countryOption
                                    HapticManager.shared.selection()
                                }
                            }
                        } label: {
                            HStack {
                                Text(country.isEmpty ? "Select Country" : country)
                                    .foregroundColor(country.isEmpty ? .gray : .primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(
                                        LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                                    )
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        country.isEmpty ?
                                        LinearGradient(colors: [Color.red.opacity(0.5), Color.orange.opacity(0.3)], startPoint: .leading, endPoint: .trailing) :
                                        LinearGradient(colors: [Color.green.opacity(0.2), Color.mint.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .accessibilityLabel("Country")
                        .accessibilityHint("Select your country from the list")
                        .accessibilityValue(country.isEmpty ? "No country selected" : country)
                        .accessibilityIdentifier(AccessibilityIdentifier.countryField)
                    }

                    // Helper text showing what's needed
                    if bio.isEmpty || location.isEmpty || country.isEmpty {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.15))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "info.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(
                                        LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                            }
                            Text("Fill in all required fields (*) to continue")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .padding(.top, 4)
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
            VStack(spacing: 24) {
                // Icon with radial glow
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.orange.opacity(0.15), Color.pink.opacity(0.08), Color.clear],
                                center: .center,
                                startRadius: 30,
                                endRadius: 80
                            )
                        )
                        .frame(width: 140, height: 140)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.15), Color.pink.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .orange.opacity(0.3), radius: 8, y: 4)
                }

                VStack(spacing: 8) {
                    Text("Show Your Best Self")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Great photos get 10x more matches")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    // Requirement badge
                    HStack(spacing: 6) {
                        Image(systemName: photoImages.count >= 2 ? "checkmark.circle.fill" : "info.circle.fill")
                            .font(.caption)
                        Text(photoImages.count >= 2 ? "Ready to continue!" : "Add at least 2 photos")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(photoImages.count >= 2 ? .green : .orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(photoImages.count >= 2 ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                    .cornerRadius(20)
                    .padding(.top, 4)
                }

                // Photo Progress Card
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        // Progress circle
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                                .frame(width: 50, height: 50)

                            Circle()
                                .trim(from: 0, to: CGFloat(photoImages.count) / 6.0)
                                .stroke(
                                    LinearGradient(
                                        colors: [.orange, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                )
                                .frame(width: 50, height: 50)
                                .rotationEffect(.degrees(-90))

                            Text("\(photoImages.count)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(photoImages.count) of 6 photos")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text(photoImages.count == 0 ? "Add photos to get started" :
                                 photoImages.count < 2 ? "Add \(2 - photoImages.count) more to continue" :
                                 photoImages.count < 6 ? "Add more for better matches" : "Maximum photos reached!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Photo quality indicator
                        if photoImages.count >= 2 {
                            VStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.title3)
                                    .foregroundColor(.yellow)
                                Text("Good")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.orange.opacity(0.3), .pink.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

                // Photo Tips Card - Collapsible style
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.yellow.opacity(0.2))
                                .frame(width: 32, height: 32)
                            Image(systemName: "lightbulb.fill")
                                .font(.callout)
                                .foregroundColor(.yellow)
                        }
                        Text("Photo Tips for Success")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Spacer()

                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        photoTipRow(icon: "face.smiling.fill", text: "Show your smile - it's your best feature!", color: .green)
                        photoTipRow(icon: "sun.max.fill", text: "Good lighting makes you shine", color: .orange)
                        photoTipRow(icon: "camera.fill", text: "Mix it up with different angles", color: .blue)
                        photoTipRow(icon: "sparkles", text: "Be yourself - authenticity wins", color: .purple)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow.opacity(0.08), Color.orange.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )

                // Photo grid - Main photo is larger and more prominent
                VStack(spacing: 12) {
                    // Main Profile Photo - Full width, taller
                    if photoImages.count > 0 {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: photoImages[0])
                                .resizable()
                                .scaledToFill()
                                .frame(height: 240)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .cornerRadius(20)
                                .overlay(
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Image(systemName: "star.fill")
                                                .font(.caption)
                                            Text("Profile Picture")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(Color.black.opacity(0.6))
                                        )
                                        .padding(12)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                )

                            Button {
                                withAnimation {
                                    photoImages.remove(at: 0)
                                    HapticManager.shared.impact(.light)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.5)).padding(4))
                                    .padding(12)
                            }
                        }
                    } else {
                        // Empty main photo slot
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.1), Color.pink.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 240)
                            .overlay(
                                VStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.purple.opacity(0.15))
                                            .frame(width: 70, height: 70)

                                        Image(systemName: "person.crop.circle.badge.plus")
                                            .font(.system(size: 36))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [.purple, .pink],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }

                                    VStack(spacing: 4) {
                                        Text("Profile Picture")
                                            .font(.headline)
                                            .foregroundColor(.primary)

                                        Text("This will be your main photo")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.purple.opacity(0.5), .pink.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        style: StrokeStyle(lineWidth: 2, dash: [8])
                                    )
                            )
                    }

                    // Additional photos grid (2 columns)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(1..<6, id: \.self) { index in
                            if index < photoImages.count {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: photoImages[index])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 150)
                                        .clipped()
                                        .cornerRadius(16)

                                    Button {
                                        withAnimation {
                                            photoImages.remove(at: index)
                                            HapticManager.shared.impact(.light)
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.white)
                                            .background(Circle().fill(Color.black.opacity(0.5)).padding(4))
                                            .padding(8)
                                    }
                                }
                            } else {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white)
                                    .frame(height: 150)
                                    .overlay(
                                        VStack(spacing: 6) {
                                            Image(systemName: "plus")
                                                .font(.title2)
                                                .foregroundColor(.purple.opacity(0.4))

                                            Text("Photo \(index + 1)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                                            .foregroundColor(.gray.opacity(0.3))
                                    )
                            }
                        }
                    }
                }

                // Add photos button
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 6 - photoImages.count,
                    matching: .images
                ) {
                    HStack(spacing: 12) {
                        if isUploadingPhotos {
                            ProgressView()
                                .tint(.white)
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(photoImages.isEmpty ? "Add Photos" : "Add More Photos")
                                    .fontWeight(.semibold)
                                Text(photoImages.count >= 6 ? "Maximum reached" : "\(6 - photoImages.count) slots available")
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                        }
                        Spacer()
                        if !isUploadingPhotos {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title2)
                                .opacity(0.8)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: photoImages.count >= 6 ? [Color.gray, Color.gray.opacity(0.8)] : [Color.orange, Color.pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: photoImages.count >= 6 ? .clear : .orange.opacity(0.3), radius: 10, y: 5)
                }
                .disabled(photoImages.count >= 6 || isUploadingPhotos)
                .onChange(of: selectedPhotos) { _, newValue in
                    Task {
                        isUploadingPhotos = true
                        await loadPhotos(newValue)
                        isUploadingPhotos = false
                    }
                }

                // Photo count indicator with animation
                HStack(spacing: 6) {
                    ForEach(0..<6, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                index < photoImages.count ?
                                LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: index < photoImages.count ? 24 : 16, height: 6)
                            .animation(.spring(response: 0.3), value: photoImages.count)
                    }
                }
                .padding(.top, 8)

                // Motivation card
                HStack(spacing: 12) {
                    Image(systemName: "heart.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.pink, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("First impressions matter")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Profiles with 3+ photos get 5x more likes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.pink.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.pink.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .padding(20)
            .padding(.top, 20)
        }
    }

    private func photoTipRow(icon: String, text: String, color: Color = .purple) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
            }

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundColor(.green.opacity(0.6))
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Step 4: Preferences
    
    private var step4View: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 30) {
                // Icon with radial glow
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.08), Color.clear],
                                center: .center,
                                startRadius: 30,
                                endRadius: 80
                            )
                        )
                        .frame(width: 140, height: 140)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
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
                        .shadow(color: .purple.opacity(0.3), radius: 8, y: 4)
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
                    HStack(spacing: 8) {
                        Image(systemName: "heart.circle.fill")
                            .font(.caption)
                            .foregroundStyle(
                                LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                            )
                        Text("Interested in")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                    }

                    ForEach(lookingForOptions, id: \.self) { option in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                lookingFor = option
                                HapticManager.shared.selection()
                            }
                        } label: {
                            HStack {
                                Text(option)
                                    .fontWeight(.medium)

                                Spacer()

                                ZStack {
                                    if lookingFor == option {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [.purple, .pink],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 24, height: 24)
                                            .shadow(color: .purple.opacity(0.3), radius: 4, y: 2)

                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundColor(.white)
                                    } else {
                                        Circle()
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                            .frame(width: 24, height: 24)
                                    }
                                }
                            }
                            .padding()
                            .background(
                                lookingFor == option ?
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.12), Color.pink.opacity(0.06)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ) :
                                LinearGradient(colors: [Color(.systemBackground)], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(16)
                            .shadow(color: lookingFor == option ? .purple.opacity(0.15) : .black.opacity(0.04), radius: 8, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        lookingFor == option ?
                                        LinearGradient(
                                            colors: [Color.purple.opacity(0.4), Color.pink.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ) :
                                        LinearGradient(
                                            colors: [Color.gray.opacity(0.15), Color.gray.opacity(0.1)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .foregroundColor(.primary)
                        .scaleEffect(lookingFor == option ? 1.01 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: lookingFor)
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
                // Icon with radial glow
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.yellow.opacity(0.15), Color.orange.opacity(0.08), Color.clear],
                                center: .center,
                                startRadius: 30,
                                endRadius: 80
                            )
                        )
                        .frame(width: 140, height: 140)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow.opacity(0.15), Color.orange.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)

                    Image(systemName: "star.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .yellow.opacity(0.3), radius: 8, y: 4)
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
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.12))
                                .frame(width: 32, height: 32)
                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundStyle(
                                    LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                                )
                        }
                        Text("Interests (Optional)")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        if !selectedInterests.isEmpty {
                            Text("\(selectedInterests.count) selected")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                                        )
                                )
                        }
                    }

                    FlowLayout3(spacing: 8) {
                        ForEach(availableInterests, id: \.self) { interest in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        selectedInterests.contains(interest) ?
                                        LinearGradient(
                                            colors: [Color.purple, Color.pink, Color.purple.opacity(0.9)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ) :
                                        LinearGradient(colors: [Color.purple.opacity(0.08)], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .clipShape(Capsule())
                                    .shadow(color: selectedInterests.contains(interest) ? .purple.opacity(0.3) : .clear, radius: 4, y: 2)
                            }
                            .scaleEffect(selectedInterests.contains(interest) ? 1.02 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedInterests.contains(interest))
                        }
                    }
                }

                // Languages
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.12))
                                .frame(width: 32, height: 32)
                            Image(systemName: "globe")
                                .font(.caption)
                                .foregroundStyle(
                                    LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                                )
                        }
                        Text("Languages (Optional)")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        if !selectedLanguages.isEmpty {
                            Text("\(selectedLanguages.count) selected")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                                        )
                                )
                        }
                    }

                    FlowLayout3(spacing: 8) {
                        ForEach(availableLanguages, id: \.self) { language in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        selectedLanguages.contains(language) ?
                                        LinearGradient(
                                            colors: [Color.blue, Color.cyan, Color.blue.opacity(0.9)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ) :
                                        LinearGradient(colors: [Color.blue.opacity(0.08)], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .clipShape(Capsule())
                                    .shadow(color: selectedLanguages.contains(language) ? .blue.opacity(0.3) : .clear, radius: 4, y: 2)
                            }
                            .scaleEffect(selectedLanguages.contains(language) ? 1.02 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedLanguages.contains(language))
                        }
                    }
                }
            }
            .padding(20)
            .padding(.top, 20)
        }
    }

    // MARK: - Step 6: Better Matches (Optional)

    private var step6View: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Icon with radial glow
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.green.opacity(0.15), Color.mint.opacity(0.08), Color.clear],
                                center: .center,
                                startRadius: 30,
                                endRadius: 80
                            )
                        )
                        .frame(width: 140, height: 140)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.15), Color.mint.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)

                    Image(systemName: "sparkles")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .green.opacity(0.3), radius: 8, y: 4)
                }

                VStack(spacing: 8) {
                    Text("Get Better Matches")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("These details help find your perfect match")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    // Optional badge
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap.fill")
                            .font(.caption)
                        Text("Optional - Skip anytime")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(20)
                    .padding(.top, 4)
                }

                VStack(spacing: 20) {
                    // Relationship Goal
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.text.square.fill")
                                .foregroundColor(.pink)
                            Text("What are you looking for?")
                                .font(.headline)
                        }

                        ForEach(relationshipGoalOptions.filter { $0 != "Prefer not to say" }, id: \.self) { goal in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    relationshipGoal = goal
                                    HapticManager.shared.selection()
                                }
                            } label: {
                                HStack {
                                    Text(goal)
                                        .fontWeight(.medium)

                                    Spacer()

                                    if relationshipGoal == goal {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.pink)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.gray.opacity(0.3))
                                    }
                                }
                                .padding()
                                .background(
                                    relationshipGoal == goal ?
                                    LinearGradient(
                                        colors: [Color.pink.opacity(0.1), Color.purple.opacity(0.05)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ) :
                                    LinearGradient(colors: [Color.white], startPoint: .leading, endPoint: .trailing)
                                )
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            relationshipGoal == goal ? Color.pink.opacity(0.5) : Color.gray.opacity(0.2),
                                            lineWidth: 1
                                        )
                                )
                            }
                            .foregroundColor(.primary)
                        }
                    }

                    // Height
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "ruler")
                                .foregroundColor(.blue)
                            Text("Your Height")
                                .font(.headline)

                            Spacer()

                            if let h = height {
                                Text("\(h) cm (\(heightToFeetInches(h)))")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                            }
                        }

                        HStack(spacing: 12) {
                            // Height picker
                            Menu {
                                ForEach(heightOptions, id: \.self) { h in
                                    Button("\(h) cm (\(heightToFeetInches(h)))") {
                                        height = h
                                        HapticManager.shared.selection()
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(height != nil ? "\(height!) cm" : "Select Height")
                                        .foregroundColor(height != nil ? .primary : .gray)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                            }

                            // Clear button
                            if height != nil {
                                Button {
                                    height = nil
                                    HapticManager.shared.impact(.light)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }

                    // Age Range Preference
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(.purple)
                            Text("Preferred Age Range")
                                .font(.headline)

                            Spacer()

                            Text("\(ageRangeMin) - \(ageRangeMax)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                        }

                        VStack(spacing: 16) {
                            // Min Age
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Minimum: \(ageRangeMin)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Slider(
                                    value: Binding(
                                        get: { Double(ageRangeMin) },
                                        set: { ageRangeMin = Int($0) }
                                    ),
                                    in: 18...Double(ageRangeMax - 1),
                                    step: 1
                                )
                                .tint(.purple)
                            }

                            // Max Age
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Maximum: \(ageRangeMax)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Slider(
                                    value: Binding(
                                        get: { Double(ageRangeMax) },
                                        set: { ageRangeMax = Int($0) }
                                    ),
                                    in: Double(ageRangeMin + 1)...99,
                                    step: 1
                                )
                                .tint(.purple)
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                        )
                    }

                    // Max Distance Preference
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "location.circle.fill")
                                .foregroundColor(.blue)
                            Text("Maximum Distance")
                                .font(.headline)

                            Spacer()

                            Text("\(maxDistance) km")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Slider(
                                value: Binding(
                                    get: { Double(maxDistance) },
                                    set: { maxDistance = Int($0) }
                                ),
                                in: 5...200,
                                step: 5
                            )
                            .tint(.blue)

                            HStack {
                                Text("5 km")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("200 km")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                    }
                }

                // Benefit card
                HStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundColor(.green)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("40% More Matches")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("Users with complete profiles get significantly more matches")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.green.opacity(0.1), Color.mint.opacity(0.05)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
            }
            .padding(20)
            .padding(.top, 20)
        }
    }

    // Helper to convert cm to feet/inches
    private func heightToFeetInches(_ cm: Int) -> String {
        let totalInches = Double(cm) / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
        return "\(feet)'\(inches)\""
    }

    // MARK: - Step 7: Lifestyle

    private var step7View: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Icon with radial glow
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.teal.opacity(0.15), Color.green.opacity(0.08), Color.clear],
                                center: .center,
                                startRadius: 30,
                                endRadius: 80
                            )
                        )
                        .frame(width: 140, height: 140)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.teal.opacity(0.15), Color.green.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)

                    Image(systemName: "leaf.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.teal, .green],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .teal.opacity(0.3), radius: 8, y: 4)
                }

                VStack(spacing: 8) {
                    Text("Your Lifestyle")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Help us find compatible matches")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    // Optional badge
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap.fill")
                            .font(.caption)
                        Text("Optional - Skip anytime")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.teal)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.teal.opacity(0.1))
                    .cornerRadius(20)
                    .padding(.top, 4)
                }

                VStack(spacing: 20) {
                    // Education
                    lifestyleOptionSelector(
                        title: "Education",
                        icon: "graduationcap.fill",
                        color: .blue,
                        options: educationOptions,
                        selection: $educationLevel
                    )

                    // Religion
                    lifestyleOptionSelector(
                        title: "Religion / Spirituality",
                        icon: "sparkles",
                        color: .purple,
                        options: religionOptions,
                        selection: $religion
                    )

                    // Smoking
                    lifestyleOptionSelector(
                        title: "Smoking",
                        icon: "smoke.fill",
                        color: .gray,
                        options: smokingOptions,
                        selection: $smoking
                    )

                    // Drinking
                    lifestyleOptionSelector(
                        title: "Drinking",
                        icon: "wineglass.fill",
                        color: .pink,
                        options: drinkingOptions,
                        selection: $drinking
                    )
                }

                // Info card
                HStack(spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .font(.title3)
                        .foregroundColor(.yellow)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lifestyle Matching")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("Users with similar lifestyles are 60% more likely to match")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(20)
            .padding(.top, 20)
        }
    }

    // MARK: - Step 8: Final Details

    private var step8View: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Icon with radial glow
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.orange.opacity(0.15), Color.red.opacity(0.08), Color.clear],
                                center: .center,
                                startRadius: 30,
                                endRadius: 80
                            )
                        )
                        .frame(width: 140, height: 140)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.15), Color.red.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .orange.opacity(0.3), radius: 8, y: 4)
                }

                VStack(spacing: 8) {
                    Text("Final Touches")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Just a few more details to complete your profile")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 20) {
                    // Exercise
                    lifestyleOptionSelector(
                        title: "Exercise",
                        icon: "figure.run",
                        color: .orange,
                        options: exerciseOptions,
                        selection: $exercise
                    )

                    // Pets
                    lifestyleOptionSelector(
                        title: "Pets",
                        icon: "pawprint.fill",
                        color: .brown,
                        options: petsOptions,
                        selection: $pets
                    )

                    // Diet
                    lifestyleOptionSelector(
                        title: "Diet",
                        icon: "fork.knife",
                        color: .green,
                        options: dietOptions,
                        selection: $diet
                    )
                }

                // Completion stats
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        statBadge(icon: "chart.line.uptrend.xyaxis", value: "3x", label: "More Matches", color: .green)
                        statBadge(icon: "heart.fill", value: "85%", label: "Better Compatibility", color: .pink)
                    }

                    Text("Complete profiles get significantly more attention!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.green.opacity(0.1), Color.pink.opacity(0.05)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .padding(20)
            .padding(.top, 20)
        }
    }

    // MARK: - Lifestyle Helper Views

    private func lifestyleOptionSelector(title: String, icon: String, color: Color, options: [String], selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.callout)
                        .foregroundStyle(
                            LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }
                Text(title)
                    .font(.headline)

                if !selection.wrappedValue.isEmpty {
                    Spacer()
                    Text(selection.wrappedValue)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(colors: [color, color.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                                )
                                .shadow(color: color.opacity(0.3), radius: 4, y: 2)
                        )
                }
            }

            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option.isEmpty ? "Prefer not to say" : option) {
                        selection.wrappedValue = option
                        HapticManager.shared.selection()
                    }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue.isEmpty ? "Select \(title.lowercased())..." : selection.wrappedValue)
                        .foregroundColor(selection.wrappedValue.isEmpty ? .gray : .primary)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(
                            LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                        )
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [color.opacity(0.25), color.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            }
        }
    }

    private func statBadge(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(
                            LinearGradient(colors: [color, color.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(colors: [color, color.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                    )
            }
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.08))
                .shadow(color: color.opacity(0.1), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        currentStep -= 1
                        HapticManager.shared.impact(.light)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.callout.weight(.semibold))
                        Text("Back")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.4), Color.pink.opacity(0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                }
                .accessibilityLabel("Back")
                .accessibilityHint("Go back to previous step")
                .accessibilityIdentifier(AccessibilityIdentifier.backButton)
            }

            Button {
                if currentStep < totalSteps - 1 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
                                .font(.callout.weight(.semibold))
                        } else {
                            Image(systemName: "checkmark")
                                .font(.callout.weight(.bold))
                        }
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    canProceed ?
                    LinearGradient(
                        colors: [Color.purple, Color.pink, Color.purple.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(16)
                .shadow(color: canProceed ? .purple.opacity(0.4) : .clear, radius: 12, y: 6)
                .shadow(color: canProceed ? .pink.opacity(0.2) : .clear, radius: 20, y: 10)
            }
            .disabled(!canProceed || isLoading)
            .scaleEffect(canProceed && !isLoading ? 1.0 : 0.98)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: canProceed)
            .accessibilityLabel(currentStep < totalSteps - 1 ? "Continue" : "Complete onboarding")
            .accessibilityHint(currentStep < totalSteps - 1 ? "Continue to next step" : "Finish onboarding and create profile")
            .accessibilityIdentifier(currentStep < totalSteps - 1 ? "continue_button" : "complete_button")
        }
        .padding(20)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.06), radius: 12, y: -4)
                .shadow(color: .purple.opacity(0.03), radius: 20, y: -8)
        )
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
        case 5:
            return true // Step 6 is optional, always allow proceeding
        case 6:
            return true // Step 7 (Lifestyle) is optional
        case 7:
            return true // Step 8 (Final Details) is optional
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

                // PERFORMANCE FIX: Upload photos in parallel while preserving order
                // This reduces upload time from 30s (6 photos × 5s) to ~5s
                // Using indexed tuples to maintain original photo order (first photo = profile pic)
                let photoURLs = try await withThrowingTaskGroup(of: (Int, String).self) { group in
                    // Add upload task for each photo with its index
                    for (index, image) in photoImages.enumerated() {
                        group.addTask {
                            let url = try await imageUploadService.uploadProfileImage(image, userId: userId)
                            return (index, url)
                        }
                    }

                    // Collect all URLs with their indices
                    var indexedURLs: [(Int, String)] = []
                    for try await result in group {
                        indexedURLs.append(result)
                    }

                    // Sort by original index to preserve order (first photo = profile picture)
                    return indexedURLs.sorted { $0.0 < $1.0 }.map { $0.1 }
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

                // Step 6 optional fields
                user.height = height
                user.relationshipGoal = (relationshipGoal == "Prefer not to say") ? nil : relationshipGoal
                user.ageRangeMin = ageRangeMin
                user.ageRangeMax = ageRangeMax

                // Step 6 - maxDistance
                user.maxDistance = maxDistance

                // Step 7 & 8 lifestyle fields
                if !educationLevel.isEmpty { user.educationLevel = educationLevel }
                if !religion.isEmpty { user.religion = religion }
                if !smoking.isEmpty { user.smoking = smoking }
                if !drinking.isEmpty { user.drinking = drinking }
                if !exercise.isEmpty { user.exercise = exercise }
                if !pets.isEmpty { user.pets = pets }
                if !diet.isEmpty { user.diet = diet }

                try await authService.updateUser(user)

                // Refresh user data to ensure profile shows updated photos immediately
                await authService.fetchUser()

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

    // MARK: - Load Existing User Data

    /// Pre-populate all fields with existing user data for profile editing
    /// This ensures data is preserved when users navigate back and forth
    private func loadExistingUserData() async {
        guard let user = authService.currentUser else { return }

        await MainActor.run {
            // Step 1: Basics
            fullName = user.fullName ?? ""
            gender = user.gender ?? "Male"

            // Calculate birthday from age (approximate)
            if user.age > 0 {
                let calendar = Calendar.current
                birthday = calendar.date(byAdding: .year, value: -user.age, to: Date()) ?? birthday
            }

            // Step 2: About & Location
            bio = user.bio ?? ""
            location = user.location ?? ""
            country = user.country ?? ""

            // Step 4: Preferences
            lookingFor = user.lookingFor ?? "Everyone"
            selectedInterests = user.interests ?? []
            selectedLanguages = user.languages ?? []

            // Step 6: Better Matches
            height = user.height
            relationshipGoal = user.relationshipGoal ?? "Prefer not to say"
            ageRangeMin = user.ageRangeMin ?? 18
            ageRangeMax = user.ageRangeMax ?? 50
            maxDistance = user.maxDistance ?? 50

            // Step 7 & 8: Lifestyle
            educationLevel = user.educationLevel ?? ""
            religion = user.religion ?? ""
            smoking = user.smoking ?? ""
            drinking = user.drinking ?? ""
            exercise = user.exercise ?? ""
            pets = user.pets ?? ""
            diet = user.diet ?? ""

            // Store existing photo URLs to avoid re-uploading unchanged photos
            existingPhotoURLs = user.photos ?? []
        }

        // Load existing photos as UIImages for display
        if let photoURLs = authService.currentUser?.photos, !photoURLs.isEmpty {
            await loadExistingPhotos(from: photoURLs)
        }
    }

    /// Load existing photos from URLs into UIImages for display in the photo picker
    private func loadExistingPhotos(from urls: [String]) async {
        var loadedImages: [UIImage] = []

        for urlString in urls {
            guard let url = URL(string: urlString) else { continue }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    loadedImages.append(image)
                }
            } catch {
                Logger.shared.error("Failed to load existing photo: \(urlString)", category: .storage, error: error)
            }
        }

        await MainActor.run {
            photoImages = loadedImages
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

