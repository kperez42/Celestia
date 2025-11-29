//
//  LegalDocumentView.swift
//  Celestia
//
//  Legal documents display view with Privacy Policy, Terms of Service,
//  Community Guidelines, Safety Tips, and Cookie Policy
//

import SwiftUI

// MARK: - Document Type

enum LegalDocumentType: String, CaseIterable {
    case privacyPolicy = "Privacy Policy"
    case termsOfService = "Terms of Service"
    case communityGuidelines = "Community Guidelines"
    case safetyTips = "Dating Safety Tips"
    case cookiePolicy = "Cookie & Data Policy"

    var icon: String {
        switch self {
        case .privacyPolicy: return "lock.shield"
        case .termsOfService: return "doc.text"
        case .communityGuidelines: return "person.3.fill"
        case .safetyTips: return "shield.checkered"
        case .cookiePolicy: return "server.rack"
        }
    }

    var iconColor: Color {
        switch self {
        case .privacyPolicy: return .blue
        case .termsOfService: return .purple
        case .communityGuidelines: return .green
        case .safetyTips: return .orange
        case .cookiePolicy: return .gray
        }
    }

    var lastUpdated: String {
        "November 29, 2025"
    }
}

// MARK: - Legal Document View

struct LegalDocumentView: View {
    let documentType: LegalDocumentType
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: documentType.icon)
                                .font(.title)
                                .foregroundColor(documentType.iconColor)

                            Text(documentType.rawValue)
                                .font(.title2)
                                .fontWeight(.bold)
                        }

                        Text("Last Updated: \(documentType.lastUpdated)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 8)

                    // Document Content
                    documentContent

                    Spacer(minLength: 40)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var documentContent: some View {
        switch documentType {
        case .privacyPolicy:
            privacyPolicyContent
        case .termsOfService:
            termsOfServiceContent
        case .communityGuidelines:
            communityGuidelinesContent
        case .safetyTips:
            safetyTipsContent
        case .cookiePolicy:
            cookiePolicyContent
        }
    }
}

// MARK: - Privacy Policy Content

extension LegalDocumentView {
    private var privacyPolicyContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            LegalSection(title: "Introduction") {
                Text("Welcome to Celestia (\"we,\" \"our,\" or \"us\"). We are committed to protecting your privacy and ensuring the security of your personal information. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application and services.")
            }

            LegalSection(title: "Information We Collect") {
                VStack(alignment: .leading, spacing: 12) {
                    LegalSubsection(title: "Personal Information You Provide") {
                        BulletPoint("Account information: name, email address, date of birth, gender")
                        BulletPoint("Profile information: photos, bio, interests, location preferences")
                        BulletPoint("Communication data: messages sent through our platform")
                        BulletPoint("Payment information: processed securely through Apple's App Store")
                        BulletPoint("Verification data: identity verification documents (if applicable)")
                    }

                    LegalSubsection(title: "Information Collected Automatically") {
                        BulletPoint("Device information: device type, operating system, unique identifiers")
                        BulletPoint("Usage data: features used, time spent, interaction patterns")
                        BulletPoint("Location data: general location based on IP address or device settings")
                        BulletPoint("Log data: access times, pages viewed, app crashes")
                    }
                }
            }

            LegalSection(title: "How We Use Your Information") {
                VStack(alignment: .leading, spacing: 8) {
                    BulletPoint("To provide and maintain our dating services")
                    BulletPoint("To match you with other users based on your preferences")
                    BulletPoint("To process transactions and send related information")
                    BulletPoint("To send you technical notices and support messages")
                    BulletPoint("To detect, prevent, and address fraud and abuse")
                    BulletPoint("To comply with legal obligations")
                    BulletPoint("To improve and personalize your experience")
                }
            }

            LegalSection(title: "Information Sharing") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("We may share your information in the following circumstances:")
                        .font(.subheadline)

                    BulletPoint("With other users: Your profile information is visible to other users of the app")
                    BulletPoint("Service providers: Third-party vendors who assist in operating our services")
                    BulletPoint("Legal requirements: When required by law or to protect our rights")
                    BulletPoint("Business transfers: In connection with a merger, acquisition, or sale of assets")

