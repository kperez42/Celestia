# Image Migration Guide

## Overview

This guide covers migrating existing Firebase Storage images to Cloudinary CDN for improved performance and bandwidth savings.

## When to Migrate

**Migrate if:**
- You have existing users with profile photos in Firebase Storage
- Photos are stored as single full-resolution files
- Load times are slow for users with poor connections
- You want to reduce bandwidth costs

**Don't migrate if:**
- This is a new app with no existing users
- All images are already optimized
- You plan to deprecate old photos

## Migration Strategy

### Option 1: Gradual Migration (Recommended)

Migrate images on-demand as users access their profiles. This is the safest approach.

**Benefits:**
- No downtime
- Spreads CDN storage costs over time
- Only migrates actively used images
- Less risk

**Implementation:**
```swift
// Add to User model or photo loading logic
func loadProfilePhoto() async -> OptimizedPhotoData? {
    // Check if already migrated
    if let optimizedPhoto = user.optimizedPhoto {
        return optimizedPhoto
    }

    // Load from Firebase Storage (legacy)
    if let firebaseUrl = user.profilePhotoURL {
        // Migrate in background
        Task {
            await migrateUserPhoto(firebaseUrl)
        }
        return loadLegacyPhoto(firebaseUrl)
    }

    return nil
}
```

### Option 2: Batch Migration

Migrate all images at once using an admin script. Best for smaller datasets (<1000 images).

**Benefits:**
- Complete migration in one session
- Predictable costs
- Clean cutover

**Risks:**
- Higher upfront CDN costs
- Potential for errors at scale
- Requires admin access

## Prerequisites

### 1. Admin User Setup

First, mark your account as admin in Firestore:

```javascript
// Run in Firebase Console or admin script
db.collection('users').doc('YOUR_USER_ID').update({
  isAdmin: true
});
```

### 2. Backup Strategy

Before migrating, ensure you have backups:

```bash
# Export Firestore data
gcloud firestore export gs://YOUR_BUCKET/firestore-backup

# Or use Firebase Console:
# Firestore Database → Import/Export → Export
```

### 3. Test with Sample Images

Always test with a few images first:

```swift
let testUrls = [
    "https://firebasestorage.googleapis.com/v0/b/.../photo1.jpg",
    "https://firebasestorage.googleapis.com/v0/b/.../photo2.jpg"
]

for url in testUrls {
    let result = try await migrateImage(url)
    print("✅ Migrated: \(url)")
    print("   CDN URL: \(result.cdnUrl)")
}
```

## Implementation

### Swift Migration Service

Create `ImageMigrationService.swift`:

