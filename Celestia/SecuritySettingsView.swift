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
    }

    // MARK: - Security Overview Card

    private var securityOverviewCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: securityStatus?.isHealthy ?? false ? "shield.checkered" : "shield.slash")
                    .font(.title)
                    .foregroundColor(securityStatus?.isHealthy ?? false ? .green : .orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Security Score")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(Int(securityStatus?.overallScore ?? 0))%")
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(securityStatus?.healthDescription ?? "Unknown")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(getHealthColor())
                }
            }

            // Security Features Status
            if let status = securityStatus {
                VStack(spacing: 8) {
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
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 8)
    }

    private func securityFeatureRow(icon: String, title: String, isEnabled: Bool) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)

            Spacer()

            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(isEnabled ? .green : .gray)
        }
    }

    // MARK: - Security Level Picker

    private var securityLevelPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach([SecurityLevel.low, .medium, .high], id: \.rawValue) { level in
                Button {
                    withAnimation {
                        securityManager.setSecurityLevel(level)
                    }
                    Task {
                        await loadSecurityStatus()
                    }
                } label: {
                    HStack {
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
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
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
                    HStack {
                        Image(systemName: biometricAuth.biometricType == .faceID ? "faceid" : "touchid")
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable \(biometricAuth.biometricTypeString)")
                                .font(.body)

                            if let lastAuth = biometricAuth.lastAuthenticationDate {
                                Text("Last authenticated: \(lastAuth.formatted(.relative(presentation: .named)))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if biometricAuth.isEnabled {
                    Toggle("Require on App Launch", isOn: $biometricAuth.requireOnLaunch)
                        .disabled(!biometricAuth.isEnabled)
                }
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)

                    Text("Biometric authentication not available")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Clipboard Security Section

    private var clipboardSecuritySection: some View {
        Group {
            Toggle("Enable Clipboard Security", isOn: $clipboardSecurity.isEnabled)

            if clipboardSecurity.isEnabled {
                Toggle("Auto-Clear Clipboard", isOn: $clipboardSecurity.autoClearEnabled)

                if clipboardSecurity.autoClearEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Clear After")
                            Spacer()
                            Text("\(Int(clipboardSecurity.autoClearDelay))s")
                                .foregroundColor(.secondary)
                        }

                        Slider(
                            value: $clipboardSecurity.autoClearDelay,
                            in: 10...120,
                            step: 10
                        )
                    }
                }

                Toggle("Block Sensitive Content", isOn: $clipboardSecurity.blockSensitiveContent)

                Button("Clear Clipboard Now") {
                    clipboardSecurity.clearClipboard()
                    HapticManager.shared.notification(.success)
                }
                .foregroundColor(.red)
            }
        }
    }

    // MARK: - Advanced Security Section

    private var advancedSecuritySection: some View {
        Group {
            NavigationLink {
                circuitBreakerStatusView
            } label: {
                HStack {
                    Image(systemName: "network")
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Network Security")
                            .font(.body)

                        let unhealthyCount = CircuitBreakerManager.shared.getUnhealthyServices().count
                        if unhealthyCount > 0 {
                            Text("\(unhealthyCount) unhealthy service(s)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Text("All services healthy")
                                .font(.caption)
                                .foregroundColor(.green)
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
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Run Security Check")
                            .font(.body)

                        if let lastCheck = securityManager.lastSecurityCheck {
                            Text("Last check: \(lastCheck.formatted(.relative(presentation: .named)))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if isLoading {
                        ProgressView()
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: priorityIcon(recommendation.priority))
                    .foregroundColor(priorityColor(recommendation.priority))

                VStack(alignment: .leading, spacing: 2) {
                    Text(recommendation.title)
                        .font(.headline)

                    Text(recommendation.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Button {
                handleRecommendationAction(recommendation.action)
            } label: {
                Text("Fix Now")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
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
