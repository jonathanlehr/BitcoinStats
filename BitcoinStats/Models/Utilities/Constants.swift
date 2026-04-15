//
//  Constants.swift
//  BitcoinStats
//
//  Module-level constants shared across ViewModels and Services.
//

import Foundation

/// Seconds in one day. Used for cache-staleness thresholds.
let oneDaySeconds: TimeInterval = 86_400

/// Converts a hash rate from raw H/s (as returned by mempool.space) to EH/s.
/// Equals 10^18, the SI "exa" prefix.
let hPerSecToEHPerSec: Double = 1e18