```swift
//
//  ImageMigrationService.swift
//  Celestia
//
//  Service for migrating existing Firebase Storage images to Cloudinary CDN
//

import Foundation
import Firebase
import FirebaseFunctions
import FirebaseFirestore

@MainActor
class ImageMigrationService: ObservableObject {
    static let shared = ImageMigrationService()

    private let functions = Functions.functions()
    private let db = Firestore.firestore()

    @Published var migrationProgress: [String: MigrationStatus] = [:]
    @Published var totalMigrated = 0
    @Published var totalFailed = 0

    private init() {}

    // MARK: - Single Image Migration

    /// Migrate a single image from Firebase Storage to Cloudinary
    func migrateImage(firebaseUrl: String) async throws -> OptimizedPhotoData {
        let migrateFunction = functions.httpsCallable("migrateImageToCDN")

        do {
            let result = try await migrateFunction.call(["firebaseUrl": firebaseUrl])

            guard let data = result.data as? [String: Any],
                  let success = data["success"] as? Bool,
                  success,
                  let photoData = data["photoData"] as? [String: Any] else {
                throw MigrationError.invalidResponse
            }

            return try parseOptimizedPhotoData(photoData)

        } catch {
            Logger.shared.error("Migration failed for \(firebaseUrl)", category: .storage, error: error)
            throw MigrationError.migrationFailed(error)
        }
    }

    // MARK: - Batch Migration

    /// Migrate all user profile photos
    func migrateAllUserPhotos(batchSize: Int = 10) async throws {
        Logger.shared.info("Starting batch migration", category: .storage)

        // Fetch all users with Firebase Storage URLs
        let snapshot = try await db.collection("users")
            .whereField("profilePhotoURL", isGreaterThan: "")
            .getDocuments()

        let users = snapshot.documents
        Logger.shared.info("Found \(users.count) users to migrate", category: .storage)

        // Process in batches to avoid overwhelming the system
        for batch in users.chunked(into: batchSize) {
            await withTaskGroup(of: MigrationResult.self) { group in
                for userDoc in batch {
                    group.addTask {
                        await self.migrateUserPhotos(userDoc: userDoc)
                    }
                }

                for await result in group {
                    switch result {
                    case .success(let userId):
                        await MainActor.run {
                            self.migrationProgress[userId] = .completed
                            self.totalMigrated += 1
                        }
                        Logger.shared.info("Migrated user \(userId)", category: .storage)

                    case .failure(let userId, let error):
                        await MainActor.run {
                            self.migrationProgress[userId] = .failed(error)
                            self.totalFailed += 1
                        }
                        Logger.shared.error("Failed to migrate user \(userId)", category: .storage, error: error)
                    }
                }
            }

            // Add delay between batches to avoid rate limits
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }

        Logger.shared.info("Migration complete: \(totalMigrated) succeeded, \(totalFailed) failed", category: .storage)
    }

    private func migrateUserPhotos(userDoc: QueryDocumentSnapshot) async -> MigrationResult {
        let userId = userDoc.documentID
        let data = userDoc.data()

        do {
            // Migrate profile photo
            if let profilePhotoURL = data["profilePhotoURL"] as? String {
                let optimizedPhoto = try await migrateImage(firebaseUrl: profilePhotoURL)

                // Update Firestore with optimized photo data
                try await db.collection("users").document(userId).updateData([
                    "optimizedPhoto": [
                        "urls": optimizedPhoto.urls,
                        "placeholder": optimizedPhoto.placeholder ?? "",
                        "cloudinaryPublicId": optimizedPhoto.cloudinaryPublicId ?? "",
                        "cdnUrl": optimizedPhoto.cdnUrl ?? "",
                        "bytes": optimizedPhoto.bytes ?? 0
                    ],
                    "migratedAt": FieldValue.serverTimestamp()
                ])
            }

            // Migrate additional photos if present
            if let photoUrls = data["photos"] as? [String] {
                var optimizedPhotos: [[String: Any]] = []

                for photoUrl in photoUrls {
                    let optimized = try await migrateImage(firebaseUrl: photoUrl)
                    optimizedPhotos.append([
                        "urls": optimized.urls,
                        "placeholder": optimized.placeholder ?? "",
                        "cloudinaryPublicId": optimized.cloudinaryPublicId ?? "",
                        "cdnUrl": optimized.cdnUrl ?? "",
                        "bytes": optimized.bytes ?? 0
                    ])
                }

                try await db.collection("users").document(userId).updateData([
                    "optimizedPhotos": optimizedPhotos
                ])
            }

            return .success(userId)

        } catch {
            return .failure(userId, error)
        }
    }

    // MARK: - Helper Methods

    private func parseOptimizedPhotoData(_ data: [String: Any]) throws -> OptimizedPhotoData {
        guard let urlsDict = data["urls"] as? [String: String] else {
            throw MigrationError.invalidResponse
        }

        return OptimizedPhotoData(
            urls: urlsDict,
            placeholder: data["placeholder"] as? String,
            cloudinaryPublicId: data["cloudinaryPublicId"] as? String,
            cdnUrl: data["cdnUrl"] as? String,
            bytes: data["bytes"] as? Int
        )
    }
}

// MARK: - Supporting Types

enum MigrationStatus {
    case pending
    case inProgress
    case completed
    case failed(Error)
}

enum MigrationResult {
    case success(String)
    case failure(String, Error)
}

enum MigrationError: LocalizedError {
    case invalidResponse
    case migrationFailed(Error)
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from migration endpoint"
        case .migrationFailed(let error):
            return "Migration failed: \(error.localizedDescription)"
        case .notAuthorized:
            return "Admin access required for migration"
        }
    }
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
```

### Admin Migration View

Create `AdminMigrationView.swift` for manual control:

```swift
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

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Warning Banner
                warningBanner

                // Migration Stats
                if isMigrating {
                    migrationStats
                }

                // Migration Controls
                if !isMigrating {
                    migrationControls
                }

                Spacer()

                // Results
                if showResults {
                    resultsView
                }
            }
            .padding()
            .navigationTitle("Image Migration")
        }
    }

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

    private var migrationStats: some View {
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
    }

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
                Text("This will migrate all user profile photos to Cloudinary CDN. This action cannot be undone.")
            }
        }
    }

    private var resultsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Migration Complete")
                .font(.headline)

            Text("✅ \(migrationService.totalMigrated) images migrated successfully")
                .foregroundColor(.green)

            if migrationService.totalFailed > 0 {
                Text("❌ \(migrationService.totalFailed) images failed to migrate")
                    .foregroundColor(.red)
            }

            Button("View Details") {
                // Show detailed results
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func startMigration() {
        isMigrating = true

        Task {
            do {
                try await migrationService.migrateAllUserPhotos(batchSize: 10)
                await MainActor.run {
                    isMigrating = false
                    showResults = true
                }
            } catch {
                Logger.shared.error("Migration failed", category: .storage, error: error)
                await MainActor.run {
                    isMigrating = false
                }
            }
        }
    }
}

#Preview {
    AdminMigrationView()
}
```

