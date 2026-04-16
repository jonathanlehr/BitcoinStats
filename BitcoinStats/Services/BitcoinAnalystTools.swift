//
//  BitcoinAnalystTools.swift
//  BitcoinStats
//
//  Pattern: Tool calling.
//
//  These types conform to FoundationModels' `Tool` protocol. When a tool is passed
//  to `LanguageModelSession(tools:)`, the model can decide during a conversation
//  that it needs one of them, emit a structured call, receive the tool's output,
//  and then continue reasoning. The loop is driven by the model, not the app.
//
//  Three design rules for tools in this project:
//
//  1. Tools are thin wrappers over existing services (APIService, DataService,
//     CalculationService). No business logic should live here.
//  2. Tool outputs are terse and structured (CSV, key=value) — the model pays
//     tokens to read them, so readability is less important than density.
//  3. Tools emit activity messages via a callback so the UI can show "Checking
//     hash rate…" while the tool runs. This is what makes the agent loop feel
//     transparent instead of mysterious.
//

import Foundation
import FoundationModels

// MARK: - ToolActivityEmitter

/// Sendable callback used by every tool to report when it starts/stops work.
/// The view model installs a closure that hops to `@MainActor` and updates
/// an `@Observable` property the chat UI binds to.
///
/// Using a plain closure keeps tools value-typed and Sendable-clean, without
/// the complexity of sharing an @Observable class across actor boundaries.
typealias ToolActivityEmitter = @Sendable (String?) -> Void

// MARK: - GetCurrentPriceTool

@available(iOS 26.0, *)
struct GetCurrentPriceTool: Tool {

    let name = "getCurrentPrice"
    let description = "Fetches the current live Bitcoin spot price in USD from mempool.space."

    @Generable
    struct Arguments: Sendable {}

    let api: APIService
    let emit: ToolActivityEmitter

    func call(arguments: Arguments) async throws -> String {
        emit("Fetching current price…")
        defer { emit(nil) }

        let response = try await api.fetchCurrentPrice()
        let iso = Date(timeIntervalSince1970: TimeInterval(response.time)).ISO8601Format()
        return """
            metric=price \
            usd=\(String(format: "%.2f", response.USD)) \
            asOf=\(iso)
            """
    }
}

// MARK: - GetMetricHistoryTool

/// `@unchecked Sendable` because `DataService` is a plain class and not formally
/// `Sendable`, but the method we call (`fetchChartData`) is already async and
/// dispatches onto a private CoreData background context — so sharing the reference
/// across actors is safe in practice. Training-course note: this is the kind of
/// place where an "unchecked" conformance is appropriate and should be documented.
@available(iOS 26.0, *)
struct GetMetricHistoryTool: Tool, @unchecked Sendable {

    let name = "getMetricHistory"
    let description = """
        Returns a time-series sample of a Bitcoin metric over a chosen range, \
        pulled from the app's local CoreData cache. The series is downsampled \
        to at most 40 points so it fits in the model's context window. \
        Use this for questions about trends, trajectories, or "over time".
        """

    @Generable
    struct Arguments: Sendable {
        @Guide(description: "The Bitcoin metric to fetch.")
        let metric: QueryableMetric

        @Guide(description: "The time range to return.")
        let range: QueryableTimeRange
    }

    /// Upper bound on points returned to the model so we don't blow the token budget.
    static let maxPoints = 40

    let dataService: DataService
    let emit: ToolActivityEmitter

    func call(arguments: Arguments) async throws -> String {
        let metric = arguments.metric.metricType
        emit("Loading \(metric.rawValue) history…")
        defer { emit(nil) }

        // Use arguments.range.days directly to avoid going through timeRange,
        // which may carry @MainActor isolation in some Swift concurrency configurations.
        let start = Calendar.current.date(byAdding: .day, value: -arguments.range.days, to: .now)
        let all = await dataService.fetchChartData(type: metric, since: start)
        let sampled = Self.downsample(all, to: Self.maxPoints)

        let rows = sampled
            .map { "\($0.date.ISO8601Format()),\(String(format: "%.6g", $0.value))" }
            .joined(separator: "\n")

        return """
            metric=\(metric.rawValue) range=\(arguments.range.rawValue) \
            storedPoints=\(all.count) returnedPoints=\(sampled.count)
            date,value
            \(rows)
            """
    }

