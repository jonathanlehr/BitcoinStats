//
//  PriceViewModelTests.swift
//  BitcoinStatsTests
//

import Foundation
import Testing
@testable import BitcoinStats

/// Tests for PriceViewModel load() logic, focusing on:
///   - long-range (>90 day) error surfacing when the full history fetch fails
///   - short-range (<= 90 day) chart resilience when only the full history fetch fails
///
/// All tests are MainActor-isolated because PriceViewModel inherits the project's default
/// MainActor isolation, and DataService's viewContext is main-queue bound.
@Suite(.serialized)
@MainActor
struct PriceViewModelTests {

    // MARK: - Helpers

    private func makeViewModel(
        mempoolStatusCode: Int = 200,
        coinGeckoResponses: [(data: Data, statusCode: Int)],
        coinGeckoAPIKey: String? = nil
    ) -> PriceViewModel {
        let mempoolMock = MockHTTPClient()
        mempoolMock.responseData = CannedJSON.currentPrice
        mempoolMock.statusCode = mempoolStatusCode

        let coinGeckoMock = MockHTTPClient()
        if coinGeckoResponses.count == 1 {
            coinGeckoMock.responseData = coinGeckoResponses[0].data
            coinGeckoMock.statusCode = coinGeckoResponses[0].statusCode
        } else {
            coinGeckoMock.orderedResponses = coinGeckoResponses
        }

        return PriceViewModel(
            api: APIService(client: mempoolMock),
            supplementaryAPI: SupplementaryAPIService(
                client: coinGeckoMock,
                coinGeckoAPIKey: coinGeckoAPIKey
            ),
            dataService: DataService(
                persistenceController: PersistenceController(inMemory: true)
            )
        )
    }

    // MARK: - Long Range (> 90 days)

    /// Regression: before the fix, a 401 on days=max left the chart blank with no error message.
    @Test func longRangeErrorIsSetWhenFullHistoryReturns401() async {
        let originalRange = UserPreferences.shared.selectedTimeRange
        defer { UserPreferences.shared.selectedTimeRange = originalRange }
        UserPreferences.shared.selectedTimeRange = .sixMonths

        let vm = makeViewModel(
            coinGeckoResponses: [(data: Data(), statusCode: 401)]
        )

        await vm.load()

        #expect(vm.priceHistory.isEmpty)
        #expect(vm.error != nil)
    }

    @Test func longRangeErrorDescriptionMentionsStatusCode() async {
        let originalRange = UserPreferences.shared.selectedTimeRange
        defer { UserPreferences.shared.selectedTimeRange = originalRange }
        UserPreferences.shared.selectedTimeRange = .year

        let vm = makeViewModel(
            coinGeckoResponses: [(data: Data(), statusCode: 401)]
        )

        await vm.load()

        #expect(vm.error?.contains("401") == true)
    }

    @Test func longRangeNoErrorWhenHistorySucceeds() async {
        let originalRange = UserPreferences.shared.selectedTimeRange
        defer { UserPreferences.shared.selectedTimeRange = originalRange }
        UserPreferences.shared.selectedTimeRange = .sixMonths

        // Full history now fetches from blockchain.com (BlockchainChartResponse format).
        let vm = makeViewModel(
            coinGeckoResponses: [(data: CannedSupplementaryJSON.blockchainChartData, statusCode: 200)]
        )

        await vm.load()

        #expect(vm.error == nil)
    }

    // MARK: - Short Range (<= 90 days)

    /// The granular fetch (step 2) succeeds and populates priceHistory even when the
    /// full history fetch (step 3) fails — short-range charts should always show data
    /// after the granular cache warms up.
    @Test func shortRangeChartPopulatedWhenGranularSucceedsAndHistoryFails() async {
        let originalRange = UserPreferences.shared.selectedTimeRange
        defer { UserPreferences.shared.selectedTimeRange = originalRange }
        UserPreferences.shared.selectedTimeRange = .day

        let vm = makeViewModel(coinGeckoResponses: [
            (data: CannedSupplementaryJSON.coinGeckoMarketChart, statusCode: 200), // step 2: granular
            (data: Data(), statusCode: 401)                                         // step 3: history
        ])

        await vm.load()

        // Granular data from step 2 should be present despite step 3 failing.
        #expect(!vm.priceHistory.isEmpty)
    }

    @Test func shortRangeErrorNotSetWhenGranularSucceeds() async {
        let originalRange = UserPreferences.shared.selectedTimeRange
        defer { UserPreferences.shared.selectedTimeRange = originalRange }
        UserPreferences.shared.selectedTimeRange = .threeMonths

        let vm = makeViewModel(coinGeckoResponses: [
            (data: CannedSupplementaryJSON.coinGeckoMarketChart, statusCode: 200), // step 2: granular
            (data: Data(), statusCode: 401)                                         // step 3: history
        ])

        await vm.load()

        // A non-fatal step 3 failure must not override the step 2 success in the error state.
        #expect(vm.error == nil)
    }
}
