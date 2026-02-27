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
            // RectangleMark for fill: AreaMark interpolates in linear data space and misaligns
            // with the logarithmic y-axis. RectangleMark positions each bar at exact data values.
            // SMA and EMA are stored as actual values (not forced min/max) so crossings show correctly.
            ForEach(Array(zip(viewModel.bullBandSMA, viewModel.bullBandEMA)), id: \.0.id) { sma, ema in
                RectangleMark(
                    x: .value("Date", sma.date),
                    yStart: .value("Band", sma.value),
                    yEnd: .value("Band", ema.value),
                    width: .ratio(1)
                )
                .foregroundStyle(Color.orange.opacity(0.2))
            }
            ForEach(viewModel.bullBandSMA) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Price", point.value),
                    series: .value("Series", "bull_sma")
                )
                .foregroundStyle(Color.red)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.linear)
            }
            ForEach(viewModel.bullBandEMA) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Price", point.value),
                    series: .value("Series", "bull_ema")
                )
                .foregroundStyle(Color.green)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.linear)
            }

            // Price line + area fill
            ForEach(viewModel.priceHistory) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Price", point.value),
                    yEnd: .value("Price", priceFloor)
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
        .chartYScale(domain: yAxisDomain, type: .log)
        .chartYAxis {
            AxisMarks(position: .trailing, values: yAxisValues) { value in
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
        .clipped()
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

    /// Overlays shown as toggle chips. Currently only 200W MA and Bull Market Support Band.
    /// Realized Price is hidden until a free data source is available (all current providers require paid plans).
    private static let visibleOverlays: [PriceOverlay] = PriceOverlay.allCases.filter {
        ![ PriceOverlay.ma20week, .ema21week, .ma200day, .ma50day, .realizedPrice ].contains($0)
    }

    private var overlayToggleRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Self.visibleOverlays) { overlay in
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

    /// Minimum price value used as the AreaMark baseline on the log scale.
    /// Must be > 0 (log of zero is undefined).
    private var priceFloor: Double {
        viewModel.priceHistory.map(\.value).min() ?? 1.0
    }

    /// Exactly 5 values log-linearly spaced across `yAxisDomain`.
    /// Passed directly to AxisMarks so Swift Charts can't collapse them to fewer ticks.
    private var yAxisValues: [Double] {
        let lo = yAxisDomain.lowerBound
        let hi = yAxisDomain.upperBound
        guard lo > 0, hi > lo else { return [] }
        let logLo = log10(lo)
        let logHi = log10(hi)
        return (0..<5).map { i in
            pow(10, logLo + Double(i) / 4.0 * (logHi - logLo))
        }
    }

    /// Y-axis domain with time-range-aware padding.
    /// Short ranges use price history only (keeps the chart zoomed in).
    /// Long ranges also include the bull band lines so they stay within the visible area —
    /// the 20W SMA lags far below recent prices after a fast rally, pushing it off-screen
    /// if the domain is based on price history alone.
    private var yAxisDomain: ClosedRange<Double> {
        var values = viewModel.priceHistory.map(\.value)
        if viewModel.selectedTimeRange.days > 90 {
            values += viewModel.bullBandSMA.map(\.value)
            values += viewModel.bullBandEMA.map(\.value)
        }
        guard let lo = values.min(), let hi = values.max(), lo > 0, hi > lo else {
            return 1...100_000
        }
        let pad: Double
        switch viewModel.selectedTimeRange {
        case .day, .week:             pad = 0.03
        case .month, .threeMonths:    pad = 0.06
        default:                      pad = 0.12
        }
        return (lo * (1 - pad))...(hi * (1 + pad))
    }

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
