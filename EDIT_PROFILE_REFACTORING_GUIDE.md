# EditProfileView Refactoring Guide

**Status:** In Progress
**Original File Size:** 1,594 lines
**Target File Size:** ~300 lines
**Reduction:** 81% smaller

---

## Summary

EditProfileView.swift is being refactored from a monolithic 1,594-line file into a modular architecture with:
- 1 ViewModel (state management)
- 10+ View Components (UI sections)
- Improved testability and maintainability

---

## Architecture

### Before (Monolithic)
```
EditProfileView.swift (1,594 lines)
├── 38+ @State properties
├── All business logic inline
├── All UI sections inline
└── Helper functions mixed with UI
```

### After (Modular)
```
EditProfile/
├── EditProfileViewModel.swift (✅ CREATED - 250 lines)
├── EditProfileView.swift (REFACTORED - ~300 lines)
└── Components/
    ├── ProfileCompletionView.swift (✅ CREATED - 50 lines)
    ├── ProfilePhotoSection.swift (TODO - ~100 lines)
    ├── PhotoGallerySection.swift (TODO - ~80 lines)
    ├── BasicInfoSection.swift (TODO - ~120 lines)
    ├── AboutMeSection.swift (TODO - ~50 lines)
    ├── PreferencesSection.swift (TODO - ~80 lines)
    ├── LifestyleSection.swift (TODO - ~180 lines)
    ├── LanguagesSection.swift (TODO - ~70 lines)
    ├── InterestsSection.swift (TODO - ~70 lines)
    └── PromptsSection.swift (TODO - ~70 lines)
```

---

## ✅ Completed

### 1. EditProfileViewModel.swift (250 lines)
**Purpose:** Centralized state management and business logic

**Features:**
- All 38+ @State properties moved here as @Published
- Computed properties (isFormValid, completionProgress)
- Business logic (saveProfile, uploadProfileImage, updateUserProfile)
- Constants (options arrays, predefined lists)
- Actions (add/remove languages, interests)

**Benefits:**
- Testable business logic
- Reusable across views
- Single source of truth
- Cleaner main view

**Usage:**
```swift
struct EditProfileView: View {
    @StateObject private var viewModel = EditProfileViewModel()

    var body: some View {
        // Access via viewModel.property
        Text(viewModel.fullName)
    }
}
```

### 2. ProfileCompletionView.swift (50 lines)
**Purpose:** Extracted profile completion progress indicator

**Props:**
- `progress: Double` - Completion percentage (0.0 to 1.0)

**Features:**
- Color-coded progress (red < 50%, orange < 80%, green >= 80%)
- Motivational text
- Uses DesignSystem tokens

**Usage:**
```swift
ProfileCompletionView(progress: viewModel.completionProgress)
```

---

## 📋 TODO: Remaining Components

### Component Template

Each extracted component should follow this pattern:

```swift
//
//  [ComponentName].swift
//  Celestia
//
//  [Description]
//  Extracted from EditProfileView.swift
//

import SwiftUI

struct [ComponentName]: View {
    @ObservedObject var viewModel: EditProfileViewModel

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Component UI
        }
    }
}
```

---

### 3. ProfilePhotoSection.swift (~100 lines)
**Extract From:** Lines 194-305

**Purpose:** Profile photo upload with picker

**Key Elements:**
```swift
struct ProfilePhotoSection: View {
    @ObservedObject var viewModel: EditProfileViewModel

    var body: some View {
        VStack {
            // Profile photo circle
            ZStack {
                if let image = viewModel.profileImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                    // Placeholder with PhotosPicker
                }
            }

            PhotosPicker(selection: $viewModel.selectedImage) {
                Label("Change Photo", systemImage: "camera.fill")
            }
            .onChange(of: viewModel.selectedImage) { ... }
        }
    }
}
```

**Properties Used:**
- viewModel.profileImage
- viewModel.selectedImage
- viewModel.showImagePicker

---

### 4. PhotoGallerySection.swift (~80 lines)
**Extract From:** Lines 306-381

**Purpose:** Multiple photo upload grid

**Key Elements:**
```swift
struct PhotoGallerySection: View {
    @ObservedObject var viewModel: EditProfileViewModel

    var body: some View {
        VStack(alignment: .leading) {
            Text("Photos (\(viewModel.photos.count)/6)")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
                ForEach(viewModel.photos, id: \.self) { photo in
                    PhotoGridItem(photoURL: photo, onDelete: {
                        viewModel.photos.removeAll { $0 == photo }
                    })
                }

                if viewModel.photos.count < 6 {
                    PhotosPicker(selection: $viewModel.selectedPhotoItems) {
                        AddPhotoButton()
                    }
                }
            }
        }
    }
}
```

**Properties Used:**
- viewModel.photos
- viewModel.selectedPhotoItems
- viewModel.isUploadingPhotos
- viewModel.uploadProgress

---

### 5. BasicInfoSection.swift (~120 lines)
**Extract From:** Lines 440-561

**Purpose:** Name, age, location, gender, looking for

