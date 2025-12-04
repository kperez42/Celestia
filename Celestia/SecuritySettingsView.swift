//
//  SecuritySettingsView.swift
//  Celestia
//
//  User interface for security settings and preferences
//  Provides centralized control for all security features
//

import SwiftUI

struct SecuritySettingsView: View {
    @StateObject private var securityManager = SecurityManager.shared
    @StateObject private var biometricAuth = BiometricAuthManager.shared
    @StateObject private var clipboardSecurity = ClipboardSecurityManager.shared

    @State private var showingBiometricError = false
    @State private var biometricError: Error?
    @State private var securityStatus: SecurityStatus?
    @State private var isLoading = false
    @State private var animateHeader = false

    var body: some View {
        List {
            // Security Overview Section
            Section {
                securityOverviewCard
            } header: {
                Text("Security Overview")
            }

            // Security Level Section
            Section {
                securityLevelPicker
            } header: {
                Text("Security Level")
            } footer: {
                Text("Choose your preferred security level. Higher levels provide more protection but may require additional steps.")
            }

            // Biometric Authentication Section
            Section {
                biometricAuthSection
            } header: {
                Text("Biometric Authentication")
            } footer: {
                if biometricAuth.isBiometricAvailable {
                    Text("Use \(biometricAuth.biometricTypeString) to secure your account and sensitive actions.")
                } else {
                    Text("Biometric authentication is not available on this device.")
                }
            }

            // Clipboard Security Section
            Section {
                clipboardSecuritySection
            } header: {
                Text("Clipboard Security")
            } footer: {
                Text("Protect your messages and personal information from clipboard leakage.")
            }

            // Advanced Security Section
            Section {
                advancedSecuritySection
            } header: {
                Text("Advanced")
            }

            // Security Recommendations
            if let recommendations = getRecommendations(), !recommendations.isEmpty {
                Section {
                    ForEach(recommendations) { recommendation in
                        recommendationRow(recommendation)
                    }
                } header: {
                    Text("Recommendations")
                }
            }

            // Circuit Breaker Status (for debugging/advanced users)
            #if DEBUG
            Section {
                circuitBreakerSection
            } header: {
                Text("Circuit Breakers (Debug)")
            }
            #endif
        }
        .navigationTitle("Security & Privacy")
        .navigationBarTitleDisplayMode(.large)
        .alert("Biometric Authentication Error", isPresented: $showingBiometricError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = biometricError {
                Text(error.localizedDescription)
            }
        }
        .task {
            await loadSecurityStatus()
        }
        .onAppear {
            animateHeader = true
        }
    }

    // MARK: - Security Overview Card

