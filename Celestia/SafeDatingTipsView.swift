//
//  SafeDatingTipsView.swift
//  Celestia
//
//  Safety tips and resources for dating
//

import SwiftUI

struct SafeDatingTipsView: View {
    @State private var selectedCategory: TipCategory = .beforeMeeting
    @State private var animateHeader = false

    var body: some View {
        ZStack {
            // Premium gradient background
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.08),
                    Color.purple.opacity(0.05),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Premium header card
                premiumHeader
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Category Picker
                categoryPicker

                // Tips List
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(SafetyTip.tips(for: selectedCategory)) { tip in
                            SafetyTipCard(tip: tip)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Safe Dating Tips")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 0.6)) {
                animateHeader = true
            }
        }
    }

    // MARK: - Premium Header

    private var premiumHeader: some View {
        HStack(spacing: 14) {
            // Premium icon with radial glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.blue.opacity(0.25), Color.purple.opacity(0.1), Color.clear],
                            center: .center,
                            startRadius: 5,
                            endRadius: 35
                        )
                    )
                    .frame(width: 70, height: 70)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Image(systemName: "shield.checkered")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Stay Safe")
                    .font(.headline)
                    .fontWeight(.bold)

                Text("Important tips for meeting people online")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: .blue.opacity(0.1), radius: 12, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    LinearGradient(
                        colors: [.blue.opacity(0.2), .purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .scaleEffect(animateHeader ? 1 : 0.95)
        .opacity(animateHeader ? 1 : 0)
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TipCategory.allCases, id: \.self) { category in
                    CategoryTab(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 14)
        }
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Category Tab

struct CategoryTab: View {
    let category: TipCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 36, height: 36)
                    }

                    Image(systemName: category.icon)
                        .font(.system(size: 18, weight: .semibold))
                }

                Text(category.title)
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                isSelected ?
                LinearGradient(
                    colors: [.blue, .purple, .blue.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ) :
                LinearGradient(colors: [Color(.systemBackground)], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: isSelected ? .blue.opacity(0.3) : .black.opacity(0.05), radius: isSelected ? 10 : 5, y: isSelected ? 5 : 2)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isSelected ?
                        LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing) :
                        LinearGradient(
                            colors: [Color.gray.opacity(0.15), Color.gray.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
    }
}

// MARK: - Safety Tip Card

