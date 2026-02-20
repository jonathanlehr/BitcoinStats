//
//  ChartDataPoint.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import Foundation

/// Lightweight value type for feeding data into Swift Charts.
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}
