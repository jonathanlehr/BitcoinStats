# Bitcoin Analytics App - Project Handoff Transcript

## Project Overview
A native iOS application (iPhone primary, iPad secondary) for Bitcoin on-chain analytics featuring real-time data, customizable charts with overlays, and comprehensive metrics visualization. Mac version to follow in Phase 2.

## Context: How We Got Here
This project emerged from a conversation exploring Bitcoin app ideas. We settled on two concepts:
1. A Bitcoin "clock" desktop app (simpler, future project)
2. **On-chain analytics dashboard** (chosen for V1 - more complex but highly useful)

Initially considered as a Mac app, but pivoted to iOS-first because:
- Developer has 12 years of iOS experience vs occasional Mac experience
- Better positioned to architect and review iOS code
- Larger market for validation
- iOS → Mac port is easier than reverse
- Compelling iOS-specific features (Lock Screen widgets, StandBy mode)

The user is an experienced iOS developer and trainer who is new to working with AI assistance. This is their first agentic AI project using Claude.

---

## Key Architectural Decisions Made

### 1. Data Persistence Strategy
**Decision:** Use CoreData managed objects directly throughout the app.

**Rejected Alternative:** Protocol abstraction layer between managed objects and ViewModels.

**Rationale:** 
- Simpler architecture
- Better performance (no conversion overhead)
- Appropriate for native Mac app that won't be ported
- User is experienced with CoreData

**Implementation:**
- Two managed object classes: `Metric` and `PriceCandle`
- ViewModels work directly with NSManagedObject subclasses
- Only use simple structs for API response parsing before saving to CoreData

### 2. User Preferences Storage
**Decision:** UserDefaults for all preferences.

**Rejected Alternative:** CoreData for preferences.

**Rationale:**
- Preferences are simple key-value pairs
- No need for CoreData complexity
- UserDefaults is the standard for app settings

**What's stored:**
- Enabled price chart overlays (Set<PriceOverlay>)
- Selected metric (MetricType)
- Selected time range (TimeRange)
- Mini chart metrics ([MetricType])

### 3. Unit Handling
**Decision:** Hybrid approach.

**Implementation:**
- Custom `UnitHashRate` (extends Dimension) for hash rate
- Built-in Currency formatters for price
- Manual string formatting for ratios (MVRV, Mayer Multiple, NUPL)

**Rejected Alternative:** Using Dimension for all units (overkill for simple ratios).

### 4. Naming Conventions
**Decision:** Avoid "snapshot" terminology due to CoreData-specific meaning.

**Resolved naming:**
- Managed objects: `Metric` and `PriceCandle` (not "MetricEntity" or "MetricSnapshot")
- Correctly distinguish between CoreData entities (schema) and managed objects (instances)

---

## Core Features (V1 Scope)

### Metrics Included (10 total)

#### Valuation Metrics (5)
1. **Price & Market Cap** - Current price, 24h/7d changes
2. **MVRV Ratio** - Market Value to Realized Value (valuation indicator)
3. **Realized Price** - Aggregate cost basis of all BTC
4. **Mayer Multiple** - Price / 200-day MA (simple valuation metric)
5. **NUPL** - Net Unrealized Profit/Loss (sentiment indicator)

#### Network Metrics (3)
6. **Mempool Status** - Size, fee recommendations, pending tx count
7. **Hash Rate & Difficulty** - Network security indicators
8. **Active Addresses** - Network usage proxy

#### Holder Behavior (2)
9. **HODL Waves** - Supply distribution by age (stacked area chart)
10. **Long-Term Holder Supply** - % of supply unmoved 155+ days

### Price Chart Overlays
User-selectable overlays on the primary price chart:

**Moving Averages:**
- 200-week MA (most important long-term indicator)
- 200-day MA
- 50-day MA
- 20-week MA
- 21-week EMA

**Key Levels:**
- Realized Price
- **Bull Market Support Band** (area between 20w MA and 21w EMA)

**Default enabled:** 200-week MA + Bull Market Support Band

### UI/UX Design

**Tab Bar Navigation:**
Three tabs provide clear, focused experiences:

**Tab 1: Price**
```
┌─────────────────────────────┐
│ 💰 Price          $95,234   │
├─────────────────────────────┤
│                             │
│   [Price Chart]             │
│   (with overlays)           │
│                             │
├─────────────────────────────┤
│ Overlays:                   │
│ [✓ 200w MA] [Bull Band]    │
├─────────────────────────────┤
│ ⏱️ 1D 1W 1M 3M 1Y All      │
└─────────────────────────────┘
```

