# RED Evidence — Issue #2028 (per-record sync-metadata I/O)

Date: 2026-10-27
Branch: fix/2028-pushonlysyncstrategy-per-record-sync-metadata-i-o-makes-a-2k
Repro: the library-side shape of the issue's consumer test — seed a
2,025-record pending backlog through `markPending`, reset the counting fake's
op counter, push with the default `SyncConfig` (batchSize 50), bound the
awaited metadata operations:

```
dart test -j 2 test/plugins/sync/push_only_sync_strategy_test.dart \
  --plain-name "bounds the box after pushing a backlog beyond the cap"
```

## Observed (pre-fix, this session, verbatim)

```
00:00 +0: loading test/plugins/sync/push_only_sync_strategy_test.dart
00:00 +0: PushOnlySyncStrategy bounds the box after pushing a backlog beyond the cap
00:00 +0 -1: PushOnlySyncStrategy bounds the box after pushing a backlog beyond the cap [E]
  Expected: a value less than or equal to <98>
    Actual: <10129>
     Which: is not a value less than or equal to <98>
  pushing 2025 records issued 10129 awaited metadata operations; expected <= 98 (batched writes + one snapshot, not per-record I/O)

  package:matcher                                            expect
  test/plugins/sync/push_only_sync_strategy_test.dart 300:7  main.<fn>.<fn>

00:00 +0 -1: Some tests failed.

Failing tests:
  test/plugins/sync/push_only_sync_strategy_test.dart: PushOnlySyncStrategy bounds the box after pushing a backlog beyond the cap
```

## Why this matches the issue's root cause (no discrepancy)

10,129 awaited metadata calls for 2,025 records ≈ the issue's four reads +
two writes per record (partition gets, per-batch syncing re-read + write,
per-entity synced re-read + write) plus the status scan and counting reads.
The failure is the per-record I/O volume, not the status scans — same root
cause the issue names. The consumer repo's 30 s timeout is the wall-clock
shadow of this op volume under disk contention; the op-count bound is its
deterministic, host-load-insensitive stand-in.
