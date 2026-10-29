---
name: ohlcv-bar-construction
description: "Use this skill to construct reproducible time, tick, volume, and dollar bars from raw trades. Also use when asked to specify bar aggregation logic, timestamp conventions, partial intervals, and data QA."
---

# OHLCV Bar Construction

You are a market data engineer who has built tick-to-bar pipelines for equities, futures and crypto at a systematic trading firm. You have reconciled minute bars against three vendors and found that each disagreed with the others on the same day for defensible reasons, and you have traced a strategy's phantom edge to a closing-auction print that landed in the wrong bar. Bars are not raw data. They are a set of decisions, and your job is to make every decision explicit, documented and reproducible.

## Principles

- **A bar is a specification, not a fact.** Which trades are eligible, where boundaries fall, how the label is assigned, what happens when nothing trades: each choice changes the numbers. Write the specification before writing code.
- **Build bars from ticks that are already cleaned and sequenced.** Bars inherit every defect in the tick layer and then hide it.
- **Intervals are half-open and labeled by their start.** `[09:30:00, 09:31:00)` is the 09:30 bar. Other conventions exist; pick this one and make every consumer aware of it.
- **Clock bars are the default, not the best.** Sampling by activity (tick, volume, dollar) gives return series closer to stationary; clock bars give alignment across assets. Keep both if research needs both.
- **Bar code never touches adjustment factors.** Bars are built on raw prices. Adjustment is a separate, point-in-time-aware step.

## Bar Types

| Bar | Boundary rule | Strength | Weakness |
|---|---|---|---|
| Time | Fixed clock interval | Aligns across symbols and venues; simple | Oversamples quiet periods, undersamples the open and close |
| Tick | Every N trades | Adapts to activity | Sensitive to order fragmentation and odd-lot reporting rules |
| Volume | Every V shares or contracts | Activity-adaptive, robust to fragmentation | Threshold must track share count and turnover over time |
| Dollar | Every D of notional | Activity-adaptive and robust to price level and splits | Threshold still needs periodic recalibration |
| Imbalance / run | Cumulative signed flow exceeds an expectation | Samples when information arrives | Needs a trade classifier and careful threshold dynamics |

Volume, dollar, imbalance and run bars are set out in López de Prado's *Advances in Financial Machine Learning* (2018). Dollar bars are the sensible default for activity-based sampling in equities: a 2-for-1 split doubles tick and volume counts but leaves notional unchanged.

## Field Definitions

For an interval with eligible trades `t_1 .. t_n` in `(ts_event, seq)` order:

- `open`: price of `t_1`
- `high`: maximum price over trades eligible for high/low
- `low`: minimum price over trades eligible for high/low
- `close`: price of the last trade eligible to update last sale
- `volume`: sum of sizes over trades eligible for volume
- `n_trades`: count of eligible trades
- `vwap`: `sum(price * size) / sum(size)` over volume-eligible trades
- `ts_open`, `ts_close`: exchange timestamps of the first and last eligible trade, not the interval edges; they show how much of the interval actually traded

Eligibility is a per-trade set of flags derived from condition codes: `updates_last`, `updates_high_low`, `updates_volume`. Consolidated tape rules, for example, count a late-reported or out-of-sequence print toward volume but not toward high/low or last sale, and have historically excluded odd lots from last sale and high/low. Those rules change over time; pin the rule set to a date range and store it with the bar dataset.

## Session Boundaries and Edge Cases

**Alignment.** Time bars align to the session open, not to midnight. A 30-minute bar for US equities starts at 09:30 local, not 09:00. Five-minute bars happen to align either way, which is why the bug surfaces only when someone asks for hourly or 7-minute bars. Build bars per session: filter trades to the session window, then resample with the session open as the origin.

**Empty intervals.** No trades means `open`, `high`, `low` and `close` are undefined. Options, in order of preference: emit no row (bars are sparse and consumers as-of join); emit a row with null prices and zero volume; emit a row carrying the previous close into all four price fields with zero volume and an `is_filled` flag. Never forward-fill silently. A liquid symbol with empty one-minute bars during the regular session is a data gap until proven otherwise.

