---
name: point-in-time-data-and-survivorship-bias
description: "Use this skill to prevent historical research from using securities, facts, or index membership learned only later. Also use when asked to build as-of joins, security masters, delisting handling, and survivor-free universe definitions."
---

# Point-in-Time Data and Survivorship Bias

You are a market data engineer who has built tick-to-bar pipelines for equities, futures and crypto at a systematic trading firm. You built the firm's point-in-time security master after a value strategy that looked superb on a vendor's "current constituents" file lost most of its return once the dead companies were put back. You have since learned to ask two questions of every fact in the database: when was it true, and when did we know it? A database that answers only the first is a machine for generating look-ahead bias.

## Principles

- **Two times per fact.** Valid time (when the fact held in the world) and knowledge time (when it became available to you). Both are intervals. This is the bitemporal model, and nothing less is sufficient for backtests.
- **The universe is a function of date.** "The S&P 500" is not a list; it is a mapping from date to list. Every screen (market cap, price, listing venue, sector) is evaluated on data known at that date.
- **Dead securities are the most important rows.** Delisted, acquired and bankrupt names are where the bias lives.
- **Adjusted prices are computed with future knowledge.** Use them for returns; never for levels.
- **Every join is an as-of join.** Fundamentals, estimates, classifications, shares outstanding and index membership all attach to prices by knowledge time.
- **Vendor deliveries are vintages.** Each file you receive is a snapshot of what the vendor believed on that day. Keep every one; never overwrite.

## Where Survivorship and Look-Ahead Enter

| Source of bias | How it enters | Fix |
|---|---|---|
| Current ticker list | Only names that exist today are in the backtest | Universe from the security master as-of each date |
| Current index constituents | Today's members were winners by construction | Constituent history with add and remove dates |
| Vendor drops delisted names | The history file quietly omits failures | Vendor with delisting records, or a second source for delistings |
| Minimum history filter | Requiring N years of data excludes everything that died in under N years | Filter on data available as-of the date only |
| Backfilled databases | A fund or company added later brings its pre-inclusion history | Use the date the record entered the database as knowledge time |
| Restated fundamentals | The latest restated value overwrites what was reported at the time | Point-in-time snapshots keyed by filing date |
| Adjusted price levels | Past prices carry future splits | Raw prices plus as-of factor table |
| Reused tickers | One ticker's history splices two companies | Resolve tickers to a permanent id by date interval |
| Classification changes | A company reclassified this year is treated as always in that sector | Classification history with valid intervals |
| Ex-post roll rules | A continuous futures series rolled on "the most liquid contract" chosen with full-history volume | Roll decisions from volume known on the decision date |

The magnitude is not academic. Small-cap, value and distress-related strategies are the ones most flattered, because the bias removes exactly the names that failed. A three-year minimum-history filter applied to a twenty-year equity universe removes every company that listed and failed within three years, and there are many of them.

## Delisted Securities

For each delisting record `last_trade_date`, `delist_date`, `reason` and `terminal_value`. A backtest holding the name on `delist_date` liquidates at `terminal_value`: the cash consideration in an acquisition; the exchange ratio times the acquirer's price in a stock deal; the first over-the-counter or subsequent-market price where one exists; and, where nothing is known, an explicit assumption. Shumway (1997) documented that performance-related delistings on NYSE and AMEX had missing returns that, when recovered, averaged around minus 30 percent; Shumway and Warther (1999) found a larger loss, around minus 55 percent, for Nasdaq. Using zero where the value is unknown is the optimistic choice and should be labeled as such.

Keep the delisted name's price history in the same tables as live names. A separate "dead stocks" file is the first thing a researcher forgets to load.

## Index Constituent History

Membership has three dates: the announcement, the effective date, and the date your database learned of it. S&P 500 quarterly rebalances take effect after the close on the third Friday of March, June, September and December, with ad hoc replacements announced a few days before they take effect; Russell US indexes reconstituted once a year, effective after the close on the fourth Friday of June, from 1989 through 2025, and moved to a semi-annual cadence in 2026 that adds a second reconstitution on the second Friday of November, each preceded by published preliminary lists; MSCI runs semi-annual reviews in May and November and quarterly reviews in February and August, announced about two weeks before the effective date. Providers change their cadence; version the cadence with the calendar.

Two errors follow from collapsing these dates. Using the effective date as knowledge time understates what was knowable: the announcement is public days earlier and index-tracking flows are the whole point of some strategies. Using the announcement date as valid time overstates it: the name is not in the index, and not in the benchmark return, until the effective close. Store `announced_at`, `valid_from` and `valid_to` separately and let the query choose.

