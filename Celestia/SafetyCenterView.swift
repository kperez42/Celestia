//
//  SafetyCenterView.swift
//  Celestia
//
//  Safety Center - Hub for all safety features and settings
//

import SwiftUI

struct SafetyCenterView: View {
    @StateObject private var safetyManager = SafetyManager.shared
    @StateObject private var emergencyContactManager = EmergencyContactManager.shared
    @StateObject private var verificationService = VerificationService.shared

    var body: some View {
        List {
            // Safety Score Section
            Section {
                VStack(spacing: 12) {
                    Text("Your Safety Score")
                        .font(.headline)

                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 12)

                        Circle()
                            .trim(from: 0, to: CGFloat(safetyManager.safetyScore) / 100)
                            .stroke(
                                LinearGradient(
                                    colors: [.green, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        VStack {
                            Text("\(safetyManager.safetyScore)")
                                .font(.system(size: 48, weight: .bold))
                            Text("/ 100")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(height: 150)

                    Text("Improve your safety score by completing verifications and adding emergency contacts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical)
            }

            // Verification Section
            Section("Verification") {
                NavigationLink {
                    Text("Photo Verification")
                } label: {
                    HStack {
                        Image(systemName: verificationService.photoVerified ? "checkmark.circle.fill" : "camera.circle")
                            .foregroundColor(verificationService.photoVerified ? .green : .gray)
                        Text("Photo Verification")
                        Spacer()
                        if verificationService.photoVerified {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        }
                    }
                }

                NavigationLink {
                    Text("ID Verification")
                } label: {
                    HStack {
                        Image(systemName: verificationService.idVerified ? "checkmark.shield.fill" : "person.text.rectangle")
                            .foregroundColor(verificationService.idVerified ? .green : .gray)
                        Text("ID Verification")
                        Spacer()
                        if verificationService.idVerified {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        }
                    }
                }

                NavigationLink {
                    Text("Background Check")
                } label: {
                    HStack {
                        Image(systemName: verificationService.backgroundCheckCompleted ? "checkmark.seal.fill" : "doc.text.magnifyingglass")
                            .foregroundColor(verificationService.backgroundCheckCompleted ? .green : .gray)
                        Text("Background Check")
                        Spacer()
                        if verificationService.backgroundCheckCompleted {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        }
                    }
                }
            }

            // Emergency Contacts Section
            Section("Emergency Contacts") {
                if emergencyContactManager.contacts.isEmpty {
                    Text("No emergency contacts added")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(emergencyContactManager.contacts) { contact in
                        HStack {
                            Image(systemName: "person.fill.badge.plus")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text(contact.name)
                                    .font(.body)
                                Text(contact.phoneNumber)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                NavigationLink {
                    Text("Manage Emergency Contacts")
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add Emergency Contact")
                    }
                }
            }

            // Safety Features Section
            Section("Safety Features") {
                NavigationLink {
                    Text("Date Check-in")
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("Date Check-in")
                    }
                }

                NavigationLink {
                    Text("Safety Tips")
                } label: {
                    HStack {
                        Image(systemName: "lightbulb")
                        Text("Safety Tips")
                    }
                }

                NavigationLink {
                    Text("Report & Block")
                } label: {
                    HStack {
                        Image(systemName: "hand.raised")
                        Text("Report & Block")
                    }
                }
            }

            // Emergency Button
            Section {
                Button(action: {
                    Task {
                        do {
                            try await safetyManager.triggerEmergency()
                        } catch {
                            Logger.shared.error("Error triggering emergency", category: .general, error: error)
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Emergency Alert")
                        Spacer()
                    }
                    .foregroundColor(.red)
                }
            } footer: {
                Text("Tap to immediately alert your emergency contacts")
                    .font(.caption)
            }
        }
        .navigationTitle("Safety Center")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct SafetyCenterView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SafetyCenterView()
        }
    }
}