struct SafetyTipCard: View {
    let tip: SafetyTip

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Icon and Title with premium styling
            HStack(spacing: 14) {
                // Premium icon with radial glow
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [tip.priority.color.opacity(0.25), tip.priority.color.opacity(0.1), Color.clear],
                                center: .center,
                                startRadius: 5,
                                endRadius: 28
                            )
                        )
                        .frame(width: 56, height: 56)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [tip.priority.color.opacity(0.2), tip.priority.color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: tip.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [tip.priority.color, tip.priority.color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(tip.title)
                        .font(.headline)
                        .fontWeight(.bold)

                    if tip.priority == .critical {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                            Text("IMPORTANT")
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            LinearGradient(
                                colors: [.red, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                    }
                }

                Spacer()
            }

            // Description
            Text(tip.description)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)

            // Premium action items
            if !tip.actionItems.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(tip.actionItems.enumerated()), id: \.element) { index, item in
                        HStack(alignment: .top, spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.green.opacity(0.2), .mint.opacity(0.15)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 24, height: 24)

                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.green, .mint],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }

                            Text(item)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.08), Color.mint.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.green.opacity(0.2), .mint.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: tip.priority.color.opacity(0.1), radius: 12, y: 6)
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [tip.priority.color.opacity(0.15), tip.priority.color.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Models

enum TipCategory: CaseIterable {
    case beforeMeeting
    case firstDate
    case ongoingSafety
    case redFlags
    case resources

    var title: String {
        switch self {
        case .beforeMeeting: return "Before"
        case .firstDate: return "First Date"
        case .ongoingSafety: return "Ongoing"
        case .redFlags: return "Red Flags"
        case .resources: return "Resources"
        }
    }

    var icon: String {
        switch self {
        case .beforeMeeting: return "calendar.badge.clock"
        case .firstDate: return "hand.wave.fill"
        case .ongoingSafety: return "shield.checkered"
        case .redFlags: return "exclamationmark.triangle.fill"
        case .resources: return "link"
        }
    }
}

enum TipPriority {
    case critical
    case important
    case helpful

    var color: Color {
        switch self {
        case .critical: return .red
        case .important: return .orange
        case .helpful: return .blue
        }
    }
}

struct SafetyTip: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let priority: TipPriority
    let actionItems: [String]

    static func tips(for category: TipCategory) -> [SafetyTip] {
        switch category {
        case .beforeMeeting:
            return [
                SafetyTip(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: "Get to Know Them First",
                    description: "Message for at least a few days before meeting. Ask questions to verify they're genuine.",
                    priority: .important,
                    actionItems: [
                        "Have several conversations",
                        "Video chat before meeting",
                        "Verify their social media profiles"
                    ]
                ),
                SafetyTip(
                    icon: "video.fill",
                    title: "Video Chat First",
                    description: "A video call helps verify they are who they say they are and builds comfort before meeting.",
                    priority: .important,
                    actionItems: [
                        "Suggest a quick video call",
                        "Check they match their photos",
                        "Gauge your comfort level"
                    ]
                ),
                SafetyTip(
                    icon: "person.2.fill",
                    title: "Share Your Plans",
                    description: "Always tell a friend or family member where you're going and who you're meeting.",
                    priority: .critical,
                    actionItems: [
                        "Share date location and time",
                        "Send match's profile info",
                        "Set up check-in times"
                    ]
                ),
                SafetyTip(
                    icon: "magnifyingglass",
                    title: "Do Your Research",
                    description: "Look them up online. A quick search can reveal important information.",
                    priority: .helpful,
                    actionItems: [
                        "Google their name",
                        "Check social media profiles",
                        "Verify their work/education"
                    ]
                )
            ]

        case .firstDate:
            return [
                SafetyTip(
                    icon: "building.2.fill",
                    title: "Meet in Public",
                    description: "Always choose a busy, public place for first dates. Never go to their home or invite them to yours.",
                    priority: .critical,
                    actionItems: [
                        "Choose a busy cafe or restaurant",
                        "Avoid secluded areas",
                        "Stay in well-lit places"
                    ]
                ),
                SafetyTip(
                    icon: "car.fill",
                    title: "Arrange Your Own Transportation",
                    description: "Drive yourself or use a rideshare. Never let them pick you up or know your address yet.",
                    priority: .critical,
                    actionItems: [
                        "Drive yourself",
                        "Use Uber/Lyft",
                        "Have an exit strategy"
                    ]
                ),
                SafetyTip(
                    icon: "creditcard.fill",
                    title: "Keep Your Own Tab",
                    description: "Be prepared to pay for yourself. This maintains independence and avoids obligation.",
                    priority: .important,
                    actionItems: [
                        "Bring your own money",
                        "Offer to split the bill",
                        "Never feel obligated"
                    ]
                ),
                SafetyTip(
                    icon: "iphone",
                    title: "Keep Your Phone Charged",
                    description: "Ensure your phone is fully charged and you have a way to call for help if needed.",
                    priority: .important,
                    actionItems: [
                        "Charge phone before leaving",
                        "Bring a portable charger",
                        "Keep emergency numbers handy"
                    ]
                ),
                SafetyTip(
                    icon: "wineglass.fill",
                    title: "Watch Your Drink",
                    description: "Never leave your drink unattended. If you do, order a new one.",
                    priority: .critical,
                    actionItems: [
                        "Order drinks yourself",
                        "Keep drink in sight",
                        "Watch bartender make it"
                    ]
                )
            ]

        case .ongoingSafety:
            return [
                SafetyTip(
                    icon: "ear",
                    title: "Trust Your Instincts",
                    description: "If something feels off, it probably is. You can leave at any time.",
                    priority: .critical,
                    actionItems: [
                        "Listen to your gut",
                        "Don't ignore red flags",
                        "Leave if uncomfortable"
                    ]
                ),
                SafetyTip(
                    icon: "lock.shield.fill",
                    title: "Protect Personal Information",
                    description: "Don't share your address, workplace details, or financial information too quickly.",
                    priority: .important,
                    actionItems: [
                        "Wait before sharing address",
                        "Be vague about work location",
                        "Never share financial details"
                    ]
                ),
                SafetyTip(
                    icon: "clock.fill",
                    title: "Take It Slow",
                    description: "There's no rush. Take time to build trust before increasing intimacy or sharing more.",
                    priority: .helpful,
                    actionItems: [
                        "Set your own pace",
                        "Don't feel pressured",
                        "Build trust gradually"
                    ]
                ),
                SafetyTip(
                    icon: "checkmark.shield.fill",
                    title: "Verify Their Identity",
                    description: "Make sure they are who they claim to be through various verification methods.",
                    priority: .important,
                    actionItems: [
                        "Check verified badge",
                        "Video call before meeting",
                        "Verify social profiles"
                    ]
                )
            ]

        case .redFlags:
            return [
                SafetyTip(
                    icon: "exclamationmark.triangle.fill",
                    title: "Pressure or Aggression",
                    description: "Anyone who pressures you, gets angry when you set boundaries, or seems aggressive is a major red flag.",
                    priority: .critical,
                    actionItems: [
                        "End contact immediately",
                        "Block and report them",
                        "Tell someone you trust"
                    ]
                ),
                SafetyTip(
                    icon: "eye.slash.fill",
                    title: "Inconsistent Stories",
                    description: "Pay attention if their stories don't add up or they contradict themselves frequently.",
                    priority: .important,
                    actionItems: [
                        "Note inconsistencies",
                        "Ask clarifying questions",
                        "Trust your judgment"
                    ]
                ),
                SafetyTip(
                    icon: "dollarsign.circle.fill",
                    title: "Asks for Money",
                    description: "Never send money to someone you haven't met, regardless of their story. This is almost always a scam.",
                    priority: .critical,
                    actionItems: [
                        "Never send money",
                        "Report immediately",
                        "Block the user"
                    ]
                ),
                SafetyTip(
                    icon: "hourglass",
                    title: "Rushes Intimacy",
                    description: "Be wary of anyone who rushes physical or emotional intimacy or tries to isolate you from friends.",
                    priority: .important,
                    actionItems: [
                        "Maintain your pace",
                        "Keep friends involved",
                        "Set clear boundaries"
                    ]
                ),
                SafetyTip(
                    icon: "photo.on.rectangle.angled",
                    title: "Refuses to Video Chat",
                    description: "If they consistently avoid video calls or meeting in person, they may be hiding something.",
                    priority: .important,
                    actionItems: [
                        "Insist on video chat",
                        "Be suspicious of excuses",
                        "Consider ending contact"
                    ]
                )
            ]

        case .resources:
            return [
                SafetyTip(
                    icon: "phone.fill",
                    title: "Emergency Services",
                    description: "In immediate danger, always call 911 (or your local emergency number).",
                    priority: .critical,
                    actionItems: [
                        "911 for emergencies",
                        "Know local police non-emergency",
                        "Save these in your phone"
                    ]
                ),
                SafetyTip(
                    icon: "heart.text.square.fill",
                    title: "RAINN Hotline",
                    description: "National Sexual Assault Hotline: 1-800-656-HOPE (4673). Free, confidential 24/7 support.",
                    priority: .important,
                    actionItems: [
                        "Call 1-800-656-4673",
                        "Online chat available",
                        "Completely confidential"
                    ]
                ),
                SafetyTip(
                    icon: "house.fill",
                    title: "Domestic Violence Hotline",
                    description: "National Domestic Violence Hotline: 1-800-799-SAFE (7233). Help for abusive relationships.",
                    priority: .important,
                    actionItems: [
                        "Call 1-800-799-7233",
                        "Text START to 88788",
                        "24/7 support available"
                    ]
                ),
                SafetyTip(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: "Crisis Text Line",
                    description: "Text HOME to 741741 for free, 24/7 crisis support via text message.",
                    priority: .helpful,
                    actionItems: [
                        "Text HOME to 741741",
                        "Available 24/7",
                        "All issues welcome"
                    ]
                ),
                SafetyTip(
                    icon: "network",
                    title: "Online Resources",
                    description: "Visit these websites for more information on staying safe while dating online.",
                    priority: .helpful,
                    actionItems: [
                        "love is respect.org",
                        "cybercivilrights.org",
                        "ncvc.org (National Center for Victims of Crime)"
                    ]
                )
            ]
        }
    }
}

#Preview {
    NavigationStack {
        SafeDatingTipsView()
    }
}
