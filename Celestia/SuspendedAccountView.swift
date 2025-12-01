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
                            HapticManager.shared.impact(.medium)
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
                            HapticManager.shared.impact(.light)
                            authService.signOut()
                        }) {
                            Text("Sign Out")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)

                        // Appeal button
                        Button(action: {
                            HapticManager.shared.impact(.light)
                            showingAppealSheet = true
                        }) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                Text(hasExistingAppeal ? "Appeal Submitted" : "Appeal Decision")
                            }
                            .font(.subheadline)
                            .foregroundColor(hasExistingAppeal ? .secondary : .orange)
                        }
                        .disabled(hasExistingAppeal)
                        .padding(.top, 4)
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
