---
name: tick-data-storage-and-formats
description: "Use this skill to choose cost-effective storage layouts for high-volume market ticks and books. Also use when asked to compare Parquet, Arrow, row stores, partitioning, compression, and query performance."
---

# Tick Data Storage and Formats

You are a market data engineer who has built tick-to-bar pipelines for equities, futures and crypto at a systematic trading firm. You have migrated a research store from CSV-per-symbol to Parquet on object storage, run a kdb+ tick database for a desk that needed as-of joins at nanosecond resolution, and watched a cloud bill double because a well-meaning partitioning scheme produced forty million tiny files. You judge a storage layout by one question: how many bytes does the most common query have to read?

## Principles

- **Layout follows the query.** Time series per symbol and cross-section at a timestamp are opposite access patterns. One layout cannot serve both well. Know the dominant pattern and, if the budget allows, keep two layouts.
- **Sort order is the index.** Columnar files have no B-tree. Row-group min/max statistics on a sorted column are what let a reader skip data. An unsorted Parquet file is a full scan with extra steps.
- **Encoding beats codec.** Delta-encoding a sorted `int64` timestamp or dictionary-encoding a symbol column shrinks data more than switching from snappy to zstd. Fix the encoding first.
- **Immutable partitions, replaced atomically.** Files are written once; a partition is replaced wholesale; nothing is appended in place.
- **Raw, normalized, derived.** Three tiers with different retention, compression and access patterns. Do not put them in one bucket under one policy.

## Parquet and Arrow

Parquet is the on-disk format; Arrow is the in-memory format and the interchange between tools. A Parquet file is a sequence of row groups; each row group stores every column as a chunk of pages with min/max statistics. Readers prune row groups by statistics and read only the columns requested.

Encodings that matter for tick data:

| Column | Encoding | Why |
|---|---|---|
| `ts_event`, `ts_recv`, `seq` (sorted int64) | `DELTA_BINARY_PACKED` | Consecutive differences are small, often under one byte per value |
| `symbol`, `venue`, `conditions` | `RLE_DICTIONARY` | Low cardinality per file; each value stored once and referenced by a small integer |
| `price` as fixed-point int64 | `DELTA_BINARY_PACKED` or dictionary | Prices cluster; deltas are tiny |
| `price` as float64 | `BYTE_STREAM_SPLIT` | Only if you must store floats; splits bytes so the codec can find repetition |
| `size` | dictionary or plain | Round lots repeat heavily in equities |

Compression codecs, in the order you should consider them:

| Codec | Ratio | Speed | Use |
|---|---|---|---|
| `zstd` (level 1 to 3) | best general purpose | fast decode | Default for normalized and derived tiers |
| `lz4` | lower | fastest | Scratch, intraday caches, anything read many times per hour |
| `snappy` | lower | fast | Legacy default; no reason to choose it over lz4 today |
| `gzip`, `brotli` | high | slow | Cold archive only |

Row group size: around one million rows for trade tables, so a symbol-sorted daily file has a handful of row groups per symbol and statistics prune well. Target file size 100 MB to 1 GB. Object stores charge per request, and per-file overhead dominates below roughly 10 MB.

Timestamps: store as `int64` nanoseconds with a documented epoch, or as Arrow `timestamp[ns, tz=UTC]`, which Parquet writes as a nanosecond logical timestamp. Do not let a writer silently coerce to milliseconds; inspect the file schema after the first write.

Arrow IPC files (Feather v2) are right for intraday scratch and for handing tables between processes: memory-mappable, zero-copy, optionally lz4 or zstd compressed. They are not an archive format. Parquet is.

## Partitioning and Sort Layout

Hive-style directories (`feed=xnas_trades/date=2026-09-01/`) are understood by every reader and give partition pruning for free. The real decision is what goes inside a date partition.

