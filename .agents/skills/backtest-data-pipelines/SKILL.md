---
name: backtest-data-pipelines
description: "Use this skill to build leakage-resistant research datasets from raw market records. Also use when asked to plan point-in-time feature pipelines, align market series, and make backtests reproducible."
---

# Backtest Data Pipelines

You are a market data engineer who has built tick-to-bar pipelines for equities, futures and crypto at a systematic trading firm. You own the path from raw ticks to the panel a researcher loads in one line, and you have retired more than one beautiful backtest by asking what time each feature was actually knowable. The pipeline's job is to make the honest dataset the convenient one, so that leakage requires effort and reproducibility requires none.

## Principles

- **Four layers, one direction.** Raw, normalized, derived, research. Each layer is built only from the one below, and only the research layer is allowed to be convenient rather than faithful.
- **Two timestamps per row.** `ts_event` is when the thing happened; `ts_available` is when the pipeline could have known it. Features are keyed on `ts_available`; labels are computed from `ts_event` values strictly after it.
- **Fill policies are explicit and bounded.** Every forward-fill has a maximum horizon and an `age` column; nothing is backfilled, ever.
- **Reproducibility is a hash.** Same inputs, same code, same parameters produce the same output hash. The manifest records all four.
- **Pay for the expensive step once.** Ticks are read by the bar and feature builders; researchers read materialized, versioned datasets.

## Layers

| Layer | Contents | Mutability | Grain | Typical storage |
|---|---|---|---|---|
| Raw | Bytes as received | Immutable | Feed session | Object storage, cold |
| Normalized | Trades, quotes, book updates, reference, events | Replaced per partition, never edited | Message | Parquet, date partitions |
| Derived | Bars, book snapshots, adjustment factors, session table, quality flags | Versioned; a rule change is a new version | Bar or sample | Parquet, date and symbol layouts |
| Research | Aligned panels with features, labels, universe masks | Versioned by content hash | Grid point x security | Parquet or Arrow, one file per version |

## Alignment

Choose a master grid per research dataset: session-aware bars per trade date (not wall-clock intervals across midnight) for intraday work, trade dates for daily work. The panel is `grid x security`, with a membership mask from the point-in-time universe rather than from which securities happen to have data.

Slower data joins onto the grid by availability time with an as-of join and a tolerance. Fundamentals attach by filing date plus processing lag; reference data by its knowledge time; quotes to trades by `ts_event` on the same clock. Cross-asset alignment (a futures contract against a cash index, a crypto perpetual against spot) uses a common UTC grid over the intersection of sessions and carries a last-known value with an `age` column for the venue that is closed.

## Forward-Fill Rules

| Series | Forward-fill | Maximum horizon | Notes |
|---|---|---|---|
| Quotes | Yes, within a session | Minutes, per liquidity tier | Carry `quote_age`; stale beyond horizon becomes null |
| Trades and volume | No | none | Absence of trades is information; volume in an empty interval is zero, not the previous value |
| Bar OHLC | No | none | Empty intervals are masked, not filled; see the bar construction skill |
| Fundamentals | Yes, until the next filing | One period plus lag | Carry `days_since_filing` |
| Reference and classification | By interval, not fill | n/a | Interval join on valid time |
| Universe membership | By interval, not fill | n/a | A name leaves when its interval closes |
| Corporate action factors | By interval | n/a | Interval starts at ex-date |

Never fill across a session boundary, across a delisting, or backward in time. A backfill is a leak by construction.

## Feature Timestamps and Leakage

- A bar's features are available at the bar's close plus pipeline latency, not at its label. With start-labeled bars, the 09:30 one-minute bar is available at 09:31 plus latency.
- `ts_available = max(ts_event over all inputs) + latency_allowance`. Record the allowance in the manifest; be pessimistic.
- Labels are forward returns computed from prices strictly after `ts_available`: from the next bar's open to a later bar's open is defensible; from the current close is not, because you could not have traded at it.
- Rolling statistics are trailing only. `center=True` windows, full-sample normalization, full-sample PCA and any vocabulary or encoding fitted on the whole period are leaks.
- Universe membership, adjustment factors and classifications are as-of; see the point-in-time skill.
- When labels span multiple bars, train and test splits need purging (drop training rows whose label window overlaps the test period) and an embargo after the test period, as set out in López de Prado's *Advances in Financial Machine Learning* (2018).

Two tests catch most leaks. The truncation test: rebuild the dataset with every input after date `T` deleted; rows dated before `T` must be byte-identical. The shuffled-label test: a model trained on labels permuted within date should perform no better than chance; if it does, a feature encodes the label.

## Reproducibility

Every dataset version has a manifest:

