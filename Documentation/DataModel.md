1# Bitcoin Analytics - Data Model

## Domain Enums

### MetricType
Defines all supported metrics in the application.

```swift
enum MetricType: String, CaseIterable, Identifiable {
    // Valuation Metrics
    case price = "Price"
    case marketCap = "Market Cap"
    case mvrv = "MVRV Ratio"
    case realizedPrice = "Realized Price"
    case mayerMultiple = "Mayer Multiple"
    case nupl = "NUPL"
    
    // Network Metrics
    case mempoolSize = "Mempool Size"
    case hashRate = "Hash Rate"
    case difficulty = "Difficulty"
    case activeAddresses = "Active Addresses"
    
    // Holder Behavior Metrics
    case hodlWaves = "HODL Waves"
    case lthSupply = "LTH Supply"
    
    var id: String { rawValue }
    
    var category: MetricCategory {
        switch self {
        case .price, .marketCap, .mvrv, .realizedPrice, .mayerMultiple, .nupl:
            return .valuation
        case .mempoolSize, .hashRate, .difficulty, .activeAddresses:
            return .network
        case .hodlWaves, .lthSupply:
            return .holders
        }
    }
    
    var description: String {
        switch self {
        case .price:
            return "Current Bitcoin price in USD"
        case .mvrv:
            return "Market Value to Realized Value. Ratio above 3.5 historically indicates overvaluation, below 1.0 indicates undervaluation."
        case .mayerMultiple:
            return "Price divided by 200-day MA. Values >2.4 suggest overheating, <0.8 suggest undervaluation."
        case .nupl:
            return "Net Unrealized Profit/Loss. Shows aggregate profit/loss of all holders as percentage. >0.75 = euphoria, <0 = capitulation."
        case .realizedPrice:
            return "Average price at which all BTC last moved. Network's aggregate cost basis."
        case .mempoolSize:
            return "Current size of the mempool (unconfirmed transactions) in megabytes."
        case .hashRate:
            return "Network hash rate - computational power securing the network."
        case .hodlWaves:
            return "Distribution of Bitcoin supply by age. Shows holding conviction."
        case .lthSupply:
            return "Percentage of supply held by Long-Term Holders (155+ days)."
        default:
            return rawValue
        }
    }
    
    var unit: String {
        switch self {
        case .price, .marketCap, .realizedPrice: return "USD"
        case .hashRate: return "EH/s"
        case .mempoolSize: return "MB"
        case .mvrv, .mayerMultiple, .nupl: return "ratio"
        case .lthSupply: return "%"
        case .difficulty: return ""
        case .activeAddresses: return "addresses"
        case .hodlWaves: return "%"
        }
    }
    
    var preferredChartType: ChartType {
        switch self {
        case .hodlWaves: return .stackedArea
        case .mempoolSize: return .stackedArea
        default: return .line
        }
    }
    
    func format(_ value: Double) -> String {
        switch self {
        case .price, .realizedPrice:
            return value.formatted(.currency(code: "USD"))
        case .hashRate:
            let measurement = Measurement(value: value, unit: UnitHashRate.exahashesPerSecond)
            return MeasurementFormatter().string(from: measurement)
        case .mvrv, .mayerMultiple:
            return String(format: "%.2f", value)
        case .nupl:
            return String(format: "%.1f%%", value * 100)
        case .mempoolSize:
            return String(format: "%.1f MB", value)
        case .lthSupply:
            return String(format: "%.1f%%", value)
        case .marketCap:
            return "$\(value / 1_000_000_000, specifier: "%.2f")B"
        default:
            return "\(value)"
        }
    }
}

enum MetricCategory: String, CaseIterable {
    case valuation = "Valuation"
    case network = "Network"
    case holders = "Holders"
}

enum ChartType {
    case line
    case area
    case stackedArea
    case candlestick
}
```

### TimeRange
Defines time ranges for charts and data queries.

```swift
enum TimeRange: String, CaseIterable, Identifiable {
    case day = "24H"
    case week = "1W"
    case month = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case year = "1Y"
    case twoYears = "2Y"
    case allTime = "All"
    
    var id: String { rawValue }
    
    var days: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        case .sixMonths: return 180
        case .year: return 365
        case .twoYears: return 730
        case .allTime: return 5000 // ~13.7 years since Bitcoin genesis
        }
    }
    
    var dataGranularity: DataGranularity {
        switch self {
        case .day, .week: return .hourly
        case .month, .threeMonths: return .daily
        case .sixMonths, .year, .twoYears: return .daily
        case .allTime: return .weekly
        }
    }
}

enum DataGranularity {
    case hourly
    case daily
    case weekly
    
    var seconds: TimeInterval {
        switch self {
        case .hourly: return 3600
        case .daily: return 86400
        case .weekly: return 604800
        }
    }
}
```

