# DesignSystem Migration Guide

**Status:** Foundation Created
**Target:** Replace 1,000+ magic numbers across 216 Swift files
**Estimated Impact:** Consistent design, easier theming, better maintainability

---

## Summary

Migrate from hardcoded values to DesignSystem tokens across the codebase:
- **507 hardcoded opacity values** → DesignSystem.Opacity.*
- **293 hardcoded corner radius values** → DesignSystem.CornerRadius.*
- **127+ card styling duplications** → .cardStyle() or .card()
- **300+ spacing values** → DesignSystem.Spacing.*
- **100+ font sizes** → DesignSystem.FontSize.*

---

## Migration Strategy

### Phase 1: High-Priority Files (Week 1)
Migrate most frequently used/viewed files first for maximum impact:
- DiscoverView.swift
- MatchesView.swift
- ChatView.swift
- ProfileView.swift
- SettingsView.swift

### Phase 2: Medium-Priority Files (Week 2)
Migrate modal and sheet views:
- EditProfileView.swift
- DiscoverFiltersView.swift
- PhotoVerificationView.swift
- PremiumUpgradeView.swift

### Phase 3: Remaining Files (Week 3)
Migrate remaining files incrementally:
- Component files
- Supporting views
- Sheet views

### Phase 4: Cleanup (Week 4)
- Remove any remaining magic numbers
- Ensure consistency
- Update documentation

---

## Common Migrations

### 1. Opacity Values

| Before | After | Usage |
|--------|-------|-------|
| `.opacity(0.1)` | `DesignSystem.Opacity.xxs` | Very subtle |
| `.opacity(0.2)` | `DesignSystem.Opacity.xs` | Subtle |
| `.opacity(0.3)` | `DesignSystem.Opacity.sm` | Light |
| `.opacity(0.4)` | `DesignSystem.Opacity.md` | Medium-light |
| `.opacity(0.5)` | `DesignSystem.Opacity.mediumOpacity` | Medium |
| `.opacity(0.6)` | `DesignSystem.Opacity.lg` | Medium-strong |
| `.opacity(0.7)` | `DesignSystem.Opacity.xl` | Strong |
| `.opacity(0.8)` | `DesignSystem.Opacity.xxl` | Very strong |

**Example:**
```swift
// Before:
Color.gray.opacity(0.3)
Image(systemName: "heart").opacity(0.6)

// After:
Color.gray.opacity(DesignSystem.Opacity.sm)
Image(systemName: "heart").opacity(DesignSystem.Opacity.lg)
```

---

### 2. Corner Radius Values

| Before | After | Usage |
|--------|-------|-------|
| `.cornerRadius(4)` | `DesignSystem.CornerRadius.xs` | Subtle rounding |
| `.cornerRadius(8)` | `DesignSystem.CornerRadius.sm` | Small rounding |
| `.cornerRadius(12)` | `DesignSystem.CornerRadius.md` | Medium (most common) |
| `.cornerRadius(16)` | `DesignSystem.CornerRadius.lg` | Large rounding |
| `.cornerRadius(20)` | `DesignSystem.CornerRadius.xl` | Extra large |
| `.cornerRadius(24)` | `DesignSystem.CornerRadius.xxl` | Double XL |

**Semantic Names:**
```swift
DesignSystem.CornerRadius.button  // 12pt (md)
DesignSystem.CornerRadius.card    // 16pt (lg)
DesignSystem.CornerRadius.sheet   // 20pt (xl)
```

**Example:**
```swift
// Before:
.cornerRadius(16)
.clipShape(RoundedRectangle(cornerRadius: 12))

// After:
.cornerRadius(DesignSystem.CornerRadius.lg)
.clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
```

---

### 3. Spacing Values

| Before | After | Usage |
|--------|-------|-------|
| `.padding(4)` | `DesignSystem.Spacing.xxs` | Minimum spacing |
| `.padding(8)` | `DesignSystem.Spacing.xs` | Extra small |
| `.padding(12)` | `DesignSystem.Spacing.sm` | Small |
| `.padding(16)` | `DesignSystem.Spacing.md` | Medium (most common) |
| `.padding(20)` | `DesignSystem.Spacing.lg` | Large |
| `.padding(24)` | `DesignSystem.Spacing.xl` | Extra large |
| `.padding(32)` | `DesignSystem.Spacing.xxl` | 2X large |

**Semantic Names:**
```swift
DesignSystem.Spacing.cardPadding     // 16pt (md)
DesignSystem.Spacing.sectionSpacing  // 24pt (xl)
DesignSystem.Spacing.screenPadding   // 20pt (lg)
```

**Example:**
```swift
// Before:
VStack(spacing: 24) {
    Text("Hello")
        .padding(16)
}
.padding(.horizontal, 20)

// After:
VStack(spacing: DesignSystem.Spacing.xl) {
    Text("Hello")
        .padding(DesignSystem.Spacing.cardPadding)
}
.padding(.horizontal, DesignSystem.Spacing.screenPadding)
```

---

### 4. Shadow Values