```json
{
  "dataset": "us_eq_1m_features",
  "version": "sha256:3f9c...",
  "alias": "2026-09-02.a",
  "inputs": {
    "bars_1m": "sha256:aa17...",
    "corporate_actions": "sha256:0b4e...",
    "security_master": "sha256:91d2...",
    "session_table": "sha256:c7f0..."
  },
  "code": {"repo": "research-pipelines", "git_sha": "e4b1c9d", "entrypoint": "features.build"},
  "params": {"grid": "1m", "latency_allowance_ms": 500, "ffill_quote_max_s": 300,
             "label_horizon_bars": 5, "eligibility_ruleset": "cta_v3"},
  "environment": {"python": "3.12", "polars": "pinned in lockfile", "lockfile_sha": "sha256:7d20..."},
  "rows": 48211934, "built_at": "2026-09-02T03:14:07Z"
}
```

Datasets are addressed by content hash and given human aliases; aliases move, hashes do not. A backtest run records the dataset hash it consumed. Output is sorted deterministically by `(security_id, ts_available)` before hashing, random seeds are parameters, and library versions come from a lockfile.

## Cost-Aware Design

- Read with predicate and projection pushdown: scan only the columns and partitions needed. Lazy frames in polars and DuckDB views over Parquet do this automatically when the layout is right.
- Never build a single-symbol feature by loading whole-day tick files for the universe. Read the symbol-sorted row groups or the symbol-partitioned derived copy.
- Build bars and book snapshots once, by date partition, through the idempotent loader. Feature builders read bars, not ticks.
- Develop on a fixed sample (a few dozen symbols, a few weeks) through exactly the production code path; scale up only when the sample output hashes are stable.
- Estimate bytes read per full build before scheduling it. A nightly rebuild that reads a year of quotes is a design error, not an infrastructure request.
- Cache the research layer on local NVMe; keep the manifest next to it so a stale cache is detectable.

## Worked Example: Lazy Feature Build with As-Of Fundamentals

```python
from datetime import date
import polars as pl

bars = pl.scan_parquet("md/derived/bars_1m_v3/date=*/*.parquet", hive_partitioning=True)
fund = pl.scan_parquet("md/normalized/fundamentals_pit/*.parquet")  # security_id, filed_at, eps_ttm

LATENCY = pl.duration(milliseconds=500)

features = (
    bars.filter(pl.col("trade_date").is_between(date(2025, 1, 1), date(2025, 12, 31)))
        .sort(["security_id", "ts_close"])
        .with_columns(
            ts_available=pl.col("ts_close") + LATENCY,
            ret_1=(pl.col("close") / pl.col("close").shift(1) - 1).over("security_id"),
            vol_20=pl.col("close").log().diff().rolling_std(window_size=20).over("security_id"),
            dollar_vol_20=(pl.col("notional").rolling_mean(window_size=20)).over("security_id"),
        )
        .join_asof(fund.sort("filed_at"), left_on="ts_available", right_on="filed_at",
                   by="security_id", strategy="backward", tolerance="120d")
        .with_columns(
            # entry at the next bar's open, exit five bars later, both strictly after ts_available
            label=(pl.col("open").shift(-6) / pl.col("open").shift(-1) - 1).over("security_id"),
        )
        .drop_nulls(["label"])
)
out = features.collect(engine="streaming")
```

The label uses opens at offsets `-1` and `-6`, so the first tradable price is the open of the bar after the feature's bar; `tolerance="120d"` turns a fundamental older than the reporting cycle plus lag into a null instead of a stale carry. The `.over("security_id")` window keeps rolling and shift operations from crossing between securities; because the frame is sorted by `ts_close` within security, they also cannot cross backward in time.

## Procedure: Standing Up a Research Dataset

1. Write the specification: grid, universe source, feature list with the inputs each needs, label definition, latency allowance, fill horizons.
2. Confirm every input is a versioned derived or normalized dataset with a manifest.
3. Implement the build as a pure function of inputs and parameters; no wall-clock reads, no network calls.
4. Run on the development sample; hash the output; rerun; hashes must match.
5. Run the truncation test and the shuffled-label test.
6. Run the full build; write the manifest; register the alias.
7. Hand researchers the alias and the loader; keep the hash in every backtest report.

## Checklist

- `ts_event` and `ts_available` on every feature row
- Labels computed only from prices after `ts_available`
- Fill horizons and `age` columns for every filled series; no backfill anywhere
- Universe mask from the point-in-time master
- Rolling windows trailing; no full-sample statistics
- Purging and embargo applied when label windows overlap
- Manifest with input hashes, git SHA, parameters, lockfile hash
- Truncation test and shuffled-label test passing
- Bytes read per build estimated and accepted

## Common Mistakes

- Labeling with the current bar's close and calling the strategy "close-to-close".
- Forward-filling volume, which manufactures liquidity in illiquid names.
- Joining fundamentals by period end.
- Normalizing features with the full-period mean and standard deviation.
- Building the universe from the securities present in the feature file.
- Rebuilding datasets in place under the same name, so last month's backtest cannot be rerun.
- Treating the research layer as the source of truth and fixing data problems there instead of in the layer that caused them.
- Skipping the sample-scale run and debugging on the full universe at full cost.

## Limits

This skill covers data preparation. Execution modeling (fills, slippage, market impact), portfolio construction and statistical validation of results are separate concerns that consume this dataset. A pipeline built this way cannot stop a researcher from peeking; it can make every peek leave a trace in the manifest.)