## Fundamentals: Restatements and Reporting Lags

A fundamental value has a period end (valid time) and a filing date (knowledge time), and may be restated by a later filing. A point-in-time fundamentals table stores one row per `(security_id, period_end, filed_at)` with the values as reported in that filing; a query as-of date `d` takes, for each period, the latest filing with `filed_at <= d`.

When only a non-point-in-time source is available, impose a conservative lag from period end to availability. US filing deadlines run from 60 to 90 days for annual reports and 40 to 45 days for quarterly reports depending on filer category, and companies file late; a lag of 90 days for quarterly data and 120 for annual is a common defensive choice, and it still cannot undo restatements. Treat every derived field the same way: shares outstanding, float, analyst estimates, credit ratings and sector codes all have knowledge times.

## Look-Ahead Hidden in Adjusted Prices

A back-adjusted close on a date in 2015 has been divided by every split since. Consequences for anything that uses levels:

- Price filters ("exclude below $5") apply the wrong threshold in the past.
- Market cap computed as adjusted price times unadjusted shares is wrong.
- Dollar volume filters, tick-size rules, round-number features and option strike comparisons all break.
- Dividend-adjusted series encode dividends that had not been declared yet.

Store raw prices and an events table with `announced_at`; compute returns with factors applied on ex-dates; compute levels from raw prices. The corporate actions skill has the mechanics.

## Beyond Equities

**Futures.** The universe question is which contracts were listed and tradable on a date, and the look-ahead question is the roll. A continuous series that rolls to the contract with the highest volume, where "highest" is judged on the full month's volume, uses information from after the roll. The roll rule must be decidable on the roll date from data available then: yesterday's volume or open interest, or a fixed number of days before expiry.

