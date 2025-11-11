//
//  PaywallView.swift
//  Celestia
//
//  Subscription paywall with tiered pricing
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTier: SubscriptionTier = .plus
    @State private var selectedPeriod: BillingPeriod = .monthly
    @State private var isPurchasing = false
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    header

                    // Tier selection
                    tierSelection

                    // Period selection
                    periodSelection

                    // Features list
                    featuresList

                    // Purchase button
                    purchaseButton

                    // Restore & Terms
                    footer
                }
                .padding()
            }
            .navigationTitle("Go Premium")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)

            Text("Unlock Premium Features")
                .font(.title)
                .fontWeight(.bold)

            Text("Find your perfect match faster with unlimited access")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var tierSelection: some View {
        VStack(spacing: 12) {
            ForEach([SubscriptionTier.basic, .plus, .premium], id: \.self) { tier in
                TierCard(
                    tier: tier,
                    period: selectedPeriod,
                    isSelected: selectedTier == tier,
                    onSelect: { selectedTier = tier }
                )
            }
        }
    }

    private var periodSelection: some View {
        HStack(spacing: 16) {
            PeriodButton(
                period: .monthly,
                isSelected: selectedPeriod == .monthly,
                onSelect: { selectedPeriod = .monthly }
            )

            PeriodButton(
                period: .yearly,
                isSelected: selectedPeriod == .yearly,
                onSelect: { selectedPeriod = .yearly }
            )
        }
    }

    private var featuresList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's Included")
                .font(.headline)

            ForEach(selectedTier.features, id: \.displayName) { feature in
                if feature.isEnabled {
                    FeatureRow(feature: feature)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var purchaseButton: some View {
        Button(action: { Task { await purchase() } }) {
            if isPurchasing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Text("Subscribe - \(selectedTier.monthlyPrice)/month")
                    .fontWeight(.semibold)
            }
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue)
        .cornerRadius(12)
        .disabled(isPurchasing)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button("Restore Purchases") {
                Task { await restore() }
            }
            .font(.subheadline)

            HStack(spacing: 16) {
                Button("Terms") { }
                Button("Privacy") { }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }

    private func purchase() async {
        isPurchasing = true
        // Implementation would connect to StoreManager
        isPurchasing = false
    }

    private func restore() async {
        do {
            try await storeManager.restorePurchases()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

struct TierCard: View {
    let tier: SubscriptionTier
    let period: BillingPeriod
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: tier.icon)
                        Text(tier.displayName)
                            .fontWeight(.semibold)
                    }

                    Text(period == .monthly ? tier.monthlyPrice : tier.yearlyPrice)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PeriodButton: View {
    let period: BillingPeriod
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack {
                Text(period.displayName)
                    .fontWeight(.semibold)

                if period.savingsPercentage > 0 {
                    Text("Save \(period.savingsPercentage)%")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.blue : Color(.secondarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(12)
        }
    }
}

struct FeatureRow: View {
    let feature: SubscriptionFeature

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: feature.icon)
                .foregroundColor(.blue)

            Text(feature.displayName)
                .font(.subheadline)

            Spacer()
        }
    }
}