                    Text("We do NOT sell your personal information to third parties.")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .padding(.top, 8)
                }
            }

            LegalSection(title: "Data Security") {
                Text("We implement industry-standard security measures to protect your personal information, including encryption, secure servers, and regular security audits. However, no method of transmission over the Internet or electronic storage is 100% secure.")
            }

            LegalSection(title: "Your Rights and Choices") {
                VStack(alignment: .leading, spacing: 8) {
                    BulletPoint("Access: Request a copy of your personal data")
                    BulletPoint("Correction: Update or correct inaccurate information")
                    BulletPoint("Deletion: Request deletion of your account and data")
                    BulletPoint("Portability: Receive your data in a portable format")
                    BulletPoint("Opt-out: Unsubscribe from marketing communications")
                    BulletPoint("Restrict: Limit how we process your data")
                }
            }

            LegalSection(title: "Data Retention") {
                Text("We retain your personal information for as long as your account is active or as needed to provide services. After account deletion, we may retain certain information for legal compliance, fraud prevention, or legitimate business purposes for up to 90 days.")
            }

            LegalSection(title: "Children's Privacy") {
                Text("Celestia is not intended for users under the age of 18. We do not knowingly collect personal information from children. If we become aware that we have collected data from a minor, we will take steps to delete such information promptly.")
            }

            LegalSection(title: "International Data Transfers") {
                Text("Your information may be transferred to and processed in countries other than your own. We ensure appropriate safeguards are in place for such transfers in compliance with applicable data protection laws.")
            }

            LegalSection(title: "Changes to This Policy") {
                Text("We may update this Privacy Policy from time to time. We will notify you of any material changes by posting the new policy on this page and updating the \"Last Updated\" date. Your continued use of the app after changes constitutes acceptance of the updated policy.")
            }

            LegalSection(title: "Contact Us") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("If you have questions about this Privacy Policy, please contact us:")
                        .font(.subheadline)

                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.purple)
                        Text("support@celestia.app")
                    }
                    .font(.subheadline)
                }
            }
        }
    }
}

// MARK: - Terms of Service Content

extension LegalDocumentView {
    private var termsOfServiceContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            LegalSection(title: "Acceptance of Terms") {
                Text("By accessing or using Celestia, you agree to be bound by these Terms of Service and our Privacy Policy. If you do not agree to these terms, please do not use our services.")
            }