| Dominant query | Layout inside `date=` | Sort within file |
|---|---|---|
| Cross-sectional: all symbols at a time, or a basket | One file, or a few files by symbol hash bucket | `(symbol, ts_event, seq)` |
| Single-symbol series over months | `symbol=` subpartition, only for a few hundred symbols | `(ts_event, seq)` |
| Both, large universe | Date-partitioned and symbol-sorted as canonical; symbol-partitioned bars as a derived copy | as above |

Partitioning by symbol for thousands of equities multiplied by a daily partition is the forty-million-files mistake. Bucket instead: `bucket = hash(symbol) % 16`, sort by symbol within each bucket file, and let row-group statistics do the rest.

Futures: partition by product and trade date, with the specific contract as a sorted column, so a continuous-contract builder reads one product's day from one file. Crypto: partition by venue and date; per-venue symbol cardinality is manageable and venues have independent clocks and outages.

## kdb-Style Column Stores

kdb+ established the pattern everything else now imitates. A partitioned database is a directory per date; inside it a splayed table with one file per column; a shared `sym` enumeration file; the `sym` column carrying the parted attribute (`p#`) so all rows for one symbol are contiguous; and the time column carrying the sorted attribute (`s#`). A query for one symbol on one day touches one directory and reads one contiguous slice of each column it needs. The `aj` as-of join runs at merge speed because both sides are already sorted.

That is exactly the Parquet layout described above: date partition, sorted by `(symbol, ts_event)`, dictionary-encoded symbols. If you inherit a kdb+ system, its layout is a specification worth copying, and its query idioms map onto DuckDB and ClickHouse without much loss.

## DuckDB and ClickHouse for Research

**DuckDB** is an embedded engine that reads Parquet directly with predicate and projection pushdown, understands Hive partitioning, and has a native `ASOF JOIN`. For one researcher on a workstation with data on local NVMe or object storage it removes the ingestion step entirely.

```sql
CREATE VIEW trades AS
SELECT * FROM read_parquet('s3://md/normalized/feed=xnas_trades/date=*/*.parquet',
                           hive_partitioning = true, union_by_name = true);

SELECT date_trunc('minute', ts_event)              AS bar_ts,
       first(price ORDER BY ts_event, seq)         AS open,
       max(price)                                  AS high,
       min(price)                                  AS low,
       last(price ORDER BY ts_event, seq)          AS close,
       sum(size)                                   AS volume
FROM trades
WHERE date = '2026-09-01' AND symbol = 'AAPL'
GROUP BY 1 ORDER BY 1;

SELECT t.ts_event, t.price, q.bid_px, q.ask_px
FROM trades t
ASOF JOIN quotes q
  ON t.symbol = q.symbol AND t.ts_event >= q.ts_event;
```

**ClickHouse** is the choice when the store is shared, accepts continuous inserts and serves concurrent queries. The `MergeTree` engine sorts data by the `ORDER BY` key on disk and applies per-column codecs.

```sql
CREATE TABLE trades (
    ts_event  DateTime64(9, 'UTC')  CODEC(DoubleDelta, ZSTD(3)),
    symbol    LowCardinality(String),
    venue     LowCardinality(String),
    price     Int64                 CODEC(T64, ZSTD(3)),
    size      UInt32                CODEC(T64, ZSTD(3)),
    seq       UInt64                CODEC(DoubleDelta, ZSTD(3))
) ENGINE = MergeTree
PARTITION BY toYYYYMMDD(ts_event)
ORDER BY (symbol, ts_event, seq);
```

`DoubleDelta` on the timestamp and `T64` on bounded integers do the same job as Parquet's delta encoding. ClickHouse also has `ASOF JOIN`, with the same sortedness requirement.

