//
//  MetricsView.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import SwiftUI

struct MetricsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "On-Chain Metrics",
                systemImage: "chart.xyaxis.line",
                description: Text("Valuation, network, and holder metrics — coming soon.")
            )
            .navigationTitle("Metrics")
        }
    }
}

#Preview {
    MetricsView()
}
