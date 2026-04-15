//
//  MarketSummaryViewModel.swift
//  BitcoinStats
//
//  Uses Apple's on-device FoundationModels framework (iOS 18.1+) to generate
//  a natural-language Bitcoin market summary from live on-chain data.
//

import Foundation
import FoundationModels
import OSLog

@available(iOS 18.1, *)
@Observable
class MarketSummaryViewModel {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BitcoinStats",
        category: "MarketSummaryViewModel"
    )

    // MARK: - Published State

    private(set) var summary: String = ""
    private(set) var isGenerating = false
    private(set) var error: String?

    // MARK: - Availability

    /// True when Apple Intelligence is ready to use on this device.
    var isModelAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    // MARK: - Dependencies

    private let api: APIService
    private let dataService: DataService

    // MARK: - Init

    init(api: APIService = APIService(), dataService: DataService = DataService()) {
        self.api = api
        self.dataService = dataService
    }

    // MARK: - Generate

    /// Fetches live Bitcoin metrics then asks Apple Intelligence to write a market summary.
    func generate() async {
        guard isModelAvailable else {
            error = "Apple Intelligence is not available on this device. Enable it in Settings > Apple Intelligence & Siri."
            return
        }

        isGenerating = true
        error = nil
        summary = ""
        defer { isGenerating = false }

        // --- 1. Fetch live data ---

        let price: Double
        let priceChangePercent: Double
        let mempoolCount: Int
        let fastestFee: Int
        let hashrate: Double?

        do {
            // Current price
            let priceResponse = try await api.fetchCurrentPrice()
            price = priceResponse.USD
            Self.logger.info("Fetched price: $\(String(format: "%.0f", price), privacy: .public)")

            // 24-hour price change: fetch the price from roughly one day ago
            let oneDayAgoTimestamp = Int(Date().timeIntervalSince1970 - oneDaySeconds)
            let historicalResponse = try await api.fetchHistoricalPrices(timestamp: oneDayAgoTimestamp)
            let priceOneDayAgo = historicalResponse.prices.first?.USD ?? price
            priceChangePercent = priceOneDayAgo > 0 ? (price - priceOneDayAgo) / priceOneDayAgo * 100 : 0

            // Mempool and fee data
            async let mempoolFetch = api.fetchMempoolStats()
            async let feesFetch = api.fetchRecommendedFees()
            let (mempool, fees) = try await (mempoolFetch, feesFetch)
            mempoolCount = mempool.count
            fastestFee = fees.fastestFee

            // Hash rate (short-range request returns currentHashrate)
            let hashrateResponse = try await api.fetchHashrateAndDifficulty(timePeriod: "1m")
            let rawHashrate = hashrateResponse.currentHashrate ?? hashrateResponse.hashrates.last?.avgHashrate
            hashrate = rawHashrate.map { $0 / hPerSecToEHPerSec }  // convert H/s → EH/s

        } catch {
            Self.logger.error("Data fetch failed: \(error, privacy: .public)")
            self.error = "Could not fetch live data: \(error.localizedDescription)"
            return
        }

        // --- 2. Compute Mayer Multiple from cached price history ---

        let mayerMultiple = computeMayerMultiple()

        // --- 3. Build the prompt ---

        let prompt = buildPrompt(
            price: price,
            priceChangePercent: priceChangePercent,
            mempoolCount: mempoolCount,
            fastestFee: fastestFee,
            hashrate: hashrate,
            mayerMultiple: mayerMultiple
        )

        // --- 4. Generate summary with Apple Intelligence ---

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            summary = response.content
            Self.logger.info("Summary generated successfully")
        } catch {
            Self.logger.error("FoundationModels generation failed: \(error, privacy: .public)")
            self.error = "Summary generation failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Private Helpers

    /// Builds the prompt sent to Apple Intelligence.
    private func buildPrompt(
        price: Double,
        priceChangePercent: Double,
        mempoolCount: Int,
        fastestFee: Int,
        hashrate: Double?,
        mayerMultiple: Double?
    ) -> String {
        let priceStr = String(format: "$%.0f", price)
        let changeSign = priceChangePercent >= 0 ? "+" : ""
        let changeStr = "\(changeSign)\(String(format: "%.1f", priceChangePercent))%"

        var bullets = [
            "Current price: \(priceStr) (\(changeStr) over the past 24 hours)",
            "Unconfirmed transactions (mempool): \(mempoolCount.formatted())",
            "Fastest fee rate: \(fastestFee) sat/vB",
        ]
        if let hr = hashrate {
            bullets.append("Network hash rate: \(String(format: "%.0f", hr)) EH/s")
        }
        if let mm = mayerMultiple {
            bullets.append(
                "Mayer Multiple: \(String(format: "%.2f", mm)) " +
                "(price ÷ 200-day MA; historically elevated above 2.4)"
            )
        }

        let metricsText = bullets.map { "- \($0)" }.joined(separator: "\n")

        return """
        You are a concise Bitcoin market analyst writing for a mobile analytics app. \
        Based on the live on-chain metrics below, write a 3–4 sentence market summary. \
        Be factual and objective. Do not make price predictions or investment recommendations.

        \(metricsText)
        """
    }

    /// Derives the current Mayer Multiple (price ÷ 200-day SMA) from the daily price
    /// history already stored in CoreData by PriceViewModel. Returns nil if there is
    /// insufficient history.
    private func computeMayerMultiple() -> Double? {
        let allMetrics = (try? dataService.fetchMetrics(type: .price)) ?? []
        let allPoints = allMetrics
            .compactMap { m -> ChartDataPoint? in
                guard let date = m.timestamp else { return nil }
                return ChartDataPoint(date: date, value: m.value)
            }
            .sorted { $0.date < $1.date }

        guard allPoints.count >= CalculationService.period200DayMA else { return nil }

        let sma200 = CalculationService.sma(data: allPoints, period: CalculationService.period200DayMA)
        guard let lastSMA = sma200.last, lastSMA.value > 0,
              let lastPrice = allPoints.last?.value else { return nil }

        return lastPrice / lastSMA.value
    }
}
