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

    // MARK: - Constants

    /// Maximum number of days for which CoinGecko returns sub-daily granular data.
    /// Ranges at or below this use CoinGecko for display; longer ranges use the
    /// all-time daily history stored in CoreData.
    static let granularFetchMaxDays = 90

    /// One day expressed in seconds. Used for cache staleness checks.
    private static let oneDaySeconds: TimeInterval = 86_400

    /// CoinGecko returns timestamps in milliseconds; divide by this to get seconds.
    private static let millisecondsPerSecond: Double = 1_000

    /// Interval for periodic price updates (5 minutes).
    private static let updateInterval: TimeInterval = 300

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

    /// Caches short-range granular price data fetched from CoinGecko.
    /// Entries are valid for 24 hours so toggling between short ranges avoids redundant network calls.
    private struct GranularCacheEntry {
        let data: [ChartDataPoint]
        let fetchedAt: Date
    }
    private var granularCache: [TimeRange: GranularCacheEntry] = [:]

    // MARK: - Periodic Updates

    private var updateTimer: Timer?

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

    /// Populates the view with cached data immediately, then refreshes from the network.
    ///
    /// Three fetches run in sequence so faster calls populate the UI before slower ones complete:
    /// 1. Current price — mempool.space, fast.
    /// 2. Granular display data — CoinGecko, short ranges only (≤ 90 days).
    /// 3. All-time daily history — blockchain.com, needed for MA overlays.
    func load() async {
        loadFromCache()
        computeOverlays()

        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        error = nil

        await fetchCurrentPrice()
        await fetchGranularData()
        await fetchAllTimeHistory()

        computeOverlays()
    }

    // MARK: - Periodic Updates

    /// Starts periodic updates every 5 minutes to refresh price data.
    func startPeriodicUpdates() {
        guard updateTimer == nil else { return }
        updateTimer = Timer.scheduledTimer(withTimeInterval: Self.updateInterval, repeats: true) { [weak self] _ in
            Task { await self?.load() }
        }
    }

    /// Stops periodic updates.
    func stopPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
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

    // MARK: - Private Fetch Steps

    /// Fetches the live Bitcoin price from mempool.space.
    /// Always runs; a failure sets `error` but doesn't prevent history from loading.
    private func fetchCurrentPrice() async {
        do {
            Self.logger.info("Fetching current price from mempool.space")
            let price = try await api.fetchCurrentPrice()
            currentPrice = price.USD
            Self.logger.info("Current price: $\(String(format: "%.0f", price.USD), privacy: .public)")
        } catch {
            Self.logger.error("Current price fetch failed: \(error, privacy: .public)")
            self.error = error.localizedDescription
        }
    }

    /// Fetches sub-daily granular price data from CoinGecko for short time ranges (≤ 90 days).
    /// Skipped entirely for longer ranges, which use the all-time history instead.
    /// Results are cached in memory for 24 hours so switching between short ranges is instant.
    private func fetchGranularData() async {
        guard selectedTimeRange.days <= Self.granularFetchMaxDays else { return }

        let range = selectedTimeRange
        let cacheAge = granularCache[range].map { Date().timeIntervalSince($0.fetchedAt) } ?? .infinity

        if cacheAge < Self.oneDaySeconds, let entry = granularCache[range] {
            Self.logger.debug("Granular cache hit for \(range.rawValue, privacy: .public) (age \(Int(cacheAge), privacy: .public)s)")
            priceHistory = entry.data
            if currentPrice == nil { currentPrice = priceHistory.last?.value }
            return
        }

        do {
            Self.logger.info("Fetching granular data (days=\(self.selectedTimeRange.days, privacy: .public)) from CoinGecko")
            let chart = try await supplementaryAPI.fetchMarketChart(days: String(selectedTimeRange.days))
            Self.logger.info("Received \(chart.prices.count) granular price points")
            let points = chart.prices.map { point in
                // CoinGecko timestamps are milliseconds; divide by 1,000 to get seconds.
                ChartDataPoint(
                    date: Date(timeIntervalSince1970: point[0] / Self.millisecondsPerSecond),
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

    /// Fetches the complete daily price history from blockchain.com for MA overlay calculations.
    /// Skips the network fetch when stored data is fresh. Non-fatal: MA overlays simply won't
    /// render if this fails and there is no cached fallback.
    ///
    /// blockchain.com is used instead of CoinGecko because the CoinGecko Demo tier caps
    /// historical data at 365 days (error 10012). blockchain.com supports `timespan=all`
    /// back to 2010 with no authentication.
    private func fetchAllTimeHistory() async {
        guard needsHistoryRefresh() else {
            Self.logger.debug("Price history is current — skipping full history fetch")
            if selectedTimeRange.days > Self.granularFetchMaxDays { loadFromCache() }
            return
        }

        do {
            Self.logger.info("Fetching full price history from blockchain.com")
            let chart = try await supplementaryAPI.fetchChartData(chartName: .marketPrice, timespan: "all")
            Self.logger.info("Received \(chart.values.count) price points — saving to CoreData")
            try dataService.deleteMetrics(type: .price)
            let responses = chart.values.map { point in
                // blockchain.com timestamps are Unix seconds (not milliseconds like CoinGecko).
                APIMetricResponse(
                    timestamp: Date(timeIntervalSince1970: TimeInterval(point.x)),
                    value: point.y
                )
            }
            try dataService.saveMetrics(type: .price, responses: responses)
            Self.logger.info("Price history save complete")
            if selectedTimeRange.days > Self.granularFetchMaxDays { loadFromCache() }
        } catch {
            Self.logger.error("Full history fetch failed: \(error, privacy: .public)")
            if selectedTimeRange.days > Self.granularFetchMaxDays {
                loadFromCache()
                // Only surface the error when there's no cached data to fall back on,
                // so the user sees a message rather than a silently blank chart.
                if priceHistory.isEmpty {
                    self.error = error.localizedDescription
                }
            }
        }
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

        // Realized price overlay — data source deferred; no free API currently available.
        if enabled.contains(.realizedPrice) {
            let metrics = (try? dataService.fetchMetrics(type: .realizedPrice)) ?? []
            let points = metrics.compactMap { m -> ChartDataPoint? in
                guard let date = m.timestamp else { return nil }
                return ChartDataPoint(date: date, value: m.value)
            }
            result[.realizedPrice] = filtered(points)
        }

        // Bull Market Support Band: align SMA and EMA series by date so only matched
        // pairs are drawn. Values are stored as-is — the lines intentionally cross in
        // real data, and that crossing is a meaningful signal.
        alignBullMarketSupportBand(sma20: sma20, ema21: ema21, filtered: filtered)

        overlayData = result
    }

    /// Pairs SMA and EMA data points by date, storing the aligned results in
    /// `bullBandSMA` and `bullBandEMA`. Points with no matching counterpart are dropped.
    private func alignBullMarketSupportBand(
        sma20: [ChartDataPoint],
        ema21: [ChartDataPoint],
        filtered: ([ChartDataPoint]) -> [ChartDataPoint]
    ) {
        guard UserPreferences.shared.enabledPriceOverlays.contains(.bullMarketSupportBand),
              !sma20.isEmpty, !ema21.isEmpty else {
            bullBandSMA = []
            bullBandEMA = []
            return
        }

        let smaFiltered = filtered(sma20)
        // Build a date-keyed lookup so each SMA point can find its EMA counterpart in O(1).
        let emaValueByDate = Dictionary(uniqueKeysWithValues: filtered(ema21).map { ($0.date, $0.value) })

        var smaPoints: [ChartDataPoint] = []
        var emaPoints: [ChartDataPoint] = []
        for s in smaFiltered {
            if let e = emaValueByDate[s.date] {
                smaPoints.append(ChartDataPoint(date: s.date, value: s.value))
                emaPoints.append(ChartDataPoint(date: s.date, value: e))
            }
        }
        bullBandSMA = smaPoints
        bullBandEMA = emaPoints
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
        if Date().timeIntervalSince(latestTimestamp) > Self.oneDaySeconds { return true }

        guard let oldest = try? dataService.oldestMetric(type: .price),
              let oldestTimestamp = oldest.timestamp else {
            return true
        }
        // minDailyHistory = 1400 days — enough raw data for weeklyResample to produce
        // 200 weekly candles for the 200W MA.
        let requiredSpan = TimeInterval(CalculationService.minDailyHistory) * Self.oneDaySeconds
        return Date().timeIntervalSince(oldestTimestamp) < requiredSpan
    }
}