            LegalSection(title: "Eligibility") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("To use Celestia, you must:")
                        .font(.subheadline)
                    BulletPoint("Be at least 18 years of age")
                    BulletPoint("Be legally capable of entering into a binding contract")
                    BulletPoint("Not be prohibited from using our services under applicable law")
                    BulletPoint("Not have been previously banned from our platform")
                }
            }

            LegalSection(title: "Account Registration") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("When creating an account, you agree to:")
                        .font(.subheadline)
                    BulletPoint("Provide accurate, current, and complete information")
                    BulletPoint("Maintain the security of your account credentials")
                    BulletPoint("Promptly update any changes to your information")
                    BulletPoint("Accept responsibility for all activities under your account")
                    BulletPoint("Use only one account per person")
                }
            }

            LegalSection(title: "User Conduct") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You agree NOT to:")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    BulletPoint("Harass, abuse, or harm other users")
                    BulletPoint("Post false, misleading, or fraudulent content")
                    BulletPoint("Upload illegal, obscene, or offensive material")
                    BulletPoint("Impersonate another person or entity")
                    BulletPoint("Use the service for commercial purposes without permission")
                    BulletPoint("Attempt to access other users' accounts")
                    BulletPoint("Transmit viruses, malware, or harmful code")
                    BulletPoint("Scrape, collect, or harvest user data")
                    BulletPoint("Circumvent security or access restrictions")
                    BulletPoint("Violate any applicable laws or regulations")
                }
            }

            LegalSection(title: "Content Ownership") {
                VStack(alignment: .leading, spacing: 12) {
                    LegalSubsection(title: "Your Content") {
                        Text("You retain ownership of content you submit. By posting content, you grant Celestia a non-exclusive, worldwide, royalty-free license to use, display, and distribute your content in connection with our services.")
                    }

                    LegalSubsection(title: "Our Content") {
                        Text("Celestia and its content, features, and functionality are owned by us and protected by intellectual property laws. You may not copy, modify, or distribute our content without permission.")
                    }
                }
            }

            LegalSection(title: "Premium Services") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Celestia offers premium subscription features:")
                        .font(.subheadline)
                    BulletPoint("Subscriptions are billed through Apple's App Store")
                    BulletPoint("Subscriptions auto-renew unless cancelled 24 hours before the end of the current period")
                    BulletPoint("Refunds are subject to Apple's refund policy")
                    BulletPoint("Premium features may change with notice")
                }
            }

            LegalSection(title: "Termination") {
                Text("We reserve the right to suspend or terminate your account at any time for violations of these terms, fraudulent activity, or any other reason at our sole discretion. You may delete your account at any time through the app settings.")
            }

            LegalSection(title: "Assumption of Risk") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("YOU ACKNOWLEDGE AND AGREE THAT:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)

                    BulletPoint("Online dating involves inherent risks including meeting strangers")
                    BulletPoint("You are solely responsible for your interactions with other users")
                    BulletPoint("Celestia does not conduct criminal background checks on users")
                    BulletPoint("We cannot guarantee the identity, intentions, or conduct of any user")
                    BulletPoint("You should take appropriate safety precautions when meeting anyone in person")
                    BulletPoint("Any meetings or relationships that result from the app are at your own risk")
                }
            }

            LegalSection(title: "No Background Checks") {
                Text("CELESTIA DOES NOT CONDUCT CRIMINAL BACKGROUND CHECKS OR IDENTITY VERIFICATION ON ALL USERS. We are not responsible for the conduct of any user, whether online or offline. You are solely responsible for your safety and should exercise caution when communicating with or meeting other users.")
                    .font(.caption)
            }

            LegalSection(title: "User Representations") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("By using Celestia, you represent and warrant that:")
                        .font(.subheadline)
                    BulletPoint("You are at least 18 years old")
                    BulletPoint("You are legally permitted to use the service in your jurisdiction")
                    BulletPoint("You have not been convicted of a felony or sex crime")
                    BulletPoint("You are not required to register as a sex offender")
                    BulletPoint("All information you provide is accurate and truthful")
                    BulletPoint("You will comply with all applicable laws while using the service")
                }
            }

            LegalSection(title: "Indemnification") {
                Text("You agree to indemnify, defend, and hold harmless Celestia, its officers, directors, employees, agents, and affiliates from any claims, damages, losses, liabilities, costs, and expenses (including reasonable attorney fees) arising from: (a) your use of the service; (b) your violation of these Terms; (c) your violation of any rights of another person or entity; (d) your conduct in connection with the service; or (e) any content you submit to the service.")
                    .font(.caption)
            }

            LegalSection(title: "Disclaimers") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CELESTIA IS PROVIDED \"AS IS\" WITHOUT WARRANTIES OF ANY KIND. WE DO NOT GUARANTEE:")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    BulletPoint("The accuracy or reliability of user profiles")
                    BulletPoint("That you will find a compatible match")
                    BulletPoint("Uninterrupted or error-free service")
                    BulletPoint("The conduct of other users")
                }
            }

            LegalSection(title: "Limitation of Liability") {
                Text("TO THE MAXIMUM EXTENT PERMITTED BY LAW, CELESTIA SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES ARISING FROM YOUR USE OF THE SERVICE, INCLUDING DAMAGES FOR LOSS OF PROFITS, DATA, OR OTHER INTANGIBLE LOSSES.")
                    .font(.caption)
            }

            LegalSection(title: "Dispute Resolution") {
                Text("Any disputes arising from these terms or your use of Celestia shall be resolved through binding arbitration in accordance with applicable arbitration rules. You agree to waive any right to a jury trial or to participate in a class action lawsuit.")
            }

            LegalSection(title: "Governing Law") {
                Text("These Terms shall be governed by and construed in accordance with the laws of the United States, without regard to conflict of law principles.")
            }

            LegalSection(title: "Changes to Terms") {
                Text("We may modify these Terms at any time. Material changes will be notified through the app or email. Continued use after changes constitutes acceptance of the modified terms.")
            }

            LegalSection(title: "Copyright & DMCA") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("If you believe content on Celestia infringes your copyright, please send a DMCA notice to support@celestia.app including:")
                        .font(.subheadline)
                    BulletPoint("Identification of the copyrighted work")
                    BulletPoint("Identification of the infringing material")
                    BulletPoint("Your contact information")
                    BulletPoint("A statement of good faith belief")
                    BulletPoint("A statement of accuracy under penalty of perjury")
                    BulletPoint("Your physical or electronic signature")
                }
            }

            LegalSection(title: "Severability") {
                Text("If any provision of these Terms is found to be invalid or unenforceable, that provision shall be limited or eliminated to the minimum extent necessary, and the remaining provisions shall remain in full force and effect.")
            }

            LegalSection(title: "Entire Agreement") {
                Text("These Terms, together with our Privacy Policy and Community Guidelines, constitute the entire agreement between you and Celestia regarding your use of the service and supersede all prior agreements and understandings.")
            }

            LegalSection(title: "No Waiver") {
                Text("Our failure to enforce any right or provision of these Terms shall not constitute a waiver of such right or provision. Any waiver must be in writing and signed by an authorized representative of Celestia.")
            }

            LegalSection(title: "Contact") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("For questions about these Terms:")
                        .font(.subheadline)
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.purple)
                        Text("support@celestia.app")
                    }
                    .font(.subheadline)
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.blue)
                        Text("legal@celestia.app")
                    }
                    .font(.subheadline)
                }
            }
        }
    }
}