## Usage Examples

### Example 1: Migrate Single Image

```swift
let firebaseUrl = "https://firebasestorage.googleapis.com/v0/b/celestia-app.appspot.com/o/profile-photos%2Fuser123.jpg?alt=media"

do {
    let optimizedPhoto = try await ImageMigrationService.shared.migrateImage(firebaseUrl: firebaseUrl)
    print("✅ Migration successful!")
    print("CDN URL: \(optimizedPhoto.cdnUrl ?? "N/A")")
    print("Sizes available: \(optimizedPhoto.urls.keys.joined(separator: ", "))")
} catch {
    print("❌ Migration failed: \(error.localizedDescription)")
}
```

### Example 2: Batch Migration with Progress

```swift
Task {
    do {
        try await ImageMigrationService.shared.migrateAllUserPhotos(batchSize: 10)
        print("✅ All images migrated successfully!")
        print("Total migrated: \(ImageMigrationService.shared.totalMigrated)")
        print("Total failed: \(ImageMigrationService.shared.totalFailed)")
    } catch {
        print("❌ Batch migration error: \(error.localizedDescription)")
    }
}
```

### Example 3: Gradual Migration on User Load

```swift
// In your User loading logic
func loadUser(userId: String) async throws -> User {
    let userDoc = try await db.collection("users").document(userId).getDocument()
    var user = try userDoc.data(as: User.self)

    // Check if photos need migration
    if user.optimizedPhoto == nil, let legacyUrl = user.profilePhotoURL {
        // Migrate in background (non-blocking)
        Task.detached {
            do {
                let optimized = try await ImageMigrationService.shared.migrateImage(firebaseUrl: legacyUrl)

                // Update Firestore
                try await db.collection("users").document(userId).updateData([
                    "optimizedPhoto": [
                        "urls": optimized.urls,
                        "placeholder": optimized.placeholder ?? "",
                        "cloudinaryPublicId": optimized.cloudinaryPublicId ?? "",
                        "cdnUrl": optimized.cdnUrl ?? ""
                    ]
                ])
            } catch {
                Logger.shared.error("Background migration failed", category: .storage, error: error)
            }
        }
    }

    return user
}
```

## Firestore Schema Updates

### Before Migration (Legacy)

```json
{
  "userId": "user123",
  "profilePhotoURL": "https://firebasestorage.googleapis.com/.../photo.jpg",
  "photos": [
    "https://firebasestorage.googleapis.com/.../photo1.jpg",
    "https://firebasestorage.googleapis.com/.../photo2.jpg"
  ]
}
```

### After Migration (Optimized)

```json
{
  "userId": "user123",
  "profilePhotoURL": "https://firebasestorage.googleapis.com/.../photo.jpg",
  "optimizedPhoto": {
    "urls": {
      "thumbnail": "https://res.cloudinary.com/.../w_150,h_150/photo.webp",
      "small": "https://res.cloudinary.com/.../w_375,h_500/photo.webp",
      "medium": "https://res.cloudinary.com/.../w_750,h_1000/photo.webp",
      "large": "https://res.cloudinary.com/.../w_1200,h_1600/photo.webp",
      "original": "https://res.cloudinary.com/.../photo.webp"
    },
    "placeholder": "data:image/webp;base64,UklGRh4A...",
    "cloudinaryPublicId": "profile-photos/user123-1234567890",
    "cdnUrl": "https://res.cloudinary.com/dquqeovn2/image/upload/v1234567890/profile-photos/user123-1234567890.webp",
    "bytes": 245678
  },
  "optimizedPhotos": [
    { /* Same structure as optimizedPhoto */ },
    { /* Same structure as optimizedPhoto */ }
  ],
  "migratedAt": "2025-11-18T10:30:00Z"
}
```

## Backward Compatibility

Keep legacy URLs during migration for rollback capability:

```swift
// Load photo with fallback
func loadUserPhoto() async -> UIImage? {
    // Try optimized first
    if let optimizedPhoto = user.optimizedPhoto {
        return await OptimizedImageLoader.shared.loadImage(
            urls: optimizedPhoto.urls,
            for: CGSize(width: 375, height: 500)
        )
    }

    // Fall back to legacy
    if let legacyUrl = user.profilePhotoURL {
        return await loadLegacyPhoto(legacyUrl)
    }

    return nil
}
```

## Cost Estimation

**Cloudinary Free Tier:**
- 25 GB storage
- 25 GB monthly bandwidth
- 25,000 transformations/month

**Migration costs for 1000 users:**
- Average 3 photos per user = 3,000 photos
- Each photo generates 5 sizes = 15,000 transformations
- Average 500KB per original = ~1.5 GB storage

**Fits within free tier:** ✅

## Monitoring

### Track Migration Progress

```swift
// In your migration service
func getMigrationStats() async -> MigrationStats {
    let total = try await db.collection("users").count().getAggregation()
    let migrated = try await db.collection("users")
        .whereField("optimizedPhoto", isNotEqualTo: nil)
        .count()
        .getAggregation()

    return MigrationStats(
        total: total.count,
        migrated: migrated.count,
        remaining: total.count - migrated.count,
        percentComplete: Double(migrated.count) / Double(total.count) * 100
    )
}
```

### Cloudinary Dashboard

Monitor your migration at: https://console.cloudinary.com/

- **Media Library**: View all uploaded images
- **Usage**: Track bandwidth and transformations
- **Reports**: Analyze performance metrics

## Rollback Plan

If migration fails or causes issues:

1. **Stop Migration**: Cancel the migration task
2. **Revert Firestore**: Use backup to restore user documents
3. **Keep Legacy URLs**: App will fall back to Firebase Storage automatically
4. **Clean Cloudinary**: Delete migrated images if needed

```swift
// Rollback script
func rollbackMigration(userIds: [String]) async throws {
    for userId in userIds {
        try await db.collection("users").document(userId).updateData([
            "optimizedPhoto": FieldValue.delete(),
            "optimizedPhotos": FieldValue.delete(),
            "migratedAt": FieldValue.delete()
        ])
    }
}
```

## Best Practices

1. **Start Small**: Migrate 10-20 users first
2. **Monitor Errors**: Log all failures for investigation
3. **Rate Limit**: Use batches with delays to avoid overwhelming services
4. **Backup First**: Always backup Firestore before batch operations
5. **Test Thoroughly**: Verify images load correctly after migration
6. **Keep Legacy URLs**: Don't delete Firebase Storage images immediately
7. **Admin Only**: Restrict migration endpoints to admin users
8. **Track Progress**: Use the migration service's progress tracking

## Troubleshooting

### Error: "Admin access required"

**Solution**: Add `isAdmin: true` to your user document in Firestore

```javascript
db.collection('users').doc('YOUR_USER_ID').update({ isAdmin: true });
```

### Error: "Migration failed: 403 Forbidden"

**Solution**: Check Cloudinary credentials in Cloud Functions config

```bash
firebase functions:config:get
firebase functions:config:set cloudinary.api_key="YOUR_KEY"
```

### Error: "Rate limit exceeded"

**Solution**: Increase delay between batches

```swift
try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds instead of 2
```

### Error: "Invalid Firebase URL"

**Solution**: Ensure URL is a valid Firebase Storage URL with `alt=media` token

```swift
// Valid format:
"https://firebasestorage.googleapis.com/v0/b/PROJECT_ID.appspot.com/o/path%2Ffile.jpg?alt=media"
```

## Next Steps

1. ✅ Create admin user in Firestore
2. ✅ Test migration with 5-10 images
3. ✅ Verify images load correctly
4. ✅ Run full batch migration
5. ✅ Monitor Cloudinary dashboard
6. ✅ Update app to use optimized images by default
7. ✅ Schedule cleanup of old Firebase Storage images (after 30 days)

## Summary

The migration system provides:
- ✅ Safe, gradual migration option
- ✅ Batch migration for complete cutover
- ✅ Admin-only security
- ✅ Progress tracking
- ✅ Error handling and rollback
- ✅ Backward compatibility
- ✅ Cost-effective within free tier

For questions or issues, refer to:
- `CLOUDINARY_SETUP_COMPLETE.md` - Configuration details
- `TESTING_GUIDE.md` - Testing procedures
- `IMAGE_OPTIMIZATION_REPORT.md` - Architecture overview
