---
name: trading-calendars-and-timezones
description: "Use this skill to apply correct market-session, holiday, daylight-saving, and contract timing rules. Also use when asked to build exchange calendars, align cross-market data, and prevent timestamp look-ahead."
---

# Trading Calendars and Timezones

You are a market data engineer who has built tick-to-bar pipelines for equities, futures and crypto at a systematic trading firm. You have debugged a four-hour-fifty-six-minute offset that came from a timezone object used the wrong way, a bar builder that produced a 09:00 bar for two weeks every March, and a futures loader that filed Sunday evening's trades under Sunday. None of these were exotic. They are what happens whenever time is treated as a number instead of as a session.

## Principles

- **Store UTC, reason in exchange-local.** Every stored timestamp is `int64` nanoseconds UTC. Session logic (open, close, breaks, trade date) runs in the exchange's IANA timezone, never a fixed offset.
- **Trade date is not calendar date.** A futures session that opens Sunday evening belongs to Monday. A bar's trade date is a column derived from the session, not from the timestamp's date part.
- **The calendar is a dataset.** Exchanges announce unscheduled closures, special sessions and permanent hour changes. Version the calendar and record which version built each dataset.
- **Every dataset declares its session.** "Daily bars" without a session definition is not a dataset; it is a guess.
- **Venues are aligned on UTC and interpreted per venue.** A cross-venue feature is computed on a UTC grid with a session mask per venue, never by shifting one venue's local clock onto another's.
- **Test the transitions.** Two DST weekends, every holiday, every half day and the year boundary are the test cases. If the pipeline works on a normal Tuesday it has proven nothing.

## Sessions by Asset Class

| Venue | Timezone (IANA) | Regular session (local) | Notes |
|---|---|---|---|
| NYSE, Nasdaq | `America/New_York` | 09:30 to 16:00 | Pre-market from 04:00, post-market to 20:00; half days close 13:00 |
| London Stock Exchange | `Europe/London` | 08:00 to 16:30 | Closing auction follows 16:30; 12:30 close on Christmas Eve and New Year's Eve |
| Tokyo Stock Exchange | `Asia/Tokyo` | 09:00 to 11:30, 12:30 to 15:30 | Lunch break; afternoon close moved from 15:00 to 15:30 in November 2024 |
| Hong Kong Exchanges | `Asia/Hong_Kong` | 09:30 to 12:00, 13:00 to 16:00 | Lunch break; severe-weather closures were unscheduled until the exchange began trading through them in 2024 |
| Shanghai, Shenzhen | `Asia/Shanghai` | 09:30 to 11:30, 13:00 to 15:00 | Lunch break; multi-day closures around Lunar New Year and National Day |
| CME Globex equity index | `America/Chicago` | 17:00 to 16:00 next day, Sunday to Friday | Maintenance 16:00 to 17:00; halt 15:15 to 15:30 Monday to Thursday; settlement window ends 15:15 |
| CME rates, NYMEX energy, CME crypto | `America/Chicago` | 17:00 to 16:00 next day, Sunday to Friday | Same shape as equity index; product-specific settlement windows |
| CBOT grains | `America/Chicago` | 19:00 to 07:45, then 08:30 to 13:20 | Overnight and day segments; settlement at the day close |
| Crypto spot and perpetuals | UTC by convention | 24 hours, 7 days | Daily boundary 00:00 UTC on most venues; perpetual funding commonly every 8 hours; maintenance windows |

US equity holidays: New Year's Day, Martin Luther King Jr. Day, Presidents' Day, Good Friday, Memorial Day, Juneteenth, Independence Day, Labor Day, Thanksgiving, Christmas, with weekend holidays observed on the adjacent weekday. Half days: the day after Thanksgiving, Christmas Eve when it falls Monday to Thursday (a Friday 24 December is the observed Christmas holiday and a full closure), and 3 July in years when it precedes a weekday Independence Day. In 2026, Independence Day is a Saturday, so Friday 3 July 2026 is a full holiday; Thanksgiving is 26 November 2026 and the following Friday closes at 13:00. Good Friday is not a federal holiday, the bond market keeps different holidays and early closes from equities, and CME equity index futures typically trade with an early close on several equity holidays. Do not share a calendar across asset classes, even for the same underlying.

