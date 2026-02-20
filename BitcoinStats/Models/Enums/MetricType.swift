//
//  MetricType.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import Foundation

// MARK: - MetricType

enum MetricType: String, CaseIterable, Identifiable {
    // Valuation Metrics
    case price = "Price"
    case marketCap = "Market Cap"
    case mvrv = "MVRV Ratio"
    case realizedPrice = "Realized Price"
    case mayerMultiple = "Mayer Multiple"
    case nupl = "NUPL"

    // Network Metrics
    case mempoolSize = "Mempool Size"
    case hashRate = "Hash Rate"
    case difficulty = "Difficulty"
    case activeAddresses = "Active Addresses"

    // Holder Behavior Metrics
    case hodlWaves = "HODL Waves"
    case lthSupply = "LTH Supply"

    var id: String { rawValue }

    var category: MetricCategory {
        switch self {
        case .price, .marketCap, .mvrv, .realizedPrice, .mayerMultiple, .nupl:
            return .valuation
        case .mempoolSize, .hashRate, .difficulty, .activeAddresses:
            return .network
        case .hodlWaves, .lthSupply:
            return .holders
        }
    }

    var description: String {
        switch self {
        case .price:
            "Current Bitcoin price in USD"
        case .marketCap:
            "Total value of all Bitcoin in circulation"
        case .mvrv:
            "Market Value to Realized Value. Ratio above 3.5 historically indicates overvaluation, below 1.0 indicates undervaluation."
        case .realizedPrice:
            "Average price at which all BTC last moved. Network's aggregate cost basis."
        case .mayerMultiple:
            "Price divided by 200-day MA. Values >2.4 suggest overheating, <0.8 suggest undervaluation."
        case .nupl:
            "Net Unrealized Profit/Loss. Shows aggregate profit/loss of all holders as percentage. >0.75 = euphoria, <0 = capitulation."
        case .mempoolSize:
            "Current size of the mempool (unconfirmed transactions) in megabytes."
        case .hashRate:
            "Network hash rate - computational power securing the network."
        case .difficulty:
            "How hard it is to find a valid block. Adjusts every ~2 weeks."
        case .activeAddresses:
            "Number of unique addresses involved in transactions per day."
        case .hodlWaves:
            "Distribution of Bitcoin supply by age. Shows holding conviction."
        case .lthSupply:
            "Percentage of supply held by Long-Term Holders (155+ days)."
        }
    }

    var unit: String {
        switch self {
        case .price, .marketCap, .realizedPrice: "USD"
        case .hashRate: "EH/s"
        case .mempoolSize: "MB"
        case .mvrv, .mayerMultiple, .nupl: "ratio"
        case .lthSupply, .hodlWaves: "%"
        case .difficulty: ""
        case .activeAddresses: "addresses"
        }
    }

    var preferredChartType: ChartType {
        switch self {
        case .hodlWaves, .mempoolSize: .stackedArea
        default: .line
        }
    }

    func format(_ value: Double) -> String {
        switch self {
        case .price, .realizedPrice:
            return value.formatted(.currency(code: "USD"))
        case .marketCap:
            return "$\(String(format: "%.2f", value / 1_000_000_000))B"
        case .hashRate:
            let measurement = Measurement(value: value, unit: UnitHashRate.exahashesPerSecond)
            return MeasurementFormatter().string(from: measurement)
        case .mvrv, .mayerMultiple:
            return String(format: "%.2f", value)
        case .nupl:
            return String(format: "%.1f%%", value * 100)
        case .mempoolSize:
            return String(format: "%.1f MB", value)
        case .lthSupply:
            return String(format: "%.1f%%", value)
        case .difficulty:
            return String(format: "%.2fT", value / 1_000_000_000_000)
        case .activeAddresses:
            return Int(value).formatted(.number)
        case .hodlWaves:
            return String(format: "%.1f%%", value)
        }
    }
}

// MARK: - MetricCategory

enum MetricCategory: String, CaseIterable {
    case valuation = "Valuation"
    case network = "Network"
    case holders = "Holders"
}

// MARK: - ChartType

enum ChartType {
    case line
    case area
    case stackedArea
    case candlestick
}
