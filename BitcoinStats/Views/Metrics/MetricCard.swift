//
//  MetricCard.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/20/26.
//

import SwiftUI

/// A tappable card representing a single on-chain metric.
/// Used in the Metrics tab grid; tapping navigates to the metric's detail view.
struct MetricCard: View {

    let title: String
    let description: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 46, height: 46)
                .background(tint.opacity(0.15))
                .foregroundStyle(tint)
                .clipShape(RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    MetricCard(
        title: "Hash Rate",
        description: "Computational power securing the network.",
        systemImage: "bolt.fill",
        tint: .indigo
    )
    .padding()
}
