//
//  ProfileEnhancementView.swift
//  Celestia
//
//  Additional profile information collection view
//  Shown after sign-up to help users get better matches
//

import SwiftUI
import UIKit

struct ProfileEnhancementView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss

    @State private var currentStep = 0
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    // Lifestyle fields
    @State private var educationLevel: String = ""
    @State private var religion: String = ""
    @State private var smoking: String = ""
    @State private var drinking: String = ""
    @State private var pets: String = ""
    @State private var exercise: String = ""
    @State private var diet: String = ""

    let totalSteps = 3

    // Options
    let educationOptions = ["", "High School", "Some College", "Associate's Degree", "Bachelor's Degree", "Master's Degree", "Doctorate", "Trade School", "Other"]
    let religionOptions = ["", "Christian", "Catholic", "Jewish", "Muslim", "Hindu", "Buddhist", "Spiritual", "Agnostic", "Atheist", "Other", "Prefer not to say"]
    let smokingOptions = ["", "Never", "Sometimes", "Regularly", "Trying to quit", "Prefer not to say"]
    let drinkingOptions = ["", "Never", "Socially", "Occasionally", "Regularly", "Prefer not to say"]
    let petsOptions = ["", "Dog", "Cat", "Both", "Other pets", "No pets", "Want pets", "Allergic"]
    let exerciseOptions = ["", "Daily", "Often (3-4x/week)", "Sometimes (1-2x/week)", "Rarely", "Never"]
    let dietOptions = ["", "Omnivore", "Vegetarian", "Vegan", "Pescatarian", "Keto", "Halal", "Kosher", "Other"]

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.08),
                        Color.purple.opacity(0.05),
                        Color.pink.opacity(0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress indicator
                    progressHeader

                    // Content
                    TabView(selection: $currentStep) {
                        lifestyleStep1.tag(0)
                        lifestyleStep2.tag(1)
                        lifestyleStep3.tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut, value: currentStep)

                    // Navigation
                    navigationButtons
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Skip") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
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
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: 16) {
            // Progress dots
            HStack(spacing: 12) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Circle()
                        .fill(
                            currentStep >= step ?
                            LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing) :
                            LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: currentStep == step ? 12 : 8, height: currentStep == step ? 12 : 8)
                        .animation(.spring(response: 0.3), value: currentStep)
                }
            }

            VStack(spacing: 4) {
                Text(stepTitle)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("Help us find your perfect match")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(Color.white)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    private var stepTitle: String {
        switch currentStep {
        case 0: return "Education & Beliefs"
        case 1: return "Lifestyle Habits"
        case 2: return "More About You"
        default: return ""
        }
    }

    // MARK: - Step 1: Education & Religion

    private var lifestyleStep1: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 80, height: 80)

                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }

                Text("Your Background")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(spacing: 20) {
                    // Education
                    optionSelector(
                        title: "Education Level",
                        icon: "book.fill",
                        color: .blue,
                        options: educationOptions,
                        selection: $educationLevel
                    )

                    // Religion
                    optionSelector(
                        title: "Religion / Spirituality",
                        icon: "sparkles",
                        color: .purple,
                        options: religionOptions,
                        selection: $religion
                    )
                }

                infoCard(
                    icon: "lightbulb.fill",
                    text: "Sharing your background helps find compatible matches",
                    color: .yellow
                )
            }
            .padding(20)
            .padding(.top, 10)
        }
    }

    // MARK: - Step 2: Habits

    private var lifestyleStep2: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 80, height: 80)

                    Image(systemName: "leaf.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }

                Text("Your Lifestyle")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(spacing: 20) {
                    // Smoking
                    optionSelector(
                        title: "Smoking",
                        icon: "smoke.fill",
                        color: .gray,
                        options: smokingOptions,
                        selection: $smoking
                    )

                    // Drinking
                    optionSelector(
                        title: "Drinking",
                        icon: "wineglass.fill",
                        color: .purple,
                        options: drinkingOptions,
                        selection: $drinking
                    )

                    // Exercise
                    optionSelector(
                        title: "Exercise",
                        icon: "figure.run",
                        color: .orange,
                        options: exerciseOptions,
                        selection: $exercise
                    )
                }

                infoCard(
                    icon: "heart.fill",
                    text: "Lifestyle compatibility leads to stronger connections",
                    color: .pink
                )
            }
            .padding(20)
            .padding(.top, 10)
        }
    }

    // MARK: - Step 3: More Details

    private var lifestyleStep3: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 80, height: 80)

                    Image(systemName: "star.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }

                Text("Final Touches")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(spacing: 20) {
                    // Pets
                    optionSelector(
                        title: "Pets",
                        icon: "pawprint.fill",
                        color: .brown,
                        options: petsOptions,
                        selection: $pets
                    )

                    // Diet
                    optionSelector(
                        title: "Diet",
                        icon: "fork.knife",
                        color: .green,
                        options: dietOptions,
                        selection: $diet
                    )
                }

                // Completion stats
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.green)

                        Text("Profiles with lifestyle info get")
                            .font(.subheadline)

                        Text("3x more matches!")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(20)
            .padding(.top, 10)
        }
    }

    // MARK: - Helper Views

    private func optionSelector(title: String, icon: String, color: Color, options: [String], selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
            }

            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option.isEmpty ? "Select..." : option) {
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
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    private func infoCard(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button {
                    withAnimation {
                        currentStep -= 1
                        HapticManager.shared.impact(.light)
                    }
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.blue, lineWidth: 2)
                    )
                }
            }

            Button {
                if currentStep < totalSteps - 1 {
                    withAnimation {
                        currentStep += 1
                        HapticManager.shared.impact(.medium)
                    }
                } else {
                    saveAndComplete()
                }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(currentStep < totalSteps - 1 ? "Continue" : "Complete Profile")
                            .fontWeight(.semibold)

                        Image(systemName: currentStep < totalSteps - 1 ? "chevron.right" : "checkmark")
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
            }
            .disabled(isLoading)
        }
        .padding(20)
        .background(Color.white)
        .shadow(color: .black.opacity(0.05), radius: 5, y: -2)
    }

    // MARK: - Save Data

    private func saveAndComplete() {
        isLoading = true

        Task {
            do {
                guard var user = authService.currentUser else { return }

                // Update user with new lifestyle info
                if !educationLevel.isEmpty { user.educationLevel = educationLevel }
                if !religion.isEmpty { user.religion = religion }
                if !smoking.isEmpty { user.smoking = smoking }
                if !drinking.isEmpty { user.drinking = drinking }
                if !pets.isEmpty { user.pets = pets }
                if !exercise.isEmpty { user.exercise = exercise }
                if !diet.isEmpty { user.diet = diet }

                try await authService.updateUser(user)

                await MainActor.run {
                    isLoading = false
                    HapticManager.shared.notification(.success)
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

// MARK: - Prompt-based Profile Enhancement

struct ProfilePromptsOnboardingView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss

    @State private var prompts: [ProfilePrompt] = []
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    let availablePrompts = [
        "A perfect first date would be...",
        "I'm looking for someone who...",
        "My ideal weekend looks like...",
        "Two truths and a lie...",
        "The way to my heart is...",
        "I geek out on...",
        "My most spontaneous moment...",
        "I'm convinced that...",
        "The key to my heart is...",
        "My simple pleasures are..."
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.pink.opacity(0.15))
                                .frame(width: 80, height: 80)

                            Image(systemName: "text.bubble.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(
                                    LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                        }

                        Text("Add Profile Prompts")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Answer prompts to show your personality")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    // Current prompts
                    if !prompts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Prompts (\(prompts.count)/3)")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            ForEach(prompts) { prompt in
                                promptCard(prompt: prompt)
                            }
                        }
                    }

                    // Add prompt section
                    if prompts.count < 3 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Choose a prompt")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            ForEach(availablePrompts.filter { question in
                                !prompts.contains { $0.question == question }
                            }, id: \.self) { question in
                                Button {
                                    addPrompt(question: question)
                                } label: {
                                    HStack {
                                        Text(question)
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)

                                        Spacer()

                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.pink)
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.pink.opacity(0.2), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }

                    // Info card
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.yellow)

                        Text("Profiles with prompts get 40% more conversations!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile Prompts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Skip") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePrompts()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.pink)
                    .disabled(prompts.isEmpty || isLoading)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func promptCard(prompt: ProfilePrompt) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(prompt.question)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.pink)

                Spacer()

                Button {
                    withAnimation {
                        prompts.removeAll { $0.id == prompt.id }
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }

            Text(prompt.answer)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    private func addPrompt(question: String) {
        let alert = UIAlertController(title: question, message: "Write your answer", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Your answer..."
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default) { _ in
            if let answer = alert.textFields?.first?.text, !answer.isEmpty {
                let newPrompt = ProfilePrompt(
                    id: UUID().uuidString,
                    question: question,
                    answer: answer
                )
                withAnimation {
                    prompts.append(newPrompt)
                }
                HapticManager.shared.notification(.success)
            }
        })

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let viewController = windowScene.windows.first?.rootViewController {
            viewController.present(alert, animated: true)
        }
    }

    private func savePrompts() {
        isLoading = true

        Task {
            do {
                guard var user = authService.currentUser else { return }
                user.prompts = prompts

                try await authService.updateUser(user)

                await MainActor.run {
                    isLoading = false
                    HapticManager.shared.notification(.success)
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

// MARK: - Profile Completion Card (for MainTabView)

struct ProfileCompletionCard: View {
    @EnvironmentObject var authService: AuthService
    @State private var showEnhancement = false
    @State private var showPrompts = false

    var completionPercentage: Int {
        guard let user = authService.currentUser else { return 0 }

        var completed = 0
        var total = 10

        // Required fields (always complete after sign-up)
        if !user.fullName.isEmpty { completed += 1 }
        if user.age > 0 { completed += 1 }
        if !user.gender.isEmpty { completed += 1 }
        if !user.location.isEmpty { completed += 1 }

        // Optional but valuable
        if !user.bio.isEmpty { completed += 1 }
        if user.photos.count >= 3 { completed += 1 }
        if !user.interests.isEmpty { completed += 1 }

        // Advanced fields
        if user.educationLevel != nil { completed += 1 }
        if user.smoking != nil || user.drinking != nil { completed += 1 }
        if !user.prompts.isEmpty { completed += 1 }

        return (completed * 100) / total
    }

    var body: some View {
        if completionPercentage < 100 {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Complete Your Profile")
                            .font(.headline)

                        Text("\(completionPercentage)% complete")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                            .frame(width: 50, height: 50)

                        Circle()
                            .trim(from: 0, to: CGFloat(completionPercentage) / 100)
                            .stroke(
                                LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))

                        Text("\(completionPercentage)%")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        showEnhancement = true
                    } label: {
                        HStack {
                            Image(systemName: "person.fill.badge.plus")
                            Text("Add Details")
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(20)
                    }

                    Button {
                        showPrompts = true
                    } label: {
                        HStack {
                            Image(systemName: "text.bubble")
                            Text("Add Prompts")
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                        .foregroundColor(.pink)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.pink.opacity(0.1))
                        .cornerRadius(20)
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
            .sheet(isPresented: $showEnhancement) {
                ProfileEnhancementView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showPrompts) {
                ProfilePromptsOnboardingView()
                    .environmentObject(authService)
            }
        }
    }
}

#Preview {
    ProfileEnhancementView()
        .environmentObject(AuthService.shared)
}
