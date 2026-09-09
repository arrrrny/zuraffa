# Plan — Spec 1359 sync simulate chaos driver

**Branch**: `1359-sync-simulate-chaos` | **Date**: 2026-09-09 | **Spec**: [spec.md](./spec.md)

## Approach

`SimulateSyncCapability` on the sync plugin (auto-registers as
`zfa sync simulate`; schema enum derives `--scenario`). The driver seeds
N pending entities into an in-memory Hive-shaped box, wires the REAL
`PushOnlySyncStrategy` to a scripted remote (offline window → fail/fail/ok
flap cycle → recovery), and re-drives the strategy's own recovery paths
until the ledger fills or the 10-round horizon ends. Per-key ledger +
summary line + ExecutionResult carrying the verdict.

## Test strategy

CLI-level group in `test/plugins/sync/simulate_sync_capability_test.dart`
(B1–B4); scoped pin: `test/plugins/sync/` + analyze on touched files.