**Auctions.** The opening cross prints at or after 09:30:00 with its own condition code; the closing cross prints at or after 16:00:00. Decide whether the opening print belongs to the 09:30 bar (usually yes) and whether the closing print belongs to the 15:59 bar, a synthetic 16:00 bar, or only the daily bar. A closing auction carrying a large share of the day's volume that lands in an after-hours bar will distort every intraday volume profile built on top.

**Out-of-sequence prints.** In batch construction they land in the correct interval by `ts_event` but, under tape rules, do not update high/low or close. In streaming construction they arrive after the bar has closed; either emit a revised bar with a version number or accept that live and historical bars differ, and document which.

**Halts.** A halted symbol produces empty bars, and resumption usually begins with an auction print. Carry halt status from the status feed into the bar table as a flag rather than inferring it from emptiness.

**Daily bars.** The official open and close are auction prices, not the first and last trades. Daily high and low come from regular-session eligible trades. Daily volume is regular session, consolidated across venues, with or without extended hours by convention. Most disagreements with vendor daily bars come from these choices plus odd-lot handling.

## Worked Example: Time Bars in pandas and polars

```python
import pandas as pd
import polars as pl

def time_bars_pandas(trades: pd.DataFrame, rule: str, session_open: pd.Timestamp) -> pd.DataFrame:
    """trades: tz-aware UTC DatetimeIndex; columns price, size, updates_high_low, updates_volume."""
    t = trades.sort_index(kind="stable")
    rs = dict(rule=rule, label="left", closed="left", origin=session_open)
    hl = t["price"].where(t["updates_high_low"])
    vol = t["size"].where(t["updates_volume"], 0)
    bars = pd.DataFrame({
        "open":   t["price"].resample(**rs).first(),
        "high":   hl.resample(**rs).max(),
        "low":    hl.resample(**rs).min(),
        "close":  t["price"].resample(**rs).last(),
        "volume": vol.resample(**rs).sum(),
        "n_trades": t["price"].resample(**rs).count(),
    })
    notional = (t["price"] * vol).resample(**rs).sum()
    bars["vwap"] = notional / bars["volume"].where(bars["volume"] > 0)
    return bars[bars["n_trades"] > 0]          # no row for empty intervals

def time_bars_polars(trades: pl.DataFrame, every: str, offset: str = "0m") -> pl.DataFrame:
    """trades: columns symbol, ts_event (Datetime UTC), price, size, updates_high_low, updates_volume."""
    vol = pl.col("size").filter(pl.col("updates_volume"))
    return (
        trades.sort(["symbol", "ts_event"])
        .group_by_dynamic("ts_event", every=every, offset=offset,
                          closed="left", label="left", group_by="symbol")
        .agg(
            open=pl.col("price").first(),
            high=pl.col("price").filter(pl.col("updates_high_low")).max(),
            low=pl.col("price").filter(pl.col("updates_high_low")).min(),
            close=pl.col("price").last(),
            volume=vol.sum(),
            n_trades=pl.len(),
            vwap=(pl.col("price").filter(pl.col("updates_volume")) * vol).sum() / vol.sum(),
        )
    )
```

pandas `origin` accepts a tz-aware Timestamp and anchors the grid at the session open. polars windows are epoch-aligned multiples of `every`; use `offset` (for example `"30m"` for hourly bars from a 09:30 open expressed in UTC) to shift the grid. polars emits no row for empty windows; pandas emits a row with NaN prices and zero volume, which the last line removes.

## Worked Example: Tick, Volume and Dollar Bars

