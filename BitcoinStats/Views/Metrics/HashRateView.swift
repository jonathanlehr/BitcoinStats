//
//  HashRateView.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/20/26.
//

import Charts
import SwiftUI

/// Full-screen detail view for the Bitcoin Network Hash Rate metric.
/// Pushed onto MetricsView's NavigationStack — no NavigationStack wrapper here.
struct HashRateView: View {

    @State private var viewModel = HashRateViewModel()

    var body: some View {
        hashRateContent
            .navigationTitle("Hash Rate")
            .task(id: viewModel.selectedTimeRange) {
                await viewModel.load()
            }
    }

    // MARK: - Subviews

    private var hashRateContent: some View {
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

    private var metricDescription: some View {
        Text("The total computational power dedicated to mining Bitcoin blocks, measured in exahashes per second (EH/s). A rising hash rate signals growing miner confidence and a more secure network; a sharp decline can indicate miner capitulation.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var chartArea: some View {
        if viewModel.isLoading && viewModel.history.isEmpty {
            ProgressView("Loading hash rate data…")
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
            hashRateChart
        }
    }

    private var currentValueHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let rate = viewModel.currentHashrate {
                Text(MetricType.hashRate.format(rate))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
            } else {
                Text("—")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Text("Network Hash Rate")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hashRateChart: some View {
        Chart {
            ForEach(viewModel.history) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Hash Rate", point.value),
                    yEnd: .value("Hash Rate", 0)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [Color.indigo.opacity(0.25), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Hash Rate", point.value),
                    series: .value("Series", "hashrate")
                )
                .foregroundStyle(Color.indigo)
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
                    if let rate = value.as(Double.self) {
                        Text(abbreviatedHashrate(rate))
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

    // MARK: - Helpers

    private var xAxisFormat: Date.FormatStyle {
        switch viewModel.selectedTimeRange {
        case .day:
            .dateTime.hour()
        case .week, .month, .threeMonths:
            .dateTime.month(.abbreviated).day()
        case .sixMonths, .year, .twoYears:
            .dateTime.month(.abbreviated).year(.twoDigits)
        case .allTime:
            .dateTime.year()
        }
    }

    private var xAxisDesiredCount: Int {
        switch viewModel.selectedTimeRange {
        case .sixMonths, .year, .twoYears, .allTime: 3
        default: 4
        }
    }

    private func abbreviatedHashrate(_ value: Double) -> String {
        if value >= 1_000 {
            return String(format: "%.0fK EH/s", value / 1_000)
        }
        return String(format: "%.0f EH/s", value)
    }
}

#Preview {
    NavigationStack {
        HashRateView()
    }
}
