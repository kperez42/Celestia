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
    case eula = "End User License Agreement"
    case accessibility = "Accessibility Statement"

    var icon: String {
        switch self {
        case .privacyPolicy: return "lock.shield"
        case .termsOfService: return "doc.text"
        case .communityGuidelines: return "person.3.fill"
        case .safetyTips: return "shield.checkered"
        case .cookiePolicy: return "server.rack"
        case .eula: return "doc.badge.gearshape"
        case .accessibility: return "accessibility"
        }
    }

    var iconColor: Color {
        switch self {
        case .privacyPolicy: return .blue
        case .termsOfService: return .purple
        case .communityGuidelines: return .green
        case .safetyTips: return .orange
        case .cookiePolicy: return .gray
        case .eula: return .indigo
        case .accessibility: return .teal
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
        case .eula:
            eulaContent
        case .accessibility:
            accessibilityContent
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
                        SimpleBulletPoint("Account information: name, email address, date of birth, gender")
                        SimpleBulletPoint("Profile information: photos, bio, interests, location preferences")
                        SimpleBulletPoint("Communication data: messages sent through our platform")
                        SimpleBulletPoint("Payment information: processed securely through Apple's App Store")
                        SimpleBulletPoint("Verification data: identity verification documents (if applicable)")
                    }

                    LegalSubsection(title: "Information Collected Automatically") {
                        SimpleBulletPoint("Device information: device type, operating system, unique identifiers")
                        SimpleBulletPoint("Usage data: features used, time spent, interaction patterns")
                        SimpleBulletPoint("Location data: general location based on IP address or device settings")
                        SimpleBulletPoint("Log data: access times, pages viewed, app crashes")
                    }
                }
            }

            LegalSection(title: "Biometric Data Notice") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("IMPORTANT BIOMETRIC DATA DISCLOSURE (ILLINOIS BIPA & OTHER STATE LAWS)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)

                    Text("If you use our photo verification feature, we may collect biometric data including facial geometry scans. By using photo verification, you consent to the following:")
                        .font(.subheadline)

                    SimpleBulletPoint("Purpose: Biometric data is used solely for identity verification and fraud prevention")
                    SimpleBulletPoint("Storage: Facial geometry data is encrypted and stored securely")
                    SimpleBulletPoint("Retention: Biometric data is permanently deleted within 3 years of your last interaction with the app, or upon account deletion, whichever occurs first")
                    SimpleBulletPoint("Sharing: We do not sell, lease, trade, or profit from your biometric data")
                    SimpleBulletPoint("Third Parties: Biometric data may be processed by our secure verification partners under strict contractual obligations")

                    Text("You may opt out of photo verification features. To request deletion of biometric data, contact privacy@celestia.app.")
                        .font(.caption)
                        .padding(.top, 4)
                }
            }

            LegalSection(title: "How We Use Your Information") {
                VStack(alignment: .leading, spacing: 8) {
                    SimpleBulletPoint("To provide and maintain our dating services")
                    SimpleBulletPoint("To match you with other users based on your preferences")
                    SimpleBulletPoint("To process transactions and send related information")
                    SimpleBulletPoint("To send you technical notices and support messages")
                    SimpleBulletPoint("To detect, prevent, and address fraud and abuse")
                    SimpleBulletPoint("To comply with legal obligations")
                    SimpleBulletPoint("To improve and personalize your experience")
                }
            }

            LegalSection(title: "Information Sharing") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("We may share your information in the following circumstances:")
                        .font(.subheadline)

                    SimpleBulletPoint("With other users: Your profile information is visible to other users of the app")
                    SimpleBulletPoint("Service providers: Third-party vendors who assist in operating our services")
                    SimpleBulletPoint("Legal requirements: When required by law or to protect our rights")
                    SimpleBulletPoint("Business transfers: In connection with a merger, acquisition, or sale of assets")

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
                    SimpleBulletPoint("Access: Request a copy of your personal data")
                    SimpleBulletPoint("Correction: Update or correct inaccurate information")
                    SimpleBulletPoint("Deletion: Request deletion of your account and data")
                    SimpleBulletPoint("Portability: Receive your data in a portable format")
                    SimpleBulletPoint("Opt-out: Unsubscribe from marketing communications")
                    SimpleBulletPoint("Restrict: Limit how we process your data")
                }
            }

            LegalSection(title: "Data Retention") {
                Text("We retain your personal information for as long as your account is active or as needed to provide services. After account deletion, we may retain certain information for legal compliance, fraud prevention, or legitimate business purposes for up to 90 days.")
            }

            LegalSection(title: "Children's Privacy") {
                Text("Celestia is not intended for users under the age of 18. We do not knowingly collect personal information from children. If we become aware that we have collected data from a minor, we will take steps to delete such information promptly.")
            }

            LegalSection(title: "International Data Transfers") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your information may be transferred to and processed in countries other than your own, including the United States. We ensure appropriate safeguards are in place for such transfers, including:")
                        .font(.subheadline)
                    SimpleBulletPoint("Standard Contractual Clauses (SCCs) approved by the European Commission")
                    SimpleBulletPoint("Data Processing Agreements with all third-party processors")
                    SimpleBulletPoint("Encryption of data in transit and at rest")
                    SimpleBulletPoint("Compliance with EU-US Data Privacy Framework where applicable")
                }
            }

            LegalSection(title: "Legal Bases for Processing (GDPR)") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("We process your personal data under the following legal bases:")
                        .font(.subheadline)
                    SimpleBulletPoint("Contract: To provide our dating services as agreed in our Terms of Service")
                    SimpleBulletPoint("Consent: For marketing communications and optional features")
                    SimpleBulletPoint("Legitimate Interests: For fraud prevention, security, and service improvement")
                    SimpleBulletPoint("Legal Obligation: To comply with applicable laws and regulations")
                }
            }

            LegalSection(title: "Data Protection Officer") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("For GDPR-related inquiries, you may contact our Data Protection Officer:")
                        .font(.subheadline)
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.blue)
                        Text("dpo@celestia.app")
                    }
                    .font(.subheadline)
                    Text("EU Representative: Available upon request for EU/EEA residents")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            LegalSection(title: "State-Specific Privacy Rights") {
                VStack(alignment: .leading, spacing: 12) {
                    LegalSubsection(title: "California (CCPA/CPRA)") {
                        VStack(alignment: .leading, spacing: 4) {
                            SimpleBulletPoint("Right to know what personal information is collected")
                            SimpleBulletPoint("Right to delete personal information")
                            SimpleBulletPoint("Right to opt-out of sale/sharing of personal information")
                            SimpleBulletPoint("Right to correct inaccurate personal information")
                            SimpleBulletPoint("Right to limit use of sensitive personal information")
                            SimpleBulletPoint("Right to non-discrimination for exercising rights")
                            Text("We do not sell or share your personal information for cross-context behavioral advertising.")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.top, 4)
                        }
                    }

                    LegalSubsection(title: "Virginia (VCDPA)") {
                        VStack(alignment: .leading, spacing: 4) {
                            SimpleBulletPoint("Right to access, correct, and delete personal data")
                            SimpleBulletPoint("Right to data portability")
                            SimpleBulletPoint("Right to opt-out of targeted advertising and profiling")
                        }
                    }

                    LegalSubsection(title: "Colorado (CPA), Connecticut (CTDPA), Utah (UCPA)") {
                        Text("Residents of these states have similar rights to access, delete, correct, and opt-out of certain data processing. Contact privacy@celestia.app to exercise your rights.")
                            .font(.caption)
                    }
                }
            }

            LegalSection(title: "Data Breach Notification") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("In the event of a data breach affecting your personal information, we will:")
                        .font(.subheadline)
                    SimpleBulletPoint("Notify affected users within 72 hours of discovery (as required by GDPR)")
                    SimpleBulletPoint("Notify relevant supervisory authorities as required by law")
                    SimpleBulletPoint("Provide information about the breach and steps you can take")
                    SimpleBulletPoint("Offer appropriate remediation such as credit monitoring if applicable")
                }
            }

            LegalSection(title: "Automated Decision-Making") {
                Text("We may use automated systems to help detect fraud, enforce our policies, and improve matching algorithms. You have the right to request human review of decisions that significantly affect you. Matching suggestions are based on your stated preferences and are not final decisions about your eligibility for any service.")
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
                    SimpleBulletPoint("Be at least 18 years of age")
                    SimpleBulletPoint("Be legally capable of entering into a binding contract")
                    SimpleBulletPoint("Not be prohibited from using our services under applicable law")
                    SimpleBulletPoint("Not have been previously banned from our platform")
                }
            }

            LegalSection(title: "Account Registration") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("When creating an account, you agree to:")
                        .font(.subheadline)
                    SimpleBulletPoint("Provide accurate, current, and complete information")
                    SimpleBulletPoint("Maintain the security of your account credentials")
                    SimpleBulletPoint("Promptly update any changes to your information")
                    SimpleBulletPoint("Accept responsibility for all activities under your account")
                    SimpleBulletPoint("Use only one account per person")
                }
            }

            LegalSection(title: "User Conduct") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You agree NOT to:")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    SimpleBulletPoint("Harass, abuse, or harm other users")
                    SimpleBulletPoint("Post false, misleading, or fraudulent content")
                    SimpleBulletPoint("Upload illegal, obscene, or offensive material")
                    SimpleBulletPoint("Impersonate another person or entity")
                    SimpleBulletPoint("Use the service for commercial purposes without permission")
                    SimpleBulletPoint("Attempt to access other users' accounts")
                    SimpleBulletPoint("Transmit viruses, malware, or harmful code")
                    SimpleBulletPoint("Scrape, collect, or harvest user data")
                    SimpleBulletPoint("Circumvent security or access restrictions")
                    SimpleBulletPoint("Violate any applicable laws or regulations")
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

            LegalSection(title: "Premium Services & Subscriptions") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Celestia offers premium subscription features. By purchasing a subscription, you agree to the following:")
                        .font(.subheadline)

                    LegalSubsection(title: "Billing & Payment") {
                        VStack(alignment: .leading, spacing: 4) {
                            SimpleBulletPoint("Payment is charged to your Apple ID account at confirmation of purchase")
                            SimpleBulletPoint("Prices are in US dollars unless otherwise stated")
                            SimpleBulletPoint("Prices may vary by location and are subject to change")
                        }
                    }

                    LegalSubsection(title: "Auto-Renewal Terms") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("YOUR SUBSCRIPTION WILL AUTOMATICALLY RENEW UNLESS AUTO-RENEW IS TURNED OFF AT LEAST 24 HOURS BEFORE THE END OF THE CURRENT BILLING PERIOD.")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                            SimpleBulletPoint("Your account will be charged for renewal within 24 hours prior to the end of the current period")
                            SimpleBulletPoint("The renewal charge will be the same as the initial subscription price unless you are notified of a price change")
                        }
                    }

                    LegalSubsection(title: "Managing Subscriptions") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("You may manage or cancel your subscription at any time through your Apple ID account settings:")
                                .font(.caption)
                            SimpleBulletPoint("Go to Settings > [Your Name] > Subscriptions on your iOS device")
                            SimpleBulletPoint("Select Celestia and choose Cancel Subscription")
                            SimpleBulletPoint("Cancellation takes effect at the end of the current billing period")
                        }
                    }

                    LegalSubsection(title: "Refund Policy") {
                        VStack(alignment: .leading, spacing: 4) {
                            SimpleBulletPoint("Refunds are subject to Apple's refund policy")
                            SimpleBulletPoint("No refunds for partial subscription periods")
                            SimpleBulletPoint("Request refunds through Apple at reportaproblem.apple.com")
                            Text("Deleting the app does not cancel your subscription.")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                    }

                    LegalSubsection(title: "Free Trials") {
                        VStack(alignment: .leading, spacing: 4) {
                            SimpleBulletPoint("Free trials automatically convert to paid subscriptions")
                            SimpleBulletPoint("Cancel before the trial ends to avoid charges")
                            SimpleBulletPoint("Unused portion of free trial is forfeited upon subscription purchase")
                        }
                    }
                }
            }

            LegalSection(title: "Virtual Items & Consumables") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Celestia may offer virtual items (such as Super Likes or Boosts) for purchase:")
                        .font(.subheadline)
                    SimpleBulletPoint("Virtual items have no cash value and cannot be exchanged for cash")
                    SimpleBulletPoint("Virtual items are non-refundable and non-transferable")
                    SimpleBulletPoint("Virtual items may expire or be modified at our discretion")
                    SimpleBulletPoint("Unused virtual items are forfeited upon account termination")
                    SimpleBulletPoint("We reserve the right to modify virtual item pricing and availability")
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

                    SimpleBulletPoint("Online dating involves inherent risks including meeting strangers")
                    SimpleBulletPoint("You are solely responsible for your interactions with other users")
                    SimpleBulletPoint("Celestia does not conduct criminal background checks on users")
                    SimpleBulletPoint("We cannot guarantee the identity, intentions, or conduct of any user")
                    SimpleBulletPoint("You should take appropriate safety precautions when meeting anyone in person")
                    SimpleBulletPoint("Any meetings or relationships that result from the app are at your own risk")
                }
            }

            LegalSection(title: "No Background Checks") {
                Text("CELESTIA DOES NOT CONDUCT CRIMINAL BACKGROUND CHECKS OR IDENTITY VERIFICATION ON ALL USERS. We are not responsible for the conduct of any user, whether online or offline. You are solely responsible for your safety and should exercise caution when communicating with or meeting other users.")
                    .font(.caption)
            }

            LegalSection(title: "Age Verification Limitations") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("IMPORTANT NOTICE REGARDING AGE VERIFICATION:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    Text("While we require users to confirm they are 18 years or older, Celestia cannot independently verify the age of all users. We rely on user-provided information and representations. If you become aware of any user who is under 18, please report them immediately to support@celestia.app.")
                        .font(.caption)
                }
            }

            LegalSection(title: "FOSTA-SESTA Compliance") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Celestia has zero tolerance for sex trafficking, prostitution, or any form of sexual exploitation. In compliance with the Allow States and Victims to Fight Online Sex Trafficking Act (FOSTA) and the Stop Enabling Sex Traffickers Act (SESTA):")
                        .font(.subheadline)
                    SimpleBulletPoint("We actively monitor and remove content that promotes or facilitates sex trafficking")
                    SimpleBulletPoint("We cooperate fully with law enforcement investigations")
                    SimpleBulletPoint("Users who violate these provisions will be immediately banned and reported to authorities")
                    SimpleBulletPoint("We maintain records as required by 18 U.S.C. § 2257")
                    Text("If you witness any suspicious activity, report it immediately to support@celestia.app or contact the National Human Trafficking Hotline at 1-888-373-7888.")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.top, 4)
                }
            }

            LegalSection(title: "User-Generated Content Disclaimer") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Celestia is a platform that hosts user-generated content. We do not endorse, verify, or guarantee the accuracy, completeness, or reliability of any content posted by users, including but not limited to:")
                        .font(.subheadline)
                    SimpleBulletPoint("Profile information, photos, and biographical details")
                    SimpleBulletPoint("Messages and communications between users")
                    SimpleBulletPoint("Claims about identity, occupation, or personal circumstances")
                    SimpleBulletPoint("Any representations made by users about themselves")
                    Text("Content posted by users represents the views and opinions of those users only and does not represent the views of Celestia. We are not responsible for any user content and disclaim all liability arising from user-generated content.")
                        .font(.caption)
                        .padding(.top, 4)
                }
            }

            LegalSection(title: "Content Moderation") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("While we employ content moderation measures, we cannot review all content in real-time. You acknowledge that:")
                        .font(.subheadline)
                    SimpleBulletPoint("Offensive, harmful, or inappropriate content may appear before it is removed")
                    SimpleBulletPoint("Automated systems may not catch all violations")
                    SimpleBulletPoint("We are not liable for content that appears temporarily before moderation")
                    SimpleBulletPoint("You should report any violating content immediately")
                }
            }

            LegalSection(title: "No Professional Advice") {
                Text("Celestia does not provide professional advice of any kind, including but not limited to legal, medical, psychological, financial, or relationship counseling. Any information provided through the app is for general informational purposes only and should not be relied upon as professional advice. Always seek the advice of qualified professionals for specific concerns.")
                    .font(.caption)
            }

            LegalSection(title: "Third-Party Trademarks") {
                Text("All third-party trademarks, service marks, logos, and trade names referenced in this app are the property of their respective owners. Reference to any third-party products, services, or other information does not constitute or imply endorsement, sponsorship, or recommendation by Celestia or any affiliation with such third parties. Apple, the Apple logo, iPhone, and iOS are trademarks of Apple Inc., registered in the U.S. and other countries. App Store is a service mark of Apple Inc.")
                    .font(.caption)
            }

            LegalSection(title: "User Representations") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("By using Celestia, you represent and warrant that:")
                        .font(.subheadline)
                    SimpleBulletPoint("You are at least 18 years old")
                    SimpleBulletPoint("You are legally permitted to use the service in your jurisdiction")
                    SimpleBulletPoint("You have not been convicted of a felony or sex crime")
                    SimpleBulletPoint("You are not required to register as a sex offender")
                    SimpleBulletPoint("All information you provide is accurate and truthful")
                    SimpleBulletPoint("You will comply with all applicable laws while using the service")
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

                    SimpleBulletPoint("The accuracy or reliability of user profiles")
                    SimpleBulletPoint("That you will find a compatible match")
                    SimpleBulletPoint("Uninterrupted or error-free service")
                    SimpleBulletPoint("The conduct of other users")
                }
            }

            LegalSection(title: "Limitation of Liability") {
                Text("TO THE MAXIMUM EXTENT PERMITTED BY LAW, CELESTIA SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES ARISING FROM YOUR USE OF THE SERVICE, INCLUDING DAMAGES FOR LOSS OF PROFITS, DATA, OR OTHER INTANGIBLE LOSSES.")
                    .font(.caption)
            }

            LegalSection(title: "Binding Arbitration Agreement") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("PLEASE READ THIS SECTION CAREFULLY. IT AFFECTS YOUR LEGAL RIGHTS.")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.red)

                    Text("You and Celestia agree that any dispute, claim, or controversy arising out of or relating to these Terms or your use of the Service shall be resolved exclusively through final and binding arbitration, rather than in court.")
                        .font(.caption)

                    LegalSubsection(title: "Arbitration Rules") {
                        VStack(alignment: .leading, spacing: 4) {
                            SimpleBulletPoint("Arbitration shall be administered by the American Arbitration Association (AAA) under its Consumer Arbitration Rules")
                            SimpleBulletPoint("The arbitration will be conducted in the English language")
                            SimpleBulletPoint("The arbitrator's decision shall be final and binding")
                            SimpleBulletPoint("Judgment on the award may be entered in any court of competent jurisdiction")
                        }
                    }

                    LegalSubsection(title: "Arbitration Fees") {
                        Text("For claims under $10,000, Celestia will reimburse your filing fees and pay the arbitrator's fees. For claims above $10,000, fees will be allocated according to AAA rules.")
                            .font(.caption)
                    }

                    LegalSubsection(title: "Opt-Out Right") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("You may opt out of this arbitration agreement within 30 days of creating your account by sending written notice to:")
                                .font(.caption)
                            Text("legal@celestia.app")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("Include your name, email, and a statement that you wish to opt out of the arbitration agreement.")
                                .font(.caption)
                        }
                    }

                    LegalSubsection(title: "Exceptions") {
                        Text("Either party may bring claims in small claims court if eligible. Either party may seek injunctive relief in court for intellectual property infringement or unauthorized access to the Service.")
                            .font(.caption)
                    }
                }
            }

            LegalSection(title: "Class Action Waiver") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("YOU AND CELESTIA AGREE THAT EACH MAY BRING CLAIMS AGAINST THE OTHER ONLY IN YOUR OR ITS INDIVIDUAL CAPACITY AND NOT AS A PLAINTIFF OR CLASS MEMBER IN ANY PURPORTED CLASS, CONSOLIDATED, OR REPRESENTATIVE ACTION.")
                        .font(.caption)
                        .fontWeight(.semibold)

                    Text("The arbitrator may not consolidate more than one person's claims and may not preside over any form of representative or class proceeding. If this class action waiver is found to be unenforceable, then the entirety of the arbitration agreement shall be null and void.")
                        .font(.caption)
                }
            }

            LegalSection(title: "Governing Law & Jurisdiction") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("These Terms shall be governed by and construed in accordance with the laws of the State of Delaware, United States, without regard to conflict of law principles.")
                        .font(.subheadline)

                    Text("For any disputes not subject to arbitration, you agree to submit to the exclusive jurisdiction of the state and federal courts located in Delaware.")
                        .font(.caption)
                }
            }

            LegalSection(title: "Electronic Communications Consent") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("By creating an account, you consent to receive electronic communications from us, including:")
                        .font(.subheadline)
                    SimpleBulletPoint("Account notifications and security alerts")
                    SimpleBulletPoint("Service updates and policy changes")
                    SimpleBulletPoint("Match notifications and messages from other users")
                    SimpleBulletPoint("Marketing communications (which you may opt out of)")

                    Text("These electronic communications satisfy any legal requirement that communications be in writing. You may withdraw consent by deleting your account.")
                        .font(.caption)
                        .padding(.top, 4)
                }
            }

            LegalSection(title: "Changes to Terms") {
                Text("We may modify these Terms at any time. Material changes will be notified through the app or email. Continued use after changes constitutes acceptance of the modified terms.")
            }

            LegalSection(title: "Copyright & DMCA") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("If you believe content on Celestia infringes your copyright, please send a DMCA notice to support@celestia.app including:")
                        .font(.subheadline)
                    SimpleBulletPoint("Identification of the copyrighted work")
                    SimpleBulletPoint("Identification of the infringing material")
                    SimpleBulletPoint("Your contact information")
                    SimpleBulletPoint("A statement of good faith belief")
                    SimpleBulletPoint("A statement of accuracy under penalty of perjury")
                    SimpleBulletPoint("Your physical or electronic signature")
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

            LegalSection(title: "Force Majeure") {
                Text("Celestia shall not be liable for any failure or delay in performance resulting from causes beyond our reasonable control, including but not limited to: acts of God, natural disasters, pandemic, war, terrorism, riots, embargoes, acts of civil or military authorities, fire, floods, accidents, strikes, labor disputes, equipment failures, internet or telecommunications failures, or actions of third-party service providers.")
                    .font(.caption)
            }

            LegalSection(title: "Third-Party Services") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Celestia may contain links to or integrate with third-party services. We are not responsible for:")
                        .font(.subheadline)
                    SimpleBulletPoint("The content, accuracy, or practices of third-party websites or services")
                    SimpleBulletPoint("Any damages arising from your use of third-party services")
                    SimpleBulletPoint("The privacy practices of third parties")

                    Text("Your use of third-party services is governed by their respective terms and privacy policies.")
                        .font(.caption)
                        .padding(.top, 4)
                }
            }

            LegalSection(title: "Export Controls") {
                Text("You agree to comply with all applicable export and import laws and regulations. You represent that you are not located in, under the control of, or a national or resident of any country subject to US trade sanctions, and you are not on any government restricted party list.")
                    .font(.caption)
            }

            LegalSection(title: "Assignment") {
                Text("You may not assign or transfer these Terms or your rights hereunder without our prior written consent. Celestia may assign these Terms without restriction. Subject to the foregoing, these Terms will bind and inure to the benefit of the parties and their successors and assigns.")
                    .font(.caption)
            }

            LegalSection(title: "Survival") {
                Text("Sections relating to intellectual property, disclaimers, limitation of liability, indemnification, arbitration, and any other provisions that by their nature should survive termination shall survive the termination of these Terms.")
                    .font(.caption)
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
                    SimpleBulletPoint("Use your real name and recent photos")
                    SimpleBulletPoint("Be honest about your age, relationship status, and intentions")
                    SimpleBulletPoint("Don't impersonate others or create fake profiles")
                    SimpleBulletPoint("Represent yourself accurately in your bio and interests")
                }
            }

            LegalSection(title: "Be Respectful") {
                VStack(alignment: .leading, spacing: 8) {
                    SimpleBulletPoint("Treat all users with kindness and dignity")
                    SimpleBulletPoint("Accept rejection gracefully - not everyone will be a match")
                    SimpleBulletPoint("Avoid discriminatory language or behavior")
                    SimpleBulletPoint("Respect boundaries and privacy")
                    SimpleBulletPoint("Communicate honestly and clearly")
                }
            }

            LegalSection(title: "Keep It Safe") {
                VStack(alignment: .leading, spacing: 8) {
                    SimpleBulletPoint("Never share personal information publicly")
                    SimpleBulletPoint("Report suspicious or harmful behavior")
                    SimpleBulletPoint("Meet in public places for first dates")
                    SimpleBulletPoint("Trust your instincts - if something feels wrong, report it")
                    SimpleBulletPoint("Don't share financial information or send money")
                }
            }

            LegalSection(title: "Prohibited Content") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("The following content is strictly prohibited:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)

                    SimpleBulletPoint("Nudity, sexual content, or pornography")
                    SimpleBulletPoint("Violence, threats, or harassment")
                    SimpleBulletPoint("Hate speech or discrimination")
                    SimpleBulletPoint("Spam, scams, or commercial solicitation")
                    SimpleBulletPoint("Illegal activities or substances")
                    SimpleBulletPoint("Content involving minors")
                    SimpleBulletPoint("Copyrighted material without permission")
                }
            }

            LegalSection(title: "Prohibited Behaviors") {
                VStack(alignment: .leading, spacing: 8) {
                    SimpleBulletPoint("Harassment, bullying, or stalking")
                    SimpleBulletPoint("Catfishing or identity fraud")
                    SimpleBulletPoint("Soliciting money or promoting businesses")
                    SimpleBulletPoint("Attempting to meet minors")
                    SimpleBulletPoint("Using the platform while in a committed relationship (without partner's knowledge)")
                    SimpleBulletPoint("Mass messaging or spamming users")
                    SimpleBulletPoint("Sharing others' private information")
                }
            }

            LegalSection(title: "Photo Guidelines") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Acceptable Photos:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    SimpleBulletPoint("Clear photos of your face")
                    SimpleBulletPoint("Recent photos (within the last 2 years)")
                    SimpleBulletPoint("Photos that represent you authentically")

                    Text("Not Allowed:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .padding(.top, 8)
                    SimpleBulletPoint("Group photos as your main photo")
                    SimpleBulletPoint("Photos with nudity or suggestive content")
                    SimpleBulletPoint("Photos of someone else")
                    SimpleBulletPoint("Heavily filtered or misleading photos")
                    SimpleBulletPoint("Photos with contact information")
                }
            }

            LegalSection(title: "Reporting Violations") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("If you encounter violations, please report them immediately:")
                        .font(.subheadline)
                    SimpleBulletPoint("Use the Report button on any profile or message")
                    SimpleBulletPoint("Provide details about the violation")
                    SimpleBulletPoint("Block users who make you uncomfortable")
                    SimpleBulletPoint("Contact support for urgent safety concerns")
                }
            }

            LegalSection(title: "Enforcement") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Violations may result in:")
                        .font(.subheadline)
                    SimpleBulletPoint("Warning notification")
                    SimpleBulletPoint("Temporary account suspension")
                    SimpleBulletPoint("Permanent account ban")
                    SimpleBulletPoint("Reporting to law enforcement (for serious violations)")
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
                    SimpleBulletPoint("Never share your home address, workplace, or daily routine")
                    SimpleBulletPoint("Use our in-app messaging until you feel comfortable")
                    SimpleBulletPoint("Don't share financial information or social security numbers")
                    SimpleBulletPoint("Be cautious about sharing your full name early on")
                    SimpleBulletPoint("Consider using a Google Voice number instead of your real phone number")
                }
            }

            LegalSection(title: "Verify Before You Meet") {
                VStack(alignment: .leading, spacing: 8) {
                    SimpleBulletPoint("Video chat before meeting in person")
                    SimpleBulletPoint("Look for consistent information in their profile")
                    SimpleBulletPoint("Do a reverse image search on their photos")
                    SimpleBulletPoint("Check their social media profiles if available")
                    SimpleBulletPoint("Trust your gut - if something feels off, it probably is")
                }
            }

            LegalSection(title: "Meeting In Person") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("For your first meeting:")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    SimpleBulletPoint("Always meet in a public place")
                    SimpleBulletPoint("Tell a friend or family member your plans")
                    SimpleBulletPoint("Share your location with someone you trust")
                    SimpleBulletPoint("Arrange your own transportation")
                    SimpleBulletPoint("Don't leave drinks unattended")
                    SimpleBulletPoint("Stay sober and alert")
                    SimpleBulletPoint("Have an exit plan")
                }
            }

            LegalSection(title: "Red Flags to Watch For") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Be cautious if someone:")
                        .font(.subheadline)
                        .foregroundColor(.red)

                    SimpleBulletPoint("Asks for money or financial help")
                    SimpleBulletPoint("Refuses to video chat or meet in public")
                    SimpleBulletPoint("Has inconsistent stories or information")
                    SimpleBulletPoint("Pressures you to move off the app quickly")
                    SimpleBulletPoint("Asks for explicit photos")
                    SimpleBulletPoint("Claims to be in love very quickly")
                    SimpleBulletPoint("Makes you feel uncomfortable or unsafe")
                    SimpleBulletPoint("Claims to be in the military overseas needing money")
                }
            }

            LegalSection(title: "Romance Scam Warning Signs") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scammers often:")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    SimpleBulletPoint("Claim to be overseas (military, business)")
                    SimpleBulletPoint("Express strong feelings very quickly")
                    SimpleBulletPoint("Create emergencies requiring money")
                    SimpleBulletPoint("Ask for gift cards or wire transfers")
                    SimpleBulletPoint("Have professional model-quality photos")
                    SimpleBulletPoint("Can never video chat")

                    Text("NEVER send money to someone you haven't met in person.")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .padding(.top, 8)
                }
            }

            LegalSection(title: "If You Feel Unsafe") {
                VStack(alignment: .leading, spacing: 8) {
                    SimpleBulletPoint("Trust your instincts and leave immediately")
                    SimpleBulletPoint("Call 911 if you're in immediate danger")
                    SimpleBulletPoint("Report the user on Celestia")
                    SimpleBulletPoint("Block the person on all platforms")
                    SimpleBulletPoint("Save any threatening messages as evidence")
                    SimpleBulletPoint("Contact local authorities if needed")
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
                    SimpleBulletPoint("Report suspicious profiles immediately")
                    SimpleBulletPoint("Report harassment or inappropriate messages")
                    SimpleBulletPoint("Contact support@celestia.app for urgent concerns")
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
                        SimpleBulletPoint("Authentication tokens to keep you logged in")
                        SimpleBulletPoint("Session data for app functionality")
                        SimpleBulletPoint("Security tokens to protect your account")
                        SimpleBulletPoint("Preferences you've set in the app")
                    }

                    LegalSubsection(title: "Analytics Data") {
                        SimpleBulletPoint("App usage patterns and feature interactions")
                        SimpleBulletPoint("Crash reports and performance metrics")
                        SimpleBulletPoint("Device type and operating system")
                        SimpleBulletPoint("General location data")
                    }

                    LegalSubsection(title: "Advertising Identifiers") {
                        SimpleBulletPoint("IDFA (iOS Identifier for Advertisers)")
                        SimpleBulletPoint("Used for measuring ad effectiveness")
                        SimpleBulletPoint("Can be limited in device settings")
                    }
                }
            }

            LegalSection(title: "How We Use This Data") {
                VStack(alignment: .leading, spacing: 8) {
                    SimpleBulletPoint("Maintain your logged-in session")
                    SimpleBulletPoint("Remember your preferences and settings")
                    SimpleBulletPoint("Analyze and improve our services")
                    SimpleBulletPoint("Detect and prevent fraud")
                    SimpleBulletPoint("Measure the effectiveness of marketing")
                    SimpleBulletPoint("Provide personalized experiences")
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

                    SimpleBulletPoint("iOS Settings > Privacy > Tracking")
                    SimpleBulletPoint("iOS Settings > Privacy > Analytics & Improvements")
                    SimpleBulletPoint("In-app privacy settings")
                    SimpleBulletPoint("Deleting the app removes local data")
                }
            }

            LegalSection(title: "Data Retention") {
                VStack(alignment: .leading, spacing: 8) {
                    SimpleBulletPoint("Session data: Until you log out or session expires")
                    SimpleBulletPoint("Analytics data: Up to 14 months")
                    SimpleBulletPoint("Crash reports: Up to 90 days")
                    SimpleBulletPoint("Account data: Until account deletion")
                }
            }

            LegalSection(title: "CCPA Rights (California)") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("California residents have the right to:")
                        .font(.subheadline)
                    SimpleBulletPoint("Know what data we collect")
                    SimpleBulletPoint("Delete your personal information")
                    SimpleBulletPoint("Opt-out of the sale of personal information")
                    SimpleBulletPoint("Non-discrimination for exercising rights")

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
                    SimpleBulletPoint("Access your personal data")
                    SimpleBulletPoint("Rectify inaccurate data")
                    SimpleBulletPoint("Erase your data (right to be forgotten)")
                    SimpleBulletPoint("Restrict processing")
                    SimpleBulletPoint("Data portability")
                    SimpleBulletPoint("Object to processing")
                    SimpleBulletPoint("Withdraw consent at any time")
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

