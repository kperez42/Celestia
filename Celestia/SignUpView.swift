//
//  SignUpView.swift
//  Celestia
//
//  Multi-step sign up flow
//

import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authService: AuthService
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
                            case 2:
                                step2Content
                            case 3:
                                step3Content
                            default:
                                EmptyView()
                            }
                        }
                        .padding(.horizontal, 30)
                        
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

                TextField("CEL-XXXXXXXX", text: $referralCode)
                    .textInputAutocapitalization(.characters)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                    )

                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundColor(.purple)
                    Text("Get 3 days of Premium free!")
                        .font(.caption)
                        .foregroundColor(.purple)
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
}

#Preview {
    SignUpView()
        .environmentObject(AuthService.shared)
}
