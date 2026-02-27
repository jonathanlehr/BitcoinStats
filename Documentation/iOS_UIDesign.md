# Bitcoin Analytics - iOS UI Design

## Navigation Architecture: Tab Bar

Three main tabs provide clear separation of concerns and familiar iOS patterns.

```
┌─────────────────────────────┐
│    Bitcoin Analytics        │
├─────────────────────────────┤
│                             │
│      [Tab Content]          │
│                             │
│                             │
│                             │
├─────────────────────────────┤
│  💰      📊      ⚙️         │
│ Price  Metrics Settings     │
└─────────────────────────────┘
```

---

## Tab 1: Price Tab

**Primary Purpose:** Deep dive into Bitcoin price with overlays and controls.

### Layout
```
┌─────────────────────────────┐
│ 💰 Price                    │
├─────────────────────────────┤
│ $95,234.50        ↗ +2.3%  │
├─────────────────────────────┤
│                             │
│   [Price Chart]             │
│   (Interactive, zoomable)   │
│                             │
│                             │
├─────────────────────────────┤
│ Overlays:                   │
│ [✓ 200w MA] [Bull Band]    │
├─────────────────────────────┤
│ ⏱️  1D  1W  1M  3M  1Y  All │
└─────────────────────────────┘
```

### Components

**Price Header**
- Current price (large, bold)
- 24h change (with color: green up, red down)
- Last updated timestamp (small, gray)

**Chart Area**
- Takes up ~60% of screen
- Pinch to zoom
- Pan to scroll through time
- Long press for crosshair with exact values
- Shows selected overlays

**Overlay Selector**
- Horizontal scrolling chips
- Tap to toggle on/off
- Selected state: filled background
- Max 2-3 overlays recommended (avoid clutter)

**Time Range Selector**
- Segmented control or button group
- Highlights selected range
- Smooth animation when switching

### Interactions

**Chart Gestures:**
- **Pinch**: Zoom in/out on time axis
- **Pan**: Scroll through time
- **Long press**: Show crosshair with date/price tooltip
- **Double tap**: Reset zoom to full range

**Overlay Management:**
- Tap chip to toggle
- Long press chip for overlay info sheet
- Visual indicator when overlay is calculating

**Additional Actions:**
- Share button (top right): Export chart as image
- Info button: Explain current overlays

---

## Tab 2: Metrics Tab

**Primary Purpose:** Browse all available metrics at a glance, tap for details.

### Layout - Grid View
```
┌─────────────────────────────┐
│ 📊 Metrics                  │
├─────────────────────────────┤
│ Valuation ▼                 │
│ ┌─────────┐ ┌─────────┐    │
│ │ Price   │ │ MVRV    │    │
│ │ $95.2K  │ │ 2.1     │    │
│ │ ↗ +2.3% │ │ ↘ -0.1  │    │
│ └─────────┘ └─────────┘    │
│ ┌─────────┐ ┌─────────┐    │
│ │ Mayer   │ │ NUPL    │    │
│ │ 1.2     │ │ 0.68    │    │
│ └─────────┘ └─────────┘    │
├─────────────────────────────┤
│ Network ▼                   │
│ ┌─────────┐ ┌─────────┐    │
│ │ Mempool │ │ Hash    │    │
│ │ 42 MB   │ │ 750 EH/s│    │
│ └─────────┘ └─────────┘    │
└─────────────────────────────┘
```

### Components

**Metric Cards** (2 per row)
- Metric name
- Current value (large)
- 24h change (small, with arrow)
- Sparkline (optional, mini trend line)
- Color-coded status indicator
  - Green: favorable/bullish
  - Yellow: neutral
  - Red: cautious/bearish

**Category Sections**
- Collapsible headers (Valuation, Network, Holders)
- Tap to expand/collapse
- Default: all expanded

**Pull to Refresh**
- Standard iOS pattern
- Shows last update time

### Metric Detail View (Tap on any card)
```
┌─────────────────────────────┐
│ ← MVRV Ratio                │
├─────────────────────────────┤
│                             │
│   [Full-height Chart]       │
│                             │
│                             │
├─────────────────────────────┤
│ Current: 2.1                │
│ 24h: -0.1  7d: +0.3        │
├─────────────────────────────┤
│ ℹ️ About MVRV               │
│ Market Value to Realized... │
│                             │
│ 📊 Historical Context       │
│ • >3.5: Overheated         │
│ • <1.0: Undervalued        │
└─────────────────────────────┘
```

