//
//  ChatMessage.swift
//  BitcoinStats
//
//  Simple value-type model for one message in the Analyst chat transcript.
//

import Foundation

struct ChatMessage: Identifiable, Equatable {

    enum Role: Equatable {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    var text: String
    /// True while this message's text is still being streamed in from the model.
    /// Used by the UI to show a pulsing caret on the trailing bubble.
    var isStreaming: Bool
}
