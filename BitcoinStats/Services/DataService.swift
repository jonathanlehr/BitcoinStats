//
//  DataService.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import CoreData
import Foundation

/// Encapsulates all CoreData CRUD operations for Metric and PriceCandle entities.
/// ViewModels should go through this service rather than building fetch requests directly.
class DataService {

    let persistenceController: PersistenceController

    var viewContext: NSManagedObjectContext {
        persistenceController.container.viewContext
    }

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    // MARK: - Metric Operations

    /// Saves a single metric data point.
    @discardableResult
    func saveMetric(
        type: MetricType,
        timestamp: Date,
        value: Double,
        metadataJSON: String? = nil
    ) throws -> Metric {
        let metric = Metric(
            context: viewContext,
            type: type,
            timestamp: timestamp,
            value: value,
            metadataJSON: metadataJSON
        )
        try viewContext.save()
        return metric
    }

    /// Saves a batch of metric data points from API responses.
    func saveMetrics(
        type: MetricType,
        responses: [APIMetricResponse]
    ) throws {
        for response in responses {
            _ = Metric(
                context: viewContext,
                type: type,
                timestamp: response.timestamp,
                value: response.value
            )
        }
        try viewContext.save()
    }

    /// Fetches metrics of a given type, ordered by timestamp ascending.
    func fetchMetrics(
        type: MetricType,
        since startDate: Date? = nil,
        limit: Int? = nil
    ) throws -> [Metric] {
        let request = NSFetchRequest<Metric>(entityName: "Metric")

        var predicates = [NSPredicate(format: "metricTypeRaw == %@", type.rawValue)]
        if let startDate {
            predicates.append(NSPredicate(format: "timestamp >= %@", startDate as NSDate))
        }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Metric.timestamp, ascending: true)]

        if let limit {
            request.fetchLimit = limit
        }

        return try viewContext.fetch(request)
    }

    /// Returns the most recent metric of a given type, or nil if none exists.
    func latestMetric(type: MetricType) throws -> Metric? {
        let request = NSFetchRequest<Metric>(entityName: "Metric")
        request.predicate = NSPredicate(format: "metricTypeRaw == %@", type.rawValue)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Metric.timestamp, ascending: false)]
        request.fetchLimit = 1
        return try viewContext.fetch(request).first
    }

    /// Returns the oldest metric of a given type, or nil if none exists.
    func oldestMetric(type: MetricType) throws -> Metric? {
        let request = NSFetchRequest<Metric>(entityName: "Metric")
        request.predicate = NSPredicate(format: "metricTypeRaw == %@", type.rawValue)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Metric.timestamp, ascending: true)]
        request.fetchLimit = 1
        return try viewContext.fetch(request).first
    }

    /// Deletes all metrics of a given type.
    func deleteMetrics(type: MetricType) throws {
        let request = NSFetchRequest<Metric>(entityName: "Metric")
        request.predicate = NSPredicate(format: "metricTypeRaw == %@", type.rawValue)
        let objects = try viewContext.fetch(request)
        for object in objects {
            viewContext.delete(object)
        }
        try viewContext.save()
    }

    // MARK: - PriceCandle Operations

    /// Saves a single price candle.
    @discardableResult
    func savePriceCandle(
        timestamp: Date,
        open: Double,
        high: Double,
        low: Double,
        close: Double,
        volume: Double
    ) throws -> PriceCandle {
        let candle = PriceCandle(
            context: viewContext,
            timestamp: timestamp,
            open: open,
            high: high,
            low: low,
            close: close,
            volume: volume
        )
        try viewContext.save()
        return candle
    }

    /// Saves a batch of price candles from API responses.
    func savePriceCandles(responses: [APIPriceCandleResponse]) throws {
        for response in responses {
            _ = PriceCandle(
                context: viewContext,
                timestamp: response.timestamp,
                open: response.open,
                high: response.high,
                low: response.low,
                close: response.close,
                volume: response.volume
            )
        }
        try viewContext.save()
    }

    /// Fetches price candles ordered by timestamp ascending, optionally filtered by date range.
    func fetchPriceCandles(
        since startDate: Date? = nil,
        until endDate: Date? = nil,
        limit: Int? = nil
    ) throws -> [PriceCandle] {
        let request = NSFetchRequest<PriceCandle>(entityName: "PriceCandle")

        var predicates: [NSPredicate] = []
        if let startDate {
            predicates.append(NSPredicate(format: "timestamp >= %@", startDate as NSDate))
        }
        if let endDate {
            predicates.append(NSPredicate(format: "timestamp <= %@", endDate as NSDate))
        }
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PriceCandle.timestamp, ascending: true)]

        if let limit {
            request.fetchLimit = limit
        }

        return try viewContext.fetch(request)
    }

    /// Deletes all price candles.
    func deleteAllPriceCandles() throws {
        let request = NSFetchRequest<PriceCandle>(entityName: "PriceCandle")
        let objects = try viewContext.fetch(request)
        for object in objects {
            viewContext.delete(object)
        }
        try viewContext.save()
    }
}
