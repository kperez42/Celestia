//
//  PremiumUpgradeView.swift
//  Celestia
//
//  Beautiful premium upgrade screen with features and pricing
//

import SwiftUI

struct PremiumUpgradeView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    
    @State private var selectedPlan: PremiumPlan = .monthly
    @State private var showPurchaseSuccess = false
    @State private var isProcessing = false
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero Header
                    heroHeader
                    
                    // Main Content
                    VStack(spacing: 30) {
                        // Features Section
                        featuresSection
                        
                        // Pricing Plans
                        pricingPlans
                        
                        // Testimonials
                        testimonialsSection
                        
                        // FAQ
                        faqSection
                        
                        // CTA Button
                        ctaButton
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
            .alert("Welcome to Premium! 🎉", isPresented: $showPurchaseSuccess) {
                Button("Start Exploring") {
                    dismiss()
                }
            } message: {
                Text("You now have unlimited access to all premium features!")
            }
        }
    }
    
    // MARK: - Hero Header
    
    private var heroHeader: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.9),
                    Color.pink.opacity(0.8),
                    Color.orange.opacity(0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 280)
            .overlay {
                // Animated circles
                GeometryReader { geometry in
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 200, height: 200)
                        .offset(x: -50, y: -50)
                    
                    Circle()
                        .fill(Color.yellow.opacity(0.15))
                        .frame(width: 150, height: 150)
                        .offset(x: geometry.size.width - 100, y: 50)
                    
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 100, height: 100)
                        .offset(x: geometry.size.width / 2, y: 150)
                }
            }
            
            // Content
            VStack(spacing: 20) {
                Spacer()
                
                // Crown icon with glow
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.3))
                        .frame(width: 100, height: 100)
                        .blur(radius: 20)
                    
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .yellow.opacity(0.5), radius: 10)
                }
                
                VStack(spacing: 8) {
                    Text("Upgrade to Premium")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Unlock unlimited connections worldwide")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.95))
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .padding(.vertical, 30)
        }
    }
    
    // MARK: - Features Section
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Premium Features")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 15) {
                FeatureRow(
                    icon: "infinity",
                    title: "Unlimited Likes",
                    description: "Like as many profiles as you want",
                    color: .purple
                )
                
                FeatureRow(
                    icon: "eye.fill",
                    title: "See Who Likes You",
                    description: "Know who's interested before you swipe",
                    color: .pink
                )
                
                FeatureRow(
                    icon: "arrow.uturn.left",
                    title: "Rewind Swipes",
                    description: "Undo accidental passes instantly",
                    color: .blue
                )
                
                FeatureRow(
                    icon: "sparkles",
                    title: "5 Super Likes/Day",
                    description: "Stand out and get 3x more matches",
                    color: .cyan
                )
                
                FeatureRow(
                    icon: "globe.americas.fill",
                    title: "Passport Mode",
                    description: "Match with people anywhere in the world",
                    color: .green
                )
                
                FeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Advanced Insights",
                    description: "See detailed profile analytics",
                    color: .orange
                )
                
                FeatureRow(
                    icon: "bolt.fill",
                    title: "Profile Boost",
                    description: "Get 10x more visibility monthly",
                    color: .yellow
                )
                
                FeatureRow(
                    icon: "sparkle",
                    title: "Ad-Free Experience",
                    description: "Browse without interruptions",
                    color: .indigo
                )
            }
        }
        .padding(25)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
    
    // MARK: - Pricing Plans
    
    private var pricingPlans: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Choose Your Plan")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 15) {
                PricingCard(
                    plan: .annual,
                    isSelected: selectedPlan == .annual,
                    onSelect: { selectedPlan = .annual },
                    badge: "BEST VALUE - Save 50%"
                )
                
                PricingCard(
                    plan: .sixMonth,
                    isSelected: selectedPlan == .sixMonth,
                    onSelect: { selectedPlan = .sixMonth },
                    badge: "POPULAR"
                )
                
                PricingCard(
                    plan: .monthly,
                    isSelected: selectedPlan == .monthly,
                    onSelect: { selectedPlan = .monthly }
                )
            }
        }
    }
    
    // MARK: - Testimonials
    
    private var testimonialsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Success Stories")
                .font(.title2)
                .fontWeight(.bold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    TestimonialCard(
                        name: "Sarah & James",
                        age: "28 & 30",
                        location: "London, UK",
                        quote: "We matched through Passport mode while I was traveling. Now we're engaged! 💍",
                        imageName: "person.2.fill"
                    )
                    
                    TestimonialCard(
                        name: "Maria & Carlos",
                        age: "25 & 27",
                        location: "Barcelona, Spain",
                        quote: "Premium helped me find my soulmate in just 2 weeks. Worth every penny!",
                        imageName: "person.2.fill"
                    )
                    
                    TestimonialCard(
                        name: "Alex & Jordan",
                        age: "31 & 29",
                        location: "New York, USA",
                        quote: "Being able to see who liked me saved so much time. Best decision ever!",
                        imageName: "person.2.fill"
                    )
                }
                .padding(.horizontal, 5)
            }
        }
    }
    
    // MARK: - FAQ Section
    
    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Frequently Asked Questions")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 5)
            
            VStack(spacing: 12) {
                FAQItem(
                    question: "Can I cancel anytime?",
                    answer: "Yes! You can cancel your subscription at any time with no penalties. Your premium features will remain active until the end of your billing period."
                )
                
                FAQItem(
                    question: "What payment methods do you accept?",
                    answer: "We accept all major credit cards, debit cards, Apple Pay, and Google Pay for your convenience."
                )
                
                FAQItem(
                    question: "Is there a free trial?",
                    answer: "New users get a 7-day free trial of Premium to explore all features risk-free!"
                )
                
                FAQItem(
                    question: "What happens if I don't renew?",
                    answer: "Your account will revert to the free tier, but all your matches and conversations will be preserved."
                )
            }
        }
        .padding(25)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
    
    // MARK: - CTA Button
    
    private var ctaButton: some View {
        VStack(spacing: 15) {
            Button {
                purchasePremium()
            } label: {
                HStack(spacing: 12) {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "crown.fill")
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start Free Trial")
                                .font(.headline)
                            Text("\(selectedPlan.price) after 7 days")
                                .font(.caption)
                                .opacity(0.9)
                        }
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.pink, Color.orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .purple.opacity(0.4), radius: 15, y: 8)
            }
            .disabled(isProcessing)
            
            Text("Billed as \(selectedPlan.totalPrice) • Cancel anytime")
                .font(.caption)
                .foregroundColor(.gray)
            
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                Text("Secure payment powered by Stripe")
                    .font(.caption2)
            }
            .foregroundColor(.gray)
        }
    }
    
    // MARK: - Actions
    
    private func purchasePremium() {
        isProcessing = true
        
        // Simulate purchase process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isProcessing = false
            
            // TODO: Integrate with actual payment processor (Stripe, RevenueCat, etc.)
            // For now, just update user status locally
            Task {
                guard var user = authService.currentUser else { return }
                user.isPremium = true
                user.premiumTier = selectedPlan.rawValue
                user.subscriptionExpiryDate = selectedPlan.expiryDate
                
                do {
                    try await authService.updateUser(user)
                    showPurchaseSuccess = true
                } catch {
                    print("Error updating user: \(error)")
                }
            }
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Pricing Card

struct PricingCard: View {
    let plan: PremiumPlan
    let isSelected: Bool
    let onSelect: () -> Void
    var badge: String? = nil
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                // Badge
                if let badge = badge {
                    Text(badge)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [Color.green, Color.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8, corners: [.topLeft, .topRight])
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(plan.name)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(plan.price)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(isSelected ? .purple : .primary)
                            
                            Text("/ " + plan.period)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        if plan.savings > 0 {
                            Text("Save \(plan.savings)%")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                    
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .stroke(
                                isSelected ?
                                LinearGradient(
                                    colors: [Color.purple, Color.pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.gray.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 28, height: 28)
                        
                        if isSelected {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.purple, Color.pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 16, height: 16)
                        }
                    }
                }
                .padding(20)
            }
            .background(
                isSelected ?
                LinearGradient(
                    colors: [Color.purple.opacity(0.05), Color.pink.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ) :
                LinearGradient(
                    colors: [Color.white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ?
                        LinearGradient(
                            colors: [Color.purple, Color.pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.gray.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .shadow(
                color: isSelected ? Color.purple.opacity(0.2) : Color.black.opacity(0.05),
                radius: isSelected ? 15 : 5
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Testimonial Card

struct TestimonialCard: View {
    let name: String
    let age: String
    let location: String
    let quote: String
    let imageName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.6), Color.pink.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: imageName)
                        .foregroundColor(.white)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.headline)
                    
                    Text("\(age) • \(location)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Text(quote)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineSpacing(4)
            
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding(20)
        .frame(width: 280)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

// MARK: - FAQ Item

struct FAQItem: View {
    let question: String
    let answer: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(question)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            if isExpanded {
                Text(answer)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Premium Plan Enum

enum PremiumPlan: String, CaseIterable {
    case monthly = "monthly"
    case sixMonth = "6-month"
    case annual = "annual"
    
    var name: String {
        switch self {
        case .monthly: return "Monthly"
        case .sixMonth: return "6 Months"
        case .annual: return "Annual"
        }
    }
    
    var price: String {
        switch self {
        case .monthly: return "$19.99"
        case .sixMonth: return "$14.99"
        case .annual: return "$9.99"
        }
    }
    
    var period: String {
        switch self {
        case .monthly: return "month"
        case .sixMonth: return "month"
        case .annual: return "month"
        }
    }
    
    var totalPrice: String {
        switch self {
        case .monthly: return "$19.99/month"
        case .sixMonth: return "$89.94 ($14.99/month)"
        case .annual: return "$119.88 ($9.99/month)"
        }
    }
    
    var savings: Int {
        switch self {
        case .monthly: return 0
        case .sixMonth: return 25
        case .annual: return 50
        }
    }
    
    var expiryDate: Date {
        let calendar = Calendar.current
        switch self {
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        case .sixMonth:
            return calendar.date(byAdding: .month, value: 6, to: Date()) ?? Date()
        case .annual:
            return calendar.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        }
    }
}

// MARK: - Custom Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PremiumUpgradeView()
            .environmentObject(AuthService.shared)
    }
}
