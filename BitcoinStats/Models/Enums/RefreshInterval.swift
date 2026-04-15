//
//  RefreshInterval.swift
//  BitcoinStats
//

import Foundation

/// How often the price view automatically refreshes live data.
enum RefreshInterval: String, CaseIterable {
    case oneMinute      = "1 min"
    case fiveMinutes    = "5 min"
    case fifteenMinutes = "15 min"
    case thirtyMinutes  = "30 min"

    var seconds: TimeInterval {
        switch self {
        case .oneMinute:      60
        case .fiveMinutes:    300
        case .fifteenMinutes: 900
        case .thirtyMinutes:  1_800
        }
    }
}
