# Test List: bug #2028 — PushOnlySyncStrategy per-record sync-metadata I/O

Traces: GitHub issue #2028 · red-evidence.md in this directory · hard
constraints: one PR for this bug only; fix exactly the enumerated per-record
I/O (partition reads, batch syncing marks, per-entity synced writes); no
status index, no unrelated refactors; `syncFailed`'s reset loop and the
tombstone path are outside the issue's enumeration and stay per-key.

- feature: 2028-pushonlysyncstrategy-per-record-sync-metadata-i-o
- source: issue.md (Root cause + Suggested fix) + red-evidence.md
- suite tier: fast (`dart test test/plugins/sync/push_only_sync_strategy_test.dart`)

## Behaviors

| id | behavior | serves | test | state |
| -- | -------- | ------ | ---- | ----- |
| B1 | Pushing a 2,025-record pending backlog with the default batch size costs awaited metadata operations proportional to the number of batches, not records: ceiling `2 * batchCount + 16` (two batched writes per batch + snapshot + scan + assertion reads), floor `2 * batchCount` (both batched transitions must actually fire), while every record lands remotely and every status reaches `synced` | issue Expected ("cost of pushing N records is proportional to N" — per batch for the metadata layer) + Suggested fix (one `putAll` per transition, one partition snapshot) | `test/plugins/sync/push_only_sync_strategy_test.dart` → `bounds the box after pushing a backlog beyond the cap` | green |

## Regression surface guarded by pre-existing tests

- `test/plugins/sync/push_only_sync_strategy_test.dart` (existing 10 tests):
  pending/failed lifecycle, tombstones, retry → failed escalation,
  getPendingCount, no-op sync, batch handling — all green post-fix.
- `test/plugins/sync/` whole dir (42 tests) incl. bidirectional strategy
  (shares the metadata store contract via its fake) and the simulate chaos
  capability (drives the REAL strategy through `_FakeBox`).
- `test/integration/sync_with_di_test.dart` (slow tier) and the
  sync-referencing repository suites (8 tests).
