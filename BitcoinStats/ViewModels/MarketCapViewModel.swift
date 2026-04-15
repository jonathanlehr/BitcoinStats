//
//  MarketCapViewModel.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import Foundation
import OSLog

@Observable
class MarketCapViewModel {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BitcoinStats",
        category: "MarketCapViewModel"
    )

    /// Market cap history is considered stale after this interval and will be re-fetched.
    private static let historyStaleInterval: TimeInterval = 3_600  // 1 hour

    // MARK: - Published State

    /// Historical market cap data for the selected display range.
    private(set) var history: [ChartDataPoint] = []
    private(set) var isLoading = false
    private(set) var error: String?

    // MARK: - User State

    var selectedTimeRange: TimeRange = .year

    // MARK: - Dependencies

    private let api: SupplementaryAPIService
    private let dataService: DataService

    // MARK: - Init

    init(api: SupplementaryAPIService = SupplementaryAPIService(), dataService: DataService = DataService()) {
        self.api = api
        self.dataService = dataService
    }

    // MARK: - Load

    func load() async {
        loadFromCache()

        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        error = nil

        do {
            if needsHistoryRefresh() {
                // Bootstrap with full history when no data exists; otherwise fetch the last
                // 30 days and append only records newer than the latest stored timestamp.
                let latestTimestamp = (try? dataService.latestMetric(type: .marketCap))?.timestamp
                let isBootstrap = latestTimestamp == nil
                let timespan = isBootstrap ? "all" : "30days"
                let cutoff = latestTimestamp ?? .distantPast

                // TODO: Persist the last-launch date in UserDefaults. If more than 30 days have
                // elapsed since the last launch, fall back to "all" so the incremental window
                // cannot silently miss records.

                Self.logger.info("Fetching market cap history from blockchain.com (timespan=\(timespan, privacy: .public))")
                let chart = try await api.fetchChartData(chartName: .marketCap, timespan: timespan)
                Self.logger.info("Received \(chart.values.count) market cap points")

                let newResponses = chart.values.compactMap { point -> APIMetricResponse? in
                    let date = Date(timeIntervalSince1970: TimeInterval(point.x))
                    guard date > cutoff else { return nil }
                    return APIMetricResponse(timestamp: date, value: point.y)
                }
                Self.logger.info("Inserting \(newResponses.count, privacy: .public) new market cap records")
                try await dataService.insertMetrics(type: .marketCap, responses: newResponses)
                loadFromCache()
            }
        } catch {
            Self.logger.error("Market cap load failed: \(error, privacy: .public)")
            self.error = error.localizedDescription
        }
    }

    // MARK: - Private Helpers

    private func loadFromCache() {
        let startDate = Calendar.current.date(
            byAdding: .day,
            value: -selectedTimeRange.days,
            to: Date()
        )
        let metrics = (try? dataService.fetchMetrics(type: .marketCap, since: startDate)) ?? []
        history = metrics.compactMap { metric in
            guard let date = metric.timestamp else { return nil }
            return ChartDataPoint(date: date, value: metric.value)
        }
    }

    private func needsHistoryRefresh() -> Bool {
        guard let latest = try? dataService.latestMetric(type: .marketCap),
              let timestamp = latest.timestamp else {
            return true
        }
        return Date().timeIntervalSince(timestamp) > Self.historyStaleInterval
    }
}
