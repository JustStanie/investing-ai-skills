---
name: options-trading
description: "Use this skill to analyze listed options strategies, payoff structures, Greeks, and margin risks. Also use when asked to compare option spreads, hedges, scenario payoffs, and sensitivity to volatility or time."
---

# Options Trading

Analyze listed options and volatility strategies with explicit payoffs, Greeks, assignment risk, liquidity, margin, and possible loss under stress.

## Core Philosophy

Options are contracts that convey the right, but not the obligation, to buy or sell an underlying asset at a specified price before a specified date. They are fundamentally instruments of risk transfer. Every options trade has a buyer who pays a premium for a defined risk profile and a seller who collects that premium in exchange for accepting an obligation.

The value of options derives from a combination of intrinsic value and time value, influenced by factors captured in the Greeks: delta, gamma, theta, vega, and rho. Understanding these sensitivities is not optional for anyone trading options seriously. They determine how your position will behave under various market conditions and are essential for managing risk.

Options should serve a clear purpose within your broader financial strategy. Whether you are generating income on existing holdings, hedging against downside risk, or expressing a directional view with defined risk, every trade should have a documented rationale, a profit target, and a loss limit before execution.

## Key Techniques

- **Covered Calls**: Sell call options against shares you own to generate income. This strategy works best in flat to moderately bullish markets. You collect premium in exchange for capping your upside at the strike price.
- **Cash-Secured Puts**: Sell put options on stocks you want to own at a lower price while setting aside cash to fulfill the obligation. This generates income while establishing a buy order below current market price.
- **Vertical Spreads**: Buy and sell options at different strike prices within the same expiration to create defined-risk, defined-reward positions. Bull call spreads and bear put spreads limit both your maximum profit and maximum loss.
- **Iron Condors**: Combine a bull put spread with a bear call spread to profit from low volatility. You collect premium from both sides and profit if the underlying stays within the range defined by your short strikes.
- **Protective Puts**: Purchase put options on holdings you want to protect from downside risk. This acts as portfolio insurance, establishing a floor on losses for the cost of the premium.
- **The Greeks in Practice**: Use delta to estimate directional exposure, gamma to understand how delta changes, theta to quantify time decay working for or against you, and vega to assess your exposure to volatility changes. Manage positions based on Greek exposures, not just price.
- **Implied Volatility Analysis**: Compare current implied volatility to historical levels to assess whether options are relatively cheap or expensive. Sell options when implied volatility is elevated and buy when it is depressed relative to historical norms.
- **Rolling Positions**: Extend or adjust positions by closing current options and opening new ones at different strikes or expirations. Rolling allows you to manage trades that have moved against you or to extend winners.

## Best Practices

- Never sell naked options unless you fully understand and can absorb the maximum potential loss. Naked calls have theoretically unlimited risk, and naked puts can result in losses equal to the strike price minus premium received.
- Size every position so that the maximum loss is a small percentage of your total portfolio. A single options trade should never risk more than two to five percent of your account.
- Define your exit criteria before entering any trade. Know your profit target, your stop loss, and the conditions under which you will roll or adjust the position.
- Trade liquid options with tight bid-ask spreads. Wide spreads increase your cost of entry and exit, eroding potential profits significantly.
- Avoid holding short options through earnings announcements or other known catalysts unless that is the explicit purpose of the trade. Event risk can produce moves that overwhelm your position.
- Understand assignment risk, particularly for short options that are in the money near expiration. Early assignment can occur on American-style options at any time, especially around ex-dividend dates.
- Paper trade new strategies before risking real capital. Simulated trading builds competence and reveals practical challenges that theory alone does not address.
- Monitor your overall portfolio Greeks, not just individual positions. Aggregate delta, gamma, and vega exposures determine how your total portfolio responds to market movements.
- Keep a detailed trading journal documenting every trade, the rationale, the outcome, and lessons learned. Pattern recognition from your own history is invaluable.
- Start with simple strategies and add complexity only as your understanding deepens. Mastering covered calls and cash-secured puts provides a strong foundation.

## Anti-Patterns

- **Buying Far Out-of-the-Money Options**: Purchasing cheap options with low probability of profit feels like a bargain but consistently destroys capital. The low price reflects the low probability of success.
- **Ignoring Time Decay**: Options are wasting assets. Holding long options without a catalyst or timeline for the expected move allows theta to steadily erode your investment.
- **Overleveraging Through Options**: The leverage inherent in options makes it tempting to take oversized positions. A series of leveraged losses can devastate an account far faster than stock losses.
- **Selling Premium Without Risk Management**: Collecting small premiums consistently feels profitable until a large adverse move wipes out months of gains. Always have a plan for managing losing trades.
- **Trading Illiquid Options**: Wide bid-ask spreads in illiquid options create immediate losses on entry and make it difficult to exit positions at fair prices during volatile markets.
- **Ignoring Correlation Risk**: Selling options on multiple correlated underlyings creates concentrated exposure. A broad market decline can trigger losses across all positions simultaneously.
- **Failing to Understand the Strategy**: Entering multi-leg options trades without fully understanding the profit and loss diagram, breakeven points, and risk exposures at every price level is reckless.
- **Letting Losses Run**: Hope is not a risk management strategy. When a trade moves beyond your predetermined loss threshold, exit the position and preserve capital for better opportunities.

## Verification and Practical Limits

Option contract multipliers, exercise/assignment rules, expiry conventions and margin treatments differ across venues; avoid assuming standard US-equity conventions for every product.
