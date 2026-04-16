//
//  QueryIntent.swift
//  BitcoinStats
//
//  Pattern: Guided generation with @Generable.
//
//  `QueryIntent` is the typed shape that FoundationModels coerces a user question into.
//  The LLM is only responsible for *classifying* the question — picking a metric, a
//  time range, and a display style. The app then deterministically executes the query
//  against CoreData / live APIs and renders the result.
//
//  Contrast this with:
//   • MarketSummaryViewModel — plain prompt → free-form text.
//   • AnalystViewModel        — tool calling → multi-turn agent loop.
//

import Foundation
import FoundationModels

// MARK: - QueryIntent

/// Structured representation of a user's natural-language question about Bitcoin data.
///
/// Produced by calling:
/// ```swift
/// try await session.respond(to: question, generating: QueryIntent.self).content
/// ```
/// Every field is constrained by a `@Generable` enum so the model cannot invent
/// metric names, time ranges, or display styles that the app doesn't know how to render.
@available(iOS 26.0, *)
@Generable
struct QueryIntent {

    @Guide(description: "The Bitcoin metric the user is asking about.")
    let metric: QueryableMetric

    @Guide(description: """
        The time range the question is scoped to. Use `day` for questions phrased in the \
        present ("right now", "today"). Use longer ranges for historical questions.
        """)
    let range: QueryableTimeRange

    @Guide(description: """
        How the result should be presented:
        - currentValue: a single number ("What's Bitcoin's price right now?").
        - history: a chart over the range ("Show me MVRV over the last year").
        - change: start vs. end comparison ("How much has hash rate moved in 6 months?").
        """)
    let style: QueryStyle
}

// MARK: - QueryableMetric

/// Subset of `MetricType` the Ask feature currently supports.
///
/// Kept separate from `MetricType` on purpose: we want the model to pick from a
/// constrained list tied to what we have cached data for, without having to make
/// the broader `MetricType` enum conform to `Generable`.
@available(iOS 26.0, *)
@Generable
enum QueryableMetric: String, CaseIterable, Sendable {
    case price
    case marketCap
    case mvrv
    case mayerMultiple
    case nupl
    case hashRate
    case mempoolSize

    /// Maps to the app's core `MetricType`, which drives CoreData fetches and formatting.
    var metricType: MetricType {
        switch self {
        case .price:         .price
        case .marketCap:     .marketCap
        case .mvrv:          .mvrv
        case .mayerMultiple: .mayerMultiple
        case .nupl:          .nupl
        case .hashRate:      .hashRate
        case .mempoolSize:   .mempoolSize
        }
    }
}

// MARK: - QueryableTimeRange

/// `TimeRange` with a `Generable` conformance so the model can pick a range directly.
@available(iOS 26.0, *)
@Generable
enum QueryableTimeRange: String, CaseIterable, Sendable {
    case day
    case week
    case month
    case threeMonths
    case sixMonths
    case year
    case twoYears
    case allTime

    var timeRange: TimeRange {
        switch self {
        case .day:         .day
        case .week:        .week
        case .month:       .month
        case .threeMonths: .threeMonths
        case .sixMonths:   .sixMonths
        case .year:        .year
        case .twoYears:    .twoYears
        case .allTime:     .allTime
        }
    }

    /// The approximate number of calendar days this range spans.
    ///
    /// Mirrors `TimeRange.days` but declared here so tools — which run off the main
    /// actor — can read the value without going through `timeRange`, which may carry
    /// inferred `@MainActor` isolation in some Swift concurrency configurations.
    var days: Int {
        switch self {
        case .day:         1
        case .week:        7
        case .month:       30
        case .threeMonths: 90
        case .sixMonths:   180
        case .year:        365
        case .twoYears:    730
        case .allTime:     5_000
        }
    }
}

// MARK: - QueryStyle

/// Dictates which variant of `QueryResultCard` the view renders.
@available(iOS 26.0, *)
@Generable
enum QueryStyle: String, CaseIterable, Sendable {
    /// Single "big number" display. Best for "what is X right now?" questions.
    case currentValue
    /// Mini chart over the selected range. Best for "show me X over time" questions.
    case history
    /// Start-of-range vs. end-of-range comparison. Best for "how much has X moved?" questions.
    case change
}
