//
//  AskViewModel.swift
//  BitcoinStats
//
//  Pattern: Guided generation.
//  LLM → typed `QueryIntent` struct → deterministic app code executes the query.
//
//  The model is used as a *parser*: it classifies the user's natural-language question
//  into a constrained enum-based struct. No prose is generated. Once the struct is
//  produced, the rest of the flow is pure Swift — fetch data, build a result, render.
//
//  This is the middle point on the training-course progression:
//
//    MarketSummaryViewModel  — plain prompt → free-form text
//    AskViewModel            — guided generation → typed struct → app-rendered result   ← THIS
//    AnalystViewModel        — tool calling → streaming agent loop
//

import Foundation
import FoundationModels
import OSLog

@available(iOS 26.0, *)
@MainActor
@Observable
final class AskViewModel {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BitcoinStats",
        category: "AskViewModel"
    )

    // MARK: - Published State

    private(set) var result: AskResult?
    private(set) var isWorking = false
    private(set) var error: String?

    /// True when Apple Intelligence is ready to use on this device.
    var isModelAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    // MARK: - Dependencies

    private let api: APIService
    private let dataService: DataService

    init(api: APIService = APIService(), dataService: DataService? = nil) {
        self.api = api
        self.dataService = dataService ?? DataService()
    }

    // MARK: - Submit

    /// Parses `question` into a `QueryIntent` via guided generation, then executes the intent
    /// against cached data and (where needed) a single live API call.
    func submit(question: String) async {
        guard isModelAvailable else {
            error = "Apple Intelligence is not available on this device. Enable it in Settings > Apple Intelligence & Siri."
            return
        }

        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isWorking = true
        error = nil
        result = nil
        defer { isWorking = false }

        // --- 1. Guided generation: turn the question into a typed QueryIntent. ---

        let intent: QueryIntent
        do {
            let session = LanguageModelSession(instructions: Self.systemInstructions)
            // Ask the model for a QueryIntent directly. FoundationModels enforces the
            // schema during decoding — any output that doesn't match the @Generable
            // structure will throw rather than reach our code.
            let response = try await session.respond(
                to: trimmed,
                generating: QueryIntent.self
            )
            intent = response.content
            // OSLogMessage doesn't support + concatenation; put all fields in one literal.
            Self.logger.info("Parsed intent: metric=\(intent.metric.rawValue, privacy: .public) range=\(intent.range.rawValue, privacy: .public) style=\(intent.style.rawValue, privacy: .public)")
        } catch {
            Self.logger.error("Guided generation failed: \(error, privacy: .public)")
            self.error = "Couldn't understand the question: \(error.localizedDescription)"
            return
        }

        // --- 2. Execute the intent with plain Swift — no model calls from here on. ---

        do {
            result = try await execute(intent: intent)
        } catch {
            Self.logger.error("Intent execution failed: \(error, privacy: .public)")
            self.error = "Couldn't load the data for that question: \(error.localizedDescription)"
        }
    }

    /// Clears the current result so the UI returns to the empty state.
    func reset() {
        result = nil
        error = nil
    }

    // MARK: - Intent Execution

    private func execute(intent: QueryIntent) async throws -> AskResult {
        let metricType = intent.metric.metricType
        // Use intent.range.days directly (QueryableTimeRange) rather than going through
        // intent.range.timeRange.days (TimeRange), which may carry @MainActor isolation.
        let startDate = Calendar.current.date(byAdding: .day, value: -intent.range.days, to: .now)

        // Run the CoreData fetch and the optional live API call concurrently — they are
        // independent, so there is no reason to wait for one before starting the other.
        async let historyFetch   = dataService.fetchChartData(type: metricType, since: startDate)
        async let liveValueFetch = fetchLiveValueIfAvailable(for: metricType, style: intent.style)

        let history   = await historyFetch
        let liveValue = try await liveValueFetch

        return AskResult(intent: intent, history: history, liveValue: liveValue)
    }

    /// Fetches a live value for metrics where `APIService` has a fast path.
    private func fetchLiveValueIfAvailable(for metric: MetricType, style: QueryStyle) async throws -> Double? {
        // Only worth a network call when the card is going to display a single "now" value.
        guard style == .currentValue else { return nil }

        switch metric {
        case .price:
            return try await api.fetchCurrentPrice().USD
        case .mempoolSize:
            let stats = try await api.fetchMempoolStats()
            // vsize is stored in virtual bytes — the rest of the app shows mempool size in MB.
            return Double(stats.vsize) / 1_000_000
        default:
            return nil
        }
    }

    // MARK: - Prompt

    /// System instructions that bias the model toward our constrained taxonomy.
    /// Kept short intentionally — the `@Generable` schema does most of the "constraint"
    /// work; instructions just help the model interpret fuzzy phrasing consistently.
    private static let systemInstructions = """
        You convert user questions about Bitcoin analytics into a structured query.
        Choose the closest available metric, time range, and display style.
        If the question says "now", "today", or asks for a single value, use style=currentValue.
        If it asks to see values over time ("show", "chart", "history"), use style=history.
        If it asks how much something has moved, use style=change.
        """
}

// MARK: - AskResult

/// Output of the Ask flow. Consumed by `QueryResultCard`.
///
/// Note that every field is computed from cached/live data — there is no model-generated
/// prose. Summaries are built with plain string formatting so the result is fully
/// deterministic once the `QueryIntent` has been produced.
@available(iOS 26.0, *)
struct AskResult {

    let intent: QueryIntent
    let history: [ChartDataPoint]
    let liveValue: Double?

    /// The single value to emphasize at the top of the result card.
    var headlineValue: Double? {
        liveValue ?? history.last?.value
    }

    /// First value in the range, if available.
    var startValue: Double? { history.first?.value }

    /// Last value in the range, if available.
    var endValue: Double? { history.last?.value }

    /// Absolute change from start to end of range.
    var delta: Double? {
        guard let s = startValue, let e = endValue else { return nil }
        return e - s
    }

    /// Percent change from start to end of range.
    var percentChange: Double? {
        guard let s = startValue, let e = endValue, s != 0 else { return nil }
        return (e - s) / s * 100
    }

    /// Highest value observed in the range.
    var rangeHigh: Double? { history.map(\.value).max() }

    /// Lowest value observed in the range.
    var rangeLow: Double? { history.map(\.value).min() }

    /// A short plain-language summary, built from the values above — no LLM call.
    var plainLanguageSummary: String {
        let metric = intent.metric.metricType
        let range  = intent.range.timeRange.rawValue

        switch intent.style {
        case .currentValue:
            if let v = headlineValue {
                return "\(metric.rawValue) is currently \(metric.format(v))."
            }
            return "No recent data for \(metric.rawValue)."

        case .history:
            guard let s = startValue, let e = endValue, let lo = rangeLow, let hi = rangeHigh else {
                return "No cached history for \(metric.rawValue) over \(range)."
            }
            let pct = percentChange.map { String(format: "%+.1f%%", $0) } ?? "—"
            return """
                \(metric.rawValue) over \(range): \
                started at \(metric.format(s)), ended at \(metric.format(e)) (\(pct)). \
                Range low \(metric.format(lo)), high \(metric.format(hi)).
                """

        case .change:
            guard let s = startValue, let e = endValue, let d = delta, let p = percentChange else {
                return "No cached data to compute a change for \(metric.rawValue) over \(range)."
            }
            let sign = d >= 0 ? "up" : "down"
            return """
                \(metric.rawValue) is \(sign) \(String(format: "%+.1f%%", p)) over \(range) \
                (\(metric.format(s)) → \(metric.format(e))).
                """
        }
    }
}