**Detail View Features:**
- Full-screen chart
- Time range selector
- Metric explanation (collapsible)
- Historical context/ranges
- Share button
- Alert button (set threshold alerts)

---

## Tab 3: Settings Tab

**Primary Purpose:** App configuration and preferences.

### Layout
```
┌─────────────────────────────┐
│ ⚙️ Settings                 │
├─────────────────────────────┤
│ Appearance                  │
│  Color Theme      Auto   >  │
│  Chart Style      Line   >  │
│                             │
│ Data & Sync                 │
│  Auto Refresh     ON        │
│  Refresh Interval 30s    >  │
│  Cache Size       124 MB    │
│                             │
│ Notifications               │
│  Price Alerts     ON        │
│  Daily Summary    OFF       │
│                             │
│ About                       │
│  Data Sources            >  │
│  Privacy Policy          >  │
│  Version          1.0.0     │
└─────────────────────────────┘
```

### Settings Sections

**Appearance**
- Color theme: Auto (system), Light, Dark
- Chart style: Line, Candlestick (for price)
- Default time range
- Default price overlay set

**Data & Sync**
- Auto-refresh toggle
- Refresh interval (30s, 1m, 5m, manual)
- Clear cache button
- Cache size indicator
- Data sources info (which APIs)

**Notifications**
- Enable/disable alerts
- Configure alert sounds
- Daily/weekly summary emails (future)

**About**
- Data sources and attribution
- Privacy policy
- Terms of service
- App version
- Rate on App Store link

---

## Widgets

### Lock Screen Widgets

**Circular (Accessory Circular)**
```
┌──────┐
│ ₿    │
│95.2K │
└──────┘
```
Shows: Current price

**Inline (Accessory Inline)**
```
₿ $95,234 ↗ +2.3%
```
Shows: Price with 24h change

**Rectangular (Accessory Rectangular)**
```
┌──────────────┐
│ Bitcoin      │
│ $95,234  +2% │
│ MVRV: 2.1    │
└──────────────┘
```
Shows: Price + one key metric

### Home Screen Widgets

**Small Widget (2x2)**
```
┌────────────┐
│ Bitcoin    │
│            │
│  $95,234   │
│  ↗ +2.3%   │
│            │
└────────────┘
```
Shows: Price and change only

**Medium Widget (4x2)**
```
┌──────────────────────────┐
│ Bitcoin        $95,234   │
│ ────────────────────────  │
│ MVRV      2.1      ↘ -0.1│
│ Hash Rate 750 EH/s ↗ +2% │
│ Mempool   42 MB    ↗ +5  │
└──────────────────────────┘
```
Shows: Price + 3 key metrics

**Large Widget (4x4)**
```
┌──────────────────────────┐
│ Bitcoin        $95,234   │
├──────────────────────────┤
│     ╱╲    ╱╲            │
│   ╱    ╲╱    ╲          │  Mini chart
│ ╱              ╲        │
├──────────────────────────┤
│ MVRV      2.1      ↘ -0.1│
│ Mayer     1.2      ↗ +0.1│
│ Hash Rate 750 EH/s ↗ +2% │
└──────────────────────────┘
```
Shows: Price + mini chart + 3 metrics

### StandBy Mode (iPhone 14+)

**Full-screen clock display** when charging on a stand.

```
┌─────────────────────┐
│                     │
│                     │
│    ₿ $95,234       │
│                     │
│    Block 820,145    │
│                     │
│                     │
└─────────────────────┘
```

**Features:**
- Toggle between price and block height (tap)
- Always-on display
- Large, readable text (like physical Bitcoin clock)
- Auto-updates every 30s
- Minimal design, high contrast

**Implementation:**
- Use `.widgetAccentable()` for StandBy compatibility
- Extra-large font sizes
- High contrast colors
- Minimal animation

---

## Adaptive Layouts

### iPhone (Primary Target)

**Portrait Mode** (default)
- Stack layout
- Charts take 60% height
- Controls below
- Tab bar at bottom

