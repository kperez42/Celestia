//
//  SafetyPlaceholderViews.swift
//  Celestia
//
//  Placeholder views for safety features not yet implemented
//  NOTE: Phone verification is now functional - see PhoneVerificationView.swift
//  NOTE: ID verification is now functional - see ManualIDVerificationView.swift
//

import SwiftUI

// MARK: - Verification Views

struct IDVerificationView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.text.rectangle")
                .font(.system(size: 60))
                .foregroundColor(.purple)

            Text("ID Verification")
                .font(.title.bold())

            Text("Government ID verification coming soon")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .navigationTitle("ID Verification")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SocialMediaVerificationView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "at")
                .font(.system(size: 60))
                .foregroundColor(.pink)

            Text("Social Media Verification")
                .font(.title.bold())

            Text("Link your social media accounts coming soon")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .navigationTitle("Social Media")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Safety Tools Views

struct ReportingCenterView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Report & Support")
                .font(.title.bold())

            Text("Report issues or users. Support coming soon")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .navigationTitle("Report & Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SafetySettingsView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gear")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("Privacy Settings")
                .font(.title.bold())

            Text("Control who sees your profile. Coming soon")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .navigationTitle("Privacy Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Date Safety Views

struct SafeDateLocationsView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Safe Meeting Spots")
                .font(.title.bold())

            Text("Public places recommended for first dates. Coming soon")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .navigationTitle("Safe Meeting Spots")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DateCheckInView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Date Check-In")
                .font(.title.bold())

            Text("Set reminders during your date. Coming soon")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .navigationTitle("Date Check-In")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Resources Views

struct CommunityGuidelinesView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Community Guidelines")
                    .font(.title.bold())

                Text("Our Rules and Standards")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text("Detailed community guidelines coming soon")
                    .font(.body)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Community Guidelines")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Previews

#Preview("ID Verification") {
    NavigationStack {
        IDVerificationView()
    }
}

#Preview("Phone Verification") {
    NavigationStack {
        PhoneVerificationView()
    }
}

#Preview("Social Media Verification") {
    NavigationStack {
        SocialMediaVerificationView()
    }
}