## Trade Date versus Calendar Date

For equities the trade date is the local calendar date and extended-hours prints belong to the same date. For nearly-24-hour futures the session straddles midnight and the trade date is the date on which the session *closes*. For crypto the trade date is the UTC date by convention, and any other convention must be stated.

The robust method is an interval join against a session table rather than arithmetic on the timestamp:

```python
import polars as pl

sessions = pl.DataFrame({          # from the versioned calendar; CME equity index, CDT = UTC-5
    "trade_date": ["2026-09-15", "2026-09-16"],
    "open_utc":   ["2026-09-14 22:00:00", "2026-09-15 22:00:00"],
    "close_utc":  ["2026-09-15 21:00:00", "2026-09-16 21:00:00"],
}).with_columns(pl.col("open_utc", "close_utc").str.to_datetime(time_zone="UTC")).sort("open_utc")

def assign_trade_date(ticks: pl.DataFrame) -> pl.DataFrame:
    return (
        ticks.sort("ts_event")
        .join_asof(sessions, left_on="ts_event", right_on="open_utc", strategy="backward")
        .filter(pl.col("ts_event") < pl.col("close_utc"))   # drops maintenance-window noise
    )
```

Ticks that fall between a close and the next open are outside any session. Count them; a nonzero count during a supposed maintenance window means either the calendar or the feed is wrong.

## Daylight Saving Time

- United States: second Sunday of March to first Sunday of November (8 March and 1 November in 2026).
- United Kingdom and European Union: last Sunday of March to last Sunday of October (29 March and 25 October in 2026).
- Japan, China, Hong Kong, Singapore, India: no DST.
- Australia (Sydney): first Sunday of October to first Sunday of April, the opposite direction.

The US and European transitions do not coincide, so for three weeks each spring and one week each autumn the London-to-New York offset is four hours instead of five. The US equity open moves between 13:30 UTC and 14:30 UTC. A bar grid fixed in UTC drifts against the session twice a year; an "hours since open" feature computed in UTC is wrong for half the year; a cross-venue overlap window has to be computed from both calendars, not hard-coded. CME hours are defined in Central time, so Globex opens shift in UTC on the US date while Eurex and London shift three weeks later.

Because storage is UTC, the transitions are invisible in the store and appear only in session logic, which is where they belong. Ambiguous local times (01:30 on the fall-back Sunday occurs twice) and nonexistent ones (02:30 on the spring-forward Sunday) matter only when you construct local times; equity sessions never include those hours, but 24-hour markets do, and a futures Sunday-evening open in local time is constructed on exactly those days.

## Aligning Venues

Two venues never share a clock; they share UTC. Alignment is four decisions, each recorded with the dataset:

1. Put every venue's ticks and bars on the UTC grid with its own `trade_date` from its own session table.
2. Build a session mask per venue: for each grid point, is the venue in regular session, in a break, in extended hours, or closed.
3. Compute the overlap window per day as the intersection of the venues' session intervals.
4. Decide the rule outside the overlap: no cross-venue feature, or carry the last value with an explicit age column that the model can see.

The London-to-New York overlap in 2026 illustrates why step 3 is computed rather than typed:

| Period | London regular session (UTC) | New York regular session (UTC) | Overlap |
|---|---|---|---|
| Winter, both on standard time | 08:00 to 16:30 | 14:30 to 21:00 | 14:30 to 16:30 (2 h) |
| 8 to 28 March, US on DST only | 08:00 to 16:30 | 13:30 to 20:00 | 13:30 to 16:30 (3 h) |
| Summer, both on DST | 07:00 to 15:30 | 13:30 to 20:00 | 13:30 to 15:30 (2 h) |
| 25 to 31 October, US on DST only | 08:00 to 16:30 | 13:30 to 20:00 | 13:30 to 16:30 (3 h) |

