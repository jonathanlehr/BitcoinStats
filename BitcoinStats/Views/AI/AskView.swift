//
//  AskView.swift
//  BitcoinStats
//
//  UI for the guided-generation Ask feature.
//  User types a question → the model parses it into a typed QueryIntent →
//  the app renders an inline result card from cached data.
//
//  This view is intentionally small. The interesting code lives in:
//    • QueryIntent.swift   — the @Generable schema the model must satisfy.
//    • AskViewModel.swift  — the parse-then-execute flow.
//    • QueryResultCard.swift — the deterministic renderer.
//

import SwiftUI

@available(iOS 26.0, *)
struct AskView: View {

    @State private var viewModel = AskViewModel()
    @State private var question: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                inputField
                suggestionChips
                resultArea
                if !viewModel.isModelAvailable {
                    unavailableNote
                }
            }
            .padding()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Ask", systemImage: "sparkles")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Type a question about Bitcoin data. The on-device model turns it into a structured query — the app fetches the data and renders the answer.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Input

    private var inputField: some View {
        HStack(spacing: 8) {
            TextField("e.g. What's Bitcoin's price right now?", text: $question, axis: .vertical)
                .lineLimit(1...3)
                .focused($isInputFocused)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit(submit)
            Button {
                submit()
            } label: {
                if viewModel.isWorking {
                    ProgressView()
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
            }
            .disabled(!canSubmit)
        }
    }

    private var canSubmit: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.isWorking
            && viewModel.isModelAvailable
    }

    private func submit() {
        guard canSubmit else { return }
        isInputFocused = false
        Task { await viewModel.submit(question: question) }
    }

    // MARK: - Suggestions

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.suggestions, id: \.self) { suggestion in
                    Button {
                        question = suggestion
                        submit()
                    } label: {
                        Text(suggestion)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.secondary.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private static let suggestions: [String] = [
        "What's BTC price right now?",
        "Show MVRV over the last year",
        "How much has hash rate changed in 6 months?",
        "Mayer Multiple history for 2 years"
    ]

    // MARK: - Result

    @ViewBuilder
    private var resultArea: some View {
        if viewModel.isWorking {
            HStack(spacing: 10) {
                ProgressView()
                Text("Parsing your question…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        } else if let error = viewModel.error {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.red)
        } else if let result = viewModel.result {
            QueryResultCard(result: result)
        } else {
            Text("Your answer will appear here.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
    }

    // MARK: - Unavailable

    private var unavailableNote: some View {
        Text("Apple Intelligence is not available on this device or hasn't been set up. Go to Settings > Apple Intelligence & Siri to enable it.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    if #available(iOS 26.0, *) {
        AskView()
    }
}
