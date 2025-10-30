//
//  ContentView.swift
//  Celestia
//
//  Created by Kevin Perez on 10/29/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isAuthenticated = false
    
    var body: some View {
        Group {
            if isAuthenticated {
                MainTabView()
                    .transition(.opacity)
            } else {
                WelcomeView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isAuthenticated)
        .onChange(of: authService.userSession?.uid) { newValue in
            print("🔍 ContentView: userSession changed to: \(newValue ?? "nil")")
            isAuthenticated = (newValue != nil)
        }
        .onAppear {
            print("🔍 ContentView: onAppear - userSession: \(authService.userSession?.uid ?? "nil")")
            isAuthenticated = (authService.userSession != nil)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService.shared)
}
