//
//  HashRateViewModel.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/20/26.
//

import Foundation
import os

@Observable
class HashRateViewModel {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BitcoinStats",
        category: "HashRateViewModel"
    )

    // MARK: - Published State

    /// Current network hash rate in EH/s.
    private(set) var currentHashrate: Double?
    /// Historical hash rate data for the selected display range (EH/s values).
    private(set) var history: [ChartDataPoint] = []
    private(set) var isLoading = false
    private(set) var error: String?

    // MARK: - User State

    var selectedTimeRange: TimeRange = .year

    // MARK: - Dependencies

    private let api: APIService
    private let dataService: DataService

    // MARK: - Init

    init(api: APIService = APIService(), dataService: DataService = DataService()) {
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
                // "all" returns the full history; currentHashrate may be absent on this endpoint.
                Self.logger.info("Fetching full hash rate history (timePeriod=all) from mempool.space")
                let response = try await api.fetchHashrateAndDifficulty(timePeriod: "all")
                Self.logger.info("Received \(response.hashrates.count) hash rate points")

                // Prefer the explicit current value; fall back to the most recent history point.
                let latestRaw = response.currentHashrate ?? response.hashrates.last?.avgHashrate ?? 0
                currentHashrate = latestRaw / 1e18  // H/s → EH/s
                Self.logger.info("Current hash rate: \(String(format: "%.1f", latestRaw / 1e18), privacy: .public) EH/s")

                try dataService.deleteMetrics(type: .hashRate)
                let responses = response.hashrates.map { point in
                    APIMetricResponse(
                        timestamp: Date(timeIntervalSince1970: TimeInterval(point.timestamp)),
                        value: point.avgHashrate / 1e18  // H/s → EH/s
                    )
                }
                try dataService.saveMetrics(type: .hashRate, responses: responses)
                Self.logger.info("Saved \(responses.count) hash rate records to CoreData")
                loadFromCache()
            } else {
                // History is fresh — just grab the current value from a lightweight call.
                Self.logger.debug("Hash rate history is current — fetching live value only")
                let response = try await api.fetchHashrateAndDifficulty(timePeriod: "1m")
                let latestRaw = response.currentHashrate ?? response.hashrates.last?.avgHashrate ?? 0
                currentHashrate = latestRaw / 1e18
                Self.logger.info("Current hash rate: \(String(format: "%.1f", latestRaw / 1e18), privacy: .public) EH/s")
            }
        } catch {
            Self.logger.error("Hash rate load failed: \(error, privacy: .public)")
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
        let metrics = (try? dataService.fetchMetrics(type: .hashRate, since: startDate)) ?? []
        history = metrics.compactMap { metric in
            guard let date = metric.timestamp else { return nil }
            return ChartDataPoint(date: date, value: metric.value)
        }
        if currentHashrate == nil {
            currentHashrate = history.last?.value
        }
    }

    private func needsHistoryRefresh() -> Bool {
        guard let latest = try? dataService.latestMetric(type: .hashRate),
              let timestamp = latest.timestamp else {
            return true
        }
        return Date().timeIntervalSince(timestamp) > 3_600  // Stale after 1 hour
    }
}