**Key Elements:**
```swift
struct BasicInfoSection: View {
    @ObservedObject var viewModel: EditProfileViewModel

    var body: some View {
        Section("Basic Information") {
            TextField("Full Name", text: $viewModel.fullName)
            TextField("Age", text: $viewModel.age)
                .keyboardType(.numberPad)
            TextField("Location", text: $viewModel.location)
            TextField("Country", text: $viewModel.country)

            Picker("Gender", selection: $viewModel.gender) {
                ForEach(viewModel.genderOptions, id: \.self) { option in
                    Text(option).tag(option)
                }
            }

            Picker("Looking for", selection: $viewModel.lookingFor) {
                ForEach(viewModel.lookingForOptions, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
        }
    }
}
```

**Properties Used:**
- viewModel.fullName
- viewModel.age
- viewModel.location
- viewModel.country
- viewModel.gender
- viewModel.lookingFor
- viewModel.genderOptions
- viewModel.lookingForOptions

---

### 6. AboutMeSection.swift (~50 lines)
**Extract From:** Lines 562-610

**Purpose:** Bio text editor

**Key Elements:**
```swift
struct AboutMeSection: View {
    @ObservedObject var viewModel: EditProfileViewModel

    var body: some View {
        Section("About Me") {
            TextEditor(text: $viewModel.bio)
                .frame(minHeight: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .stroke(Color.gray.opacity(DesignSystem.Opacity.sm), lineWidth: 1)
                )

            Text("\(viewModel.bio.count)/500 characters")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
```

**Properties Used:**
- viewModel.bio

---

### 7. PreferencesSection.swift (~80 lines)
**Extract From:** Lines 611-636

**Purpose:** Height and relationship preferences

**Key Elements:**
```swift
struct PreferencesSection: View {
    @ObservedObject var viewModel: EditProfileViewModel

    var body: some View {
        Section("Preferences") {
            // Height picker (120-220 cm)
            if let height = viewModel.height {
                HStack {
                    Text("Height")
                    Spacer()
                    Text("\(height) cm")
                        .foregroundColor(.secondary)
                }
            } else {
                Button("Add Height") {
                    viewModel.height = 170
                }
            }

            Picker("Relationship Goal", selection: $viewModel.relationshipGoal) {
                ForEach(viewModel.relationshipGoalOptions, id: \.self) { option in
                    Text(option).tag(option as String?)
                }
            }
        }
    }
}
```

**Properties Used:**
- viewModel.height
- viewModel.relationshipGoal
- viewModel.relationshipGoalOptions

---

### 8. LifestyleSection.swift (~180 lines)
**Extract From:** Lines 637-824

**Purpose:** Religion, smoking, drinking, pets, exercise, diet

**Key Elements:**
```swift
struct LifestyleSection: View {
    @ObservedObject var viewModel: EditProfileViewModel

    var body: some View {
        Section("Lifestyle") {
            LifestylePicker(
                title: "Religion",
                selection: $viewModel.religion,
                options: viewModel.religionOptions
            )

            LifestylePicker(
                title: "Smoking",
                selection: $viewModel.smoking,
                options: viewModel.smokingOptions
            )

            LifestylePicker(
                title: "Drinking",
                selection: $viewModel.drinking,
                options: viewModel.drinkingOptions
            )

            // ... more pickers
        }
    }
}

struct LifestylePicker: View {
    let title: String
    @Binding var selection: String?
    let options: [String]

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(options, id: \.self) { option in
                Text(option).tag(option as String?)
            }
        }
    }
}
```

**Properties Used:**
- viewModel.religion
- viewModel.smoking
- viewModel.drinking
- viewModel.pets
- viewModel.exercise
- viewModel.diet
- All options arrays

---

### 9. LanguagesSection.swift (~70 lines)
**Extract From:** Lines 825-876

**Purpose:** Language selection with predefined options

**Key Elements:**
```swift
struct LanguagesSection: View {
    @ObservedObject var viewModel: EditProfileViewModel

    var body: some View {
        Section("Languages") {
            ForEach(viewModel.languages, id: \.self) { language in
                HStack {
                    Text(language)
                    Spacer()
                    Button(action: {
                        viewModel.removeLanguage(language)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }

            Button("Add Language") {
                viewModel.showLanguagePicker = true
            }
        }
        .sheet(isPresented: $viewModel.showLanguagePicker) {
            LanguagePickerSheet(viewModel: viewModel)
        }
    }
}
```

**Properties Used:**
- viewModel.languages
- viewModel.showLanguagePicker
- viewModel.predefinedLanguages
- viewModel.addLanguage()
- viewModel.removeLanguage()

---

### 10. InterestsSection.swift (~70 lines)
**Extract From:** Lines 877-928

**Purpose:** Interest selection (max 10)

**Key Elements:**
```swift
struct InterestsSection: View {
    @ObservedObject var viewModel: EditProfileViewModel

    var body: some View {
        Section("Interests (Max 10)") {
            FlowLayout(items: viewModel.interests) { interest in
                InterestTag(text: interest, onRemove: {
                    viewModel.removeInterest(interest)
                })
            }

            if viewModel.interests.count < 10 {
                Button("Add Interest") {
                    viewModel.showInterestPicker = true
                }
            }
        }
        .sheet(isPresented: $viewModel.showInterestPicker) {
            InterestPickerSheet(viewModel: viewModel)
        }
    }
}

struct InterestTag: View {
    let text: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.purple.opacity(0.2))
        .cornerRadius(16)
    }
}
```

