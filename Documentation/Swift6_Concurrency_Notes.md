# Swift 6.2 Concurrency & API Layer — Session Notes

**Date:** February 16, 2026
**Xcode:** 26.2 beta · **Swift:** 6.2 · **Target:** iOS 26.2

---

## Project Build Settings That Drive Everything

Two build settings shape the entire concurrency story in this project:

```
SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor
SWIFT_APPROACHABLE_CONCURRENCY = YES
```

**`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`** (new in Swift 6.2, SE-0466) means every type — struct, class, enum, protocol — is implicitly `@MainActor` unless explicitly opted out. This is a project-wide setting, not per-file. It's great for UI code (views, view models) because you never have to think about isolation. But it creates friction for types that shouldn't be on the main actor: network services, response models, test helpers.

**`SWIFT_APPROACHABLE_CONCURRENCY = YES`** downgrades strict concurrency violations from errors to warnings. This is why we see warnings rather than build failures. It's a transitional setting — eventually you'd turn it off and enforce strict concurrency.

---

## The Core Problem: Everything Defaults to MainActor

With default MainActor isolation, the compiler treats *every* type as if it were annotated `@MainActor`. That includes:

- Service classes (`APIService`, `SupplementaryAPIService`)
- Codable response structs (`PriceResponse`, `MempoolStatsResponse`, etc.)
- Error enums (`APIError`)
- Test helper classes (`MockHTTPClient`)
- Static data enums (`CannedJSON`, `CannedSupplementaryJSON`)

This means:

1. **Synthesized `init`s are MainActor-isolated.** A `Codable` struct's compiler-generated `init(from:)` is MainActor-isolated, so calling `JSONDecoder().decode(PriceResponse.self, from: data)` from a nonisolated context warns — the decoder invokes a MainActor-isolated initializer from a non-MainActor context.

2. **Stored properties are MainActor-isolated.** Even if a method is marked `nonisolated`, accessing `self.client` or `self.baseURL` inside it warns because the properties themselves live on the main actor.

3. **Enum cases and static properties are MainActor-isolated.** Throwing `APIError.httpError(statusCode: 429)` from a nonisolated function warns. Accessing `CannedJSON.currentPrice` in a test warns.

---

## The Solution: Type-Level `nonisolated`

Swift 6.2 (SE-0466) allows `nonisolated` as a type-level modifier. This opts the *entire* type out of default actor isolation — its init, stored properties, methods, and nested types all become nonisolated in one stroke.

### Before (per-member approach — insufficient):

```swift
final class APIService: Sendable {
    nonisolated let client: HTTPClient       // one by one
    nonisolated let baseURL: URL             // tedious
    nonisolated init(...) { ... }            // easy to miss
    nonisolated func fetchPrice() { ... }    // every method
}
```

This is fragile. Miss one member and you get a warning. And it doesn't help with synthesized Codable inits on response structs — there's no way to annotate those per-member.

### After (type-level — comprehensive):

```swift
nonisolated final class APIService: Sendable {
    private let client: HTTPClient
    private let baseURL: URL
    init(...) { ... }
    func fetchPrice() { ... }
}
```

One keyword, entire type opted out. Clean and impossible to miss a member.

### The Pattern for Each Kind of Type

**Service classes** — network code that must not be on the main actor:
```swift
nonisolated final class APIService: Sendable { ... }
nonisolated final class SupplementaryAPIService: Sendable { ... }
```

**Codable response structs** — value types decoded on background threads:
```swift
nonisolated struct PriceResponse: Codable, Sendable { ... }
nonisolated struct MempoolStatsResponse: Codable, Sendable { ... }
nonisolated struct CoinGeckoMarketResponse: Codable, Sendable { ... }
```

**Error enums** — thrown from nonisolated code:
```swift
nonisolated enum APIError: Error, LocalizedError { ... }
```

**Test mock classes** — used from nonisolated test functions:
```swift
nonisolated final class MockHTTPClient: HTTPClient, @unchecked Sendable { ... }
```

**Canned test data enums** — static properties accessed from nonisolated tests:
```swift
nonisolated enum CannedJSON { ... }
nonisolated enum CannedSupplementaryJSON { ... }
```

### Protocol Methods

The `HTTPClient` protocol method is marked `nonisolated` explicitly so that URLSession's existing `data(for:)` method satisfies the requirement without conflict:

```swift
protocol HTTPClient: Sendable {
    nonisolated func data(for request: URLRequest) async throws -> (Data, URLResponse)
}
extension URLSession: HTTPClient {}
```

### Test Suites That Use CoreData

`DataServiceTests` accesses CoreData's `viewContext`, which is main-queue-bound. This test suite *should* be on the main actor:

```swift
@Suite(.serialized)
@MainActor
struct DataServiceTests { ... }
```

---

## What Doesn't Need `nonisolated`

Types that belong on the main actor should be left alone (they inherit the default):

