# Bitcoin Analytics - Architecture Overview

## Project Vision
A native iOS application for Bitcoin on-chain analytics with beautiful, customizable charts and real-time data. Mac version to follow after iOS is proven and polished.

## Platform Strategy
**Phase 1:** iOS app (iPhone primary, iPad secondary)
**Phase 2:** Mac app (after iOS core is solid)

**Rationale for iOS First:**
- Developer's primary expertise (12 years iOS vs occasional Mac)
- Larger potential user base
- Faster market validation
- iOS → Mac port is easier than reverse
- Lock Screen widgets and StandBy mode are compelling features

## Core Architectural Decisions

### Data Layer
- **CoreData** for all persistent storage of historical metric data
- **UserDefaults** for user preferences (overlays, selected metrics, time ranges)
- **No abstraction layer** - ViewModels work directly with NSManagedObject subclasses
  - Rationale: Simpler, more performant, appropriate for a native Mac app
  - Trade-off: Tighter coupling to CoreData, but acceptable for this use case

### Data Model
Two primary CoreData entities:

1. **Metric** (NSManagedObject)
   - Stores all metric data points (price, MVRV, hash rate, etc.)
   - Uses a single entity with `metricTypeRaw` discriminator
   - Complex data (like HODL waves) stored as JSON in `metadataJSON` field

2. **PriceCandle** (NSManagedObject)
   - Stores OHLCV (Open, High, Low, Close, Volume) data
   - Enables candlestick chart visualization

### Service Layer Architecture
```
┌─────────────┐
│  SwiftUI    │
│   Views     │  (Tab-based navigation)
│  Tabs:      │
│  - Price    │
│  - Metrics  │
│  - AI       │  (iOS 26+ only: Ask | Analyst)
│  - Settings │
└──────┬──────┘
       │
┌──────▼──────────┐
│   ViewModels    │  @Published var priceData: [Metric]
└──────┬──────────┘
       │
┌──────▼──────────┐
│  DataManager    │  Coordinates fetching & caching
└──────┬──────────┘
       │
   ┌───┴────┐
   │        │
┌──▼───┐ ┌─▼────────────┐
│ APIs │ │ Persistence  │
└──────┘ └──────────────┘
```

### API Integration Strategy
- **Primary Source**: mempool.space (free, comprehensive)
- **Supplementary**: CoinGecko for historical price data
- All API responses parsed into simple structs (Codable)
- Immediately saved to CoreData as managed objects
- ViewModels receive managed objects, never raw API responses

### Caching & Update Strategy
- **Real-time metrics** (mempool, current price): 30-second polling or WebSocket
- **Daily metrics** (MVRV, HODL waves): Fetch once per day
- **Historical data**: 
  - Detailed hourly data for last 2 years
  - Weekly aggregates for data older than 2 years
  - Fetched once, appended to incrementally

### Unit Formatting
- **Custom Dimension**: `UnitHashRate` for hash rate conversions
- **Built-in**: Currency formatters for price
- **Manual**: Simple string formatting for ratios (MVRV, Mayer Multiple, NUPL)

## Technology Stack
- **UI**: SwiftUI with Swift Charts
- **Persistence**: CoreData
- **Networking**: URLSession with async/await
- **Minimum Target**: iOS 17.0+ (for Swift Charts maturity and Lock Screen widgets)
- **Device Support**: iPhone (primary), iPad (optimized layouts)

## Key Design Patterns
- **MVVM**: ViewModels mediate between Views and Services
- **Protocol-based APIs**: `MetricDataSource` protocol allows multiple implementations
- **Reactive**: Combine publishers for real-time updates
- **Value types where possible**: Enums, structs for domain concepts

## Apple Intelligence Integration

The app demonstrates three distinct FoundationModels patterns — kept deliberately
separate so this codebase doubles as teaching material for integrating Apple
Intelligence into native iOS apps.

| Feature                | Pattern                        | Control flow          | Output           | File(s) |
|------------------------|--------------------------------|-----------------------|------------------|---------|
| Market Summary (Price tab) | Plain prompt → free-form text | App → model → app       | Prose            | `MarketSummaryViewModel.swift`, `MarketSummaryView.swift` |
| Ask (AI tab)               | Guided generation            | App → model → app (typed) → app | Rendered UI card | `QueryIntent.swift`, `AskViewModel.swift`, `AskView.swift`, `QueryResultCard.swift` |
| Analyst (AI tab)           | Tool calling + streaming     | Model drives a loop of tool calls | Streamed prose   | `BitcoinAnalystTools.swift`, `AnalystViewModel.swift`, `AnalystView.swift`, `ChatBubble.swift` |

### Pattern 1 — Plain prompt (Market Summary)
The simplest integration. The app assembles a prompt from live Bitcoin metrics,
calls `LanguageModelSession.respond(to:)`, and displays the returned text.
Good baseline; no structure beyond the prompt itself. (iOS 18.1+)

### Pattern 2 — Guided generation (Ask)
The model is used as a *parser*, not a writer. The user's question is coerced
into a `QueryIntent` struct whose fields are all `@Generable` enums (metric,
time range, display style). Once the struct is produced, the app executes the
query deterministically against CoreData and renders a UI card — no model
output reaches the view. (iOS 26+)

Use this pattern when the LLM's job is to *classify* a request and the UI
response is structured, not prose.

### Pattern 3 — Tool calling (Analyst)
The model drives a multi-turn loop. It receives the user's question plus a
catalog of `Tool`-conforming types that wrap `APIService`, `DataService`, and
`CalculationService`. The model decides which tools to call, reads their
structured outputs, chains further calls if needed, and finally streams a
prose answer via `LanguageModelSession.streamResponse(to:)`. Tool progress is
surfaced to the UI via a Sendable emitter closure so "Fetching current price…"
tickers appear while tools run. (iOS 26+)

Use this pattern when the question is open-ended and the app can expose its
services as discrete capabilities the model can combine on its own.

## What We Explicitly Decided NOT to Do (for iOS V1)
- ❌ Abstraction layer between CoreData and ViewModels (unnecessary complexity)
- ❌ Protocol conformance for managed objects (went with direct usage)
- ❌ Color customization for overlays (V2 feature)
- ❌ Advanced alerts (V2 - start with simple threshold alerts)
- ❌ Exchange reserves metric (data sourcing complexity)
- ❌ iPad-specific optimizations (phone-first, but use adaptive layouts)
- ❌ Apple Watch complications (V2 consideration)
- ❌ Mac app (Phase 2, after iOS is proven)

## Future Considerations (Post-iOS V1)
- Alert system with push notifications
- Advanced widgets (interactive, dynamic island)
- Export to CSV/PDF
- Correlation analysis between metrics
- Additional data sources (Glassnode, CryptoQuant)
- iPad multi-column layout
- Apple Watch app
- Mac app (Phase 2 main goal)