**Tab 2: Metrics**
```
┌─────────────────────────────┐
│ 📊 Metrics                  │
├─────────────────────────────┤
│ Valuation ▼                 │
│ ┌─────────┐ ┌─────────┐    │
│ │ MVRV    │ │ Mayer   │    │
│ │ 2.1     │ │ 1.2     │    │
│ │ ↘ -0.1  │ │ ↗ +0.1  │    │
│ └─────────┘ └─────────┘    │
│                             │
│ Network ▼                   │
│ ┌─────────┐ ┌─────────┐    │
│ │ Mempool │ │ Hash    │    │
│ └─────────┘ └─────────┘    │
└─────────────────────────────┘
```
- Grid of all metrics (2 per row)
- Tap any card → full detail view
- Pull to refresh

**Tab 3: Settings**
```
┌─────────────────────────────┐
│ ⚙️ Settings                 │
├─────────────────────────────┤
│ Appearance                  │
│  Color Theme      Auto   >  │
│                             │
│ Data & Sync                 │
│  Auto Refresh     ON        │
│  Refresh Interval 30s    >  │
│                             │
│ About                       │
│  Data Sources            >  │
└─────────────────────────────┘
```

**Interaction Patterns:**
- Pinch to zoom charts
- Long press for crosshair with values
- Tap overlay chips to toggle on/off
- Swipe down to refresh metrics
- Standard iOS navigation patterns

---

## Technology Stack

**UI Framework:** SwiftUI + Swift Charts
**Persistence:** CoreData
**Networking:** URLSession with async/await
**Minimum Target:** iOS 17.0+
**Device Support:** iPhone (primary), iPad (adaptive layouts)
**Widgets:** Lock Screen, Home Screen, StandBy mode

---

## Data Architecture

### CoreData Schema

**Entity: Metric**
```
Attributes:
- id: UUID (primary key)
- metricTypeRaw: String (stores MetricType.rawValue)
- timestamp: Date
- value: Double
- metadataJSON: String? (for complex data like HODL waves)

Indexes:
- Compound index on (metricTypeRaw, timestamp)
```

**Entity: PriceCandle**
```
Attributes:
- id: UUID (primary key)
- timestamp: Date
- open: Double
- high: Double
- low: Double
- close: Double
- volume: Double

Indexes:
- Index on timestamp
```

**Extensions:**
```swift
extension Metric {
    var metricType: MetricType {
        MetricType(rawValue: metricTypeRaw ?? "") ?? .price
    }
    
    var metadata: [String: Any]? {
        // Parse metadataJSON
    }
}
```

### Data Sources

**Primary:** mempool.space (free, comprehensive)
- Current price
- Mempool stats
- Hash rate, difficulty
- Block data

**Supplementary:**
- CoinGecko: Historical price (free tier)
- blockchain.com: Realized cap, active addresses (free)
- CoinMetrics: MVRV components, HODL waves (free tier)

### Caching Strategy
- **Real-time metrics** (mempool, price): 30-second polling
- **Daily metrics** (MVRV, HODL waves): Fetch once daily
- **Historical data**: 
  - Detailed hourly for last 2 years
  - Weekly aggregates for older data
  - Fetch once, append incrementally

---

## Implementation Phases (Suggested)

### Phase 1: iOS Core Experience (Week 1-2)
- Tab bar navigation structure
- Price tab with basic chart
- One overlay (200-week MA)
- Time range selection
- mempool.space API integration
- CoreData models and persistence
- Basic data refresh

### Phase 2: Complete iOS Feature Set (Week 2-3)
- All 10 metrics in Metrics tab grid
- Metric detail views with charts
- All price overlays functional
- Pull to refresh
- Settings screen basics
- Moving average calculations

### Phase 3: iOS Widgets & Polish (Week 3-4)
- Lock Screen widgets (3 types)
- Home Screen widgets (small, medium, large)
- StandBy mode support
- Animations and transitions
- Full accessibility (VoiceOver, Dynamic Type)
- iPad layout optimizations

### Phase 4: Advanced & Mac Port (Week 4+)
- Advanced alerts system
- Export functionality
- Performance optimizations
- **Begin Mac app port** (sidebar navigation, menu bar)
- Cross-platform code sharing

---

## Key Files Created

Four documentation files have been provided:

1. **Architecture.md**
   - Overall structure (iOS-first strategy)
   - Design decisions and rationale
   - Technology stack
   - What we explicitly decided NOT to do

2. **DataModel.md**
   - Complete enum definitions (MetricType, TimeRange, PriceOverlay)
   - CoreData schema
   - UserPreferences structure
   - Custom units (UnitHashRate)
   - Helper types

3. **MetricsDefinitions.md**
   - What each metric means
   - How to calculate derived metrics (MVRV, Mayer Multiple, NUPL)
   - Moving average calculations
   - Bull Market Support Band explanation
   - Data freshness requirements
   - API data source mapping

