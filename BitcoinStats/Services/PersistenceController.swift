//
//  PersistenceController.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import CoreData

/// Manages the Core Data stack for the application.
struct PersistenceController {

    static let shared = PersistenceController()

    /// An in-memory store for SwiftUI previews and testing.
    @MainActor
    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        // Seed sample data for previews
        let now = Date()
        for i in 0..<30 {
            let metric = Metric(
                context: context,
                type: .price,
                timestamp: Calendar.current.date(byAdding: .day, value: -i, to: now)!,
                value: Double.random(in: 80_000...105_000)
            )
            _ = metric
        }

        for i in 0..<10 {
            let candle = PriceCandle(
                context: context,
                timestamp: Calendar.current.date(byAdding: .day, value: -i, to: now)!,
                open: Double.random(in: 90_000...95_000),
                high: Double.random(in: 95_000...105_000),
                low: Double.random(in: 85_000...90_000),
                close: Double.random(in: 90_000...100_000),
                volume: Double.random(in: 10_000...50_000)
            )
            _ = candle
        }

        do {
            try context.save()
        } catch {
            fatalError("PersistenceController preview save error: \(error)")
        }

        return controller
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "BitcoinStats")

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { _, error in
            if let error {
                // In production, handle this more gracefully (e.g., migrate or reset the store).
                fatalError("Failed to load Core Data store: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
