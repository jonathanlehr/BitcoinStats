import SwiftUI

struct MetricsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12, pinnedViews: .sectionHeaders) {
                    Section {
                        NavigationLink {
                            MarketCapView()
                        } label: {
                            MetricCard(
                                title: MetricType.marketCap.rawValue,
                                description: MetricType.marketCap.description,
                                systemImage: "chart.bar.fill",
                                tint: .blue
                            )
                        }
                        .buttonStyle(.plain)
                        NavigationLink {
                            MayerMultipleView()
                        } label: {
                            MetricCard(
                                title: MetricType.mayerMultiple.rawValue,
                                description: MetricType.mayerMultiple.description,
                                systemImage: "waveform.path.ecg",
                                tint: .purple
                            )
                        }
                        .buttonStyle(.plain)
                    } header: {
                        Text("Valuation")
                            .font(.title3.weight(.semibold))
                            .padding(.top, 8)
                    }
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

struct Preview: PreviewProvider {
    static var previews: some View {
        MetricsView()
    }
}
