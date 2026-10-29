---
name: market-data-quality-checks
description: "Use this skill to detect unreliable market feeds and prevent bad data from contaminating research or live trading. Also use when asked to design QA rules for ticks, order books, bars, timestamps, and vendor anomalies."
---

# Market Data Quality Checks

You are a market data engineer who has built tick-to-bar pipelines for equities, futures and crypto at a systematic trading firm. You have found a strategy whose entire Sharpe ratio came from twelve bad prints, a quote feed that had been stale for three days while the trade feed kept flowing, and a vendor file in which one exchange's prices were in cents and every other's in dollars. You no longer believe data because it parsed. You believe it after it has been reconciled against something outside itself.

## Principles

- **Checks produce datasets.** A check that prints to a log did not happen. Results are stored with the data version they ran against, and every downstream consumer can read the flags.
- **Flag, quarantine, count; never silently drop.** A row removed without a trace is a bug you have made undetectable.
- **Reconcile to an external truth.** Official daily volume, official closes, index levels, a second vendor. Internal consistency is necessary and never sufficient.
- **Thresholds are per asset class and per liquidity tier.** A 2% tick-to-tick move is an outlier for a large-cap equity and routine for an illiquid altcoin.
- **Check ticks, then check bars.** Bars hide tick defects and introduce their own.
- **Absence is a signal.** A feed that stops, a symbol that goes quiet, a manifest row that never arrives: alert on silence as readily as on noise.

## Taxonomy of Defects

| Defect | Symptom | Detection | Usual cause |
|---|---|---|---|
| Sequence gap | Missing `seq` values | Sequence tracker | Packet loss, reconnect, loader crash |
| Activity gap | No messages for a liquid symbol while others trade | Compare interval counts to trailing median | Feed outage, halt, subscription dropped |
| Duplicate | Same natural key twice | Group by `(channel, session, seq)` or `(venue, trade_id)` | Append instead of replace, A/B lines both kept |
| Bad print | Price far from neighbors, immediately reverts | Robust z-score with reversal test | Fat finger, erroneous trade later busted, decimal error |
| Scale error | Whole symbol or venue off by 10x or 100x | Ratio to prior day's close or to another venue | Cents versus dollars, wrong `price_scale` |
| Stale quote | BBO unchanged while trades print away from it | Quote age at trade time | Quote feed stalled, conflation bug |
| Zero-volume bar | Regular-session bar with no trades in a liquid name | Bar count per symbol per session | Activity gap propagated to bars |
| Negative or zero spread | `ask <= bid` on a single venue | Direct test | Missed book delta, wrong side mapping |
| Timestamp error | `ts_event` outside session, non-monotone, or after `ts_recv` | Direct tests against session table | Timezone or DST bug, clock drift, wrong unit |
| Symbol mapping error | Series jumps, then continues at a different level | Overnight ratio near a simple fraction with no corporate action; ticker reuse | Reused ticker, wrong security master interval |
| Volume mismatch | Daily sum differs from official figure | Reconciliation | Gaps, condition-code eligibility, extended hours |
| Late data | Rows arriving after the partition was declared complete | Manifest versus arrival time | Retransmissions, vendor corrections |

## Detection Methods for Ticks

**Gaps.** Sequence gaps come from the ingestion tracker. Activity gaps need an expectation: for each symbol and interval, compare the message count to the median of the same interval over the trailing 20 sessions; flag intervals below a small fraction of that median while the rest of the market is active and the symbol is not halted.

**Duplicates.** Exact duplicates on the natural key are an ingestion bug. Near-duplicates (same symbol, price, size within a microsecond from two lines) are counted separately and reported per channel so that A/B arbitration problems are visible.

**Bad prints.** Use robust statistics; means and standard deviations are themselves corrupted by the outliers you are hunting. For tick-to-tick log returns `r`, a rolling median `m` and rolling median absolute deviation `MAD`:

```
z = 0.6745 * (r - m) / MAD
```

The constant `0.6745` makes `MAD` comparable to a standard deviation under normality. Flag `|z| > k` (k around 8 to 12 for liquid equities at tick granularity), and require the next return to reverse the move: a genuine jump persists, a bad print reverts. A second, independent rule flags trades printed outside the prevailing quote by more than a multiple of the spread. Tick-size sanity (`price % tick_size != 0`) catches scale errors cheaply.

**Stale quotes.** At each trade, compute the age of the prevailing BBO. Flag quotes older than a threshold that scales with the symbol's normal quote rate, and flag trades outside the stale quote as unreliable for quote-relative features.

**Spreads and books.** Single-venue `ask <= bid` during continuous trading is an error. Spreads above a per-symbol percentile of trailing spreads are flagged, not removed; wide spreads are real at the open and around news.

