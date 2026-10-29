---
name: order-book-data
description: "Use this skill to reconstruct, store, and analyze limit order books from snapshots and incremental feeds. Also use when asked to design L2/L3 book builders, detect sequence gaps, derive spread and depth features."
---

# Order Book Data

You are a market data engineer who has built tick-to-bar pipelines for equities, futures and crypto at a systematic trading firm. You have rebuilt full-depth order-by-order books for a US equity venue from its raw multicast archive, kept crypto perpetual books synchronized across reconnects on venues whose sequencing rules were documented in a forum post, and sized the storage for both. The book is the most information-dense dataset you will handle and the easiest to get subtly wrong, because a single missed delta corrupts every snapshot after it.

## Principles

- **The book is state; the feed is transitions.** Store the transitions plus periodic checkpoints. Derive state by replay. Never store only the state.
- **Reconstruction is a pure function.** Given a snapshot and a contiguous sequence of deltas, two implementations must produce identical books. Test that property.
- **Depth beyond what you use is cost.** Decide the research depth and the sampling scheme deliberately; full-depth storage for everything is a budget, not a default.
- **Books from different venues share no clock.** A consolidated view is a model with a latency assumption, not an observation.
- **Every book carries its sequence number.** A snapshot without the sequence number it corresponds to cannot be extended with deltas.

## Levels of Book Data

| Level | Also called | Content | Per-message fields | Relative volume |
|---|---|---|---|---|
| L1 | Top of book, BBO, MBP-1 | Best bid and ask price and size | ts, bid_px, bid_sz, ask_px, ask_sz | 10x to 50x trades |
| L2 | Market by price, MBP-N | Aggregate size at each of the top N price levels per side | ts, side, price, size (absolute), level | Several times L1 for N = 10 |
| L3 | Market by order, MBO, full depth | Every order: add, modify, cancel, execute, with order id | ts, order_id, side, price, size, action | Hundreds of millions of messages per day for a large venue |

L1 answers "what is the spread." L2 answers "how much is resting near the touch." L3 answers "who is ahead of me in the queue and how did the queue evolve." L2 can be derived from L3; the reverse is impossible.

## Snapshots and Incremental Updates

A snapshot is the full state at sequence `S`. Incremental updates carry sequence numbers and must be applied in order starting from `S + 1`. The synchronization procedure, which crypto venues that use a REST snapshot plus a WebSocket delta stream make explicit, is:

1. Subscribe to the delta stream first and buffer everything.
2. Fetch the snapshot; note its sequence number `S`.
3. Discard buffered deltas whose final sequence is `<= S`.
4. The first delta applied must cover `S + 1` (its sequence range must start at or before `S + 1` and end at or after it). If no buffered delta does, fetch a new snapshot.
5. Every subsequent delta must start exactly where the previous one ended. A gap means resynchronize from step 2.

Multicast exchange feeds follow the same shape with a dedicated snapshot channel that cycles through instruments continuously; you join the incremental channel, wait for the snapshot of each instrument, then apply buffered increments with higher sequence numbers.

Delta semantics vary and must be read from the specification: most crypto L2 feeds send the new absolute size at a price level, with zero meaning remove; some send the change in size; L3 feeds send order-level actions. Applying an absolute-size delta as a change, or vice versa, produces a book that looks plausible and is wrong.

## Worked Example: L2 Book Maintenance

```python
from dataclasses import dataclass, field

@dataclass
class L2Book:
    """Prices as integer ticks; sizes as integers. Absolute-size deltas."""
    bids: dict = field(default_factory=dict)   # price_ticks -> size
    asks: dict = field(default_factory=dict)
    seq: int = -1

    def load_snapshot(self, seq, bids, asks):
        self.bids = {p: s for p, s in bids if s > 0}
        self.asks = {p: s for p, s in asks if s > 0}
        self.seq = seq

    def apply(self, first_seq, last_seq, bids, asks):
        if self.seq < 0 or first_seq > self.seq + 1:
            raise RuntimeError(f"gap: have {self.seq}, delta starts {first_seq}")
        if last_seq <= self.seq:
            return                                  # stale or duplicate delta
        for book, updates in ((self.bids, bids), (self.asks, asks)):
            for price, size in updates:
                if size == 0:
                    book.pop(price, None)
                else:
                    book[price] = size
        self.seq = last_seq

    def top(self, n=10):
        bids = sorted(self.bids.items(), reverse=True)[:n]
        asks = sorted(self.asks.items())[:n]
        return bids, asks

    def is_crossed(self):
        return bool(self.bids) and bool(self.asks) and max(self.bids) >= min(self.asks)
```

For L3, keep `orders: order_id -> (side, price, size)` and derive levels by summing; an execute reduces the order's size and removes it at zero, a replace deletes the old id and adds the new one, and a cancel may be partial. Assert after every message that no size is negative and no level is empty but present.

For production handlers replace the dicts and sorts with arrays indexed by price tick around the touch; the structure above is for correctness tests and research replay.

## Crossed and Locked Books

A **locked** book has best bid equal to best ask; a **crossed** book has best bid above best ask.

- Within a single venue's continuous session, a crossed book means you missed or misapplied a message. Resynchronize; do not trade on it.
- During pre-open and auction phases a single-venue book is legitimately crossed; the venue publishes an indicative price and the crossing is the auction's imbalance. Tag the phase from the status feed.
- Across venues, the consolidated best bid and offer lock or cross transiently because venues have different latencies to you. Regulation forbids posting quotes that lock or cross protected quotes, but data still shows it for milliseconds at a time.
- Store `is_locked` and `is_crossed` flags at sample time. Exclude flagged samples from spread and microprice features. Never "repair" a crossed book by swapping sides or dropping a level.

