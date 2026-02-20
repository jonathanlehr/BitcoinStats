//
//  Metric+Extensions.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import CoreData
import Foundation

extension Metric {

    /// Maps the raw string stored in CoreData back to the MetricType enum.
    var metricType: MetricType {
        MetricType(rawValue: metricTypeRaw ?? "Price") ?? .price
    }

    /// Parses the optional metadataJSON string into a dictionary.
    var metadata: [String: Any]? {
        guard let jsonString = metadataJSON,
              let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return dict
    }

    /// Convenience initializer for creating a new Metric with required values.
    convenience init(
        context: NSManagedObjectContext,
        type: MetricType,
        timestamp: Date,
        value: Double,
        metadataJSON: String? = nil
    ) {
        self.init(context: context)
        self.id = UUID()
        self.metricTypeRaw = type.rawValue
        self.timestamp = timestamp
        self.value = value
        self.metadataJSON = metadataJSON
    }
}
