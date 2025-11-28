//
//  CurrentUserProfileCard.swift
//  Celestia
//
//  Current user's profile card for display at top of discover feed
//  Tappable to navigate to full ProfileView for viewing and editing
//

import SwiftUI

struct CurrentUserProfileCard: View {
    let user: User
    let onTap: () -> Void

    // Get the best available photo URL (photos array first, then profileImageURL)
    private var displayPhotoURL: String {
        if let firstPhoto = user.photos.first, !firstPhoto.isEmpty {
            return firstPhoto
        }
        return user.profileImageURL
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Profile Image with badge
            ZStack(alignment: .topTrailing) {
                CachedCardImage(url: URL(string: displayPhotoURL))
                    .frame(height: 400)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(16, corners: [.topLeft, .topRight])

                // "Your Profile" badge
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.caption)
                        .foregroundColor(.white)

                    Text("Your Profile")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
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
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                .padding(12)
            }

            // User Details
            VStack(alignment: .leading, spacing: 8) {
                // Name and Verification
                HStack(spacing: 8) {
                    Text(user.fullName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }

                    Spacer()
                }

                // Age and Location
                HStack(spacing: 4) {
                    Text("\(user.age)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundColor(.purple)

                    Text("\(user.location), \(user.country)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer()
                }

                // Seeking preferences
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.pink)

                    Text("Seeking \(user.lookingFor), \(user.ageRangeMin)-\(user.ageRangeMax)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()
                }

                // Photo count if available
                if !user.photos.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.stack.fill")
                            .font(.caption)
                            .foregroundColor(.purple)

                        Text("\(user.photos.count) photo\(user.photos.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Tap hint
            HStack {
                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill")
                        .font(.subheadline)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("Tap to view and edit your profile")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .padding(.top, 4)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.purple.opacity(0.3), .pink.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.impact(.medium)
            onTap()
        }
    }
}

#Preview {
    ScrollView {
        CurrentUserProfileCard(
            user: User(
                email: "me@test.com",
                fullName: "John Doe",
                age: 30,
                gender: "Male",
                lookingFor: "Women",
                bio: "Tech enthusiast and coffee lover",
                location: "Los Angeles",
                country: "USA",
                interests: ["Coffee", "Music", "Technology", "Hiking"],
                photos: [
                    "https://example.com/photo1.jpg",
                    "https://example.com/photo2.jpg",
                    "https://example.com/photo3.jpg"
                ],
                ageRangeMin: 25,
                ageRangeMax: 35
            ),
            onTap: {
                print("Navigate to profile")
            }
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
