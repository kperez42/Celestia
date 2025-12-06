//
//  SendInterestView.swift
//  Celestia
//
//  Created by Kevin Perez on 10/29/25.
//

import SwiftUI

struct SendInterestView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @StateObject private var interestService = InterestService.shared
    
    let user: User
    @Binding var showSuccess: Bool
    
    @State private var message = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // User info - PERFORMANCE: Use CachedAsyncImage
                VStack(spacing: 10) {
                    if let imageURL = URL(string: user.profileImageURL), !user.profileImageURL.isEmpty {
                        CachedAsyncImage(url: imageURL) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 100, height: 100)
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
                            .frame(width: 100, height: 100)
                            .overlay {
                                Text(user.fullName.prefix(1))
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.white)
                            }
                    }
                    
                    Text("Send interest to \(user.fullName)?")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 30)
                
                // Optional message
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add a message (optional)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    TextEditor(text: $message)
                        .frame(height: 120)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Send button
                Button {
                    Task {
                        isLoading = true
                        // BUGFIX: Use effectiveId for reliable user identification
                        guard let currentUserId = authService.currentUser?.effectiveId else { return }
                        guard let userId = user.effectiveId else { return }
                        
                        do {
                            try await interestService.sendInterest(
                                fromUserId: currentUserId,
                                toUserId: userId,
                                message: message.isEmpty ? nil : message
                            )
                            isLoading = false
                            dismiss()
                            showSuccess = true
                        } catch {
                            isLoading = false
                            Logger.shared.error("Error sending interest", category: .matching, error: error)
                        }
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(15)
                    } else {
                        Text("Send Interest")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(15)
                    }
                }
                .disabled(isLoading)
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .navigationTitle("Send Interest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
