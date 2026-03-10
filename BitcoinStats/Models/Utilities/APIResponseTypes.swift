//
//  APIResponseTypes.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import Foundation

/// Intermediate data transfer object (DTO) for a single metric data point.
///
/// API responses are decoded into these structs before being persisted to CoreData.
/// Using a dedicated DTO keeps the parsing logic separate from the managed object layer.
nonisolated struct APIMetricResponse: Codable, Sendable {
    let timestamp: Date
    let value: Double
}

/// Intermediate DTO for a single OHLCV (open/high/low/close/volume) price candle.
///
/// Decoded from API responses and then saved to the `PriceCandle` CoreData entity.
nonisolated struct APIPriceCandleResponse: Codable, Sendable {
    let timestamp: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
}
