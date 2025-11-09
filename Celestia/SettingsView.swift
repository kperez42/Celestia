//
//  SettingsView.swift
//  Celestia
//
//  Created by Kevin Perez on 10/29/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(authService.currentUser?.email ?? "")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("Account Type")
                        Spacer()
                        Text(authService.currentUser?.isPremium == true ? "Premium" : "Free")
                            .foregroundColor(.gray)
                    }
                }
                
                Section("Preferences") {
                    NavigationLink {
                        FilterView()
                    } label: {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                            Text("Discovery Filters")
                        }
                    }
                }

                Section("Notifications") {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                            Text("Notification Preferences")
                        }
                    }
                }

                Section("Safety & Privacy") {
                    NavigationLink {
                        PrivacySettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "hand.raised.shield")
                            Text("Privacy Controls")
                        }
                    }

                    NavigationLink {
                        SafetyCenterView()
                    } label: {
                        HStack {
                            Image(systemName: "shield.checkered")
                            Text("Safety Center")
                        }
                    }

                    NavigationLink {
                        BlockedUsersView()
                    } label: {
                        HStack {
                            Image(systemName: "hand.raised.slash")
                            Text("Blocked Users")
                        }
                    }
                }
                
                Section("Support") {
                    Link(destination: URL(string: "mailto:support@celestia.app")!) {
                        HStack {
                            Image(systemName: "envelope")
                            Text("Contact Support")
                        }
                    }
                    
                    Link(destination: URL(string: "https://celestia.app/privacy")!) {
                        HStack {
                            Image(systemName: "lock.shield")
                            Text("Privacy Policy")
                        }
                    }
                    
                    Link(destination: URL(string: "https://celestia.app/terms")!) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("Terms of Service")
                        }
                    }
                }
                
                Section("Danger Zone") {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Account")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        do {
                            try await authService.deleteAccount()
                        } catch {
                            print("Error deleting account: \(error)")
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone.")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthService.shared)
}
