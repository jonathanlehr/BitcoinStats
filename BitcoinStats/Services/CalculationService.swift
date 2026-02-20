//
//  CalculationService.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import Foundation

/// Pure computation functions for deriving technical indicators from price series.
/// All methods are stateless and operate on sorted (oldest-first) ChartDataPoint arrays.
nonisolated enum CalculationService {

    // MARK: - MA Periods (in daily data points, per MetricsDefinitions.md)

    static let period200WeekMA  = 200 * 7   // 1400 days
    static let period200DayMA   = 200
    static let period50DayMA    = 50
    static let period20WeekMA   = 20 * 7    // 140 days
    static let period21WeekEMA  = 21 * 7    // 147 days

    // MARK: - Simple Moving Average

    /// Computes an SMA using an O(n) sliding-window algorithm.
    ///
    /// The result array is shorter than the input: the first value appears at index `period - 1`
    /// of the input (i.e. once there are enough preceding points to fill the window).
    ///
    /// - Parameters:
    ///   - data: Price series sorted chronologically (oldest first).
    ///   - period: Number of data points in the rolling window.
    static func sma(data: [ChartDataPoint], period: Int) -> [ChartDataPoint] {
        guard period > 0, data.count >= period else { return [] }

        var result = [ChartDataPoint]()
        result.reserveCapacity(data.count - period + 1)

        // Seed the running sum with the first full window.
        var runningSum = data.prefix(period).reduce(0.0) { $0 + $1.value }
        result.append(ChartDataPoint(date: data[period - 1].date, value: runningSum / Double(period)))

        for i in period ..< data.count {
            runningSum += data[i].value - data[i - period].value
            result.append(ChartDataPoint(date: data[i].date, value: runningSum / Double(period)))
        }
        return result
    }

    // MARK: - Exponential Moving Average

    /// Computes an EMA seeded by the SMA of the first `period` points.
    ///
    /// Smoothing factor: `k = 2 / (period + 1)`
    ///
    /// - Parameters:
    ///   - data: Price series sorted chronologically (oldest first).
    ///   - period: Lookback window (e.g. 147 for a 21-week EMA).
    static func ema(data: [ChartDataPoint], period: Int) -> [ChartDataPoint] {
        guard period > 0, data.count >= period else { return [] }

        let k = 2.0 / Double(period + 1)

        var result = [ChartDataPoint]()
        result.reserveCapacity(data.count - period + 1)

        // Seed with the SMA of the first window.
        var prev = data.prefix(period).reduce(0.0) { $0 + $1.value } / Double(period)
        result.append(ChartDataPoint(date: data[period - 1].date, value: prev))

        for i in period ..< data.count {
            prev = data[i].value * k + prev * (1.0 - k)
            result.append(ChartDataPoint(date: data[i].date, value: prev))
        }
        return result
    }
}
