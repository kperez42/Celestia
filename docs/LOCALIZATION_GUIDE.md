# Localization (i18n) Guide

This guide covers the complete localization setup for Celestia, including how to add new languages and use localized strings throughout the app.

## 📋 Table of Contents

1. [Overview](#overview)
2. [Supported Languages](#supported-languages)
3. [Using Localized Strings](#using-localized-strings)
4. [Adding New Languages](#adding-new-languages)
5. [String Management](#string-management)
6. [Date & Number Formatting](#date--number-formatting)
7. [Testing Localization](#testing-localization)
8. [Best Practices](#best-practices)

---

## Overview

Celestia supports multiple languages to reach a global audience. The localization system is built on:
- **LocalizationManager**: Centralized language management
- **Localizable.strings**: Translation files for each language
- **Type-safe keys**: Structured enum for string keys
- **SwiftUI extensions**: Easy-to-use localization in views

---

## Supported Languages

Currently supported languages:

| Language | Code | Flag | Native Name |
|----------|------|------|-------------|
| English | `en` | 🇺🇸 | English |
| Spanish | `es` | 🇪🇸 | Español |
| French | `fr` | 🇫🇷 | Français |
| German | `de` | 🇩🇪 | Deutsch |
| Portuguese | `pt` | 🇵🇹 | Português |
| Italian | `it` | 🇮🇹 | Italiano |
| Japanese | `ja` | 🇯🇵 | 日本語 |
| Korean | `ko` | 🇰🇷 | 한국어 |
| Chinese | `zh` | 🇨🇳 | 中文 |

---

## Using Localized Strings

### In SwiftUI Views

```swift
import SwiftUI

struct LoginView: View {
    var body: some View {
        VStack {
            // Method 1: Using LocalizedStringKey directly
            Text("auth.sign_in")

            // Method 2: Using custom Text initializer
            Text(localized: LocalizedStrings.Auth.signIn)

            // Method 3: Using String extension
            Text(LocalizedStrings.Auth.email.localized)

            // Method 4: Using Button with localized title
            Button("auth.create_account") {
                // Action
            }
        }
    }
}
```

### In UIKit Views

```swift
import UIKit

class LoginViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // Method 1: Using NSLocalizedString
        let title = NSLocalizedString("auth.sign_in", comment: "Sign in button title")

        // Method 2: Using String extension
        let subtitle = LocalizedStrings.Auth.email.localized

        // Method 3: Using LocalizationManager
        let message = LocalizationManager.shared.string(
            for: LocalizedStringKey(LocalizedStrings.Auth.signIn),
            comment: "Sign in"
        )
    }
}
```

### With Format Arguments

```swift
// In Localizable.strings:
// "matches.matched_with" = "Matched with %@";

// In code:
let name = "Sarah"
let message = LocalizedStrings.Matches.matchedWith.localized(with: name)
// Result: "Matched with Sarah"

// Multiple arguments:
// "message.sent_at" = "%@ sent a message at %@";
let sender = "John"
let time = "3:45 PM"
let message = "message.sent_at".localized(with: sender, time)
// Result: "John sent a message at 3:45 PM"
```

### Programmatic Language Switching

```swift
// Change app language
LocalizationManager.shared.currentLanguage = .spanish

// Get current language
let current = LocalizationManager.shared.currentLanguage
print("Current language: \(current.name)") // "Español"

// Listen for language changes
NotificationCenter.default.addObserver(
    forName: .languageChanged,
    object: nil,
    queue: .main
) { _ in
    // Reload UI
    print("Language changed!")
}
```

---

## Adding New Languages

### Step 1: Add Language to Enum

Update `LocalizationManager.swift`:

```swift
enum Language: String, CaseIterable {
    // ... existing languages
    case dutch = "nl"  // Add new language

    var name: String {
        switch self {
        // ... existing cases
        case .dutch: return "Nederlands"
        }
    }

    var flag: String {
        switch self {
        // ... existing cases
        case .dutch: return "🇳🇱"
        }
    }
}
```

### Step 2: Create Localization Directory

In Xcode:
1. Right-click `Celestia/Localization` folder
2. Select **New File** → **Strings File**
3. Name it `Localizable.strings`
4. In File Inspector, click **Localize...**
5. Select the new language (e.g., Dutch)
6. Create folder structure: `nl.lproj/Localizable.strings`

### Step 3: Translate Strings

Copy `en.lproj/Localizable.strings` to `nl.lproj/Localizable.strings` and translate:

```
// nl.lproj/Localizable.strings
"auth.sign_in" = "Inloggen";
"auth.sign_up" = "Registreren";
"auth.email" = "E-mail";
// ... translate all strings
```

### Step 4: Add to Xcode Project

1. Select `Localizable.strings` file
2. Open File Inspector (⌥⌘1)
3. In **Localization** section, check the new language
4. Ensure the file is added to all targets

### Step 5: Test

```swift
// Test the new language
LocalizationManager.shared.currentLanguage = .dutch
print("auth.sign_in".localized) // Should print: "Inloggen"
```

---

## String Management

### Organization

Strings are organized by feature area using the `LocalizedStrings` enum:

```swift
// In LocalizationManager.swift
enum LocalizedStrings {
    enum Common {
        static let ok = "common.ok"
        static let cancel = "common.cancel"
    }

    enum Auth {
        static let signIn = "auth.sign_in"
        static let signUp = "auth.sign_up"
    }

    // Add new sections as needed
    enum Notifications {
        static let title = "notifications.title"
        static let settings = "notifications.settings"
    }
}
```

### Adding New Strings

1. **Add to enum** (for type safety):
```swift
enum Profile {
    static let verified = "profile.verified"
}
```

2. **Add to all Localizable.strings files**:
```
// en.lproj/Localizable.strings
"profile.verified" = "Verified";

// es.lproj/Localizable.strings
"profile.verified" = "Verificado";

// fr.lproj/Localizable.strings
"profile.verified" = "Vérifié";
```

3. **Use in code**:
```swift
Text(LocalizedStrings.Profile.verified)
```

### Pluralization

iOS supports automatic pluralization:

```
// Localizable.stringsdict
<key>matches.count</key>
<dict>
    <key>NSStringLocalizedFormatKey</key>
    <string>%#@matches@</string>
    <key>matches</key>
    <dict>
        <key>NSStringFormatSpecTypeKey</key>
        <string>NSStringPluralRuleType</string>
        <key>NSStringFormatValueTypeKey</key>
        <string>d</string>
        <key>zero</key>
        <string>No matches</string>
        <key>one</key>
        <string>1 match</string>
        <key>other</key>
        <string>%d matches</string>
    </dict>
</dict>
```

Usage:
```swift
let count = 5
let text = String.localizedStringWithFormat(
    NSLocalizedString("matches.count", comment: ""),
    count
)
// Result: "5 matches"
```

---

## Date & Number Formatting

The `LocalizationManager` provides locale-aware formatting:

### Date Formatting

```swift
let date = Date()
let manager = LocalizationManager.shared

// Format date
let dateString = manager.formatDate(date, style: .medium)
// en: "Nov 10, 2025"
// es: "10 nov 2025"
// fr: "10 nov. 2025"

// Format time
let timeString = manager.formatTime(date, style: .short)
// en: "3:45 PM"
// es: "15:45"
// fr: "15:45"

// Format date and time
let dateTimeString = manager.formatDateTime(date)
// en: "Nov 10, 2025 at 3:45 PM"
// es: "10 nov 2025, 15:45"

// Relative date
let relativeString = manager.formatRelativeDate(date)
// en: "2 hours ago"
// es: "hace 2 horas"
// fr: "il y a 2 heures"
```

### Number Formatting

```swift
let manager = LocalizationManager.shared

// Format number
let numberString = manager.formatNumber(1000)
// en: "1,000"
// de: "1.000"
// fr: "1 000"

// Format currency
let priceString = manager.formatCurrency(9.99, currencyCode: "USD")
// en: "$9.99"
// es: "9,99 US$"
// fr: "9,99 $US"

// Format percentage
let percentString = manager.formatPercentage(0.75)
// en: "75%"
// de: "75 %"
// fr: "75 %"
```

---

## Testing Localization

### Manual Testing in Simulator

1. Open **Settings** app in Simulator
2. Go to **General** → **Language & Region**
3. Tap **iPhone Language**
4. Select a different language
5. Restart the app

### Programmatic Testing

```swift
// In AppDelegate or SceneDelegate for testing
#if DEBUG
LocalizationManager.shared.currentLanguage = .spanish
#endif
```

### UI Tests with Different Languages

```swift
func testSpanishLocalization() {
    app.launchEnvironment["AppLanguage"] = "es"
    app.launch()

    // Verify Spanish strings appear
    XCTAssertTrue(app.buttons["Iniciar Sesión"].exists)
}
```

### Verify All Strings Are Translated

Create a test to ensure all keys exist in all languages:

```swift
func testAllStringsExist() {
    let languages = ["en", "es", "fr", "de"]
    let keys = [
        "auth.sign_in",
        "auth.sign_up",
        // ... all keys
    ]

    for language in languages {
        let bundle = Bundle(path: Bundle.main.path(
            forResource: language,
            ofType: "lproj"
        )!)!

        for key in keys {
            let value = NSLocalizedString(
                key,
                bundle: bundle,
                comment: ""
            )
            XCTAssertNotEqual(value, key, "Missing translation for \(key) in \(language)")
        }
    }
}
```

---

## Best Practices

### 1. Always Use Keys, Never Hardcode Strings

❌ **Bad:**
```swift
Text("Sign In")
Button("Create Account") { }
```

✅ **Good:**
```swift
Text(LocalizedStrings.Auth.signIn)
Button(LocalizedStrings.Auth.createAccount) { }
```

### 2. Provide Context in Comments

```swift
// Good comments help translators
"button.save" = "Save"; // Button to save user changes
"label.save" = "Save"; // Label showing last save time
```

### 3. Avoid String Concatenation

❌ **Bad:**
```swift
let message = "Hello" + " " + name + "!"
```

✅ **Good:**
```swift
// In Localizable.strings:
// "greeting.message" = "Hello %@!";

let message = "greeting.message".localized(with: name)
```

### 4. Use Placeholders Correctly

```swift
// Single placeholder
"message.from" = "Message from %@";

// Multiple placeholders (numbered)
"message.details" = "%1$@ sent you a message at %2$@";
```

### 5. Consider RTL Languages

For languages like Arabic or Hebrew, use:

```swift
if UIView.userInterfaceLayoutDirection(
    for: .unspecified
) == .rightToLeft {
    // Adjust layout for RTL
}
```

### 6. Keep String Keys Organized

Use a consistent naming convention:
- `category.subcategory.description`
- Examples: `auth.sign_in`, `profile.edit_bio`, `error.network`

### 7. Test All Languages

Always test with:
- Longest language (usually German) for layout issues
- Shortest language (usually English) for proper spacing
- RTL languages (Arabic, Hebrew) for layout direction

### 8. Handle Missing Translations Gracefully

```swift
extension String {
    var localized: String {
        let value = NSLocalizedString(self, comment: "")
        // If translation missing, use key as fallback
        return value == self ? self.replacingOccurrences(of: "_", with: " ").capitalized : value
    }
}
```

---

## Language Picker UI

Example implementation of a language picker:

```swift
struct LanguagePickerView: View {
    @StateObject private var localization = LocalizationManager.shared

    var body: some View {
        List {
            ForEach(LocalizationManager.Language.allCases) { language in
                Button {
                    localization.currentLanguage = language
                } label: {
                    HStack {
                        Text(language.flag)
                            .font(.title)

                        Text(language.name)
                            .foregroundColor(.primary)

                        Spacer()

                        if localization.currentLanguage == language {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle(LocalizedStrings.Settings.language)
    }
}
```

---

## Exporting Strings for Translation

### Export for Translators

```bash
# Export all strings to XLIFF format
xcodebuild -exportLocalizations -project Celestia.xcodeproj -localizationPath ./Localizations

# This creates .xliff files that can be sent to translators
```

### Import Translations

```bash
# Import translated XLIFF files
xcodebuild -importLocalizations -project Celestia.xcodeproj -localizationPath ./Localizations/es.xliff
```

---

## Localization Checklist

Before releasing in a new language:

- [ ] All strings translated in `Localizable.strings`
- [ ] App Store metadata translated (name, description, screenshots)
- [ ] Date/time formats tested
- [ ] Number/currency formats tested
- [ ] Layout tested (especially for long strings)
- [ ] RTL support tested (if applicable)
- [ ] Error messages translated
- [ ] Push notifications localized
- [ ] Email templates localized
- [ ] Terms of Service and Privacy Policy translated
- [ ] Help/Support content available in language

---

## Resources

- [Apple Localization Guide](https://developer.apple.com/documentation/xcode/localization)
- [NSLocalizedString Documentation](https://developer.apple.com/documentation/foundation/nslocalizedstring)
- [DateFormatter Guide](https://developer.apple.com/documentation/foundation/dateformatter)
- [NumberFormatter Guide](https://developer.apple.com/documentation/foundation/numberformatter)
- [Internationalization Best Practices](https://developer.apple.com/internationalization/)

---

## Support

For localization issues or questions:
1. Check this guide first
2. Review the `LocalizationManager.swift` implementation
3. Test in Simulator with different languages
4. Enable debug logging: `Logger.shared.minimumLogLevel = .debug`