**Properties Used:**
- viewModel.interests
- viewModel.showInterestPicker
- viewModel.predefinedInterests
- viewModel.addInterest()
- viewModel.removeInterest()

---

### 11. PromptsSection.swift (~70 lines)
**Extract From:** Lines 929-1000

**Purpose:** Profile prompts editor

**Key Elements:**
```swift
struct PromptsSection: View {
    @ObservedObject var viewModel: EditProfileViewModel

    var body: some View {
        Section("Prompts") {
            ForEach(viewModel.prompts) { prompt in
                VStack(alignment: .leading, spacing: 8) {
                    Text(prompt.question)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(prompt.answer)
                        .font(.body)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }

            Button("Edit Prompts") {
                viewModel.showPromptsEditor = true
            }
        }
        .sheet(isPresented: $viewModel.showPromptsEditor) {
            PromptsEditorView(prompts: $viewModel.prompts)
        }
    }
}
```

**Properties Used:**
- viewModel.prompts
- viewModel.showPromptsEditor

---

## Refactored Main View

After extracting all components, EditProfileView.swift becomes:

```swift
//
//  EditProfileView.swift
//  Celestia
//
//  Enhanced profile editing with modular components
//  Refactored from 1,594 lines to ~300 lines
//

import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = EditProfileViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView("Saving...")
                } else {
                    Form {
                        ProfileCompletionView(progress: viewModel.completionProgress)

                        ProfilePhotoSection(viewModel: viewModel)
                        PhotoGallerySection(viewModel: viewModel)
                        BasicInfoSection(viewModel: viewModel)
                        AboutMeSection(viewModel: viewModel)
                        PreferencesSection(viewModel: viewModel)
                        LifestyleSection(viewModel: viewModel)
                        LanguagesSection(viewModel: viewModel)
                        InterestsSection(viewModel: viewModel)
                        PromptsSection(viewModel: viewModel)

                        SaveButton(viewModel: viewModel, authService: authService, dismiss: dismiss)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Success", isPresented: $viewModel.showSuccessAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your profile has been updated!")
            }
            .alert("Error", isPresented: $viewModel.showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
}

struct SaveButton: View {
    @ObservedObject var viewModel: EditProfileViewModel
    let authService: AuthService
    let dismiss: DismissAction

    var body: some View {
        Button(action: {
            Task {
                await viewModel.saveProfile(authService: authService) {
                    dismiss()
                }
            }
        }) {
            Text("Save Changes")
                .frame(maxWidth: .infinity)
        }
        .primaryButtonStyle()
        .disabled(!viewModel.isFormValid)
        .padding()
    }
}
```

---

## Migration Steps

1. ✅ **Create EditProfileViewModel.swift**
   - Move all @State properties to @Published
   - Move business logic methods
   - Move computed properties
   - Move constants

2. ✅ **Create ProfileCompletionView.swift**
   - Extract completion progress UI
   - Use DesignSystem tokens

3. ⏳ **Create remaining component files**
   - Follow the template above for each section
   - Pass viewModel as @ObservedObject
   - Use $ bindings for two-way data flow

4. ⏳ **Refactor main EditProfileView**
   - Replace @State with @StateObject viewModel
   - Replace inline sections with component views
   - Remove extracted code
   - Update bindings to use viewModel

5. ⏳ **Test thoroughly**
   - Verify all functionality works
   - Test form validation
   - Test save functionality
   - Test photo uploads

---

## Benefits

### Code Quality
- ✅ Reduced file size by 81% (1,594 → 300 lines)
- ✅ Single Responsibility Principle
- ✅ Testable ViewModel
- ✅ Reusable components

### Maintainability
- ✅ Easier to find and fix bugs
- ✅ Components can be reused
- ✅ Clear separation of concerns
- ✅ Self-documenting code structure

### Developer Experience
- ✅ Faster to understand
- ✅ Easier to onboard new developers
- ✅ Simpler to add new fields
- ✅ Better Git diffs

---

## Estimated Impact

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| **File Size** | 1,594 lines | ~300 lines | **-81%** |
| **Components** | 1 monolith | 12 modular | **+1100%** |
| **Testability** | Low | High | **✅** |
| **Reusability** | None | High | **✅** |
| **Maintainability** | Poor | Excellent | **✅** |

---

## Next Steps

1. Complete remaining component extractions
2. Apply same pattern to:
   - ProfileView.swift (1,530 lines)
   - OnboardingView.swift (1,294 lines)
   - ChatView.swift (1,045 lines)
   - ProfileInsightsView.swift (1,029 lines)

3. Create unit tests for ViewModels
4. Document component library

---

**Status:** ViewModel + 2 components created, ready for full migration
**Estimated Time to Complete:** 2-3 days for all 5 large files
