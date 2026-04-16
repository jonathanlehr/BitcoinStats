//
//  AnalystView.swift
//  BitcoinStats
//
//  Chat UI for the tool-calling Analyst feature.
//
//  The view is deliberately thin: a scrolling transcript of ChatBubbles, a tool-activity
//  ticker, and a composer at the bottom. All of the interesting behavior — session
//  management, tool plumbing, streaming — lives in AnalystViewModel.
//

import SwiftUI

@available(iOS 26.0, *)
struct AnalystView: View {

    @State private var viewModel = AnalystViewModel()
    @State private var composerText: String = ""
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            transcript
            Divider()
            activityTicker
            composer
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.newConversation()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .disabled(viewModel.messages.isEmpty || viewModel.isResponding)
            }
        }
        .overlay {
            if viewModel.messages.isEmpty {
                emptyState
            }
        }
    }

    // MARK: - Transcript

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }
                    if let error = viewModel.error {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
            // Observe message count, not the streaming text, so we only scroll
            // when a new bubble appears — not on every token. Per-token scroll
            // animations pile up on @MainActor and cause the UI to feel frozen.
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Tool activity

    @ViewBuilder
    private var activityTicker: some View {
        if let activity = viewModel.activeToolActivity {
            HStack(spacing: 8) {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundStyle(.purple)
                Text(activity)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                ProgressView().controlSize(.mini)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08))
            .transition(.opacity)
        }
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("Ask the analyst…", text: $composerText, axis: .vertical)
                .lineLimit(1...4)
                .focused($isComposerFocused)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit(submit)

            Button {
                submit()
            } label: {
                Image(systemName: viewModel.isResponding ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(!canSubmit)
        }
        .padding()
    }

    private var canSubmit: Bool {
        !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.isResponding
            && viewModel.isModelAvailable
    }

    private func submit() {
        guard canSubmit else { return }
        let question = composerText
        composerText = ""
        isComposerFocused = false
        Task { await viewModel.send(question: question) }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(.purple)
            Text("Ask the Analyst")
                .font(.title2.weight(.semibold))
            Text("A multi-turn chat backed by on-device tool calling. The analyst can fetch live prices, read cached history, and compute indicators as it answers.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            sampleQuestions
            if !viewModel.isModelAvailable {
                Text("Apple Intelligence isn't available on this device. Enable it in Settings > Apple Intelligence & Siri.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    private var sampleQuestions: some View {
        VStack(spacing: 6) {
            ForEach(Self.sampleQuestions, id: \.self) { sample in
                Button {
                    composerText = sample
                    submit()
                } label: {
                    Text(sample)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.secondary.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private static let sampleQuestions: [String] = [
        "How does today's hash rate compare to a year ago?",
        "Is the Mayer Multiple high right now?",
        "Should I wait to send a transaction?"
    ]
}

#Preview {
    if #available(iOS 26.0, *) {
        NavigationStack { AnalystView() }
    }
}
