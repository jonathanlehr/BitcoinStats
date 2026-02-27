//
//  PriceViewModel.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import Foundation
import os

@Observable
class PriceViewModel {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BitcoinStats",
        category: "PriceViewModel"
    )

    // MARK: - Published State

    private(set) var priceHistory: [ChartDataPoint] = []
    private(set) var overlayData: [PriceOverlay: [ChartDataPoint]] = [:]
    /// 20-week SMA component of the Bull Market Support Band.
    private(set) var bullBandSMA: [ChartDataPoint] = []
    /// 21-week EMA component of the Bull Market Support Band.
    private(set) var bullBandEMA: [ChartDataPoint] = []
    private(set) var currentPrice: Double?
    private(set) var isLoading = false
    private(set) var error: String?

    // MARK: - User Preferences (pass-through)

    var selectedTimeRange: TimeRange {
        get { UserPreferences.shared.selectedTimeRange }
        set { UserPreferences.shared.selectedTimeRange = newValue }
    }

    // MARK: - In-Memory Granular Cache

    private struct GranularCacheEntry {
        let data: [ChartDataPoint]
        let fetchedAt: Date
    }
    private var granularCache: [TimeRange: GranularCacheEntry] = [:]

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

        // Step 1 — Current price (mempool.space, fast).
        do {
            Self.logger.info("Fetching current price from mempool.space")
            let price = try await api.fetchCurrentPrice()
            currentPrice = price.USD
            Self.logger.info("Current price: $\(String(format: "%.0f", price.USD), privacy: .public)")
        } catch {
            Self.logger.error("Current price fetch failed: \(error, privacy: .public)")
            self.error = error.localizedDescription
        }

        // Step 2 — Granular display data for short ranges (CoinGecko, ≤ 90 days).
        // Fetched *before* the heavy all-time history so the chart is immediately responsive.
        // CoinGecko returns sub-hourly for days=1, hourly for days=2–90.
        // Results are cached in memory for 24 hours so switching ranges doesn't re-fetch.
        if selectedTimeRange.days <= 90 {
            let range = selectedTimeRange
            let cacheAge = granularCache[range].map { Date().timeIntervalSince($0.fetchedAt) } ?? .infinity
            if cacheAge < 86_400, let entry = granularCache[range] {
                Self.logger.debug("Granular cache hit for \(range.rawValue, privacy: .public) (age \(Int(cacheAge), privacy: .public)s)")
                priceHistory = entry.data
                if currentPrice == nil { currentPrice = priceHistory.last?.value }
            } else {
                do {
                    Self.logger.info("Fetching granular data (days=\(self.selectedTimeRange.days, privacy: .public)) from CoinGecko")
                    let chart = try await supplementaryAPI.fetchMarketChart(
                        days: String(selectedTimeRange.days)
                    )
                    Self.logger.info("Received \(chart.prices.count) granular price points")
                    let points = chart.prices.map { point in
                        ChartDataPoint(
                            date: Date(timeIntervalSince1970: point[0] / 1000),
                            value: point[1]
                        )
                    }
                    granularCache[range] = GranularCacheEntry(data: points, fetchedAt: Date())
                    priceHistory = points
                    if currentPrice == nil { currentPrice = priceHistory.last?.value }
                } catch {
                    Self.logger.error("Granular display fetch failed: \(error, privacy: .public)")
                    self.error = error.localizedDescription
                }
            }
        }

        // Step 3 — All-time daily history for MA computation (CoinGecko, days=max).
        // Fetched after the display data so step 2 is never blocked by this slower request.
        // Failures here are non-fatal: MAs simply won't render until the next successful fetch.
        if needsHistoryRefresh() {
            do {
                // CoinGecko Demo tier caps historical data at 365 days (error 10012).
                // Use blockchain.com instead — no auth required, supports timespan=all
                // back to 2010, giving us the full history needed for MA calculations.
                Self.logger.info("Fetching full price history from blockchain.com")
                let chart = try await supplementaryAPI.fetchChartData(
                    chartName: .marketPrice, timespan: "all"
                )
                Self.logger.info("Received \(chart.values.count) price points — saving to CoreData")
                try dataService.deleteMetrics(type: .price)
                let responses = chart.values.map { point in
                    // blockchain.com timestamps are Unix seconds (not ms like CoinGecko).
                    APIMetricResponse(
                        timestamp: Date(timeIntervalSince1970: TimeInterval(point.x)),
                        value: point.y
                    )
                }
                try dataService.saveMetrics(type: .price, responses: responses)
                Self.logger.info("Price history save complete")
                if selectedTimeRange.days > 90 { loadFromCache() }
            } catch {
                Self.logger.error("Full history fetch failed: \(error, privacy: .public)")
                if selectedTimeRange.days > 90 {
                    loadFromCache()
                    // Surface the error when there's no cached data to fall back on,
                    // so the user sees a message instead of a blank chart.
                    if priceHistory.isEmpty {
                        self.error = error.localizedDescription
                    }
                }
            }
        } else {
            Self.logger.debug("Price history is current — skipping full history fetch")
            if selectedTimeRange.days > 90 { loadFromCache() }
        }

        computeOverlays()
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

        // All week-based indicators use weekly-resampled data.
        // Compute weeklyPoints once whenever any of them is needed.
        let needWeekly = enabled.contains(.ma200week)
            || enabled.contains(.ma20week)
            || enabled.contains(.ema21week)
            || enabled.contains(.bullMarketSupportBand)

        var weeklyPoints: [ChartDataPoint] = []
        if needWeekly {
            weeklyPoints = CalculationService.weeklyResample(data: allPoints)
        }

        if enabled.contains(.ma200week) {
            let ma = CalculationService.sma(data: weeklyPoints, period: CalculationService.period200WeekMA)
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

        // 20W SMA and 21W EMA: computed on weekly data with their true weekly periods.
        let needSMA20 = enabled.contains(.ma20week) || enabled.contains(.bullMarketSupportBand)
        let needEMA21 = enabled.contains(.ema21week) || enabled.contains(.bullMarketSupportBand)

        var sma20: [ChartDataPoint] = []
        var ema21: [ChartDataPoint] = []

        if needSMA20 {
            sma20 = CalculationService.sma(data: weeklyPoints, period: CalculationService.period20WeekMA)
            if enabled.contains(.ma20week) {
                result[.ma20week] = filtered(sma20)
            }
        }

        if needEMA21 {
            ema21 = CalculationService.ema(data: weeklyPoints, period: CalculationService.period21WeekEMA)
            if enabled.contains(.ema21week) {
                result[.ema21week] = filtered(ema21)
            }
        }

        // Realized price — loaded from CoreData (populated by Step 4 in load()).
        if enabled.contains(.realizedPrice) {
            let metrics = (try? dataService.fetchMetrics(type: .realizedPrice)) ?? []
            let points = metrics.compactMap { m -> ChartDataPoint? in
                guard let date = m.timestamp else { return nil }
                return ChartDataPoint(date: date, value: m.value)
            }
            result[.realizedPrice] = filtered(points)
        }

        // Bull Market Support Band: 20W SMA and 21W EMA stored as their actual values.
        // Do NOT force min/max ordering — the lines cross in real data, and that crossing
        // is a meaningful signal that must be preserved.
        if enabled.contains(.bullMarketSupportBand), !sma20.isEmpty, !ema21.isEmpty {
            let smaFiltered = filtered(sma20)
            let emaByDate = Dictionary(
                uniqueKeysWithValues: filtered(ema21).map { ($0.date, $0.value) }
            )
            var smaPoints: [ChartDataPoint] = []
            var emaPoints: [ChartDataPoint] = []
            for s in smaFiltered {
                if let e = emaByDate[s.date] {
                    smaPoints.append(ChartDataPoint(date: s.date, value: s.value))
                    emaPoints.append(ChartDataPoint(date: s.date, value: e))
                }
            }
            bullBandSMA = smaPoints
            bullBandEMA = emaPoints
        } else {
            bullBandSMA = []
            bullBandEMA = []
        }

        overlayData = result
    }

    /// Returns true when the stored daily price history should be re-fetched:
    /// - No data exists.
    /// - Fewer than 1,400 daily data points (not enough to resample into 200 weekly candles).
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
        // minDailyHistory = 1400 days — enough raw data for weeklyResample to produce
        // 200 weekly candles for the 200W MA.
        let requiredSpan = TimeInterval(CalculationService.minDailyHistory) * 86_400
        return Date().timeIntervalSince(oldestTimestamp) < requiredSpan
    }

}
