# Celestia App - Actionable Fixes & Code Examples

---

## QUICK FIX #1: Remove Unused previousTab State
**File:** `/home/user/Celestia/Celestia/MainTabView.swift`
**Lines:** 16, 59-62
**Time:** 2 minutes

### Current Code (REMOVE)
```swift
@State private var previousTab = 0

// ...

.onChange(of: selectedTab) { oldValue, newValue in
    previousTab = oldValue  // ← UNUSED
    HapticManager.shared.selection()
}
```

### Fixed Code
```swift
// Remove @State private var previousTab = 0

.onChange(of: selectedTab) { oldValue, newValue in
    HapticManager.shared.selection()
}
```

---

## QUICK FIX #2: Remove Test Crash Code
**File:** `/home/user/Celestia/Celestia/CrashlyticsManager.swift`
**Line:** 269
**Time:** 1 minute

### Current Code (DANGEROUS)
```swift
fatalError("Test crash triggered from CrashlyticsManager")
```

### Fixed Code
```swift
// Remove completely OR replace with:
Logger.shared.error("Crash test request received", category: .analytics)
// Don't actually crash - use testing environment instead
```

---

## QUICK FIX #3: Add Accessibility Labels
**File:** `/home/user/Celestia/Celestia/SavedProfilesView.swift`
**Lines:** 149-159
**Time:** 5 minutes

### Current Code
```swift
Button {
    showClearAllConfirmation = true
    HapticManager.shared.impact(.light)
} label: {
    Image(systemName: "trash.circle.fill")
        .font(.title3)
        .foregroundColor(.white)
}
```

### Fixed Code
```swift
Button {
    showClearAllConfirmation = true
    HapticManager.shared.impact(.light)
} label: {
    Image(systemName: "trash.circle.fill")
        .font(.title3)
        .foregroundColor(.white)
}
.accessibilityLabel("Clear all")
.accessibilityHint("Removes all \(viewModel.savedProfiles.count) saved profiles permanently")
```

---

## QUICK FIX #4: Hide Decorative Elements from VoiceOver
**File:** `/home/user/Celestia/Celestia/SavedProfilesView.swift`
**Lines:** 93-105
**Time:** 3 minutes

### Current Code
```swift
GeometryReader { geo in
    Circle()
        .fill(Color.white.opacity(0.1))
        .frame(width: 100, height: 100)
        .blur(radius: 20)
        .offset(x: -30, y: 20)

    Circle()
        .fill(Color.yellow.opacity(0.15))
        .frame(width: 60, height: 60)
        .blur(radius: 15)
        .offset(x: geo.size.width - 50, y: 40)
}
```

### Fixed Code
```swift
GeometryReader { geo in
    Circle()
        .fill(Color.white.opacity(0.1))
        .frame(width: 100, height: 100)
        .blur(radius: 20)
        .offset(x: -30, y: 20)
        .accessibilityHidden(true)  // ← ADD THIS

    Circle()
        .fill(Color.yellow.opacity(0.15))
        .frame(width: 60, height: 60)
        .blur(radius: 15)
        .offset(x: geo.size.width - 50, y: 40)
        .accessibilityHidden(true)  // ← ADD THIS
}
```

---

## QUICK FIX #5: Replace DispatchQueue with Task-based Scheduling
**File:** `/home/user/Celestia/Celestia/MainTabView.swift`
**Line:** 198
**Time:** 5 minutes

### Current Code (LEGACY)
```swift
Button(action: {
    isPressed = true
    action()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
        isPressed = false
    }
}) {
```

### Fixed Code
```swift
Button(action: {
    isPressed = true
    action()
    Task {
        try? await Task.sleep(nanoseconds: 150_000_000)
        isPressed = false
    }
}) {
```

---

## MEDIUM FIX #1: Create Reusable Header Component
**Time:** 30 minutes | **Reduces:** ~200 lines of duplication

### New File: `/home/user/Celestia/Celestia/Components/ScreenHeaderView.swift`
```swift
import SwiftUI

struct ScreenHeaderView: View {
    let title: String
    let icon: String
    let gradient: LinearGradient
    let subtitle: String?
    let actionButtons: [HeaderAction]
    
    var body: some View {
        ZStack {
            gradient
            
            // Decorative circles
            GeometryReader { geo in
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)
                    .offset(x: -30, y: 20)
                    .accessibilityHidden(true)
                
                Circle()
                    .fill(Color.yellow.opacity(0.15))
                    .frame(width: 60, height: 60)
                    .blur(radius: 15)
                    .offset(x: geo.size.width - 50, y: 40)
                    .accessibilityHidden(true)
            }
            
            VStack(spacing: 12) {
                HStack(alignment: .center) {
                    HStack(spacing: 12) {
                        Image(systemName: icon)
                            .font(.system(size: 36))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .yellow.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .white.opacity(0.4), radius: 10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.largeTitle.weight(.bold))
                                .foregroundColor(.white)
                                .accessibilityAddTraits(.isHeader)
                            
                            if let subtitle = subtitle {
                                Text(subtitle)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.95))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        ForEach(actionButtons, id: \.id) { button in
                            button.view
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, 50)
                .padding(.bottom, 16)
            }
        }
        .frame(height: 140)
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }
}

struct HeaderAction: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let action: () -> Void
    let view: AnyView
}

#Preview {
    ScreenHeaderView(
        title: "Messages",
        icon: "message.circle.fill",
        gradient: LinearGradient(
            colors: [Color.purple.opacity(0.9), Color.pink.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        subtitle: "5 chats • 2 unread",
        actionButtons: []
    )
}
```