4. **iOS_UIDesign.md** (NEW)
   - Tab bar architecture details
   - Each tab's layout and components
   - Widget specifications (Lock Screen, Home Screen, StandBy)
   - Interaction patterns and gestures
   - Design guidelines (colors, typography, animations)
   - Accessibility considerations
   - Implementation priorities

---

## Deferred Features (V2 or Later)

**iOS V1 Deferred:**
- ❌ FoundationModels integration (natural language queries)
- ❌ Advanced alerts with push notifications
- ❌ Color customization for overlays
- ❌ Exchange reserves metric (complex data sourcing)
- ❌ Apple Watch app/complications
- ❌ iPad-specific multi-column layouts (use adaptive for now)
- ❌ Interactive widgets (iOS 17 feature, but complex)
- ❌ Export to CSV/PDF
- ❌ Correlation analysis between metrics

**Phase 2 (Post iOS V1):**
- ✅ **Mac app** (primary Phase 2 goal)
- Advanced widget features
- Cloud sync across devices
- More data sources (Glassnode, CryptoQuant)

---

## Conversation Context: Working with AI

The user is new to AI-assisted development and this is a learning experience. Key points:

**What worked well:**
- Starting with high-level architecture before diving into code
- Questioning complexity when it didn't serve the project
- Pushing back on over-engineering (protocol abstraction, CoreData for preferences)
- Clarifying terminology (entity vs managed object, snapshot naming)

**Preferred workflow discovered:**
- Browser Claude (Opus) for architectural decisions and planning
- Xcode Sonnet for implementation with project context
- Come back to browser for complex design questions

**Next steps the user wanted:**
- Try Cowork to continue development
- Test the agentic AI workflow
- See how documentation files can be maintained alongside code

---

## Outstanding Questions / Next Decisions

### Immediate Implementation Needs

1. **DataManager Architecture**
   - How to coordinate between cache and API
   - When to fetch fresh vs use cached data
   - Background update strategy

2. **CalculationService Design**
   - Where to calculate moving averages
   - How to efficiently compute MVRV, Mayer Multiple, NUPL
   - Caching calculated values vs recalculating on-demand

3. **ViewModel Structure**
   - One ViewModel per chart or shared?
   - How to handle overlay state
   - ObservableObject patterns with CoreData

4. **API Client Details**
   - Error handling strategy
   - Rate limiting
   - Retry logic
   - Response caching

### UI/UX Details to Finalize

1. **Widget priorities:**
   - Which metrics show in medium/large widgets?
   - Update frequency for widgets (every 15 min? 30 min?)
   - Interactive widget actions (tap to open specific tab?)

2. **Chart interactions:**
   - Haptic feedback on data point selection?
   - Share sheet options (image? PDF? data?)
   - Annotation capabilities?

3. **Metrics tab:**
   - Sort order (fixed categories or user customizable?)
   - Favorites system for quick access?
   - Search/filter functionality?

4. **Settings depth:**
   - How granular should refresh controls be?
   - Data usage concerns (WiFi only option?)
   - Cache management (auto-clear old data?)

5. **iPad optimizations:**
   - When to switch to split-view layout?
   - Side-by-side chart comparisons?
   - Pointer support enhancements?

---

## Code Patterns Established

### Working with MetricType
```swift
// Getting formatted value
let formattedValue = metricType.format(value)

// Getting description
let description = metricType.description

// Chart type for metric
let chartType = metricType.preferredChartType
```

### Saving to CoreData
```swift
// From API response
let apiData = try await api.fetchHistorical()
for response in apiData {
    let metric = Metric(context: context)
    metric.id = UUID()
    metric.metricTypeRaw = MetricType.price.rawValue
    metric.timestamp = response.timestamp
    metric.value = response.value
}
try context.save()
```

### User Preferences
```swift
// Singleton with auto-save
UserPreferences.shared.enabledPriceOverlays.insert(.ma200week)
// Automatically saves to UserDefaults

// In SwiftUI view
@ObservedObject var prefs = UserPreferences.shared
```

---

## Suggested Next Actions for Cowork

### 1. iOS Project Setup
- Create new iOS app project (iPhone target, iOS 17.0+)
- Set up CoreData model with Metric and PriceCandle entities
- Add documentation files to Documentation/ group in Xcode
- Create basic folder structure (Models, Services, Views, ViewModels)
- Configure app identifier and basic Info.plist settings

### 2. Implement Core Types
- Create all enums from DataModel.md (MetricType, TimeRange, PriceOverlay)
- Implement UnitHashRate custom unit
- Create UserPreferences class with UserDefaults backing
- Add Metric and PriceCandle extensions for computed properties

### 3. Build PersistenceController
- Basic save/fetch methods for Metric
- Basic save/fetch methods for PriceCandle
- Add proper error handling
- Test with sample data in previews

