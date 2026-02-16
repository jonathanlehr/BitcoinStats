# Bitcoin Metrics - Definitions & Calculations

## Market Valuation Metrics

### Price
**What it is:** Current Bitcoin price in USD.

**Data Source:** Real-time from exchanges via mempool.space or CoinGecko API.

**Update Frequency:** Every 30 seconds for current price, historical stored hourly/daily.

**Chart Type:** Line or candlestick chart.

---

### Market Cap
**What it is:** Total value of all Bitcoin in circulation.

**Calculation:** `Current Price × Circulating Supply`

**Data Source:** mempool.space provides this directly.

**Interpretation:** 
- Measures the total USD value of Bitcoin as an asset
- Useful for comparing to other assets (gold, stocks, etc.)

---

### MVRV Ratio (Market Value to Realized Value)
**What it is:** Ratio of market cap to realized cap.

**Calculation:** `Market Cap / Realized Cap`

**Realized Cap:** Sum of the value of each UTXO at the price when it last moved.

**Data Source:** 
- Market cap from mempool.space
- Realized cap from blockchain.com or CoinMetrics

**Interpretation:**
- **< 1.0**: Market trading below aggregate cost basis (historically undervalued)
- **1.0 - 2.0**: Fair value range
- **2.0 - 3.5**: Bull market range
- **> 3.5**: Historically overheated territory (potential tops)

**Historical Context:**
- Major tops: 2011 (>5), 2013 (~5.5), 2017 (~4.5), 2021 (~4.0)
- Major bottoms typically occur around 1.0 or below

---

### Realized Price
**What it is:** The average price at which all Bitcoin last moved on-chain.

**Calculation:** `Realized Cap / Circulating Supply`

**Interpretation:**
- Represents the aggregate cost basis of all Bitcoin holders
- Acts as a macro support/resistance level
- Price tends to bounce off realized price during bear markets

---

### Mayer Multiple
**What it is:** Ratio of current price to the 200-day moving average.

**Calculation:** `Current Price / 200-Day MA`

**Interpretation:**
- **< 0.8**: Historically undervalued territory
- **0.8 - 1.0**: Fair value accumulation zone
- **1.0 - 2.4**: Normal bull market range
- **> 2.4**: Overextended, historically leads to corrections

**Strategy Guidance:**
- Mayer himself suggested avoiding buying above 2.4
- Dollar-cost averaging works well in 0.8-2.4 range

---

### NUPL (Net Unrealized Profit/Loss)
**What it is:** The difference between market cap and realized cap, normalized by market cap.

**Calculation:** `(Market Cap - Realized Cap) / Market Cap`

**Alternative Form:** `1 - (Realized Cap / Market Cap)` or `1 - (1 / MVRV)`

**Interpretation:**
- Shows what percentage of the market cap is unrealized profit (if positive) or loss (if negative)
- **< 0**: Net loss - Capitulation zone
- **0 - 0.25**: Hope/Fear - Recovery zone
- **0.25 - 0.5**: Optimism/Anxiety - Transitional zone  
- **0.5 - 0.75**: Belief/Denial - Bull market zone
- **> 0.75**: Euphoria/Greed - Overheated zone

**Cycle Context:**
- Bear market bottoms: Often negative or near 0
- Bull market peaks: Typically > 0.70

---

## Network Activity Metrics

### Mempool Size
**What it is:** Size of unconfirmed transactions waiting to be included in blocks.

**Unit:** Megabytes (MB)

**Data Source:** mempool.space real-time API

**Interpretation:**
- Small mempool (< 10 MB): Low network congestion, low fees
- Medium mempool (10-100 MB): Moderate activity
- Large mempool (> 100 MB): High congestion, high fees

**Practical Use:** 
- Helps users decide when to make transactions
- Can indicate market activity/excitement

---

### Hash Rate
**What it is:** Total computational power securing the Bitcoin network.

**Unit:** Exahashes per second (EH/s) - 10^18 hashes per second

**Data Source:** mempool.space (estimated from block production rate)

**Interpretation:**
- Rising hash rate = more security, more miner investment
- Falling hash rate = potential miner capitulation (can signal bottoms)
- Current levels (2025): ~500-750 EH/s

**Correlation:**
- Tends to follow price with a lag
- Hash rate stability indicates miner confidence

---

### Difficulty
**What it is:** How hard it is to find a valid block (adjusts every 2016 blocks, ~2 weeks).

**Calculation:** Automatically adjusted by protocol to maintain ~10 minute block time.

