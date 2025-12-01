//
//  BannedAccountView.swift
//  Celestia
//
//  Shows ban feedback to users whose accounts have been permanently banned
//

import SwiftUI
import FirebaseFirestore

struct BannedAccountView: View {
    @EnvironmentObject var authService: AuthService
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

                        Image(systemName: "xmark.octagon.fill")
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
                    Text("Account Permanently Banned")
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 20)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                        .foregroundColor(.red)

                    // Reason card
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Reason for Ban", systemImage: "info.circle.fill")
                            .font(.headline)
                            .foregroundColor(.red)

                        Text(user?.banReason ?? "Your account has been permanently banned due to serious violations of our community guidelines.")
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
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: appearAnimation)

                    // What this means
                    VStack(alignment: .leading, spacing: 16) {
                        Label("What This Means", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundColor(.orange)

                        VStack(alignment: .leading, spacing: 12) {
                            bulletPoint("Your profile is no longer visible to other users")
                            bulletPoint("You cannot send or receive messages")
                            bulletPoint("You cannot create matches or interact with profiles")
                            bulletPoint("This decision is permanent unless successfully appealed")
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
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

                    Spacer(minLength: 40)

                    // Action buttons
                    VStack(spacing: 12) {
                        // Appeal button
                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            showingAppealSheet = true
                        }) {
                            HStack {
                                Image(systemName: hasExistingAppeal ? "checkmark.circle.fill" : "envelope.fill")
                                Text(hasExistingAppeal ? "Appeal Submitted" : "Appeal This Decision")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: hasExistingAppeal ? [.gray, .gray.opacity(0.8)] : [.orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                        }
                        .disabled(hasExistingAppeal)

                        Button(action: {
                            HapticManager.shared.impact(.light)
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
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: appearAnimation)
                }
            }
            .navigationTitle("Account Status")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await checkExistingAppeal()
            }
            .sheet(isPresented: $showingAppealSheet) {
                appealSheet
            }
            .alert("Appeal Submitted", isPresented: $showAppealSuccess) {
                Button("OK") { }
            } message: {
                Text("Your appeal has been submitted. Our team will review it and respond within 24-48 hours. If your appeal is approved, your account will be restored.")
            }
        }
    }

    // MARK: - Helper Views

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.secondary)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
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

                    Text("Appeal Your Ban")
                        .font(.title2.bold())

                    Text("If you believe this ban was made in error, please explain why below. Appeals are carefully reviewed by our moderation team.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)

                // Current reason display
                if let reason = user?.banReason {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ban Reason")
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

                    Text("Please provide specific details about why you believe this ban was an error. Include any relevant context.")
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
                        appealMessage.trimmingCharacters(in: .whitespacesAndNewlines).count >= 30
                            ? Color.orange
                            : Color.gray
                    )
                    .cornerRadius(16)
                }
                .disabled(appealMessage.trimmingCharacters(in: .whitespacesAndNewlines).count < 30 || isSubmittingAppeal)
                .padding(.horizontal)
                .padding(.bottom)

                Text("Minimum 30 characters required for ban appeals")
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

    // MARK: - Helper Data

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

    // MARK: - Helper Methods

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
                "type": "ban",
                "originalReason": user?.banReason ?? "",
                "appealMessage": appealMessage,
                "status": "pending",
                "submittedAt": FieldValue.serverTimestamp()
            ])

            await MainActor.run {
                isSubmittingAppeal = false
                showingAppealSheet = false
                hasExistingAppeal = true
                showAppealSuccess = true
                appealMessage = ""
            }

            HapticManager.shared.notification(.success)
            Logger.shared.info("Ban appeal submitted for user: \(userId)", category: .moderation)

        } catch {
            await MainActor.run {
                isSubmittingAppeal = false
            }
            HapticManager.shared.notification(.error)
            Logger.shared.error("Failed to submit ban appeal", category: .database, error: error)
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

#Preview {
    BannedAccountView()
        .environmentObject(AuthService.shared)
}
