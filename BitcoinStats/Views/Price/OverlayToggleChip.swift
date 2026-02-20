//
//  OverlayToggleChip.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import SwiftUI

/// A capsule-shaped toggle chip for enabling/disabling a price chart overlay.
/// Shows a colored dot and uses the overlay's color as an accent when active.
struct OverlayToggleChip: View {

    let label: String
    let color: Color
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Circle()
                    .fill(isEnabled ? color : Color.secondary.opacity(0.4))
                    .frame(width: 7, height: 7)
                Text(label)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isEnabled ? color.opacity(0.12) : Color.secondary.opacity(0.1))
            .foregroundStyle(isEnabled ? color : Color.secondary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isEnabled ? color.opacity(0.4) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack {
        OverlayToggleChip(label: "200W MA", color: .orange, isEnabled: true) {}
        OverlayToggleChip(label: "Bull Band", color: .green, isEnabled: false) {}
    }
    .padding()
}
