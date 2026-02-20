#  Integrating Claude Code in This Xcode Project

cd /path/to/BitcoinAnalytics
claude
```

### Step 3: Let Claude Code Explore

**First prompt:**
```
I have an existing iOS project that was started with Cowork. Please:

1. Read CLAUDE.md to understand the project
2. Review the Documentation/ folder for architecture details
3. Analyze the existing Services/ layer code
4. Run the existing tests to verify everything works
5. Give me a summary of what's implemented and what needs to be done next

Then suggest 3-5 logical next steps to continue development.
```

Claude Code will:
- ✅ Read all your files
- ✅ Understand the existing structure
- ✅ Run your tests with XcodeBuildMCP
- ✅ Identify gaps
- ✅ Suggest next steps that build on what Cowork created

---

## Advantages of Continuing vs Starting Over

### ✅ Continue with Existing Project

**Pros:**
- Your service layer is tested and working
- You've already validated the architecture
- Cowork made good decisions you can learn from
- Faster to production
- More realistic for your course (students rarely start from scratch)

**Cons:**
- Need to bring Claude Code up to speed (but CLAUDE.md helps)

### ❌ Start Over from Scratch

**Pros:**
- Clean slate
- Fully automated from the beginning

**Cons:**
- Waste good work
- May not match what Cowork did
- Slower overall
- Less realistic workflow

---

## Recommended Workflow: Cowork → Claude Code Handoff

This is actually **excellent teaching material** for your course!

### The Handoff Pattern

**1. Cowork Phase** (already done)
- Project setup
- Basic structure
- Service layer
- Tests

**2. Claude Code Phase** (next)
- ViewModels
- Calculation services
- Batch file generation
- Test expansion

**3. Xcode Claude Phase**
- UI implementation
- Chart refinement
- Debugging
- Polish

**4. Back to Claude Code**
- Widget implementation
- Build automation
- Final testing

This shows students that **tools can work together** - you don't need to commit to just one!

---

## Practical Next Steps with Claude Code

Once Claude Code has analyzed your project, you could ask:

### Task 1: Create ViewModels
```
Based on the existing Services layer and the specifications in iOS_UIDesign.md:

1. Create PriceChartViewModel that:
   - Fetches price data from PersistenceController
   - Manages time range selection
   - Handles overlay toggles
   - Provides data for the chart

2. Create the file in ViewModels/
3. Follow the MVVM pattern used in the project
4. Write unit tests
```

### Task 2: Implement Calculations
```
Create CalculationService based on MetricsDefinitions.md:

1. Implement moving average calculations (SMA, EMA)
2. Calculate MVRV ratio from price and realized cap
3. Calculate Mayer Multiple
4. Calculate NUPL

Add comprehensive tests for each calculation.
```

### Task 3: Build First View
```
Create the Price tab view following iOS_UIDesign.md:

1. PriceTabView.swift with chart area
2. Overlay selector chips
3. Time range selector
4. Use PriceChartViewModel
5. Integrate Swift Charts

Then build and run on simulator to verify it works.