    private var securityOverviewCard: some View {
        VStack(spacing: 16) {
            // Header with animated icon
            HStack(spacing: 16) {
                ZStack {
                    // Radial glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    (securityStatus?.isHealthy ?? false ? Color.green : Color.orange).opacity(0.25),
                                    (securityStatus?.isHealthy ?? false ? Color.green : Color.orange).opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 40
                            )
                        )
                        .frame(width: 80, height: 80)
                        .scaleEffect(animateHeader ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animateHeader)

                    // Inner circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: securityStatus?.isHealthy ?? false
                                    ? [.green.opacity(0.2), .mint.opacity(0.15)]
                                    : [.orange.opacity(0.2), .yellow.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    Image(systemName: securityStatus?.isHealthy ?? false ? "shield.checkered" : "shield.slash")
                        .font(.system(size: 26))
                        .foregroundStyle(
                            LinearGradient(
                                colors: securityStatus?.isHealthy ?? false ? [.green, .mint] : [.orange, .yellow],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolEffect(.pulse, options: .repeating)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Security Score")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(Int(securityStatus?.overallScore ?? 0))%")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(securityStatus?.healthDescription ?? "Unknown")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(getHealthColor())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(getHealthColor().opacity(0.15))
                        )
                }
            }

            // Divider with gradient
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            // Security Features Status
            if let status = securityStatus {
                VStack(spacing: 10) {
                    securityFeatureRow(
                        icon: "faceid",
                        title: "Biometric Auth",
                        isEnabled: status.biometricAuth.isEnabled
                    )

                    securityFeatureRow(
                        icon: "doc.on.clipboard",
                        title: "Clipboard Security",
                        isEnabled: status.clipboardSecurity.isEnabled
                    )

                    securityFeatureRow(
                        icon: "network",
                        title: "Circuit Breakers",
                        isEnabled: status.circuitBreakers.isEnabled
                    )

                    securityFeatureRow(
                        icon: "speedometer",
                        title: "Rate Limiting",
                        isEnabled: status.rateLimiting.isEnabled
                    )

                    securityFeatureRow(
                        icon: "camera.fill",
                        title: "Screenshot Detection",
                        isEnabled: status.screenshotDetection.isEnabled
                    )
                }
            }
        }
        .padding(.vertical, 12)
    }

    private func securityFeatureRow(icon: String, title: String, isEnabled: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.1), .blue.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            ZStack {
                Circle()
                    .fill(isEnabled ? Color.green.opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 28, height: 28)

                Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle")
                    .font(.system(size: 16))
                    .foregroundColor(isEnabled ? .green : .gray)
            }
        }
    }

    // MARK: - Security Level Picker

    private var securityLevelPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach([SecurityLevel.low, .medium, .high], id: \.rawValue) { level in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        securityManager.setSecurityLevel(level)
                        HapticManager.shared.impact(.medium)
                    }
                    Task {
                        await loadSecurityStatus()
                    }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: securityManager.securityLevel == level
                                            ? [.purple.opacity(0.2), .blue.opacity(0.15)]
                                            : [.gray.opacity(0.1), .gray.opacity(0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)

                            Image(systemName: levelIcon(level))
                                .font(.system(size: 18))
                                .foregroundStyle(
                                    securityManager.securityLevel == level
                                        ? LinearGradient(
                                            colors: [.purple, .blue],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                        : LinearGradient(
                                            colors: [.gray, .gray.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                )
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(level.rawValue.capitalized)
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text(level.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if securityManager.securityLevel == level {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.purple.opacity(0.15), .blue.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 28, height: 28)

                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.purple, .blue],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func levelIcon(_ level: SecurityLevel) -> String {
        switch level {
        case .low: return "shield"
        case .medium: return "shield.lefthalf.filled"
        case .high: return "shield.checkered"
        case .custom: return "shield.badge.plus"
        }
    }

    // MARK: - Biometric Auth Section

    private var biometricAuthSection: some View {
        Group {
            if biometricAuth.isBiometricAvailable {
                Toggle(isOn: Binding(
                    get: { biometricAuth.isEnabled },
                    set: { newValue in
                        Task {
                            await toggleBiometricAuth(newValue)
                        }
                    }
                )) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.2), .cyan.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)

                            Image(systemName: biometricAuth.biometricType == .faceID ? "faceid" : "touchid")
                                .font(.system(size: 18))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enable \(biometricAuth.biometricTypeString)")
                                .font(.body)
                                .fontWeight(.medium)

                            if let lastAuth = biometricAuth.lastAuthenticationDate {
                                Text("Last authenticated: \(lastAuth.formatted(.relative(presentation: .named)))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .tint(.purple)

                if biometricAuth.isEnabled {
                    Toggle(isOn: $biometricAuth.requireOnLaunch) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.purple.opacity(0.15), .blue.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)

                                Image(systemName: "lock.shield")
                                    .font(.system(size: 16))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.purple, .blue],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }

                            Text("Require on App Launch")
                                .font(.body)
                        }
                    }
                    .tint(.purple)
                    .disabled(!biometricAuth.isEnabled)
                }
            } else {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.orange.opacity(0.2), .yellow.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)

                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 18))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    Text("Biometric authentication not available")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Clipboard Security Section

    private var clipboardSecuritySection: some View {
        Group {
            Toggle(isOn: $clipboardSecurity.isEnabled) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple.opacity(0.2), .pink.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)

                        Image(systemName: "doc.on.clipboard.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    Text("Enable Clipboard Security")
                        .font(.body)
                        .fontWeight(.medium)
                }
            }
            .tint(.purple)

            if clipboardSecurity.isEnabled {
                Toggle(isOn: $clipboardSecurity.autoClearEnabled) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.15), .cyan.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 36, height: 36)

                            Image(systemName: "timer")
                                .font(.system(size: 16))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }

                        Text("Auto-Clear Clipboard")
                            .font(.body)
                    }
                }
                .tint(.purple)

                if clipboardSecurity.autoClearEnabled {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Clear After")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(Int(clipboardSecurity.autoClearDelay))s")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }

                        Slider(
                            value: $clipboardSecurity.autoClearDelay,
                            in: 10...120,
                            step: 10
                        )
                        .tint(.purple)
                    }
                }

                Toggle(isOn: $clipboardSecurity.blockSensitiveContent) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.orange.opacity(0.15), .yellow.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 36, height: 36)

                            Image(systemName: "eye.slash.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.orange, .yellow],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }

                        Text("Block Sensitive Content")
                            .font(.body)
                    }
                }
                .tint(.purple)

                Button {
                    clipboardSecurity.clearClipboard()
                    HapticManager.shared.notification(.success)
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.red.opacity(0.15), .orange.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 36, height: 36)

                            Image(systemName: "trash.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.red, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }

                        Text("Clear Clipboard Now")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }

    // MARK: - Advanced Security Section

    private var advancedSecuritySection: some View {
        Group {
            NavigationLink {
                circuitBreakerStatusView
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.2), .indigo.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)

                        Image(systemName: "network")
                            .font(.system(size: 18))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .indigo],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Network Security")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        let unhealthyCount = CircuitBreakerManager.shared.getUnhealthyServices().count
                        if unhealthyCount > 0 {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 6, height: 6)
                                Text("\(unhealthyCount) unhealthy service(s)")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                Text("All services healthy")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }

            Button {
                Task {
                    await securityManager.performSecurityCheck()
                    await loadSecurityStatus()
                }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.green.opacity(0.2), .mint.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)

                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 18))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green, .mint],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Run Security Check")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        if let lastCheck = securityManager.lastSecurityCheck {
                            Text("Last check: \(lastCheck.formatted(.relative(presentation: .named)))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if isLoading {
                        ProgressView()
                            .tint(.purple)
                    }
                }
            }
        }
    }

    // MARK: - Circuit Breaker Section (Debug)

    private var circuitBreakerSection: some View {
        Group {
            let statuses = CircuitBreakerManager.shared.getAllStatuses()

            if statuses.isEmpty {
                Text("No circuit breakers active")
                    .foregroundColor(.secondary)
            } else {
                ForEach(statuses, id: \.serviceName) { status in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(status.serviceName)
                                .font(.headline)

                            Spacer()

                            Text(status.healthDescription)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    status.isHealthy ? Color.green.opacity(0.2) : Color.orange.opacity(0.2)
                                )
                                .cornerRadius(8)
                        }

                        HStack {
                            Label("\(status.failureCount) failures", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            if let timeUntilRetry = status.timeUntilRetry, timeUntilRetry > 0 {
                                Text("Retry in \(Int(timeUntilRetry))s")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Recommendation Row

    private func recommendationRow(_ recommendation: SecurityRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    priorityColor(recommendation.priority).opacity(0.25),
                                    priorityColor(recommendation.priority).opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 5,
                                endRadius: 25
                            )
                        )
                        .frame(width: 50, height: 50)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    priorityColor(recommendation.priority).opacity(0.2),
                                    priorityColor(recommendation.priority).opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: priorityIcon(recommendation.priority))
                        .font(.system(size: 18))
                        .foregroundColor(priorityColor(recommendation.priority))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.title)
                        .font(.headline)

                    Text(recommendation.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Button {
                handleRecommendationAction(recommendation.action)
                HapticManager.shared.impact(.medium)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.subheadline)

                    Text("Fix Now")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: .purple.opacity(0.3), radius: 8, y: 4)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Circuit Breaker Status View

    private var circuitBreakerStatusView: some View {
        List {
            let statuses = CircuitBreakerManager.shared.getAllStatuses()

            if statuses.isEmpty {
                Section {
                    Text("No circuit breakers active")
                        .foregroundColor(.secondary)
                }
            } else {
                ForEach(statuses, id: \.serviceName) { status in
                    Section(status.serviceName) {
                        statusDetailRow("State", value: status.state.description)
                        statusDetailRow("Health", value: status.healthDescription)
                        statusDetailRow("Failures", value: "\(status.failureCount)")
                        statusDetailRow("Failure Rate", value: "\(Int(status.failureRate * 100))%")
                        statusDetailRow("Concurrent Requests", value: "\(status.currentConcurrency)")

                        if let timeUntilRetry = status.timeUntilRetry, timeUntilRetry > 0 {
                            statusDetailRow("Retry In", value: "\(Int(timeUntilRetry))s")
                        }

                        if let lastFailure = status.lastFailureTime {
                            statusDetailRow("Last Failure", value: lastFailure.formatted(.relative(presentation: .named)))
                        }
                    }
                }

                Section {
                    Button("Reset All Circuit Breakers") {
                        CircuitBreakerManager.shared.resetAll()
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Network Security")
    }

    private func statusDetailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }

    // MARK: - Helper Methods

    private func loadSecurityStatus() async {
        isLoading = true
        securityStatus = securityManager.getSecurityStatus()
        isLoading = false
    }

    private func toggleBiometricAuth(_ enabled: Bool) async {
        if enabled {
            do {
                _ = try await biometricAuth.enableBiometricAuth()
                HapticManager.shared.notification(.success)
            } catch {
                biometricError = error
                showingBiometricError = true
                HapticManager.shared.notification(.error)
            }
        } else {
            biometricAuth.disableBiometricAuth()
            HapticManager.shared.notification(.success)
        }

        await loadSecurityStatus()
    }

    private func getRecommendations() -> [SecurityRecommendation]? {
        return securityManager.getSecurityRecommendations()
    }

    private func handleRecommendationAction(_ action: SecurityRecommendation.Action) {
        Task {
            switch action {
            case .enableBiometric:
                await toggleBiometricAuth(true)

            case .enableClipboardSecurity:
                clipboardSecurity.isEnabled = true

            case .upgradeSecurityLevel:
                securityManager.setSecurityLevel(.medium)

            case .custom:
                break
            }

            await loadSecurityStatus()
        }
    }

    private func getHealthColor() -> Color {
        guard let status = securityStatus else { return .gray }

        if status.overallScore >= 80 {
            return .green
        } else if status.overallScore >= 60 {
            return .blue
        } else if status.overallScore >= 40 {
            return .orange
        } else {
            return .red
        }
    }

    private func priorityIcon(_ priority: SecurityRecommendation.Priority) -> String {
        switch priority {
        case .high: return "exclamationmark.triangle.fill"
        case .medium: return "exclamationmark.circle.fill"
        case .low: return "info.circle.fill"
        }
    }

    private func priorityColor(_ priority: SecurityRecommendation.Priority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
}

// MARK: - Circuit Breaker State Extension

extension CircuitBreakerState {
    var description: String {
        switch self {
        case .closed: return "Closed (Healthy)"
        case .open: return "Open (Unhealthy)"
        case .halfOpen: return "Half-Open (Testing)"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        SecuritySettingsView()
    }
}
