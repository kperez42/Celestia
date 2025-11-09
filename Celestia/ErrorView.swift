//
//  ErrorView.swift
//  Celestia
//
//  Beautiful error display and network status components
//

import SwiftUI

// MARK: - Error Alert View

struct ErrorAlertView: View {
    let error: AppError
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.red.opacity(0.15),
                                Color.orange.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: error.icon)
                    .font(.system(size: 40))
                    .foregroundColor(.red)
            }
            .scaleEffect(appeared ? 1 : 0.8)
            .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1), value: appeared)

            // Error details
            VStack(spacing: 12) {
                Text("Oops!")
                    .font(.title2)
                    .fontWeight(.bold)

                if let description = error.errorDescription {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                }

                if let recovery = error.recoverySuggestion {
                    Text(recovery)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 20)

            // Actions
            VStack(spacing: 12) {
                if let onRetry = onRetry, error.retryable {
                    Button(action: {
                        HapticManager.shared.impact(.medium)
                        onDismiss()
                        onRetry()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                            Text("Try Again")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: 240)
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                    }
                }

                Button(action: {
                    HapticManager.shared.impact(.light)
                    onDismiss()
                }) {
                    Text(error.retryable ? "Dismiss" : "OK")
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 12)
                }
            }
        }
        .padding(32)
        .background(Color(.systemBackground))
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        .padding(40)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}

// MARK: - Network Status Banner

struct NetworkStatusBanner: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    @ObservedObject var messageQueue = OfflineMessageQueue.shared

    @State private var showBanner = false
    @State private var bannerOffset: CGFloat = -100

    var body: some View {
        VStack(spacing: 0) {
            if showBanner {
                HStack(spacing: 12) {
                    // Icon
                    Image(systemName: networkMonitor.isConnected ? "wifi" : "wifi.slash")
                        .font(.callout)
                        .foregroundColor(.white)

                    // Message
                    VStack(alignment: .leading, spacing: 2) {
                        Text(networkMonitor.isConnected ? "Back Online" : "No Connection")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)

                        if !networkMonitor.isConnected {
                            Text("Messages will be sent when reconnected")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.9))
                        } else if messageQueue.isSyncing {
                            Text("Syncing messages...")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.9))
                        } else if messageQueue.hasQueuedMessages {
                            Text("\(messageQueue.queuedMessages.count) message(s) pending")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }

                    Spacer()

                    // Syncing indicator
                    if messageQueue.isSyncing {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    networkMonitor.isConnected ?
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(
                            colors: [.red, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                )
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                .offset(y: bannerOffset)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showBanner)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: bannerOffset)
        .onChange(of: networkMonitor.isConnected) { newValue in
            showBanner = true
            bannerOffset = 0

            // Auto-hide "Back Online" banner after 3 seconds
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    hideBanner()
                }
            }
        }
        .onChange(of: messageQueue.isSyncing) { newValue in
            if !newValue && networkMonitor.isConnected && showBanner {
                // Hide banner when syncing completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    hideBanner()
                }
            }
        }
    }

    private func hideBanner() {
        withAnimation {
            bannerOffset = -100
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showBanner = false
        }
    }
}

// MARK: - Inline Error View

struct InlineErrorView: View {
    let error: AppError
    let onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: error.icon)
                .font(.system(size: 50))
                .foregroundColor(.red.opacity(0.7))

            VStack(spacing: 8) {
                if let description = error.errorDescription {
                    Text(description)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                }

                if let recovery = error.recoverySuggestion {
                    Text(recovery)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 20)

            if let onRetry = onRetry, error.retryable {
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    onRetry()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
                }
            }
        }
        .padding(32)
    }
}

// MARK: - Preview

#Preview("Error Alert") {
    ZStack {
        Color.black.opacity(0.4)
            .ignoresSafeArea()

        ErrorAlertView(
            error: .network(.noConnection),
            onRetry: { print("Retry") },
            onDismiss: { print("Dismiss") }
        )
    }
}

#Preview("Network Banner") {
    VStack {
        NetworkStatusBanner()
        Spacer()
    }
}

#Preview("Inline Error") {
    InlineErrorView(
        error: .database("Failed to load data"),
        onRetry: { print("Retry") }
    )
}
