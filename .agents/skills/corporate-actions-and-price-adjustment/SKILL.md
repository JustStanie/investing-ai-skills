---
name: corporate-actions-and-price-adjustment
description: "Use this skill to handle dividends, splits, spin-offs, symbol changes, and continuous contracts in research price series. Also use when asked to design adjustment factors, total-return series, corporate-action event tables, and futures rolls."
---

# Corporate Actions and Price Adjustment

You are a market data engineer who has built tick-to-bar pipelines for equities, futures and crypto at a systematic trading firm. You have maintained the corporate actions table for a global equity universe and the roll engine for sixty futures products. You have seen a 10-for-1 split appear in a backtest as a 90% crash, a dividend factor applied to volume, and a difference-adjusted crude oil series go negative twenty years back. Every one of those was a pipeline that adjusted prices in place instead of storing raw prices and factors.

## Principles

- **Store raw prices and an events table; adjust on read.** Adjusted prices are a view. Writing them back into the canonical store destroys the ability to reproduce anything.
- **Two families of factors.** Share-count events (splits, reverse splits, stock dividends) change price and volume. Cash-distribution events (dividends, spin-offs, special distributions) change price only.
- **Factors have a knowledge time.** A split is known weeks ahead; a dividend amount is known before the ex-date but not years before. Keep `announced_at` with every event so signals can be built as-of.
- **Price return and total return are different series.** Split-only adjustment gives price return. Split-plus-dividend adjustment approximates total return. Know which the research needs.
- **Continuous futures series are synthetic.** They exist for signals and charts. Positions are held in specific contracts.

## Event Types and Factor Formulas

Factors apply multiplicatively to every price strictly before the ex-date `E`. `P_prev` is the close on the last trading day before `E`.

| Event | Price factor | Volume factor | Notes |
|---|---|---|---|
| Split, `m` new for `n` old | `n / m` | `m / n` | 2-for-1: price x0.5, volume x2 |
| Reverse split, 1 new for `k` old | `k` | `1 / k` | 1-for-10: price x10, volume x0.1 |
| Stock dividend of `s` percent | `1 / (1 + s)` | `1 + s` | Treat as a split of `(1 + s)` for 1 |
| Cash dividend `D` | `1 - D / P_prev` | 1 | Applies to regular and special dividends |
| Spin-off, `r` child shares per parent share at child reference price `C` | `1 - (r * C) / P_prev` | 1 | `C` is the when-issued close before `E` or the first regular-way close |
| Rights issue | From the theoretical ex-rights price | 1 | Vendor-specific; check the source's convention |
| Merger, acquisition, bankruptcy | none | none | Handled as a delisting with a terminal value |

The multiplicative dividend factor is the standard convention and reproduces the exact total return `(P_E + D) / P_prev - 1` only when the ex-date move equals `-D`. If research needs exact total returns, compute them directly from raw prices and dividend amounts rather than from adjusted levels.

## Back-Adjustment and Forward-Adjustment

**Back-adjustment** leaves the latest price raw and multiplies every earlier price by the cumulative factor of all events after it. Consequences: every new event changes all of history, which invalidates caches and breaks reproducibility unless the factor table is versioned; historical price levels are no longer what traded, so a price-below-five-dollars filter, a tick-size rule or an options strike comparison is wrong in the past.

**Forward-adjustment** leaves prices raw at an anchor date and divides later prices by the cumulative factor of events between the anchor and each date. Past values never change, which suits live systems that keep running state. Both views carry the same information; only the anchor differs.

**Return-based.** For most research the cleanest object is the return series computed from raw prices with factors applied only on ex-dates:

```
r_t = P_t / (P_{t-1} * f_t) - 1        where f_t = product of price factors with ex-date t (1 if none)
```

Check: a 2-for-1 split on `t` gives `f_t = 0.5` and `P_t ~ P_{t-1} / 2`, so `r_t ~ 0`.

## Adjusting OHLCV Correctly

