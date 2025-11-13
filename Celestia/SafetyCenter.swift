//
//  SafetyCenter.swift
//  Celestia
//
//  Comprehensive safety features: verification, reporting, blocking, date sharing
//

import SwiftUI
import FirebaseFirestore

// MARK: - Safety Center View

struct SafetyCenterView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = SafetyCenterViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection

                    // Verification Status
                    verificationSection

                    // Safety Tools
                    safetyToolsSection

                    // Date Safety
                    dateSafetySection

                    // Emergency Contacts
                    emergencyContactsSection

                    // Resources
                    resourcesSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Safety Center")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
            }
            .task {
                await viewModel.loadSafetyData()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Your Safety Matters")
                .font(.title2.bold())

            Text("We're committed to keeping you safe. Use these tools to protect yourself.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(16)
    }

    // MARK: - Verification Section

    private var verificationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SafetySectionHeader(title: "Verification", icon: "checkmark.seal.fill")

            VStack(spacing: 12) {
                NavigationLink {
                    if let userId = AuthService.shared.currentUser?.id {
                        PhotoVerificationView(userId: userId)
                    } else {
                        Text("Please log in to verify")
                    }
                } label: {
                    SafetyOptionRow(
                        icon: "camera.fill",
                        title: "Photo Verification",
                        subtitle: "Verify you're a real person",
                        color: .blue,
                        isCompleted: viewModel.photoVerified
                    )
                }

                NavigationLink {
                    IDVerificationView()
                } label: {
                    SafetyOptionRow(
                        icon: "person.text.rectangle",
                        title: "Government ID",
                        subtitle: "Verify your identity",
                        color: .purple,
                        isCompleted: viewModel.idVerified
                    )
                }

                NavigationLink {
                    PhoneVerificationView()
                } label: {
                    SafetyOptionRow(
                        icon: "phone.fill",
                        title: "Phone Number",
                        subtitle: "Verify your phone",
                        color: .green,
                        isCompleted: viewModel.phoneVerified
                    )
                }

                NavigationLink {
                    SocialMediaVerificationView()
                } label: {
                    SafetyOptionRow(
                        icon: "at",
                        title: "Social Media",
                        subtitle: "Link your social accounts",
                        color: .pink,
                        isCompleted: viewModel.socialMediaVerified
                    )
                }
            }
        }
    }

    // MARK: - Safety Tools Section

    private var safetyToolsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SafetySectionHeader(title: "Safety Tools", icon: "shield.fill")

            VStack(spacing: 12) {
                NavigationLink {
                    BlockedUsersView()
                } label: {
                    SafetyOptionRow(
                        icon: "hand.raised.fill",
                        title: "Blocked Users",
                        subtitle: "Manage blocked accounts",
                        color: .red,
                        badge: viewModel.blockedCount
                    )
                }

                NavigationLink {
                    ReportingCenterView()
                } label: {
                    SafetyOptionRow(
                        icon: "exclamationmark.triangle.fill",
                        title: "Report & Support",
                        subtitle: "Report issues or users",
                        color: .orange
                    )
                }

                NavigationLink {
                    SafetySettingsView()
                } label: {
                    SafetyOptionRow(
                        icon: "gear",
                        title: "Privacy Settings",
                        subtitle: "Control who sees your profile",
                        color: .gray
                    )
                }
            }
        }
    }

    // MARK: - Date Safety Section

    private var dateSafetySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SafetySectionHeader(title: "Date Safety", icon: "calendar.badge.exclamationmark")

            VStack(spacing: 12) {
                NavigationLink {
                    ShareDateView()
                } label: {
                    SafetyOptionRow(
                        icon: "person.2.fill",
                        title: "Share Your Date",
                        subtitle: "Let trusted contacts know your plans",
                        color: .blue
                    )
                }

                NavigationLink {
                    SafeDateLocationsView()
                } label: {
                    SafetyOptionRow(
                        icon: "mappin.and.ellipse",
                        title: "Safe Meeting Spots",
                        subtitle: "Public places recommended for first dates",
                        color: .green
                    )
                }

                NavigationLink {
                    DateCheckInView()
                } label: {
                    SafetyOptionRow(
                        icon: "bell.badge.fill",
                        title: "Date Check-In",
                        subtitle: "Set reminders during your date",
                        color: .orange
                    )
                }
            }
        }
    }

    // MARK: - Emergency Contacts Section

    private var emergencyContactsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SafetySectionHeader(title: "Emergency", icon: "phone.badge.plus")

            VStack(spacing: 12) {
                NavigationLink {
                    EmergencyContactsView()
                } label: {
                    SafetyOptionRow(
                        icon: "person.crop.circle.badge.plus",
                        title: "Emergency Contacts",
                        subtitle: "\(viewModel.emergencyContactsCount) contacts added",
                        color: .red
                    )
                }

                Button {
                    viewModel.showQuickSOS = true
                } label: {
                    SafetyOptionRow(
                        icon: "sos",
                        title: "Quick SOS",
                        subtitle: "Instantly alert your contacts",
                        color: .red
                    )
                }
            }
        }
    }

    // MARK: - Resources Section

    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SafetySectionHeader(title: "Resources", icon: "book.fill")

            VStack(spacing: 12) {
                NavigationLink {
                    SafeDatingTipsView()
                } label: {
                    SafetyOptionRow(
                        icon: "lightbulb.fill",
                        title: "Safe Dating Tips",
                        subtitle: "Learn how to stay safe",
                        color: .yellow
                    )
                }

                NavigationLink {
                    CommunityGuidelinesView()
                } label: {
                    SafetyOptionRow(
                        icon: "doc.text.fill",
                        title: "Community Guidelines",
                        subtitle: "Our rules and standards",
                        color: .blue
                    )
                }

                Button {
                    if let url = URL(string: "https://www.rainn.org/") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    SafetyOptionRow(
                        icon: "link",
                        title: "Support Hotlines",
                        subtitle: "Access help resources",
                        color: .purple
                    )
                }
            }
        }
    }
}

