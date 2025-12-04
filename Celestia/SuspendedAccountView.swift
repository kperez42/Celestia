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
    @State private var showingAppealSheet = false
    @State private var appealMessage = ""
    @State private var isSubmittingAppeal = false
    @State private var showAppealSuccess = false
    @State private var hasExistingAppeal = false

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
                    // Header icon with premium radial glow
                    ZStack {
                        // Large radial glow background
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.red.opacity(0.2),
                                        Color.orange.opacity(0.12),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 30,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 200, height: 200)
                            .scaleEffect(animateIcon ? 1.1 : 1.0)

                        // Outer pulse ring with gradient
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.red.opacity(0.4), Color.orange.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2.5
                            )
                            .frame(width: 130, height: 130)
                            .scaleEffect(animateIcon ? 1.25 : 1.0)
                            .opacity(animateIcon ? 0 : 0.8)

                        // Middle glow layer
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.red.opacity(0.2), Color.orange.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 110, height: 110)

                        // Inner glow
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 95, height: 95)
                            .blur(radius: 8)

                        // Icon background
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.9), Color.white.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 90, height: 90)
                            .shadow(color: .red.opacity(0.2), radius: 10, y: 4)

                        Image(systemName: "exclamationmark.octagon.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .red.opacity(0.3), radius: 8)
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

                    // Title with gradient
                    Text("Account Suspended")
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 20)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .multilineTextAlignment(.center)

                    // Time remaining card with premium styling
                    if let _ = suspendedUntilDate {
                        VStack(spacing: 16) {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.orange.opacity(0.2), Color.yellow.opacity(0.15)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 36, height: 36)

                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(
                                            LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                                        )
                                }

                                Text("Suspension Period")
                                    .font(.headline)
                            }

                            HStack(spacing: 24) {
                                VStack(spacing: 6) {
                                    Text("\(daysRemaining)")
                                        .font(.system(size: 38, weight: .bold, design: .rounded))
                                        .foregroundStyle(
                                            LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom)
                                        )
                                    Text("Days")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.secondary)
                                }
                                .frame(width: 80)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.orange.opacity(0.08))
                                )

                                Text(":")
                                    .font(.title)
                                    .foregroundColor(.secondary)

                                VStack(spacing: 6) {
                                    Text("\(hoursRemaining)")
                                        .font(.system(size: 38, weight: .bold, design: .rounded))
                                        .foregroundStyle(
                                            LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom)
                                        )
                                    Text("Hours")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.secondary)
                                }
                                .frame(width: 80)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.orange.opacity(0.08))
                                )
                            }
                            .padding(.vertical, 8)

                            if let until = suspendedUntilDate {
                                Text("Access will be restored on \(until.formatted(date: .long, time: .shortened))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.orange.opacity(0.1), Color.yellow.opacity(0.06)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.orange.opacity(0.25), Color.yellow.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .orange.opacity(0.1), radius: 12, y: 6)
                        .padding(.horizontal)
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 30)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: appearAnimation)
                    }

                    // Reason card with premium styling
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.red.opacity(0.2), Color.orange.opacity(0.15)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)

                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(
                                        LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
                                    )
                            }

                            Text("Reason for Suspension")
                                .font(.headline)
                        }

                        Text(user?.suspendReason ?? "Your account has been temporarily suspended due to a violation of our community guidelines.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineSpacing(3)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                LinearGradient(
                                    colors: [Color.red.opacity(0.1), Color.orange.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.red.opacity(0.2), Color.orange.opacity(0.12)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .padding(.horizontal)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: appearAnimation)

                    // Guidelines reminder with premium styling
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 32, height: 32)

                                Image(systemName: "list.bullet.clipboard.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(
                                        LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                                    )
                            }

                            Text("Community Guidelines")
                                .font(.headline)
                        }
                        .padding(.horizontal)

                        ForEach(guidelines, id: \.title) { guideline in
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(guideline.color.opacity(0.12))
                                        .frame(width: 32, height: 32)

                                    Image(systemName: guideline.icon)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(guideline.color)
                                }

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
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .cornerRadius(18)
                    .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
                    .padding(.horizontal)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: appearAnimation)

                    // What happens next with premium styling
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue.opacity(0.2), Color.cyan.opacity(0.15)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)

                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(
                                        LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                                    )
                            }

                            Text("What Happens Next")
                                .font(.headline)
                        }

                        Text("Once your suspension period ends, your account will be automatically restored. Please ensure you follow our community guidelines to avoid future suspensions.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineSpacing(3)

                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(
                                    LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
                                )
                            Text("Repeated violations may result in permanent account suspension.")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.red)
                        }
                        .padding(10)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(10)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.1), Color.cyan.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.2), Color.cyan.opacity(0.12)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .padding(.horizontal)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: appearAnimation)

                    Spacer(minLength: 40)

                    // Action buttons with premium styling
                    VStack(spacing: 14) {
                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            Task {
                                await checkSuspensionStatus()
                            }
                        }) {
                            HStack(spacing: 10) {
                                if isRefreshing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                        .font(.title3)
                                    Text("Check Status")
                                        .fontWeight(.semibold)
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple, .blue.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(18)
                            .shadow(color: .blue.opacity(0.35), radius: 12, y: 6)
                            .shadow(color: .purple.opacity(0.2), radius: 20, y: 10)
                        }
                        .disabled(isRefreshing)

                        // Appeal button with gradient
                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            showingAppealSheet = true
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: hasExistingAppeal ? "checkmark.circle.fill" : "envelope.fill")
                                    .font(.title3)
                                Text(hasExistingAppeal ? "Appeal Submitted" : "Appeal Decision")
                                    .fontWeight(.semibold)
                            }
                            .font(.headline)
                            .foregroundStyle(
                                hasExistingAppeal ?
                                LinearGradient(colors: [.secondary, .secondary.opacity(0.8)], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                hasExistingAppeal ?
                                LinearGradient(colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.08)], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.1), Color.red.opacity(0.08)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(18)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(
                                        hasExistingAppeal ?
                                        LinearGradient(colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.15)], startPoint: .leading, endPoint: .trailing) :
                                        LinearGradient(
                                            colors: [Color.orange.opacity(0.25), Color.red.opacity(0.15)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .disabled(hasExistingAppeal)

                        Button(action: {
                            HapticManager.shared.impact(.light)
                            authService.signOut()
                        }) {
                            Text("Sign Out")
                                .font(.subheadline.weight(.medium))
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
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.96, blue: 0.96),
                        Color(red: 1.0, green: 0.98, blue: 0.98),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Account Status")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // Auto-check if suspension has expired on view appear
                await checkSuspensionOnAppear()
                // Check if user has already submitted an appeal
                await checkExistingAppeal()
            }
            .sheet(isPresented: $showingAppealSheet) {
                appealSheet
            }
            .alert("Appeal Submitted", isPresented: $showAppealSuccess) {
                Button("OK") { }
            } message: {
                Text("Your appeal has been submitted. Our team will review it and get back to you within 24-48 hours.")
            }
        }
    }

    // MARK: - Appeal Sheet

    private var appealSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "envelope.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)

                    Text("Appeal Your Suspension")
                        .font(.title2.bold())

                    Text("If you believe this suspension was made in error, please explain why below. Our team will review your appeal.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)

                // Current reason display
                if let reason = user?.suspendReason {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Suspension Reason")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)

                        Text(reason)
                            .font(.subheadline)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }

                // Appeal message input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Appeal")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)

                    TextEditor(text: $appealMessage)
                        .frame(minHeight: 150)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.separator), lineWidth: 1)
                        )

                    Text("Please provide specific details about why you believe this decision was an error.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                Spacer()

                // Submit button
                Button(action: {
                    Task {
                        await submitAppeal()
                    }
                }) {
                    HStack {
                        if isSubmittingAppeal {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text("Submit Appeal")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        appealMessage.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20
                            ? Color.orange
                            : Color.gray
                    )
                    .cornerRadius(16)
                }
                .disabled(appealMessage.trimmingCharacters(in: .whitespacesAndNewlines).count < 20 || isSubmittingAppeal)
                .padding(.horizontal)
                .padding(.bottom)

                Text("Minimum 20 characters required")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom)
            }
            .navigationTitle("Appeal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingAppealSheet = false
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func checkSuspensionOnAppear() async {
        // If suspension period has passed, automatically clear it
        if let until = suspendedUntilDate, until <= Date() {
            do {
                try await clearSuspension()
                HapticManager.shared.notification(.success)
            } catch {
                Logger.shared.error("Failed to auto-clear suspension", category: .database, error: error)
            }
        }
    }

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

    private func checkExistingAppeal() async {
        guard let userId = user?.id else { return }

        do {
            let snapshot = try await Firestore.firestore()
                .collection("appeals")
                .whereField("userId", isEqualTo: userId)
                .whereField("status", isEqualTo: "pending")
                .limit(to: 1)
                .getDocuments()

            await MainActor.run {
                hasExistingAppeal = !snapshot.documents.isEmpty
            }
        } catch {
            Logger.shared.error("Failed to check existing appeal", category: .database, error: error)
        }
    }

    private func submitAppeal() async {
        guard let userId = user?.id else { return }

        isSubmittingAppeal = true

        do {
            // Create appeal document
            try await Firestore.firestore().collection("appeals").addDocument(data: [
                "userId": userId,
                "userName": user?.fullName ?? "Unknown",
                "userEmail": user?.email ?? "",
                "type": "suspension",
                "originalReason": user?.suspendReason ?? "",
                "appealMessage": appealMessage,
                "status": "pending",
                "submittedAt": FieldValue.serverTimestamp(),
                "suspendedUntil": user?.suspendedUntil as Any
            ])

            await MainActor.run {
                isSubmittingAppeal = false
                showingAppealSheet = false
                hasExistingAppeal = true
                showAppealSuccess = true
                appealMessage = ""
            }

            HapticManager.shared.notification(.success)
            Logger.shared.info("Appeal submitted for user: \(userId)", category: .moderation)

        } catch {
            await MainActor.run {
                isSubmittingAppeal = false
            }
            HapticManager.shared.notification(.error)
            Logger.shared.error("Failed to submit appeal", category: .database, error: error)
        }
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
