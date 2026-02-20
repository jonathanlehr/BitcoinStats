//
//  APIServiceTests.swift
//  BitcoinStatsTests
//
//  Created by Jonathan Lehr on 2/16/26.
//  Copyright © 2026 About Objects. All rights reserved.
//

import Foundation
import Testing

@testable import BitcoinStats

/// Tests for APIService using a mock HTTP client (no real network calls).
@Suite(.serialized)
struct APIServiceTests {

    // MARK: - Current Price

    @Test func fetchCurrentPriceDecodesResponse() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedJSON.currentPrice
        let service = APIService(client: mock)

        let price = try await service.fetchCurrentPrice()

        #expect(price.USD == 95234)
        #expect(price.EUR == 87500)
        #expect(price.GBP == 75200)
        #expect(price.time == 1703252411)
    }

    @Test func fetchCurrentPriceHitsCorrectEndpoint() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedJSON.currentPrice
        let service = APIService(client: mock)

        _ = try await service.fetchCurrentPrice()

        let url = mock.lastRequest?.url
        #expect(url?.path.contains("/api/v1/prices") == true)
    }

    @Test func fetchCurrentPriceThrowsOnHTTPError() async throws {
        let mock = MockHTTPClient()
        mock.responseData = Data()
        mock.statusCode = 500
        let service = APIService(client: mock)

        await #expect(throws: APIError.self) {
            _ = try await service.fetchCurrentPrice()
        }
    }

    @Test func fetchCurrentPriceThrowsOnMalformedJSON() async throws {
        let mock = MockHTTPClient()
        mock.responseData = "{ not valid json".data(using: .utf8)!
        let service = APIService(client: mock)

        await #expect(throws: DecodingError.self) {
            _ = try await service.fetchCurrentPrice()
        }
    }

    // MARK: - Historical Prices

    @Test func fetchHistoricalPricesDecodesResponse() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedJSON.historicalPrice
        let service = APIService(client: mock)

        let history = try await service.fetchHistoricalPrices()

        #expect(history.prices.count == 3)
        #expect(history.prices[0].USD == 94100.0)
        #expect(history.prices[2].USD == 95234.0)
        #expect(history.exchangeRates.USDEUR == 0.92)
    }

    @Test func fetchHistoricalPricesIncludesCurrencyQueryParam() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedJSON.historicalPrice
        let service = APIService(client: mock)

        _ = try await service.fetchHistoricalPrices(currency: "EUR")

        let url = mock.lastRequest?.url
        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        let currencyParam = components?.queryItems?.first(where: { $0.name == "currency" })
        #expect(currencyParam?.value == "EUR")
    }

    @Test func fetchHistoricalPricesIncludesTimestampQueryParam() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedJSON.historicalPrice
        let service = APIService(client: mock)

        _ = try await service.fetchHistoricalPrices(timestamp: 1500000000)

        let url = mock.lastRequest?.url
        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        let timestampParam = components?.queryItems?.first(where: { $0.name == "timestamp" })
        #expect(timestampParam?.value == "1500000000")
    }

    @Test func fetchHistoricalPricesHandlesEmptyPricesArray() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedJSON.emptyHistoricalPrice
        let service = APIService(client: mock)

        let history = try await service.fetchHistoricalPrices()

        #expect(history.prices.isEmpty)
        #expect(history.exchangeRates.USDEUR == 0.92)
    }

    @Test func fetchHistoricalPricesThrowsOnHTTPError() async throws {
        let mock = MockHTTPClient()
        mock.responseData = Data()
        mock.statusCode = 429
        let service = APIService(client: mock)

        await #expect(throws: APIError.self) {
            _ = try await service.fetchHistoricalPrices()
        }
    }

    // MARK: - Mempool Stats

    @Test func fetchMempoolStatsDecodesResponse() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedJSON.mempoolStats
        let service = APIService(client: mock)

        let stats = try await service.fetchMempoolStats()

        #expect(stats.count == 45231)
        #expect(stats.vsize == 87654321)
        #expect(stats.total_fee == 2345678)
        #expect(stats.fee_histogram.count == 3)
        #expect(stats.fee_histogram[0][0] == 12.5)
        #expect(stats.fee_histogram[0][1] == 345678)
    }

    @Test func fetchMempoolStatsHitsCorrectEndpoint() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedJSON.mempoolStats
        let service = APIService(client: mock)

        _ = try await service.fetchMempoolStats()

        let url = mock.lastRequest?.url
        #expect(url?.path.contains("/api/mempool") == true)
    }

    @Test func fetchMempoolStatsThrowsOnHTTPError() async throws {
        let mock = MockHTTPClient()
        mock.responseData = Data()
        mock.statusCode = 503
        let service = APIService(client: mock)

        await #expect(throws: APIError.self) {
            _ = try await service.fetchMempoolStats()
        }
    }

    // MARK: - Recommended Fees

    @Test func fetchRecommendedFeesDecodesResponse() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedJSON.recommendedFees
        let service = APIService(client: mock)

        let fees = try await service.fetchRecommendedFees()

        #expect(fees.fastestFee == 12)
        #expect(fees.halfHourFee == 8)
        #expect(fees.hourFee == 6)
        #expect(fees.economyFee == 4)
        #expect(fees.minimumFee == 1)
    }

    @Test func fetchRecommendedFeesHitsCorrectEndpoint() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedJSON.recommendedFees
        let service = APIService(client: mock)

        _ = try await service.fetchRecommendedFees()

        let url = mock.lastRequest?.url
        #expect(url?.path.contains("/api/v1/fees/recommended") == true)
    }

    @Test func fetchRecommendedFeesThrowsOnHTTPError() async throws {
        let mock = MockHTTPClient()
        mock.responseData = Data()
        mock.statusCode = 500
        let service = APIService(client: mock)

        await #expect(throws: APIError.self) {
            _ = try await service.fetchRecommendedFees()
        }
    }

    // MARK: - Hashrate & Difficulty

    @Test func fetchHashrateDecodesResponse() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedJSON.hashrateAndDifficulty
        let service = APIService(client: mock)

        let result = try await service.fetchHashrateAndDifficulty()

        #expect(result.hashrates.count == 3)
        #expect(result.hashrates[0].timestamp == 1703166000)
        #expect(result.hashrates[0].avgHashrate == 5.5e20)
        #expect(result.difficulty.count == 2)
        #expect(result.difficulty[0].height == 823000)
        #expect(result.currentHashrate == 5.6e20)
        #expect(result.currentDifficulty == 72006146478567.1)
    }

    @Test func fetchHashrateHitsCorrectEndpoint() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedJSON.hashrateAndDifficulty
        let service = APIService(client: mock)

        _ = try await service.fetchHashrateAndDifficulty(timePeriod: "6m")

        let url = mock.lastRequest?.url
        #expect(url?.path.contains("/api/v1/mining/hashrate/6m") == true)
    }

    @Test func fetchHashrateUsesDefaultTimePeriod() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedJSON.hashrateAndDifficulty
        let service = APIService(client: mock)

        _ = try await service.fetchHashrateAndDifficulty()

        let url = mock.lastRequest?.url
        #expect(url?.path.contains("/api/v1/mining/hashrate/1m") == true)
    }

    @Test func fetchHashrateThrowsOnHTTPError() async throws {
        let mock = MockHTTPClient()
        mock.responseData = Data()
        mock.statusCode = 429
        let service = APIService(client: mock)

        await #expect(throws: APIError.self) {
            _ = try await service.fetchHashrateAndDifficulty()
        }
    }

    // MARK: - Difficulty Adjustments

    @Test func fetchDifficultyAdjustmentsDecodesResponse() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedJSON.difficultyAdjustments
        let service = APIService(client: mock)

        let adjustments = try await service.fetchDifficultyAdjustments()

        #expect(adjustments.count == 3)
        // First adjustment: [timestamp, height, difficulty, adjustment%]
        #expect(adjustments[0][0] == 1703252400)  // timestamp
        #expect(adjustments[0][1] == 823000)       // height
        #expect(adjustments[0][3] == 2.35)         // adjustment %
    }

    @Test func fetchDifficultyAdjustmentsHitsCorrectEndpoint() async throws {
        let mock = MockHTTPClient()
        mock.responseData = CannedJSON.difficultyAdjustments
        let service = APIService(client: mock)

        _ = try await service.fetchDifficultyAdjustments(count: 5)

        let url = mock.lastRequest?.url
        #expect(url?.path.contains("/api/v1/mining/difficulty-adjustments/5") == true)
    }

    @Test func fetchDifficultyAdjustmentsThrowsOnHTTPError() async throws {
        let mock = MockHTTPClient()
        mock.responseData = Data()
        mock.statusCode = 500
        let service = APIService(client: mock)

        await #expect(throws: APIError.self) {
            _ = try await service.fetchDifficultyAdjustments()
        }
    }
}
