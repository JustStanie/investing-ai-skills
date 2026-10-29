---
name: commodities-trading
description: "Use this skill to evaluate commodity exposures, futures curves, physical market fundamentals, and hedge design. Also use when asked to compare forward curves, analyze basis, design hedge ratios, and stress-test commodity positions."
---

# Commodities Trading

Analyze commodity markets and hedging through physical supply and demand, futures curves, basis risk, delivery logistics, and market-specific volatility.

## Core Philosophy

Commodity markets are fundamentally different from financial asset markets because they are anchored by physical supply and demand dynamics. Unlike stocks or bonds, commodities are consumed, produced, stored, and transported, and these physical constraints create unique price dynamics including backwardation and contango structures, seasonal patterns, locational basis differentials, and quality premiums. Understanding the physical market is not optional for commodity traders; it is the foundation upon which all analysis, whether fundamental or technical, must be built.

The forward curve in commodity markets contains critical information that is often misinterpreted. A market in contango, where future prices exceed spot prices, reflects carrying costs including storage, insurance, and financing, and may also signal current oversupply or anticipated future demand growth. A market in backwardation, where spot prices exceed futures, typically signals current tightness, low inventories, or supply disruption risk. The shape and dynamics of the forward curve are as important for trading strategy as the outright price level, particularly for roll yield in passive commodity exposure and for timing physical procurement and sales.

Commodity markets are uniquely susceptible to supply shocks that can produce extreme price movements. Weather events disrupting agricultural output, geopolitical conflicts threatening energy supply routes, mine accidents or labor disputes curtailing metals production, and logistical bottlenecks impeding transportation can all create price dislocations that overwhelm fundamental models calibrated to normal conditions. Risk management must explicitly account for these fat-tail events, which occur with greater frequency in commodity markets than statistical models typically assume.

## Key Techniques

### Fundamental Supply-Demand Analysis

Build a comprehensive balance sheet for each commodity you trade that tracks production, consumption, trade flows, and inventory levels on a monthly or quarterly basis. The global balance between supply and demand, expressed as the change in inventories, is the primary driver of price direction over medium-term horizons. A market transitioning from surplus to deficit will tighten, and prices will rise; the converse holds for markets moving from deficit to surplus. The speed and magnitude of balance shifts determine the pace of price adjustment.

Supply analysis requires understanding the production economics, capacity constraints, and investment cycles specific to each commodity. In energy markets, track rig counts, drilling efficiency trends, OPEC production decisions, and the cost curves of marginal producers. In metals, monitor mine production, refinery capacity utilization, and the lead times for new supply development. In agriculture, follow planted acreage, growing conditions, yield estimates, and the production calendar across key producing regions. Supply responses to price changes are often slow due to the long lead times for new capacity development, creating extended periods of imbalance.

Demand analysis should decompose total consumption by end-use sector, geography, and the sensitivity of each demand segment to price changes and economic conditions. Industrial commodity demand correlates strongly with manufacturing activity and construction spending. Energy demand is driven by transportation, industrial, residential, and power generation consumption. Agricultural demand is influenced by population growth, dietary shifts, and biofuel mandates. Identify the marginal demand segments that are most responsive to price changes, as these determine the elasticity that governs how much price must adjust to clear the market.

### Futures, Options, and Derivative Strategies

Futures contracts are the primary instruments for commodity trading, and understanding their specifications is essential. Contract size, delivery months, delivery locations, quality specifications, and settlement procedures vary across exchanges and commodities. These details matter because they determine basis risk, roll costs, and the relationship between the paper market price and the physical commodity value. Always know the delivery mechanics of the contracts you trade, even if you never intend to take or make delivery, because delivery optionality influences pricing around contract expiration.

Options strategies provide tools for expressing views with defined risk profiles that are particularly valuable in commodity markets given the potential for extreme price moves. Use put spreads to protect physical inventory or committed production against downside price risk while retaining some downside exposure through the sold put to reduce premium cost. Use call spreads to participate in potential supply disruption upside without the unlimited cost exposure of outright long futures. Collar structures that combine sold calls with purchased puts create zero-cost or low-cost hedges that are appropriate for physical producers and consumers.

