# Cycle Log: bug #2028 — PushOnlySyncStrategy per-record sync-metadata I/O

Append only. Newest last. Every entry's `red` block is the evidence that
the test existed and failed before the implementation.

## Baseline

- suite: `dart test -j 2 test/plugins/sync/push_only_sync_strategy_test.dart`
  → 10/10 passed at branch base `a9c148b8` (pre-change)
- full-project analyze baseline: 271 issues, identical with the fix stashed
  (see tdd/verification.md §3)
- recorded: cycle 0, before any change

## Cycle 1: batch-bounded metadata I/O for the whole push (bug #2028)

- behavior: B1 in `tdd/test-list.md` — a 2,025-record `syncPending()` push
  with the default batch size issues awaited metadata operations bounded by
  the batch count (ceiling `2 * batchCount + 16`, floor `2 * batchCount`),
  with every record landing remotely and every status reaching `synced`.
- test (new test `bounds the box after pushing a backlog beyond the cap` in
  `test/plugins/sync/push_only_sync_strategy_test.dart`; counting fake gains
  an `opCount` incremented per awaited store call, one `putAll`/`getByKeys`
  call counts as one operation mirroring one box operation):
  - RED verbatim: `pushing 2025 records issued 10129 awaited metadata
    operations; expected <= 98` — full output in `../red-evidence.md`
  - red observed BEFORE any source change in this session (test-first)
- implementation (minimal, matches the issue's first suggested fix):
  - `SyncMetadataStore.getByKeys(keys)`: one `Box.toMap()` snapshot →
    `Map<String, SyncMetadata>` for the requested keys (replaces N awaited
    `get` calls for the partition)
  - `SyncMetadataStore.putAll(entries)`: one `Box.putAll` (batched writes)
  - `PushOnlySyncStrategy._processKeys`: partition tombstones/live from ONE
    `getByKeys` snapshot; hands the snapshot to `_syncBatch`
  - `PushOnlySyncStrategy._syncBatch`: marks the whole batch `syncing` with
    one `putAll`; pushes each entity to the remote (per-record by design —
    the network layer is not the target); collects `synced` transitions and
    writes them with one `putAll` at the end of the batch; per-entity
    metadata comes from the snapshot (the old per-record `_syncEntity`
    re-read/write loop is inlined and de-duplicated)
  - `_FakeBox` (simulate capability) gains `putAll` + `toMap` — it implements
    exactly the box members the store uses; the store's new calls surfaced a
    `NoSuchMethodError` in 4 simulate tests mid-cycle (caught by the
    regression sweep, fixed in-cycle, sync dir re-run green)
- GREEN: `00:00 +11: All tests passed!` (bound test + all pre-existing
  behaviors in the file); post-fix instrumented push: 84 awaited metadata
  ops, 24 ms in-memory
- mutation checks (deliberate mutants, hand-run, restore verified):
  - M1 drop syncing `putAll` → killed (floor: 46 < 82)
  - M2 drop synced `putAll` → killed (status stuck `syncing`)
  - M3 per-record partition reads → killed (ceiling: 10,129 > 98; the red)
- regression: `test/plugins/sync/` 42/42, `sync_with_di` slow-lane 1/1,
  repository-adjacent 8/8, changed-file analyze clean, format-clean —
  full evidence in `tdd/verification.md`
