//
//  PriceCandle+Extensions.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import CoreData
import Foundation

extension PriceCandle {

    /// Convenience initializer for creating a new PriceCandle with required values.
    convenience init(
        context: NSManagedObjectContext,
        timestamp: Date,
        open: Double,
        high: Double,
        low: Double,
        close: Double,
        volume: Double
    ) {
        self.init(context: context)
        self.id = UUID()
        self.timestamp = timestamp
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
    }
}
