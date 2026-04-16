//
//  AIView.swift
//  BitcoinStats
//
//  Parent view for the AI tab. Hosts two side-by-side examples of Apple Intelligence
//  integration so students in the training course can compare them:
//
//    Ask      — guided generation (LLM → typed struct → app renders result).
//    Analyst  — tool calling (LLM drives a loop of tool calls + streaming prose).
//
//  (A third pattern — plain prompt → plain text — lives on the Price tab as the
//   existing Market Summary sheet.)
//

import SwiftUI

@available(iOS 26.0, *)
struct AIView: View {

    enum Mode: String, CaseIterable, Identifiable {
        case ask     = "Ask"
        case analyst = "Analyst"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .ask

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                modePicker
                Divider()
                content
            }
            .navigationTitle(mode.rawValue)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            ForEach(Mode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .ask:     AskView()
        case .analyst: AnalystView()
        }
    }
}

#Preview {
    if #available(iOS 26.0, *) {
        AIView()
    }
}
