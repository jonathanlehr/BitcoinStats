//
//  PriceViewModel.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import Foundation

@Observable
class PriceViewModel {

    // MARK: - Published State

    private(set) var priceHistory: [ChartDataPoint] = []
    private(set) var currentPrice: Double?
    private(set) var isLoading = false
    private(set) var error: String?

    // MARK: - User Preferences (pass-through)

    var selectedTimeRange: TimeRange {
        get { UserPreferences.shared.selectedTimeRange }
        set { UserPreferences.shared.selectedTimeRange = newValue }
    }

    // MARK: - Dependencies

    private let api: APIService
    private let supplementaryAPI: SupplementaryAPIService
    private let dataService: DataService

    // MARK: - Internal State

    private var lastFetchedRange: TimeRange?

    // MARK: - Init

    init(
        api: APIService = APIService(),
        supplementaryAPI: SupplementaryAPIService = SupplementaryAPIService(),
        dataService: DataService = DataService()
    ) {
        self.api = api
        self.supplementaryAPI = supplementaryAPI
        self.dataService = dataService
    }

    // MARK: - Load

    func load() async {
        // Show cached data immediately while the network request is in flight.
        loadFromCache()

        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        error = nil

        do {
            if needsHistoryRefresh() {
                // Fetch current price and historical chart in parallel.
                async let priceTask = api.fetchCurrentPrice()
                async let historyTask = supplementaryAPI.fetchMarketChart(
                    days: coinGeckoDays(for: selectedTimeRange)
                )

                let (price, chart) = try await (priceTask, historyTask)
                currentPrice = price.USD

                // Replace stored history with the fresh batch.
                try dataService.deleteMetrics(type: .price)
                let responses = chart.prices.map { point in
                    // CoinGecko timestamps are in milliseconds.
                    APIMetricResponse(
                        timestamp: Date(timeIntervalSince1970: point[0] / 1000),
                        value: point[1]
                    )
                }
                try dataService.saveMetrics(type: .price, responses: responses)
                lastFetchedRange = selectedTimeRange
                loadFromCache()

            } else {
                // History is fresh — just update the current price.
                let price = try await api.fetchCurrentPrice()
                currentPrice = price.USD
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Private Helpers

    /// Loads stored price metrics into `priceHistory` and seeds `currentPrice` if not yet set.
    private func loadFromCache() {
        let startDate = Calendar.current.date(
            byAdding: .day,
            value: -selectedTimeRange.days,
            to: Date()
        )
        let metrics = (try? dataService.fetchMetrics(type: .price, since: startDate)) ?? []
        priceHistory = metrics.compactMap { metric in
            guard let date = metric.timestamp else { return nil }
            return ChartDataPoint(date: date, value: metric.value)
        }
        if currentPrice == nil {
            currentPrice = priceHistory.last?.value
        }
    }

    /// Returns true when a history fetch is warranted — no data, stale data, or a new time range.
    private func needsHistoryRefresh() -> Bool {
        guard let latest = try? dataService.latestMetric(type: .price),
              let timestamp = latest.timestamp else {
            return true
        }
        let isStale = Date().timeIntervalSince(timestamp) > 3600
        let rangeChanged = lastFetchedRange != selectedTimeRange
        return isStale || rangeChanged
    }

    /// Converts a `TimeRange` to the string the CoinGecko API expects for its `days` parameter.
    private func coinGeckoDays(for range: TimeRange) -> String {
        range == .allTime ? "max" : String(range.days)
    }
}
