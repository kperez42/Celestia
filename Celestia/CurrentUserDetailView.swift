//
//  CurrentUserDetailView.swift
//  Celestia
//
//  Detail view for viewing own profile (similar to how other users see you)
//

import SwiftUI

struct CurrentUserDetailView: View {
    let user: User
    @Environment(\.dismiss) var dismiss

    @State private var showingEditProfile = false
    @State private var selectedPhotoIndex = 0
    @State private var showingPhotoViewer = false

    var onEditProfile: (() -> Void)?
    var onViewFullProfile: (() -> Void)?

    // Filter out empty photo URLs
    private var validPhotos: [String] {
        let photos = user.photos.isEmpty ? [user.profileImageURL] : user.photos
        return photos.filter { !$0.isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Photos carousel with tap to view full screen
                ZStack(alignment: .topTrailing) {
                    TabView(selection: $selectedPhotoIndex) {
                        ForEach(validPhotos.indices, id: \.self) { index in
                            CachedCardImage(url: URL(string: validPhotos[index]))
                                .frame(height: 400)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .onTapGesture {
                                    showingPhotoViewer = true
                                }
                                .tag(index)
                        }
                    }
                    .frame(height: 400)
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .indexViewStyle(.page(backgroundDisplayMode: .always))

                    // "Your Profile" badge
                    HStack(spacing: 6) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.caption)
                        Text("Your Profile")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
                    .padding(16)
                }

                // Profile info
                VStack(alignment: .leading, spacing: 24) {
                    // Name and age
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Text(user.fullName)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )

                            Text("\(user.age)")
                                .font(.title2)
                                .foregroundColor(.secondary)

                            if user.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                            }
                        }

                        // Location
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.purple)
                            Text("\(user.location), \(user.country)")
                                .foregroundColor(.secondary)
                        }
                        .font(.subheadline)

                        // Photo count
                        HStack(spacing: 6) {
                            Image(systemName: "photo.stack.fill")
                                .foregroundColor(.purple)
                            Text("\(validPhotos.count) photo\(validPhotos.count == 1 ? "" : "s")")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }

                    // Bio section
                    if !user.bio.isEmpty {
                        ProfileSectionCard(
                            icon: "quote.bubble.fill",
                            title: "About",
                            iconColors: [.purple, .pink],
                            borderColor: .purple
                        ) {
                            Text(user.bio)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .lineSpacing(4)
                        }
                    }

                    // Languages section
                    if !user.languages.isEmpty {
                        ProfileSectionCard(
                            icon: "globe",
                            title: "Languages",
                            iconColors: [.blue, .cyan],
                            borderColor: .blue
                        ) {
                            FlowLayout2(spacing: 10) {
                                ForEach(user.languages, id: \.self) { language in
                                    ProfileTagView(text: language, colors: [.blue, .cyan], textColor: .blue)
                                }
                            }
                        }
                    }

                    // Interests section
                    if !user.interests.isEmpty {
                        ProfileSectionCard(
                            icon: "sparkles",
                            title: "Interests",
                            iconColors: [.orange, .pink],
                            borderColor: .orange
                        ) {
                            FlowLayout2(spacing: 10) {
                                ForEach(user.interests, id: \.self) { interest in
                                    ProfileTagView(text: interest, colors: [.orange, .pink], textColor: .orange)
                                }
                            }
                        }
                    }

                    // Prompts section
                    if !user.prompts.isEmpty {
                        ProfileSectionCard(
                            icon: "quote.bubble.fill",
                            title: "Get to Know Me",
                            iconColors: [.purple, .pink],
                            borderColor: .purple
                        ) {
                            VStack(spacing: 12) {
                                ForEach(user.prompts) { prompt in
                                    PromptCard(prompt: prompt)
                                }
                            }
                        }
                    }

                    // Details section (height, religion, relationship goal)
                    if hasAdvancedDetails {
                        ProfileSectionCard(
                            icon: "person.text.rectangle",
                            title: "Details",
                            iconColors: [.indigo, .purple],
                            borderColor: .indigo
                        ) {
                            VStack(spacing: 12) {
                                if let height = user.height {
                                    DetailRow(icon: "ruler", label: "Height", value: "\(height) cm (\(heightToFeetInches(height)))")
                                }
                                if let education = user.educationLevel, education != "Prefer not to say" {
                                    DetailRow(icon: "graduationcap.fill", label: "Education", value: education)
                                }
                                if let goal = user.relationshipGoal, goal != "Prefer not to say" {
                                    DetailRow(icon: "heart.circle", label: "Looking for", value: goal)
                                }
                                if let religion = user.religion, religion != "Prefer not to say" {
                                    DetailRow(icon: "sparkles", label: "Religion", value: religion)
                                }
                            }
                        }
                    }

                    // Lifestyle section
                    if hasLifestyleDetails {
                        ProfileSectionCard(
                            icon: "leaf.fill",
                            title: "Lifestyle",
                            iconColors: [.green, .mint],
                            borderColor: .green
                        ) {
                            VStack(spacing: 12) {
                                if let smoking = user.smoking, smoking != "Prefer not to say" {
                                    DetailRow(icon: "smoke", label: "Smoking", value: smoking)
                                }
                                if let drinking = user.drinking, drinking != "Prefer not to say" {
                                    DetailRow(icon: "wineglass", label: "Drinking", value: drinking)
                                }
                                if let exercise = user.exercise, exercise != "Prefer not to say" {
                                    DetailRow(icon: "figure.run", label: "Exercise", value: exercise)
                                }
                                if let diet = user.diet, diet != "Prefer not to say" {
                                    DetailRow(icon: "fork.knife", label: "Diet", value: diet)
                                }
                                if let pets = user.pets, pets != "Prefer not to say" {
                                    DetailRow(icon: "pawprint.fill", label: "Pets", value: pets)
                                }
                            }
                        }
                    }

                    // Looking for section
                    ProfileSectionCard(
                        icon: "heart.fill",
                        title: "Looking for",
                        iconColors: [.purple, .pink],
                        borderColor: .purple
                    ) {
                        Text("\(user.lookingFor), ages \(user.ageRangeMin)-\(user.ageRangeMax)")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(20)
                .padding(.bottom, 100)
                .background(Color(.systemGroupedBackground))
            }
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .bottom) {
            // Action buttons
            HStack(spacing: 20) {
                // Close button
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.gray)
                        .frame(width: 60, height: 60)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.1), radius: 5)
                }
                .accessibilityLabel("Close")

                // Edit Profile button
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onEditProfile?()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                            .font(.title3)
                        Text("Edit")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(width: 120, height: 60)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color.purple.opacity(0.4), radius: 10)
                }
                .accessibilityLabel("Edit Profile")
            }
            .padding(.bottom, 30)
        }
        .fullScreenCover(isPresented: $showingPhotoViewer) {
            PhotoViewerView(
                photos: validPhotos,
                selectedIndex: $selectedPhotoIndex
            )
        }
    }

    // MARK: - Helper Properties

    private var hasAdvancedDetails: Bool {
        user.height != nil ||
        (user.educationLevel != nil && user.educationLevel != "Prefer not to say") ||
        (user.relationshipGoal != nil && user.relationshipGoal != "Prefer not to say") ||
        (user.religion != nil && user.religion != "Prefer not to say")
    }

    private var hasLifestyleDetails: Bool {
        (user.smoking != nil && user.smoking != "Prefer not to say") ||
        (user.drinking != nil && user.drinking != "Prefer not to say") ||
        (user.exercise != nil && user.exercise != "Prefer not to say") ||
        (user.diet != nil && user.diet != "Prefer not to say") ||
        (user.pets != nil && user.pets != "Prefer not to say")
    }

    // MARK: - Helper Functions

    private func heightToFeetInches(_ cm: Int) -> String {
        let totalInches = Double(cm) / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
        return "\(feet)'\(inches)\""
    }
}

#Preview {
    CurrentUserDetailView(
        user: User(
            email: "test@example.com",
            fullName: "John Doe",
            age: 28,
            gender: "Male",
            lookingFor: "Women",
            bio: "Love hiking and coffee. Looking for someone to explore the city with!",
            location: "San Francisco",
            country: "USA",
            interests: ["Hiking", "Coffee", "Photography", "Travel"],
            photos: [],
            ageRangeMin: 24,
            ageRangeMax: 35
        )
    )
}
