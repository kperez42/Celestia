//
//  ProfileFeedCard.swift
//  Celestia
//
//  Feed-style profile card for vertical scrolling discovery
//

import SwiftUI

struct ProfileFeedCard: View {
    let user: User
    let onLike: () -> Void
    let onFavorite: () -> Void
    let onMessage: () -> Void
    let onViewPhotos: () -> Void

    @State private var isFavorited = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Profile Image
            profileImage

            // User Details
            VStack(alignment: .leading, spacing: 8) {
                // Name and Verification
                nameRow

                // Age and Location
                locationRow

                // Seeking preferences
                seekingRow

                // Last active
                lastActiveRow
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Action Buttons
            actionButtons
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }

    // MARK: - Components

    private var profileImage: some View {
        CachedCardImage(url: URL(string: user.profileImageURL))
            .frame(height: 400)
            .clipped()
            .cornerRadius(16, corners: [.topLeft, .topRight])
    }

    private var nameRow: some View {
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
    }

    private var locationRow: some View {
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
    }

    private var seekingRow: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.2.fill")
                .font(.caption)
                .foregroundColor(.pink)

            Text("Seeking \(user.lookingFor), \(user.ageRangeMin)-\(user.ageRangeMax)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
    }

    private var lastActiveRow: some View {
        HStack(spacing: 4) {
            if user.isOnline {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)

                Text("Active now")
                    .font(.caption)
                    .foregroundColor(.green)
                    .fontWeight(.medium)
            } else {
                Image(systemName: "clock.fill")
                    .font(.caption)
                    .foregroundColor(.gray)

                Text("Active \(formatLastActive(user.lastActive))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Like/Heart button
            ActionButton(
                icon: "heart.fill",
                color: .pink,
                label: "Like",
                action: {
                    HapticManager.shared.impact(.medium)
                    onLike()
                }
            )

            // Favorite button
            ActionButton(
                icon: isFavorited ? "star.fill" : "star",
                color: .orange,
                label: "Save",
                action: {
                    HapticManager.shared.impact(.light)
                    isFavorited.toggle()
                    onFavorite()
                }
            )

            // Message button
            ActionButton(
                icon: "message.fill",
                color: .blue,
                label: "Message",
                action: {
                    HapticManager.shared.impact(.medium)
                    onMessage()
                }
            )

            // View photos button
            ActionButton(
                icon: "camera.fill",
                color: .purple,
                label: "Photos",
                action: {
                    HapticManager.shared.impact(.light)
                    onViewPhotos()
                }
            )
        }
    }

    // MARK: - Helper Functions

    private func formatLastActive(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else if interval < 2592000 {
            let weeks = Int(interval / 604800)
            return "\(weeks)w ago"
        } else {
            let months = Int(interval / 2592000)
            return "\(months)mo ago"
        }
    }
}

// MARK: - Action Button Component

struct ActionButton: View {
    let icon: String
    let color: Color
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                }

                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ScrollView {
        ProfileFeedCard(
            user: User(
                email: "test@test.com",
                fullName: "Sarah Johnson",
                age: 28,
                gender: "Female",
                lookingFor: "Men",
                bio: "Love hiking and coffee",
                location: "Los Angeles",
                country: "USA",
                ageRangeMin: 25,
                ageRangeMax: 35
            ),
            onLike: {},
            onFavorite: {},
            onMessage: {},
            onViewPhotos: {}
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
