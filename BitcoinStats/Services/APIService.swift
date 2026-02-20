//
//  APIService.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import Foundation

/// Handles all network requests to the mempool.space API.
/// `nonisolated` opts this type out of the project's default MainActor isolation —
/// network services don't need actor isolation.
nonisolated final class APIService: Sendable {

    private let client: HTTPClient
    private let baseURL: URL

    init(client: HTTPClient = URLSession.shared,
         baseURL: URL = URL(string: "https://mempool.space")!) {
        self.client = client
        self.baseURL = baseURL
    }

    // MARK: - Price Endpoints

    /// Fetches the current Bitcoin price from mempool.space.
    ///
    /// Response shape:
    /// ```json
    /// { "time": 1703252411, "USD": 43753, "EUR": 40545, ... }
    /// ```
    func fetchCurrentPrice() async throws -> PriceResponse {
        let url = baseURL.appendingPathComponent("/api/v1/prices")
        let request = URLRequest(url: url)
        let (data, response) = try await client.data(for: request)
        try validate(response)
        return try JSONDecoder().decode(PriceResponse.self, from: data)
    }

    /// Fetches historical Bitcoin price data from mempool.space.
    ///
    /// - Parameters:
    ///   - currency: The fiat currency code (e.g. "USD"). Defaults to "USD".
    ///   - timestamp: Optional Unix timestamp to fetch prices around a specific time.
    ///
    /// Response shape:
    /// ```json
    /// {
    ///   "prices": [{ "time": 1499904000, "USD": 2254.9 }, ...],
    ///   "exchangeRates": { "USDEUR": 0.92, ... }
    /// }
    /// ```
    func fetchHistoricalPrices(
        currency: String = "USD",
        timestamp: Int? = nil
    ) async throws -> HistoricalPriceResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/v1/historical-price"), resolvingAgainstBaseURL: false)!
        var queryItems = [URLQueryItem(name: "currency", value: currency)]
        if let timestamp {
            queryItems.append(URLQueryItem(name: "timestamp", value: String(timestamp)))
        }
        components.queryItems = queryItems

        let request = URLRequest(url: components.url!)
        let (data, response) = try await client.data(for: request)
        try validate(response)
        return try JSONDecoder().decode(HistoricalPriceResponse.self, from: data)
    }

    // MARK: - Mempool Endpoints

    /// Fetches current mempool statistics (unconfirmed transaction pool).
    ///
    /// Response shape:
    /// ```json
    /// { "count": 12345, "vsize": 12345678, "total_fee": 1234567,
    ///   "fee_histogram": [[10.5, 123456], ...] }
    /// ```
    func fetchMempoolStats() async throws -> MempoolStatsResponse {
        let url = baseURL.appendingPathComponent("/api/mempool")
        let request = URLRequest(url: url)
        let (data, response) = try await client.data(for: request)
        try validate(response)
        return try JSONDecoder().decode(MempoolStatsResponse.self, from: data)
    }

    /// Fetches recommended transaction fees.
    ///
    /// Response shape:
    /// ```json
    /// { "fastestFee": 10, "halfHourFee": 8, "hourFee": 6,
    ///   "economyFee": 4, "minimumFee": 1 }
    /// ```
    func fetchRecommendedFees() async throws -> RecommendedFeesResponse {
        let url = baseURL.appendingPathComponent("/api/v1/fees/recommended")
        let request = URLRequest(url: url)
        let (data, response) = try await client.data(for: request)
        try validate(response)
        return try JSONDecoder().decode(RecommendedFeesResponse.self, from: data)
    }

    // MARK: - Mining Endpoints

    /// Fetches network hash rate and difficulty over a given time period.
    ///
    /// - Parameter timePeriod: One of "1m", "3m", "6m", "1y", "2y", "3y", "all".
    ///
    /// Response shape:
    /// ```json
    /// {
    ///   "hashrates": [{ "timestamp": 1703252411, "avgHashrate": 5.5e20 }],
    ///   "difficulty": [{ "timestamp": 1703252411, "difficulty": 7.2e13, "height": 823456 }],
    ///   "currentHashrate": 5.5e20,
    ///   "currentDifficulty": 7.2e13
    /// }
    /// ```
    func fetchHashrateAndDifficulty(
        timePeriod: String = "1m"
    ) async throws -> HashrateResponse {
        let url = baseURL.appendingPathComponent("/api/v1/mining/hashrate/\(timePeriod)")
        let request = URLRequest(url: url)
        let (data, response) = try await client.data(for: request)
        try validate(response)
        return try JSONDecoder().decode(HashrateResponse.self, from: data)
    }

    /// Fetches recent difficulty adjustments.
    ///
    /// - Parameter count: Number of recent adjustments to fetch.
    ///
    /// Response is an array of arrays: `[[timestamp, height, difficulty, adjustment], ...]`
    func fetchDifficultyAdjustments(
        count: Int = 3
    ) async throws -> [[Double]] {
        let url = baseURL.appendingPathComponent("/api/v1/mining/difficulty-adjustments/\(count)")
        let request = URLRequest(url: url)
        let (data, response) = try await client.data(for: request)
        try validate(response)
        return try JSONDecoder().decode([[Double]].self, from: data)
    }

    // MARK: - Validation

    private func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - Response Types

/// Response from `GET /api/v1/prices`.
nonisolated struct PriceResponse: Codable, Sendable {
    let time: Int
    let USD: Double
    let EUR: Double
    let GBP: Double
    let CAD: Double
    let CHF: Double
    let AUD: Double
    let JPY: Double
}

/// Response from `GET /api/v1/historical-price`.
nonisolated struct HistoricalPriceResponse: Codable, Sendable {
    let prices: [HistoricalPricePoint]
    let exchangeRates: ExchangeRates
}

nonisolated struct HistoricalPricePoint: Codable, Sendable {
    let time: Int
    let USD: Double?
    let EUR: Double?
    let GBP: Double?
    let CAD: Double?
    let CHF: Double?
    let AUD: Double?
    let JPY: Double?
}

nonisolated struct ExchangeRates: Codable, Sendable {
    let USDEUR: Double?
    let USDGBP: Double?
    let USDCAD: Double?
    let USDCHF: Double?
    let USDAUD: Double?
    let USDJPY: Double?
}

/// Response from `GET /api/mempool`.
nonisolated struct MempoolStatsResponse: Codable, Sendable {
    let count: Int
    let vsize: Int
    let total_fee: Int
    let fee_histogram: [[Double]]
}

/// Response from `GET /api/v1/fees/recommended`.
nonisolated struct RecommendedFeesResponse: Codable, Sendable {
    let fastestFee: Int
    let halfHourFee: Int
    let hourFee: Int
    let economyFee: Int
    let minimumFee: Int
}

/// Response from `GET /api/v1/mining/hashrate/:timePeriod`.
nonisolated struct HashrateResponse: Codable, Sendable {
    let hashrates: [HashrateDataPoint]
    let difficulty: [DifficultyDataPoint]
    let currentHashrate: Double
    let currentDifficulty: Double
}

nonisolated struct HashrateDataPoint: Codable, Sendable {
    let timestamp: Int
    let avgHashrate: Double
}

nonisolated struct DifficultyDataPoint: Codable, Sendable {
    let timestamp: Int
    let difficulty: Double
    let height: Int
}

// MARK: - Errors

nonisolated enum APIError: Error, LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server."
        case .httpError(let statusCode):
            return "HTTP error \(statusCode)."
        }
    }
}
