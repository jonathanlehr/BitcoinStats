//
//  ContentView.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import SwiftUI

struct ContentView: View {

    private var preferences = UserPreferences.shared

    var body: some View {
        TabView {
            Tab("Price", systemImage: "bitcoinsign.circle") {
                PriceView()
            }
            Tab("Metrics", systemImage: "chart.xyaxis.line") {
                MetricsView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .preferredColorScheme(preferences.colorScheme.colorScheme)
    }
}

#Preview {
    ContentView()
}
