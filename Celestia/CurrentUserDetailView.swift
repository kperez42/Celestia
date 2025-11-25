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
                                .onTapGesture {
                                    showingPhotoViewer = true
                                }
                                .tag(index)
                        }
                    }
                    .frame(height: 450)
                    .tabViewStyle(.page)

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
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "quote.bubble.fill")
                                    .font(.title3)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.purple, .pink],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )

                                Text("About")
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(.primary)
                            }

                            Text(user.bio)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .lineSpacing(4)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.purple.opacity(0.1), lineWidth: 1)
                        )
                    }

                    // Languages section
                    if !user.languages.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "globe")
                                    .font(.title3)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue, .cyan],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )

                                Text("Languages")
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(.primary)
                            }

                            FlowLayout2(spacing: 10) {
                                ForEach(user.languages, id: \.self) { language in
                                    Text(language)
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            LinearGradient(
                                                colors: [Color.blue.opacity(0.15), Color.cyan.opacity(0.1)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .foregroundColor(.blue)
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.blue.opacity(0.1), lineWidth: 1)
                        )
                    }

                    // Interests section
                    if !user.interests.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.title3)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.orange, .pink],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )

                                Text("Interests")
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(.primary)
                            }

                            FlowLayout2(spacing: 10) {
                                ForEach(user.interests, id: \.self) { interest in
                                    Text(interest)
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            LinearGradient(
                                                colors: [Color.orange.opacity(0.15), Color.pink.opacity(0.1)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .foregroundColor(.orange)
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.orange.opacity(0.1), lineWidth: 1)
                        )
                    }

                    // Looking for section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                                .font(.title3)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Text("Looking for")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.primary)
                        }

                        Text("\(user.lookingFor), ages \(user.ageRangeMin)-\(user.ageRangeMax)")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.purple.opacity(0.1), lineWidth: 1)
                    )
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
