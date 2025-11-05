//
//  PremiumUpgradeView.swift
//  Celestia
//
//  ELITE PREMIUM UPGRADE - Maximize Conversions
//

import SwiftUI
import StoreKit

struct PremiumUpgradeView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @StateObject private var storeManager = StoreManager.shared
    
    @State private var selectedPlan: PremiumPlan = .annual
    @State private var showPurchaseSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isProcessing = false
    @State private var animateHeader = false
    @State private var animateFeatures = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Hero header
                        heroSection
                        
                        // Content
                        VStack(spacing: 30) {
                            // Social proof
                            socialProofBanner
                            
                            // Features showcase
                            featuresShowcase
                            
                            // Pricing cards
                            pricingSection
                            
                            // Testimonials
                            testimonialCarousel
                            
                            // FAQ
                            faqSection
                            
                            // Trust badges
                            trustSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 120)
                    }
                }
                
                // Sticky CTA button
                VStack {
                    Spacer()
                    ctaButton
                }
            }
            .navigationTitle("")
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
            .overlay {
                if isProcessing {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            
                            Text("Processing...")
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                        }
                        .padding(40)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(20)
                    }
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    animateHeader = true
                }
                withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.2)) {
                    animateFeatures = true
                }
                
                Task {
                    await storeManager.loadProducts()
                }
            }
        }
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.95),
                    Color.pink.opacity(0.85),
                    Color.orange.opacity(0.75)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 340)
            
            // Decorative elements
            GeometryReader { geo in
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .blur(radius: 40)
                    .offset(x: -60, y: -40)
                
                Circle()
                    .fill(Color.yellow.opacity(0.2))
                    .frame(width: 140, height: 140)
                    .blur(radius: 30)
                    .offset(x: geo.size.width - 70, y: 80)
            }
            
            // Content
            VStack(spacing: 24) {
                Spacer()
                
                // Crown icon
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.3))
                        .frame(width: 120, height: 120)
                        .blur(radius: 30)
                    
                    Image(systemName: "crown.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .yellow.opacity(0.6), radius: 15)
                        .rotationEffect(.degrees(animateHeader ? 0 : -15))
                        .scaleEffect(animateHeader ? 1 : 0.5)
                }
                
                VStack(spacing: 12) {
                    Text("Upgrade to Premium")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(animateHeader ? 1 : 0)
                    
                    Text("Join 50,000+ premium members")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.95))
                        .opacity(animateHeader ? 1 : 0)
                    
                    Text("Get 3x more matches & exclusive features")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .opacity(animateHeader ? 1 : 0)
                }
                
                Spacer()
            }
            .padding(.vertical, 40)
        }
    }
    
    // MARK: - Social Proof Banner
    
    private var socialProofBanner: some View {
        HStack(spacing: 30) {
            statBadge(number: "50K+", label: "Members", icon: "person.3.fill")
            statBadge(number: "4.8★", label: "Rating", icon: "star.fill")
            statBadge(number: "3x", label: "Matches", icon: "heart.fill")
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.08), radius: 15, y: 8)
    }
    
    private func statBadge(number: String, label: String, icon: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(number)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(animateFeatures ? 1 : 0.8)
        .opacity(animateFeatures ? 1 : 0)
    }
    
    // MARK: - Features Showcase
    
    private var featuresShowcase: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Premium Features")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                featureRow(
                    icon: "infinity",
                    title: "Unlimited Likes",
                    description: "Like as many profiles as you want",
                    color: .purple
                )
                
                featureRow(
                    icon: "eye.fill",
                    title: "See Who Likes You",
                    description: "Know who's interested before you swipe",
                    color: .pink
                )
                
                featureRow(
                    icon: "arrow.uturn.left",
                    title: "Rewind Swipes",
                    description: "Undo accidental passes instantly",
                    color: .blue
                )
                
                featureRow(
                    icon: "sparkles",
                    title: "5 Super Likes/Day",
                    description: "Stand out and get 3x more matches",
                    color: .cyan
                )
                
                featureRow(
                    icon: "bolt.fill",
                    title: "Profile Boost",
                    description: "Be seen by 10x more people",
                    color: .orange
                )
                
                featureRow(
                    icon: "shield.checkered",
                    title: "Priority Support",
                    description: "Get help when you need it",
                    color: .green
                )
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
    
    private func featureRow(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(spacing: 16) {
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
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3)
        }
    }
    
    // MARK: - Pricing Section
    
    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Choose Your Plan")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                ForEach(PremiumPlan.allCases, id: \.self) { plan in
                    pricingCard(plan: plan)
                }
            }
        }
    }
    
    private func pricingCard(plan: PremiumPlan) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedPlan = plan
                HapticManager.shared.selection()
            }
        } label: {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(plan.name)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            if plan == .annual {
                                Text("BEST VALUE")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green)
                                    .cornerRadius(8)
                            }
                        }
                        
                        Text(plan.totalPrice)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(plan.price)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("/\(plan.period)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if plan.savings > 0 {
                            Text("Save \(plan.savings)%")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                if selectedPlan == plan {
                    Divider()
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.purple)
                        
                        Text("Selected")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                        
                        Spacer()
                    }
                }
            }
            .padding(20)
            .background(
                selectedPlan == plan ?
                LinearGradient(
                    colors: [Color.purple.opacity(0.1), Color.pink.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ) :
                LinearGradient(colors: [Color.white], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        selectedPlan == plan ?
                        LinearGradient(
                            colors: [Color.purple, Color.pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(colors: [Color.gray.opacity(0.2)], startPoint: .leading, endPoint: .trailing),
                        lineWidth: 2
                    )
            )
            .shadow(color: selectedPlan == plan ? .purple.opacity(0.2) : .clear, radius: 15, y: 8)
        }
    }
    
    // MARK: - Testimonial Carousel
    
    private var testimonialCarousel: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Success Stories")
                .font(.title2)
                .fontWeight(.bold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    testimonialCard(
                        name: "Sarah M.",
                        text: "Found my perfect match within a week of upgrading! Totally worth it.",
                        rating: 5
                    )
                    
                    testimonialCard(
                        name: "Mike R.",
                        text: "The unlimited likes feature changed everything. Met amazing people!",
                        rating: 5
                    )
                    
                    testimonialCard(
                        name: "Emma L.",
                        text: "Seeing who likes me first saved so much time. Best decision ever!",
                        rating: 5
                    )
                }
            }
        }
    }
    
    private func testimonialCard(name: String, text: String, rating: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ForEach(0..<rating, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
            }
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(3)
            
            Text(name)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
        .frame(width: 250)
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
    
    // MARK: - FAQ Section
    
    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Frequently Asked")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                faqItem(
                    question: "Can I cancel anytime?",
                    answer: "Yes! Cancel your subscription anytime from your account settings. No questions asked."
                )
                
                faqItem(
                    question: "What payment methods do you accept?",
                    answer: "We accept all major credit cards, Apple Pay, and Google Pay through the App Store."
                )
                
                faqItem(
                    question: "Will I lose my matches if I cancel?",
                    answer: "No, you'll keep all your existing matches. You just won't have access to premium features."
                )
            }
        }
    }
    
    private func faqItem(question: String, answer: String) -> some View {
        DisclosureGroup {
            Text(answer)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        } label: {
            Text(question)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
    }
    
    // MARK: - Trust Section
    
    private var trustSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                trustBadge(icon: "lock.shield.fill", text: "Secure")
                trustBadge(icon: "checkmark.seal.fill", text: "Verified")
                trustBadge(icon: "arrow.clockwise", text: "Cancel Anytime")
            }
            
            Text("Your payment information is encrypted and secure")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }
    
    private func trustBadge(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.green)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - CTA Button
    
    private var ctaButton: some View {
        VStack(spacing: 12) {
            Button {
                purchasePremium()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                    
                    Text("Upgrade to Premium")
                        .fontWeight(.bold)
                    
                    Text(selectedPlan.price + "/" + selectedPlan.period)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .purple.opacity(0.5), radius: 20, y: 10)
            }
            .disabled(isProcessing)
            
            Text("7-day free trial • Cancel anytime")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(Color.white)
        .shadow(color: .black.opacity(0.1), radius: 15, y: -5)
    }
    
    // MARK: - Actions
    
    private func purchasePremium() {
        isProcessing = true
        
        Task {
            do {
                guard let product = storeManager.getProduct(for: selectedPlan) else {
                    throw PurchaseError.productNotFound
                }
                
                let success = try await storeManager.purchase(product)
                
                if success {
                    // Update Firestore
                    if var user = authService.currentUser {
                        user.isPremium = true
                        user.premiumTier = selectedPlan.rawValue
                        user.subscriptionExpiryDate = selectedPlan.expiryDate
                        try await authService.updateUser(user)
                    }
                    
                    await MainActor.run {
                        isProcessing = false
                        showPurchaseSuccess = true
                        HapticManager.shared.notification(.success)
                    }
                } else {
                    await MainActor.run {
                        isProcessing = false
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
                        showPurchaseSuccess = true
                        HapticManager.shared.notification(.success)
                    } else {
                        errorMessage = "No active subscriptions found"
                        showError = true
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
}

// MARK: - Premium Plan

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

// MARK: - Store Manager

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var hasActiveSubscription = false
    
    private var updates: Task<Void, Never>?
    
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

#Preview {
    NavigationStack {
        PremiumUpgradeView()
            .environmentObject(AuthService.shared)
    }
}
