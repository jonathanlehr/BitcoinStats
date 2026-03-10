import Foundation
import os

@Observable
class MVRVViewModel {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BitcoinStats",
        category: "MVRVViewModel"
    )

    /// MVRV history is considered stale after this interval and will be re-fetched.
    private static let historyStaleInterval: TimeInterval = 3_600  // 1 hour

    // MARK: - Published State

    /// Historical MVRV data for the selected display range.
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
                Self.logger.info("Fetching data for MVRV calculation")
                // Fetch market cap and realized price if needed
                let marketCapChart = try await api.fetchMarketChart(days: "max")
                let realizedPriceChart = try await api.fetchChartData(chartName: .marketPrice, timespan: "all")  // Placeholder; adjust if realized price API differs

                try dataService.deleteMetrics(type: .marketCap)
                let marketCapResponses = marketCapChart.market_caps.map { point in
                    APIMetricResponse(
                        timestamp: Date(timeIntervalSince1970: point[0] / 1_000),
                        value: point[1]
                    )
                }
                try dataService.saveMetrics(type: .marketCap, responses: marketCapResponses)

                try dataService.deleteMetrics(type: .realizedPrice)
                let realizedPriceResponses = realizedPriceChart.values.map { point in
                    APIMetricResponse(
                        timestamp: Date(timeIntervalSince1970: TimeInterval(point.x)),
                        value: point.y  // Assuming this is realized price; adjust API if needed
                    )
                }
                try dataService.saveMetrics(type: .realizedPrice, responses: realizedPriceResponses)

                Self.logger.info("Saved data for MVRV calculation")
                computeMVRV()
                loadFromCache()
            }
        } catch {
            Self.logger.error("MVRV load failed: \(error, privacy: .public)")
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
        let metrics = (try? dataService.fetchMetrics(type: .mvrv, since: startDate)) ?? []
        history = metrics.compactMap { metric in
            guard let date = metric.timestamp else { return nil }
            return ChartDataPoint(date: date, value: metric.value)
        }
    }

    private func computeMVRV() {
        let marketCapMetrics = (try? dataService.fetchMetrics(type: .marketCap)) ?? []
        let realizedPriceMetrics = (try? dataService.fetchMetrics(type: .realizedPrice)) ?? []

        // Simple calculation: MVRV = marketCap / realizedPrice
        // Align by date (simplified; use interpolation for better accuracy)
        var mvrvPoints: [APIMetricResponse] = []
        for mc in marketCapMetrics {
            if let rp = realizedPriceMetrics.first(where: { abs($0.timestamp.timeIntervalSince(mc.timestamp)) < 86_400 }), rp.value > 0 {
                let mvrv = mc.value / rp.value
                mvrvPoints.append(APIMetricResponse(timestamp: mc.timestamp, value: mvrv))
            }
        }
        try? dataService.saveMetrics(type: .mvrv, responses: mvrvPoints)
    }

    private func needsHistoryRefresh() -> Bool {
        guard let latest = try? dataService.latestMetric(type: .mvrv),
              let timestamp = latest.timestamp else {
            return true
        }
        return Date().timeIntervalSince(timestamp) > Self.historyStaleInterval
    }
}
