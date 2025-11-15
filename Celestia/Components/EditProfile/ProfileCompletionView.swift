//
//  ProfileCompletionView.swift
//  Celestia
//
//  Profile completion progress indicator
//  Extracted from EditProfileView.swift
//

import SwiftUI

struct ProfileCompletionView: View {
    let progress: Double

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(progressColor)

                Text("Profile Completion")
                    .font(.headline)

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.headline)
                    .foregroundColor(progressColor)
            }

            ProgressView(value: progress)
                .tint(progressColor)
                .scaleEffect(y: 2)

            if progress < 1.0 {
                Text("Complete your profile to get better matches!")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.card)
    }

    private var progressColor: Color {
        if progress >= 0.8 {
            return .green
        } else if progress >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
}