// MARK: - Community Guidelines Content

extension LegalDocumentView {
    private var communityGuidelinesContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            LegalSection(title: "Our Community Values") {
                Text("Celestia is built on respect, authenticity, and safety. These guidelines help create a positive environment where everyone can find meaningful connections. Violations may result in warnings, temporary suspensions, or permanent bans.")
            }

            LegalSection(title: "Be Authentic") {
                VStack(alignment: .leading, spacing: 8) {
                    BulletPoint("Use your real name and recent photos")
                    BulletPoint("Be honest about your age, relationship status, and intentions")
                    BulletPoint("Don't impersonate others or create fake profiles")
                    BulletPoint("Represent yourself accurately in your bio and interests")
                }
            }

            LegalSection(title: "Be Respectful") {
                VStack(alignment: .leading, spacing: 8) {
                    BulletPoint("Treat all users with kindness and dignity")
                    BulletPoint("Accept rejection gracefully - not everyone will be a match")
                    BulletPoint("Avoid discriminatory language or behavior")
                    BulletPoint("Respect boundaries and privacy")
                    BulletPoint("Communicate honestly and clearly")
                }
            }

            LegalSection(title: "Keep It Safe") {
                VStack(alignment: .leading, spacing: 8) {
                    BulletPoint("Never share personal information publicly")
                    BulletPoint("Report suspicious or harmful behavior")
                    BulletPoint("Meet in public places for first dates")
                    BulletPoint("Trust your instincts - if something feels wrong, report it")
                    BulletPoint("Don't share financial information or send money")
                }
            }

            LegalSection(title: "Prohibited Content") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("The following content is strictly prohibited:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)

                    BulletPoint("Nudity, sexual content, or pornography")
                    BulletPoint("Violence, threats, or harassment")
                    BulletPoint("Hate speech or discrimination")
                    BulletPoint("Spam, scams, or commercial solicitation")
                    BulletPoint("Illegal activities or substances")
                    BulletPoint("Content involving minors")
                    BulletPoint("Copyrighted material without permission")
                }
            }

            LegalSection(title: "Prohibited Behaviors") {
                VStack(alignment: .leading, spacing: 8) {
                    BulletPoint("Harassment, bullying, or stalking")
                    BulletPoint("Catfishing or identity fraud")
                    BulletPoint("Soliciting money or promoting businesses")
                    BulletPoint("Attempting to meet minors")
                    BulletPoint("Using the platform while in a committed relationship (without partner's knowledge)")
                    BulletPoint("Mass messaging or spamming users")
                    BulletPoint("Sharing others' private information")
                }
            }

            LegalSection(title: "Photo Guidelines") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Acceptable Photos:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    BulletPoint("Clear photos of your face")
                    BulletPoint("Recent photos (within the last 2 years)")
                    BulletPoint("Photos that represent you authentically")

                    Text("Not Allowed:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .padding(.top, 8)
                    BulletPoint("Group photos as your main photo")
                    BulletPoint("Photos with nudity or suggestive content")
                    BulletPoint("Photos of someone else")
                    BulletPoint("Heavily filtered or misleading photos")
                    BulletPoint("Photos with contact information")
                }
            }

            LegalSection(title: "Reporting Violations") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("If you encounter violations, please report them immediately:")
                        .font(.subheadline)
                    BulletPoint("Use the Report button on any profile or message")
                    BulletPoint("Provide details about the violation")
                    BulletPoint("Block users who make you uncomfortable")
                    BulletPoint("Contact support for urgent safety concerns")
                }
            }

            LegalSection(title: "Enforcement") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Violations may result in:")
                        .font(.subheadline)
                    BulletPoint("Warning notification")
                    BulletPoint("Temporary account suspension")
                    BulletPoint("Permanent account ban")
                    BulletPoint("Reporting to law enforcement (for serious violations)")
                }
            }
        }
    }
}