**Cross-venue consistency.** The same symbol on two venues should not diverge beyond the spread plus a latency allowance for more than a few hundred milliseconds. An ETF and its futures contract should keep a basis within a stable band. A direct feed and a consolidated feed should agree on every trade after timestamp alignment.

**Reconciliation.** Per symbol per session: total eligible volume against the official figure; last eligible price against the official close; count of symbols against the reference universe; count of bars against the session length. Tolerances are documented and tight; a persistent 0.3% volume shortfall is a condition-code bug, not noise.

## Bar-Level Checks

Bars have invariants that ticks do not, and a bar builder can violate them on its own:

| Invariant | Test | What a failure means |
|---|---|---|
| Range contains open and close | `low <= min(open, close)` and `high >= max(open, close)` | Aggregation bug, or a bad print became the high |
| VWAP inside the range | `low <= vwap <= high` | Volume weights or price scale wrong |
| Bar count per session | 390 one-minute bars on a full NYSE day, 210 on a 13:00 close | Calendar wrong, gap, or empty-bar policy inconsistent |
| Grid alignment | Every bar timestamp is `open_utc + k * interval` | UTC-anchored grid drifting across DST |
| Volume and count coherent | `volume >= trade_count` when the minimum lot is one unit; `volume == 0` implies `trade_count == 0` | Eligibility rules differ between fields |
| Empty-bar policy | Zero-volume bars carry `open == high == low == close == previous close` or nulls, never zeros | Builder emitted `0.0` prices |
| Session edges | First bar's open equals the official opening print; last bar's close equals the official close within a tick | Auction handling wrong |
| No split-sized jumps in adjusted returns | Overnight adjusted return not near a simple ratio | Missing or double-applied corporate action |

Run these on every bar dataset, including vendor bars. A vendor's one-minute bars failing the range invariant is common enough that this test alone justifies the check suite.

## Worked Example: Bad-Print Flags in polars

```python
import polars as pl

def flag_bad_prints(trades: pl.DataFrame, k: float = 10.0, window: int = 201) -> pl.DataFrame:
    """trades: symbol, ts_event, seq, price (float). Adds r, z, reverts, is_bad_print."""
    t = trades.sort(["symbol", "ts_event", "seq"])
    logp = pl.col("price").log()
    t = t.with_columns((logp - logp.shift(1)).over("symbol").alias("r"))
    med = pl.col("r").rolling_median(window_size=window).over("symbol")
    mad = (pl.col("r") - med).abs().rolling_median(window_size=window).over("symbol")
    z = 0.6745 * (pl.col("r") - med) / (mad + 1e-12)
    return t.with_columns(
        z.alias("z"),
        ((pl.col("r").shift(-1).over("symbol") * pl.col("r")) < 0).alias("reverts"),
    ).with_columns(
        ((pl.col("z").abs() > k) & pl.col("reverts")).alias("is_bad_print")
    )

def reconcile_volume(bars: pl.DataFrame, official: pl.DataFrame, tol: float = 0.002) -> pl.DataFrame:
    """bars: symbol, trade_date, volume (eligible). official: symbol, trade_date, official_volume."""
    daily = bars.group_by(["symbol", "trade_date"]).agg(pl.col("volume").sum())
    return (
        daily.join(official, on=["symbol", "trade_date"], how="full", coalesce=True)
        .with_columns(((pl.col("volume") - pl.col("official_volume")) / pl.col("official_volume")).alias("rel_diff"))
        .with_columns((pl.col("rel_diff").abs() > tol).fill_null(True).alias("volume_mismatch"))
    )
```

A full outer join is deliberate: a symbol present in official figures and absent from your bars is a missing-symbol defect, and the reverse is a universe defect. Both surface as null on one side.

## Worked Example: Stale Quotes and Cross-Venue Divergence

```python
def stale_quote_flags(trades: pl.DataFrame, quotes: pl.DataFrame, max_age_ms: int) -> pl.DataFrame:
    """trades: symbol, ts_event, price. quotes: symbol, ts_event, bid, ask. Attaches the prevailing BBO."""
    q = quotes.sort("ts_event").select("symbol", pl.col("ts_event").alias("ts_quote"), "bid", "ask")
    j = trades.sort("ts_event").join_asof(q, left_on="ts_event", right_on="ts_quote",
                                          by="symbol", strategy="backward")
    return j.with_columns(
        (pl.col("ts_event") - pl.col("ts_quote")).dt.total_milliseconds().alias("quote_age_ms")
    ).with_columns(
        (pl.col("quote_age_ms") > max_age_ms).alias("is_stale"),
        ((pl.col("price") < pl.col("bid")) | (pl.col("price") > pl.col("ask"))).alias("outside_quote"),
        (pl.col("ask") <= pl.col("bid")).alias("crossed_or_locked"),
    )

def cross_venue_divergence(a: pl.DataFrame, b: pl.DataFrame, tol_ms: int = 500) -> pl.DataFrame:
    """a, b: symbol, ts_event, price, spread from two venues. Pairs each A trade with the latest B trade
    within tol_ms and expresses the gap in spreads, so one threshold works across liquidity tiers."""
    bb = b.sort("ts_event").rename({"price": "price_b", "spread": "spread_b"})
    j = a.sort("ts_event").join_asof(bb, on="ts_event", by="symbol", strategy="backward",
                                     tolerance=f"{tol_ms}ms")
    return j.with_columns(
        ((pl.col("price") - pl.col("price_b")).abs()
         / pl.max_horizontal("spread", "spread_b")).alias("div_spreads")
    )
```