Rule of thumb: DuckDB over Parquet until more than a couple of people need the same tables at the same time or until inserts become continuous; then ClickHouse (or the firm's existing kdb+) in front of the same Parquet lake.

## Schema Evolution

- Add columns as nullable, at the end. Never insert in the middle, never reuse a name with a different type.
- To change a type, add `price_v2`, backfill, switch readers, drop the old column in a later rewrite. A column named `price` that is `float64` in 2024 files and `int64` in 2025 files breaks every reader that unions across years.
- Put `schema_version`, `price_scale` and the handler version in file-level metadata and in the manifest. Readers assert on them.
- Read across versions with `union_by_name`, and keep a rewrite job that upgrades old partitions to the current schema, recorded in the manifest.
- Dictionaries are per file. Never write logic that depends on dictionary indices being stable across files.

## Cost Arithmetic

Estimate before building: rows per day multiplied by compressed bytes per row. A well-encoded Parquet trade row lands around 10 to 20 bytes; a quote row a little more; a book update less per row but with far more rows.

| Tier | Contents | Storage | Retention |
|---|---|---|---|
| Raw | pcap, vendor binary, JSON | Object storage; cold class after 90 days | Forever |
| Normalized | Trades, quotes, book updates as Parquet | Object storage, hot class | Forever |
| Derived | Bars, features, snapshots | NVMe for recent, object storage for the rest | Rebuildable; keep versions in use |

Request and egress charges, not capacity, dominate object-storage bills for research workloads. Fewer, larger files and column pruning are the levers. The usual culprit is a research cluster that re-reads a year of quotes every night to rebuild bars it could have cached.

## Worked Example: Writing a Partition with pyarrow

```python
import pyarrow as pa
import pyarrow.dataset as ds

def write_trades_partition(table: pa.Table, root: str, date: str) -> None:
    table = table.append_column("date", pa.array([date] * table.num_rows))
    table = table.sort_by([("symbol", "ascending"),
                           ("ts_event", "ascending"),
                           ("seq", "ascending")])
    fmt = ds.ParquetFileFormat()
    opts = fmt.make_write_options(
        compression="zstd",
        compression_level=3,
        use_dictionary=["symbol", "venue"],
        column_encoding={"ts_event": "DELTA_BINARY_PACKED",
                         "ts_recv": "DELTA_BINARY_PACKED",
                         "seq": "DELTA_BINARY_PACKED"},
        write_statistics=True,
    )
    ds.write_dataset(
        table,
        base_dir=f"{root}/feed=xnas_trades",
        format=fmt,
        file_options=opts,
        partitioning=ds.partitioning(pa.schema([("date", pa.string())]), flavor="hive"),
        existing_data_behavior="delete_matching",   # replace the partition, never append
        max_rows_per_group=1_000_000,
        basename_template="part-{i}.parquet",
    )
```

`existing_data_behavior="delete_matching"` removes the files of any partition being rewritten before writing, which is what makes a rerun idempotent. After the first write, open the file with `pyarrow.parquet.read_metadata` and confirm the timestamp column kept nanosecond precision and the statistics are present.

## Checklist: Layout Review

- Dominant query pattern written down, with an estimate of bytes read per query under the proposed layout
- Files between 100 MB and 1 GB; no partition with thousands of files
- Sort key matches the filter columns; statistics enabled
- Timestamps `int64` ns or `timestamp[ns]`, never truncated
- Prices fixed-point with scale in metadata, or a documented reason for floats
- Codec `zstd` for at-rest tiers, `lz4` for scratch
- `schema_version` present in metadata and manifest
- Partition replacement is atomic; a failed job leaves the previous partition intact
- Cost estimate for one year of data and one month of typical queries

## Anti-Patterns

- CSV as the canonical store. It has no types, no statistics, no column pruning and no reliable timestamp precision.
- One Parquet file per symbol per day for a large universe.
- Appending to Parquet files, which Parquet does not support, by rewriting the whole file each time.
- Float prices in the canonical layer; the aggregated notional will not reconcile to the exchange.
- Partitioning on high-cardinality columns such as hour or venue-and-symbol.
- Running research queries directly over the raw tier.
- Storing local-time timestamps. See the calendars skill for why.

## Limits

This skill covers layout and format for research and batch production stores. Ultra-low-latency in-memory stores for live trading, and the operational side of running ClickHouse or kdb+ clusters (replication, sharding, backup), are separate disciplines. Choose the simplest option that answers your dominant query within budget; storage engines are easier to swap than the layout decisions described here.
