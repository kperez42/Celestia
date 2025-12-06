//
//  ScreenshotDetectionService.swift
//  Celestia
//
//  Service for detecting screenshots and notifying users
//

import SwiftUI
import Foundation
import UIKit
import FirebaseFirestore

@MainActor
class ScreenshotDetectionService: ObservableObject {
    static let shared = ScreenshotDetectionService()

    @Published var screenshotDetected = false
    @Published var lastScreenshotContext: ScreenshotContext?

    private let db = Firestore.firestore()
    private var notificationObserver: NSObjectProtocol?

    enum ScreenshotContext {
        case chat(matchId: String, otherUserId: String)
        case profile(userId: String)
        case photo(userId: String, photoIndex: Int)
    }

    private init() {
        setupScreenshotDetection()
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Setup

    private func setupScreenshotDetection() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleScreenshot()
            }
        }
    }

    // MARK: - Screenshot Handling

    private func handleScreenshot() {
        screenshotDetected = true
        HapticManager.shared.notification(.warning)

        // Log screenshot event if in a sensitive context
        if let context = lastScreenshotContext {
            logScreenshotEvent(context: context)
        }

        // Reset after showing alert
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.screenshotDetected = false
        }
    }

    func setContext(_ context: ScreenshotContext) {
        lastScreenshotContext = context
    }

    func clearContext() {
        lastScreenshotContext = nil
    }

    // MARK: - Logging

    private func logScreenshotEvent(context: ScreenshotContext) {
        // BUGFIX: Use effectiveId for reliable user identification
        guard let currentUserId = AuthService.shared.currentUser?.effectiveId else { return }

        let eventData: [String: Any]

        switch context {
        case .chat(let matchId, let otherUserId):
            eventData = [
                "type": "chat_screenshot",
                "userId": currentUserId,
                "matchId": matchId,
                "targetUserId": otherUserId,
                "timestamp": Timestamp(date: Date())
            ]
            // Notify the other user
            sendScreenshotNotification(to: otherUserId, type: "chat")

        case .profile(let userId):
            eventData = [
                "type": "profile_screenshot",
                "userId": currentUserId,
                "targetUserId": userId,
                "timestamp": Timestamp(date: Date())
            ]
            sendScreenshotNotification(to: userId, type: "profile")

        case .photo(let userId, let photoIndex):
            eventData = [
                "type": "photo_screenshot",
                "userId": currentUserId,
                "targetUserId": userId,
                "photoIndex": photoIndex,
                "timestamp": Timestamp(date: Date())
            ]
            sendScreenshotNotification(to: userId, type: "photo")
        }

        // Log to Firestore
        db.collection("screenshotEvents").addDocument(data: eventData) { error in
            if let error = error {
                Logger.shared.error("Error logging screenshot", category: .general, error: error)
            }
        }
    }

    // MARK: - Notifications

    private func sendScreenshotNotification(to userId: String, type: String) {
        guard let currentUser = AuthService.shared.currentUser,
              let senderId = currentUser.effectiveId else { return }

        let notificationData: [String: Any] = [
            "recipientId": userId,
            "senderId": senderId,
            "senderName": currentUser.fullName,
            "type": "screenshot_alert",
            "screenshotType": type,
            "timestamp": Timestamp(date: Date()),
            "isRead": false
        ]

        db.collection("notifications").addDocument(data: notificationData) { error in
            if let error = error {
                Logger.shared.error("Error sending screenshot notification", category: .general, error: error)
            }
        }
    }
}

// MARK: - Screenshot Alert View

struct ScreenshotAlertView: View {
    @Binding var isPresented: Bool
    let userName: String
    let context: String

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            // Alert card
            VStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 35))
                        .foregroundColor(.orange)
                }

                VStack(spacing: 8) {
                    Text("Screenshot Detected")
                        .font(.title3)
                        .fontWeight(.bold)

                    Text("\(userName) will be notified that you took a screenshot of their \(context)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(icon: "lock.shield.fill", text: "Screenshots are tracked for safety")
                    InfoRow(icon: "bell.fill", text: "User will receive a notification")
                    InfoRow(icon: "hand.raised.fill", text: "Please respect others' privacy")
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)

                Button {
                    isPresented = false
                } label: {
                    Text("I Understand")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGroupedBackground))
                    .shadow(color: .black.opacity(0.3), radius: 20)
            )
            .padding(.horizontal, 40)
        }
        .transition(.opacity.combined(with: .scale))
    }
}

struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - View Modifier

struct ScreenshotDetectionModifier: ViewModifier {
    @StateObject private var screenshotService = ScreenshotDetectionService.shared
    let context: ScreenshotDetectionService.ScreenshotContext
    let userName: String

    @State private var showAlert = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                screenshotService.setContext(context)
            }
            .onDisappear {
                screenshotService.clearContext()
            }
            .onChange(of: screenshotService.screenshotDetected) { detected in
                if detected {
                    showAlert = true
                }
            }
            .overlay {
                if showAlert {
                    ScreenshotAlertView(
                        isPresented: $showAlert,
                        userName: userName,
                        context: contextDescription
                    )
                    .transition(.opacity)
                    .animation(.spring(response: 0.3), value: showAlert)
                }
            }
    }

    private var contextDescription: String {
        switch context {
        case .chat:
            return "conversation"
        case .profile:
            return "profile"
        case .photo:
            return "photo"
        }
    }
}

extension View {
    func detectScreenshots(
        context: ScreenshotDetectionService.ScreenshotContext,
        userName: String
    ) -> some View {
        self.modifier(ScreenshotDetectionModifier(context: context, userName: userName))
    }
}
