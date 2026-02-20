//
//  PriceView.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import Charts
import SwiftUI

struct PriceView: View {

    @State private var viewModel = PriceViewModel()

    var body: some View {
        NavigationStack {
            priceContent
                .navigationTitle("Price")
                .task(id: viewModel.selectedTimeRange) {
                    await viewModel.load()
                }
        }
    }

    // MARK: - Subviews

    private var priceContent: some View {
        VStack(spacing: 0) {
            currentPriceHeader
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 16)
            chartArea
                .padding(.horizontal)
            overlayToggleRow
                .padding(.top, 10)
            timeRangePicker
                .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var chartArea: some View {
        if viewModel.isLoading && viewModel.priceHistory.isEmpty {
            // First-ever load — spinner fills the chart slot.
            ProgressView("Loading price data…")
                .frame(maxWidth: .infinity)
                .frame(height: 280)
        } else if let error = viewModel.error, viewModel.priceHistory.isEmpty {
            // Fetch failed and there's nothing cached to fall back on.
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
            // Show the chart. A loading overlay appears during range-change refreshes.
            priceChart
        }
    }

    private var currentPriceHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let price = viewModel.currentPrice {
                Text(MetricType.price.format(price))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
            } else {
                Text("—")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Text("Bitcoin (BTC)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var priceChart: some View {
        Chart {
            // Bull Market Support Band — rendered first so it sits beneath the price line.
            // Filled area between the date-aligned 20W SMA (lower) and 21W EMA (upper), or vice versa.
            ForEach(Array(zip(viewModel.bullBandLower, viewModel.bullBandUpper)), id: \.0.id) { lower, upper in
                AreaMark(
                    x: .value("Date", lower.date),
                    yStart: .value("Band", lower.value),
                    yEnd: .value("Band", upper.value)
                )
                .foregroundStyle(PriceOverlay.bullMarketSupportBand.color.opacity(0.4))
                .interpolationMethod(.catmullRom)
            }

            // Price line + area fill
            ForEach(viewModel.priceHistory) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Price", point.value),
                    yEnd: .value("Price", 0)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [Color.orange.opacity(0.25), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Price", point.value),
                    series: .value("Series", "price")
                )
                .foregroundStyle(Color.orange)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }

            // MA overlays — each rendered only when data is present (overlay enabled and
            // enough stored history to compute the window). bullMarketSupportBand is skipped
            // here because it is rendered above as an AreaMark.
            ForEach(PriceOverlay.allCases) { overlay in
                if let points = viewModel.overlayData[overlay] {
                    ForEach(points) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Price", point.value),
                            series: .value("Series", overlay.rawValue)
                        )
                        .foregroundStyle(overlay.color)
                        .lineStyle(StrokeStyle(lineWidth: overlay.lineWidth))
                        .interpolationMethod(.catmullRom)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: xAxisFormat)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let price = value.as(Double.self) {
                        Text(abbreviatedPrice(price))
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
        // Force a full chart rebuild when the time range changes so the x-axis format updates.
        .id(viewModel.selectedTimeRange)
    }

    private var overlayToggleRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(PriceOverlay.allCases) { overlay in
                    OverlayToggleChip(
                        label: overlay.rawValue,
                        color: overlay.color,
                        isEnabled: UserPreferences.shared.enabledPriceOverlays.contains(overlay)
                    ) {
                        viewModel.toggleOverlay(overlay)
                    }
                }
            }
            .padding(.horizontal)
        }
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
        case .sixMonths, .year:
            .dateTime.month(.abbreviated)
        case .twoYears:
            .dateTime.month(.abbreviated).year(.twoDigits)  // e.g. "Feb '24"
        case .allTime:
            .dateTime.year()
        }
    }

    private func abbreviatedPrice(_ price: Double) -> String {
        if price >= 1_000_000 {
            return String(format: "$%.1fM", price / 1_000_000)
        } else if price >= 1_000 {
            return String(format: "$%.0fK", price / 1_000)
        }
        return String(format: "$%.0f", price)
    }
}

#Preview {
    PriceView()
}
