//
//  AdminMigrationView.swift
//  Celestia
//
//  Admin interface for migrating images to CDN
//

import SwiftUI

struct AdminMigrationView: View {
    @StateObject private var migrationService = ImageMigrationService.shared
    @State private var isConfirming = false
    @State private var isMigrating = false
    @State private var showResults = false
    @State private var migrationStats: MigrationStats?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Warning Banner
                    warningBanner

                    // Current Stats
                    if let stats = migrationStats {
                        currentStatsView(stats: stats)
                    }

                    // Migration Progress
                    if isMigrating {
                        migrationProgressView
                    }

                    // Migration Controls
                    if !isMigrating {
                        migrationControls
                    }

                    // Results
                    if showResults {
                        resultsView
                    }
                }
                .padding()
            }
            .navigationTitle("Image Migration")
            .task {
                await loadStats()
            }
        }
    }

    // MARK: - Warning Banner

    private var warningBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Admin Only")
                    .font(.headline)
            }

            Text("This will migrate all existing images to Cloudinary CDN. Make sure you have:")
                .font(.caption)

            VStack(alignment: .leading, spacing: 4) {
                Text("✓ Backed up Firestore data")
                Text("✓ Tested with sample images")
                Text("✓ Verified Cloudinary credentials")
                Text("✓ Admin permissions in Firestore")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Current Stats

    private func currentStatsView(stats: MigrationStats) -> some View {
        VStack(spacing: 16) {
            Text("Current Status")
                .font(.headline)

            HStack(spacing: 20) {
                MigrationStatBox(
                    value: "\(stats.total)",
                    label: "Total Users",
                    color: .blue
                )

                MigrationStatBox(
                    value: "\(stats.migrated)",
                    label: "Migrated",
                    color: .green
                )

                MigrationStatBox(
                    value: "\(stats.remaining)",
                    label: "Remaining",
                    color: .orange
                )
            }

            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(stats.percentComplete / 100), height: 12)
                }
            }
            .frame(height: 12)

            Text("\(Int(stats.percentComplete))% Complete")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Migration Progress

    private var migrationProgressView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()

            Text("Migrating Images...")
                .font(.headline)

            HStack(spacing: 40) {
                VStack {
                    Text("\(migrationService.totalMigrated)")
                        .font(.title)
                        .foregroundColor(.green)
                    Text("Migrated")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Text("\(migrationService.totalFailed)")
                        .font(.title)
                        .foregroundColor(.red)
                    Text("Failed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }

    // MARK: - Migration Controls

    private var migrationControls: some View {
        VStack(spacing: 16) {
            Button(action: {
                isConfirming = true
            }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Start Migration")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .confirmationDialog(
                "Start Image Migration?",
                isPresented: $isConfirming,
                titleVisibility: .visible
            ) {
                Button("Migrate All Images", role: .destructive) {
                    startMigration()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will migrate all user profile photos to Cloudinary CDN. This action cannot be undone. Make sure you have backed up your data.")
            }

            Button(action: {
                Task { await testMigration() }
            }) {
                HStack {
                    Image(systemName: "flask.fill")
                    Text("Test with Sample Images")
                }
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Results View

    private var resultsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Migration Complete")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(migrationService.totalMigrated) images migrated successfully")
                }

                if migrationService.totalFailed > 0 {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text("\(migrationService.totalFailed) images failed to migrate")
                    }
                }
            }
            .font(.subheadline)

            Divider()

            Button(action: {
                Task { await loadStats() }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh Stats")
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Actions

    private func loadStats() async {
        do {
            migrationStats = try await migrationService.getMigrationStats()
        } catch {
            Logger.shared.error("Failed to load migration stats", category: .storage, error: error)
        }
    }

    private func startMigration() {
        isMigrating = true
        showResults = false

        Task {
            do {
                try await migrationService.migrateAllUserPhotos(batchSize: 10)
                await MainActor.run {
                    isMigrating = false
                    showResults = true
                }
                await loadStats()
            } catch {
                Logger.shared.error("Migration failed", category: .storage, error: error)
                await MainActor.run {
                    isMigrating = false
                }
            }
        }
    }

    private func testMigration() async {
        Logger.shared.info("Testing migration with sample images...", category: .storage)
        // TODO: Implement test migration with sample images
    }
}

// MARK: - Stat Box Component

struct MigrationStatBox: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    AdminMigrationView()
}
