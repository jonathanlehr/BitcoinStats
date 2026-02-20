//
//  HTTPClient.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import Foundation

/// Protocol abstracting URL data fetching, enabling mock injection for tests.
/// Methods are explicitly `nonisolated` so conformances (URLSession, MockHTTPClient)
/// don't conflict with the project's default MainActor isolation.
protocol HTTPClient: Sendable {
    nonisolated func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

// MARK: - URLSession Conformance

extension URLSession: HTTPClient {}