```python
def overlap_windows(a: pl.DataFrame, b: pl.DataFrame) -> pl.DataFrame:
    """a, b: trade_date, open_utc, close_utc for two venues. Pairing on trade_date is itself a
    choice; a CME Monday session starts on Sunday evening UTC and a Tokyo Monday is already over."""
    j = a.join(b, on="trade_date", how="inner", suffix="_b")
    return (
        j.with_columns(
            pl.max_horizontal("open_utc", "open_utc_b").alias("ov_start"),
            pl.min_horizontal("close_utc", "close_utc_b").alias("ov_end"),
        )
        .filter(pl.col("ov_start") < pl.col("ov_end"))
        .select("trade_date", "ov_start", "ov_end")
    )
```

Cases that recur:

- **Futures against the cash index.** The cash session is 09:30 to 16:00 New York; the future trades almost round the clock. The future's overnight move is a feature the cash series cannot supply, and the cash open is the moment the two become comparable. Never forward-fill the cash index across the night and call the difference a basis.
- **CME crypto futures against spot.** The future is closed from Friday 16:00 to Sunday 17:00 Chicago time; spot trades through the weekend. An as-of join carries Friday's futures price against Saturday's spot and produces a fictional basis; mask it.
- **Cross-listed shares.** Session and currency both differ. Convert with an FX rate timestamped inside the overlap, not the day's fixing.
- **Asia against the Americas.** There is no overlap. The only computable relation is "previous session", and it must come from the session table: the previous Tokyo session before a New York open is not "yesterday" on a Tuesday after a Japanese holiday.

## Worked Example: Timezone Handling in Python

```python
from datetime import datetime
from zoneinfo import ZoneInfo
import pandas as pd
import polars as pl
import exchange_calendars as xcals

NY = ZoneInfo("America/New_York")
UTC = ZoneInfo("UTC")

# 2026-03-08 is the spring-forward Sunday in the US.
friday_open = datetime(2026, 3, 6, 9, 30, tzinfo=NY).astimezone(UTC)   # 14:30 UTC
monday_open = datetime(2026, 3, 9, 9, 30, tzinfo=NY).astimezone(UTC)   # 13:30 UTC

# pandas: localize a naive local time, then convert; never the other way round.
idx = pd.DatetimeIndex(["2026-11-01 01:30"]).tz_localize(NY, ambiguous="NaT")          # fall-back day
gap = pd.DatetimeIndex(["2026-03-08 02:30"]).tz_localize(NY, nonexistent="shift_forward")
utc_idx = pd.DatetimeIndex(["2026-11-01 05:30"], tz="UTC").tz_convert(NY)

# polars: stored UTC column, local display column derived, never stored.
df = pl.DataFrame({"ts_event": [monday_open]}).with_columns(
    pl.col("ts_event").dt.convert_time_zone("America/New_York").alias("ts_local")
)

# exchange_calendars: sessions and UTC open/close for XNYS.
cal = xcals.get_calendar("XNYS")
assert not cal.is_session("2026-07-03")                   # observed Independence Day
sched = cal.schedule.loc["2026-11-23":"2026-11-27"]        # includes the 13:00 close on 27 Nov
nxt = cal.next_session("2026-07-02")                       # 2026-07-06
```

The `pytz` trap: `datetime(..., tzinfo=pytz.timezone("America/New_York"))` attaches the zone's earliest historical offset, local mean time of minus 4 hours 56 minutes. `pytz` requires `tz.localize(naive_dt)`. `zoneinfo` (standard library since Python 3.9) does not have this problem and should be the default.

## Session-Relative Features

Once ticks carry `open_utc` and `close_utc` from the interval join, time-of-day features are arithmetic on those columns and are DST-proof by construction:

```python
def session_features(ticks: pl.DataFrame, bar_ns: int = 5 * 60 * 10**9) -> pl.DataFrame:
    since_open = pl.col("ts_event") - pl.col("open_utc")
    return ticks.with_columns(
        (since_open.dt.total_seconds() / 60).alias("min_since_open"),
        ((pl.col("close_utc") - pl.col("ts_event")).dt.total_seconds() / 60).alias("min_to_close"),
        (since_open.dt.total_nanoseconds() // bar_ns).alias("bar_idx"),   # 0-based bar within the session
    )
```

A bar index anchored on the session open gives 78 five-minute bars on a full NYSE day and 42 on a 13:00 half day, and the first bar is always the opening bar regardless of what UTC says.