// MARK: - Safety Tips Content

extension LegalDocumentView {
    private var safetyTipsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            LegalSection(title: "Your Safety Matters") {
                Text("While we work hard to keep Celestia safe, online dating requires caution. These tips will help protect you while meeting new people.")
            }

            LegalSection(title: "Protect Your Personal Information") {
                VStack(alignment: .leading, spacing: 8) {
                    BulletPoint("Never share your home address, workplace, or daily routine")
                    BulletPoint("Use our in-app messaging until you feel comfortable")
                    BulletPoint("Don't share financial information or social security numbers")
                    BulletPoint("Be cautious about sharing your full name early on")
                    BulletPoint("Consider using a Google Voice number instead of your real phone number")
                }
            }

            LegalSection(title: "Verify Before You Meet") {
                VStack(alignment: .leading, spacing: 8) {
                    BulletPoint("Video chat before meeting in person")
                    BulletPoint("Look for consistent information in their profile")
                    BulletPoint("Do a reverse image search on their photos")
                    BulletPoint("Check their social media profiles if available")
                    BulletPoint("Trust your gut - if something feels off, it probably is")
                }
            }

            LegalSection(title: "Meeting In Person") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("For your first meeting:")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    BulletPoint("Always meet in a public place")
                    BulletPoint("Tell a friend or family member your plans")
                    BulletPoint("Share your location with someone you trust")
                    BulletPoint("Arrange your own transportation")
                    BulletPoint("Don't leave drinks unattended")
                    BulletPoint("Stay sober and alert")
                    BulletPoint("Have an exit plan")
                }
            }

            LegalSection(title: "Red Flags to Watch For") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Be cautious if someone:")
                        .font(.subheadline)
                        .foregroundColor(.red)

                    BulletPoint("Asks for money or financial help")
                    BulletPoint("Refuses to video chat or meet in public")
                    BulletPoint("Has inconsistent stories or information")
                    BulletPoint("Pressures you to move off the app quickly")
                    BulletPoint("Asks for explicit photos")
                    BulletPoint("Claims to be in love very quickly")
                    BulletPoint("Makes you feel uncomfortable or unsafe")
                    BulletPoint("Claims to be in the military overseas needing money")
                }
            }

            LegalSection(title: "Romance Scam Warning Signs") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scammers often:")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    BulletPoint("Claim to be overseas (military, business)")
                    BulletPoint("Express strong feelings very quickly")
                    BulletPoint("Create emergencies requiring money")
                    BulletPoint("Ask for gift cards or wire transfers")
                    BulletPoint("Have professional model-quality photos")
                    BulletPoint("Can never video chat")

                    Text("NEVER send money to someone you haven't met in person.")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .padding(.top, 8)
                }
            }

            LegalSection(title: "If You Feel Unsafe") {
                VStack(alignment: .leading, spacing: 8) {
                    BulletPoint("Trust your instincts and leave immediately")
                    BulletPoint("Call 911 if you're in immediate danger")
                    BulletPoint("Report the user on Celestia")
                    BulletPoint("Block the person on all platforms")
                    BulletPoint("Save any threatening messages as evidence")
                    BulletPoint("Contact local authorities if needed")
                }
            }

            LegalSection(title: "Resources") {
                VStack(alignment: .leading, spacing: 12) {
                    ResourceLink(title: "National Domestic Violence Hotline", number: "1-800-799-7233")
                    ResourceLink(title: "RAINN Sexual Assault Hotline", number: "1-800-656-4673")
                    ResourceLink(title: "FTC Romance Scam Reporting", website: "reportfraud.ftc.gov")
                }
            }

            LegalSection(title: "Report Concerns") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Help us keep Celestia safe:")
                        .font(.subheadline)
                    BulletPoint("Report suspicious profiles immediately")
                    BulletPoint("Report harassment or inappropriate messages")
                    BulletPoint("Contact support@celestia.app for urgent concerns")
                }
            }
        }
    }
}

// MARK: - Cookie Policy Content

extension LegalDocumentView {
    private var cookiePolicyContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            LegalSection(title: "About This Policy") {
                Text("This Cookie & Data Policy explains how Celestia uses cookies, local storage, and similar technologies to collect and store information when you use our mobile application and related services.")
            }

            LegalSection(title: "What Are Cookies?") {
                Text("Cookies are small text files stored on your device. In mobile apps, we use similar technologies like local storage, device identifiers, and SDKs to achieve similar functionality.")
            }

