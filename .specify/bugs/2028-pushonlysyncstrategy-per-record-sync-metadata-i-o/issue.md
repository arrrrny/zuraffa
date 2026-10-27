# Issue #2028 (verbatim) — PushOnlySyncStrategy: per-record sync-metadata I/O makes a 2k backlog a ~6,000-op disk-bound push

Recorded as the sole input for the bug cycle. Content below is the issue
text, unmodified.

## Command

From `arrrrny/zik_zak` (`zuraffa` 7.2.0):

```bash
flutter test --no-pub --concurrency=2 \
  test/data/datasources/engagement_event/engagement_event_sync_strategy_test.dart \
  --plain-name "bounds the box after pushing a backlog beyond the cap"
```

## Expected

A 2,025-record `syncPending()` push (each record marked `pending` via
`markPending`) completes comfortably inside a test's default 30 s budget, and
the cost of pushing N records is proportional to N.

## Actual

Pushing a 2,025-record backlog takes ~1.5 s on an idle host and blows past 30 s
once the test runs beside another disk-heavy file in the same suite:

```text
TimeoutException after 0:00:30.000000: Test timed out after 30 seconds.
```

Instrumented timings (idle 2019 Intel host, `hive_ce` 2.22.0):

- seeding 2,025 `pending` records through a repository: ~1.3 s
- `syncPending()` over them: ~1.5 s

`SyncMetadataStore.getKeysByStatus` itself is cheap (~4 ms per full scan of
2,025 rows), so the cost is not the scans — it is the per-record read/write
traffic below.

## Root cause

`PushOnlySyncStrategy` issues its sync-metadata I/O one awaited call at a time,
four reads and two writes per record, for the whole pass:

1. `_processKeys` (lib/src/plugins/sync/builders/push_only_sync_strategy.dart)
   reads every pending key's metadata to split tombstones from live records —
   1 read per record.
2. `_syncBatch` re-reads each key and then writes `syncing` back — 2 calls per
   record, per batch.
3. `_syncEntity` reads the metadata again and writes `synced` — 2 more calls
   per record.

That is ~6,000 sequential `Hive` operations for 2,025 records, each a real
write to the box backend, so the pass is disk-bound rather than CPU-bound. Its
wall time therefore tracks disk contention, and there is no batching anywhere:
`SyncMetadataStore` exposes only single-key `get`/`put`.

## Suggested fix

- Write a batch's status transitions with one `Box.putAll` (`_syncBatch` marks
  every key `syncing`; `_syncEntity` writes each `synced` — both are batches of
  a known size), and take the partition's metadata from one `values` snapshot
  instead of N `get` calls.
- Or give `SyncMetadataStore` a status index so `getKeysByStatus` and the
  per-record reads stop round-tripping through the box.

Either would cut the pass from ~6,000 box operations to a few dozen and make it
insensitive to host load.