**Data Source:** mempool.space

**Interpretation:**
- Increases when hash rate increases
- Decreases when hash rate decreases
- Difficulty adjustments can create temporary profit squeezes for miners

---

### Active Addresses
**What it is:** Number of unique addresses involved in transactions per day (7-day moving average).

**Data Source:** Blockchain.com or CoinMetrics

**Interpretation:**
- Proxy for network usage/adoption
- Rising addresses = growing user base
- Falling addresses = declining activity

**Note:** Can be gamed, so use in context with other metrics

---

## Holder Behavior Metrics

### HODL Waves
**What it is:** Visualization of Bitcoin supply segmented by how long it hasn't moved.

**Age Bands:**
- < 1 month
- 1-3 months
- 3-6 months
- 6-12 months
- 1-2 years
- 2-5 years
- 5+ years

**Data Source:** Blockchain analysis (Glassnode, CoinMetrics, or custom calculation)

**Visualization:** Stacked area chart showing percentage in each band

**Interpretation:**
- Old coins accumulating = HODLing conviction, supply squeeze
- Young coins increasing = distribution, potential selling pressure
- During bear markets, coins "age up" into older bands
- During bull markets, old coins move (shown by younger bands expanding)

---

### LTH Supply (Long-Term Holder Supply)
**What it is:** Percentage of Bitcoin supply that hasn't moved in 155+ days.

**Why 155 days?** Statistical analysis shows this threshold best separates long-term holders from short-term traders.

**Data Source:** On-chain analysis (Glassnode definition)

**Interpretation:**
- **Rising LTH Supply**: Accumulation, coins moving into strong hands
- **Falling LTH Supply**: Distribution, long-term holders taking profit
- **Cycle Pattern:**
  - Bear markets: LTH supply increases (weak hands shaken out)
  - Bull markets: LTH supply decreases (HODLers take profit)

**Current Context (typical ranges):**
- Bear market lows: 65-70% LTH supply
- Bull market peaks: 50-55% LTH supply

---

## Derived Calculations (CalculationService Responsibility)

### Moving Averages
**Simple Moving Average (SMA):**
```
SMA = (P₁ + P₂ + ... + Pₙ) / n
```
Where P = price at each period, n = number of periods

**Exponential Moving Average (EMA):**
```
EMA = (Price_today × k) + (EMA_yesterday × (1 - k))
Where k = 2 / (n + 1)
```

**Required for overlays:**
- 200-week MA (SMA over 1400 days)
- 200-day MA (SMA over 200 days)
- 50-day MA (SMA over 50 days)
- 20-week MA (SMA over 140 days)
- 21-week EMA (EMA over 147 days)

---

### Bull Market Support Band
**Components:**
1. 20-week Simple Moving Average
2. 21-week Exponential Moving Average

**Visualization:** Area between these two lines (shaded green)

**Interpretation:**
- In bull markets, price typically stays above this band
- Breaking below the band = warning signal
- Reclaiming the band after a dip = bullish continuation signal

**Historical Performance:**
- 2017 bull: Price stayed above until peak
- 2021 bull: Price stayed above until May, returned in July
- Bear markets: Price stays below the band

---

## Data Freshness Requirements

| Metric | Update Frequency | Historical Granularity |
|--------|-----------------|----------------------|
| Price | 30 seconds | Hourly (2yr), Daily (older) |
| Market Cap | 30 seconds | Daily |
| MVRV | Daily | Daily |
| Realized Price | Daily | Daily |
| Mayer Multiple | Calculated on-demand | Daily (needs 200d price) |
| NUPL | Daily | Daily |
| Mempool | Real-time (30s) | Hourly |
| Hash Rate | Hourly | Daily |
| Difficulty | On adjustment (~2 weeks) | Per adjustment |
| Active Addresses | Daily | Daily |
| HODL Waves | Weekly | Weekly |
| LTH Supply | Daily | Daily |

---

## API Data Sources Summary

**mempool.space (Free, Primary):**
- Current price
- Mempool stats (size, fees)
- Hash rate, difficulty
- Block data

**CoinGecko (Free tier):**
- Historical price data (backup)
- Market cap

**blockchain.com (Free):**
- Realized cap
- Active addresses (historical)

**CoinMetrics (Free tier):**
- MVRV components
- HODL waves data
- LTH supply
- Realized price

**For V2 (Paid services):**
- Glassnode: Most comprehensive on-chain data
- CryptoQuant: Professional analytics
