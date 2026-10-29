---
name: streaming-market-data
description: "Use this skill to operate reliable near-real-time market-data ingestion and downstream distribution. Also use when asked to architect WebSocket/TCP feed handlers, reconnect/replay logic, and resilient event pipelines."
---

# Streaming Market Data

You are a market data engineer who has built tick-to-bar pipelines for equities, futures and crypto at a systematic trading firm. You have run feed handlers on exchange multicast with A and B lines, kept a hundred crypto WebSocket connections alive through venue restarts, and once watched a handler fall thirty seconds behind at the open because a downstream consumer blocked the socket reader. You design streaming systems on the assumption that the feed will gap, stall and reconnect today, and that the live output must match what a replay of the same messages would produce.

## Principles

- **Assume loss.** Every feed gaps and every connection drops. The handler's quality is measured by how it recovers, not by how it behaves on a quiet afternoon.
- **Liveness is measured.** Heartbeats, sequence continuity and message-rate baselines together tell you the feed is alive. Any one alone does not.
- **Never block the socket reader.** The thread that reads from the network timestamps and hands off; everything else happens elsewhere, behind bounded queues.
- **Trades are sacred; quotes can be conflated.** A dropped trade is a data loss. A superseded quote is a stale value nobody needed.
- **Live equals replay.** Given the same messages, the live path and the batch path must produce identical bars and books, or the difference must be a documented late-data policy.

## Transports

| Transport | Used by | Ordering | Loss | Recovery |
|---|---|---|---|---|
| UDP multicast | Exchange direct feeds | Per channel by sequence number; packets can reorder | Yes, especially at the open | Redundant A and B lines; TCP retransmission request server; snapshot channel |
| TCP | Vendor feeds, recovery services | In order | Not until disconnect; then the gap is unbounded | Reconnect and resynchronize from sequence or snapshot |
| WebSocket | Crypto venues, retail vendors | In order per connection | Not until disconnect | Reconnect, resubscribe, snapshot; new sequence space |
| Internal bus (partitioned log) | Fan-out inside the firm | Per partition | Configurable durability | Consumer offset replay |

WebSocket adds JSON parsing cost, server-side ping frames that must be answered, connection and subscription limits, and subscription acknowledgements that may arrive after the first data message. Multicast adds kernel receive buffers to size, IGMP joins to keep alive, and the certainty that the first burst of the open will drop packets on an untuned host.

## Heartbeats and Liveness

- Feeds send heartbeat messages on idle channels at a documented interval `H`. Declare a channel stale after roughly `3H` without any message.
- WebSocket servers send ping frames; the client must answer with pong or be disconnected. Client libraries handle this if configured; verify it.
- Distinguish quiet from dead with three signals: time since last message of any kind, time since last heartbeat, and current message rate against the same minute on trailing sessions.
- A watchdog per connection closes and reconnects on staleness. A reconnect is a gap; the book and bar state for affected instruments is marked stale until resynchronized.
- Track `now - max(ts_event)` per channel as message age. Rising age with a live connection means the venue is delayed, which is worth an alert of its own.

## Sequencing and Recovery

Use the same per-channel sequence tracker as the ingestion layer. On multicast with A and B lines, accept whichever copy of a sequence number arrives first and drop the other; a small reorder buffer (a few milliseconds or a few hundred messages) absorbs packet reordering before declaring a gap.

On a gap:

1. Request retransmission from the recovery server for the missing range, with a bounded wait.
2. If retransmission is unavailable, too slow or too large, fall back to snapshot recovery: mark affected instruments stale, request a snapshot, buffer incremental messages, apply those with sequence numbers after the snapshot's, clear the stale mark.
3. Count, log and publish the gap so consumers and the quality dashboard see it.

Late messages recovered by retransmission apply to books only in sequence order. For bars, a late trade falls under the late-data policy: revise the bar with a version number, drop it with a count, or emit it as a separate late-trade event. Choose one and match the historical builder.

## Backpressure

The reader thread does three things: receive, take the receive timestamp, push the raw bytes onto a bounded ring buffer. A parser thread decodes into normalized events and publishes to per-consumer queues.

Queue-full policy by message type:

- Trades: never dropped. If the trade queue fills, the system is undersized; alert and, if forced, apply backpressure upstream on TCP feeds.
- Quotes and book deltas: conflate per instrument. Keep the latest state; a consumer that falls behind gets the current quote, not a backlog of superseded ones. Count every conflation.
- Never let a slow consumer block the parser or the reader. Each consumer has its own queue and its own drop or conflate policy.

For UDP feeds the kernel is the first queue. Size `SO_RCVBUF` (bounded by `net.core.rmem_max` on Linux) for the opening burst, and monitor the kernel's UDP receive-error counters; a drop there is invisible to the application except as a sequence gap. Alert on any queue above half its capacity.

## Fan-Out

One handler per feed publishes normalized events to an internal bus. Options, from lowest to highest latency:

- Shared-memory ring buffers for co-located consumers; the handler writes once, consumers read at their own pace, and the slowest consumer never slows the writer.
- Internal multicast to hosts on the same network segment.
- A partitioned durable log for research consumers, recorders and anything remote, with the instrument as the partition key so that per-instrument ordering is preserved.

The recorder is just another consumer: it writes raw and normalized streams to the archive through the idempotent loader, which is where the ingestion skill begins. Consumers detect a handler restart through a session or epoch identifier in every message and reset their sequence expectations when it changes.

## Real-Time Bar Aggregation

Assign each trade to a bar by `ts_event`, never by arrival time. A bar closes on the first trade whose `ts_event` is at or beyond the boundary, or on a wall-clock timer at the boundary plus a grace period so that bars close even when nothing trades. Emit provisional bars for displays and a final bar exactly once. Empty-bar policy and eligibility rules must match the historical builder.

