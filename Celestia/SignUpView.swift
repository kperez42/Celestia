//
//  SignUpView.swift
//  Celestia
//
//  Multi-step sign up flow
//

import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @Environment(\.dismiss) var dismiss

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

    // Referral code (optional)
    @State private var referralCode = ""
    @State private var isValidatingReferral = false
    @State private var referralCodeValid: Bool? = nil

    let genderOptions = ["Male", "Female", "Non-binary", "Other"]
    let lookingForOptions = ["Men", "Women", "Everyone"]

    // Computed properties for validation
    private var passwordsMatch: Bool {
        !password.isEmpty && !confirmPassword.isEmpty && password == confirmPassword
    }

    private var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Progress indicator
                        HStack(spacing: 10) {
                            ForEach(1...3, id: \.self) { step in
                                Circle()
                                    .fill(currentStep >= step ? Color.purple : Color.gray.opacity(0.3))
                                    .frame(width: 12, height: 12)
                                    .scaleEffect(currentStep == step ? 1.2 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: currentStep)
                            }
                        }
                        .padding(.top, 20)
                        
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
                                .scaleButton()
                            }

                            Button {
                                handleNext()
                            } label: {
                                if authService.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text(currentStep == 3 ? "Create Account" : "Next")
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
                            .disabled(!canProceed || authService.isLoading)
                            .scaleButton()
                        }
                        .padding(.horizontal, 30)
                        .padding(.bottom, 30)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
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
                print("✅ Pre-filled referral code from deep link: \(deepLinkCode)")
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
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                SecureField("Min. 6 characters", text: $password)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
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
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Country")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("e.g. United States", text: $country)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
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
    
    // MARK: - Computed Properties
    var stepTitle: String {
        switch currentStep {
        case 1: return "Create Account"
        case 2: return "Tell us about yourself"
        case 3: return "Where are you from?"
        default: return ""
        }
    }
    
    var stepSubtitle: String {
        switch currentStep {
        case 1: return "Let's get started with your account"
        case 2: return "This helps us find your perfect match"
        case 3: return "Connect with people near and far"
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
        default:
            return false
        }
    }
    
    // MARK: - Actions
    func handleNext() {
        if currentStep < 3 {
            withAnimation {
                currentStep += 1
            }
        } else {
            // Final step - create account
            guard let ageInt = Int(age) else { return }
            Task {
                do {
                    try await authService.createUser(
                        withEmail: email,
                        password: password,
                        fullName: name,
                        age: ageInt,
                        gender: gender,
                        lookingFor: lookingFor,
                        location: location,
                        country: country,
                        referralCode: referralCode.trimmingCharacters(in: .whitespaces)
                    )
                } catch {
                    print("Error creating account: \(error)")
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