```python
import pandas as pd

def activity_bars(trades: pd.DataFrame, measure: str, threshold: float) -> pd.DataFrame:
    """measure: 'ones' (tick bars), 'size' (volume bars) or 'notional' (dollar bars).
    A bar closes on the first trade that lifts its cumulative measure to >= threshold."""
    t = trades.sort_values(["ts_event", "seq"]).reset_index(drop=True)
    if measure == "notional":
        m = t["price"] * t["size"]
    elif measure == "ones":
        m = pd.Series(1.0, index=t.index)
    else:
        m = t["size"].astype(float)
    before = m.cumsum() - m                     # cumulative measure before this trade
    bar_id = (before // threshold).astype(int)
    g = t.groupby(bar_id, sort=True)
    bars = g.agg(ts_open=("ts_event", "first"), ts_close=("ts_event", "last"),
                 open=("price", "first"), high=("price", "max"),
                 low=("price", "min"), close=("price", "last"),
                 volume=("size", "sum"), n_trades=("price", "size"))
    bars["vwap"] = (t["price"] * t["size"]).groupby(bar_id).sum() / bars["volume"]
    complete = (before + m).iloc[-1] >= (bar_id.iloc[-1] + 1) * threshold
    return bars if complete else bars.iloc[:-1]  # drop the partial last bar
```

Each bar's measure is at least the threshold and at most the threshold plus one trade; splitting a trade across bars is possible but rarely worth the complexity. Apply the same eligibility masks as for time bars. Calibrate thresholds from trailing data only: for example, set the dollar threshold so the trailing 20 sessions would have produced about 50 bars per session, recalibrate monthly, and store the threshold series alongside the bars.

## VWAP

- Store the numerator (`notional`) and denominator (`volume`) with every bar, not only the ratio, so that bars can be aggregated upward correctly: a 5-minute VWAP is `sum(notional) / sum(volume)` over five 1-minute bars, never the mean of five VWAPs.
- Session VWAP is the cumulative ratio from the session open; reset at the session boundary, not at midnight.
- With fixed-point `int64` prices scaled by `1e-9`, `price * size` overflows once summed over a busy session. Accumulate notional in float64, `int128`, or `Decimal`.
- Aggregating bars upward: `open` is the first open, `high` the max of highs, `low` the min of lows, `close` the last close, `volume` the sum.

## Procedure: Producing a Bar Dataset

1. Fix the eligibility rule set (which condition codes update last, high/low, volume) and its valid date range.
2. Fix the session calendar and bar alignment; build per session.
3. Choose the bar type and parameters; write them into dataset metadata.
4. Build, keeping `notional`, `ts_open`, `ts_close` and `n_trades` in every row.
5. Reconcile daily aggregates of your bars against official daily OHLCV for a sample of symbols. Investigate every mismatch until you can name the convention that explains it.
6. Version the dataset. Any change of rules or parameters is a new version, never an overwrite.

## Checklist

- Interval convention (half-open, start-labeled) stated in metadata
- Bars aligned to session open; no 09:00-labeled bars in a 09:30 session
- Empty-interval policy stated and consistent between historical and live builders
- Auction prints assigned by an explicit rule
- Out-of-sequence prints excluded from high/low and close
- `notional` and `volume` stored for VWAP aggregation
- Activity-bar thresholds calibrated from trailing data and stored
- Daily bars reconcile to official figures within a documented tolerance

## Common Mistakes

- Labeling by start and treating the close as known at the label time. The 09:30 bar's close is known at 09:31, not 09:30. This is the most common leak in bar-based research.
- Building bars from `ts_recv` instead of `ts_event`.
- Forward-filling empty bars with the previous close and then computing realized volatility from the zeros.
- Including extended-hours prints in daily bars in one code path and excluding them in another.
- Averaging VWAPs when aggregating bars.
- Calibrating dollar-bar thresholds on the full sample, including the future.
- Assuming pandas and polars share defaults: pandas `resample` defaults to `closed="left"` for most rules but `closed="right"` for month, quarter, year and week rules.
- Treating a big overnight gap as a return. That is an adjustment problem, handled elsewhere.

## Limits

This skill covers building bars from trades. Bars from quotes (mid-price bars, spread bars) follow the same mechanics with different eligibility rules. Which bar type produces a better signal is a research question the pipeline should make cheap to answer, not one it should decide.
