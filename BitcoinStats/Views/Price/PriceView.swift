//
//  PriceView.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import SwiftUI

struct PriceView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Price Chart",
                systemImage: "bitcoinsign.circle",
                description: Text("Real-time price and overlays — coming soon.")
            )
            .navigationTitle("Price")
        }
    }
}

#Preview {
    PriceView()
}