// MARK: - Section Header

struct SafetySectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.purple)

            Text(title)
                .font(.title3.bold())

            Spacer()
        }
    }
}

// MARK: - Safety Option Row

struct SafetyOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var isCompleted: Bool = false
    var badge: Int?

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.green)
            } else if let badge = badge, badge > 0 {
                Text("\(badge)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color)
                    .clipShape(Capsule())
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
}

// MARK: - View Model

@MainActor
class SafetyCenterViewModel: ObservableObject {
    @Published var photoVerified = false
    @Published var idVerified = false
    @Published var phoneVerified = false
    @Published var socialMediaVerified = false
    @Published var blockedCount = 0
    @Published var emergencyContactsCount = 0
    @Published var showQuickSOS = false

    private let db = Firestore.firestore()

    func loadSafetyData() async {
        guard let userId = AuthService.shared.currentUser?.id else { return }

        do {
            // Load verification status
            let userDoc = try await db.collection("users").document(userId).getDocument()
            if let verificationData = userDoc.data()?["verificationStatus"] as? [String: Bool] {
                photoVerified = verificationData["photoVerified"] ?? false
                idVerified = verificationData["idVerified"] ?? false
                phoneVerified = verificationData["phoneVerified"] ?? false
                socialMediaVerified = verificationData["socialMediaVerified"] ?? false
            }

            // Load blocked users count
            let blockedSnapshot = try await db.collection("blocked_users")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            blockedCount = blockedSnapshot.documents.count

            // Load emergency contacts count
            let contactsSnapshot = try await db.collection("emergency_contacts")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            emergencyContactsCount = contactsSnapshot.documents.count

        } catch {
            Logger.shared.error("Error loading safety data", category: .general, error: error)
        }
    }
}

#Preview {
    SafetyCenterView()
        .environmentObject(AuthService.shared)
}
