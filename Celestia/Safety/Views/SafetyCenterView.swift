//
//  SafetyCenterView.swift
//  Celestia
//
//  Main safety center UI with verification, check-ins, tips, and reports
//

import SwiftUI

struct SafetyCenterView: View {

    @StateObject private var safetyManager = SafetyManager.shared
    @StateObject private var verificationService = VerificationService.shared
    @StateObject private var emergencyContactManager = EmergencyContactManager.shared
    @StateObject private var checkInManager = DateCheckInManager.shared

    @State private var selectedTab: SafetyTab = .overview

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Safety Score Header
                safetyScoreHeader

                // Tab Bar
                safetyTabBar

                // Content
                TabView(selection: $selectedTab) {
                    overviewTab
                        .tag(SafetyTab.overview)

                    verificationTab
                        .tag(SafetyTab.verification)

                    checkInTab
                        .tag(SafetyTab.checkIn)

                    tipsTab
                        .tag(SafetyTab.tips)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Safety Center")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Safety Score Header

    private var safetyScoreHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Safety Score")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Text("\(safetyManager.safetyScore)")
                            .font(.system(size: 40, weight: .bold))
                        Text("/ 100")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Score Ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: CGFloat(safetyManager.safetyScore) / 100)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))

                    Image(systemName: scoreIcon)
                        .font(.system(size: 28))
                        .foregroundColor(scoreColor)
                }
            }

            // Status Message
            Text(scoreMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Tab Bar

    private var safetyTabBar: some View {
        HStack(spacing: 0) {
            ForEach(SafetyTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20))

                        Text(tab.title)
                            .font(.caption)
                    }
                    .foregroundColor(selectedTab == tab ? .blue : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Overview Tab

    private var overviewTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Active Alerts
                if !safetyManager.activeAlerts.isEmpty {
                    alertsSection
                }

                // Verification Status
                verificationStatusCard

                // Emergency Contacts
                emergencyContactsCard

                // Active Check-In
                if checkInManager.activeCheckIn != nil {
                    activeCheckInCard
                }

                // Quick Actions
                quickActionsSection
            }
            .padding()
        }
    }

    // MARK: - Verification Tab

    private var verificationTab: some View {
        VerificationFlowView()
    }

    // MARK: - Check-In Tab

    private var checkInTab: some View {
        CheckInView()
    }

    // MARK: - Tips Tab

    private var tipsTab: some View {
        SafetyTipsView()
    }

    // MARK: - Alerts Section

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Alerts")
                .font(.headline)

            ForEach(safetyManager.activeAlerts) { alert in
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(alertColor(alert.severity))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(alert.type.rawValue.capitalized)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(alert.message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: { safetyManager.dismissAlert(alert) }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(alertColor(alert.severity).opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Verification Status Card

    private var verificationStatusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: verificationService.verificationStatus.icon)
                    .font(.title2)
                    .foregroundColor(.blue)

                Text("Verification Status")
                    .font(.headline)

                Spacer()

                NavigationLink(destination: VerificationFlowView()) {
                    Text("Verify")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }

            VStack(spacing: 12) {
                verificationRow(
                    title: "Photo Verification",
                    isComplete: verificationService.photoVerified,
                    icon: "camera.fill"
                )

                verificationRow(
                    title: "ID Verification",
                    isComplete: verificationService.idVerified,
                    icon: "person.text.rectangle.fill"
                )

                verificationRow(
                    title: "Background Check",
                    isComplete: verificationService.backgroundCheckCompleted,
                    icon: "shield.checkered"
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func verificationRow(title: String, isComplete: Bool, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isComplete ? .green : .gray)

            Text(title)
                .font(.subheadline)

            Spacer()

            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isComplete ? .green : .gray)
        }
    }

    // MARK: - Emergency Contacts Card

    private var emergencyContactsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.title2)
                    .foregroundColor(.red)

                Text("Emergency Contacts")
                    .font(.headline)

                Spacer()

                NavigationLink(destination: EmergencyContactsView()) {
                    Text(emergencyContactManager.hasContacts() ? "Manage" : "Add")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }

            if emergencyContactManager.hasContacts() {
                VStack(spacing: 8) {
                    ForEach(emergencyContactManager.contacts.prefix(3)) { contact in
                        HStack {
                            Image(systemName: contact.relationship.icon)
                                .foregroundColor(.gray)

                            Text(contact.name)
                                .font(.subheadline)

                            Spacer()

                            Text(contact.relationship.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if emergencyContactManager.contacts.count > 3 {
                        Text("+\(emergencyContactManager.contacts.count - 3) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("Add trusted contacts who will be notified during emergencies")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Active Check-In Card

    private var activeCheckInCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.title2)
                    .foregroundColor(.orange)

                Text("Active Check-In")
                    .font(.headline)

                Spacer()

                Text(checkInManager.activeCheckIn?.status.displayName ?? "")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(8)
            }

            if let checkIn = checkInManager.activeCheckIn {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date with \(checkIn.matchName)")
                        .font(.subheadline)

                    Text(checkIn.location.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button(action: {
                    Task {
                        try? await checkInManager.checkInAtEnd(rating: .felt_safe)
                    }
                }) {
                    Text("Check In - I'm Safe")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                quickActionButton(
                    title: "Report User",
                    icon: "flag.fill",
                    color: .red
                ) {
                    // Navigate to report view
                }

                quickActionButton(
                    title: "Block User",
                    icon: "hand.raised.fill",
                    color: .orange
                ) {
                    // Navigate to block view
                }

                quickActionButton(
                    title: "Safety Tips",
                    icon: "lightbulb.fill",
                    color: .yellow
                ) {
                    selectedTab = .tips
                }

                quickActionButton(
                    title: "Emergency",
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                ) {
                    Task {
                        try? await safetyManager.triggerEmergency()
                    }
                }
            }
        }
    }

    private func quickActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Helpers

    private var scoreColor: Color {
        if safetyManager.safetyScore >= 80 {
            return .green
        } else if safetyManager.safetyScore >= 50 {
            return .yellow
        } else {
            return .red
        }
    }

    private var scoreIcon: String {
        if safetyManager.safetyScore >= 80 {
            return "checkmark.shield.fill"
        } else if safetyManager.safetyScore >= 50 {
            return "exclamationmark.shield.fill"
        } else {
            return "xmark.shield.fill"
        }
    }

    private var scoreMessage: String {
        if safetyManager.safetyScore >= 80 {
            return "Great! Your safety features are well configured."
        } else if safetyManager.safetyScore >= 50 {
            return "Good start. Complete more verifications to improve your score."
        } else {
            return "Let's improve your safety. Start by completing verifications."
        }
    }

    private func alertColor(_ severity: AlertSeverity) -> Color {
        switch severity {
        case .low:
            return .gray
        case .medium:
            return .yellow
        case .high:
            return .orange
        case .critical:
            return .red
        }
    }
}

// MARK: - Safety Tab

enum SafetyTab: CaseIterable {
    case overview
    case verification
    case checkIn
    case tips

    var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .verification:
            return "Verify"
        case .checkIn:
            return "Check-In"
        case .tips:
            return "Tips"
        }
    }

    var icon: String {
        switch self {
        case .overview:
            return "house.fill"
        case .verification:
            return "checkmark.seal.fill"
        case .checkIn:
            return "clock.fill"
        case .tips:
            return "lightbulb.fill"
        }
    }
}

// MARK: - Preview

struct SafetyCenterView_Previews: PreviewProvider {
    static var previews: some View {
        SafetyCenterView()
    }
}
