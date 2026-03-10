//
//  ChartDataPoint.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import Foundation

/// A single (date, value) data point for rendering in Swift Charts.
///
/// Each instance is assigned a new `UUID` on creation. Swift Charts requires `Identifiable`
/// elements to render `ForEach` series, but does not persist or compare IDs across reloads —
/// a fresh UUID per instance is intentional and correct here.
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}
