//
//  AppColorScheme.swift
//  BitcoinStats
//

import SwiftUI

/// The user's preferred color scheme for the app UI.
enum AppColorScheme: String, CaseIterable {
    case system = "Auto"
    case light  = "Light"
    case dark   = "Dark"

    /// Maps to the SwiftUI `ColorScheme` type. Returns `nil` for `.system`
    /// so that `View.preferredColorScheme(nil)` defers to the OS setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }
}
