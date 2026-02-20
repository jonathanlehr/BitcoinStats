//
//  PriceOverlay.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import SwiftUI

enum PriceOverlay: String, CaseIterable, Identifiable {
    case ma200week = "200-Week MA"
    case ma200day = "200-Day MA"
    case ma50day = "50-Day MA"
    case ma20week = "20-Week MA"
    case ema21week = "21-Week EMA"
    case bullMarketSupportBand = "Bull Market Support Band"
    case realizedPrice = "Realized Price"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .ma200week: .red
        case .ma200day: .blue
        case .ma50day: .purple
        case .ma20week: .teal
        case .ema21week: .green
        case .bullMarketSupportBand: .mint
        case .realizedPrice: .pink
        }
    }

    var lineWidth: CGFloat {
        switch self {
        case .bullMarketSupportBand: 0 // Area fill, not a line
        default: 2
        }
    }

    var description: String {
        switch self {
        case .ma200week:
            "200-week moving average. Long-term trend indicator and historical support level in bull markets."
        case .ma200day:
            "200-day moving average. Important medium-term trend indicator."
        case .ma50day:
            "50-day moving average. Short-term trend indicator."
        case .ma20week:
            "20-week simple moving average. Component of Bull Market Support Band."
        case .ema21week:
            "21-week exponential moving average. Component of Bull Market Support Band."
        case .bullMarketSupportBand:
            "Band between 20-week SMA and 21-week EMA. Bull markets typically hold above this range."
        case .realizedPrice:
            "Average price at which all BTC last moved. Represents the network's aggregate cost basis."
        }
    }
}
