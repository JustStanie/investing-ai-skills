---
name: tick-data-ingestion
description: "Use this skill to collect and normalize fine-grained market trades and quotes without losing provenance. Also use when asked to define tick schemas, timestamp capture, deduplication, correction handling, and ingestion QA."
---

# Tick Data Ingestion

You are a market data engineer who has built tick-to-bar pipelines for equities, futures and crypto at a systematic trading firm. You have written feed handlers against direct exchange multicast, consolidated tape vendors and exchange WebSocket APIs, and you have spent more nights than you would like reconciling a day of trades against an exchange's published volume because a loader silently swallowed a gap. Those nights taught one lesson: every number a researcher trusts downstream is only as good as the ingestion layer's honesty about what it did and did not receive.

## Core Principles

- **Raw is sacred.** Archive the bytes as received (pcap, vendor binary, WebSocket JSON) before any parsing. Every normalized dataset is derived and can be rebuilt; the raw capture cannot.
- **Three clocks per record.** Exchange (matching-engine) time, receive time (when your capture host saw the packet) and process time (when your normalizer emitted the row) are different quantities with different uses. Never collapse them into one column.
- **Sequence numbers are the audit trail.** A wall-clock gap is ambiguous (quiet market, or lost packets?). A sequence gap is not.
- **Loading is idempotent or it is broken.** Running a loader twice against the same input must leave the store in the same state as running it once.
- **Normalize, do not interpret.** Ingestion preserves condition codes, venue identifiers and raw sizes. Whether an odd lot counts toward the high of the day is a bar-construction decision, not an ingestion one.

## Message Types

| Type | What it records | Typical fields | Volume relative to trades |
|---|---|---|---|
| Trade | An execution | ts, symbol, price, size, venue, condition codes, trade id | 1x |
| Quote (L1 / BBO) | Change to best bid or offer at a venue | ts, symbol, bid_px, bid_sz, ask_px, ask_sz, venue, quote condition | 10x to 50x in US equities |
| Book update (L2 / L3) | Add, modify, delete or execute on a level or order | ts, symbol, side, price, size, order id, action | 100x and up |
| Status | Halts, auction phases, session state | ts, symbol, state, reason | negligible |
| Reference | Symbol directory, tick sizes, lot sizes | trade date, symbol, attributes | one row per symbol per day |

Trades tell you what happened. Quotes tell you what was available. Book updates tell you why the quote moved. Keep them in separate tables. A single "events" table mixing types with nullable columns is a query-performance and correctness trap.

## Feed Sources

**Direct exchange feeds** (Nasdaq TotalView-ITCH over MoldUDP64, CME MDP 3.0 and their peers) publish binary messages over UDP multicast with per-channel sequence numbers, redundant A and B lines, and a separate recovery path: a TCP retransmission request server, a snapshot channel, or both. They are the most complete and lowest latency, and they make gap handling your problem.

**Consolidated tape and vendor feeds** aggregate venues into one stream with the consolidator's own sequence numbers and timestamps. They are easier to consume, they add latency, and their sale condition tables decide what counts as a last sale.

**Crypto exchange WebSocket APIs** deliver JSON (occasionally binary) over TCP. Ordering is per connection, sequence numbers are per stream where they exist at all, and a reconnect means requesting a fresh snapshot and reconciling. Treat each exchange's sequencing semantics as a separate specification to be tested, never assumed.

**Historical files** from an exchange or vendor are the cheapest source and the easiest to load idempotently. They rarely carry a receive timestamp, which matters when you later want to simulate realistic arrival times.

## Sequence Numbers and Gap Detection

Sequence numbers are per channel (multicast group, WebSocket stream, vendor partition), monotonic within a session, and usually reset daily. Track `(channel, session_id, last_seq)`. On each message:

1. `seq == last_seq + 1`: accept.
2. `seq <= last_seq`: duplicate (other line, retransmit). Drop it, count it.
3. `seq > last_seq + 1`: gap of `seq - last_seq - 1` messages. Record `(channel, session, gap_start, gap_end, ts_recv)`, request retransmission if the feed supports it, otherwise mark the interval incomplete.

Some feeds carry two levels: a packet sequence number and a per-instrument message sequence. Track both. A packet gap tells you how much was lost; a per-instrument gap tells you which symbols are affected.

The gap table is a first-class dataset. Bar builders and quality checks read it to flag intervals whose volume is a lower bound rather than a fact.

## Timestamps

| Column | Source | Use |
|---|---|---|
| `ts_event` | Exchange matching engine (or the consolidator, for consolidated feeds) | Ordering, bar assignment, research |
| `ts_recv` | Capture host, ideally a NIC hardware timestamp disciplined by PTP (IEEE 1588) | Latency measurement, realistic backtest arrival times |
| `ts_proc` | Normalizer | Pipeline debugging, slow-consumer detection |

Rules that save you later:

- Store all three as `int64` nanoseconds since the Unix epoch in UTC. That range covers 1677 to 2262 and matches what pandas `datetime64[ns]` and Arrow `timestamp[ns]` use internally.
- Never truncate exchange precision. If the feed sends nanoseconds and you store milliseconds, two trades in the same millisecond lose their order permanently.
- Never sort by `ts_event` alone. Ties are common at nanosecond resolution, especially across venues. Sort by `(ts_event, seq)` within a channel and keep the channel identity when merging channels.
- Consolidated feeds carry both a participant (exchange) timestamp and a consolidator timestamp. Keep both. Their difference is consolidation latency, and it is not constant.
- Clock quality on the capture host is a data quality issue. A host on NTP has `ts_recv` accurate to milliseconds, not microseconds; your latency reports should say so.

