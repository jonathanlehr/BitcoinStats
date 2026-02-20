//
//  DataServiceTests.swift
//  BitcoinStatsTests
//
//  Created by Jonathan Lehr on 2/16/26.
//  Copyright © 2026 About Objects. All rights reserved.
//

import CoreData
import Testing

@testable import BitcoinStats

/// Tests for DataService CoreData CRUD operations.
/// Serialized and MainActor-isolated because CoreData's viewContext is main-queue bound.
@Suite(.serialized)
@MainActor
struct DataServiceTests {

    private func makeService() -> DataService {
        DataService(persistenceController: PersistenceController(inMemory: true))
    }

    // MARK: - Metric Save & Fetch

    @Test func saveAndFetchMetric() throws {
        let service = makeService()
        let timestamp = Date()

        try service.saveMetric(type: .price, timestamp: timestamp, value: 95_000.0)

        let results = try service.fetchMetrics(type: .price)
        #expect(results.count == 1)
        #expect(results.first?.value == 95_000.0)
        #expect(results.first?.metricType == .price)
    }

    @Test func fetchMetricsFiltersByType() throws {
        let service = makeService()
        let now = Date()

        try service.saveMetric(type: .price, timestamp: now, value: 95_000.0)
        try service.saveMetric(type: .mvrv, timestamp: now, value: 2.1)
        try service.saveMetric(type: .hashRate, timestamp: now, value: 650.0)

        let priceResults = try service.fetchMetrics(type: .price)
        #expect(priceResults.count == 1)
        #expect(priceResults.first?.value == 95_000.0)

        let mvrvResults = try service.fetchMetrics(type: .mvrv)
        #expect(mvrvResults.count == 1)
        #expect(mvrvResults.first?.value == 2.1)
    }

