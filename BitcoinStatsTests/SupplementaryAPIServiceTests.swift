//
//  SupplementaryAPIServiceTests.swift
//  BitcoinStatsTests
//
//  Created by Jonathan Lehr on 2/16/26.
//  Copyright © 2026 About Objects. All rights reserved.
//

import Foundation
import Testing

@testable import BitcoinStats

/// Tests for SupplementaryAPIService (CoinGecko + blockchain.com) using a mock HTTP client.
@Suite(.serialized)
struct SupplementaryAPIServiceTests {

    // MARK: - CoinGecko Market Data

    @Test func fetchMarketDataDecodesResponse() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedSupplementaryJSON.coinGeckoMarketData
        let service = SupplementaryAPIService(client: mock)

        let result = try await service.fetchMarketData()

        #expect(result.bitcoin.usd == 95234.0)
        #expect(result.bitcoin.usd_market_cap == 1_870_000_000_000.0)
        #expect(result.bitcoin.usd_24h_vol == 42_500_000_000.0)
        #expect(result.bitcoin.usd_24h_change == 2.35)
    }

    @Test func fetchMarketDataHitsCorrectEndpoint() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedSupplementaryJSON.coinGeckoMarketData
        let service = SupplementaryAPIService(client: mock)

        _ = try await service.fetchMarketData()

        let url = mock.lastRequest?.url
        #expect(url?.path.contains("/api/v3/simple/price") == true)
        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        let idsParam = components?.queryItems?.first(where: { $0.name == "ids" })
        #expect(idsParam?.value == "bitcoin")
        let marketCapParam = components?.queryItems?.first(where: { $0.name == "include_market_cap" })
        #expect(marketCapParam?.value == "true")
    }

    @Test func fetchMarketDataThrowsOnHTTPError() async throws {
        let mock = MockHTTPClient()
        mock.responseData = Data()
        mock.statusCode = 429
        let service = SupplementaryAPIService(client: mock)

        await #expect(throws: APIError.self) {
            _ = try await service.fetchMarketData()
        }
    }

    // MARK: - CoinGecko Market Chart

    @Test func fetchMarketChartDecodesResponse() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedSupplementaryJSON.coinGeckoMarketChart
        let service = SupplementaryAPIService(client: mock)

        let result = try await service.fetchMarketChart(days: "30")

        #expect(result.prices.count == 3)
        #expect(result.prices[0][0] == 1703166000000)  // timestamp in ms
        #expect(result.prices[0][1] == 94100.0)
        #expect(result.market_caps.count == 3)
        #expect(result.total_volumes.count == 3)
    }

    @Test func fetchMarketChartHitsCorrectEndpoint() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedSupplementaryJSON.coinGeckoMarketChart
        let service = SupplementaryAPIService(client: mock)

        _ = try await service.fetchMarketChart(days: "90")

        let url = mock.lastRequest?.url
        #expect(url?.path.contains("/api/v3/coins/bitcoin/market_chart") == true)
        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        let daysParam = components?.queryItems?.first(where: { $0.name == "days" })
        #expect(daysParam?.value == "90")
    }

    @Test func fetchMarketChartUsesDefaultDays() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedSupplementaryJSON.coinGeckoMarketChart
        let service = SupplementaryAPIService(client: mock)

        _ = try await service.fetchMarketChart()

        let url = mock.lastRequest?.url
        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        let daysParam = components?.queryItems?.first(where: { $0.name == "days" })
        #expect(daysParam?.value == "365")
    }

    @Test func fetchMarketChartThrowsOnHTTPError() async throws {
        let mock = MockHTTPClient()
        mock.responseData = Data()
        mock.statusCode = 500
        let service = SupplementaryAPIService(client: mock)

        await #expect(throws: APIError.self) {
            _ = try await service.fetchMarketChart()
        }
    }

    // MARK: - CoinGecko API Key Header

    @Test func fetchMarketChartSendsAPIKeyHeaderWhenPresent() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedSupplementaryJSON.coinGeckoMarketChart
        let service = SupplementaryAPIService(client: mock, coinGeckoAPIKey: "test-key-abc")

        _ = try await service.fetchMarketChart(days: "max")

        #expect(mock.lastRequest?.value(forHTTPHeaderField: "x-cg-demo-api-key") == "test-key-abc")
    }

    @Test func fetchMarketChartOmitsAPIKeyHeaderWhenNil() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedSupplementaryJSON.coinGeckoMarketChart
        let service = SupplementaryAPIService(client: mock, coinGeckoAPIKey: nil)

        _ = try await service.fetchMarketChart(days: "30")

        #expect(mock.lastRequest?.value(forHTTPHeaderField: "x-cg-demo-api-key") == nil)
    }

    @Test func fetchMarketChartTreatsEmptyStringKeyAsAbsent() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedSupplementaryJSON.coinGeckoMarketChart
        let service = SupplementaryAPIService(client: mock, coinGeckoAPIKey: "")

        _ = try await service.fetchMarketChart(days: "30")

        #expect(mock.lastRequest?.value(forHTTPHeaderField: "x-cg-demo-api-key") == nil)
    }

    @Test func fetchMarketDataSendsAPIKeyHeaderWhenPresent() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedSupplementaryJSON.coinGeckoMarketData
        let service = SupplementaryAPIService(client: mock, coinGeckoAPIKey: "test-key-abc")

        _ = try await service.fetchMarketData()

        #expect(mock.lastRequest?.value(forHTTPHeaderField: "x-cg-demo-api-key") == "test-key-abc")
    }

    @Test func fetchMarketChartThrowsSpecific401Error() async throws {
        let mock = MockHTTPClient()
        mock.statusCode = 401
        let service = SupplementaryAPIService(client: mock)

        let thrownError = await #expect(throws: APIError.self) {
            _ = try await service.fetchMarketChart(days: "max")
        }
        if case .httpError(let code) = thrownError {
            #expect(code == 401)
        }
    }

    // MARK: - Blockchain.com Chart Data

    @Test func fetchChartDataDecodesResponse() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedSupplementaryJSON.blockchainChartData
        let service = SupplementaryAPIService(client: mock)

        let result = try await service.fetchChartData(chartName: .nUniqueAddresses)

        #expect(result.status == "ok")
        #expect(result.name == "n-unique-addresses")
        #expect(result.unit == "Addresses")
        #expect(result.values.count == 3)
        #expect(result.values[0].x == 1703166000)
        #expect(result.values[0].y == 875432)
    }

    @Test func fetchChartDataHitsCorrectEndpoint() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedSupplementaryJSON.blockchainChartData
        let service = SupplementaryAPIService(client: mock)

        _ = try await service.fetchChartData(chartName: .nUniqueAddresses, timespan: "6months")

        let url = mock.lastRequest?.url
        #expect(url?.path.contains("/charts/n-unique-addresses") == true)
        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        let timespanParam = components?.queryItems?.first(where: { $0.name == "timespan" })
        #expect(timespanParam?.value == "6months")
        let formatParam = components?.queryItems?.first(where: { $0.name == "format" })
        #expect(formatParam?.value == "json")
    }

    @Test func fetchChartDataThrowsOnHTTPError() async throws {
        let mock = MockHTTPClient()
        mock.responseData = Data()
        mock.statusCode = 503
        let service = SupplementaryAPIService(client: mock)

        await #expect(throws: APIError.self) {
            _ = try await service.fetchChartData(chartName: .hashRate)
        }
    }

    // MARK: - Blockchain.com Single Stat

    @Test func fetchStatDecodesPlainTextResponse() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedSupplementaryJSON.blockchainStat
        let service = SupplementaryAPIService(client: mock)

        let value = try await service.fetchStat(name: "marketcap")

        #expect(value == 1_870_000_000_000.0)
    }

    @Test func fetchStatHitsCorrectEndpoint() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedSupplementaryJSON.blockchainStat
        let service = SupplementaryAPIService(client: mock)

        _ = try await service.fetchStat(name: "marketcap")

        let url = mock.lastRequest?.url
        #expect(url?.path.contains("/q/marketcap") == true)
    }

    @Test func fetchStatThrowsOnMalformedResponse() async throws {
        let mock = MockHTTPClient()
        mock.responseData = "not a number".data(using: .utf8)!
        let service = SupplementaryAPIService(client: mock)

        await #expect(throws: APIError.self) {
            _ = try await service.fetchStat(name: "marketcap")
        }
    }

    @Test func fetchStatThrowsOnHTTPError() async throws {
        let mock = MockHTTPClient()
        mock.responseData = Data()
        mock.statusCode = 404
        let service = SupplementaryAPIService(client: mock)

        await #expect(throws: APIError.self) {
            _ = try await service.fetchStat(name: "nonexistent")
        }
    }
}

