//
//  SignUpView.swift
//  Celestia
//
//  Multi-step sign up flow
//

import SwiftUI
import PhotosUI
import FirebaseFirestore

struct SignUpView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @Environment(\.dismiss) var dismiss

    // Edit mode - when true, pre-fills data and updates existing profile
    var isEditingProfile: Bool = false

    private let imageUploadService = ImageUploadService.shared

    @State private var currentStep = 0  // Start at email/password step (or step 1 if editing)

    // Step 0: Basic info (email/password)
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    // Step 2: Profile info
    @State private var name = ""
    @State private var age = ""
    @State private var gender = "Male"
    @State private var lookingFor = "Everyone"

    // Step 3: Location
    @State private var location = ""
    @State private var country = ""

    // Step 4: Photos
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoImages: [UIImage] = []
    @State private var isLoadingPhotos = false
    @State private var existingPhotoURLs: [String] = []  // For edit mode - existing photos to keep
    @State private var isLoadingExistingPhotos = false   // For edit mode - loading state
    @State private var isSavingProfile = false           // For edit mode - saving state
    @State private var photosWereModified = false        // For edit mode - track if photos changed

    // Full screen photo viewer state
    @State private var showFullScreenPhoto = false
    @State private var selectedPhotoIndex = 0

    // Referral code (optional)
    @State private var referralCode = ""
    @State private var isValidatingReferral = false
    @State private var referralCodeValid: Bool? = nil

    // Step 5: Bio
    @State private var bio = ""

    // Step 6: Interests
    @State private var selectedInterests: Set<String> = []
    let availableInterests = [
        "Travel", "Music", "Movies", "Fitness", "Reading", "Gaming",
        "Cooking", "Photography", "Art", "Dancing", "Hiking", "Yoga",
        "Sports", "Fashion", "Food", "Nature", "Pets", "Tech",
        "Coffee", "Wine", "Beach", "Mountains", "Nightlife", "Concerts"
    ]

    // Step 7: Lifestyle & Details
    @State private var height = ""
    @State private var relationshipGoal = ""
    @State private var educationLevel = ""
    @State private var smoking = ""
    @State private var drinking = ""
    @State private var religion = ""
    @State private var exercise = ""
    @State private var diet = ""
    @State private var pets = ""
    @State private var languages: [String] = []
    @State private var showLanguagePicker = false
    @State private var ageRangeMin: Int = 18
    @State private var ageRangeMax: Int = 35

    let relationshipGoalOptions = ["Long-term relationship", "Casual dating", "New friends", "Not sure yet"]
    let educationLevelOptions = ["High school", "Some college", "Bachelor's degree", "Master's degree", "Doctorate", "Trade school", "Prefer not to say"]
    let smokingOptions = ["Never", "Sometimes", "Regularly", "Prefer not to say"]
    let drinkingOptions = ["Never", "Socially", "Regularly", "Prefer not to say"]
    let religionOptions = ["Agnostic", "Atheist", "Buddhist", "Catholic", "Christian", "Hindu", "Jewish", "Muslim", "Spiritual", "Other", "Prefer not to say"]
    let exerciseOptions = ["Never", "Rarely", "Sometimes", "Often", "Daily", "Prefer not to say"]
    let dietOptions = ["No Restrictions", "Vegan", "Vegetarian", "Pescatarian", "Kosher", "Halal", "Prefer not to say"]
    let petsOptions = ["No Pets", "Dog", "Cat", "Both", "Other Pets", "Want Pets", "Prefer not to say"]
    let availableLanguages = [
        "English", "Spanish", "French", "German", "Italian", "Portuguese",
        "Chinese", "Japanese", "Korean", "Arabic", "Hindi", "Russian",
        "Dutch", "Swedish", "Norwegian", "Danish", "Polish", "Turkish",
        "Vietnamese", "Thai", "Indonesian", "Tagalog", "Greek", "Hebrew"
    ]

    let genderOptions = ["Male", "Female", "Non-binary", "Other"]
    let lookingForOptions = ["Men", "Women", "Everyone"]
    let availableCountries = [
        "United States", "Canada", "Mexico", "United Kingdom", "Australia",
        "Germany", "France", "Spain", "Italy", "Brazil", "Argentina",
        "Japan", "South Korea", "China", "India", "Philippines", "Vietnam",
        "Thailand", "Netherlands", "Sweden", "Norway", "Denmark", "Switzerland",
        "Ireland", "New Zealand", "Singapore", "Other"
    ]

    // Computed properties for validation
    private var passwordsMatch: Bool {
        !password.isEmpty && !confirmPassword.isEmpty && password == confirmPassword
    }

    // REFACTORED: Now uses ValidationHelper instead of duplicate email regex
    private var isValidEmail: Bool {
        return ValidationHelper.isValidEmail(email)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(spacing: 25) {
                            // Invisible anchor for scrolling to top
                            Color.clear
                                .frame(height: 1)
                                .id("top")

                            // Progress indicator for steps 0-6 (7 steps total)
                            HStack(spacing: 8) {
                                ForEach(0..<7, id: \.self) { step in
                                    Circle()
                                        .fill(currentStep >= step ? Color.purple : Color.gray.opacity(0.3))
                                        .frame(width: 10, height: 10)
                                        .scaleEffect(currentStep == step ? 1.2 : 1.0)
                                        .accessibleAnimation(.spring(response: 0.3, dampingFraction: 0.6), value: currentStep)
                                }
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Sign up progress")
                            .accessibilityValue("Step \(currentStep + 1) of 7")
                            .padding(.top, 10)
                        
                        // Header
                        VStack(spacing: 10) {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.purple)

                            Text(stepTitle)
                                .font(.title2.bold())

                            Text(stepSubtitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal)
                        
                        // Step content
                        Group {
                            switch currentStep {
                            case 0:
                                step1Content
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                            case 1:
                                step2Content
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                            case 2:
                                step3Content
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                            case 3:
                                step4Content
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                            case 4:
                                step5BioContent
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                            case 5:
                                step6InterestsContent
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                            case 6:
                                step7LifestyleContent
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                            default:
                                EmptyView()
                            }
                        }
                        .padding(.horizontal, 30)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                        
                        // Error message
                        if let errorMessage = authService.errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }
                        
                        // Navigation buttons
                        HStack(spacing: 15) {
                            // Back button - In edit mode: dismiss at step 1, otherwise go back
                            // In signup mode: dismiss at step 0, otherwise go back
                            Button {
                                HapticManager.shared.impact(.light)
                                let dismissStep = isEditingProfile ? 1 : 0
                                if currentStep == dismissStep {
                                    dismiss()
                                } else {
                                    withAnimation {
                                        currentStep -= 1
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    if !(isEditingProfile && currentStep == 1) {
                                        Image(systemName: "arrow.left")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    Text(isEditingProfile && currentStep == 1 ? "Cancel" : "Back")
                                        .font(.headline)
                                }
                                .foregroundColor(.purple)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(15)
                            }
                            .disabled(isSavingProfile)
                            .opacity(isSavingProfile ? 0.5 : 1.0)
                            .accessibilityLabel(isEditingProfile && currentStep == 1 ? "Cancel" : "Back")
                            .accessibilityHint(currentStep == (isEditingProfile ? 1 : 0) ? "Cancel and return" : "Go back to previous step")
                            .accessibilityIdentifier(AccessibilityIdentifier.backButton)
                            .scaleButton()

                            Button {
                                // Haptic feedback on tap
                                if currentStep == 6 {
                                    HapticManager.shared.impact(.medium)
                                } else {
                                    HapticManager.shared.impact(.light)
                                }
                                handleNext()
                            } label: {
                                if authService.isLoading || isLoadingPhotos || isLoadingExistingPhotos || isSavingProfile {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    HStack(spacing: 8) {
                                        Text(nextButtonText)
                                            .font(.headline)

                                        if currentStep < 6 {
                                            Image(systemName: "arrow.right")
                                                .font(.subheadline.weight(.semibold))
                                        }
                                    }
                                    .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color.purple, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(15)
                            .opacity(canProceed ? 1.0 : 0.5)
                            .disabled(!canProceed || authService.isLoading || isLoadingPhotos || isLoadingExistingPhotos || isSavingProfile)
                            .accessibilityLabel(nextButtonText)
                            .accessibilityHint(currentStep == 6 ? (isEditingProfile ? "Save your profile changes" : "Create your account and sign up") : "Continue to next step")
                            .accessibilityIdentifier(currentStep == 6 ? AccessibilityIdentifier.createAccountButton : AccessibilityIdentifier.nextButton)
                            .scaleButton()
                        }
                        .padding(.horizontal, 30)
                        .padding(.bottom, 30)
                    }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    // FIX: Auto-scroll to top and clear errors when changing steps
                    .onChange(of: currentStep) { _, _ in
                        // Clear any error messages when navigating between steps
                        authService.errorMessage = nil
                        withAnimation {
                            scrollProxy.scrollTo("top", anchor: .top)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            // No toolbar X button - Back button at bottom handles navigation
        }
        .onChange(of: authService.userSession) { session in
            // In edit mode, user is already logged in, so don't auto-dismiss on session change
            if !isEditingProfile && session != nil {
                dismiss()
            }
        }
        .onAppear {
            // Clear any error messages from other screens
            authService.errorMessage = nil

            // If editing existing profile, pre-fill all fields
            if isEditingProfile, let user = authService.currentUser {
                currentStep = 1  // Skip account creation step
                prefillUserData(user)
            }

            // Pre-fill referral code from deep link
            if let deepLinkCode = deepLinkManager.referralCode {
                referralCode = deepLinkCode
                validateReferralCode(deepLinkCode)
                deepLinkManager.clearReferralCode()
                Logger.shared.info("Pre-filled referral code from deep link: \(deepLinkCode)", category: .referral)
            }
        }
        .onDisappear {
            // Clear error messages when leaving
            authService.errorMessage = nil
        }
        .alert("Referral Bonus", isPresented: .constant(authService.referralBonusMessage != nil)) {
            Button("Awesome! 🎉") {
                authService.referralBonusMessage = nil
            }
        } message: {
            Text(authService.referralBonusMessage ?? "")
        }
        .alert("Referral Code Issue", isPresented: .constant(authService.referralErrorMessage != nil)) {
            Button("OK") {
                authService.referralErrorMessage = nil
            }
        } message: {
            Text(authService.referralErrorMessage ?? "")
        }
        .sheet(isPresented: $showLanguagePicker) {
            languagePickerSheet
        }
        .fullScreenCover(isPresented: $showFullScreenPhoto) {
            SignUpPhotoViewer(
                images: photoImages,
                selectedIndex: $selectedPhotoIndex,
                isPresented: $showFullScreenPhoto
            )
        }
    }

    // MARK: - Language Picker Sheet
    private var languagePickerSheet: some View {
        NavigationView {
            List {
                ForEach(availableLanguages, id: \.self) { language in
                    Button {
                        if languages.contains(language) {
                            languages.removeAll { $0 == language }
                        } else {
                            languages.append(language)
                        }
                        HapticManager.shared.impact(.light)
                    } label: {
                        HStack {
                            Text(language)
                                .foregroundColor(.primary)
                            Spacer()
                            if languages.contains(language) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Languages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showLanguagePicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Step 1: Basic Info
    var step1Content: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("your@email.com", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .accessibilityLabel("Email address")
                    .accessibilityHint("Enter your email address")
                    .accessibilityIdentifier(AccessibilityIdentifier.emailField)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                SecureField("Min. 6 characters", text: $password)
                    .textContentType(.newPassword)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .accessibilityLabel("Password")
                    .accessibilityHint("Enter at least 6 characters")
                    .accessibilityIdentifier(AccessibilityIdentifier.passwordField)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Confirm Password")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                SecureField("Re-enter password", text: $confirmPassword)
                    .textContentType(.newPassword)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(passwordsMatch ? Color.green : (!password.isEmpty && !confirmPassword.isEmpty && password != confirmPassword ? Color.red : Color.clear), lineWidth: 2)
                    )
                    .accessibilityLabel("Confirm password")
                    .accessibilityHint("Re-enter your password to confirm")
                    .accessibilityValue(passwordsMatch ? "Passwords match" : (password != confirmPassword && !confirmPassword.isEmpty ? "Passwords do not match" : ""))
                    .accessibilityIdentifier("confirm_password_field")
            }

            // Password validation feedback
            if !password.isEmpty && !confirmPassword.isEmpty {
                if password != confirmPassword {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Passwords do not match")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Passwords match")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }

            // Password strength indicator
            if !password.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: password.count >= 6 ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(password.count >= 6 ? .green : .gray)
                    Text("At least 6 characters")
                        .font(.caption)
                        .foregroundColor(password.count >= 6 ? .green : .secondary)
                }
            }
        }
    }
    
    // MARK: - Step 2: Profile Info
    var step2Content: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Your name", text: $name)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .accessibilityLabel("Name")
                    .accessibilityHint("Enter your full name")
                    .accessibilityIdentifier(AccessibilityIdentifier.nameField)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Age")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("18", text: $age)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .accessibilityLabel("Age")
                    .accessibilityHint("Enter your age, must be 18 or older")
                    .accessibilityIdentifier(AccessibilityIdentifier.ageField)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("I am")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Gender", selection: $gender) {
                    ForEach(genderOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Gender")
                .accessibilityHint("Select your gender identity")
                .accessibilityValue(gender)
                .accessibilityIdentifier(AccessibilityIdentifier.genderPicker)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Looking for")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Looking for", selection: $lookingFor) {
                    ForEach(lookingForOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Looking for")
                .accessibilityHint("Select who you're interested in meeting")
                .accessibilityValue(lookingFor)
                .accessibilityIdentifier(AccessibilityIdentifier.lookingForPicker)
            }

            // Validation feedback for step 2
            if currentStep == 2 {
                VStack(alignment: .leading, spacing: 6) {
                    if name.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                            Text("Please enter your name")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    if let ageInt = Int(age) {
                        if ageInt < 18 {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("You must be 18 or older to use Celestia")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    } else if !age.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                            Text("Please enter a valid age")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                            Text("Please enter your age")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Step 3: Location
    var step3Content: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("City")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("e.g. Los Angeles", text: $location)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .accessibilityLabel("City")
                    .accessibilityHint("Enter your city")
                    .accessibilityIdentifier(AccessibilityIdentifier.locationField)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Country")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

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
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                }
                .accessibilityLabel("Country")
                .accessibilityHint("Select your country from the list")
                .accessibilityValue(country.isEmpty ? "No country selected" : country)
                .accessibilityIdentifier(AccessibilityIdentifier.countryField)
            }

            // Referral Code (Optional)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "gift.fill")
                        .foregroundColor(.purple)
                        .font(.caption)
                    Text("Referral Code (Optional)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack {
                    TextField("CEL-XXXXXXXX", text: $referralCode)
                        .textInputAutocapitalization(.characters)
                        .onChange(of: referralCode) { oldValue, newValue in
                            validateReferralCode(newValue)
                        }
                        .accessibilityLabel("Referral code")
                        .accessibilityHint("Optional. Enter a referral code to get 3 days of Premium free")
                        .accessibilityValue(referralCodeValid == true ? "Valid code" : (referralCodeValid == false ? "Invalid code" : ""))
                        .accessibilityIdentifier("referral_code_field")

                    if isValidatingReferral {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if let isValid = referralCodeValid {
                        Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(isValid ? .green : .red)
                            .font(.title3)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            referralCodeValid == true ? Color.green :
                            referralCodeValid == false ? Color.red :
                            Color.purple.opacity(0.3),
                            lineWidth: 2
                        )
                )

                if referralCodeValid == true {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("Valid code! You'll get 3 days of Premium free!")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                } else if referralCodeValid == false {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text("Invalid referral code")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                } else if referralCode.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundColor(.purple)
                        Text("Get 3 days of Premium free with a code!")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }
            }
            .padding(.top, 8)

            Text("Your location helps connect you with people nearby and around the world")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
        }
    }

    // MARK: - Step 4: Photos
    var step4Content: some View {
        VStack(spacing: 24) {
            // Clean header card
            HStack(spacing: 16) {
                // Camera icon
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.12))
                        .frame(width: 56, height: 56)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Time to shine!")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Great photos get 10x more matches")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            )

            // Quick tips in a horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    photoTipChip(icon: "face.smiling.fill", text: "Clear face shot", color: .purple)
                    photoTipChip(icon: "heart.fill", text: "Show personality", color: .pink)
                    photoTipChip(icon: "sun.max.fill", text: "Good lighting", color: .orange)
                }
                .padding(.horizontal, 4)
            }

            // Main profile photo (larger, more prominent)
            if !photoImages.isEmpty {
                ZStack(alignment: .topTrailing) {
                    GeometryReader { geometry in
                        Image(uiImage: photoImages[0])
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: 220)
                            .clipped()
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                    )
                    .overlay(
                        VStack {
                            Spacer()
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                    Text("Main Photo")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.purple)
                                )

                                Spacer()

                                // Tap to view hint
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.caption2)
                                    Text("Tap to view")
                                        .font(.caption2)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.5))
                                )
                            }
                            .padding(10)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        HapticManager.shared.impact(.light)
                        selectedPhotoIndex = 0
                        showFullScreenPhoto = true
                    }

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            _ = photoImages.remove(at: 0)
                            photosWereModified = true
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .padding(12)
                    }
                }
            } else {
                // Empty main photo placeholder - more inviting
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 6,
                    matching: .images
                ) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.08), Color.pink.opacity(0.05), Color.orange.opacity(0.03)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 220)
                        .overlay(
                            VStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.purple.opacity(0.1))
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

                                VStack(spacing: 6) {
                                    Text("Add your best photo")
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Text("Tap here to choose from your library")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [.purple.opacity(0.4), .pink.opacity(0.3), .orange.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 2, dash: [10, 6])
                                )
                        )
                }
                .onChange(of: selectedPhotos) { _, newValue in
                    Task {
                        await loadSelectedPhotos(newValue)
                    }
                }
            }

            // Additional photos grid - matching card style
            VStack(alignment: .leading, spacing: 16) {
                // Header card matching "Time to shine" style
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.pink.opacity(0.12))
                            .frame(width: 56, height: 56)

                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.pink)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Add more photos")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("\(max(0, photoImages.count - 1))/5 additional photos")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                )

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(1..<6, id: \.self) { index in
                        if index < photoImages.count {
                            ZStack(alignment: .topTrailing) {
                                GeometryReader { geometry in
                                    Image(uiImage: photoImages[index])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: geometry.size.width, height: 100)
                                        .clipped()
                                }
                                .frame(height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    HapticManager.shared.impact(.light)
                                    selectedPhotoIndex = index
                                    showFullScreenPhoto = true
                                }

                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        _ = photoImages.remove(at: index)
                                        photosWereModified = true
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.body)
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                        .padding(6)
                                }
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(.systemBackground))
                                .frame(height: 100)
                                .overlay(
                                    VStack(spacing: 4) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [.purple.opacity(0.4), .pink.opacity(0.3)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(
                                            LinearGradient(
                                                colors: [.purple.opacity(0.2), .pink.opacity(0.15)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                                        )
                                )
                        }
                    }
                }
            }

            // Photo picker button - more prominent when photos are empty
            if !photoImages.isEmpty {
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 6 - photoImages.count,
                    matching: .images
                ) {
                    HStack(spacing: 10) {
                        Image(systemName: "photo.badge.plus.fill")
                            .font(.body)
                        Text("Add More Photos")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.pink, Color.orange.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(photoImages.count >= 6 || isLoadingPhotos)
                .onChange(of: selectedPhotos) { _, newValue in
                    Task {
                        await loadSelectedPhotos(newValue)
                    }
                }
            }

            // Progress indicator card - matching style
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(progressIconColor.opacity(0.12))
                        .frame(width: 56, height: 56)

                    Image(systemName: progressIcon)
                        .font(.system(size: 24))
                        .foregroundColor(progressIconColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(progressTitle)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(progressSubtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // Photo count dots
                    HStack(spacing: 6) {
                        ForEach(0..<6, id: \.self) { index in
                            Circle()
                                .fill(
                                    index < photoImages.count
                                        ? LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        : LinearGradient(colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.top, 2)
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            )
        }
    }

    // MARK: - Step 5: Bio
    private let bioPrompts = [
        "I'm happiest when...",
        "On weekends you'll find me...",
        "Looking for someone who...",
        "My friends describe me as...",
        "I can't live without...",
        "Let's talk about..."
    ]

    var step5BioContent: some View {
        VStack(spacing: 20) {
            // Bio prompts - tappable suggestions
            VStack(alignment: .leading, spacing: 12) {
                Text("Need inspiration? Tap a prompt:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(bioPrompts, id: \.self) { prompt in
                            Button {
                                if bio.isEmpty {
                                    bio = prompt + " "
                                } else if !bio.contains(prompt) {
                                    bio += (bio.hasSuffix(" ") || bio.hasSuffix("\n") ? "" : " ") + prompt + " "
                                }
                                HapticManager.shared.impact(.light)
                            } label: {
                                Text(prompt)
                                    .font(.caption)
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color.purple.opacity(0.1))
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            // Bio text editor
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("About You")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(bio.count)/500")
                        .font(.caption)
                        .foregroundColor(bio.count >= 20 ? .green : .secondary)
                }

                TextEditor(text: $bio)
                    .frame(minHeight: 150)
                    .padding(12)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(bio.count >= 20 ? Color.green.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .onChange(of: bio) { _, newValue in
                        if newValue.count > 500 {
                            bio = String(newValue.prefix(500))
                        }
                    }

                if bio.count < 20 {
                    Text("Write at least 20 characters to continue")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            // Bio tips - cleaner card
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tips for a great bio")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Be yourself and stay authentic")
                        Text("• Share your passions and hobbies")
                        Text("• Add a fun fact or conversation starter")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
            )
        }
    }

    // MARK: - Step 6: Interests
    var step6InterestsContent: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Select your interests")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(selectedInterests.count) selected")
                        .font(.caption)
                        .foregroundColor(selectedInterests.count >= 3 ? .purple : .purple.opacity(0.6))
                }

                if selectedInterests.count < 3 {
                    Text("Pick at least 3 interests to continue")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
            }

            // Interests grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                ForEach(availableInterests, id: \.self) { interest in
                    InterestChip(
                        interest: interest,
                        isSelected: selectedInterests.contains(interest),
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if selectedInterests.contains(interest) {
                                    selectedInterests.remove(interest)
                                } else {
                                    selectedInterests.insert(interest)
                                }
                            }
                            HapticManager.shared.impact(.light)
                        }
                    )
                }
            }

            // Selected count indicator
            if selectedInterests.count >= 3 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.purple)
                    Text("Great choices! You can select more if you'd like.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.purple.opacity(0.1))
                )
            }
        }
    }

    // MARK: - Step 7: Lifestyle Details
    private let heightOptions: [String] = {
        var heights: [String] = [""]
        // Generate heights from 4'8" to 7'0"
        for feet in 4...7 {
            let maxInches = feet == 7 ? 0 : 11
            let minInches = feet == 4 ? 8 : 0
            for inches in minInches...maxInches {
                heights.append("\(feet)'\(inches)\"")
            }
        }
        return heights
    }()

    var step7LifestyleContent: some View {
        VStack(spacing: 20) {
            // About You Card - matching photos page style
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.12))
                        .frame(width: 56, height: 56)

                    Image(systemName: "person.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("About You")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Optional details")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            )

            // Height and Relationship dropdowns - stacked vertically
            VStack(spacing: 12) {
                detailsDropdown(
                    label: "Height",
                    selection: height.isEmpty ? "Select" : height,
                    options: heightOptions.dropFirst().map { $0 },
                    onSelect: { height = $0 }
                )

                detailsDropdown(
                    label: "Looking for",
                    selection: relationshipGoal.isEmpty ? "Select" : relationshipGoal,
                    options: relationshipGoalOptions,
                    onSelect: { relationshipGoal = $0 }
                )
            }

            // Education Card
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 56, height: 56)

                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Education")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Your background")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            )

            detailsDropdown(
                label: "Education level",
                selection: educationLevel.isEmpty ? "Select" : educationLevel,
                options: educationLevelOptions,
                onSelect: { educationLevel = $0 }
            )

            // Lifestyle Card
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 56, height: 56)

                    Image(systemName: "leaf.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Lifestyle")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Your habits")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            )

            // Smoking and Drinking - stacked vertically
            VStack(spacing: 12) {
                detailsDropdown(
                    label: "Smoking",
                    selection: smoking.isEmpty ? "Select" : smoking,
                    options: smokingOptions,
                    onSelect: { smoking = $0 }
                )

                detailsDropdown(
                    label: "Drinking",
                    selection: drinking.isEmpty ? "Select" : drinking,
                    options: drinkingOptions,
                    onSelect: { drinking = $0 }
                )

                detailsDropdown(
                    label: "Exercise",
                    selection: exercise.isEmpty ? "Select" : exercise,
                    options: exerciseOptions,
                    onSelect: { exercise = $0 }
                )

                detailsDropdown(
                    label: "Diet",
                    selection: diet.isEmpty ? "Select" : diet,
                    options: dietOptions,
                    onSelect: { diet = $0 }
                )
            }

            // More About You Card
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 56, height: 56)

                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("More About You")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Optional extras")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            )

            VStack(spacing: 12) {
                detailsDropdown(
                    label: "Religion / Spirituality",
                    selection: religion.isEmpty ? "Select" : religion,
                    options: religionOptions,
                    onSelect: { religion = $0 }
                )

                detailsDropdown(
                    label: "Pets",
                    selection: pets.isEmpty ? "Select" : pets,
                    options: petsOptions,
                    onSelect: { pets = $0 }
                )

                // Languages picker
                Button {
                    showLanguagePicker = true
                    HapticManager.shared.impact(.light)
                } label: {
                    HStack {
                        Text("Languages")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        if languages.isEmpty {
                            Text("Select")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        } else {
                            Text(languages.prefix(2).joined(separator: ", ") + (languages.count > 2 ? " +\(languages.count - 2)" : ""))
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }

                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                    )
                }
            }

            // Age Preference Card
            VStack(spacing: 16) {
                // Header with icon
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.pink.opacity(0.12))
                            .frame(width: 56, height: 56)

                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.pink)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Age Preference")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("Who would you like to meet?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Age range badge
                    Text("\(ageRangeMin) - \(ageRangeMax)")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            LinearGradient(
                                colors: [.pink, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }

                // Age pickers
                HStack(spacing: 16) {
                    // Min age
                    VStack(spacing: 6) {
                        Text("From")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("Min Age", selection: $ageRangeMin) {
                            ForEach(18..<99, id: \.self) { age in
                                Text("\(age)").tag(age)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 70, height: 90)
                        .clipped()
                        .onChange(of: ageRangeMin) { _, newValue in
                            if newValue >= ageRangeMax {
                                ageRangeMax = newValue + 1
                            }
                        }
                    }

                    Text("to")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // Max age
                    VStack(spacing: 6) {
                        Text("To")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("Max Age", selection: $ageRangeMax) {
                            ForEach(19..<100, id: \.self) { age in
                                Text("\(age)").tag(age)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 70, height: 90)
                        .clipped()
                        .onChange(of: ageRangeMax) { _, newValue in
                            if newValue <= ageRangeMin {
                                ageRangeMin = newValue - 1
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            )

            // Completion card - matching style
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.12))
                        .frame(width: 56, height: 56)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("You're all set!")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Tap 'Create Account' to get started")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            )
        }
    }

    // Reusable dropdown for details page
    private func detailsDropdown(label: String, selection: String, options: [String], onSelect: @escaping (String) -> Void) -> some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) {
                    onSelect(option)
                    HapticManager.shared.impact(.light)
                }
            }
        } label: {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text(selection)
                    .font(.subheadline)
                    .foregroundColor(selection == "Select" ? .gray : .primary)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private func photoTipChip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
        )
        .overlay(
            Capsule()
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }

    private func photoTipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.purple)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        isLoadingPhotos = true
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    if photoImages.count < 6 {
                        photoImages.append(image)
                        photosWereModified = true  // User added new photos
                    }
                }
            }
        }
        await MainActor.run {
            selectedPhotos = []
            isLoadingPhotos = false
        }
    }

    // MARK: - Computed Properties
    var stepTitle: String {
        if isEditingProfile && currentStep == 1 {
            return "Edit Your Profile"
        }
        switch currentStep {
        case 0: return "Create Account"
        case 1: return "Tell us about yourself"
        case 2: return "Where are you from?"
        case 3: return "Show Your Best Self"
        case 4: return "Write Your Bio"
        case 5: return "Your Interests"
        case 6: return "A Few More Details"
        default: return ""
        }
    }

    var nextButtonText: String {
        if currentStep == 6 {
            return isEditingProfile ? "Save Changes" : "Create Account"
        }
        return "Next"
    }

    var stepSubtitle: String {
        switch currentStep {
        case 0: return "Let's get started with your account"
        case 1: return "This helps us find your perfect match"
        case 2: return "Connect with people near and far"
        case 3: return "Photos help you make meaningful connections"
        case 4: return "Let others know what makes you unique"
        case 5: return "Help us find people with similar vibes"
        case 6: return "Optional info to complete your profile"
        default: return ""
        }
    }

    // Progress card computed properties
    var progressIcon: String {
        if photoImages.count == 0 {
            return "sparkles"
        } else if photoImages.count == 1 {
            return "hand.thumbsup.fill"
        } else if photoImages.count < 4 {
            return "checkmark.circle.fill"
        } else {
            return "star.fill"
        }
    }

    var progressIconColor: Color {
        if photoImages.count < 2 {
            return .orange
        } else if photoImages.count < 4 {
            return .green
        } else {
            return .purple
        }
    }

    var progressTitle: String {
        if photoImages.count == 0 {
            return "Get started!"
        } else if photoImages.count == 1 {
            return "Great start!"
        } else if photoImages.count < 4 {
            return "Looking good!"
        } else {
            return "Amazing!"
        }
    }

    var progressSubtitle: String {
        if photoImages.count == 0 {
            return "Add at least 2 photos to continue"
        } else if photoImages.count == 1 {
            return "Add 1 more photo to continue"
        } else if photoImages.count < 4 {
            return "More photos = more matches"
        } else {
            return "Your profile will stand out"
        }
    }

    var canProceed: Bool {
        switch currentStep {
        case 0:
            return !email.isEmpty && password.count >= 6 && password == confirmPassword
        case 1:
            guard let ageInt = Int(age) else { return false }
            return !name.isEmpty && ageInt >= 18
        case 2:
            return !location.isEmpty && !country.isEmpty
        case 3:
            return photoImages.count >= 2
        case 4:
            return bio.count >= 20  // Require at least 20 characters for bio
        case 5:
            return selectedInterests.count >= 3  // Require at least 3 interests
        case 6:
            return true  // Lifestyle details are optional
        default:
            return false
        }
    }

    // MARK: - Helper Functions

    /// Pre-fill all fields from existing user data (for edit mode)
    private func prefillUserData(_ user: User) {
        // Basic info
        name = user.fullName
        age = String(user.age)
        gender = user.gender
        lookingFor = user.lookingFor

        // Location
        location = user.location
        country = user.country

        // Bio
        bio = user.bio

        // Interests
        selectedInterests = Set(user.interests)

        // Lifestyle details
        if let userHeight = user.height {
            height = formatHeightForDisplay(userHeight)
        }
        relationshipGoal = user.relationshipGoal ?? ""
        educationLevel = user.educationLevel ?? ""
        smoking = user.smoking ?? ""
        drinking = user.drinking ?? ""
        religion = user.religion ?? ""
        exercise = user.exercise ?? ""
        diet = user.diet ?? ""
        pets = user.pets ?? ""
        languages = user.languages
        ageRangeMin = user.ageRangeMin ?? 18
        ageRangeMax = user.ageRangeMax ?? 35

        // Load existing photos from URLs
        existingPhotoURLs = user.photos
        loadExistingPhotos(from: user.photos)
    }

    /// Load existing photos from URLs into photoImages array (parallel download for speed)
    private func loadExistingPhotos(from urls: [String]) {
        guard !urls.isEmpty else {
            isLoadingExistingPhotos = false
            return
        }

        isLoadingExistingPhotos = true
        Task {
            // Download all photos in parallel for faster loading
            let loadedImages = await withTaskGroup(of: (Int, UIImage?).self) { group in
                for (index, urlString) in urls.enumerated() {
                    group.addTask {
                        guard let url = URL(string: urlString) else { return (index, nil) }
                        do {
                            let (data, _) = try await URLSession.shared.data(from: url)
                            return (index, UIImage(data: data))
                        } catch {
                            Logger.shared.error("Failed to load photo from URL: \(urlString)", category: .general, error: error)
                            return (index, nil)
                        }
                    }
                }

                // Collect results and sort by original index to maintain order
                var results: [(Int, UIImage?)] = []
                for await result in group {
                    results.append(result)
                }
                return results.sorted { $0.0 < $1.0 }.compactMap { $0.1 }
            }

            await MainActor.run {
                photoImages = loadedImages
                isLoadingExistingPhotos = false
            }
        }
    }

    /// Convert height in cm to display format (e.g., "5'10\"")
    private func formatHeightForDisplay(_ cm: Int) -> String {
        let totalInches = Double(cm) / 2.54
        let feet = Int(totalInches) / 12
        let inches = Int(totalInches) % 12
        return "\(feet)'\(inches)\""
    }

    /// Parse height string to cm (handles formats like "5'10" or "178cm" or "178")
    private func parseHeight(_ heightString: String) -> Int? {
        let trimmed = heightString.trimmingCharacters(in: .whitespaces).lowercased()

        // Try feet/inches format (e.g., "5'10" or "5'10\"")
        if trimmed.contains("'") {
            let parts = trimmed.replacingOccurrences(of: "\"", with: "").split(separator: "'")
            if parts.count >= 1, let feet = Int(parts[0]) {
                let inches = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
                return Int(Double(feet * 12 + inches) * 2.54)
            }
        }

        // Try cm format (e.g., "178cm" or "178")
        let numericString = trimmed.replacingOccurrences(of: "cm", with: "")
        if let cm = Int(numericString) {
            return cm
        }

        return nil
    }

    // MARK: - Actions
    func handleNext() {
        if currentStep < 6 {
            withAnimation {
                currentStep += 1
            }
        } else {
            // Final step - create account or save profile changes
            if isEditingProfile {
                // Edit mode - update existing profile
                handleSaveProfileChanges()
            } else {
                // New account mode - create account directly
                // (Guidelines were already shown in WelcomeAwarenessSlidesView before signup)
                handleCreateAccount()
            }
        }
    }

    /// Save profile changes when in edit mode
    private func handleSaveProfileChanges() {
        isSavingProfile = true
        Task {
            defer {
                Task { @MainActor in
                    isSavingProfile = false
                }
            }

            guard var user = authService.currentUser else {
                Logger.shared.error("No current user when saving profile changes", category: .authentication)
                return
            }

            // Update basic info
            user.fullName = InputSanitizer.strict(name)
            user.age = Int(age) ?? user.age
            user.gender = gender
            user.lookingFor = lookingFor

            // Update location
            user.location = InputSanitizer.standard(location)
            user.country = InputSanitizer.basic(country)

            // Update bio and interests
            user.bio = InputSanitizer.standard(bio)
            user.interests = Array(selectedInterests)

            // Update height if provided
            if !height.isEmpty {
                user.height = parseHeight(height)
            }

            // Update lifestyle details
            user.relationshipGoal = relationshipGoal.isEmpty ? nil : relationshipGoal
            user.educationLevel = educationLevel.isEmpty ? nil : educationLevel
            user.smoking = smoking.isEmpty ? nil : smoking
            user.drinking = drinking.isEmpty ? nil : drinking
            user.religion = religion.isEmpty || religion == "Prefer not to say" ? nil : religion
            user.exercise = exercise.isEmpty || exercise == "Prefer not to say" ? nil : exercise
            user.diet = diet.isEmpty || diet == "Prefer not to say" ? nil : diet
            user.pets = pets.isEmpty || pets == "Prefer not to say" ? nil : pets
            user.languages = languages
            user.ageRangeMin = ageRangeMin
            user.ageRangeMax = ageRangeMax

            do {
                // Only upload photos if they were actually modified by the user
                if photosWereModified && !photoImages.isEmpty {
                    let userId = user.effectiveId ?? ""
                    let photosPath = "users/\(userId)/photos"
                    let uploadedURLs = try await imageUploadService.uploadMultipleImages(photoImages, path: photosPath)
                    user.photos = uploadedURLs
                    user.profileImageURL = uploadedURLs.first ?? user.profileImageURL
                }

                // Save the updated user
                try await authService.updateUser(user)
                Logger.shared.info("Profile updated successfully in edit mode", category: .authentication)

                // Dismiss the view
                await MainActor.run {
                    dismiss()
                }
            } catch {
                Logger.shared.error("Failed to update profile", category: .authentication, error: error)
                await MainActor.run {
                    authService.errorMessage = "Failed to update profile: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Create new account (original signup flow)
    private func handleCreateAccount() {
        let ageInt = Int(age) ?? 18
        Task {
            do {
                try await authService.createUser(
                    withEmail: InputSanitizer.email(email),
                    password: password,
                    fullName: InputSanitizer.strict(name),
                    age: ageInt,
                    gender: gender,
                    lookingFor: lookingFor,
                    location: InputSanitizer.standard(location),
                    country: InputSanitizer.basic(country),
                    referralCode: InputSanitizer.referralCode(referralCode),
                    photos: photoImages
                )

                // Update profile with additional data (bio, interests, lifestyle)
                // Use userSession UID directly to ensure data is saved even if currentUser isn't set yet
                guard let userId = authService.userSession?.uid else {
                    Logger.shared.error("No user session after createUser - profile data not saved", category: .authentication)
                    return
                }

                // Build the profile data update
                var profileData: [String: Any] = [
                    "bio": InputSanitizer.standard(bio),
                    "interests": Array(selectedInterests),
                    "ageRangeMin": ageRangeMin,
                    "ageRangeMax": ageRangeMax
                ]

                // Add height if provided
                if !height.isEmpty, let parsedHeight = parseHeight(height) {
                    profileData["height"] = parsedHeight
                    Logger.shared.info("Setting height: \(height) -> \(parsedHeight) cm", category: .authentication)
                }

                // Add optional lifestyle details
                if !relationshipGoal.isEmpty {
                    profileData["relationshipGoal"] = relationshipGoal
                }
                if !educationLevel.isEmpty {
                    profileData["educationLevel"] = educationLevel
                }
                if !smoking.isEmpty {
                    profileData["smoking"] = smoking
                }
                if !drinking.isEmpty {
                    profileData["drinking"] = drinking
                }
                if !religion.isEmpty && religion != "Prefer not to say" {
                    profileData["religion"] = religion
                }
                if !exercise.isEmpty && exercise != "Prefer not to say" {
                    profileData["exercise"] = exercise
                }
                if !diet.isEmpty && diet != "Prefer not to say" {
                    profileData["diet"] = diet
                }
                if !pets.isEmpty && pets != "Prefer not to say" {
                    profileData["pets"] = pets
                }
                if !languages.isEmpty {
                    profileData["languages"] = languages
                }

                // Save profile data directly to Firestore
                do {
                    try await Firestore.firestore().collection("users").document(userId).updateData(profileData)
                    Logger.shared.info("Profile data saved successfully - bio: \(bio.count) chars, interests: \(selectedInterests.count)", category: .authentication)

                    // Also update currentUser if it's now available
                    if var user = authService.currentUser {
                        user.bio = InputSanitizer.standard(bio)
                        user.interests = Array(selectedInterests)
                        user.ageRangeMin = ageRangeMin
                        user.ageRangeMax = ageRangeMax
                        if !height.isEmpty {
                            user.height = parseHeight(height)
                        }
                        if !relationshipGoal.isEmpty {
                            user.relationshipGoal = relationshipGoal
                        }
                        if !educationLevel.isEmpty {
                            user.educationLevel = educationLevel
                        }
                        if !smoking.isEmpty {
                            user.smoking = smoking
                        }
                        if !drinking.isEmpty {
                            user.drinking = drinking
                        }
                        if !religion.isEmpty && religion != "Prefer not to say" {
                            user.religion = religion
                        }
                        if !exercise.isEmpty && exercise != "Prefer not to say" {
                            user.exercise = exercise
                        }
                        if !diet.isEmpty && diet != "Prefer not to say" {
                            user.diet = diet
                        }
                        if !pets.isEmpty && pets != "Prefer not to say" {
                            user.pets = pets
                        }
                        if !languages.isEmpty {
                            user.languages = languages
                        }
                        // Update local currentUser
                        await MainActor.run {
                            authService.currentUser = user
                        }
                    }
                } catch {
                    Logger.shared.error("Failed to save profile data", category: .authentication, error: error)
                }
            } catch {
                Logger.shared.error("Error creating account", category: .authentication, error: error)
                // Error is handled by AuthService setting errorMessage
            }
        }
    }

    // MARK: - Referral Code Validation

    func validateReferralCode(_ code: String) {
        let trimmedCode = code.trimmingCharacters(in: .whitespaces).uppercased()

        // Reset validation if code is empty
        guard !trimmedCode.isEmpty else {
            referralCodeValid = nil
            return
        }

        // Don't validate if code is too short
        guard trimmedCode.count >= 8 else {
            referralCodeValid = nil
            return
        }

        isValidatingReferral = true
        referralCodeValid = nil

        Task {
            let isValid = await ReferralManager.shared.validateReferralCode(trimmedCode)

            await MainActor.run {
                isValidatingReferral = false
                referralCodeValid = isValid
                HapticManager.shared.notification(isValid ? .success : .error)
            }
        }
    }
}

// MARK: - Full Screen Photo Viewer for UIImages

struct SignUpPhotoViewer: View {
    let images: [UIImage]
    @Binding var selectedIndex: Int
    @Binding var isPresented: Bool

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if images.isEmpty {
                Text("No photos to display")
                    .foregroundColor(.white)
            } else {
                TabView(selection: $selectedIndex) {
                    ForEach(images.indices, id: \.self) { index in
                        ZoomableImageView(image: images[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }

            // Close button and counter overlay
            VStack {
                HStack {
                    // Photo counter
                    if images.count > 1 {
                        Text("\(selectedIndex + 1) / \(images.count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(20)
                    }

                    Spacer()

                    // Close button
                    Button {
                        HapticManager.shared.impact(.light)
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white, Color.black.opacity(0.6))
                    }
                }
                .padding()
                .padding(.top, 40)

                Spacer()

                // Swipe hint
                if images.count > 1 {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.draw")
                            .font(.caption)
                        Text("Swipe to see more photos")
                            .font(.caption)
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 80)
                }
            }
        }
    }
}

// Zoomable image view for pinch-to-zoom
struct ZoomableImageView: View {
    let image: UIImage

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = lastScale * value
                        }
                        .onEnded { _ in
                            withAnimation(.spring()) {
                                if scale < 1.0 {
                                    scale = 1.0
                                } else if scale > 4.0 {
                                    scale = 4.0
                                }
                                lastScale = scale
                            }
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring()) {
                        if scale > 1.0 {
                            scale = 1.0
                            lastScale = 1.0
                        } else {
                            scale = 2.0
                            lastScale = 2.0
                        }
                    }
                }
        }
    }
}

#Preview {
    SignUpView()
        .environmentObject(AuthService.shared)
}
