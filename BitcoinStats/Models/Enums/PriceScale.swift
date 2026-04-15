//
//  PriceScale.swift
//  BitcoinStats
//

import Foundation

/// The y-axis scale used on the price chart.
enum PriceScale: String, CaseIterable {
    case log    = "Log"
    case linear = "Linear"
}
