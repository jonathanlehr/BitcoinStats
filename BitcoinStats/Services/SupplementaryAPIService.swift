//
//  SupplementaryAPIService.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import Foundation

/// Handles network requests to supplementary data sources:
/// CoinGecko (market cap, historical price) and blockchain.com (realized cap, active addresses).
/// `nonisolated` opts this type out of the project's default MainActor isolation.
nonisolated final class SupplementaryAPIService: Sendable {

    private let client: HTTPClient
    private let coinGeckoBaseURL: URL
    private let blockchainBaseURL: URL

    init(
        client: HTTPClient = URLSession.shared,
        coinGeckoBaseURL: URL = URL(string: "https://api.coingecko.com")!,
        blockchainBaseURL: URL = URL(string: "https://api.blockchain.info")!
    ) {
        self.client = client
        self.coinGeckoBaseURL = coinGeckoBaseURL
        self.blockchainBaseURL = blockchainBaseURL
    }

    // MARK: - CoinGecko Endpoints

    /// Fetches current Bitcoin market data from CoinGecko.
    ///
    /// Includes price, market cap, 24h volume, and 24h change percentage.
    ///
    /// Uses: `GET /api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_market_cap=true&include_24hr_vol=true&include_24hr_change=true`
    func fetchMarketData() async throws -> CoinGeckoMarketResponse {
        var components = URLComponents(
            url: coinGeckoBaseURL.appendingPathComponent("/api/v3/simple/price"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "ids", value: "bitcoin"),
            URLQueryItem(name: "vs_currencies", value: "usd"),
            URLQueryItem(name: "include_market_cap", value: "true"),
            URLQueryItem(name: "include_24hr_vol", value: "true"),
            URLQueryItem(name: "include_24hr_change", value: "true")
        ]

        let request = URLRequest(url: components.url!)
        let (data, response) = try await client.data(for: request)
        try validate(response)
        return try JSONDecoder().decode(CoinGeckoMarketResponse.self, from: data)
    }

    /// Fetches historical Bitcoin price data from CoinGecko.
    ///
    /// - Parameter days: Number of days of historical data (e.g. 30, 90, 365, "max").
    ///
    /// Uses: `GET /api/v3/coins/bitcoin/market_chart?vs_currency=usd&days=<days>`
    func fetchMarketChart(days: String = "365") async throws -> CoinGeckoChartResponse {
        var components = URLComponents(
            url: coinGeckoBaseURL.appendingPathComponent("/api/v3/coins/bitcoin/market_chart"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "vs_currency", value: "usd"),
            URLQueryItem(name: "days", value: days)
        ]

        let request = URLRequest(url: components.url!)
        let (data, response) = try await client.data(for: request)
        try validate(response)
        return try JSONDecoder().decode(CoinGeckoChartResponse.self, from: data)
    }

    // MARK: - Blockchain.com Endpoints

    /// Fetches time-series chart data from blockchain.com.
    ///
    /// Uses the blockchain.com charts API with JSON format.
    /// Supports various chart types via `BlockchainChartName` (active addresses, hash rate, etc.).
    func fetchChartData(
        chartName: BlockchainChartName,
        timespan: String = "1year"
    ) async throws -> BlockchainChartResponse {
        var components = URLComponents(
            url: blockchainBaseURL.appendingPathComponent("/charts/\(chartName.rawValue)"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "timespan", value: timespan),
            URLQueryItem(name: "format", value: "json")
        ]

        let request = URLRequest(url: components.url!)
        let (data, response) = try await client.data(for: request)
        try validate(response)
        return try JSONDecoder().decode(BlockchainChartResponse.self, from: data)
    }

    /// Fetches a single stats value from blockchain.com (e.g., market cap, difficulty).
    ///
    /// Uses: `GET /q/<stat_name>`
    func fetchStat(name: String) async throws -> Double {
        let url = blockchainBaseURL.appendingPathComponent("/q/\(name)")
        let request = URLRequest(url: url)
        let (data, response) = try await client.data(for: request)
        try validate(response)

        guard let text = String(data: data, encoding: .utf8),
              let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw APIError.invalidResponse
        }
        return value
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

// MARK: - CoinGecko Response Types

/// Response from CoinGecko `GET /api/v3/simple/price?ids=bitcoin&...`
///
/// Shape: `{ "bitcoin": { "usd": 95234, "usd_market_cap": 1.87e12, ... } }`
nonisolated struct CoinGeckoMarketResponse: Codable, Sendable {
    let bitcoin: CoinGeckoBitcoinData
}

nonisolated struct CoinGeckoBitcoinData: Codable, Sendable {
    let usd: Double
    let usd_market_cap: Double
    let usd_24h_vol: Double
    let usd_24h_change: Double
}

/// Response from CoinGecko `GET /api/v3/coins/bitcoin/market_chart`
///
/// Shape: `{ "prices": [[timestamp, price], ...], "market_caps": [...], "total_volumes": [...] }`
nonisolated struct CoinGeckoChartResponse: Codable, Sendable {
    let prices: [[Double]]
    let market_caps: [[Double]]
    let total_volumes: [[Double]]
}

// MARK: - Blockchain.com Response Types

/// Available chart names from blockchain.com charts API.
nonisolated enum BlockchainChartName: String {
    case marketCap = "market-cap"
    case totalBitcoins = "total-bitcoins"
    case nUniqueAddresses = "n-unique-addresses"
    case estimatedTransactionVolume = "estimated-transaction-volume-usd"
    case hashRate = "hash-rate"
    case difficulty = "difficulty"
    case minersRevenue = "miners-revenue"
    case transactionsPerSecond = "transactions-per-second"
}

/// Response from blockchain.com charts API.
///
/// Shape: `{ "status": "ok", "name": "...", "unit": "...", "period": "...",
///           "description": "...", "values": [{ "x": 1703252411, "y": 95234 }, ...] }`
nonisolated struct BlockchainChartResponse: Codable, Sendable {
    let status: String
    let name: String
    let unit: String
    let period: String
    let description: String
    let values: [BlockchainChartDataPoint]
}

nonisolated struct BlockchainChartDataPoint: Codable, Sendable {
    let x: Int      // Unix timestamp
    let y: Double    // Value
}
