//
//  UserPreferences.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import Foundation
import Observation

/// Singleton that persists user preferences to UserDefaults.
/// Uses @Observable so SwiftUI views automatically track changes.
@MainActor
@Observable
class UserPreferences {

    static let shared = UserPreferences()

    // MARK: - Keys

    private enum Keys {
        static let enabledOverlays = "enabledPriceOverlays"
        static let selectedMetric = "selectedMetric"
        static let selectedTimeRange = "selectedTimeRange"
        static let miniChartMetrics = "miniChartMetrics"
    }

    // MARK: - Defaults

    static let defaultOverlays: Set<PriceOverlay> = [.ma200week, .bullMarketSupportBand]
    static let defaultMetric: MetricType = .price
    static let defaultTimeRange: TimeRange = .month
    static let defaultMiniCharts: [MetricType] = [.mvrv, .mempoolSize, .hashRate]

    // MARK: - Observed Properties

    var enabledPriceOverlays: Set<PriceOverlay> {
        didSet { saveOverlays() }
    }

    var selectedMetric: MetricType {
        didSet { UserDefaults.standard.set(selectedMetric.rawValue, forKey: Keys.selectedMetric) }
    }

    var selectedTimeRange: TimeRange {
        didSet { UserDefaults.standard.set(selectedTimeRange.rawValue, forKey: Keys.selectedTimeRange) }
    }

    var miniChartMetrics: [MetricType] {
        didSet {
            let rawValues = miniChartMetrics.map(\.rawValue)
            UserDefaults.standard.set(rawValues, forKey: Keys.miniChartMetrics)
        }
    }

    // MARK: - Init

    private init() {
        // Load overlays
        if let savedOverlays = UserDefaults.standard.stringArray(forKey: Keys.enabledOverlays) {
            self.enabledPriceOverlays = Set(savedOverlays.compactMap { PriceOverlay(rawValue: $0) })
        } else {
            self.enabledPriceOverlays = Self.defaultOverlays
        }

        // Load selected metric
        if let raw = UserDefaults.standard.string(forKey: Keys.selectedMetric),
           let metric = MetricType(rawValue: raw) {
            self.selectedMetric = metric
        } else {
            self.selectedMetric = Self.defaultMetric
        }

        // Load selected time range
        if let raw = UserDefaults.standard.string(forKey: Keys.selectedTimeRange),
           let range = TimeRange(rawValue: raw) {
            self.selectedTimeRange = range
        } else {
            self.selectedTimeRange = Self.defaultTimeRange
        }

        // Load mini chart metrics
        if let rawValues = UserDefaults.standard.stringArray(forKey: Keys.miniChartMetrics) {
            self.miniChartMetrics = rawValues.compactMap { MetricType(rawValue: $0) }
        } else {
            self.miniChartMetrics = Self.defaultMiniCharts
        }
    }

    // MARK: - Helpers

    private func saveOverlays() {
        let rawValues = enabledPriceOverlays.map(\.rawValue)
        UserDefaults.standard.set(rawValues, forKey: Keys.enabledOverlays)
    }
}