struct SimpleBulletPoint: View {
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

// MARK: - EULA Content

extension LegalDocumentView {
    private var eulaContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            LegalSection(title: "End User License Agreement") {
                Text("This End User License Agreement (\"EULA\") is a legal agreement between you and Celestia for the use of the Celestia mobile application. By installing or using Celestia, you agree to be bound by the terms of this EULA.")
            }

            LegalSection(title: "License Grant") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Subject to your compliance with this EULA, Celestia grants you a limited, non-exclusive, non-transferable, revocable license to:")
                        .font(.subheadline)
                    SimpleBulletPoint("Download and install the app on devices you own or control")
                    SimpleBulletPoint("Use the app for personal, non-commercial purposes")
                    SimpleBulletPoint("Access the features available to your account type")

                    Text("This license does not allow you to use the app on any device you do not own or control, and you may not distribute or make the app available over a network.")
                        .font(.caption)
                        .padding(.top, 4)
                }
            }

            LegalSection(title: "License Restrictions") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You agree NOT to:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    SimpleBulletPoint("Copy, modify, or distribute the app or its content")
                    SimpleBulletPoint("Reverse engineer, decompile, or disassemble the app")
                    SimpleBulletPoint("Remove or alter any proprietary notices or labels")
                    SimpleBulletPoint("Use the app for any illegal or unauthorized purpose")
                    SimpleBulletPoint("Sublicense, rent, lease, or loan the app to third parties")
                    SimpleBulletPoint("Use automated systems to access the app (bots, scrapers)")
                    SimpleBulletPoint("Circumvent or disable security features")
                }
            }

            LegalSection(title: "Intellectual Property Rights") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Celestia and its licensors own all intellectual property rights in the app, including:")
                        .font(.subheadline)
                    SimpleBulletPoint("Software code, algorithms, and architecture")
                    SimpleBulletPoint("User interface design and visual elements")
                    SimpleBulletPoint("Trademarks, logos, and brand identity")
                    SimpleBulletPoint("Documentation and other materials")

                    Text("All rights not expressly granted in this EULA are reserved by Celestia.")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.top, 4)
                }
            }

            LegalSection(title: "Open Source Components") {
                Text("Celestia may include open source software components subject to their respective licenses. A list of open source components and their licenses is available in the app settings. Open source licenses take precedence over this EULA for those specific components.")
            }

            LegalSection(title: "Updates and Modifications") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Celestia may release updates that modify the app's functionality:")
                        .font(.subheadline)
                    SimpleBulletPoint("Updates may be downloaded and installed automatically")
                    SimpleBulletPoint("Some updates may be required to continue using the app")
                    SimpleBulletPoint("We may discontinue features with or without notice")
                    SimpleBulletPoint("Your continued use after updates constitutes acceptance")
                }
            }

            LegalSection(title: "Data Collection & Privacy") {
                Text("Your use of the app is also governed by our Privacy Policy, which describes how we collect, use, and protect your personal information. By using the app, you consent to our data practices as described in the Privacy Policy.")
            }

            LegalSection(title: "Apple App Store Terms") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("If you downloaded the app from Apple's App Store, you also agree to:")
                        .font(.subheadline)
                    SimpleBulletPoint("Apple's Licensed Application End User License Agreement")
                    SimpleBulletPoint("Apple's App Store Terms of Service")

                    Text("In case of conflict between this EULA and Apple's terms regarding Apple-specific provisions, Apple's terms shall govern.")
                        .font(.caption)
                        .padding(.top, 4)
                }
            }

            LegalSection(title: "Third-Party Acknowledgments") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You acknowledge that:")
                        .font(.subheadline)
                    SimpleBulletPoint("Apple is not responsible for the app or its content")
                    SimpleBulletPoint("Apple has no obligation to provide maintenance or support")
                    SimpleBulletPoint("Apple is not liable for any claims related to the app")
                    SimpleBulletPoint("Apple is a third-party beneficiary of this EULA")
                }
            }

            LegalSection(title: "Termination") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("This EULA is effective until terminated. Your rights automatically terminate if you:")
                        .font(.subheadline)
                    SimpleBulletPoint("Fail to comply with any term of this EULA")
                    SimpleBulletPoint("Delete your account or uninstall the app")

                    Text("Upon termination, you must cease all use of the app and delete all copies.")
                        .font(.caption)
                        .padding(.top, 4)
                }
            }

            LegalSection(title: "Disclaimer of Warranties") {
                Text("THE APP IS PROVIDED \"AS IS\" AND \"AS AVAILABLE\" WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT. CELESTIA DOES NOT WARRANT THAT THE APP WILL BE UNINTERRUPTED, ERROR-FREE, OR FREE OF HARMFUL COMPONENTS.")
                    .font(.caption)
            }

            LegalSection(title: "Limitation of Liability") {
                Text("TO THE FULLEST EXTENT PERMITTED BY LAW, CELESTIA SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES ARISING OUT OF OR RELATED TO YOUR USE OF THE APP, REGARDLESS OF WHETHER SUCH DAMAGES ARE BASED ON CONTRACT, TORT, STRICT LIABILITY, OR ANY OTHER THEORY.")
                    .font(.caption)
            }

            LegalSection(title: "Export Compliance") {
                Text("You represent and warrant that you are not located in a country subject to a U.S. Government embargo or designated as a \"terrorist supporting\" country, and you are not listed on any U.S. Government list of prohibited or restricted parties.")
            }

            LegalSection(title: "Government End Users") {
                Text("If you are a U.S. Government end user, the app is a \"Commercial Item\" as defined in 48 C.F.R. §2.101, and is licensed with only those rights granted to all other end users pursuant to this EULA.")
                    .font(.caption)
            }

            LegalSection(title: "Contact Information") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("For questions about this EULA:")
                        .font(.subheadline)
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.indigo)
                        Text("legal@celestia.app")
                    }
                    .font(.subheadline)
                }
            }
        }
    }
}