// MARK: - Bundle Configuration

/// Verifies that the app bundle contains the CoinGecko API key and that the default
/// SupplementaryAPIService init reads it and sends it as a request header.
///
/// These tests catch build configuration regressions (e.g. INFOPLIST_KEY_* entries
/// missing from the pbxproj) that pure unit tests with injected keys cannot detect.
/// They pass because the test target uses BUNDLE_LOADER / TEST_HOST, so Bundle.main
/// is the app bundle, not the test bundle.
@Suite(.serialized)
struct BundleConfigurationTests {

    @Test func coinGeckoAPIKeyPresentInBundle() {
        let key = Bundle.main.object(forInfoDictionaryKey: "COINGECKO_API_KEY") as? String
        #expect(key != nil, "COINGECKO_API_KEY missing from app Info.plist — check INFOPLIST_KEY_COINGECKO_API_KEY in project build settings")
        #expect(key?.isEmpty == false, "COINGECKO_API_KEY is present but empty")
    }

    @Test func defaultServiceInitSendsAPIKeyHeader() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedSupplementaryJSON.coinGeckoMarketChart

        // Default init reads the key from Bundle.main — same code path as production.
        let service = SupplementaryAPIService(client: mock)

        _ = try await service.fetchMarketChart(days: "1")

        let sentKey = mock.lastRequest?.value(forHTTPHeaderField: "x-cg-demo-api-key")
        let bundleKey = Bundle.main.object(forInfoDictionaryKey: "COINGECKO_API_KEY") as? String
        #expect(sentKey != nil, "x-cg-demo-api-key header was not sent — key may not be in bundle")
        #expect(sentKey == bundleKey, "Header value does not match the key in Bundle.main")
    }
}