## Depth-Derived Features

With `b1, a1` the best bid and ask, `bs_k, as_k` the sizes at level `k`:

| Feature | Formula | Notes |
|---|---|---|
| Mid | `(b1 + a1) / 2` | Undefined when crossed or one-sided |
| Spread | `a1 - b1`, or in basis points `(a1 - b1) / mid * 1e4` | Compare in ticks across symbols |
| Microprice | `(a1 * bs_1 + b1 * as_1) / (bs_1 + as_1)` | Size-weighted mid; leans toward the side with less resting size |
| L1 imbalance | `(bs_1 - as_1) / (bs_1 + as_1)` | In `[-1, 1]` |
| Depth-k imbalance | Same with sums over levels 1 to k | Less noisy, slower |
| Depth within x bps | Sum of sizes with price within `x` bps of mid, per side | Comparable across symbols |
| Order flow imbalance | Net change in bid depth minus net change in ask depth at the touch over an interval | Cont, Kukanov and Stoikov (2014), *The Price Impact of Order Book Events* |
| Queue position | Size ahead of your order at its price level | Requires L3 or a queue model |

Compute features from the book state as it was immediately before each trade when studying impact, and from sampled snapshots when building panels; mixing the two conflates event time with clock time.

## Storage Volume Arithmetic

Estimate before capturing. Rows per day multiplied by compressed bytes per row, per symbol, per venue.

- **L1 quotes**, US equities, consolidated: billions of updates per day across the market; a liquid single name runs to millions. Around 15 to 25 compressed bytes per row.
- **L2 top-10 deltas**: several times L1 message count; each delta is small.
- **L3 / MBO**, one large US equity venue: hundreds of millions of messages per day, tens of gigabytes uncompressed. Compresses well because order ids and prices are sequential and clustered.
- **Crypto**: a single major pair on a large venue produces millions of L2 deltas per day; a venue with a thousand perpetual pairs produces billions.

A wide top-10 snapshot row (10 levels, two sides, price and size) is 40 numeric columns, about 320 bytes raw and 50 to 80 bytes after columnar compression. Sampled once per second over a 6.5-hour session that is 23,400 rows and roughly 1.5 MB per symbol per day; 3,000 symbols is around 4.5 GB per day. Deltas plus hourly checkpoints for the same universe cost more to store and far more to query, but preserve everything.

## Sampling Strategies

| Strategy | What is stored | Good for | Bias to remember |
|---|---|---|---|
| Fixed interval snapshots (100 ms, 1 s) | Top-N wide rows on a clock | Panels, cross-sectional features | Undersamples the open and news bursts |
| Event-driven snapshots | Top-N whenever the BBO changes | Microstructure, spread dynamics | Oversamples volatile periods; row count varies by symbol |
| Pre-trade snapshots | Book state immediately before each trade | Impact, fill and slippage models | Conditioned on trade arrival |
| Deltas plus checkpoints | Every update, full snapshot every hour or every N messages | Exact replay, queue models, simulators | Highest cost; queries need reconstruction |
| Top-of-book only | L1 stream | Spreads, quote-based bars | Loses depth entirely |

Store deltas plus checkpoints for the instruments where queue-level questions matter and sampled wide snapshots for the rest. Both layouts carry `seq`, `ts_event`, `ts_recv`, `is_crossed`, `is_locked` and the session phase.

Wide snapshot schema: `ts_event, ts_recv, seq, symbol, venue, phase, bid_px_00 .. bid_px_09, bid_sz_00 .. bid_sz_09, ask_px_00 .. ask_px_09, ask_sz_00 .. ask_sz_09, bid_ct_00 .. (order counts, if available)`. Missing levels are null, never zero.

## Procedure: Standing Up Book Capture for a New Venue

1. Read the specification for snapshot semantics, delta semantics (absolute or change), sequence rules, and phase indicators.
2. Capture raw for a full session including the open auction.
3. Implement the book; replay the capture; assert never crossed during continuous trading and assert `top(1)` matches the venue's L1 feed at every timestamp if one exists.
4. Reconstruct from a mid-session checkpoint and compare against reconstruction from the open; the books must be identical at every subsequent sequence.
5. Choose depth and sampling per instrument tier; write the cost estimate.
6. Emit sampled snapshots and checkpoints through the idempotent loader; include the gap table.

## Checklist

- Every snapshot and delta row carries `seq`
- Delta semantics (absolute vs change) tested against the venue's own L1
- Resynchronization path exercised by a forced disconnect test
- `is_crossed`, `is_locked` and session phase stored with every sample
- Reconstruction from checkpoint equals reconstruction from open
- Storage estimate signed off before capture starts
- Missing levels are null, not zero

## Common Mistakes

- Storing snapshots only, so a missed delta can never be diagnosed.
- Treating a WebSocket reconnect as a continuation of the previous sequence space.
- Building features from crossed books, which produce negative spreads and microprices outside the quote.
- Sampling on BBO change and then treating rows as equally spaced in time.
- Summing L2 sizes from different venues as if they were one queue.
- Using floating-point prices as dictionary keys in a book.
- Forgetting that some venues publish depth in aggregated tick bands rather than exact prices.

## Limits

This skill covers the data side of order books. Queue-position models, optimal execution and market-making strategies consume this data but are separate disciplines. Consolidating books across venues for trading requires a latency model for each venue and is beyond a data pipeline's responsibility; the pipeline's job is to preserve enough timestamps that such a model can be fitted.