### 4. Create Tab Bar Shell
- TabView with 3 tabs (Price, Metrics, Settings)
- Basic navigation structure
- Tab bar icons (SF Symbols)
- Placeholder views for each tab

### 5. Build Price Tab (First Vertical Slice)
- Simple price chart using Swift Charts
- Fetch real price data from mempool.space
- Display current price header
- One time range (1 month)
- Prove the full stack: API → CoreData → ViewModel → View

### 6. Add First Overlay
- 200-week MA calculation
- Overlay toggle chip
- Render overlay on chart
- Verify moving average math

### 7. Iterate from There
- Complete Price tab (all overlays, all time ranges)
- Build Metrics tab grid
- Add metric detail views
- Settings basic structure
- Pull to refresh
- Lock Screen widget (simplest)

---

## Revised Cowork Workflow

**Step 1: Create iOS Project**
- Use Xcode to create new iOS App
- Swift, SwiftUI, CoreData enabled
- Minimum deployment: iOS 17.0

**Step 2: Add Documentation**
- Drag all .md files into Xcode
- Create Documentation/ group
- Don't add to target (they're just docs)

**Step 3: Initialize Git & Push**
```bash
cd /path/to/BitcoinAnalytics
git init
git add .
git commit -m "Initial commit with documentation"
git remote add origin <your-github-url>
git push -u origin main
```

**Step 4: Point Cowork to Project**
- Cowork → Open project folder
- Navigate to `/Users/yourname/Projects/BitcoinAnalytics`

**Step 5: First Prompt to Cowork**
```
I'm building the Bitcoin Analytics iOS app described in ProjectHandoff.md. 
This is an iOS-first app using tab bar navigation as detailed in iOS_UIDesign.md.

Review the documentation files and help me:
1. Set up the CoreData model with Metric and PriceCandle entities
2. Create the core enums from DataModel.md (MetricType, TimeRange, PriceOverlay)
3. Build the tab bar structure with placeholder views

Let's start with step 1 - the CoreData model.
```

---

## Questions to Ask User Before Proceeding

If the user is available for quick clarification:

1. **Menu bar integration:** V1 feature or defer to V2?
2. **Default window size:** Full screen encouraged or fixed size?
3. **Data export:** What formats are priorities? (CSV, JSON, PDF?)
4. **Alerts:** Simple threshold alerts in V1 or completely defer?
5. **Authentication:** Any plans for cloud sync or is this purely local?

---

## Resources & References

**APIs:**
- mempool.space: https://mempool.space/docs/api
- CoinGecko: https://www.coingecko.com/en/api
- blockchain.com: https://www.blockchain.com/api
- CoinMetrics: https://docs.coinmetrics.io/

**Bitcoin Metrics Education:**
- LookIntoBitcoin.com (metric explanations)
- Glassnode Insights (methodology)
- Checkonchain.com (charts and analysis)

**Swift Charts:**
- WWDC 2022: Hello Swift Charts
- WWDC 2023: Beyond the basics of Swift Charts

---

## Current State

**What exists:**
- Complete architectural plan (iOS-first with Phase 2 Mac port)
- Detailed specifications for all 10 metrics
- CoreData schema design
- Tab bar UI/UX design with widget specs
- Documentation files ready to use

**What needs to be built:**
- Everything (implementation hasn't started)
- This is a greenfield iOS project

**Recommended first milestone:**
- Display real Bitcoin price in Price tab chart with 200-week MA overlay
- This proves: API → CoreData → ViewModel → SwiftUI Chart → iOS UI pipeline works
- Include basic tab navigation shell

**Platform Strategy:**
- **Phase 1 (Current):** iOS app - iPhone primary, iPad adaptive
- **Phase 2 (Future):** Mac app port - sidebar navigation, menu bar
- Code reuse: Data layer, ViewModels, calculation logic all transferable

---

## Closing Notes

This is a well-scoped iOS V1 with clear boundaries and a path to Mac in Phase 2. The architecture is intentionally simple and pragmatic rather than over-engineered. The user made excellent decisions to:
- Reject unnecessary abstraction layers in favor of a more direct approach
- Use managed objects directly for better performance
- Start with iOS where their expertise is strongest
- Choose tab bar navigation (familiar, well-understood pattern)

The tab bar architecture provides clear separation of concerns:
- **Price tab:** Deep dive into price action with overlays
- **Metrics tab:** Overview of all metrics with drill-down
- **Settings tab:** Configuration and preferences

The documentation files should be treated as living documents - update them as implementation progresses to keep them in sync with the actual code.

**Key Success Factors:**
1. Start with one vertical slice (Price tab with one overlay)
2. Prove the data flow end-to-end before expanding
3. Use the developer's iOS expertise as the north star
4. Keep Mac port in mind but don't let it complicate iOS V1
5. Widgets are a differentiator - prioritize Lock Screen widget early

Good luck with the iOS implementation!
