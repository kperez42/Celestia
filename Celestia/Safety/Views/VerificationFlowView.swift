//
//  VerificationFlowView.swift
//  Celestia
//
//  Complete verification flow UI (Photo, ID, Background Check)
//

import SwiftUI

struct VerificationFlowView: View {

    @StateObject private var verificationService = VerificationService.shared
    @State private var selectedVerification: VerificationType?
    @State private var showingPhotoVerification = false
    @State private var showingIDVerification = false
    @State private var showingBackgroundCheck = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                header

                // Current Status
                currentStatusCard

                // Verification Options
                verificationOptions

                // Benefits
                benefitsSection
            }
            .padding()
        }
        .navigationTitle("Verification")
        .sheet(isPresented: $showingPhotoVerification) {
            PhotoVerificationSheet()
        }
        .sheet(isPresented: $showingIDVerification) {
            IDVerificationSheet()
        }
        .sheet(isPresented: $showingBackgroundCheck) {
            BackgroundCheckSheet()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: verificationService.verificationStatus.icon)
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text(verificationService.verificationStatus.displayName)
                .font(.title2)
                .fontWeight(.bold)

            Text("Build trust with other users by verifying your identity")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Current Status

    private var currentStatusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trust Score")
                .font(.headline)

            HStack {
                VStack(alignment: .leading) {
                    Text("\(verificationService.trustScore)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.blue)

                    Text("out of 100")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Progress Ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 100, height: 100)

                    Circle()
                        .trim(from: 0, to: CGFloat(verificationService.trustScore) / 100)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Verification Options

    private var verificationOptions: some View {
        VStack(spacing: 16) {
            verificationOption(
                type: .photo,
                title: "Photo Verification",
                description: "Verify you match your profile photos",
                points: "+30 points",
                isCompleted: verificationService.photoVerified,
                action: { showingPhotoVerification = true }
            )

            verificationOption(
                type: .id,
                title: "ID Verification",
                description: "Verify your government-issued ID",
                points: "+30 points",
                isCompleted: verificationService.idVerified,
                action: { showingIDVerification = true }
            )

            verificationOption(
                type: .background,
                title: "Background Check",
                description: "Premium: Comprehensive background check",
                points: "+20 points",
                isCompleted: verificationService.backgroundCheckCompleted,
                action: { showingBackgroundCheck = true }
            )
        }
    }

    private func verificationOption(
        type: VerificationType,
        title: String,
        description: String,
        points: String,
        isCompleted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(isCompleted ? .green : .blue)
                    .frame(width: 50, height: 50)
                    .background(isCompleted ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                    .cornerRadius(10)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Status
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                } else {
                    VStack(spacing: 4) {
                        Text(points)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .disabled(isCompleted)
    }

    // MARK: - Benefits

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Benefits of Verification")
                .font(.headline)

            benefitRow(icon: "eye.fill", text: "Stand out with verified badge on your profile")
            benefitRow(icon: "heart.fill", text: "Get more matches from other verified users")
            benefitRow(icon: "shield.fill", text: "Build trust and safety in the community")
            benefitRow(icon: "star.fill", text: "Unlock premium features and visibility boosts")
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Verification Type

enum VerificationType {
    case photo
    case id
    case background

    var icon: String {
        switch self {
        case .photo:
            return "camera.fill"
        case .id:
            return "person.text.rectangle.fill"
        case .background:
            return "shield.checkered"
        }
    }
}

// MARK: - Photo Verification Sheet

struct PhotoVerificationSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Take a selfie to verify you match your profile photos")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding()

                Image(systemName: "camera.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                Button(action: {}) {
                    Text("Take Selfie")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Photo Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - ID Verification Sheet

struct IDVerificationSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Scan your government-issued ID")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding()

                Image(systemName: "person.text.rectangle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Accepted IDs:")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("• Driver's License")
                    Text("• Passport")
                    Text("• State ID")
                    Text("• National ID")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)

                Button(action: {}) {
                    Text("Scan ID")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("ID Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Background Check Sheet

struct BackgroundCheckSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 80))
                        .foregroundColor(.purple)

                    Text("Premium Background Check")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Comprehensive background verification including:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 12) {
                        checkItem("Criminal record search")
                        checkItem("Sex offender registry check")
                        checkItem("Identity verification")
                    }

                    Text("$29.99 one-time fee")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)

                    Button(action: {}) {
                        Text("Start Background Check")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Background Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func checkItem(_ text: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(text)
                .font(.subheadline)
        }
    }
}
