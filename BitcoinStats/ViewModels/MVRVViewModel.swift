//
//  MVRVViewModel.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//
//  Repurposed: originally computed MVRV (requires paid on-chain data).
//  Now computes the Mayer Multiple (price ÷ 200-day SMA) from the daily
//  price history already stored in CoreData by PriceViewModel.
//

import Foundation
import OSLog

@Observable
class MayerMultipleViewModel {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BitcoinStats",
        category: "MayerMultipleViewModel"
    )

    // MARK: - Published State

    /// Mayer Multiple history filtered to the selected time range.
    private(set) var history: [ChartDataPoint] = []
    /// The most recent computed Mayer Multiple value.
    private(set) var currentValue: Double?
    private(set) var isLoading = false
    private(set) var error: String?

    // MARK: - User State

    var selectedTimeRange: TimeRange = .year

    // MARK: - Dependencies

    private let supplementaryAPI: SupplementaryAPIService
    private let dataService: DataService

    // MARK: - Init

    init(
        supplementaryAPI: SupplementaryAPIService = SupplementaryAPIService(),
        dataService: DataService = DataService()
    ) {
        self.supplementaryAPI = supplementaryAPI
        self.dataService = dataService
    }

    // MARK: - Load

    func load() async {
        // Show whatever is computable from cached data immediately.
        computeAndLoad()

        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        error = nil

        // Fetch full price history if it is missing or stale.
        if needsPriceRefresh() {
            do {
                Self.logger.info("Fetching full price history from blockchain.com for Mayer Multiple")
                let chart = try await supplementaryAPI.fetchChartData(chartName: .marketPrice, timespan: "all")
                Self.logger.info("Received \(chart.values.count) price points")
                try dataService.deleteMetrics(type: .price)
                let responses = chart.values.map { point in
                    APIMetricResponse(
                        timestamp: Date(timeIntervalSince1970: TimeInterval(point.x)),
                        value: point.y
                    )
                }
                try dataService.saveMetrics(type: .price, responses: responses)
                computeAndLoad()
            } catch {
                Self.logger.error("Price fetch failed: \(error, privacy: .public)")
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Private Helpers

    /// Derives Mayer Multiple (price ÷ 200-day SMA) from stored price history,
    /// then filters the result to the selected time range.
    private func computeAndLoad() {
        let allMetrics = (try? dataService.fetchMetrics(type: .price)) ?? []
        let allPoints = allMetrics
            .compactMap { m -> ChartDataPoint? in
                guard let date = m.timestamp else { return nil }
                return ChartDataPoint(date: date, value: m.value)
            }
            .sorted { $0.date < $1.date }

        guard allPoints.count >= CalculationService.period200DayMA else {
            history = []
            currentValue = nil
            return
        }

        let sma200 = CalculationService.sma(data: allPoints, period: CalculationService.period200DayMA)

        // Use uniquingKeysWith in case there are any duplicate dates in stored data.
        let priceByDate = Dictionary(allPoints.map { ($0.date, $0.value) }, uniquingKeysWith: { _, last in last })

        let allMayer = sma200.compactMap { pt -> ChartDataPoint? in
            guard let price = priceByDate[pt.date], pt.value > 0 else { return nil }
            return ChartDataPoint(date: pt.date, value: price / pt.value)
        }

        currentValue = allMayer.last?.value

        let startDate = Calendar.current.date(byAdding: .day, value: -selectedTimeRange.days, to: Date())
        if let start = startDate {
            history = allMayer.filter { $0.date >= start }
        } else {
            history = allMayer
        }
    }

    /// Returns true when the stored daily price history should be re-fetched.
    /// Mirrors PriceViewModel's needsHistoryRefresh() logic.
    private func needsPriceRefresh() -> Bool {
        guard let latest = try? dataService.latestMetric(type: .price),
              let latestTimestamp = latest.timestamp else {
            return true
        }
        if Date().timeIntervalSince(latestTimestamp) > oneDaySeconds { return true }

        guard let oldest = try? dataService.oldestMetric(type: .price),
              let oldestTimestamp = oldest.timestamp else {
            return true
        }
        let requiredSpan = TimeInterval(CalculationService.minDailyHistory) * oneDaySeconds
        return Date().timeIntervalSince(oldestTimestamp) < requiredSpan
    }
}
