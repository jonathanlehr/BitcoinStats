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
            timeRangePicker
                .padding(.vertical, 8)
            chartArea
                .padding(.horizontal)
            metricDescription
        }
    }

    @ViewBuilder private var chartArea: some View {
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
            marketCapChart
        }
    }

    private var marketCapChart: some View {
        Chart {
            ForEach(viewModel.history) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Market Cap", point.value),
                    yEnd: .value("Market Cap", 0)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [Color.blue.opacity(0.25), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Market Cap", point.value),
                    series: .value("Series", "marketcap")
                )
                .foregroundStyle(Color.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: xAxisDesiredCount)) { _ in
                AxisGridLine()
                AxisValueLabel(format: xAxisFormat)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
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

    private var timeRangePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(TimeRange.allCases) { range in
                    TimeRangeButton(
                        label: range.rawValue,
                        isSelected: viewModel.selectedTimeRange == range
                    ) {
                        viewModel.selectedTimeRange = range
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var metricDescription: some View {
        Text("The total market value of all bitcoin in circulation, calculated as price × circulating supply. Market cap is the most common measure of Bitcoin's size and is used to compare it against traditional asset classes.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private var xAxisDesiredCount: Int {
        switch viewModel.selectedTimeRange {
        case .sixMonths, .year, .twoYears, .allTime: 3
        default: 4
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch viewModel.selectedTimeRange {
        case .day: .dateTime.hour()
        case .week, .month, .threeMonths: .dateTime.month(.abbreviated).day()
        case .sixMonths, .year, .twoYears: .dateTime.month(.abbreviated).year(.twoDigits)
        case .allTime: .dateTime.year()
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

struct MarketCapView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            MarketCapView()
        }
    }
}
