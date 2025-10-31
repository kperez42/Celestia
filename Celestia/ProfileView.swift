//
//  ProfileView.swift
//  Celestia
//
//  Enhanced user profile with modern design
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    @State private var selectedPhoto = 0
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if let user = authService.currentUser {
                    VStack(spacing: 0) {
                        // Hero Header
                        heroHeader(user: user)
                        
                        // Main Content
                        VStack(spacing: 20) {
                            // Quick Stats
                            quickStats(user: user)
                                .padding(.top, 20)
                            
                            // Edit Profile Button
                            editProfileButton
                            
                            // About Section
                            if !user.bio.isEmpty {
                                aboutSection(bio: user.bio)
                            }
                            
                            // Details Grid
                            detailsGrid(user: user)
                            
                            // Languages & Interests
                            if !user.languages.isEmpty {
                                languagesSection(languages: user.languages)
                            }
                            
                            if !user.interests.isEmpty {
                                interestsSection(interests: user.interests)
                            }
                            
                            // Preferences Card
                            preferencesCard(user: user)
                            
                            // Premium Card
                            if !user.isPremium {
                                premiumCard
                            }
                            
                            // Action Buttons
                            actionButtons
                        }
                        .padding(.top, -30)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
    
    // MARK: - Hero Header
    
    private func heroHeader(user: User) -> some View {
        ZStack(alignment: .bottom) {
            // Background gradient
            LinearGradient(
                colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 340)
            .overlay {
                // Pattern overlay
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .offset(x: -100, y: -80)
                
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 150, height: 150)
                    .offset(x: 120, y: -50)
            }
            
            // Profile content
            VStack(spacing: 16) {
                Spacer()
                
                // Profile image
                profileImage(user: user)
                
                // Name and info
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Text(user.fullName)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                        
                        if user.isPremium {
                            Image(systemName: "star.fill")
                                .font(.subheadline)
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.subheadline)
                        Text("\(user.location), \(user.country)")
                            .font(.subheadline)
                    }
                    .foregroundColor(.white.opacity(0.9))
                }
                .padding(.bottom, 30)
            }
            .frame(height: 340)
            
            // Settings button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
            }
            .frame(height: 340)
        }
    }
    
    private func profileImage(user: User) -> some View {
        Group {
            if !user.profileImageURL.isEmpty, let url = URL(string: user.profileImageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholderProfileImage(initial: user.fullName.prefix(1))
                    }
                }
            } else {
                placeholderProfileImage(initial: user.fullName.prefix(1))
            }
        }
        .frame(width: 130, height: 130)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color.white, lineWidth: 4)
        }
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
    }
    
    private func placeholderProfileImage(initial: String.SubSequence) -> some View {
        ZStack {
            Circle()
                .fill(Color.white)
            
            Text(String(initial))
                .font(.system(size: 50, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
    // MARK: - Quick Stats
    
    private func quickStats(user: User) -> some View {
        HStack(spacing: 0) {
            statItem(title: "Matches", value: "\(user.matchCount)", icon: "heart.fill")
            
            Divider()
                .frame(height: 40)
            
            statItem(title: "Likes", value: "\(user.likesReceived)", icon: "star.fill")
            
            Divider()
                .frame(height: 40)
            
            statItem(title: "Views", value: "\(user.profileViews)", icon: "eye.fill")
        }
        .padding(.vertical, 20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        .padding(.horizontal)
    }
    
    private func statItem(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Edit Profile Button
    
    private var editProfileButton: some View {
        Button {
            showingEditProfile = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "pencil")
                    .font(.headline)
                
                Text("Edit Profile")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.purple, Color.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: Color.purple.opacity(0.3), radius: 8, y: 4)
        }
        .padding(.horizontal)
    }
    
    // MARK: - About Section
    
    private func aboutSection(bio: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "quote.bubble.fill")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("About Me")
                    .font(.headline)
            }
            
            Text(bio)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5)
        .padding(.horizontal)
    }
    
    // MARK: - Details Grid
    
    private func detailsGrid(user: User) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            detailCard(icon: "calendar", title: "Age", value: "\(user.age)")
            detailCard(icon: "person.fill", title: "Gender", value: user.gender)
            detailCard(icon: "heart.circle.fill", title: "Looking For", value: user.lookingFor)
            detailCard(icon: "envelope.fill", title: "Email", value: user.email)
        }
        .padding(.horizontal)
    }
    
    private func detailCard(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.7), Color.blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Spacer()
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
    
    // MARK: - Languages Section
    
    private func languagesSection(languages: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "globe")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Languages I Speak")
                    .font(.headline)
            }
            
            FlowLayout3(spacing: 10) {
                ForEach(languages, id: \.self) { language in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.purple)
                        
                        Text(language)
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5)
        .padding(.horizontal)
    }
    
    // MARK: - Interests Section
    
    private func interestsSection(interests: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("My Interests")
                    .font(.headline)
            }
            
            FlowLayout3(spacing: 10) {
                ForEach(interests, id: \.self) { interest in
                    Text(interest)
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [Color.pink.opacity(0.1), Color.orange.opacity(0.1)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.pink)
                        .cornerRadius(20)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5)
        .padding(.horizontal)
    }
    
    // MARK: - Preferences Card
    
    private func preferencesCard(user: User) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("My Preferences")
                    .font(.headline)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                preferenceRow(icon: "calendar", title: "Age Range", value: "\(user.ageRangeMin) - \(user.ageRangeMax)")
                preferenceRow(icon: "location.circle", title: "Max Distance", value: "\(user.maxDistance) km")
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5)
        .padding(.horizontal)
    }
    
    private func preferenceRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.purple)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // MARK: - Premium Card
    
    private var premiumCard: some View {
        Button {
            // TODO: Show premium upgrade
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow.opacity(0.2), Color.orange.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "crown.fill")
                        .font(.title2)
                        .foregroundColor(.yellow)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Upgrade to Premium")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Unlock unlimited features & boost visibility")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color.yellow.opacity(0.1), Color.orange.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.5), Color.orange.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            actionButton(icon: "questionmark.circle.fill", title: "Help & Support", color: .blue) {
                // TODO: Help & Support
            }
            
            actionButton(icon: "arrow.right.square.fill", title: "Sign Out", color: .red) {
                authService.signOut()
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 30)
    }
    
    private func actionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
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
            .padding(16)
            .background(Color.white)
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.05), radius: 5)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout3: Layout {
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
            subview.place(
                at: CGPoint(
                    x: bounds.minX + result.frames[index].minX,
                    y: bounds.minY + result.frames[index].minY
                ),
                proposal: .unspecified
            )
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
