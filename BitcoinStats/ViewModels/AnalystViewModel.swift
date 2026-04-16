//
//  AnalystViewModel.swift
//  BitcoinStats
//
//  Pattern: Tool calling (agent loop) with streaming.
//
//  The LLM drives the loop. It receives the user's question plus a catalog of tools
//  (see BitcoinAnalystTools.swift), decides which tools to call, reads the results,
//  possibly calls more tools, and then produces a streamed prose answer.
//
//  Two capabilities this pattern demonstrates that guided generation cannot:
//   1. Multi-turn conversation — the same session carries history forward.
//   2. Dynamic data access — the model fetches what it needs instead of the app
//      pre-deciding which metrics to include in a prompt.
//
//  This is the last stop on the training-course progression:
//
//    MarketSummaryViewModel  — plain prompt → free-form text
//    AskViewModel            — guided generation → typed struct
//    AnalystViewModel        — tool calling → streaming agent loop   ← THIS
//

import Foundation
import FoundationModels
import OSLog
import SwiftUI

@available(iOS 26.0, *)
@MainActor
@Observable
final class AnalystViewModel {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BitcoinStats",
        category: "AnalystViewModel"
    )

    // MARK: - Published State

    private(set) var messages: [ChatMessage] = []

    /// Short status like "Fetching current price…" set by whichever tool is running.
    /// The UI shows this as a ticker below the transcript while it is non-nil.
    private(set) var activeToolActivity: String?

    /// Delays clearing activeToolActivity so the ticker stays visible long enough to read.
    private var activityClearTask: Task<Void, Never>?

    private(set) var isResponding = false
    private(set) var error: String?

    /// True when Apple Intelligence is ready to use on this device.
    var isModelAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    // MARK: - Dependencies

    private let api: APIService
    private let dataService: DataService

    /// The session is created lazily on first send so its transcript — and therefore
    /// multi-turn context — persists across messages without leaking across app launches.
    private var session: LanguageModelSession?

    // MARK: - Init

    init(api: APIService = APIService(), dataService: DataService? = nil) {
        self.api = api
        self.dataService = dataService ?? DataService()
    }

    // MARK: - Send

    /// Appends the user message to the transcript and streams the assistant's reply.
    /// Tools are invoked automatically by `LanguageModelSession` as the model decides it
    /// needs them; each tool reports activity through `activeToolActivity`.
    func send(question: String) async {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard isModelAvailable else {
            error = "Apple Intelligence is not available on this device. Enable it in Settings > Apple Intelligence & Siri."
            return
        }

        error = nil

        // Append the user message and an empty assistant message that we'll stream into.
        messages.append(ChatMessage(role: .user, text: trimmed, isStreaming: false))
        messages.append(ChatMessage(role: .assistant, text: "", isStreaming: true))
        let assistantIndex = messages.count - 1

        isResponding = true
        defer {
            isResponding = false
            activeToolActivity = nil
            if messages.indices.contains(assistantIndex) {
                messages[assistantIndex].isStreaming = false
            }
        }

        // Build a session on first use. The same session is reused for subsequent
        // messages so the model has access to prior Q&A as context.
        let session = await ensureSession()

        do {
            // Bridge FoundationModels streaming to this @MainActor task via
            // AsyncThrowingStream. A detached task owns the ResponseStream iterator
            // (off the main actor), yielding tokens into the stream. This task
            // consumes them with `for try await`, which is a genuine suspension at
            // each token — so @MainActor is released between deliveries and stays
            // free for touch events during tool calls and inference.
            //
            // The alternative (Task.detached + MainActor.run per token) races
            // MainActor.run enqueues against touch events and can starve the run loop.
            let (tokenStream, continuation) = AsyncThrowingStream<String, Error>.makeStream()

            Task.detached { [session, trimmed] in
                do {
                    let responseStream = session.streamResponse(to: Prompt(trimmed))
                    for try await partial in responseStream {
                        let text = partial.content
                        // Skip the spurious "null" partial emitted during tool calling
                        // before any prose is available.
                        guard !text.isEmpty, text != "null" else { continue }
                        continuation.yield(text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            for try await text in tokenStream {
                if messages.indices.contains(assistantIndex) {
                    messages[assistantIndex].text = text
                }
            }
        } catch {
            Self.logger.error("Analyst stream failed: \(error, privacy: .public)")
            self.error = "The analyst couldn't finish that answer: \(error.localizedDescription)"
            if messages.indices.contains(assistantIndex),
               messages[assistantIndex].text.isEmpty {
                messages.removeLast()
            }
        }
    }

    /// Wipes the conversation and drops the current session so the next message starts fresh.
    func newConversation() {
        messages.removeAll()
        error = nil
        session = nil
    }

    // MARK: - Session Setup

    private func ensureSession() async -> LanguageModelSession {
        if let existing = session { return existing }

        // Tools share a single activity emitter that hops to MainActor and updates
        // our @Observable property. The closure is @Sendable so tools — which are
        // value types called off the main actor — can invoke it freely.
        let emit: ToolActivityEmitter = { [weak self] message in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Cancel any pending clear so a rapid new message replaces it instantly.
                self.activityClearTask?.cancel()
                if let message {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.activeToolActivity = message
                    }
                } else {
                    // Hold the current message for 1.5 s so it's readable, then fade out.
                    self.activityClearTask = Task { [weak self] in
                        try? await Task.sleep(for: .seconds(1.5))
                        guard !Task.isCancelled else { return }
                        await MainActor.run { [weak self] in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                self?.activeToolActivity = nil
                            }
                        }
                    }
                }
            }
        }

        let tools: [any Tool] = [
            GetCurrentPriceTool(api: api, emit: emit),
            GetMetricHistoryTool(dataService: dataService, emit: emit),
            ComputeIndicatorTool(dataService: dataService, emit: emit),
            GetMempoolSnapshotTool(api: api, emit: emit)
        ]

        // LanguageModelSession initialisation loads the model and compiles tool
        // schemas — it is synchronous and can take several seconds. Running it in
        // a detached task keeps the main actor free so the UI stays responsive
        // while the session warms up.
        let newSession = await Task.detached {
            LanguageModelSession(
                tools: tools,
                instructions: Self.systemInstructions
            )
        }.value
        session = newSession
        return newSession
    }

    // MARK: - Prompt

    nonisolated private static let systemInstructions = """
        You are a concise Bitcoin analyst inside a native iOS app. Answer the user's
        questions using the tools provided — prefer calling a tool over guessing a number.

        Guidelines:
         • When a question is about "right now", call getCurrentPrice or getMempoolSnapshot.
         • For trends or comparisons over time, call getMetricHistory with an appropriate range.
         • For valuation context, call computeIndicator with mayerMultiple or percentChange.
         • Ground every number in the tool output. Never invent values.
         • Keep answers to 3–5 sentences.
         • Never give price predictions or investment advice; stick to describing what the data shows.
        """
}