    /// Evenly strides `points` down to at most `maxPoints` entries, always preserving
    /// the last point so the model sees the most recent value.
    private static func downsample(_ points: [ChartDataPoint], to maxPoints: Int) -> [ChartDataPoint] {
        guard points.count > maxPoints else { return points }
        let step = Int((Double(points.count) / Double(maxPoints)).rounded(.up))
        var sampled = stride(from: 0, to: points.count, by: step).map { points[$0] }
        if let last = points.last, sampled.last?.date != last.date {
            sampled.append(last)
        }
        return sampled
    }
}

// MARK: - ComputeIndicatorTool

/// See the note on `GetMetricHistoryTool` — same reason for `@unchecked Sendable`.
@available(iOS 26.0, *)
struct ComputeIndicatorTool: Tool, @unchecked Sendable {

    let name = "computeIndicator"
    let description = """
        Computes a derived indicator from stored price history. \
        Supports mayerMultiple (price / 200-day SMA) and percentChange (between the \
        first and last price over a given range).
        """

    @Generable
    enum Indicator: String, CaseIterable, Sendable {
        case mayerMultiple
        case percentChange
    }

    @Generable
    struct Arguments: Sendable {
        @Guide(description: "Which derived indicator to compute.")
        let indicator: Indicator

        @Guide(description: "Time range used by `percentChange`. Ignored for `mayerMultiple`.")
        let range: QueryableTimeRange
    }

    let dataService: DataService
    let emit: ToolActivityEmitter

    func call(arguments: Arguments) async throws -> String {
        emit("Computing \(arguments.indicator.rawValue)…")
        defer { emit(nil) }

        switch arguments.indicator {
        case .mayerMultiple:
            return try await mayerMultiple()
        case .percentChange:
            return try await percentChange(range: arguments.range)
        }
    }

    // MARK: - Indicators

    private func mayerMultiple() async throws -> String {
        let all = await dataService.fetchChartData(type: .price)
        guard all.count >= CalculationService.period200DayMA else {
            return "indicator=mayerMultiple status=insufficientHistory"
        }

        let sma = CalculationService.sma(data: all, period: CalculationService.period200DayMA)
        guard let lastSMA = sma.last, lastSMA.value > 0,
              let last = all.last else {
            return "indicator=mayerMultiple status=couldNotCompute"
        }

        let mm = last.value / lastSMA.value
        return """
            indicator=mayerMultiple value=\(String(format: "%.3f", mm)) \
            price=\(String(format: "%.2f", last.value)) \
            sma200=\(String(format: "%.2f", lastSMA.value)) \
            note=historicallyOverheatedAbove2.4 historicallyUndervaluedBelow0.8
            """
    }

    // Takes QueryableTimeRange directly to avoid going through timeRange.days,
    // which may carry @MainActor isolation in some Swift concurrency configurations.
    private func percentChange(range: QueryableTimeRange) async throws -> String {
        let start = Calendar.current.date(byAdding: .day, value: -range.days, to: .now)
        let points = await dataService.fetchChartData(type: .price, since: start)
        guard let first = points.first, let last = points.last, first.value != 0 else {
            return "indicator=percentChange range=\(range.rawValue) status=insufficientData"
        }
        let pct = (last.value - first.value) / first.value * 100
        return """
            indicator=percentChange range=\(range.rawValue) \
            startValue=\(String(format: "%.2f", first.value)) \
            endValue=\(String(format: "%.2f", last.value)) \
            percentChange=\(String(format: "%+.2f", pct))
            """
    }
}

// MARK: - GetMempoolSnapshotTool

@available(iOS 26.0, *)
struct GetMempoolSnapshotTool: Tool {

    let name = "getMempoolSnapshot"
    let description = """
        Returns live mempool status: unconfirmed transaction count and recommended \
        fee rates in sat/vB. Use for questions about network congestion or how much \
        to pay to send a transaction.
        """

    @Generable
    struct Arguments: Sendable {}

    let api: APIService
    let emit: ToolActivityEmitter

    func call(arguments: Arguments) async throws -> String {
        emit("Checking mempool…")
        defer { emit(nil) }

        async let mempool = api.fetchMempoolStats()
        async let fees    = api.fetchRecommendedFees()
        let (m, f) = try await (mempool, fees)

        return """
            mempoolTxCount=\(m.count) mempoolVsize=\(m.vsize) \
            fastestFee=\(f.fastestFee) halfHourFee=\(f.halfHourFee) \
            hourFee=\(f.hourFee) economyFee=\(f.economyFee) minimumFee=\(f.minimumFee) \
            units=sat/vB
            """
    }
}
