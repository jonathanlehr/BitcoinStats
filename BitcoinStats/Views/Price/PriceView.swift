//
//  PriceView.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import SwiftUI

struct PriceView: View {

    @State private var viewModel = PriceViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.priceHistory.isEmpty {
                    ProgressView("Loading price data…")
                } else if let error = viewModel.error {
                    ContentUnavailableView(
                        "Unable to Load",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else {
                    priceContent
                }
            }
            .navigationTitle("Price")
            .task {
                await viewModel.load()
            }
        }
    }

    // MARK: - Subviews

    private var priceContent: some View {
        VStack(spacing: 24) {
            currentPriceHeader
            Spacer()
            // Chart goes here in step 3
            dataPlaceholder
            Spacer()
        }
        .padding()
    }

    private var currentPriceHeader: some View {
        VStack(spacing: 4) {
            if let price = viewModel.currentPrice {
                Text(MetricType.price.format(price))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
            } else {
                Text("—")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Text("Bitcoin")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var dataPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("\(viewModel.priceHistory.count) data points loaded")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Chart coming in step 3")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    PriceView()
}
