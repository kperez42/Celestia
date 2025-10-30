//
//  MainTabView.swift
//  Celestia
//
//  Main tab navigation for authenticated users
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var authService: AuthService
    @StateObject private var matchService = MatchService.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: selectedTab == 0 ? "flame.fill" : "flame")
                }
                .tag(0)
            
            MatchesView()
                .tabItem {
                    Label("Matches", systemImage: selectedTab == 1 ? "heart.fill" : "heart")
                }
                .badge(matchBadgeCount)
                .tag(1)
            
            // ADDED: Messages tab
            MessagesView()
                .tabItem {
                    Label("Messages", systemImage: selectedTab == 2 ? "message.fill" : "message")
                }
                .badge(messagesBadgeCount)
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: selectedTab == 3 ? "person.fill" : "person")
                }
                .tag(3)
        }
        .accentColor(Color.purple)
        .onAppear {
            configureTabBarAppearance()
            
            // Start listening to matches for badge count
            if let userId = authService.currentUser?.id {
                matchService.listenToMatches(userId: userId)
            }
        }
    }
    
    // Badge count for Matches tab (new matches without any messages)
    private var matchBadgeCount: Int {
        let newMatches = matchService.matches.filter { $0.lastMessageTimestamp == nil }.count
        return newMatches > 0 ? newMatches : 0
    }
    
    // Badge count for Messages tab (unread messages)
    private var messagesBadgeCount: Int {
        let totalUnread = matchService.matches.reduce(0) { total, match in
            guard let userId = authService.currentUser?.id else { return total }
            return total + (match.unreadCount[userId] ?? 0)
        }
        return totalUnread > 0 ? totalUnread : 0
    }
    
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        // Unselected item color
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.gray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray]
        
        // Selected item color (purple)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemPurple
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.systemPurple]
        
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService.shared)
}
