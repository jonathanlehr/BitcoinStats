//
//  ContentView.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import SwiftUI

struct ContentView: View {
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
    }
}

#Preview {
    ContentView()
}