// MARK: - Accessibility Statement Content

extension LegalDocumentView {
    private var accessibilityContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            LegalSection(title: "Our Commitment to Accessibility") {
                Text("Celestia is committed to ensuring digital accessibility for people with disabilities. We continually improve the user experience for everyone and apply the relevant accessibility standards to ensure we provide equal access to all users.")
            }

            LegalSection(title: "Accessibility Standards") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("We aim to conform to the following standards:")
                        .font(.subheadline)
                    SimpleBulletPoint("Web Content Accessibility Guidelines (WCAG) 2.1 Level AA")
                    SimpleBulletPoint("Apple's Human Interface Guidelines for Accessibility")
                    SimpleBulletPoint("Section 508 of the Rehabilitation Act (where applicable)")
                    SimpleBulletPoint("Americans with Disabilities Act (ADA) requirements")
                }
            }

            LegalSection(title: "Accessibility Features") {
                VStack(alignment: .leading, spacing: 12) {
                    LegalSubsection(title: "VoiceOver Support") {
                        VStack(alignment: .leading, spacing: 4) {
                            SimpleBulletPoint("Full VoiceOver compatibility throughout the app")
                            SimpleBulletPoint("Descriptive labels for all interactive elements")
                            SimpleBulletPoint("Logical reading order and navigation")
                            SimpleBulletPoint("Meaningful image descriptions")
                        }
                    }

                    LegalSubsection(title: "Visual Accommodations") {
                        VStack(alignment: .leading, spacing: 4) {
                            SimpleBulletPoint("Support for Dynamic Type (adjustable text sizes)")
                            SimpleBulletPoint("High contrast color combinations")
                            SimpleBulletPoint("Respect for system-wide Dark Mode preferences")
                            SimpleBulletPoint("No reliance on color alone to convey information")
                        }
                    }

                    LegalSubsection(title: "Motor Accessibility") {
                        VStack(alignment: .leading, spacing: 4) {
                            SimpleBulletPoint("Support for Switch Control")
                            SimpleBulletPoint("Adequate touch target sizes (minimum 44x44 points)")
                            SimpleBulletPoint("No time-limited interactions required")
                            SimpleBulletPoint("Alternative navigation methods supported")
                        }
                    }

                    LegalSubsection(title: "Cognitive Accessibility") {
                        VStack(alignment: .leading, spacing: 4) {
                            SimpleBulletPoint("Clear and consistent navigation")
                            SimpleBulletPoint("Simple, understandable language")
                            SimpleBulletPoint("Predictable interface behavior")
                            SimpleBulletPoint("Support for Reduce Motion preference")
                        }
                    }
                }
            }

            LegalSection(title: "Assistive Technologies Supported") {
                VStack(alignment: .leading, spacing: 8) {
                    SimpleBulletPoint("VoiceOver screen reader")
                    SimpleBulletPoint("Voice Control")
                    SimpleBulletPoint("Switch Control")
                    SimpleBulletPoint("AssistiveTouch")
                    SimpleBulletPoint("Full Keyboard Access")
                    SimpleBulletPoint("Zoom magnification")
                    SimpleBulletPoint("Spoken Content (Speak Selection, Speak Screen)")
                }
            }

            LegalSection(title: "Known Limitations") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("We are working to address the following areas:")
                        .font(.subheadline)
                    SimpleBulletPoint("Some user-uploaded images may lack alternative text")
                    SimpleBulletPoint("Complex gesture interactions have keyboard alternatives being developed")
                    SimpleBulletPoint("Third-party content may not meet our accessibility standards")

                    Text("We are actively working to resolve these issues and improve accessibility across all features.")
                        .font(.caption)
                        .padding(.top, 4)
                }
            }

            LegalSection(title: "Accessibility Testing") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Our accessibility program includes:")
                        .font(.subheadline)
                    SimpleBulletPoint("Regular automated accessibility testing")
                    SimpleBulletPoint("Manual testing with assistive technologies")
                    SimpleBulletPoint("User feedback incorporation")
                    SimpleBulletPoint("Ongoing staff training on accessibility best practices")
                }
            }

            LegalSection(title: "Feedback & Assistance") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("We welcome your feedback on the accessibility of Celestia. If you encounter accessibility barriers or need assistance, please contact us:")
                        .font(.subheadline)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.teal)
                            Text("accessibility@celestia.app")
                        }
                        .font(.subheadline)

                        HStack {
                            Image(systemName: "phone")
                                .foregroundColor(.green)
                            Text("Relay service users: Please use your preferred relay service")
                        }
                        .font(.caption)
                    }

                    Text("When contacting us, please include:")
                        .font(.subheadline)
                        .padding(.top, 8)
                    SimpleBulletPoint("Description of the accessibility issue")
                    SimpleBulletPoint("The assistive technology you are using")
                    SimpleBulletPoint("Your device type and iOS version")
                    SimpleBulletPoint("Steps to reproduce the issue")
                }
            }

            LegalSection(title: "Response Time") {
                Text("We aim to respond to accessibility feedback within 5 business days and to resolve accessibility issues as quickly as possible. For urgent accessibility needs, please indicate \"Urgent\" in your subject line.")
            }

            LegalSection(title: "Alternative Formats") {
                Text("If you need this accessibility statement or other information in an alternative format (such as large print, audio, or braille), please contact us and we will do our best to accommodate your request.")
            }

            LegalSection(title: "Continuous Improvement") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("We are committed to continuous improvement of our accessibility:")
                        .font(.subheadline)
                    SimpleBulletPoint("Regular accessibility audits are conducted")
                    SimpleBulletPoint("User feedback is reviewed and incorporated")
                    SimpleBulletPoint("New features are designed with accessibility in mind")
                    SimpleBulletPoint("Development team receives ongoing accessibility training")
                }
            }

            LegalSection(title: "Legal Information") {
                Text("This statement was last updated on November 29, 2025. Celestia strives to comply with applicable accessibility laws and regulations. If you believe you have experienced discrimination based on disability in accessing our services, you may file a complaint with the appropriate regulatory authority in your jurisdiction.")
                    .font(.caption)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    LegalDocumentView(documentType: .privacyPolicy)
}