- **SwiftUI Views** — always main actor
- **ViewModels** (`@Observable` classes) — drive UI, should be main actor
- **CoreData-facing code** (`DataService`, `PersistenceController`) — uses `viewContext` which is main-queue
- **`UserPreferences`** — UI state backed by UserDefaults

The rule of thumb: if it touches UI or CoreData's `viewContext`, leave it as default MainActor. If it does network I/O, background computation, or is a pure data container for decoding, mark it `nonisolated`.

---

## Mistakes Made Along the Way

### Attempt 1: `nonisolated(unsafe)` on mock properties
Added `nonisolated(unsafe)` to `MockHTTPClient.responseData` and `.statusCode`. This is a sledgehammer — it tells the compiler "trust me, this is fine" without actually proving safety. It also didn't fix the root cause (the mock's `init()` was still MainActor-isolated), and *increased* warning count from 70 to 79 because test code now needed `await MockHTTPClient()` everywhere.

**Lesson:** `nonisolated(unsafe)` is a last resort for interop with legacy code. Don't reach for it first.

### Attempt 2: Per-member `nonisolated` on methods + init
Made service methods and inits nonisolated, added `Sendable`. Reduced warnings to 51 but stored properties were still MainActor-isolated, producing warnings when accessed from nonisolated methods.

**Lesson:** In a default-MainActor project, everything on a type needs to be opted out, not just methods.

### Attempt 3: Per-member `nonisolated` on stored properties too
Added `private nonisolated let` to stored properties. Still 51 warnings — the *response structs* and *error enum* were still MainActor-isolated. `JSONDecoder.decode(PriceResponse.self)` calls PriceResponse's synthesized `init(from:)` which is MainActor.

**Lesson:** You can't annotate synthesized inits. The type itself must be `nonisolated`.

### Attempt 4: Type-level `nonisolated` on everything
Applied `nonisolated` at the type level to all service classes, response structs, error enums, mock classes, and canned data enums. This is the correct, comprehensive fix.

**Key insight:** When using `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, you need to think in terms of *which types* belong on the main actor and which don't. It's a type-level decision, not a member-level one.

---

## API Layer Summary

### What Was Built

Six mempool.space endpoints in `APIService`:

| Method | Endpoint | Returns |
|---|---|---|
| `fetchCurrentPrice()` | `GET /api/v1/prices` | `PriceResponse` |
| `fetchHistoricalPrices(currency:timestamp:)` | `GET /api/v1/historical-price` | `HistoricalPriceResponse` |
| `fetchMempoolStats()` | `GET /api/mempool` | `MempoolStatsResponse` |
| `fetchRecommendedFees()` | `GET /api/v1/fees/recommended` | `RecommendedFeesResponse` |
| `fetchHashrateAndDifficulty(timePeriod:)` | `GET /api/v1/mining/hashrate/:period` | `HashrateResponse` |
| `fetchDifficultyAdjustments(count:)` | `GET /api/v1/mining/difficulty-adjustments/:count` | `[[Double]]` |

Four supplementary endpoints in `SupplementaryAPIService`:

| Method | Source | Endpoint |
|---|---|---|
| `fetchMarketData()` | CoinGecko | `GET /api/v3/simple/price` |
| `fetchMarketChart(days:)` | CoinGecko | `GET /api/v3/coins/bitcoin/market_chart` |
| `fetchChartData(chartName:timespan:)` | blockchain.com | `GET /charts/:chartName` |
| `fetchStat(name:)` | blockchain.com | `GET /q/:statName` |

### Testing Pattern

All tests use `MockHTTPClient` (injected via `HTTPClient` protocol) with canned JSON responses. Each endpoint has at minimum:

1. **Decode test** — verifies response parsing against known JSON
2. **Endpoint test** — verifies the correct URL path and query parameters
3. **HTTP error test** — verifies that non-2xx responses throw `APIError`

Test suites use `@Suite(.serialized)` to avoid shared-mock data races.

### File Map

```
BitcoinStats/
  Services/
    HTTPClient.swift           — Protocol + URLSession conformance
    APIService.swift           — mempool.space (6 endpoints + response types)
    SupplementaryAPIService.swift — CoinGecko + blockchain.com (4 endpoints + response types)
    DataService.swift          — CoreData persistence layer
  Models/Utilities/
    APIResponseTypes.swift     — Lightweight structs for CoreData ingestion

BitcoinStatsTests/
    MockHTTPClient.swift       — Mock + CannedJSON for mempool.space
    APIServiceTests.swift      — 21 tests covering all 6 mempool.space endpoints
    SupplementaryAPIServiceTests.swift — 14 tests covering supplementary APIs
    DataServiceTests.swift     — CoreData persistence tests
```

---

## Still To Do

- Confirm the type-level `nonisolated` fix resolves all remaining warnings (user has not yet rebuilt)
- If warnings persist, need actual Xcode warning text to diagnose — the fix should be comprehensive but edge cases may remain
- CoinMetrics API integration (MVRV, NUPL, HODL waves — more complex response shapes)
- Wire services into `DataService` for CoreData persistence
- ViewModel layer to connect data to views
