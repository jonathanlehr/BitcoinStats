//
//  TimeRange.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import Foundation

// MARK: - TimeRange

enum TimeRange: String, CaseIterable, Identifiable {
    case day = "24H"
    case week = "1W"
    case month = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case year = "1Y"
    case twoYears = "2Y"
    case allTime = "All"

    var id: String { rawValue }

    /// The approximate number of calendar days this range spans.
    ///
    /// Used to build date-filtered CoreData fetch requests and to determine which
    /// API to call. `.allTime` returns a large sentinel value (5,000) rather than
    /// a precise day count — the intent is "fetch everything available."
    var days: Int {
        switch self {
        case .day: 1
        case .week: 7
        case .month: 30
        case .threeMonths: 90
        case .sixMonths: 180
        case .year: 365
        case .twoYears: 730
        case .allTime: 5_000
        }
    }

    var dataGranularity: DataGranularity {
        switch self {
        case .day, .week, .month, .threeMonths, .sixMonths, .year: .hourly
        case .twoYears: .daily
        case .allTime: .weekly
        }
    }
}

// MARK: - DataGranularity

enum DataGranularity {
    case hourly
    case daily
    case weekly

    var seconds: TimeInterval {
        switch self {
        case .hourly: 3_600
        case .daily: 86_400
        case .weekly: 604_800
        }
    }
}
