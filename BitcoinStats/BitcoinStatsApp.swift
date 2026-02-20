//
//  BitcoinStatsApp.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import CoreData
import SwiftUI

@main
struct BitcoinStatsApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
