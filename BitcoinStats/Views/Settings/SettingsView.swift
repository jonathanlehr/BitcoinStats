//
//  SettingsView.swift
//  BitcoinStats
//

import SwiftUI

struct SettingsView: View {

    @Bindable private var preferences = UserPreferences.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Color Scheme", selection: $preferences.colorScheme) {
                        ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                            Text(scheme.rawValue).tag(scheme)
                        }
                    }
                    Picker("Price Scale", selection: $preferences.priceScale) {
                        ForEach(PriceScale.allCases, id: \.self) { scale in
                            Text(scale.rawValue).tag(scale)
                        }
                    }
                }
                Section("Data") {
                    Picker("Refresh Interval", selection: $preferences.refreshInterval) {
                        ForEach(RefreshInterval.allCases, id: \.self) { interval in
                            Text(interval.rawValue).tag(interval)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
