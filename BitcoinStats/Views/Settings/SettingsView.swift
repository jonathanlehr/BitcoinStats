//
//  SettingsView.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Settings",
                systemImage: "gearshape",
                description: Text("Appearance, refresh interval, and data sources — coming soon.")
            )
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
