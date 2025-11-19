//
//  SharedUIComponents.swift
//  Celestia
//
//  Shared UI components used across the app
//

import SwiftUI

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String?
    let color: Color

    init(title: String, value: String, icon: String? = nil, color: Color) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
    }

    var body: some View {
        VStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }

            Text(value)
                .font(icon != nil ? .title3 : .title)
                .fontWeight(.bold)
                .foregroundColor(icon != nil ? .primary : color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(icon != nil ? Color.white : color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Benefit Row

struct BenefitRow: View {
    let icon: String
    let text: String
    let color: Color

    init(icon: String, text: String, color: Color = .purple) {
        self.icon = icon
        self.text = text
        self.color = color
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}