| Before | After |
|--------|-------|
| `.shadow(color: .black.opacity(0.1), radius: 2, y: 1)` | `DesignSystem.Shadow.sm` |
| `.shadow(color: .black.opacity(0.15), radius: 4, y: 2)` | `DesignSystem.Shadow.md` |
| `.shadow(color: .black.opacity(0.2), radius: 8, y: 4)` | `DesignSystem.Shadow.lg` |

**Example:**
```swift
// Before:
.shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)

// After:
.shadow(
    color: Color.black.opacity(DesignSystem.Shadow.md.opacity),
    radius: DesignSystem.Shadow.md.radius,
    x: DesignSystem.Shadow.md.offset.width,
    y: DesignSystem.Shadow.md.offset.height
)

// Or use the card modifier:
.card(shadow: .md)
```

---

### 5. Card Styling

**Before (127+ duplications):**
```swift
VStack {
    // content
}
.padding(16)
.background(Color(.systemBackground))
.cornerRadius(16)
.shadow(color: .black.opacity(0.15), radius: 4, y: 2)
```

**After (single line):**
```swift
VStack {
    // content
}
.cardStyle()
```

**Or with customization:**
```swift
VStack {
    // content
}
.card(cornerRadius: DesignSystem.CornerRadius.xl, shadow: .lg)
```

---

## File-Specific Examples

### Example 1: DiscoverFiltersView.swift

**Before:**
```swift
struct DiscoverFiltersView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                distanceSection
                    .padding(16)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)

                ageRangeSection
                    .padding(16)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
            }
            .padding(.horizontal, 20)
        }
    }

    var interestTag: some View {
        HStack {
            Text("Travel")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.purple.opacity(0.2))
        .cornerRadius(16)
    }
}
```

**After:**
```swift
struct DiscoverFiltersView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.sectionSpacing) {
                distanceSection.cardStyle()
                ageRangeSection.cardStyle()
            }
            .screenPadding()
        }
    }

    var interestTag: some View {
        HStack {
            Text("Travel")
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(Color.purple.opacity(DesignSystem.Opacity.xs))
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }
}
```

**Lines Changed:** ~15 lines
**Magic Numbers Removed:** 12
**Improvement:** More readable, consistent, maintainable

---

### Example 2: Profile Card Component

**Before:**
```swift
struct ProfileCard: View {
    let user: User

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AsyncImage(url: URL(string: user.profileImageURL)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(height: 200)
            .cornerRadius(12)

            Text(user.fullName)
                .font(.system(size: 20, weight: .bold))

            Text(user.bio)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .opacity(0.7)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }
}
```

**After:**
```swift
struct ProfileCard: View {
    let user: User

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            AsyncImage(url: URL(string: user.profileImageURL)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color.gray.opacity(DesignSystem.Opacity.sm)
            }
            .frame(height: 200)
            .cornerRadius(DesignSystem.CornerRadius.card)

            Text(user.fullName)
                .font(.system(size: DesignSystem.FontSize.headline, weight: .bold))

            Text(user.bio)
                .font(.system(size: DesignSystem.FontSize.sm))
                .foregroundColor(.secondary)
                .opacity(DesignSystem.Opacity.xl)
        }
        .cardStyle()
    }
}
```

**Magic Numbers Removed:** 10
**Readability:** Much improved with semantic names
**Consistency:** Matches design system across app

---

## Migration Tools

### Find and Replace Patterns

Use Xcode's Find & Replace (⌘⌥F) with regex:

#### 1. Common Opacity Values

Find: `\.opacity\(0\.1\)`
Replace: `.opacity(DesignSystem.Opacity.xxs)`

Find: `\.opacity\(0\.2\)`
Replace: `.opacity(DesignSystem.Opacity.xs)`

Find: `\.opacity\(0\.3\)`
Replace: `.opacity(DesignSystem.Opacity.sm)`

Find: `\.opacity\(0\.6\)`
Replace: `.opacity(DesignSystem.Opacity.lg)`

#### 2. Common Corner Radius

Find: `\.cornerRadius\(12\)`
Replace: `.cornerRadius(DesignSystem.CornerRadius.md)`

Find: `\.cornerRadius\(16\)`
Replace: `.cornerRadius(DesignSystem.CornerRadius.lg)`

Find: `\.cornerRadius\(20\)`
Replace: `.cornerRadius(DesignSystem.CornerRadius.xl)`

#### 3. Common Spacing

Find: `\.padding\(16\)`
Replace: `.padding(DesignSystem.Spacing.md)`

Find: `\.padding\(20\)`
Replace: `.padding(DesignSystem.Spacing.lg)`

Find: `\.padding\(24\)`
Replace: `.padding(DesignSystem.Spacing.xl)`

#### 4. VStack Spacing

Find: `VStack\(spacing: 24\)`
Replace: `VStack(spacing: DesignSystem.Spacing.xl)`

Find: `VStack\(spacing: 16\)`
Replace: `VStack(spacing: DesignSystem.Spacing.md)`

#### 5. Card Pattern

