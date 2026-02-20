//
//  MockHTTPClient.swift
//  BitcoinStatsTests
//
//  Created by Jonathan Lehr on 2/16/26.
//  Copyright © 2026 About Objects. All rights reserved.
//

import Foundation

@testable import BitcoinStats

/// A mock HTTP client that returns canned responses for testing.
/// `nonisolated` opts the type out of default MainActor isolation.
/// `@unchecked Sendable` because tests are serialized — no actual data race risk.
nonisolated final class MockHTTPClient: HTTPClient, @unchecked Sendable {

    /// The data to return from `data(for:)`.
    var responseData: Data = Data()

    /// The HTTP status code to use in the response. Defaults to 200.
    var statusCode: Int = 200

    /// The last request that was passed to `data(for:)`.
    private(set) var lastRequest: URLRequest?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (responseData, response)
    }
}

// MARK: - Canned JSON Responses

nonisolated enum CannedJSON {

    static let currentPrice = """
    {
        "time": 1703252411,
        "USD": 95234,
        "EUR": 87500,
        "GBP": 75200,
        "CAD": 129800,
        "CHF": 83600,
        "AUD": 144300,
        "JPY": 14250000
    }
    """.data(using: .utf8)!

    static let historicalPrice = """
    {
        "prices": [
            { "time": 1703166000, "USD": 94100.0 },
            { "time": 1703170000, "USD": 94500.5 },
            { "time": 1703174000, "USD": 95234.0 }
        ],
        "exchangeRates": {
            "USDEUR": 0.92,
            "USDGBP": 0.79,
            "USDCAD": 1.36,
            "USDCHF": 0.88,
            "USDAUD": 1.52,
            "USDJPY": 149.7
        }
    }
    """.data(using: .utf8)!

    static let emptyHistoricalPrice = """
    {
        "prices": [],
        "exchangeRates": {
            "USDEUR": 0.92,
            "USDGBP": 0.79,
            "USDCAD": 1.36,
            "USDCHF": 0.88,
            "USDAUD": 1.52,
            "USDJPY": 149.7
        }
    }
    """.data(using: .utf8)!

    // MARK: - Mempool Responses

    static let mempoolStats = """
    {
        "count": 45231,
        "vsize": 87654321,
        "total_fee": 2345678,
        "fee_histogram": [[12.5, 345678], [8.0, 234567], [4.0, 123456]]
    }
    """.data(using: .utf8)!

    static let recommendedFees = """
    {
        "fastestFee": 12,
        "halfHourFee": 8,
        "hourFee": 6,
        "economyFee": 4,
        "minimumFee": 1
    }
    """.data(using: .utf8)!

    // MARK: - Mining Responses

    static let hashrateAndDifficulty = """
    {
        "hashrates": [
            { "timestamp": 1703166000, "avgHashrate": 5.5e20 },
            { "timestamp": 1703252400, "avgHashrate": 5.6e20 },
            { "timestamp": 1703338800, "avgHashrate": 5.45e20 }
        ],
        "difficulty": [
            { "timestamp": 1703166000, "difficulty": 72006146478567.1, "height": 823000 },
            { "timestamp": 1703252400, "difficulty": 72006146478567.1, "height": 823144 }
        ],
        "currentHashrate": 5.6e20,
        "currentDifficulty": 72006146478567.1
    }
    """.data(using: .utf8)!

    static let difficultyAdjustments = """
    [
        [1703252400, 823000, 72006146478567.1, 2.35],
        [1702043200, 821000, 70343519904866.5, -1.12],
        [1700834000, 819000, 71140447001344.8, 3.07]
    ]
    """.data(using: .utf8)!
}
