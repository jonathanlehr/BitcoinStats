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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12, pinnedViews: .sectionHeaders) {
                    Section {
                        NavigationLink {
                            HashRateView()
                        } label: {
                            MetricCard(
                                title: MetricType.hashRate.rawValue,
                                description: MetricType.hashRate.description,
                                systemImage: "bolt.fill",
                                tint: .indigo
                            )
                        }
                        .buttonStyle(.plain)
                    } header: {
                        Text("Network")
                            .font(.title3.weight(.semibold))
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Metrics")
        }
    }
}

#Preview {
    MetricsView()
}
