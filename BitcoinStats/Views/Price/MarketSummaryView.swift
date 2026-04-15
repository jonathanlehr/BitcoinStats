//
//  MarketSummaryView.swift
//  BitcoinStats
//
//  A sheet that generates a natural-language Bitcoin market summary using
//  Apple Intelligence (FoundationModels, iOS 18.1+).
//

import SwiftUI

@available(iOS 18.1, *)
struct MarketSummaryView: View {

    @State private var viewModel = MarketSummaryViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    appleIntelligenceBadge
                    Divider()
                    summaryContent
                    Spacer(minLength: 16)
                    generateButton
                    if !viewModel.isModelAvailable {
                        unavailableNote
                    }
                }
                .padding()
            }
            .navigationTitle("Market Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Subviews

    private var appleIntelligenceBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .foregroundStyle(.purple)
            Text("Apple Intelligence")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var summaryContent: some View {
        if viewModel.isGenerating {
            HStack(spacing: 12) {
                ProgressView()
                Text("Generating summary…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let error = viewModel.error {
            Label(error, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        } else if viewModel.summary.isEmpty {
            Text("Tap **Generate Summary** to create a real-time market summary using live Bitcoin data and Apple Intelligence.")
                .foregroundStyle(.secondary)
        } else {
            Text(viewModel.summary)
                .lineSpacing(4)
        }
    }

    private var generateButton: some View {
        Button {
            Task { await viewModel.generate() }
        } label: {
            Label(
                viewModel.summary.isEmpty ? "Generate Summary" : "Regenerate",
                systemImage: "sparkles"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isGenerating || !viewModel.isModelAvailable)
    }

    private var unavailableNote: some View {
        Text("Apple Intelligence is not available on this device or has not been set up. Go to Settings > Apple Intelligence & Siri to enable it.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    if #available(iOS 18.1, *) {
        MarketSummaryView()
    }
}