    @Test func fetchMetricsWithDateFilter() throws {
        let service = makeService()
        let calendar = Calendar.current
        let now = Date()
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: now)!
        let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: now)!

        try service.saveMetric(type: .price, timestamp: fiveDaysAgo, value: 90_000.0)
        try service.saveMetric(type: .price, timestamp: threeDaysAgo, value: 93_000.0)
        try service.saveMetric(type: .price, timestamp: now, value: 95_000.0)

        let fourDaysAgo = calendar.date(byAdding: .day, value: -4, to: now)!
        let recent = try service.fetchMetrics(type: .price, since: fourDaysAgo)
        #expect(recent.count == 2)
    }

    @Test func fetchMetricsWithLimit() throws {
        let service = makeService()
        let calendar = Calendar.current
        let now = Date()

        for i in 0..<10 {
            let date = calendar.date(byAdding: .hour, value: -i, to: now)!
            try service.saveMetric(type: .price, timestamp: date, value: Double(90_000 + i * 100))
        }

        let limited = try service.fetchMetrics(type: .price, limit: 3)
        #expect(limited.count == 3)
    }

    @Test func fetchMetricsOrderedByTimestamp() throws {
        let service = makeService()
        let calendar = Calendar.current
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now)!

        // Insert out of order
        try service.saveMetric(type: .price, timestamp: now, value: 95_000.0)
        try service.saveMetric(type: .price, timestamp: twoDaysAgo, value: 91_000.0)
        try service.saveMetric(type: .price, timestamp: yesterday, value: 93_000.0)

        let results = try service.fetchMetrics(type: .price)
        #expect(results.count == 3)
        #expect(results[0].value == 91_000.0)  // oldest first
        #expect(results[1].value == 93_000.0)
        #expect(results[2].value == 95_000.0)  // newest last
    }

    @Test func latestMetric() throws {
        let service = makeService()
        let calendar = Calendar.current
        let now = Date()

        try service.saveMetric(
            type: .mvrv,
            timestamp: calendar.date(byAdding: .day, value: -1, to: now)!,
            value: 2.0
        )
        try service.saveMetric(type: .mvrv, timestamp: now, value: 2.5)

        let latest = try service.latestMetric(type: .mvrv)
        #expect(latest?.value == 2.5)
    }

    @Test func latestMetricReturnsNilWhenEmpty() throws {
        let service = makeService()
        let latest = try service.latestMetric(type: .nupl)
        #expect(latest == nil)
    }

    @Test func saveMetricWithMetadata() throws {
        let service = makeService()
        let json = "{\"bands\":{\"<1m\":0.15,\"1-3m\":0.10}}"

        try service.saveMetric(
            type: .hodlWaves,
            timestamp: Date(),
            value: 0.0,
            metadataJSON: json
        )

        let results = try service.fetchMetrics(type: .hodlWaves)
        #expect(results.count == 1)

        let metadata = results.first?.metadata
        #expect(metadata != nil)
        #expect(metadata?["bands"] != nil)
    }

    @Test func deleteMetrics() throws {
        let service = makeService()
        let now = Date()

        try service.saveMetric(type: .price, timestamp: now, value: 95_000.0)
        try service.saveMetric(type: .price, timestamp: now, value: 96_000.0)
        try service.saveMetric(type: .mvrv, timestamp: now, value: 2.1)

        try service.deleteMetrics(type: .price)

        let priceResults = try service.fetchMetrics(type: .price)
        #expect(priceResults.isEmpty)

        // MVRV should be untouched
        let mvrvResults = try service.fetchMetrics(type: .mvrv)
        #expect(mvrvResults.count == 1)
    }

    // MARK: - Batch Save

    @Test func saveBatchMetrics() throws {
        let service = makeService()
        let calendar = Calendar.current
        let now = Date()

        let responses = (0..<5).map { i in
            APIMetricResponse(
                timestamp: calendar.date(byAdding: .hour, value: -i, to: now)!,
                value: Double(90_000 + i * 500)
            )
        }

        try service.saveMetrics(type: .price, responses: responses)

        let results = try service.fetchMetrics(type: .price)
        #expect(results.count == 5)
    }

    // MARK: - PriceCandle Save & Fetch

    @Test func saveAndFetchPriceCandle() throws {
        let service = makeService()
        let timestamp = Date()

        try service.savePriceCandle(
            timestamp: timestamp,
            open: 94_000,
            high: 96_000,
            low: 93_000,
            close: 95_500,
            volume: 25_000
        )

        let results = try service.fetchPriceCandles()
        #expect(results.count == 1)

        let candle = results.first!
        #expect(candle.open == 94_000)
        #expect(candle.high == 96_000)
        #expect(candle.low == 93_000)
        #expect(candle.close == 95_500)
        #expect(candle.volume == 25_000)
    }

    @Test func fetchPriceCandlesWithDateRange() throws {
        let service = makeService()
        let calendar = Calendar.current
        let now = Date()

        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -i, to: now)!
            try service.savePriceCandle(
                timestamp: date,
                open: 94_000,
                high: 96_000,
                low: 93_000,
                close: 95_000,
                volume: 20_000
            )
        }

        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: now)!
        let oneDayAgo = calendar.date(byAdding: .day, value: -1, to: now)!

        let ranged = try service.fetchPriceCandles(since: threeDaysAgo, until: oneDayAgo)
        #expect(ranged.count >= 2 && ranged.count <= 3)
    }

    @Test func saveBatchPriceCandles() throws {
        let service = makeService()
        let calendar = Calendar.current
        let now = Date()

        let responses = (0..<3).map { i in
            APIPriceCandleResponse(
                timestamp: calendar.date(byAdding: .day, value: -i, to: now)!,
                open: 94_000,
                high: 96_000,
                low: 93_000,
                close: 95_000,
                volume: 20_000
            )
        }

        try service.savePriceCandles(responses: responses)

        let results = try service.fetchPriceCandles()
        #expect(results.count == 3)
    }

    @Test func deleteAllPriceCandles() throws {
        let service = makeService()

        for _ in 0..<5 {
            try service.savePriceCandle(
                timestamp: Date(),
                open: 94_000,
                high: 96_000,
                low: 93_000,
                close: 95_000,
                volume: 20_000
            )
        }

        try service.deleteAllPriceCandles()

        let results = try service.fetchPriceCandles()
        #expect(results.isEmpty)
    }

    // MARK: - Metric Extension Computed Properties

    @Test func metricTypeComputedProperty() throws {
        let service = makeService()

        try service.saveMetric(type: .hashRate, timestamp: Date(), value: 650.0)
        let result = try service.fetchMetrics(type: .hashRate).first!
        #expect(result.metricType == .hashRate)
        #expect(result.metricTypeRaw == "Hash Rate")
    }

    @Test func metricTypeDefaultsToPrice() throws {
        let service = makeService()
        let context = service.viewContext

        // Create a metric with a bogus raw value
        let metric = Metric(context: context)
        metric.id = UUID()
        metric.metricTypeRaw = "NonexistentMetric"
        metric.timestamp = Date()
        metric.value = 0

        #expect(metric.metricType == .price)
    }
}
