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
            // Gated behind iOS 26 because the AI tab's contents rely on FoundationModels
            // features (guided generation with @Generable, tool calling) that are only
            // available there. The Market Summary sheet on the Price tab continues to
            // work on iOS 18.1+ as a plain-prompt baseline example.
            if #available(iOS 26.0, *) {
                Tab("AI", systemImage: "sparkles") {
                    AIView()
                }
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