Spread trading exploits relative value relationships between related contracts while reducing outright directional risk. Calendar spreads between different delivery months of the same commodity express views on forward curve shape and inventory dynamics. Crack spreads between crude oil and refined products express views on refinery margins. Crush spreads between soybeans and soybean meal and oil express views on processing margins. Geographic basis spreads between the same commodity at different delivery locations express views on logistics and regional supply-demand dynamics.

### Physical Market Integration

Physical market knowledge provides an informational edge that purely financial participants cannot replicate. Understand the supply chains for the commodities you trade, including production regions, transportation infrastructure, storage capacity, processing facilities, and end-use consumption patterns. This knowledge enables identification of bottlenecks, dislocations, and arbitrage opportunities that manifest as basis differentials between physical and paper markets or between different delivery locations and quality grades.

Inventory monitoring across visible and estimated invisible stocks provides the most timely indicator of market tightness. Track exchange-reported warehouse stocks, commercial storage levels reported by industry bodies, government inventory reports, and vessel tracking data that reveals commodities in transit. Declining visible inventories combined with backwardation in the forward curve strongly signal physical market tightness. Rising inventories with contango signal oversupply and accumulation.

Quality and grade differentials create trading opportunities for participants with the physical infrastructure and expertise to arbitrage them. The premium or discount for different crude oil grades, metal purities, or agricultural quality specifications fluctuates based on relative supply and demand for each specification. Understanding the technical specifications that determine interchangeability and the blending or processing options available creates opportunities that are invisible to traders who view commodities as homogeneous.

## Best Practices

- Track inventory levels across all measurable storage points and develop estimates for unreported stocks using production, consumption, and trade flow data to build the most complete picture of physical market tightness possible.
- Monitor the forward curve structure daily, as changes in the contango or backwardation slope often provide the earliest signal of shifting supply-demand dynamics before they are reflected in outright price movements.
- Develop relationships with physical market participants including producers, consumers, storage operators, and logistics providers who provide ground-level intelligence that financial data sources do not capture.
- Model the full cost of carry including storage, insurance, financing, and quality deterioration to identify when contango structures offer profitable storage arbitrage and when backwardation signals genuine physical scarcity.
- Manage roll risk actively by planning futures contract rolls well in advance and executing them during liquid periods rather than waiting until the last days before expiration when liquidity deteriorates and roll costs widen.
- Study historical supply disruption events specific to the commodities you trade, analyzing the magnitude, duration, and price impact of past disruptions to calibrate expectations for future scenarios.
- Maintain awareness of regulatory developments affecting commodity markets including position limits, margin requirements, environmental regulations, and trade policies that can alter supply-demand dynamics or market structure.

## Anti-Patterns

- **Ignoring storage economics** — Trading commodity futures without understanding the physical storage costs, capacity constraints, and financing dynamics that determine the fair value of the forward curve shape. This leads to mispricing of calendar spreads and incorrect assumptions about roll costs.

- **Treating commodities as financial assets** — Applying equity or fixed income analytical frameworks to commodity markets without adapting for the unique features of physical markets including production seasonality, weather sensitivity, geopolitical supply risk, and the absence of discounted cash flow valuation anchors.

- **Concentration in single commodity exposure** — Building large positions in a single commodity without diversification across the commodity complex, creating vulnerability to commodity-specific supply or demand shocks that can produce extreme adverse moves.

- **Underestimating correlation regime shifts** — Assuming stable correlations between commodities, or between commodities and financial assets, based on recent historical relationships. Commodity correlations are highly regime-dependent and frequently break down during the stress periods when diversification is most needed.

- **Neglecting delivery risk** — Holding futures positions into the delivery period without adequate preparation for either making or taking physical delivery, creating exposure to logistical complications, quality disputes, and forced liquidation at unfavorable prices.

## Verification and Practical Limits

Commodity contract specifications, delivery terms, exchange margin rules, settlement prices and trading hours are venue- and contract-specific and may change; verify live details before relying on them.
