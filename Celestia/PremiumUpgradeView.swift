//
//  PremiumUpgradeView.swift - IMPROVED VERSION
//  Celestia
//
//  ✨ Enhanced with real IAP, better UX, and proper error handling
//

import SwiftUI
import StoreKit
import FirebaseFirestore

struct PremiumUpgradeView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @StateObject private var storeManager = StoreManager.shared
    
    @State private var selectedPlan: PremiumPlan = .annual
    @State private var showPurchaseSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isProcessing = false
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Hero Header
                        heroHeader
                        
                        // Main Content
                        VStack(spacing: 30) {
                            // Social Proof
                            socialProof
                            
                            // Features Section
                            featuresSection
                            
                            // Pricing Plans
                            pricingPlans
                            
                            // Testimonials
                            testimonialsSection
                            
                            // FAQ
                            faqSection
                            
                            // Trust Badges
                            trustBadges
                            
                            // Legal Text
                            legalText
                        }
                        .padding(.top, 20)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100) // Space for sticky button
                    }
                }
                
                // Sticky CTA Button at bottom
                VStack {
                    Spacer()
                    stickyCtaButton
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Restore") {
                        restorePurchases()
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                }
            }
            .alert("Welcome to Premium! 🎉", isPresented: $showPurchaseSuccess) {
                Button("Start Exploring") {
                    dismiss()
                }
            } message: {
                Text("You now have unlimited access to all premium features!")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .loadingOverlay(isLoading: isProcessing)
            .onAppear {
                // Load products from App Store
                Task {
                    await storeManager.loadProducts()
                }
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
            .frame(height: 300)
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
                
                // Crown icon with glow effect
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
                
                VStack(spacing: 12) {
                    Text("Upgrade to Premium")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Join 50,000+ premium members")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.95))
                    
                    Text("Find your perfect match faster")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .padding(.vertical, 30)
        }
    }
    
    // MARK: - Social Proof
    
    private var socialProof: some View {
        HStack(spacing: 25) {
            StatBadge(number: "50K+", label: "Members")
            StatBadge(number: "4.8★", label: "Rating")
            StatBadge(number: "3x", label: "More Matches")
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 25)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
    
    // MARK: - Features Section
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Premium Features")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .font(.title2)
            }
            
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
            HStack {
                Text("Choose Your Plan")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Risk-free badge
                HStack(spacing: 4) {
                    Image(systemName: "shield.checkered")
                        .font(.caption)
                    Text("7-day trial")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }
            
            VStack(spacing: 15) {
                PricingCard(
                    plan: .annual,
                    isSelected: selectedPlan == .annual,
                    onSelect: { selectedPlan = .annual },
                    badge: "BEST VALUE - Save 50%",
                    actualPrice: storeManager.getPrice(for: .annual)
                )
                
                PricingCard(
                    plan: .sixMonth,
                    isSelected: selectedPlan == .sixMonth,
                    onSelect: { selectedPlan = .sixMonth },
                    badge: "POPULAR - Save 25%",
                    actualPrice: storeManager.getPrice(for: .sixMonth)
                )
                
                PricingCard(
                    plan: .monthly,
                    isSelected: selectedPlan == .monthly,
                    onSelect: { selectedPlan = .monthly },
                    actualPrice: storeManager.getPrice(for: .monthly)
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
                        name: "Sarah M.",
                        age: "28",
                        location: "NYC",
                        quote: "I met my partner within a week of upgrading! The unlimited likes made all the difference.",
                        imageName: "person.fill"
                    )
                    
                    TestimonialCard(
                        name: "James K.",
                        age: "32",
                        location: "London",
                        quote: "Passport mode let me connect with someone amazing while traveling. Worth every penny!",
                        imageName: "person.fill"
                    )
                    
                    TestimonialCard(
                        name: "Maria L.",
                        age: "25",
                        location: "Barcelona",
                        quote: "Seeing who likes me first saved so much time. Found my match in 3 days!",
                        imageName: "person.fill"
                    )
                }
                .padding(.vertical, 5)
            }
        }
    }
    
    // MARK: - FAQ Section
    
    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Frequently Asked Questions")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                FAQItem(
                    question: "Can I cancel anytime?",
                    answer: "Yes! You can cancel your subscription at any time through your iPhone settings. You'll keep premium features until the end of your billing period."
                )
                
                FAQItem(
                    question: "Is there a free trial?",
                    answer: "Yes! All new premium subscriptions come with a 7-day free trial. Cancel anytime during the trial period and you won't be charged."
                )
                
                FAQItem(
                    question: "What happens after I subscribe?",
                    answer: "You'll get instant access to all premium features. Your matches will increase dramatically within the first 24 hours!"
                )
                
                FAQItem(
                    question: "Is my payment secure?",
                    answer: "Absolutely! All payments are processed securely through Apple's App Store. We never see or store your payment information."
                )
                
                FAQItem(
                    question: "Can I switch plans later?",
                    answer: "Yes, you can upgrade or downgrade your plan at any time through the app or iPhone settings."
                )
            }
        }
        .padding(.vertical, 10)
    }
    
    // MARK: - Trust Badges
    
    private var trustBadges: some View {
        VStack(spacing: 15) {
            HStack(spacing: 30) {
                TrustBadge(icon: "lock.shield.fill", text: "Secure Payment")
                TrustBadge(icon: "arrow.clockwise", text: "Cancel Anytime")
                TrustBadge(icon: "checkmark.seal.fill", text: "Money Back")
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Legal Text
    
    private var legalText: some View {
        VStack(spacing: 8) {
            Text("By continuing, you agree to our Terms of Service and Privacy Policy. Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 20) {
                Link("Terms", destination: URL(string: "https://celestia.app/terms")!)
                Link("Privacy", destination: URL(string: "https://celestia.app/privacy")!)
                Link("Support", destination: URL(string: "mailto:support@celestia.app")!)
            }
            .font(.caption)
            .foregroundColor(.purple)
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
    
    // MARK: - Sticky CTA Button
    
    private var stickyCtaButton: some View {
        VStack(spacing: 0) {
            // Gradient fade at top
            LinearGradient(
                colors: [Color.clear, Color(.systemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)
            
            Button {
                purchasePlan()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Continue with \(selectedPlan.name)")
                            .font(.headline)
                        
                        if selectedPlan != .monthly {
                            Text("Save \(selectedPlan.savings)% • 7-day free trial")
                                .font(.caption)
                                .opacity(0.9)
                        } else {
                            Text("7-day free trial")
                                .font(.caption)
                                .opacity(0.9)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 25)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .purple.opacity(0.4), radius: 15, y: 5)
            }
            .disabled(isProcessing || storeManager.products.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .background(Color(.systemGroupedBackground))
        }
    }
    
    // MARK: - Actions
    
    private func purchasePlan() {
        isProcessing = true
        
        Task {
            do {
                // Get the actual product from StoreKit
                guard let product = storeManager.getProduct(for: selectedPlan) else {
                    throw PurchaseError.productNotFound
                }
                
                // Purchase the product
                let success = try await storeManager.purchase(product)
                
                await MainActor.run {
                    isProcessing = false
                    
                    if success {
                        // Update user in Firebase
                        updatePremiumStatus()
                        showPurchaseSuccess = true
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func restorePurchases() {
        isProcessing = true
        
        Task {
            do {
                try await storeManager.restorePurchases()
                
                await MainActor.run {
                    isProcessing = false
                    
                    if storeManager.hasActiveSubscription {
                        updatePremiumStatus()
                        showPurchaseSuccess = true
                    } else {
                        errorMessage = "No previous purchases found."
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Failed to restore purchases. Please try again."
                    showError = true
                }
            }
        }
    }
    
    private func updatePremiumStatus() {
        guard let userId = authService.currentUser?.id else { return }
        
        Task {
            do {
                try await Firestore.firestore()
                    .collection("users")
                    .document(userId)
                    .updateData([
                        "isPremium": true,
                        "premiumTier": selectedPlan.rawValue,
                        "subscriptionExpiryDate": selectedPlan.expiryDate
                    ])
                
                // Refresh user data
                await authService.fetchUser()
            } catch {
                print("Error updating premium status: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

struct StatBadge: View {
    let number: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(number)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

struct TrustBadge: View {
    let icon: String
    let text: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.green)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

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
                    .foregroundColor(color)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
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

struct PricingCard: View {
    let plan: PremiumPlan
    let isSelected: Bool
    let onSelect: () -> Void
    var badge: String? = nil
    var actualPrice: String? = nil
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                // Badge if present
                if let badge = badge {
                    Text(badge)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [Color.orange, Color.red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8, corners: [.topLeft, .topRight])
                }
                
                // Main content
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(plan.name)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(actualPrice ?? plan.price)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(
                                    isSelected ?
                                    LinearGradient(
                                        colors: [Color.purple, Color.pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ) :
                                    LinearGradient(
                                        colors: [Color.primary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("/ \(plan.period)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        if plan != .monthly {
                            Text(plan.totalPrice)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .stroke(
                                isSelected ? Color.purple : Color.gray.opacity(0.3),
                                lineWidth: 2
                            )
                            .frame(width: 24, height: 24)
                        
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
            
            Text("\"\(quote)\"")
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
                    
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                        .font(.title3)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
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
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 5)
    }
}

// MARK: - Premium Plan Enum

enum PremiumPlan: String, CaseIterable {
    case monthly = "monthly"
    case sixMonth = "6month"
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
        case .sixMonth: return "$89.94 total"
        case .annual: return "$119.88 total"
        }
    }
    
    var savings: Int {
        switch self {
        case .monthly: return 0
        case .sixMonth: return 25
        case .annual: return 50
        }
    }
    
    var productID: String {
        switch self {
        case .monthly: return "com.celestia.premium.monthly"
        case .sixMonth: return "com.celestia.premium.sixmonth"
        case .annual: return "com.celestia.premium.annual"
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

// MARK: - Store Manager (StoreKit 2)

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var hasActiveSubscription = false
    
    private var updates: Task<Void, Never>? = nil
    
    private init() {
        updates = observeTransactionUpdates()
    }
    
    deinit {
        updates?.cancel()
    }
    
    func loadProducts() async {
        do {
            let productIDs = PremiumPlan.allCases.map { $0.productID }
            products = try await Product.products(for: productIDs)
            
            // Check for active subscriptions
            await updatePurchasedProducts()
        } catch {
            print("Failed to load products: \(error)")
        }
    }
    
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updatePurchasedProducts()
            return true
            
        case .userCancelled:
            return false
            
        case .pending:
            return false
            
        @unknown default:
            return false
        }
    }
    
    func restorePurchases() async throws {
        try await AppStore.sync()
        await updatePurchasedProducts()
    }
    
    func getProduct(for plan: PremiumPlan) -> Product? {
        products.first { $0.id == plan.productID }
    }
    
    func getPrice(for plan: PremiumPlan) -> String? {
        getProduct(for: plan)?.displayPrice
    }
    
    private func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                purchasedIDs.insert(transaction.productID)
            }
        }
        
        self.purchasedProductIDs = purchasedIDs
        self.hasActiveSubscription = !purchasedIDs.isEmpty
    }
    
    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await updatePurchasedProducts()
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Purchase Error

enum PurchaseError: LocalizedError {
    case productNotFound
    case failedVerification
    case purchaseFailed
    
    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not available. Please try again."
        case .failedVerification:
            return "Purchase verification failed. Please contact support."
        case .purchaseFailed:
            return "Purchase failed. Please try again."
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PremiumUpgradeView()
            .environmentObject(AuthService.shared)
    }
}
