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

    // MARK: - Background Read/Write

    /// Fetches metrics and converts them to ChartDataPoints on a private-queue Core Data context.
    /// The returned array consists of plain value types and is safe to use on any thread.
    func fetchChartData(type: MetricType, since startDate: Date? = nil) async -> [ChartDataPoint] {
        await withCheckedContinuation { continuation in
            persistenceController.container.performBackgroundTask { context in
                let request = NSFetchRequest<Metric>(entityName: "Metric")
                var predicates = [NSPredicate(format: "metricTypeRaw == %@", type.rawValue)]
                if let startDate {
                    predicates.append(NSPredicate(format: "timestamp >= %@", startDate as NSDate))
                }
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Metric.timestamp, ascending: true)]
                let metrics = (try? context.fetch(request)) ?? []
                let points: [ChartDataPoint] = metrics.compactMap { metric in
                    guard let date = metric.timestamp else { return nil }
                    return ChartDataPoint(date: date, value: metric.value)
                }
                continuation.resume(returning: points)
            }
        }
    }

    /// Inserts metric records on a private-queue Core Data context without deleting anything.
    /// The caller is responsible for filtering to only new records before calling this method.
    /// A no-op (no save) when `responses` is empty.
    func insertMetrics(type: MetricType, responses: [APIMetricResponse]) async throws {
        guard !responses.isEmpty else { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            persistenceController.container.performBackgroundTask { context in
                do {
                    for response in responses {
                        _ = Metric(
                            context: context,
                            type: type,
                            timestamp: response.timestamp,
                            value: response.value
                        )
                    }
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Deletes all existing metrics of the given type and inserts replacements,
    /// entirely on a private-queue Core Data context so the main thread is never blocked.
    func replaceMetrics(type: MetricType, with responses: [APIMetricResponse]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            persistenceController.container.performBackgroundTask { context in
                do {
                    let deleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Metric")
                    deleteRequest.predicate = NSPredicate(format: "metricTypeRaw == %@", type.rawValue)
                    let batchDelete = NSBatchDeleteRequest(fetchRequest: deleteRequest)
                    batchDelete.resultType = .resultTypeObjectIDs
                    let result = try context.execute(batchDelete) as? NSBatchDeleteResult
                    if let ids = result?.result as? [NSManagedObjectID], !ids.isEmpty {
                        NSManagedObjectContext.mergeChanges(
                            fromRemoteContextSave: [NSDeletedObjectsKey: ids],
                            into: [self.persistenceController.container.viewContext]
                        )
                    }
                    for response in responses {
                        _ = Metric(
                            context: context,
                            type: type,
                            timestamp: response.timestamp,
                            value: response.value
                        )
                    }
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
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
            // NSManagedObject registers itself with the context on init;
            // no strong reference is needed here — the context owns the object.
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
            // NSManagedObject registers itself with the context on init;
            // no strong reference is needed here — the context owns the object.
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
