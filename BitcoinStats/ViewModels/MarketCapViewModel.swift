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
                Self.logger.info("Fetching market cap history from CoinGecko")
                let chart = try await api.fetchMarketChart(days: "max")
                Self.logger.info("Received \(chart.market_caps.count) market cap points")

                try dataService.deleteMetrics(type: .marketCap)
                let responses = chart.market_caps.map { point in
                    APIMetricResponse(
                        timestamp: Date(timeIntervalSince1970: point[0] / 1_000),
                        value: point[1]
                    )
                }
                try dataService.saveMetrics(type: .marketCap, responses: responses)
                Self.logger.info("Saved \(responses.count) market cap records to CoreData")
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