## Calendar Libraries and Their Traps

`exchange_calendars` (codes such as `XNYS`, `XLON`, `XHKG`, `XTKS`) and `pandas_market_calendars` (names such as `NYSE`) both encode holiday rules and early closes. Things that go wrong:

- **Column names differ.** One library's schedule exposes `open` and `close`; the other's exposes `market_open` and `market_close`. Both have renamed columns across major versions. Pin versions and wrap the library behind your own session table.
- **Session labels changed type across versions** (tz-aware UTC midnight in older releases, naive dates in newer ones). Comparisons that used to work silently stop matching.
- **Rules are code, updated by release.** An exchange announcing a new holiday, an unscheduled closure or a permanent hours change is not reflected until someone ships a release and you upgrade. Diff the library against the exchange's published calendar every year and keep an override table.
- **Late opens and special sessions** are poorly modeled; early closes are handled, delayed opens usually are not.
- **Futures calendars** in these libraries model hours but not always the trade-date rollover or product-specific halts. Verify against the exchange's contract specification for each product you trade.
- **Lunch breaks** exist in Tokyo, Hong Kong, Shanghai and others. A bar builder that ignores `break_start` and `break_end` produces a 90-minute bar over lunch.
- **Leap seconds** exist in UTC; Unix time and every feed you will meet ignore or smear them. Do not try to model them.

## Procedure: Building the Session Table

1. Choose a source of truth per venue: the exchange's published calendar, cross-checked against a library.
2. Generate `(venue, trade_date, open_utc, close_utc, break_start_utc, break_end_utc, is_half_day, calendar_version)` for the full history and one year forward.
3. Add an override table for unscheduled closures and special sessions, with the announcement date.
4. Regenerate the table on every library upgrade and every override; diff against the previous version and review every changed row.
5. Assign trade dates to ticks and bars by interval join; store `trade_date` as a column.
6. Add tests for both DST weekends, every holiday, every half day and the year boundary for every venue.

## Procedure: Testing Session Logic

1. Build a fixture list per venue: both local DST transition dates, every holiday and observed holiday, every half day, 31 December and 1 January, a leap day, and for futures a Sunday-evening open.
2. For each fixture, assert the first and last bar timestamps equal the session's `open_utc` and `close_utc` minus one bar.
3. Assert the bar count per session: 390 one-minute bars on a full NYSE day, 210 on a 13:00 close.
4. Assert zero ticks assigned to a non-session interval, and count ticks in breaks and maintenance windows separately.
5. Assert `trade_date` is non-decreasing in `ts_event` order within a symbol and venue.
6. Keep the generated session table as a golden file; a library upgrade that changes any row fails the build until the diff is reviewed.

## Checklist

- All stored timestamps `int64` ns UTC; local time is a derived display column
- Every dataset names its venue, session definition and calendar version
- `trade_date` assigned by session interval, never by `ts.date()`
- IANA zone names throughout; no `EST`, `EDT`, `CST` or fixed offsets
- `zoneinfo` or correctly localized `pytz`; grep the codebase for `tzinfo=pytz`
- Cross-venue features computed from both calendars with an explicit outside-overlap rule
- Tests cover both DST transitions, the half days and a Sunday futures open

## Common Mistakes

- Filtering "regular session" with a fixed UTC window, which is wrong for half the year.
- Using `ts.date()` on a UTC timestamp for a futures or Asian-session trade date.
- Storing the schedule in local time and then converting with a fixed offset.
- Resampling daily bars from UTC midnight for equities, splitting the US after-hours session across two days.
- Forward-filling a closed venue's last price into another venue's live session and computing a spread from it.
- Assuming crypto venues agree on when a day starts; some report daily candles in local time and reference rates fix at their own hours.
- Assuming the bond market and the equity market share holidays.
- Upgrading a calendar library without diffing the generated sessions.

## Limits

This skill covers session logic for market data pipelines. Settlement calendars for cash flows, options expiration calendars, and the holiday conventions of interest rate products (modified following, end-of-month) are related but separate. When an exchange and a library disagree, the exchange is right, and the override table exists to record that.
