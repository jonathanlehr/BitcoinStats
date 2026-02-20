# Bitcoin Stats - iOS App

## Project Overview
iOS app for Bitcoin on-chain analytics with real-time data and customizable charts.

## Current State
- ✅ Project structure created with Cowork
- ✅ Service layer implemented (API access + CoreData)
- ✅ Unit tests for services
- 🚧 UI layer not started yet
- 🚧 ViewModels needed
- 🚧 Charts implementation needed

## Architecture
See Documentation/ folder for complete architecture:
- Architecture.md - Overall design
- DataModel.md - Core data structures
- iOS_UIDesign.md - UI specifications
- MetricsDefinitions.md - Metric calculations
- ProjectHandoff.md - Complete context

## Current Implementation Status

### ✅ Completed
- CoreData model (Metric, PriceCandle entities)
- PersistenceController
- MempoolSpaceAPI service
- API unit tests
- CoreData storage tests

### 🚧 In Progress
[List what you're working on]

### 📋 TODO
- ViewModels for all tabs
- SwiftUI views (Price, Metrics, Settings tabs)
- Swift Charts implementation
- Moving average calculations
- Widget implementation (defer to version 2 or 3)

## Code Conventions
- SwiftUI for all UI
- MVVM architecture
- Async/await for networking
- CoreData managed objects used directly (no abstraction layer)
- UserDefaults for preferences

## Important Files
- `BitcoinStats/Services/APIService.swift` - API client
- `BitcoinStats/Services/DataService` - CoreData CRUD operations
- `BitcoinStats/Services/PersistenceController.swift` - CoreData management
- `BitcoinStats/Services/SupplementaryAPIService` - Supplementary APIs, eg. CoinGecko
- `BitcoinStats/Models/` - Domain types and enums
- `BitcoinStatsTests/` - Unit tests

## When Working on This Project
1. Read relevant documentation in Documentation/ first
2. Check existing tests to understand expected behavior
3. Follow established patterns in Services/ layer
4. Run tests after making changes
5. Use XcodeBuildMCP tools for building/testing

## Testing
Run tests with:
`mcp__xcodebuildmcp__test_sim_name_proj` using iPhone 17 Pro simulator

## Build Instructions
Build for simulator:
`mcp__xcodebuildmcp__build_sim_name_proj` with scheme: BitcoinAnalytics
