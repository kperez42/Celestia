//
//  ProfileView.swift
//  Celestia
//
//  User's own profile and settings
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if let user = authService.currentUser {
                    VStack(spacing: 20) {
                        // Profile Header Card
                        VStack(spacing: 0) {
                            // Background gradient
                            LinearGradient(
                                colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(height: 120)
                            .overlay {
                                // Profile image
                                VStack {
                                    Spacer()
                                    
                                    if !user.profileImageURL.isEmpty {
                                        AsyncImage(url: URL(string: user.profileImageURL)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Circle()
                                                .fill(Color.white)
                                        }
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                        .overlay {
                                            Circle()
                                                .stroke(Color.white, lineWidth: 4)
                                        }
                                        .offset(y: 60)
                                    } else {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.6)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 120, height: 120)
                                            .overlay {
                                                Image(systemName: "person.fill")
                                                    .font(.system(size: 50))
                                                    .foregroundColor(.white)
                                            }
                                            .overlay {
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 4)
                                            }
                                            .offset(y: 60)
                                    }
                                }
                            }
                            
                            // User info
                            VStack(spacing: 8) {
                                Spacer()
                                    .frame(height: 70)
                                
                                HStack(spacing: 6) {
                                    Text(user.fullName)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    
                                    Text("\(user.age)")
                                        .font(.title3)
                                        .foregroundColor(.gray)
                                    
                                    if user.isVerified {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [Color.purple, Color.blue],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                    }
                                }
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color.purple, Color.blue],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                    Text("\(user.location), \(user.country)")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                if user.isPremium {
                                    HStack(spacing: 6) {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                        Text("Premium Member")
                                            .font(.caption)
                                            .foregroundColor(.yellow)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.yellow.opacity(0.1))
                                    .cornerRadius(15)
                                }
                            }
                            .padding()
                            .padding(.bottom, 10)
                        }
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.05), radius: 10)
                        .padding(.horizontal)
                        
                        // Edit Profile Button
                        Button {
                            showingEditProfile = true
                        } label: {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Edit Profile")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color.purple, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(15)
                        }
                        .padding(.horizontal)
                        
                        // About section
                        if !user.bio.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("About Me", systemImage: "text.alignleft")
                                    .font(.headline)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.purple, Color.blue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                
                                Text(user.bio)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(15)
                            .shadow(color: .black.opacity(0.05), radius: 5)
                            .padding(.horizontal)
                        }
                        
                        // Languages
                        if !user.languages.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Languages", systemImage: "globe")
                                    .font(.headline)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.purple, Color.blue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(user.languages, id: \.self) { language in
                                        Text(language)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                LinearGradient(
                                                    colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [Color.purple, Color.blue],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .cornerRadius(15)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(15)
                            .shadow(color: .black.opacity(0.05), radius: 5)
                            .padding(.horizontal)
                        }
                        
                        // Interests
                        if !user.interests.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Interests", systemImage: "star.fill")
                                    .font(.headline)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.purple, Color.blue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(user.interests, id: \.self) { interest in
                                        Text(interest)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                LinearGradient(
                                                    colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [Color.purple, Color.blue],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .cornerRadius(15)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(15)
                            .shadow(color: .black.opacity(0.05), radius: 5)
                            .padding(.horizontal)
                        }
                        
                        // Preferences Card
                        VStack(spacing: 15) {
                            HStack {
                                Label("Preferences", systemImage: "slider.horizontal.3")
                                    .font(.headline)
                                Spacer()
                            }
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.purple, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            
                            PreferenceRow(icon: "heart.fill", title: "Looking for", value: user.lookingFor)
                            PreferenceRow(icon: "calendar", title: "Age Range", value: "\(user.ageRangeMin)-\(user.ageRangeMax)")
                            PreferenceRow(icon: "location.circle", title: "Max Distance", value: "\(user.maxDistance) km")
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(15)
                        .shadow(color: .black.opacity(0.05), radius: 5)
                        .padding(.horizontal)
                        
                        // Premium upgrade
                        if !user.isPremium {
                            Button {
                                // TODO: Show premium upgrade
                            } label: {
                                HStack(spacing: 15) {
                                    Image(systemName: "star.fill")
                                        .font(.title2)
                                        .foregroundColor(.yellow)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Upgrade to Premium")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text("Unlock unlimited features")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [.yellow.opacity(0.1), .orange.opacity(0.1)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(15)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Settings & Account
                        VStack(spacing: 12) {
                            SettingsButton(icon: "gearshape.fill", title: "Settings", color: .gray) {
                                showingSettings = true
                            }
                            
                            SettingsButton(icon: "questionmark.circle.fill", title: "Help & Support", color: .blue) {
                                // TODO: Help & Support
                            }
                            
                            SettingsButton(icon: "arrow.right.square.fill", title: "Sign Out", color: .red) {
                                authService.signOut()
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                    .padding(.top)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingEditProfile) {
                ProfileEditView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
}

struct PreferenceRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
}

struct SettingsButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 3)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AuthService.shared)
    }
}