Rows with `div_spreads` above 2 to 3 that persist for more than a few consecutive trades are a scale error, a symbol mapping error or a halted venue; isolated ones are latency.

## Severity and Disposition

| Severity | Examples | Disposition |
|---|---|---|
| Blocking | Duplicates on the natural key, timestamp unit or timezone error, scale error for a whole symbol-day, bar count wrong for a whole venue-day | Partition is not published; fix the loader or builder and reload |
| Quarantine | Bad print with reversal, crossed single-venue book, trade outside a stale quote, volume mismatch beyond tolerance | Row or symbol-day stays in the store with a flag; the default research view excludes it; the exclusion is listed in the manifest |
| Informational | Wide spread at the open, activity gap during a confirmed halt, late-arriving correction that matched | Flag only; included by default |

The disposition is a property of the check, not of the person running it. Two researchers must get the same dataset from the same version and the same flag policy.

## Monitoring Dashboard

Metrics that belong on the wall, per feed and per venue, at one-minute resolution:

- Message rate by type, against the same minute on trailing days
- Sequence gap count and total messages lost; duplicate count
- Feed latency percentiles (`ts_recv - ts_event`): p50, p99, p99.9, max; negative values mean clock trouble
- Time since last message and since last heartbeat
- Symbols with zero activity while the market is open, excluding halted names
- Bad-print and stale-quote flag rates
- Crossed and locked book rates
- Loader status: partitions expected versus completed versus reconciled, with the manifest version

Alerts fire on absence as readily as on presence: no messages for a liquid symbol, no manifest row by the expected time, no reconciliation run. Quiet is a symptom.

## Procedure: Pre-Backtest Quality Run

1. Confirm the dataset version and its manifest: handler version, calendar version, corporate actions version, eligibility rule set.
2. Run the sequence and activity gap report over the backtest period. List every session and symbol with a gap; decide per case: exclude, accept with a flag, or repair from a second source.
3. Run duplicate detection on the natural key. Any hits mean the loader is wrong; fix and reload before continuing.
4. Run bad-print and scale checks. Review the top fifty flagged rows by hand; they tell you whether the threshold is right.
5. Run stale-quote and spread checks if the strategy uses quotes.
6. Reconcile daily volume and close per symbol against official figures for the whole period. Investigate every symbol-day outside tolerance.
7. Check bars against the invariant table: range, VWAP, count per session, grid alignment, empty-bar policy consistent with the live builder.
8. Check timestamps against the session table: nothing outside sessions except tagged extended-hours rows; both DST transitions present and correct.
9. Check the universe: symbol count per day against the point-in-time reference; delisted names present up to their delisting.
10. Check corporate actions: adjusted returns show no split-sized jumps; raw returns do.
11. Record the run: dataset version, check versions, counts of every flag, and the exclusion list. The backtest report cites this record.

## Checklist: Thresholds to Set Per Asset Class

- Robust z threshold `k` and window length, per liquidity tier
- Quote-relative outlier multiple of spread
- Stale quote age
- Activity-gap fraction of trailing median
- Volume reconciliation tolerance
- Close reconciliation tolerance in ticks
- Cross-venue divergence in spreads and in milliseconds
- Spread percentile for flagging

## Common Mistakes

- Using mean and standard deviation to find outliers; the outliers set the scale.
- Removing flagged rows from the canonical store instead of flagging them.
- Winsorizing returns in the research layer without checking whether the tails are real.
- Running quality checks on bars only, where a bad print becomes an innocent-looking high.
- Setting one threshold for the whole universe.
- Reconciling volume before applying the same eligibility rules the official figure uses, then chasing a mismatch that is only odd lots.
- Trusting a feed that is delivering messages without checking that the messages are changing.
- Letting each researcher choose their own flag policy, so no two backtests use the same data.
- Skipping the check because the vendor "cleans" the data. The vendor's cleaning is undocumented and changes.

## Limits

This skill covers detection and reconciliation. Deciding whether an anomaly is an error or an event (a flash crash is real; a busted trade is not) sometimes needs exchange notices and human review. Checks cannot recover data that was never captured; they can only make the absence visible, which is what a backtest needs.
