//
//  SearchResultsView.swift
//  Celestia
//
//  Search results display with profile cards
//

import SwiftUI

struct SearchResultsView: View {

    @StateObject private var searchManager = SearchManager.shared
    @State private var showingFilters = false

    var body: some View {
        NavigationView {
            ZStack {
                if searchManager.isSearching {
                    loadingView
                } else if searchManager.searchResults.isEmpty {
                    emptyStateView
                } else {
                    resultsListView
                }
            }
            .navigationTitle("Search Results")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingFilters = true }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.title3)

                            if searchManager.currentFilter.activeFilterCount > 0 {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                SearchFilterView(filter: searchManager.currentFilter)
            }
        }
        .onAppear {
            if searchManager.searchResults.isEmpty {
                Task {
                    await searchManager.search()
                }
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Searching for matches...")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding()

                // Show skeleton grid of search results
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(0..<6, id: \.self) { _ in
                        MatchCardSkeleton()
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            VStack(spacing: 12) {
                Text("No matches found")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Try adjusting your filters to see more results")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { showingFilters = true }) {
                Text("Adjust Filters")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding()
    }

    // MARK: - Results List

    private var resultsListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Results count
                resultsHeader

                // Profile cards
                ForEach(searchManager.searchResults) { profile in
                    ProfileCard(profile: profile)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
            }
        }
    }

    private var resultsHeader: some View {
        HStack {
            Text("\(searchManager.totalResultsCount) matches")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            if searchManager.currentFilter.activeFilterCount > 0 {
                Button(action: {
                    searchManager.resetFilter()
                    Task {
                        await searchManager.search()
                    }
                }) {
                    Text("Clear Filters")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - Profile Card

struct ProfileCard: View {

    let profile: UserProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image
            profileImage

            // Info
            VStack(alignment: .leading, spacing: 8) {
                // Name and age
                HStack {
                    HStack(spacing: 4) {
                        Text(profile.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(String(profile.age))
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }

                    if profile.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                    }

                    Spacer()
                }

                // Distance and location
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text(profile.distanceString)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Bio
                Text(profile.bio)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                // Tags
                tags
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    private var profileImage: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 300)
            .overlay(
                // Placeholder for actual image
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.7))
            )
            .cornerRadius(16, corners: [.topLeft, .topRight])
    }

    private var tags: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let height = profile.heightFormatted {
                    SearchTagView(text: height, icon: "ruler")
                }

                if let education = profile.education {
                    SearchTagView(text: education.displayName, icon: education.icon)
                }

                if let occupation = profile.occupation {
                    SearchTagView(text: occupation, icon: "briefcase")
                }

                if let goal = profile.relationshipGoal {
                    SearchTagView(text: goal.displayName, icon: goal.icon)
                }
            }
        }
    }
}

// MARK: - Tag View

struct SearchTagView: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)

            Text(text)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

// Corner radius extension is defined in Extensions.swift

// MARK: - Preview

struct SearchResultsView_Previews: PreviewProvider {
    static var previews: some View {
        SearchResultsView()
    }
}
