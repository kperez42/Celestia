//
//  SafetyCenterView.swift
//  Celestia
//
//  Comprehensive safety tips, resources, and privacy controls
//

import SwiftUI

struct SafetyCenterView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.05),
                        Color.white
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Header
                        safetyHeader

                        // Quick Actions
                        quickActionsSection

                        // Safety Tips
                        safetyTipsSection

                        // Resources
                        resourcesSection

                        // Community Guidelines
                        communityGuidelinesSection
                    }
                }
            }
            .navigationTitle("Safety Center")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Safety Header

    private var safetyHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.2), .cyan.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "shield.checkered")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Your Safety Matters")
                .font(.title)
                .fontWeight(.bold)

            Text("Learn how to stay safe while dating and have the best experience")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 32)
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal)

            VStack(spacing: 12) {
                SafetyActionCard(
                    icon: "exclamationmark.shield.fill",
                    title: "Report Someone",
                    description: "Report inappropriate behavior or content",
                    color: .red
                ) {
                    // Navigate to reports
                }

                SafetyActionCard(
                    icon: "hand.raised.fill",
                    title: "Block a User",
                    description: "Stop seeing someone on the app",
                    color: .orange
                ) {
                    // Navigate to blocked users
                }

                SafetyActionCard(
                    icon: "lock.shield.fill",
                    title: "Privacy Settings",
                    description: "Control who can see your profile",
                    color: .blue
                ) {
                    // Navigate to privacy settings
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Safety Tips

    private var safetyTipsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Safety Tips")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal)

            VStack(spacing: 16) {
                SafetyTipCard(
                    icon: "eye.fill",
                    title: "Protect Your Personal Information",
                    tips: [
                        "Don't share your phone number or address too quickly",
                        "Use the in-app messaging until you feel comfortable",
                        "Be cautious about sharing social media profiles",
                        "Never share financial information"
                    ],
                    color: .purple
                )

                SafetyTipCard(
                    icon: "person.2.fill",
                    title: "Meeting in Person",
                    tips: [
                        "Always meet in a public place for first dates",
                        "Tell a friend where you're going and when",
                        "Arrange your own transportation",
                        "Stay sober and aware of your surroundings"
                    ],
                    color: .green
                )

                SafetyTipCard(
                    icon: "hand.thumbsup.fill",
                    title: "Trust Your Instincts",
                    tips: [
                        "If something feels off, it probably is",
                        "Don't feel pressured to meet or continue talking",
                        "Block and report suspicious behavior immediately",
                        "Take your time getting to know someone"
                    ],
                    color: .orange
                )

                SafetyTipCard(
                    icon: "camera.fill",
                    title: "Verify Profiles",
                    tips: [
                        "Look for verified profiles with the blue checkmark",
                        "Video chat before meeting in person",
                        "Check if profile photos seem genuine",
                        "Be cautious of profiles with no bio or few photos"
                    ],
                    color: .blue
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Resources

    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Helpful Resources")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal)

            VStack(spacing: 12) {
                ResourceCard(
                    icon: "phone.fill",
                    title: "24/7 Crisis Hotline",
                    subtitle: "National Domestic Violence Hotline",
                    action: "1-800-799-7233"
                ) {
                    if let url = URL(string: "tel://18007997233") {
                        UIApplication.shared.open(url)
                    }
                }

                ResourceCard(
                    icon: "message.fill",
                    title: "Text Support",
                    subtitle: "Text \"START\" to 88788",
                    action: "Text Now"
                ) {
                    if let url = URL(string: "sms:88788&body=START") {
                        UIApplication.shared.open(url)
                    }
                }

                ResourceCard(
                    icon: "globe",
                    title: "Online Resources",
                    subtitle: "Learn more about dating safety",
                    action: "Visit"
                ) {
                    if let url = URL(string: "https://www.thehotline.org") {
                        UIApplication.shared.open(url)
                    }
                }

                ResourceCard(
                    icon: "envelope.fill",
                    title: "Contact Support",
                    subtitle: "Report issues or get help",
                    action: "Email Us"
                ) {
                    if let url = URL(string: "mailto:safety@celestia.app") {
                        UIApplication.shared.open(url)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Community Guidelines

    private var communityGuidelinesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Community Guidelines")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 20) {
                GuidelineRow(
                    icon: "checkmark.circle.fill",
                    title: "Be Respectful",
                    description: "Treat others with kindness and respect",
                    color: .green
                )

                GuidelineRow(
                    icon: "checkmark.circle.fill",
                    title: "Be Authentic",
                    description: "Use real photos and honest information",
                    color: .green
                )

                GuidelineRow(
                    icon: "checkmark.circle.fill",
                    title: "Be Safe",
                    description: "Protect your personal information",
                    color: .green
                )

                GuidelineRow(
                    icon: "xmark.circle.fill",
                    title: "No Harassment",
                    description: "Harassment or bullying will not be tolerated",
                    color: .red
                )

                GuidelineRow(
                    icon: "xmark.circle.fill",
                    title: "No Hate Speech",
                    description: "Discriminatory or offensive content is prohibited",
                    color: .red
                )

                GuidelineRow(
                    icon: "xmark.circle.fill",
                    title: "No Spam",
                    description: "Don't spam, scam, or promote services",
                    color: .red
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .padding(.horizontal)
        }
        .padding(.vertical, 24)
        .padding(.bottom, 40)
    }
}

// MARK: - Safety Action Card

struct SafetyActionCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        }
    }
}

// MARK: - Safety Tip Card

struct SafetyTipCard: View {
    let icon: String
    let title: String
    let tips: [String]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)

                Text(title)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(color)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)

                        Text(tip)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Resource Card

struct ResourceCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(action)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Guideline Row

struct GuidelineRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    SafetyCenterView()
}