            LegalSection(title: "Types of Data We Collect") {
                VStack(alignment: .leading, spacing: 12) {
                    LegalSubsection(title: "Essential Data") {
                        BulletPoint("Authentication tokens to keep you logged in")
                        BulletPoint("Session data for app functionality")
                        BulletPoint("Security tokens to protect your account")
                        BulletPoint("Preferences you've set in the app")
                    }

                    LegalSubsection(title: "Analytics Data") {
                        BulletPoint("App usage patterns and feature interactions")
                        BulletPoint("Crash reports and performance metrics")
                        BulletPoint("Device type and operating system")
                        BulletPoint("General location data")
                    }

                    LegalSubsection(title: "Advertising Identifiers") {
                        BulletPoint("IDFA (iOS Identifier for Advertisers)")
                        BulletPoint("Used for measuring ad effectiveness")
                        BulletPoint("Can be limited in device settings")
                    }
                }
            }

            LegalSection(title: "How We Use This Data") {
                VStack(alignment: .leading, spacing: 8) {
                    BulletPoint("Maintain your logged-in session")
                    BulletPoint("Remember your preferences and settings")
                    BulletPoint("Analyze and improve our services")
                    BulletPoint("Detect and prevent fraud")
                    BulletPoint("Measure the effectiveness of marketing")
                    BulletPoint("Provide personalized experiences")
                }
            }

            LegalSection(title: "Third-Party Services") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("We use the following third-party services that may collect data:")
                        .font(.subheadline)

                    LegalSubsection(title: "Firebase (Google)") {
                        Text("Analytics, authentication, cloud storage, and crash reporting")
                    }

                    LegalSubsection(title: "Apple Services") {
                        Text("App Store, StoreKit for in-app purchases, push notifications")
                    }

                    LegalSubsection(title: "Content Delivery") {
                        Text("Image hosting and delivery services for faster loading")
                    }
                }
            }

            LegalSection(title: "Your Choices") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You can control data collection through:")
                        .font(.subheadline)

                    BulletPoint("iOS Settings > Privacy > Tracking")
                    BulletPoint("iOS Settings > Privacy > Analytics & Improvements")
                    BulletPoint("In-app privacy settings")
                    BulletPoint("Deleting the app removes local data")
                }
            }

            LegalSection(title: "Data Retention") {
                VStack(alignment: .leading, spacing: 8) {
                    BulletPoint("Session data: Until you log out or session expires")
                    BulletPoint("Analytics data: Up to 14 months")
                    BulletPoint("Crash reports: Up to 90 days")
                    BulletPoint("Account data: Until account deletion")
                }
            }

            LegalSection(title: "CCPA Rights (California)") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("California residents have the right to:")
                        .font(.subheadline)
                    BulletPoint("Know what data we collect")
                    BulletPoint("Delete your personal information")
                    BulletPoint("Opt-out of the sale of personal information")
                    BulletPoint("Non-discrimination for exercising rights")

                    Text("We do not sell personal information.")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.top, 4)
                }
            }

            LegalSection(title: "GDPR Rights (EU/EEA)") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("EU/EEA residents have the right to:")
                        .font(.subheadline)
                    BulletPoint("Access your personal data")
                    BulletPoint("Rectify inaccurate data")
                    BulletPoint("Erase your data (right to be forgotten)")
                    BulletPoint("Restrict processing")
                    BulletPoint("Data portability")
                    BulletPoint("Object to processing")
                    BulletPoint("Withdraw consent at any time")
                }
            }

            LegalSection(title: "Updates to This Policy") {
                Text("We may update this policy periodically. Significant changes will be notified through the app or email. Continued use after updates constitutes acceptance.")
            }

            LegalSection(title: "Contact Us") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("For questions about this policy or to exercise your rights:")
                        .font(.subheadline)

                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.purple)
                        Text("privacy@celestia.app")
                    }
                    .font(.subheadline)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct LegalSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            content
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct LegalSubsection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            content
        }
    }
}

struct BulletPoint: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.purple)
            Text(text)
        }
        .font(.subheadline)
    }
}

struct ResourceLink: View {
    let title: String
    var number: String?
    var website: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            if let number = number {
                HStack {
                    Image(systemName: "phone.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text(number)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            if let website = website {
                HStack {
                    Image(systemName: "globe")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(website)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    LegalDocumentView(documentType: .privacyPolicy)
}
