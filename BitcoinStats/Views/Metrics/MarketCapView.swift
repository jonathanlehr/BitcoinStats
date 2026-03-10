import SwiftUI
import Charts

struct MarketCapView: View {

    @State private var viewModel = MarketCapViewModel()

    var body: some View {
        marketCapContent
            .navigationTitle("Market Cap")
            .task(id: viewModel.selectedTimeRange) {
                await viewModel.load()
            }
    }

    // MARK: - Subviews

    private var marketCapContent: some View {
        VStack(spacing: 0) {
            chartArea
        }
    }

    private var chartArea: some View {
        if viewModel.isLoading && viewModel.history.isEmpty {
            ProgressView("Loading market cap data…")
                .frame(maxWidth: .infinity)
                .frame(height: 280)
        } else if let error = viewModel.error, viewModel.history.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
                .frame(height: 280)
        } else {
            Chart {
                ForEach(viewModel.history) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Market Cap", point.value)
                    )
                    .foregroundStyle(Color.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let cap = value.as(Double.self) {
                            Text(abbreviatedCap(cap))
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 280)
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .id(viewModel.selectedTimeRange)
        }
    }

    private func abbreviatedCap(_ cap: Double) -> String {
        if cap >= 1_000_000_000_000 {
            return String(format: "$%.1fT", cap / 1_000_000_000_000)
        } else if cap >= 1_000_000_000 {
            return String(format: "$%.1fB", cap / 1_000_000_000)
        } else if cap >= 1_000_000 {
            return String(format: "$%.0fM", cap / 1_000_000)
        }
        return String(format: "$%.0f", cap)
    }
}

struct Preview: PreviewProvider {
    static var previews: some View {
        MarketCapView()
    }
}
