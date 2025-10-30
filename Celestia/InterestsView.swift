//
//  InterestsView.swift
//  Celestia
//
//  Created by Kevin Perez on 10/29/25.
//

import SwiftUI

struct InterestsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var interestService = InterestService.shared
    @StateObject private var userService = UserService.shared
    
    @State private var interestUsers: [String: User] = [:]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if interestService.isLoading {
                    ProgressView()
                        .padding(.top, 100)
                } else if interestService.receivedInterests.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "heart.slash.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("No interests yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Keep exploring to find your match!")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 100)
                } else {
                    LazyVStack(spacing: 15) {
                        ForEach(interestService.receivedInterests) { interest in
                            if let user = interestUsers[interest.fromUserId] {
                                InterestCardView(interest: interest, user: user)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Interests")
            .task {
                guard let currentUserId = authService.currentUser?.id else { return }
                
                do {
                    try await interestService.fetchReceivedInterests(userId: currentUserId)
                    
                    // Fetch user details for each interest
                    for interest in interestService.receivedInterests {
                        if let user = try await userService.fetchUser(userId: interest.fromUserId) {
                            interestUsers[interest.fromUserId] = user
                        }
                    }
                } catch {
                    print("Error fetching interests: \(error)")
                }
            }
        }
    }
}

struct InterestCardView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var interestService = InterestService.shared
    
    let interest: Interest
    let user: User
    
    @State private var isProcessing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 15) {
                // Profile image
                if let imageURL = URL(string: user.profileImageURL), !user.profileImageURL.isEmpty {
                    AsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.6), .pink.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .overlay {
                            Text(user.fullName.prefix(1))
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(.white)
                        }
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(user.fullName)
                        .font(.headline)
                    
                    Text("\(user.age) • \(user.location)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text(timeAgo(from: interest.timestamp))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            // Message if provided
            if let message = interest.message, !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
            
            // Action buttons
            HStack(spacing: 15) {
                Button {
                    Task {
                        isProcessing = true
                        guard let interestId = interest.id else { return }
                        
                        do {
                            try await interestService.rejectInterest(interestId: interestId)
                            // Remove from list
                            if let currentUserId = authService.currentUser?.id {
                                try await interestService.fetchReceivedInterests(userId: currentUserId)
                            }
                        } catch {
                            print("Error rejecting interest: \(error)")
                        }
                        isProcessing = false
                    }
                } label: {
                    Text("Pass")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .frame(height: 45)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                .disabled(isProcessing)
                
                Button {
                    Task {
                        isProcessing = true
                        guard let interestId = interest.id else { return }
                        
                        do {
                            try await interestService.acceptInterest(
                                interestId: interestId,
                                fromUserId: interest.fromUserId,
                                toUserId: interest.toUserId
                            )
                            // Remove from list
                            if let currentUserId = authService.currentUser?.id {
                                try await interestService.fetchReceivedInterests(userId: currentUserId)
                            }
                        } catch {
                            print("Error accepting interest: \(error)")
                        }
                        isProcessing = false
                    }
                } label: {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 45)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(10)
                    } else {
                        Text("Accept")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 45)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(10)
                    }
                }
                .disabled(isProcessing)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

#Preview {
    NavigationStack {
        InterestsView()
            .environmentObject(AuthService.shared)
    }
}
