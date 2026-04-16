//
//  QueryResultCard.swift
//  BitcoinStats
//
//  Renders an `AskResult` in one of three variants keyed off `QueryStyle`:
//    .currentValue — big single number
//    .history      — mini chart + start/end/high/low stats
//    .change       — start → end comparison with delta and %
//
//  No LLM output reaches this view. Everything displayed here is computed directly
//  from cached CoreData history (or, for .currentValue, a single live API call).
//

import Charts
import SwiftUI

@available(iOS 26.0, *)
struct QueryResultCard: View {

    let result: AskResult

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            content
            summary
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(result.intent.metric.metricType.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(result.intent.range.timeRange.rawValue + " · " + result.intent.style.displayLabel)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Image(systemName: "sparkles")
                .foregroundStyle(.purple)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch result.intent.style {
        case .currentValue: currentValueContent
        case .history:      historyContent
        case .change:       changeContent
        }
    }

    private var currentValueContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let value = result.headlineValue {
                Text(result.intent.metric.metricType.format(value))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var historyContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if result.history.isEmpty {
                emptyState
            } else {
                miniChart
                HStack(spacing: 20) {
                    stat(label: "Start", value: result.startValue)
                    stat(label: "End",   value: result.endValue)
                    stat(label: "Low",   value: result.rangeLow)
                    stat(label: "High",  value: result.rangeHigh)
                }
            }
        }
    }

    private var changeContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let start = result.startValue,
               let end   = result.endValue,
               let pct   = result.percentChange {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(result.intent.metric.metricType.format(start))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                    Text(result.intent.metric.metricType.format(end))
                        .font(.title2.weight(.bold))
                }
                Text(String(format: "%+.2f%%", pct))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(pct >= 0 ? .green : .red)
                miniChart
            } else {
                emptyState
            }
        }
    }

    // MARK: - Mini Chart

    private var miniChart: some View {
        Chart(result.history) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Value", point.value)
            )
            .foregroundStyle(Color.orange)
            .interpolationMethod(.catmullRom)
            AreaMark(
                x: .value("Date", point.date),
                yStart: .value("Value", point.value),
                yEnd: .value("Floor", result.rangeLow ?? 0)
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [Color.orange.opacity(0.25), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 120)
    }

    // MARK: - Bits

    private func stat(label: String, value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            if let v = value {
                Text(result.intent.metric.metricType.format(v))
                    .font(.footnote.weight(.medium))
            } else {
                Text("—").font(.footnote.weight(.medium)).foregroundStyle(.tertiary)
            }
        }
    }

    private var emptyState: some View {
        Text("No cached data for this metric and range yet. Open the matching tab once to populate history.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private var summary: some View {
        Text(result.plainLanguageSummary)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - QueryStyle Display

@available(iOS 26.0, *)
private extension QueryStyle {
    var displayLabel: String {
        switch self {
        case .currentValue: "Current value"
        case .history:      "History"
        case .change:       "Change"
        }
    }
}