**Landscape Mode**
- Chart takes full width
- Controls in overlay/sheet
- Tab bar remains visible

### iPad (Secondary Target)

**Portrait Mode**
- Similar to iPhone but wider cards
- 3 metric cards per row instead of 2

**Landscape Mode**
- Split view: Metric list on left (1/3), chart on right (2/3)
- More desktop-like experience
- Preparation for Mac version

---

## Design Patterns & Guidelines

### Colors

**Semantic Colors:**
- Bullish/Positive: Green (`Color.green`)
- Bearish/Negative: Red (`Color.red`)
- Neutral: Blue (`Color.blue`)
- Warning: Orange (`Color.orange`)

**System Integration:**
- Use iOS dynamic colors for backgrounds
- Support light and dark mode
- High contrast mode support

### Typography

**Hierarchy:**
- Large Title: Price on Price tab
- Title: Current metric values
- Headline: Section headers
- Body: Descriptions, explanations
- Caption: Timestamps, metadata

**Monospaced Numbers:**
- Use `.monospacedDigit()` for all prices and metrics
- Prevents jumpy layouts when numbers update

### Animations

**Subtle & Purposeful:**
- Fade in new data (0.3s)
- Spring animation for chart updates
- Gentle pulse for loading states
- No gratuitous animations

### Accessibility

**VoiceOver Support:**
- All charts have text descriptions
- Metric values announced
- Navigation labels clear
- Alternative text for indicators

**Dynamic Type:**
- Respect user's text size preferences
- Scale layouts appropriately
- Maintain readability at all sizes

**Reduce Motion:**
- Respect system preference
- Cross-fade instead of sliding animations
- Static alternatives to animated charts

---

## Navigation Patterns

### Deep Linking
- `bitcoinanalytics://price` → Opens to Price tab
- `bitcoinanalytics://metric/mvrv` → Opens MVRV detail
- Support for widget taps

### State Preservation
- Remember last viewed tab
- Preserve scroll position
- Maintain zoom level on charts
- Restore time range selection

### Modal Presentations

**Overlay Info:**
- Sheet presentation (medium detent)
- Swipe down to dismiss
- Explanation of metrics

**Alert Configuration:**
- Full screen sheet
- Configure thresholds
- Preview alert conditions

**Share Sheet:**
- Standard iOS share sheet
- Share chart as image
- Copy current value

---

## Performance Considerations

### Chart Rendering
- Limit data points for smooth scrolling (downsample if needed)
- Use `.drawingGroup()` for complex charts
- Cache rendered charts
- Lazy load historical data

### Data Updates
- Background refresh every 30s (configurable)
- Use `@Published` with `receiveOn(.main)` for UI updates
- Debounce rapid changes
- Show loading indicators for slow operations

### Memory Management
- Paginate historical data
- Clear old cache on low memory warnings
- Use `@FetchRequest` efficiently
- Release chart views when not visible

---

## Implementation Priority

### Phase 1: Core Experience
1. Tab bar navigation shell
2. Price tab with basic chart
3. One overlay (200-week MA)
4. Time range selection
5. Basic data refresh

### Phase 2: Complete Metrics
6. All 10 metrics in grid
7. Metric detail views
8. All overlays functional
9. Pull to refresh
10. Settings basic structure

### Phase 3: Polish & Widgets
11. Lock Screen widgets (3 sizes)
12. Home Screen widgets (3 sizes)
13. StandBy mode support
14. Animations and transitions
15. Full accessibility support

### Phase 4: iPad & Advanced
16. iPad-optimized layouts
17. Landscape mode optimization
18. Deep linking
19. State preservation
20. Performance tuning

---

## Design Resources

**Apple HIG References:**
- Tab Bars: https://developer.apple.com/design/human-interface-guidelines/tab-bars
- Charts: https://developer.apple.com/design/human-interface-guidelines/charts
- Widgets: https://developer.apple.com/design/human-interface-guidelines/widgets

**Swift Charts Examples:**
- WWDC 2022: Hello Swift Charts
- WWDC 2023: Beyond the basics of Swift Charts
- Sample projects in Apple documentation

**Color Resources:**
- Use SF Symbols for icons (built-in, scalable)
- System colors for consistency
- Custom accent color: Bitcoin orange (#F7931A) as option
