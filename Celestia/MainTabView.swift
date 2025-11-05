//
//  MainTabView.swift
//  Celestia
//
//  ELITE TAB BAR - Smooth Navigation Experience
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var matchService = MatchService.shared
    @StateObject private var messageService = MessageService.shared
    
    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var showTabAnimation = false
    @State private var unreadCount = 0
    @State private var newMatchesCount = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            TabView(selection: $selectedTab) {
                // Discover
                DiscoverView()
                    .tag(0)
                
                // Matches
                MatchesView()
                    .tag(1)
                
                // Messages
                MessagesView()
                    .tag(2)
                
                // Profile
                ProfileView()
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(.keyboard)
            
            // Custom Tab Bar
            customTabBar
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: selectedTab) { oldValue, newValue in
            previousTab = oldValue
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showTabAnimation = true
            }
            HapticManager.shared.selection()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showTabAnimation = false
            }
        }
        .task {
            await loadBadgeCounts()
        }
    }
    
    // MARK: - Custom Tab Bar
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
            // Discover
            TabBarButton(
                icon: "flame.fill",
                title: "Discover",
                isSelected: selectedTab == 0,
                badgeCount: 0
            ) {
                selectedTab = 0
            }
            
            // Matches
            TabBarButton(
                icon: "heart.fill",
                title: "Matches",
                isSelected: selectedTab == 1,
                badgeCount: newMatchesCount
            ) {
                selectedTab = 1
            }
            
            // Messages
            TabBarButton(
                icon: "message.fill",
                title: "Messages",
                isSelected: selectedTab == 2,
                badgeCount: unreadCount
            ) {
                selectedTab = 2
            }
            
            // Profile
            TabBarButton(
                icon: "person.fill",
                title: "Profile",
                isSelected: selectedTab == 3,
                badgeCount: 0
            ) {
                selectedTab = 3
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(
            ZStack {
                // Blur effect
                Color.white
                
                // Gradient overlay
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.95),
                        Color.white.opacity(0.98)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea(edges: .bottom)
        )
        .shadow(color: .black.opacity(0.08), radius: 15, y: -5)
    }
    
    // MARK: - Helper Functions
    
    private func loadBadgeCounts() async {
        guard let userId = authService.currentUser?.id else { return }
        
        // Load unread messages count
        unreadCount = await messageService.getUnreadMessageCount(userId: userId)
        
        // Load new matches count
        do {
            try await matchService.fetchMatches(userId: userId)
            newMatchesCount = matchService.matches.filter { $0.lastMessage == nil }.count
        } catch {
            print("Error loading badge counts: \(error)")
        }
        
        // Update periodically
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            Task {
                unreadCount = await messageService.getUnreadMessageCount(userId: userId)
                do {
                    try await matchService.fetchMatches(userId: userId)
                    newMatchesCount = matchService.matches.filter { $0.lastMessage == nil }.count
                } catch {
                    print("Error updating badge counts: \(error)")
                }
            }
        }
    }
}

// MARK: - Tab Bar Button

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let badgeCount: Int
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundStyle(
                            isSelected ?
                            LinearGradient(
                                colors: [Color.purple, Color.pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(colors: [Color.gray.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(height: 28)
                        .scaleEffect(isPressed ? 0.85 : 1.0)
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                    
                    // Badge
                    if badgeCount > 0 {
                        Text("\(badgeCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.red, Color.pink],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .offset(x: 12, y: -6)
                            .scaleEffect(isSelected ? 1.1 : 1.0)
                    }
                }
                
                // Title
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .purple : .gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isSelected ?
                        LinearGradient(
                            colors: [Color.purple.opacity(0.1), Color.pink.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Animated Tab Indicator

struct AnimatedTabIndicator: View {
    let selectedTab: Int
    let totalTabs: Int
    
    var body: some View {
        GeometryReader { geometry in
            let tabWidth = geometry.size.width / CGFloat(totalTabs)
            
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [Color.purple, Color.pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: tabWidth * 0.5, height: 3)
                .offset(x: tabWidth * CGFloat(selectedTab) + tabWidth * 0.25)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)
        }
        .frame(height: 3)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService.shared)
}