// MARK: - Canned JSON for Supplementary APIs

nonisolated enum CannedSupplementaryJSON {

    static let coinGeckoMarketData = """
    {
        "bitcoin": {
            "usd": 95234.0,
            "usd_market_cap": 1870000000000.0,
            "usd_24h_vol": 42500000000.0,
            "usd_24h_change": 2.35
        }
    }
    """.data(using: .utf8)!

    static let coinGeckoMarketChart = """
    {
        "prices": [
            [1703166000000, 94100.0],
            [1703252400000, 94500.5],
            [1703338800000, 95234.0]
        ],
        "market_caps": [
            [1703166000000, 1850000000000.0],
            [1703252400000, 1860000000000.0],
            [1703338800000, 1870000000000.0]
        ],
        "total_volumes": [
            [1703166000000, 40000000000.0],
            [1703252400000, 41000000000.0],
            [1703338800000, 42500000000.0]
        ]
    }
    """.data(using: .utf8)!

    static let blockchainChartData = """
    {
        "status": "ok",
        "name": "n-unique-addresses",
        "unit": "Addresses",
        "period": "day",
        "description": "The number of unique addresses used per day.",
        "values": [
            { "x": 1703166000, "y": 875432 },
            { "x": 1703252400, "y": 892105 },
            { "x": 1703338800, "y": 901234 }
        ]
    }
    """.data(using: .utf8)!

    static let blockchainStat = "1870000000000.0".data(using: .utf8)!
}