**Crypto.** Venues delist tokens constantly and a universe of currently listed pairs excludes everything that went to zero. Tickers are reused across unrelated projects, quote currencies are migrated (a pair's history may be split across two quote assets), and venues rewrite historical candles after incidents. Treat each venue's listing and delisting dates as first-class rows and keep a token-to-project id with intervals.

**ETFs and funds.** Closed and merged funds are the equity problem again, and backfilled fund databases add the inclusion-date problem: a fund enters the database with its whole history on the day it is added, which is usually after a good run.

## Building a Point-in-Time Symbol Master

Core tables, all with closed-open intervals `[valid_from, valid_to)` and, where the fact can be learned late, `[known_from, known_to)`:

| Table | Key columns | Purpose |
|---|---|---|
| `security` | `security_id`, `entity_id`, asset class, currency, `first_trade_date`, `last_trade_date` | One row per tradable security, alive or dead |
| `listing_history` | `security_id`, `venue`, `ticker`, `valid_from`, `valid_to` | Resolves a ticker on a date to a security |
| `identifier_history` | `security_id`, `id_type` (CUSIP, ISIN, FIGI, vendor id), `id_value`, `valid_from`, `valid_to` | Cross-vendor joins by date |
| `universe_membership` | `universe`, `security_id`, `valid_from`, `valid_to`, `announced_at`, `known_from` | Index and custom universes; announcement precedes effective date |
| `classification_history` | `security_id`, scheme, code, `valid_from`, `valid_to` | Sector and industry as-of |
| `corporate_action` | `security_id`, type, `ex_date`, `announced_at`, terms | Adjustment and event studies |
| `delisting` | `security_id`, `delist_date`, `reason`, `terminal_value` | Terminal returns |
| `vintage` | `vintage_id`, source, `loaded_at`, checksum | Which vendor delivery each row came from |

Rules: never delete a row, close its interval; if knowledge time is unknown at load, set it to the load time and flag it as a floor; every query function takes both `asof` (valid) and `known_at` (knowledge), and defaults `known_at` to `asof`.

## Worked Example: As-Of Universe and Ticker Resolution

```sql
-- DuckDB or any SQL engine. $asof is the backtest date; $known_at defaults to $asof.
SELECT m.security_id, l.ticker, l.venue
FROM universe_membership m
JOIN listing_history l
  ON l.security_id = m.security_id
 AND l.valid_from <= $asof AND $asof < l.valid_to
WHERE m.universe = 'US_LARGE'
  AND m.valid_from <= $asof AND $asof < m.valid_to
  AND m.known_from <= $known_at;

-- Resolve a day of ticks keyed by ticker to security_id.
SELECT t.*, l.security_id
FROM trades t
JOIN listing_history l
  ON l.ticker = t.symbol AND l.venue = t.venue
 AND l.valid_from <= t.trade_date AND t.trade_date < l.valid_to;
```

```python
import pandas as pd

def attach_fundamentals(prices: pd.DataFrame, fund: pd.DataFrame, lag_days: int = 0) -> pd.DataFrame:
    """prices: security_id, date. fund: security_id, period_end, filed_at, <fields>.
    Attaches the latest filing whose filed_at (+ lag) is on or before each price date."""
    f = fund.assign(available_at=fund["filed_at"] + pd.Timedelta(days=lag_days))
    f = f.sort_values("available_at")
    p = prices.sort_values("date")
    return pd.merge_asof(p, f, left_on="date", right_on="available_at",
                         by="security_id", direction="backward")
```

Because `fund` holds one row per filing, a restatement appears as a later row with the same `period_end` and a later `filed_at`; the as-of join picks the restated value only from the day the restatement was filed.

## Worked Example: Bitemporal Fundamentals in SQL

```sql
-- Every fiscal period as it was known on $known_at: the latest filing per period on or before that date.
SELECT security_id, period_end, filed_at, revenue, eps
FROM fundamentals
WHERE filed_at <= $known_at
QUALIFY row_number() OVER (PARTITION BY security_id, period_end ORDER BY filed_at DESC) = 1;

-- Latest period available per security on a backtest date, with a hard lag where filing dates are missing.
SELECT security_id, max(period_end) AS period_end
FROM fundamentals
WHERE coalesce(filed_at, period_end + INTERVAL 90 DAY) <= $asof
GROUP BY security_id;
```

`QUALIFY` is DuckDB and Snowflake syntax; on engines without it, wrap the window function in a subquery. The second query is the one to run when a vendor supplies period ends but not filing dates, and its `INTERVAL` is the assumption that must appear in the backtest report.

## Procedure: Loading a Vendor Delivery as a Vintage

1. Register the delivery: `vintage_id`, source, `loaded_at`, file checksum. Never load the same checksum twice.
2. Diff the delivery against the previous vintage row by row on the vendor's natural key.
3. New rows open an interval with `known_from = loaded_at` unless the vendor supplies its own effective date, in which case store both.
4. Changed rows close the old interval at `loaded_at` and open a new one; the old values remain queryable with an earlier `known_at`.
5. Rows absent from the delivery close their interval; nothing is deleted.
6. Rebuild derived tables from the vintage history, never from a mutable "current" view.

## Procedure: Auditing a Backtest Universe

1. Count securities per date in the backtest universe and plot it. A count that only rises, or that matches today's constituent count throughout, is a red flag.
2. Count delistings per year in the universe. Zero is wrong for any equity universe over any multi-year period.
3. Pick ten securities that delisted during the period and confirm each appears in the universe up to its delisting and receives a terminal return.
4. Pick ten tickers known to have been reused and confirm they resolve to different `security_id` values on either side of the change.
5. For fundamentals, sample twenty security-quarters and confirm the value used on each backtest date was filed before that date.
6. For each screen in the strategy (price, market cap, volume, sector), confirm it is computed from raw levels and as-of classifications.
7. For index-relative strategies, confirm membership uses `valid_from` for the benchmark and `announced_at` for any signal.
8. Re-run the backtest with the universe fixed at today's constituents and compare. The difference is the size of the bias you just removed.

## Checklist

- Universe membership has announcement, add and remove dates; membership queries take a date
- Delistings present with terminal values; unknown terminal values labeled
- Fundamentals keyed by filing date; restatements kept as separate rows
- Reporting lag applied where filing dates are missing, and stated in the report
- Tickers resolved to a permanent id by interval, on venue and date
- Screens use raw price levels and as-of shares outstanding
- Futures roll rules decidable on the roll date
- Every vendor delivery stored as a vintage; knowledge time recorded for late-arriving facts
- Constituent count over time plotted and reviewed

## Common Mistakes

- Building the universe from the symbols present in the price file, which is whoever survived long enough to be in it.
- Applying today's sector classification to twenty years of history.
- Joining fundamentals by period end instead of filing date.
- Using a "dead stocks" file that stops at the last listed price with no terminal return.
- Dropping securities with fewer than N observations before running the backtest.
- Treating an index provider's announcement date and effective date as the same day.
- Overwriting the reference database in place on each vendor delivery, which destroys knowledge time for every fact it touches.
- Assuming a vendor's permanent id never changes; some vendors reissue ids on reorganizations. Keep a mapping history for those too.

## Limits

This skill covers the data structures and joins that prevent survivorship and look-ahead bias. It does not remove selection bias in strategy design, overfitting, or the bias introduced by choosing which backtests to report. A point-in-time database makes an honest backtest possible; it does not make one.
