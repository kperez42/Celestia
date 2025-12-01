//
//  SignUpView.swift
//  Celestia
//
//  Multi-step sign up flow
//

import SwiftUI
import PhotosUI

struct SignUpView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @Environment(\.dismiss) var dismiss

    private let imageUploadService = ImageUploadService.shared

    @State private var currentStep = 1

    // Step 1: Basic info
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

    // Referral code (optional)
    @State private var referralCode = ""
    @State private var isValidatingReferral = false
    @State private var referralCodeValid: Bool? = nil

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

                            // Progress indicator
                            HStack(spacing: 10) {
                                ForEach(1...5, id: \.self) { step in
                                    Circle()
                                        .fill(currentStep >= step ? Color.purple : Color.gray.opacity(0.3))
                                        .frame(width: 12, height: 12)
                                        .scaleEffect(currentStep == step ? 1.2 : 1.0)
                                        .accessibleAnimation(.spring(response: 0.3, dampingFraction: 0.6), value: currentStep)
                                }
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Sign up progress")
                            .accessibilityValue("Step \(currentStep) of 5")
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
                            case 1:
                                step1Content
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                            case 2:
                                step2Content
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                            case 3:
                                step3Content
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                            case 4:
                                step4Content
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                            case 5:
                                step5Content
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
                            if currentStep > 1 {
                                Button {
                                    withAnimation {
                                        currentStep -= 1
                                    }
                                } label: {
                                    Text("Back")
                                        .font(.headline)
                                        .foregroundColor(.purple)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.white)
                                        .cornerRadius(15)
                                }
                                .accessibilityLabel("Back")
                                .accessibilityHint("Go back to previous step")
                                .accessibilityIdentifier(AccessibilityIdentifier.backButton)
                                .scaleButton()
                            }

                            Button {
                                handleNext()
                            } label: {
                                if authService.isLoading || isLoadingPhotos {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text(currentStep == 5 ? "Create Account" : "Next")
                                        .font(.headline)
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
                            .disabled(!canProceed || authService.isLoading || isLoadingPhotos)
                            .accessibilityLabel(currentStep == 5 ? "Create Account" : "Next")
                            .accessibilityHint(currentStep == 5 ? "Create your account and sign up" : "Continue to next step")
                            .accessibilityIdentifier(currentStep == 5 ? AccessibilityIdentifier.createAccountButton : AccessibilityIdentifier.nextButton)
                            .scaleButton()
                        }
                        .padding(.horizontal, 30)
                        .padding(.bottom, 30)
                    }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    // FIX: Auto-scroll to top when changing steps
                    .onChange(of: currentStep) { _, _ in
                        withAnimation {
                            scrollProxy.scrollTo("top", anchor: .top)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // FIX: Only show X button on step 1 (when there's no Back button)
                // On steps 2-4, the Back button serves as navigation
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentStep == 1 {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundColor(.primary)
                        }
                        .accessibilityLabel("Close")
                        .accessibilityHint("Cancel sign up and return")
                        .accessibilityIdentifier(AccessibilityIdentifier.closeButton)
                    }
                }
            }
        }
        .onChange(of: authService.userSession) { session in
            if session != nil {
                dismiss()
            }
        }
        .onAppear {
            // Pre-fill referral code from deep link
            if let deepLinkCode = deepLinkManager.referralCode {
                referralCode = deepLinkCode
                validateReferralCode(deepLinkCode)
                deepLinkManager.clearReferralCode()
                Logger.shared.info("Pre-filled referral code from deep link: \(deepLinkCode)", category: .referral)
            }
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
            // Engaging header card
            VStack(spacing: 16) {
                // Animated camera icon with gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.2), Color.pink.opacity(0.15), Color.orange.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.3), Color.pink.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(spacing: 8) {
                    Text("Time to shine!")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("Great photos get 10x more matches")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.05), Color.pink.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )

            // Quick tips in a horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    photoTipChip(icon: "face.smiling.fill", text: "Clear face shot", color: .purple)
                    photoTipChip(icon: "figure.stand", text: "Full body pic", color: .pink)
                    photoTipChip(icon: "heart.fill", text: "Show personality", color: .orange)
                    photoTipChip(icon: "sun.max.fill", text: "Good lighting", color: .yellow)
                }
                .padding(.horizontal, 4)
            }

            // Main profile photo (larger, more prominent)
            if !photoImages.isEmpty {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: photoImages[0])
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [.purple, .pink, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 3
                                )
                        )
                        .overlay(
                            VStack {
                                Spacer()
                                HStack(spacing: 6) {
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                    Text("Main Photo")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [.purple, .pink],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                                .padding(12)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        )
                        .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            _ = photoImages.remove(at: 0)
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

            // Additional photos grid - improved styling
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("More photos")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Text("\(max(0, photoImages.count - 1))/5 added")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(1..<6, id: \.self) { index in
                        if index < photoImages.count {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: photoImages[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 100)
                                    .clipped()
                                    .cornerRadius(14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                    )

                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        _ = photoImages.remove(at: index)
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

            // Progress indicator with encouraging message
            VStack(spacing: 12) {
                // Photo count dots with gradient
                HStack(spacing: 6) {
                    ForEach(0..<6, id: \.self) { index in
                        Circle()
                            .fill(
                                index < photoImages.count
                                    ? LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 10, height: 10)
                    }
                }

                // Encouraging message based on photo count
                Group {
                    if photoImages.count == 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.orange)
                            Text("Add at least 2 photos to continue")
                                .foregroundColor(.orange)
                        }
                    } else if photoImages.count == 1 {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.thumbsup.fill")
                                .foregroundColor(.orange)
                            Text("Great start! Add 1 more photo")
                                .foregroundColor(.orange)
                        }
                    } else if photoImages.count < 4 {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Looking good! More photos = more matches")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.purple)
                            Text("Amazing! Your profile will stand out")
                                .foregroundColor(.purple)
                        }
                    }
                }
                .font(.caption)
                .fontWeight(.medium)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Step 5: Review Guidelines
    var step5Content: some View {
        VStack(spacing: 24) {
            // Header card
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)

                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(spacing: 8) {
                    Text("Almost there!")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("Your profile will be reviewed before going live")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )

            // What we check section
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "checklist")
                        .font(.headline)
                        .foregroundColor(.purple)
                    Text("What We're Checking")
                        .font(.headline)
                }

                VStack(spacing: 12) {
                    guidelinesRow(
                        icon: "person.crop.circle.fill",
                        title: "Profile Photos",
                        description: "Clear, appropriate photos that show you",
                        color: .blue
                    )

                    guidelinesRow(
                        icon: "text.alignleft",
                        title: "Bio & Information",
                        description: "Complete and authentic profile details",
                        color: .purple
                    )

                    guidelinesRow(
                        icon: "shield.checkered",
                        title: "Community Guidelines",
                        description: "Content follows our safety policies",
                        color: .green
                    )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(.separator).opacity(0.2), lineWidth: 1)
            )

            // Info card
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "clock.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.orange)
                    }

                    Text("Quick Review")
                        .font(.headline)
                }

                Text("Our team reviews profiles within 24 hours. You'll be notified as soon as your profile is approved and ready to go!")
                    .font(.body)
                    .foregroundColor(.primary.opacity(0.85))
                    .lineSpacing(4)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.orange.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
            )

            // Confirmation checkbox style message
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)

                Text("By creating your account, you agree to follow our community guidelines")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green.opacity(0.08))
            )
        }
    }

    private func guidelinesRow(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 38, height: 38)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green.opacity(0.7))
                .font(.body)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
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
        switch currentStep {
        case 1: return "Create Account"
        case 2: return "Tell us about yourself"
        case 3: return "Where are you from?"
        case 4: return "Show Your Best Self"
        case 5: return "Review Guidelines"
        default: return ""
        }
    }

    var stepSubtitle: String {
        switch currentStep {
        case 1: return "Let's get started with your account"
        case 2: return "This helps us find your perfect match"
        case 3: return "Connect with people near and far"
        case 4: return "Photos help you make meaningful connections"
        case 5: return "Here's what happens next"
        default: return ""
        }
    }

    var canProceed: Bool {
        switch currentStep {
        case 1:
            return !email.isEmpty && password.count >= 6 && password == confirmPassword
        case 2:
            guard let ageInt = Int(age) else { return false }
            return !name.isEmpty && ageInt >= 18
        case 3:
            return !location.isEmpty && !country.isEmpty
        case 4:
            return photoImages.count >= 2
        case 5:
            return true // Guidelines step - always can proceed
        default:
            return false
        }
    }

    // MARK: - Actions
    func handleNext() {
        if currentStep < 5 {
            withAnimation {
                currentStep += 1
            }
        } else {
            // Final step - create account with photos
            guard let ageInt = Int(age) else { return }
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
                } catch {
                    Logger.shared.error("Error creating account", category: .authentication, error: error)
                    // Error is handled by AuthService setting errorMessage
                }
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

#Preview {
    SignUpView()
        .environmentObject(AuthService.shared)
}