### PriceOverlay
Defines overlays that can be shown on the price chart.

```swift
enum PriceOverlay: String, CaseIterable, Identifiable {
    case ma200week = "200-Week MA"
    case ma200day = "200-Day MA"
    case ma50day = "50-Day MA"
    case ma20week = "20-Week MA"
    case ema21week = "21-Week EMA"
    case bullMarketSupportBand = "Bull Market Support Band"
    case realizedPrice = "Realized Price"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .ma200week: return .orange
        case .ma200day: return .blue
        case .ma50day: return .purple
        case .ma20week, .ema21week: return .green
        case .bullMarketSupportBand: return .green.opacity(0.2)
        case .realizedPrice: return .pink
        }
    }
    
    var lineWidth: CGFloat {
        switch self {
        case .bullMarketSupportBand: return 0 // Area, not line
        default: return 2
        }
    }
    
    var description: String {
        switch self {
        case .bullMarketSupportBand:
            return "Band between 20-week SMA and 21-week EMA. Bull markets typically hold above this range."
        case .ma200week:
            return "200-week moving average. Long-term trend indicator and historical support level in bull markets."
        case .ma200day:
            return "200-day moving average. Important medium-term trend indicator."
        case .realizedPrice:
            return "Average price at which all BTC last moved. Represents the network's aggregate cost basis."
        case .ma50day:
            return "50-day moving average. Short-term trend indicator."
        case .ma20week:
            return "20-week simple moving average. Component of Bull Market Support Band."
        case .ema21week:
            return "21-week exponential moving average. Component of Bull Market Support Band."
        }
    }
}
```

## CoreData Schema

### Entity: Metric
Stores individual metric data points.

**Attributes:**
- `id: UUID` (Primary key)
- `metricTypeRaw: String` (Stores MetricType.rawValue)
- `timestamp: Date`
- `value: Double`
- `metadataJSON: String?` (Optional JSON for complex data like HODL waves breakdown)

**Indexes:**
- Compound index on `(metricTypeRaw, timestamp)` for fast time-series queries

**Extension:**
```swift
extension Metric {
    var metricType: MetricType {
        MetricType(rawValue: metricTypeRaw ?? "") ?? .price
    }
    
    var metadata: [String: Any]? {
        guard let jsonString = metadataJSON,
              let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict
    }
}
```

### Entity: PriceCandle
Stores OHLCV data for candlestick charts.

**Attributes:**
- `id: UUID` (Primary key)
- `timestamp: Date`
- `open: Double`
- `high: Double`
- `low: Double`
- `close: Double`
- `volume: Double`

**Indexes:**
- Index on `timestamp`

## User Preferences (UserDefaults)

```swift
class UserPreferences: ObservableObject {
    static let shared = UserPreferences()
    
    @Published var enabledPriceOverlays: Set<PriceOverlay>
    @Published var selectedMetric: MetricType
    @Published var selectedTimeRange: TimeRange
    @Published var miniChartMetrics: [MetricType]
    
    // Default values
    static let defaultOverlays: Set<PriceOverlay> = [.ma200week, .bullMarketSupportBand]
    static let defaultMetric: MetricType = .price
    static let defaultTimeRange: TimeRange = .month
    static let defaultMiniCharts: [MetricType] = [.mvrv, .mempoolSize, .hashRate]
}
```

## Custom Units

```swift
class UnitHashRate: Dimension {
    static let hashesPerSecond = UnitHashRate(symbol: "H/s", converter: UnitConverterLinear(coefficient: 1))
    static let exahashesPerSecond = UnitHashRate(symbol: "EH/s", converter: UnitConverterLinear(coefficient: 1e18))
    
    override class func baseUnit() -> Self {
        return hashesPerSecond as! Self
    }
}
```

## Helper Types

### For Chart Rendering
```swift
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    
    init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}
```

### For API Parsing
```swift
// Lightweight structs for parsing JSON responses before saving to CoreData
struct APIMetricResponse: Codable {
    let timestamp: Date
    let value: Double
}

struct APIPriceCandleResponse: Codable {
    let timestamp: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
}
```
