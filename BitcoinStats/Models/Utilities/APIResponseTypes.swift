//
//  APIResponseTypes.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import Foundation

/// Lightweight struct for parsing metric JSON responses before saving to CoreData.
nonisolated struct APIMetricResponse: Codable, Sendable {
    let timestamp: Date
    let value: Double
}

/// Lightweight struct for parsing OHLCV JSON responses before saving to CoreData.
nonisolated struct APIPriceCandleResponse: Codable, Sendable {
    let timestamp: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
}