- Multiply `open`, `high`, `low`, `close` and `vwap` by the cumulative price factor.
- Multiply `volume` by the cumulative volume factor, which includes share-count events only. Dollar volume is then invariant: `(P * f) * (V / f) = P * V`.
- Keep adjusted prices as float64. Do not round to a tick; adjusted prices are not tradable prices.
- Adjust `notional` never; it is already in currency.
- For intraday bars, the factor for a date applies to every bar of that date.

## Identifiers, Symbol Changes and Delistings

Tickers change and are reused. CUSIPs change on reorganizations and reverse splits. ISINs for US securities are derived from CUSIPs and inherit the changes. FIGIs are stable per security. Vendor permanent identifiers are stable within that vendor. Build a `security_master` with an internal `security_id` and a `listing_history` table of `(security_id, venue, ticker, valid_from, valid_to)`. Tick and bar stores are keyed by the ticker as traded on that day; resolve to `security_id` at read time with an interval join, and do everything downstream by `security_id`.

Delistings need `last_trade_date`, `reason` (merger, bankruptcy, listing standards, voluntary), and `terminal_value` (cash per share in an acquisition; the exchange ratio times the acquirer's price in a stock deal; the first over-the-counter price or zero in a bankruptcy). A return series that stops at the last listed price without a terminal return has survivorship bias built in. Shumway (1997) showed that omitting delisting returns materially overstates the performance of small and distressed stocks.

## Futures: Continuous Contracts and Roll Adjustment

Each contract has an expiry, a last trading day and, for physically delivered products, a first notice day that can precede the last trading day. A roll schedule is a table `(product, from_contract, to_contract, roll_date, rule)` and is a versioned dataset in its own right.

| Roll rule | Definition | Suits |
|---|---|---|
| Calendar | Fixed number of sessions before expiry or first notice | Simple, predictable |
| Volume crossover | First session on which the next contract's volume exceeds the front's | Tracks where liquidity actually is |
| Open interest crossover | Same test on open interest | Smoother than volume; lags it |
| Fixed month sequence | For example, always the March/June/September/December cycle | Products with illiquid serial months |

Adjustment methods, with `g_k = next_close(R_k) - front_close(R_k)` and `q_k = next_close(R_k) / front_close(R_k)` on roll date `R_k`:

| Method | Adjusted price on date `t` | Preserves | Breaks |
|---|---|---|---|
| Spliced (none) | `P_raw(t)` of the held contract | Actual levels | A fake return on every roll date |
| Difference (Panama) | `P_raw(t) + sum of g_k for all R_k >= t` | Point moves; P&L per contract | Percentage returns; levels can go negative far back |
| Ratio | `P_raw(t) * product of q_k for all R_k >= t` | Percentage returns | Point moves; tick-size arithmetic |
| Return-based | No level; `r_t` from the held contract, switching after the close on `R_k` | Everything statistical | Charts and level-based rules |

Use the difference method for point-based P&L and backtests sized in contracts, the ratio method for percentage-based signals, and return-based series for anything statistical. Never compute percentage returns from a Panama series. Regenerate every continuous series whenever the roll rule changes, and store the roll schedule version with it.

## Worked Example: Equity Adjustment with pandas

```python
import pandas as pd

def cumulative_factors(events: pd.DataFrame) -> pd.DataFrame:
    """events: ex_date, price_factor, volume_factor (1.0 for cash events).
    Returns, per ex_date, the product of factors for that event and all later ones."""
    ev = events.sort_values("ex_date").copy()
    ev["cum_price"] = ev["price_factor"][::-1].cumprod()[::-1].values
    ev["cum_volume"] = ev["volume_factor"][::-1].cumprod()[::-1].values
    return ev[["ex_date", "cum_price", "cum_volume"]]

def back_adjust(bars: pd.DataFrame, events: pd.DataFrame) -> pd.DataFrame:
    """bars: date, open, high, low, close, vwap, volume for one security (raw)."""
    cf = cumulative_factors(events)
    out = pd.merge_asof(bars.sort_values("date"), cf.sort_values("ex_date"),
                        left_on="date", right_on="ex_date",
                        direction="forward", allow_exact_matches=False)
    out[["cum_price", "cum_volume"]] = out[["cum_price", "cum_volume"]].fillna(1.0)
    for c in ("open", "high", "low", "close", "vwap"):
        out[f"adj_{c}"] = out[c] * out["cum_price"]
    out["adj_volume"] = out["volume"] * out["cum_volume"]
    return out.drop(columns=["ex_date"])
```

`direction="forward"` with `allow_exact_matches=False` attaches to each bar the first event whose ex-date is strictly after the bar's date, whose cumulative factor already includes every later event. Bars on or after the last ex-date get a factor of 1.

## Worked Example: Panama-Adjusted Futures Series

```python
import pandas as pd

def panama_adjust(closes: pd.DataFrame, rolls: pd.DataFrame) -> pd.DataFrame:
    """closes: DatetimeIndex x contract code, raw settlement prices.
    rolls: roll_date, from_contract, to_contract; the from_contract is held through roll_date."""
    rolls = rolls.sort_values("roll_date")
    spliced = pd.Series(index=closes.index, dtype=float)
    offset = pd.Series(0.0, index=closes.index)
    start = closes.index[0]
    for r in rolls.itertuples():
        seg = (closes.index >= start) & (closes.index <= r.roll_date)
        spliced[seg] = closes.loc[seg, r.from_contract]
        gap = closes.at[r.roll_date, r.to_contract] - closes.at[r.roll_date, r.from_contract]
        offset[closes.index <= r.roll_date] += gap
        start = r.roll_date + pd.Timedelta(days=1)
    tail = closes.index >= start
    spliced[tail] = closes.loc[tail, rolls.iloc[-1].to_contract]
    return pd.DataFrame({"spliced": spliced, "panama": spliced + offset})
```

On each roll date the gap is added to every date up to and including the roll date, so the adjusted series moves from `next_close(R_k)` to `next_close(R_k + 1)` across the roll exactly as the new contract did.

## Procedure: Onboarding a Corporate Actions Source

1. Map the vendor's event types onto the table above; write down any the vendor merges or splits differently.
2. Load events with `ex_date`, `announced_at`, `record_date`, `pay_date`, raw terms (ratio, cash amount), and the vendor's factor if provided.
3. Recompute your own factors from the raw terms and compare with the vendor's. Investigate every mismatch above a rounding tolerance.
4. Detect unrecorded events: an overnight raw-price move whose ratio is close to a simple fraction with no matching event is a missing split.
5. Verify adjusted returns across ex-dates are small and unadjusted returns show the expected jump.
6. Version the events table; adjusted views name the version they used.

## Checklist

- Raw prices untouched in the canonical store
- Price and volume factors kept separately
- `announced_at` present for every event
- Dividend factor uses the prior close, not the ex-date close
- Volume adjusted only for share-count events
- Ticker history resolved to `security_id` by date interval
- Delistings carry a terminal value and reason
- Futures roll schedule stored and versioned; adjustment method named in the dataset

## Common Mistakes

- Adjusting volume for dividends.
- Using the ex-date close in the dividend factor.
- Applying factors to prices on the ex-date itself.
- Joining tick data to the security master by ticker without a date, so a reused ticker inherits another company's history.
- Filtering on adjusted price levels (dollar thresholds, penny-stock screens) in a backtest.
- Computing percentage returns on a difference-adjusted futures series.
- Rolling a physically delivered contract after first notice day in a backtest that assumes no delivery.
- Rebuilding adjusted prices on every research run without pinning the events-table version.

## Limits

This skill covers price and volume adjustment mechanics and identifier hygiene. Tax treatment of dividends, currency conversion for cross-listed securities, and the accounting of return-of-capital distributions are outside it. When a vendor's factor disagrees with yours by more than rounding, the vendor's raw terms, not their factor, are the reference.