Find (Regex):
```
\.padding\(16\)\s*\.background\(Color\(\.systemBackground\)\)\s*\.cornerRadius\(16\)
```

Replace:
```
.cardStyle()
```

---

## Testing Checklist

After migrating each file:

- [ ] Build succeeds without errors
- [ ] UI looks identical to before
- [ ] No visual regressions
- [ ] Spacing feels consistent
- [ ] Shadows render correctly
- [ ] Corner radii are appropriate

---

## Benefits

### Consistency
- ✅ All spacing follows 8pt grid
- ✅ Corner radii consistent across app
- ✅ Opacity values standardized
- ✅ Typography scale defined

### Maintainability
- ✅ Change design tokens in one place
- ✅ Easy to implement dark mode
- ✅ Simple to create themes
- ✅ Self-documenting code

### Developer Experience
- ✅ Autocomplete for design values
- ✅ Type-safe design system
- ✅ Less cognitive load
- ✅ Faster development

### Future-Proofing
- ✅ Easy to update design
- ✅ Supports design system evolution
- ✅ Enables A/B testing of designs
- ✅ Facilitates rebranding

---

## Progress Tracking

Use this table to track migration progress:

| File | Lines | Magic Numbers | Status | Migrated By |
|------|-------|---------------|--------|-------------|
| DiscoverView.swift | 850 | ~25 | ⏳ Pending | - |
| MatchesView.swift | 650 | ~20 | ⏳ Pending | - |
| ChatView.swift | 1,045 | ~30 | ⏳ Pending | - |
| ProfileView.swift | 1,530 | ~40 | ⏳ Pending | - |
| SettingsView.swift | 450 | ~15 | ⏳ Pending | - |
| EditProfileView.swift | 1,594 | ~35 | ⏳ Pending | - |
| ... | ... | ... | ... | ... |

**Target:** 216 files, ~1,000 magic numbers
**Estimated Time:** 2-3 weeks with 2-3 developers
**Or:** 6-8 weeks solo, migrating 5-10 files/day

---

## Quick Wins

Start with these for immediate impact:

### 1. Universal Card Styling (30 minutes)
Find all instances of repeated card pattern, replace with `.cardStyle()`

**Impact:** Removes 127+ duplications

### 2. Opacity Standardization (1 hour)
Replace common opacity values (0.1, 0.2, 0.3, 0.6) across all files

**Impact:** 507 values → consistent

### 3. Corner Radius (1 hour)
Replace common corner radii (12, 16, 20) across all files

**Impact:** 293 values → consistent

### 4. Spacing (2 hours)
Replace common spacing values (16, 20, 24) in VStacks and padding

**Impact:** 300+ values → consistent

---

## Advanced Patterns

### Custom Card Variants

```swift
// Default card
.cardStyle()

// Card with larger corner radius
.card(cornerRadius: DesignSystem.CornerRadius.xl)

// Card with stronger shadow
.card(shadow: .lg)

// Fully custom
.card(cornerRadius: DesignSystem.CornerRadius.xxl, shadow: .xl)
```

### Semantic Helpers

```swift
// Screen-level padding
.screenPadding()  // Horizontal padding for screens

// Section spacing
.sectionSpacing() // Bottom padding for sections
```

### Button Styles

```swift
// Primary CTA button
Button("Sign Up") {}
    .primaryButtonStyle()

// Secondary button
Button("Cancel") {}
    .secondaryButtonStyle()
```

---

## Common Mistakes to Avoid

### ❌ Don't Mix Systems
```swift
// Bad - mixing magic numbers with DesignSystem
.padding(16)  // Magic number
.cornerRadius(DesignSystem.CornerRadius.lg)  // DesignSystem
```

```swift
// Good - consistent use
.padding(DesignSystem.Spacing.md)
.cornerRadius(DesignSystem.CornerRadius.lg)
```

### ❌ Don't Over-abstract
```swift
// Bad - unnecessarily verbose
let myPadding = DesignSystem.Spacing.md
.padding(myPadding)
```

```swift
// Good - direct usage
.padding(DesignSystem.Spacing.md)
```

### ❌ Don't Ignore Semantics
```swift
// Okay - but not ideal
.cornerRadius(DesignSystem.CornerRadius.lg)
```

```swift
// Better - use semantic names when available
.cornerRadius(DesignSystem.CornerRadius.card)
```

---

## Next Steps

1. **Review this guide** with your team
2. **Pick a file** to migrate (start small)
3. **Use find & replace** for common patterns
4. **Test thoroughly** after each file
5. **Commit incrementally** (one file or logical group at a time)
6. **Track progress** in the table above
7. **Repeat** until all files migrated

---

## Support

- **DesignSystem.swift** - Reference for all available tokens
- **This Guide** - Migration patterns and examples
- **Team** - Ask questions, share learnings

**Estimated ROI:**
- **Time Investment:** 2-3 weeks
- **Benefit:** Lifetime of consistent, maintainable code
- **Multiplier:** Every new feature benefits from design system

---

**Status:** Guide Complete, Ready for Team Migration
**Created:** 2025-11-15
**Last Updated:** 2025-11-15