### Updated MatchesView (Remove header code, use component)
**Before (80 lines):**
```swift
private var headerView: some View {
    ZStack {
        // ... 80 lines of duplicate code
    }
}
```

**After (5 lines):**
```swift
private var headerView: some View {
    ScreenHeaderView(
        title: "Matches",
        icon: "heart.circle.fill",
        gradient: LinearGradient(
            colors: [Color.purple.opacity(0.9), Color.purple.opacity(0.7), Color.blue.opacity(0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        subtitle: "\(matchService.matches.count) matches" + 
                  (unreadCount > 0 ? " • \(unreadCount) unread" : ""),
        actionButtons: []
    )
}
```

---

## MEDIUM FIX #2: Replace DEBUG/RELEASE Inconsistency
**File:** `/home/user/Celestia/Celestia/MatchesView.swift`
**Lines:** 53-68
**Time:** 10 minutes

### Current Code (PROBLEMATIC)
```swift
#if DEBUG
let userId = authService.currentUser?.id ?? "current_user"
#else
guard let userId = authService.currentUser?.id else { return 0 }
#endif
```

### Issue
Different behavior in DEBUG vs RELEASE makes testing unreliable.

### Fixed Code
```swift
// Always use the same logic
guard let userId = authService.currentUser?.id else { 
    assertionFailure("User ID should be available")
    return 0 
}
```

**OR** inject a mock user ID for testing:
```swift
let userId = authService.currentUser?.id ?? 
    (ProcessInfo.processInfo.environment["TEST_USER_ID"] ?? "")

guard !userId.isEmpty else {
    assertionFailure("User ID not available")
    return 0
}
```

---

## MEDIUM FIX #3: Add Missing Error States
**File:** `/home/user/Celestia/Celestia/MessagesView.swift`
**Time:** 15 minutes

### Add Error State Property
```swift
struct MessagesView: View {
    // ... existing properties
    @State private var errorMessage: String = ""  // ← ADD
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    headerView
                    
                    if showSearch {
                        searchBar
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Content with error handling
                    if !errorMessage.isEmpty {
                        errorStateView  // ← ADD THIS SECTION
                    } else if matchService.isLoading && conversations.isEmpty {
                        loadingView
                    } else if conversations.isEmpty {
                        emptyStateView
                    } else {
                        conversationsListView
                    }
                }
            }
        }
    }
    
    // Add this error view
    private var errorStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.headline)
            
            Text(errorMessage)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button(action: {
                errorMessage = ""
                Task {
                    await loadData()
                }
            }) {
                Text("Try Again")
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding(20)
    }
}
```

---

## MAJOR FIX #1: Split EditProfileView Into Components
**File:** `/home/user/Celestia/Celestia/EditProfileView.swift`
**Current Size:** 1,951 lines
**Time:** 2-3 hours | **Impact:** HUGE readability improvement

### Step 1: Extract BasicInfoSection
Create: `/home/user/Celestia/Celestia/Components/EditProfile/BasicInfoSection.swift`

```swift
import SwiftUI
import PhotosUI

struct BasicInfoSection: View {
    @Binding var fullName: String
    @Binding var age: String
    @Binding var bio: String
    @Binding var location: String
    @Binding var country: String
    
    var body: some View {
        VStack(spacing: 16) {
            // Name field
            TextField("Full Name", text: $fullName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(height: DesignSystem.Layout.textFieldHeight)
            
            // Age field
            TextField("Age", text: $age)
                .keyboardType(.numberPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(height: DesignSystem.Layout.textFieldHeight)
            
            // Bio field
            TextField("Bio", text: $bio, axis: .vertical)
                .lineLimit(4...8)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(minHeight: 100)
            
            // Location
            TextField("City", text: $location)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(height: DesignSystem.Layout.textFieldHeight)
            
            // Country
            TextField("Country", text: $country)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(height: DesignSystem.Layout.textFieldHeight)
        }
        .padding(DesignSystem.Spacing.lg)
    }
}
```

### Step 2: Extract PhotoUploadSection
Create: `/home/user/Celestia/Celestia/Components/EditProfile/PhotoUploadSection.swift`

