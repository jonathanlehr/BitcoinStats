//
//  PriceViewModel.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import Foundation
import os

@MainActor
@Observable
class PriceViewModel {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BitcoinStats",
        category: "PriceViewModel"
    )

    // MARK: - Constants

    /// Maximum number of days for which CoinGecko granular data is fetched and displayed
    /// directly (instead of falling back to the daily CoreData history).
    /// Ranges up to 365 days (1Y) use CoinGecko; 2Y and All use blockchain.com daily/weekly.
    static let granularFetchMaxDays = 365

    /// CoinGecko returns hourly granularity only when a single request window is ≤ 90 days.
    /// Ranges wider than this are split into multiple 90-day windows and stitched together
    /// so every window stays within the hourly threshold.
    private static let singleWindowMaxDays = 90

    /// Maximum number of points to display for granular (CoinGecko) ranges.
    /// After stitching and thinning, all granular ranges target ≤ 750 display points so
    /// chart rendering stays fast while retaining visual fidelity.
    private static let maxGranularPoints = 750

    /// CoinGecko returns timestamps in milliseconds; divide by this to get seconds.
    private static let millisecondsPerSecond: Double = 1_000

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
        dataService: DataService? = nil
    ) {
        self.api = api
        self.supplementaryAPI = supplementaryAPI
        self.dataService = dataService ?? DataService()
    }

    // MARK: - Load

    /// Populates the view with cached data immediately, then refreshes from the network.
    ///
    /// Three fetches run in sequence so faster calls populate the UI before slower ones complete:
    /// 1. Current price — mempool.space, fast.
    /// 2. Granular display data — CoinGecko, ranges ≤ 1Y (hourly via 90-day windows).
    /// 3. All-time daily history — blockchain.com, needed for MA overlays.
    func load() async {
        await loadFromCache()

        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        error = nil

        await fetchCurrentPrice()
        await fetchGranularData()
        await fetchAllTimeHistory()

        await computeOverlays()
    }

    // MARK: - Periodic Updates

    /// Starts periodic price updates using the current refresh interval preference.
    /// Any running timer is cancelled first, so this can safely be called when the
    /// interval setting changes to pick up the new value immediately.
    func startPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(
            withTimeInterval: UserPreferences.shared.refreshInterval.seconds,
            repeats: true
        ) { [weak self] _ in
            Task { await self?.load() }
        }
    }

    /// Stops periodic updates.
    func stopPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    /// Fetches only the live price — used by pull-to-refresh so the chart stays put.
    func refreshCurrentPrice() async {
        await fetchCurrentPrice()
    }

    // MARK: - Overlay Toggling

    /// Toggles an overlay on/off in UserPreferences and recomputes overlay data.
    func toggleOverlay(_ overlay: PriceOverlay) {
        if UserPreferences.shared.enabledPriceOverlays.contains(overlay) {
            UserPreferences.shared.enabledPriceOverlays.remove(overlay)
        } else {
            UserPreferences.shared.enabledPriceOverlays.insert(overlay)
        }
        Task { await computeOverlays() }
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

    /// Fetches granular price data from CoinGecko for ranges up to 1Y.
    /// Skipped for 2Y and All, which use the daily CoreData history instead.
    /// Results are cached in memory for 24 hours so switching between ranges is instant.
    ///
    /// CoinGecko only returns hourly data when a single request window is ≤ 90 days.
    /// Ranges wider than 90 days are split into sequential 90-day windows so each window
    /// stays within the hourly threshold. All windows are stitched and thinned to
    /// ≤ maxGranularPoints before display, giving consistent visual density across all
    /// granular ranges (3M ≈ 720 pts, 6M ≈ 720 pts, 1Y ≈ 720 pts).
    private func fetchGranularData() async {
        guard selectedTimeRange.days <= Self.granularFetchMaxDays else { return }

        let range = selectedTimeRange
        let cacheAge = granularCache[range].map { Date().timeIntervalSince($0.fetchedAt) } ?? .infinity

        if cacheAge < oneDaySeconds, let entry = granularCache[range] {
            Self.logger.debug("Granular cache hit for \(range.rawValue, privacy: .public) (age \(Int(cacheAge), privacy: .public)s)")
            priceHistory = entry.data
            if currentPrice == nil { currentPrice = priceHistory.last?.value }
            return
        }

        do {
            var points: [ChartDataPoint]

            if range.days <= Self.singleWindowMaxDays {
                // Single call — CoinGecko returns hourly for ≤ 90-day requests.
                Self.logger.info("Fetching granular data (days=\(range.days, privacy: .public)) from CoinGecko")
                let chart = try await supplementaryAPI.fetchMarketChart(days: String(range.days))
                Self.logger.info("Received \(chart.prices.count, privacy: .public) granular price points")
                points = chart.prices.map { point in
                    ChartDataPoint(
                        date: Date(timeIntervalSince1970: point[0] / Self.millisecondsPerSecond),
                        value: point[1]
                    )
                }
            } else {
                // Multi-window — split into 90-day windows so each stays within CoinGecko's
                // hourly granularity threshold. Windows are fetched oldest-first and stitched.
                let now = Date()
                let totalSeconds = TimeInterval(range.days) * oneDaySeconds
                let windowSeconds = TimeInterval(Self.singleWindowMaxDays) * oneDaySeconds
                let windowCount = Int(ceil(totalSeconds / windowSeconds))
                Self.logger.info("Fetching granular data (days=\(range.days, privacy: .public)) from CoinGecko via \(windowCount, privacy: .public) 90-day windows")

                var allPoints: [ChartDataPoint] = []
                for i in 0..<windowCount {
                    let windowFrom = now.addingTimeInterval(-totalSeconds + TimeInterval(i) * windowSeconds)
                    let windowTo   = min(now.addingTimeInterval(-totalSeconds + TimeInterval(i + 1) * windowSeconds), now)
                    Self.logger.debug("Window \(i + 1, privacy: .public)/\(windowCount, privacy: .public): \(Int(now.timeIntervalSince(windowTo) / 86400), privacy: .public)d–\(Int(now.timeIntervalSince(windowFrom) / 86400), privacy: .public)d ago")
                    let chart = try await supplementaryAPI.fetchMarketChartRange(from: windowFrom, to: windowTo)
                    let windowPoints = chart.prices.map { point in
                        ChartDataPoint(
                            date: Date(timeIntervalSince1970: point[0] / Self.millisecondsPerSecond),
                            value: point[1]
                        )
                    }
                    allPoints.append(contentsOf: windowPoints)
                }

                // Sort and deduplicate any timestamps that overlap at window boundaries.
                allPoints.sort { $0.date < $1.date }
                var seen = Set<Date>()
                allPoints = allPoints.filter { seen.insert($0.date).inserted }

                Self.logger.info("Received \(allPoints.count, privacy: .public) total granular price points across \(windowCount, privacy: .public) windows")
                points = allPoints
            }

            // Thin to ≤ maxGranularPoints so chart rendering stays fast.
            // All granular ranges converge to ~720 display points after thinning:
            //   3M  ≈  2,160 hourly pts → step 3  → 720 pts
            //   6M  ≈  4,320 hourly pts → step 6  → 720 pts
            //   1Y  ≈ 10,800 hourly pts → step 15 → 720 pts
            if points.count > Self.maxGranularPoints {
                let step = (points.count + Self.maxGranularPoints - 1) / Self.maxGranularPoints
                points = Swift.stride(from: 0, to: points.count, by: step).map { points[$0] }
            }
            granularCache[range] = GranularCacheEntry(data: points, fetchedAt: Date())
            priceHistory = points
            if currentPrice == nil { currentPrice = priceHistory.last?.value }
        } catch {
            Self.logger.error("Granular display fetch failed: \(error, privacy: .public)")
            self.error = error.localizedDescription
        }
    }

    /// Fetches daily price history from blockchain.com for MA overlay calculations.
    /// Performs a one-time bootstrap ("all") when data is absent or the stored span is too short
    /// for MA calculations; otherwise does a cheap incremental fetch ("30days") and appends
    /// only records newer than the latest stored timestamp — no deletes, ever.
    ///
    /// blockchain.com is used instead of CoinGecko because the CoinGecko Demo tier caps
    /// historical data at 365 days (error 10012). blockchain.com supports `timespan=all`
    /// back to 2010 with no authentication.
    private func fetchAllTimeHistory() async {
        guard needsHistoryRefresh() else {
            Self.logger.debug("Price history is current — skipping full history fetch")
            if selectedTimeRange.days > Self.granularFetchMaxDays { await loadFromCache() }
            return
        }

        let latestTimestamp = (try? dataService.latestMetric(type: .price))?.timestamp
        let oldestTimestamp = (try? dataService.oldestMetric(type: .price))?.timestamp
        let requiredSpan = TimeInterval(CalculationService.minDailyHistory) * oneDaySeconds
        let hasEnoughSpan = oldestTimestamp.map { Date().timeIntervalSince($0) >= requiredSpan } ?? false
        let timespan = hasEnoughSpan ? "30days" : "all"
        let cutoff = latestTimestamp ?? .distantPast

        // TODO: Persist the last-launch date in UserDefaults. If more than 30 days have
        // elapsed since the last launch, fall back to "all" so the incremental window
        // cannot silently miss records.

        do {
            Self.logger.info("Fetching price history from blockchain.com (timespan=\(timespan, privacy: .public))")
            let chart = try await supplementaryAPI.fetchChartData(chartName: .marketPrice, timespan: timespan)
            // blockchain.com timestamps are Unix seconds (not milliseconds like CoinGecko).
            let newResponses = chart.values.compactMap { point -> APIMetricResponse? in
                let date = Date(timeIntervalSince1970: TimeInterval(point.x))
                guard date > cutoff else { return nil }
                return APIMetricResponse(timestamp: date, value: point.y)
            }
            Self.logger.info("Inserting \(newResponses.count, privacy: .public) new price records (received \(chart.values.count, privacy: .public))")
            try await dataService.insertMetrics(type: .price, responses: newResponses)
            Self.logger.info("Price history save complete")
            if selectedTimeRange.days > Self.granularFetchMaxDays { await loadFromCache() }
        } catch {
            Self.logger.error("Full history fetch failed: \(error, privacy: .public)")
            if selectedTimeRange.days > Self.granularFetchMaxDays {
                await loadFromCache()
                // Only surface the error when there's no cached data to fall back on,
                // so the user sees a message rather than a silently blank chart.
                if priceHistory.isEmpty {
                    self.error = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Private Helpers

    /// Loads the current display range's price data from a background Core Data context into `priceHistory`.
    /// For the "All" range the underlying data is daily (~5,000 points), which would create tens of
    /// thousands of chart marks on the main thread. `TimeRange.allTime.dataGranularity` is `.weekly`,
    /// so the data is resampled to weekly closes (~714 points) before being handed to the chart.
    private func loadFromCache() async {
        let startDate = Calendar.current.date(byAdding: .day, value: -selectedTimeRange.days, to: Date())
        var points = await dataService.fetchChartData(type: .price, since: startDate)
        if selectedTimeRange.dataGranularity == .weekly {
            points = CalculationService.weeklyResample(data: points)
        }
        priceHistory = points
        if currentPrice == nil {
            currentPrice = priceHistory.last?.value
        }
    }

    /// Computes all enabled MA overlays and the Bull Market Support Band from the full stored history.
    /// CoreData fetches happen on the main actor; the CPU-intensive indicator math runs on a
    /// background thread via Task.detached so the main thread is never blocked.
    func computeOverlays() async {
        // Fetch on a private-queue Core Data context — never blocks the main thread.
        let allPoints = await dataService.fetchChartData(type: .price)

        let enabled = UserPreferences.shared.enabledPriceOverlays
        var realizedPricePoints: [ChartDataPoint] = []
        if enabled.contains(.realizedPrice) {
            realizedPricePoints = await dataService.fetchChartData(type: .realizedPrice)
        }
        let startDate = Calendar.current.date(byAdding: .day, value: -selectedTimeRange.days, to: Date())

        // Heavy computation on a background thread — pure functions on value types only.
        let result = await Task.detached(priority: .userInitiated) {
            Self.buildOverlayData(
                allPoints: allPoints,
                enabled: enabled,
                startDate: startDate,
                realizedPricePoints: realizedPricePoints
            )
        }.value

        // Resume on main actor — safe to mutate @Observable state.
        overlayData = result.overlayData
        bullBandSMA = result.bullBandSMA
        bullBandEMA = result.bullBandEMA
    }

    // MARK: - Overlay Computation (background-safe)

    private struct OverlayResult {
        var overlayData: [PriceOverlay: [ChartDataPoint]] = [:]
        var bullBandSMA: [ChartDataPoint] = []
        var bullBandEMA: [ChartDataPoint] = []
    }

    /// Pure computation — no CoreData, no actor state. Safe to call from any thread.
    private nonisolated static func buildOverlayData(
        allPoints: [ChartDataPoint],
        enabled: Set<PriceOverlay>,
        startDate: Date?,
        realizedPricePoints: [ChartDataPoint]
    ) -> OverlayResult {
        func filtered(_ pts: [ChartDataPoint]) -> [ChartDataPoint] {
            guard let d = startDate else { return pts }
            return pts.filter { $0.date >= d }
        }

        var result: [PriceOverlay: [ChartDataPoint]] = [:]

        let needWeekly = enabled.contains(.ma200week)
            || enabled.contains(.ma20week)
            || enabled.contains(.ema21week)
            || enabled.contains(.bullMarketSupportBand)

        var weeklyPoints: [ChartDataPoint] = []
        if needWeekly {
            weeklyPoints = CalculationService.weeklyResample(data: allPoints)
        }

        if enabled.contains(.ma200week) {
            result[.ma200week] = filtered(CalculationService.sma(data: weeklyPoints, period: CalculationService.period200WeekMA))
        }
        if enabled.contains(.ma200day) {
            result[.ma200day] = filtered(CalculationService.sma(data: allPoints, period: CalculationService.period200DayMA))
        }
        if enabled.contains(.ma50day) {
            result[.ma50day] = filtered(CalculationService.sma(data: allPoints, period: CalculationService.period50DayMA))
        }

        let needSMA20 = enabled.contains(.ma20week) || enabled.contains(.bullMarketSupportBand)
        let needEMA21 = enabled.contains(.ema21week) || enabled.contains(.bullMarketSupportBand)

        var sma20: [ChartDataPoint] = []
        var ema21: [ChartDataPoint] = []

        if needSMA20 {
            sma20 = CalculationService.sma(data: weeklyPoints, period: CalculationService.period20WeekMA)
            if enabled.contains(.ma20week) { result[.ma20week] = filtered(sma20) }
        }
        if needEMA21 {
            ema21 = CalculationService.ema(data: weeklyPoints, period: CalculationService.period21WeekEMA)
            if enabled.contains(.ema21week) { result[.ema21week] = filtered(ema21) }
        }

        if enabled.contains(.realizedPrice) {
            result[.realizedPrice] = filtered(realizedPricePoints)
        }

        // Bull Market Support Band: align SMA/EMA pairs by date.
        var outSMA: [ChartDataPoint] = []
        var outEMA: [ChartDataPoint] = []
        if enabled.contains(.bullMarketSupportBand), !sma20.isEmpty, !ema21.isEmpty {
            let smaFiltered = filtered(sma20)
            let emaByDate = Dictionary(uniqueKeysWithValues: filtered(ema21).map { ($0.date, $0.value) })
            for s in smaFiltered {
                if let e = emaByDate[s.date] {
                    outSMA.append(ChartDataPoint(date: s.date, value: s.value))
                    outEMA.append(ChartDataPoint(date: s.date, value: e))
                }
            }
        }

        return OverlayResult(overlayData: result, bullBandSMA: outSMA, bullBandEMA: outEMA)
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
        if Date().timeIntervalSince(latestTimestamp) > oneDaySeconds { return true }

        guard let oldest = try? dataService.oldestMetric(type: .price),
              let oldestTimestamp = oldest.timestamp else {
            return true
        }
        // minDailyHistory = 1400 days — enough raw data for weeklyResample to produce
        // 200 weekly candles for the 200W MA.
        let requiredSpan = TimeInterval(CalculationService.minDailyHistory) * oneDaySeconds
        return Date().timeIntervalSince(oldestTimestamp) < requiredSpan
    }
}
