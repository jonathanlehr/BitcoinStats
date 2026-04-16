//
//  ChatBubble.swift
//  BitcoinStats
//
//  Single message bubble for the Analyst chat transcript.
//

import SwiftUI

struct ChatBubble: View {

    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                bubbleText
            }

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var bubbleText: some View {
        Text(displayedText)
            .font(.callout)
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .fixedSize(horizontal: false, vertical: true)
    }

    /// When we're waiting on the first chunk of an assistant reply, show a placeholder
    /// ellipsis instead of an empty bubble so the spinner-effect reads clearly.
    private var displayedText: String {
        if message.role == .assistant && message.text.isEmpty && message.isStreaming {
            return "…"
        }
        return message.text
    }

    private var foreground: Color {
        switch message.role {
        case .user:      .white
        case .assistant: .primary
        }
    }

    private var background: some ShapeStyle {
        switch message.role {
        case .user:      AnyShapeStyle(Color.accentColor)
        case .assistant: AnyShapeStyle(Color.secondary.opacity(0.15))
        }
    }
}
