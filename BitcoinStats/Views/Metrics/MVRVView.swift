import SwiftUI
import Charts

struct MayerMultipleView: View {

    @State private var viewModel = MayerMultipleViewModel()

    var body: some View {
        mvContent
            .navigationTitle("Mayer Multiple")
            .task(id: viewModel.selectedTimeRange) {
                await viewModel.load()
            }
    }

    // MARK: - Subviews

    private var mvContent: some View {
        VStack(spacing: 0) {
            currentValueHeader
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 16)
            timeRangePicker
                .padding(.vertical, 8)
            chartArea
                .padding(.horizontal)
            metricDescription
        }
    }

    private var currentValueHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let value = viewModel.currentValue {
                Text(String(format: "%.2f×", value))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
            } else {
                Text("—")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Text("Mayer Multiple")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var chartArea: some View {
        if viewModel.isLoading && viewModel.history.isEmpty {
            ProgressView("Computing Mayer Multiple…")
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
            mayerChart
        }
    }

    private var mayerChart: some View {
        Chart {
            // Reference lines drawn first so the data line sits on top.
            RuleMark(y: .value("Overheated", 2.4))
                .foregroundStyle(Color.red.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            RuleMark(y: .value("Undervalued", 0.8))
                .foregroundStyle(Color.green.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

            ForEach(viewModel.history) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Mayer Multiple", point.value)
                )
                .foregroundStyle(Color.purple)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartYScale(domain: yAxisDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: xAxisDesiredCount)) { _ in
                AxisGridLine()
                AxisValueLabel(format: xAxisFormat)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: [1.0, 2.0, 3.0, 4.0]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: "%.0f", v))
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
        Text("The Mayer Multiple is Bitcoin's current price divided by its 200-day moving average. A value of 1.0 means price equals the 200-day average. Values above 2.4 have historically coincided with market tops; values below 0.8 have marked periods of deep undervaluation.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    /// Y-axis domain: always at least [0, 4.5] so all four integer ticks are visible;
    /// expands upward if any data point exceeds 4.5 (e.g., early-cycle extremes).
    private var yAxisDomain: ClosedRange<Double> {
        let maxData = viewModel.history.map(\.value).max() ?? 4.5
        return 0...max(4.5, maxData * 1.05)
    }

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
}

struct MVRVView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            MayerMultipleView()
        }
    }
}