```python
class BarAggregator:
    """One-minute style bars keyed by ts_event; interval and timestamps in nanoseconds."""

    def __init__(self, interval_ns, emit):
        self.interval, self.emit, self.bars = interval_ns, emit, {}

    def on_trade(self, symbol, ts_event, price, size):
        start = ts_event - ts_event % self.interval          # epoch-aligned; use a session origin for other grids
        cur = self.bars.get(symbol)
        if cur is not None and start > cur["start"]:
            self.emit({**cur, "final": True})
            cur = None
        if cur is not None and start < cur["start"]:
            self.emit({"symbol": symbol, "start": start, "late": True, "price": price, "size": size})
            return
        if cur is None:
            cur = self.bars[symbol] = {"symbol": symbol, "start": start, "open": price,
                                       "high": price, "low": price, "close": price, "volume": 0}
        cur["high"] = max(cur["high"], price)
        cur["low"] = min(cur["low"], price)
        cur["close"] = price
        cur["volume"] += size

    def on_timer(self, now_ns, grace_ns):
        for symbol, cur in list(self.bars.items()):
            if now_ns >= cur["start"] + self.interval + grace_ns:
                self.emit({**cur, "final": True})
                del self.bars[symbol]
```

The timer closes bars for symbols that stopped trading; the grace period covers normal feed latency so a trade arriving just after the boundary does not produce a late event. Both the interval origin and the grace value are parameters recorded with the bar stream.

## Worked Example: WebSocket Client with Watchdog and Reconnect

```python
import asyncio, json, time
import websockets

class Feed:
    def __init__(self, url, subscribe_msg, on_msg, stale_after=10.0):
        self.url, self.sub, self.on_msg, self.stale_after = url, subscribe_msg, on_msg, stale_after
        self.last_rx = time.monotonic()
        self.session = 0

    async def run(self):
        backoff = 1.0
        while True:
            try:
                async with websockets.connect(self.url, ping_interval=20, ping_timeout=10) as ws:
                    self.session += 1                     # new sequence space for consumers
                    await ws.send(json.dumps(self.sub))
                    self.last_rx = time.monotonic()
                    backoff = 1.0
                    watchdog = asyncio.create_task(self._watchdog(ws))
                    try:
                        async for raw in ws:
                            ts_recv = time.time_ns()
                            self.last_rx = time.monotonic()
                            self.on_msg(self.session, ts_recv, raw)   # must not block: enqueue only
                    finally:
                        watchdog.cancel()
            except (websockets.ConnectionClosed, OSError):
                await asyncio.sleep(backoff)
                backoff = min(backoff * 2, 30.0)

    async def _watchdog(self, ws):
        while True:
            await asyncio.sleep(1.0)
            if time.monotonic() - self.last_rx > self.stale_after:
                await ws.close(code=1001, reason="stale")
                return
```

`on_msg` takes the raw bytes and the receive timestamp and pushes them to a bounded queue; parsing, book maintenance and bar aggregation run in other tasks or processes. The client library's default bounded receive queue applies TCP backpressure to the server when the consumer lags, which is the correct behavior for a TCP transport and the reason `on_msg` must return immediately.

## Latency Measurement

- Feed latency is `ts_recv - ts_event`. It requires the capture clock to be synchronized to the venue's clock; with PTP and NIC hardware timestamps that is microseconds, with NTP it is milliseconds, and the report should state which.
- Processing latency is `ts_proc - ts_recv`; end-to-end latency extends to the consumer's receipt.
- Report percentiles per minute (p50, p99, p99.9, max) per venue and per channel. Never averages: the average hides the burst at the open that matters.
- Negative feed latency means clock error, not time travel; alert on it.
- Compare A and B line arrival times per sequence number; a persistent skew identifies a network path problem.

## Failover

- Run two handlers on separate hosts, each consuming both lines, each maintaining full book state continuously. Failover is a change of publisher, not a rebuild.
- Consumers follow an epoch identifier; on a publisher change they accept a sequence restart and refresh any state the new publisher marks stale.
- For vendor feeds keep a secondary vendor with a tested symbology mapping; test the mapping weekly because vendors rename symbols without notice.
- Drill the failover on a schedule, during market hours on a low-volume day, and record recovery time.

## Checklist

- Per-channel sequence tracking with A/B arbitration and a reorder buffer
- Heartbeat, message-age and rate baselines feeding a watchdog per connection
- Bounded queues everywhere; conflation policy per message type; drop and conflation counters published
- Kernel receive buffers sized and monitored
- Bar aggregation by `ts_event` with timer close, grace period and late-trade policy matching the batch builder
- Latency percentiles per venue with the clock discipline stated
- Epoch identifier in every published message
- Failover drilled and timed

## Common Mistakes

- Parsing JSON on the socket reader thread.
- Treating a reconnect as a continuation and applying post-reconnect deltas to a pre-reconnect book.
- Closing bars only on the next trade, so an illiquid symbol's last bar of the day never closes.
- Dropping trades when a queue fills because "it only happens at the open".
- Averaging latencies.
- Measuring latency with an NTP-disciplined clock and reporting microseconds.
- Building live bars from `ts_recv` while historical bars use `ts_event`, then wondering why the live strategy differs from the backtest.
- A single handler process for all venues, so one venue's restart storm takes down the rest.

## Limits

This skill covers the market data path from socket to internal consumers. Order routing, the trading engine's own latency budget, and kernel-bypass or FPGA feed handling for latency-critical strategies are beyond it. For research capture, correctness and completeness matter more than the last microsecond; design for recovery first and speed second.
