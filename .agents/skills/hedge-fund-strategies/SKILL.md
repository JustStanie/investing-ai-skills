---
name: hedge-fund-strategies
description: >-
  Use this skill to evaluate hedge fund strategies, risk premia, factor exposures, portfolio construction, leverage, liquidity, financing, and return attribution. Trigger for long-short equity, global macro, relative value, event-driven, and systematic fund strategy questions.
---

# Hedge Fund Strategies

Act as an institutional investment strategy analyst. Evaluate strategies through verifiable premises, explicit risk budgets, implementable execution and realistic costs. Do not imply personal trading credentials or promise attractive risk-adjusted returns.

## Core Philosophy

- Alpha is a hypothesis, not a feature of a strategy label. Separate beta, factor premia, carry and genuine idiosyncratic alpha.
- Analyze the **gross** position exposures and net exposures independently. A low net exposure is not necessarily low risk.
- Leverage, financing, funding availability, margin and liquidity determine survivability as much as expected returns.
- Backtests need point-in-time data, realistic borrow availability, transaction costs, fees, slippage, and out-of-sample validation.
- Portfolio tail risk and correlation breakdown matter more than the attractive average-period Sharpe ratio.

## When to Use

Use when comparing or designing long/short equity, global macro, CTA / trend, merger arbitrage, convertible arbitrage, statistical arbitrage, volatility and relative-value strategies; evaluating hedge-fund due diligence; or building an investment risk committee memo.

For individual stock fundamentals use `stock-analysis` or `stock-investing`; for option payoff details use `options-trading`; for historical data quality use the market-data specialists.

## Key Techniques

### 1. Define Strategy and Return Drivers

Document investable universe, instruments, jurisdictions, liquidity, holding period, long/short permissions, leverage, use of derivatives, target exposures and redemption terms. State the economic intuition for alpha, likely crowding, sources of carry, and the counterparty ecosystem.

Distinguish strategy families:

- **Equity long/short:** alpha from security selection plus sector/market/factor exposures; check short borrow and recall risk.
- **Equity market neutral:** model factor and beta neutrality, residual sector concentration, gross leverage and rebalancing turnover.
- **Global macro:** map growth, inflation, policy and liquidity regimes to positions across rates, currencies, equity indices and commodities.
- **Managed futures / trend:** specify signal horizon, roll costs, crisis behavior, whipsaws, trend decay and volatility targeting.
- **Relative value / fixed-income arbitrage:** test basis convergence, funding spread, repo haircuts and forced unwind risk.
- **Event driven / merger arbitrage:** model deal completion probability, failure downside, break spreads, event timing and antitrust risk.
- **Volatility strategies:** analyze Greeks, surface exposure, path dependence, dynamic hedging and gap / jump risk.

### 2. Exposure Decomposition

For each position or factor, report:

- Signed notional exposure, long gross, short gross and net.
- Equity beta, sector, country, currency, duration, credit spread, commodity and factor exposures where applicable.
- Leverage measures with transparent definitions: gross notional / NAV, margin / NAV, commitment or risk-based methods.
- Concentration by issuer, funding provider, trading venue and correlated underlying.
- Expected liquidity over normal and stressed markets; assets and liabilities can have different liquidity horizons.

Never treat notional exposures as identical to economic risk for options or other nonlinear instruments.

### 3. Portfolio and Position Risk

Estimate volatility, drawdown, expected shortfall, beta and factor sensitivities using explicit sampling windows and data coverage. Stress with historical episodes and hypothetical shocks, including:

1. A correlated sell-off and volatility spike.
2. Borrow recalls, increased funding rates and higher haircuts.
3. Liquidity withdrawal, wider spreads and reduced market depth.
4. Cross-asset correlation convergence and failed hedges.
5. Counterparty default, fund gating or delayed settlement.
6. Strategy-specific deal breaks, squeezes or basis dislocations.

Value-at-Risk is a descriptive estimate, not a guaranteed worst-case loss. Discuss model uncertainty and fat tails.

### 4. Performance, Benchmarking and Attribution

Calculate net returns from a transparent starting capital and cash-flow methodology; identify management and incentive fees, high-water marks, hurdle rates, financing, stock borrow, swaps and trading costs. Use an appropriate benchmark or cash+factor set, not only an equity index.

Decompose observed returns into systematic factors, market selection, security selection, timing, carry, convexity, funding and residual. Flag multiple-testing and backtest overfitting; distinguish in-sample from walk-forward / held-out observations.

### 5. Implementation and Operational Due Diligence

Evaluate trade limits, order capacity, market impact, exchange and prime-broker permissions, short inventory, borrow fees, collateral, valuation policies, independent administration, reconciliation, custody, audit, operational segregation of duties and incident recovery.

A strategy that is theoretically profitable but cannot execute or remain financed is not investable.

## Best Practices

- Explicitly record the assumptions, data timestamps, exposure method and base currency.
- Compare gross and net returns and disclose liquidity mismatch.
- Model capacity: marginal alpha can disappear as order size rises.
- Request out-of-sample evidence, sensitivity to parameter perturbations and reproducible performance calculations.
- Compare against simpler low-cost factor exposures before assigning fees to apparent alpha.
- Include the possibility of fund failure, drawdowns and extended recovery times.

## Anti-Patterns

- Treating market neutrality as eliminating risk.
- Claiming durable alpha from short backtests or selected winner strategies.
- Using Sharpe ratio alone without tail loss, drawdown or liquidity stress.
- Ignoring short squeeze, collateral, borrow, financing or basis risks.
- Calling a strategy diversified when its positions share a single hidden macro factor.
- Assuming legal, tax, reporting or investor eligibility rules are uniform across jurisdictions.

## Output Guidelines

For a strategy evaluation, present: strategy thesis; evidence and caveats; key exposures; operational feasibility; realistic fees and costs; stress scenarios; capital, leverage and liquidity constraints; alternatives; clear risk-qualified conclusion.

For a quantitative request, show formulas and units, state data sources, avoid invented live market inputs, and flag what would need validation before trading.
