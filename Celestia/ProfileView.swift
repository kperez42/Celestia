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
                                                Text(user.fullName.prefix(1).uppercased())
                                                    .font(.system(size: 50, weight: .bold))
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
                        
                        // Languages section
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
                                
                                FlowLayout2(spacing: 8) {
                                    ForEach(user.languages, id: \.self) { language in
                                        Text(language)
                                            .font(.subheadline)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.purple.opacity(0.1))
                                            .foregroundColor(.purple)
                                            .cornerRadius(20)
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
                        
                        // Interests section
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
                                
                                FlowLayout2(spacing: 8) {
                                    ForEach(user.interests, id: \.self) { interest in
                                        Text(interest)
                                            .font(.subheadline)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.blue.opacity(0.1))
                                            .foregroundColor(.blue)
                                            .cornerRadius(20)
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
                        
                        // Preferences section
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Discovery Preferences", systemImage: "slider.horizontal.3")
                                .font(.headline)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.purple, Color.blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            VStack(spacing: 12) {
                                PreferenceRow(icon: "heart.fill", title: "Looking for", value: user.lookingFor)
                                Divider()
                                PreferenceRow(icon: "person.2.fill", title: "Age range", value: "\(user.ageRangeMin)-\(user.ageRangeMax)")
                                Divider()
                                PreferenceRow(icon: "location.fill", title: "Max distance", value: "\(user.maxDistance) km")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(15)
                        .shadow(color: .black.opacity(0.05), radius: 5)
                        .padding(.horizontal)
                        
                        // Profile Stats
                        HStack(spacing: 20) {
                            StatBox(title: "Likes", value: "\(user.likesReceived)", icon: "heart.fill", color: .pink)
                            StatBox(title: "Matches", value: "\(user.matchCount)", icon: "heart.circle.fill", color: .purple)
                            StatBox(title: "Views", value: "\(user.profileViews)", icon: "eye.fill", color: .blue)
                        }
                        .padding(.horizontal)
                        
                        // Premium upgrade (if not premium)
                        if !user.isPremium {
                            Button {
                                // TODO: Premium upgrade flow
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
                } else {
                    // FIXED: Added loading/error state when user is nil
                    VStack(spacing: 20) {
                        if authService.isLoading {
                            ProgressView()
                                .scaleEffect(1.5)
                            
                            Text("Loading profile...")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.top, 10)
                        } else {
                            Image(systemName: "person.crop.circle.badge.exclamationmark")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("Unable to load profile")
                                .font(.headline)
                            
                            Text("Please try signing out and back in")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            
                            Button {
                                Task {
                                    await authService.fetchUser()
                                }
                            } label: {
                                Text("Retry")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 30)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.purple, Color.blue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(10)
                            }
                            .padding(.top, 10)
                            
                            Button {
                                authService.signOut()
                            } label: {
                                Text("Sign Out")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                            .padding(.top, 5)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .task {
                // Attempt to load user if not already loaded
                if authService.currentUser == nil && !authService.isLoading {
                    await authService.fetchUser()
                }
            }
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.05), radius: 5)
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

// Simple FlowLayout for tags
struct FlowLayout2: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                     y: bounds.minY + result.frames[index].minY),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AuthService.shared)
    }
}