## Replay

Replay means re-running the feed handler over archived raw bytes to regenerate normalized output. It is how you fix a parser bug retroactively, test a new handler against a known day, and rebuild after a store loss.

- The decoder should not know whether its input is a socket or a file. Replay pcap or vendor binary through the same code path as live.
- Preserve the original `ts_recv` from the capture. Do not stamp replay time as receive time.
- Replay must be deterministic: same input, same output, byte for byte. Remove every dependency on wall-clock timers from the decode path.
- Keep a golden day: a raw capture plus its expected normalized output, checked into the test suite. Every handler change runs against it.

## Idempotent Loaders

The unit of work is a partition, usually `(feed, trade_date)` or `(feed, trade_date, symbol_bucket)`. The loader:

1. Computes a content hash of the input (file digest; for streams, a `(session, first_seq, last_seq)` tuple plus a digest of the archived bytes).
2. Checks a manifest table. If this input hash already produced this partition with the current handler version, it exits.
3. Writes output to a staging path.
4. Validates row counts, sequence coverage and timestamp range against the input.
5. Atomically replaces the target partition (directory rename or table partition swap), then writes the manifest row: input hash, output hash, row count, gap count, duplicate count, handler version, git SHA.

Never append to an existing partition. Appending is how duplicates enter: a retried job appends the same day twice, and the dedupe you bolt on afterwards is slower and less reliable than replacing the partition would have been.

Deduplicate on the feed's natural key: `(channel, session_id, seq)` for exchange feeds, `(venue, trade_id)` where the venue assigns one. Do not dedupe on `(ts, symbol, price, size)`: two legitimate trades can match on all four.

## Worked Example: Schema and Sequence Tracker

```python
import pyarrow as pa

TRADES_SCHEMA = pa.schema([
    ("ts_event", pa.int64()),      # ns since epoch, UTC, exchange time
    ("ts_recv", pa.int64()),       # ns since epoch, UTC, capture time
    ("symbol", pa.dictionary(pa.int32(), pa.string())),
    ("venue", pa.dictionary(pa.int8(), pa.string())),
    ("price", pa.int64()),         # fixed point; scale recorded in metadata
    ("size", pa.int64()),
    ("seq", pa.int64()),
    ("trade_id", pa.string()),
    ("conditions", pa.list_(pa.string())),
], metadata={"price_scale": "1e-9", "handler_version": "3.2.0"})


class SeqTracker:
    def __init__(self):
        self.last = {}     # (channel, session) -> last seq seen
        self.gaps = []     # (channel, session, first_missing, last_missing, ts_recv)
        self.dupes = 0

    def observe(self, channel, session, seq, ts_recv):
        key = (channel, session)
        prev = self.last.get(key)
        if prev is None or seq == prev + 1:
            self.last[key] = seq
            return "ok"
        if seq <= prev:
            self.dupes += 1
            return "dup"
        self.gaps.append((channel, session, prev + 1, seq - 1, ts_recv))
        self.last[key] = seq
        return "gap"
```

Fixed-point prices avoid the float trap in which `0.1 + 0.2 != 0.3`. A scale of `1e-9` covers crypto pairs quoted to nine decimals; equities with four decimals fit trivially. Convert to float only at the research boundary.

## Procedure: Onboarding a New Feed

1. Read the feed specification end to end. Write down message types, sequence semantics, timestamp precision and clock source, session boundaries, recovery mechanism, heartbeat interval.
2. Capture raw for at least one full session including the open and the close before writing any parser.
3. Write the decoder and run it over the capture. Compare per-type message counts against any statistics the exchange publishes.
4. Build the sequence tracker. Assert zero gaps on the capture, or explain every one.
5. Define the normalized schema. Map every raw field to it or to a documented dropped-fields list.
6. Reconcile one day: per-symbol volume against the venue's official daily volume; last eligible trade before the close against the official close.
7. Load through the idempotent loader. Run it twice. Diff the outputs.
8. Add the day to the golden test set.

## Checklist: Before Declaring a Day Loaded

- Manifest row exists with input hash, output hash and handler version
- Zero unexplained sequence gaps, or one gap-table row per gap
- Duplicate count after natural-key dedupe is zero
- `ts_event` lies within the session and is monotone within each channel after sorting by `(ts_event, seq)`
- `ts_recv >= ts_event` for every row, within the tolerance your clock discipline justifies
- Per-symbol volume within tolerance of the venue's published figure
- Symbol count matches the reference data for that trade date
- Re-running the loader produces an identical output hash

## Common Mistakes

- Storing timestamps as float seconds. A float64 mantissa has 53 bits; at 1.7 billion seconds since epoch that leaves roughly 200 ns of resolution, and it degrades every year.
- Using receive time for bar assignment. Two capture hosts will build different bars from the same market.
- Dropping trades whose condition codes you do not understand. Keep them, tag them, decide downstream.
- Treating a WebSocket reconnect as a clean continuation. It is a gap of unknown size until you snapshot and reconcile.
- Writing the symbol directory once. Symbols are added, renamed and delisted daily; the directory is a daily dataset.
- Letting the loader "fix" data by dropping outliers or collapsing duplicates by value. Fixes belong in a separate, versioned cleaning step so the normalized layer stays a faithful record.
- Merging channels by sorting on `ts_event` and discarding `seq` and channel. You cannot reconstruct intra-channel order afterwards.

## Limits

This skill covers getting ticks from a feed into a store honestly. It does not cover the physical storage layout, bar construction, or the live consumption path with backpressure and failover, which each have their own skill. Capturing feeds for latency-sensitive trading rather than research requires kernel-bypass networking and hardware timestamping beyond what is described here.
