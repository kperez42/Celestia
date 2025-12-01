//
//  SuspendedAccountView.swift
//  Celestia
//
//  Shows suspension feedback to users whose accounts have been suspended
//

import SwiftUI
import FirebaseFirestore

struct SuspendedAccountView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isRefreshing = false
    @State private var appearAnimation = false
    @State private var animateIcon = false

    private var user: User? {
        authService.currentUser
    }

    private var suspendedUntilDate: Date? {
        user?.suspendedUntil
    }

    private var daysRemaining: Int {
        guard let until = suspendedUntilDate else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: until).day ?? 0
        return max(0, days)
    }

    private var hoursRemaining: Int {
        guard let until = suspendedUntilDate else { return 0 }
        let hours = Calendar.current.dateComponents([.hour], from: Date(), to: until).hour ?? 0
        return max(0, hours % 24)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header icon
                    ZStack {
                        // Outer pulse ring
                        Circle()
                            .stroke(Color.red.opacity(0.3), lineWidth: 2)
                            .frame(width: 120, height: 120)
                            .scaleEffect(animateIcon ? 1.2 : 1.0)
                            .opacity(animateIcon ? 0 : 0.8)

                        Circle()
                            .fill(Color.red.opacity(0.15))
                            .frame(width: 100, height: 100)

                        Image(systemName: "exclamationmark.octagon.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red, .red.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .symbolEffect(.pulse, options: .repeating)
                    }
                    .padding(.top, 40)
                    .scaleEffect(appearAnimation ? 1 : 0.8)
                    .opacity(appearAnimation ? 1 : 0)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: false)) {
                            animateIcon = true
                        }
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                            appearAnimation = true
                        }
                    }

                    // Title
                    Text("Account Suspended")
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 20)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    // Time remaining card
                    if let _ = suspendedUntilDate {
                        VStack(spacing: 16) {
                            Label("Suspension Period", systemImage: "clock.fill")
                                .font(.headline)
                                .foregroundColor(.orange)

                            HStack(spacing: 20) {
                                VStack {
                                    Text("\(daysRemaining)")
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(.primary)
                                    Text("Days")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Text(":")
                                    .font(.title)
                                    .foregroundColor(.secondary)

                                VStack {
                                    Text("\(hoursRemaining)")
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(.primary)
                                    Text("Hours")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()

                            if let until = suspendedUntilDate {
                                Text("Access will be restored on \(until.formatted(date: .long, time: .shortened))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 30)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: appearAnimation)
                    }

                    // Reason card
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Reason for Suspension", systemImage: "info.circle.fill")
                            .font(.headline)
                            .foregroundColor(.red)

                        Text(user?.suspendReason ?? "Your account has been temporarily suspended due to a violation of our community guidelines.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: appearAnimation)

                    // Guidelines reminder
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Community Guidelines")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(guidelines, id: \.title) { guideline in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: guideline.icon)
                                    .foregroundColor(guideline.color)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(guideline.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(guideline.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 8)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: appearAnimation)

                    // What happens next
                    VStack(alignment: .leading, spacing: 16) {
                        Label("What Happens Next", systemImage: "arrow.right.circle.fill")
                            .font(.headline)
                            .foregroundColor(.blue)

                        Text("Once your suspension period ends, your account will be automatically restored. Please ensure you follow our community guidelines to avoid future suspensions.")
                            .font(.body)
                            .foregroundColor(.secondary)

                        Text("Repeated violations may result in permanent account suspension.")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: appearAnimation)

                    Spacer(minLength: 40)

                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            Task {
                                await checkSuspensionStatus()
                            }
                        }) {
                            HStack {
                                if isRefreshing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                    Text("Check Status")
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                        }
                        .disabled(isRefreshing)

                        Button(action: {
                            authService.signOut()
                        }) {
                            Text("Sign Out")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6), value: appearAnimation)
                }
            }
            .navigationTitle("Account Status")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Helper Methods

    private var guidelines: [GuidelineItem] {
        [
            GuidelineItem(
                icon: "hand.raised.fill",
                color: .red,
                title: "Respect Others",
                description: "Treat all users with respect. Harassment and bullying are not tolerated."
            ),
            GuidelineItem(
                icon: "photo.fill",
                color: .orange,
                title: "Appropriate Content",
                description: "Only share photos and content that follow our content guidelines."
            ),
            GuidelineItem(
                icon: "person.fill.checkmark",
                color: .green,
                title: "Be Authentic",
                description: "Use real photos and genuine information about yourself."
            ),
            GuidelineItem(
                icon: "message.fill",
                color: .blue,
                title: "Safe Communication",
                description: "Keep conversations respectful and don't share spam or scam content."
            )
        ]
    }

    private func checkSuspensionStatus() async {
        isRefreshing = true
        defer { isRefreshing = false }

        // Refresh user data to check if suspension has been lifted
        await authService.fetchUser()

        // Check if suspension is over
        if let user = authService.currentUser {
            if !user.isSuspended {
                HapticManager.shared.notification(.success)
            } else if let until = user.suspendedUntil, until <= Date() {
                // Suspension period has passed, clear the suspension
                do {
                    try await clearSuspension()
                    HapticManager.shared.notification(.success)
                } catch {
                    Logger.shared.error("Failed to clear suspension", category: .database, error: error)
                    HapticManager.shared.notification(.error)
                }
            } else {
                HapticManager.shared.notification(.warning)
            }
        }
    }

    private func clearSuspension() async throws {
        guard let userId = user?.id else { return }

        try await Firestore.firestore().collection("users").document(userId).updateData([
            "isSuspended": false,
            "suspendedAt": FieldValue.delete(),
            "suspendedUntil": FieldValue.delete(),
            "suspendReason": FieldValue.delete(),
            "profileStatus": "active"
        ])

        await authService.fetchUser()
    }
}

// MARK: - Guideline Item Model

private struct GuidelineItem: Hashable {
    let icon: String
    let color: Color
    let title: String
    let description: String
}

// MARK: - Preview

#Preview {
    SuspendedAccountView()
        .environmentObject(AuthService.shared)
}
