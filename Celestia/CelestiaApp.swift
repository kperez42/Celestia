//
//  CelestiaApp.swift
//  Celestia
//
//  Created by Kevin Perez on 10/29/25.
//

import SwiftUI
import Firebase

@main
struct CelestiaApp: App {
    @StateObject private var authService = AuthService.shared
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
        }
    }
}
