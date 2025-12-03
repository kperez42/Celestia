//
//  SignUpGuidelinesPopup.swift
//  Celestia
//
//  Community guidelines popup shown during signup
//  Users scroll through cards to learn the rules before creating their account
//

import SwiftUI

struct SignUpGuidelinesPopup: View {
    @Environment(\.dismiss) var dismiss

    let onAccept: () -> Void

    @State private var hasScrolledToBottom = false
    @State private var acceptedGuidelines = false

    private let guidelines: [Guideline] = [
        Guideline(
            icon: "person.fill.checkmark",
            color: .purple,
            title: "Be Authentic",
            description: "Use real photos of yourself and provide accurate information. Fake profiles will be removed."
        ),
        Guideline(
            icon: "hand.raised.fill",
            color: .red,
            title: "Be Respectful",
            description: "Treat everyone with kindness and respect. Harassment, hate speech, and bullying are not tolerated."
        ),
        Guideline(
            icon: "shield.checkered",
            color: .blue,
            title: "Stay Safe",
            description: "Never share personal information like your address or financial details. Meet in public places first."
        ),
        Guideline(
            icon: "camera.fill",
            color: .orange,
            title: "Appropriate Content Only",
            description: "Keep photos and messages appropriate. No nudity, violence, or illegal content."
        ),
        Guideline(
            icon: "bubble.left.and.bubble.right.fill",
            color: .green,
            title: "Meaningful Connections",
            description: "We're here to help you find genuine connections. No spam, solicitation, or commercial activity."
        ),
        Guideline(
            icon: "exclamationmark.triangle.fill",
            color: .pink,
            title: "Report Concerns",
            description: "If someone makes you uncomfortable, report them. We review all reports and take action quickly."
        ),
        Guideline(
            icon: "18.circle.fill",
            color: .indigo,
            title: "Adults Only",
            description: "You must be 18 or older to use Celestia. We verify ages to keep our community safe."
        ),
        Guideline(
            icon: "heart.circle.fill",
            color: .mint,
            title: "Consent Matters",
            description: "Always respect boundaries. No means no. Consent is essential in all interactions."
        )
    ]

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.purple.opacity(0.05), Color.pink.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.1))
                                .frame(width: 80, height: 80)

                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }

                        Text("Community Guidelines")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Please read and accept our guidelines to create a safe and respectful community")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                    // Scrollable guidelines cards
                    ScrollViewReader { scrollProxy in
                        ScrollView(showsIndicators: true) {
                            LazyVStack(spacing: 16) {
                                ForEach(Array(guidelines.enumerated()), id: \.element.id) { index, guideline in
                                    GuidelineCard(guideline: guideline, index: index + 1)
                                        .id(guideline.id)
                                }

                                // Bottom marker to detect scroll completion
                                Color.clear
                                    .frame(height: 1)
                                    .id("bottom")
                                    .onAppear {
                                        withAnimation {
                                            hasScrolledToBottom = true
                                        }
                                    }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    }

                    // Accept section
                    VStack(spacing: 16) {
                        // Checkbox
                        Button {
                            HapticManager.shared.impact(.light)
                            acceptedGuidelines.toggle()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: acceptedGuidelines ? "checkmark.square.fill" : "square")
                                    .font(.title2)
                                    .foregroundColor(acceptedGuidelines ? .purple : .gray)

                                Text("I have read and agree to follow these guidelines")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)

                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                        .accessibilityLabel("Accept guidelines checkbox")
                        .accessibilityValue(acceptedGuidelines ? "Checked" : "Unchecked")
                        .accessibilityHint("Tap to accept the community guidelines")

                        // Continue button
                        Button {
                            HapticManager.shared.impact(.medium)
                            onAccept()
                            dismiss()
                        } label: {
                            HStack {
                                Text("I Agree, Continue")
                                    .fontWeight(.semibold)

                                Image(systemName: "arrow.right")
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: acceptedGuidelines ? [.purple, .pink] : [.gray, .gray],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: acceptedGuidelines ? .purple.opacity(0.3) : .clear, radius: 10, y: 5)
                        }
                        .disabled(!acceptedGuidelines)
                        .padding(.horizontal, 20)
                        .accessibilityLabel("Continue")
                        .accessibilityHint(acceptedGuidelines ? "Tap to accept guidelines and continue" : "You must accept the guidelines first")
                    }
                    .padding(.vertical, 20)
                    .background(
                        Rectangle()
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 10, y: -5)
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled() // Prevent dismissing without accepting
    }
}

// MARK: - Guideline Model

struct Guideline: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: String
    let description: String
}

// MARK: - Guideline Card

struct GuidelineCard: View {
    let guideline: Guideline
    let index: Int

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Number badge
            ZStack {
                Circle()
                    .fill(guideline.color.opacity(0.12))
                    .frame(width: 56, height: 56)

                Image(systemName: guideline.icon)
                    .font(.system(size: 24))
                    .foregroundColor(guideline.color)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(index).")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(guideline.color)

                    Text(guideline.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                Text(guideline.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Guideline \(index): \(guideline.title). \(guideline.description)")
    }
}

#Preview {
    SignUpGuidelinesPopup {
        print("Guidelines accepted")
    }
}
