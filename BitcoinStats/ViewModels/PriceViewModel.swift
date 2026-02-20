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
    private(set) var overlayData: [PriceOverlay: [ChartDataPoint]] = [:]
    /// Lower boundary of the Bull Market Support Band (20W SMA vs 21W EMA, whichever is lower).
    private(set) var bullBandLower: [ChartDataPoint] = []
    /// Upper boundary of the Bull Market Support Band.
    private(set) var bullBandUpper: [ChartDataPoint] = []
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
        // Show whatever is cached immediately while network requests are in flight.
        loadFromCache()
        computeOverlays()

        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        error = nil

        do {
            // Always refresh the live price (fast, single value).
            let price = try await api.fetchCurrentPrice()
            currentPrice = price.USD

            // Ensure we have comprehensive all-time daily history for MA computation.
            // Fetches CoinGecko's full dataset once; re-fetches only when stale (> 24 h)
            // or when we don't have enough history for the 200-week MA.
            if needsHistoryRefresh() {
                let chart = try await supplementaryAPI.fetchMarketChart(days: "max")
                try dataService.deleteMetrics(type: .price)
                let responses = chart.prices.map { point in
                    // CoinGecko timestamps are milliseconds.
                    APIMetricResponse(
                        timestamp: Date(timeIntervalSince1970: point[0] / 1000),
                        value: point[1]
                    )
                }
                try dataService.saveMetrics(type: .price, responses: responses)
            }

            // For short display ranges CoinGecko returns granular hourly data (≤ 90 days).
            // Fetch it directly into priceHistory for a smooth chart; don't write to CoreData
            // to avoid mixing daily and sub-daily timestamps.
            if selectedTimeRange.days <= 90 {
                let displayChart = try await supplementaryAPI.fetchMarketChart(
                    days: String(selectedTimeRange.days)
                )
                priceHistory = displayChart.prices.map { point in
                    ChartDataPoint(
                        date: Date(timeIntervalSince1970: point[0] / 1000),
                        value: point[1]
                    )
                }
                if currentPrice == nil { currentPrice = priceHistory.last?.value }
            } else {
                loadFromCache()
            }

            computeOverlays()

        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Overlay Toggling

    /// Toggles an overlay on/off in UserPreferences and recomputes overlay data.
    func toggleOverlay(_ overlay: PriceOverlay) {
        if UserPreferences.shared.enabledPriceOverlays.contains(overlay) {
            UserPreferences.shared.enabledPriceOverlays.remove(overlay)
        } else {
            UserPreferences.shared.enabledPriceOverlays.insert(overlay)
        }
        computeOverlays()
    }

    // MARK: - Private Helpers

    /// Loads the current display range's price data from CoreData into `priceHistory`.
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

    /// Computes all enabled MA overlays and the Bull Market Support Band from the full stored history.
    func computeOverlays() {
        let allMetrics = (try? dataService.fetchMetrics(type: .price)) ?? []
        let allPoints = allMetrics.compactMap { metric -> ChartDataPoint? in
            guard let date = metric.timestamp else { return nil }
            return ChartDataPoint(date: date, value: metric.value)
        }

        let enabled = UserPreferences.shared.enabledPriceOverlays
        let startDate = Calendar.current.date(
            byAdding: .day,
            value: -selectedTimeRange.days,
            to: Date()
        )

        func filtered(_ pts: [ChartDataPoint]) -> [ChartDataPoint] {
            guard let d = startDate else { return pts }
            return pts.filter { $0.date >= d }
        }

        var result: [PriceOverlay: [ChartDataPoint]] = [:]

        if enabled.contains(.ma200week) {
            let ma = CalculationService.sma(data: allPoints, period: CalculationService.period200WeekMA)
            result[.ma200week] = filtered(ma)
        }

        if enabled.contains(.ma200day) {
            let ma = CalculationService.sma(data: allPoints, period: CalculationService.period200DayMA)
            result[.ma200day] = filtered(ma)
        }

        if enabled.contains(.ma50day) {
            let ma = CalculationService.sma(data: allPoints, period: CalculationService.period50DayMA)
            result[.ma50day] = filtered(ma)
        }

        // 20W SMA and 21W EMA are computed together: both may be needed by the Bull Band
        // even when neither individual overlay is enabled.
        let needSMA20 = enabled.contains(.ma20week) || enabled.contains(.bullMarketSupportBand)
        let needEMA21 = enabled.contains(.ema21week) || enabled.contains(.bullMarketSupportBand)

        var sma20: [ChartDataPoint] = []
        var ema21: [ChartDataPoint] = []

        if needSMA20 {
            sma20 = CalculationService.sma(data: allPoints, period: CalculationService.period20WeekMA)
            if enabled.contains(.ma20week) {
                result[.ma20week] = filtered(sma20)
            }
        }

        if needEMA21 {
            ema21 = CalculationService.ema(data: allPoints, period: CalculationService.period21WeekEMA)
            if enabled.contains(.ema21week) {
                result[.ema21week] = filtered(ema21)
            }
        }

        // Bull Market Support Band: filled area between the date-aligned 20W SMA and 21W EMA.
        // Both series are computed from the same `allPoints` array, so their dates are exact
        // matches at every shared index — dictionary lookup is lossless.
        if enabled.contains(.bullMarketSupportBand), !sma20.isEmpty, !ema21.isEmpty {
            let smaFiltered = filtered(sma20)
            let emaByDate = Dictionary(
                uniqueKeysWithValues: filtered(ema21).map { ($0.date, $0.value) }
            )
            var lower: [ChartDataPoint] = []
            var upper: [ChartDataPoint] = []
            for s in smaFiltered {
                if let e = emaByDate[s.date] {
                    lower.append(ChartDataPoint(date: s.date, value: Swift.min(s.value, e)))
                    upper.append(ChartDataPoint(date: s.date, value: Swift.max(s.value, e)))
                }
            }
            bullBandLower = lower
            bullBandUpper = upper
        } else {
            bullBandLower = []
            bullBandUpper = []
        }

        overlayData = result
    }

    /// Returns true when the stored daily price history should be re-fetched:
    /// - No data exists.
    /// - Fewer than 1,400 records (not enough for the 200-week MA).
    /// - The latest record is older than 24 hours.
    private func needsHistoryRefresh() -> Bool {
        guard let latest = try? dataService.latestMetric(type: .price),
              let latestTimestamp = latest.timestamp else {
            return true
        }
        if Date().timeIntervalSince(latestTimestamp) > 86_400 { return true }

        guard let oldest = try? dataService.oldestMetric(type: .price),
              let oldestTimestamp = oldest.timestamp else {
            return true
        }
        let requiredSpan = TimeInterval(CalculationService.period200WeekMA) * 86_400
        return Date().timeIntervalSince(oldestTimestamp) < requiredSpan
    }
}