```swift
import SwiftUI
import PhotosUI

struct PhotoUploadSection: View {
    @Binding var profileImage: UIImage?
    @Binding var showImagePicker: Bool
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    @Binding var photos: [String]
    @Binding var uploadProgress: Double
    
    let onDelete: (String) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Profile photo
            profilePhotoArea
            
            // Gallery
            photoGalleryArea
        }
        .padding(DesignSystem.Spacing.lg)
    }
    
    private var profilePhotoArea: some View {
        VStack(spacing: 12) {
            Text("Profile Photo")
                .font(.headline)
            
            // Photo picker button
            PhotosPicker(selection: $selectedPhotoItems) {
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.purple)
            }
        }
    }
    
    private var photoGalleryArea: some View {
        VStack(spacing: 12) {
            Text("Photo Gallery")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]) {
                ForEach(photos, id: \.self) { photo in
                    // Photo item with delete
                    ZStack(alignment: .topTrailing) {
                        AsyncImage(url: URL(string: photo))
                            .frame(height: 120)
                            .cornerRadius(8)
                        
                        Button(action: { onDelete(photo) }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                        .padding(4)
                    }
                }
            }
        }
    }
}
```

### Step 3: Refactor EditProfileView to Use Components
```swift
struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    
    // State simplified
    @State private var fullName: String = ""
    @State private var age: String = ""
    // ... etc
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 25) {
                        BasicInfoSection(
                            fullName: $fullName,
                            age: $age,
                            bio: $bio,
                            location: $location,
                            country: $country
                        )
                        
                        PhotoUploadSection(
                            profileImage: $profileImage,
                            showImagePicker: $showImagePicker,
                            selectedPhotoItems: $selectedPhotoItems,
                            photos: $photos,
                            uploadProgress: $uploadProgress,
                            onDelete: handlePhotoDelete
                        )
                        
                        PreferencesSection(...)
                        LanguagesSection(...)
                        InterestsSection(...)
                        
                        saveButton
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
            }
        }
    }
}
```

This approach:
- Reduces EditProfileView from 1,951 → ~300 lines
- Makes each section testable independently
- Improves code reusability
- Makes state management clearer

---

## MAJOR FIX #2: Replace Polling with Firebase Listeners
**File:** `/home/user/Celestia/Celestia/MainTabView.swift`
**Lines:** 143-163
**Time:** 45 minutes | **Impact:** Battery, Network Efficiency

### Current Code (POLLING - INEFFICIENT)
```swift
private func updateBadgesPeriodically() async {
    guard let userId = authService.currentUser?.id else { return }
    
    while !Task.isCancelled {
        unreadCount = await messageService.getUnreadMessageCount(userId: userId)
        try await matchService.fetchMatches(userId: userId)
        try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
    }
}
```

### Better Code (LISTENERS - REAL-TIME)
```swift
private func setupMessageListener() {
    guard let userId = authService.currentUser?.id else { return }
    
    messageService.setupRealtimeListener(
        userId: userId,
        onUnreadCountChange: { count in
            self.unreadCount = count
        }
    )
}

private func setupMatchListener() {
    guard let userId = authService.currentUser?.id else { return }
    
    matchService.setupRealtimeListener(
        userId: userId,
        onNewMatch: { match in
            self.newMatchesCount = self.matchService.matches.filter { $0.lastMessage == nil }.count
        }
    )
}
```

### In MessageService:
```swift
class MessageService: ObservableObject {
    private var messageListener: ListenerRegistration?
    private var unreadCountCallback: ((Int) -> Void)?
    
    func setupRealtimeListener(userId: String, onUnreadCountChange: @escaping (Int) -> Void) {
        messageListener = Firestore.firestore()
            .collection("messages")
            .whereField("recipientId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    Logger.shared.error("Error listening to messages", category: .messaging, error: error)
                    return
                }
                
                let unreadCount = snapshot?.documents.count ?? 0
                onUnreadCountChange(unreadCount)
            }
    }
    
    deinit {
        messageListener?.remove()
    }
}
```

Benefits:
- ✅ Real-time updates (no delay)
- ✅ Reduced battery drain (no 10-second polling)
- ✅ Reduced network traffic
- ✅ Automatic background pause

---

## SUMMARY: Implementation Priority

### Week 1 (Quick Wins)
- [ ] Remove unused previousTab
- [ ] Remove test crash code
- [ ] Add accessibility labels to interactive buttons
- [ ] Hide decorative circles from VoiceOver
- [ ] Replace DispatchQueue.main.asyncAfter with Task

### Week 2-3 (Medium Fixes)
- [ ] Create reusable ScreenHeaderView component
- [ ] Fix DEBUG/RELEASE inconsistencies
- [ ] Add error states to MessagesView/SavedProfilesView
- [ ] Replace hardcoded spacing with DesignSystem constants

### Week 4+ (Major Refactors)
- [ ] Split EditProfileView into components
- [ ] Split ProfileView into sections
- [ ] Replace polling with Firebase listeners
- [ ] Add ViewModels for complex views
- [ ] Consolidate navigation to single NavigationStack

