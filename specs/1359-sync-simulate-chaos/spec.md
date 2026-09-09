**Template Version**: `zuraffa-1.0`

# Spec: 1359-sync-simulate-chaos

GitHub issue: arrrrny/zuraffa#1359 (labels: verify-misfire, empty-implementation)
Epic: #1136 Phase A sub-issue 4 — chaos testing for temporal features
("scripted failing remote drives sync strategy")

## Summary

`zfa sync simulate --scenario offline-flap` did not exist — `zfa sync`
exposed only the `enable` generation capability, and the invocation died
at the parser. The repo ships a real, dependency-injected sync strategy
(`PushOnlySyncStrategy`/`BidirectionalSyncStrategy`) whose retry,
backoff-aware status, and batch pipelines were never chaos-driven by a
first-party verb.

## Problem

An empty-implementation gap. The minimal honest build: a `simulate`
capability on the sync plugin that drives the REAL strategy against a
scripted failing remote and reports a per-key landing ledger with a
verdict — the scenario definitions are the chaos contract.

## Locked decisions

1. Registration: a `SimulateSyncCapability` (name `simulate`) on the sync
   plugin — the capability mechanism derives `zfa sync simulate` and the
   `--scenario`/`--entity-count` options from the input schema (Spec 917
   help-text leg satisfied by schema descriptions).
2. Scenario v1: `offline-flap` — the scripted remote refuses the first
   4 create calls (offline window), then flaps on a fail/fail/ok cycle,
   then recovers. Unknown scenarios are refused at the parser layer
   (schema enum) with the capability keeping its own guard for direct
   invocation.
3. The driver exercises the REAL `PushOnlySyncStrategy` (in-memory
   Hive-shaped box, scripted remote closures) through its own public
   paths: markPending → syncPending → recovery (syncPending /
   syncFailed by store state) until the ledger is full or the horizon
   (10 rounds) is exhausted.
4. Verdict: GREEN iff every seeded entity lands exactly once (no loss,
   no duplicate remote writes, dedupe via the landing ledger) and the
   chaos evidence (retry counts > 0, recovery rounds) is reported. A RED
   verdict is an honest outcome, never swallowed.
5. No changes to the strategy, store, or generation surfaces.

## Functional requirements

- **FR-1**: the offline-flap scenario drives the strategy to
  `verdict=GREEN` with `landed=N/N` (exit 0).
- **FR-2**: unknown scenarios refuse honestly naming the allowed list;
  the summary line carries `retries>0`, `recovery-rounds`, and the
  `sync-simulate:` summary prefix.
- **FR-3**: `--help` documents `--scenario` with the offline-flap
  description.

## Acceptance scenarios (measurable)

1. `zfa sync simulate --scenario offline-flap` → exit 0, `verdict=GREEN`,
   `landed=5/5`, `retries>0=5` (every entity felt the offline window).
2. `--scenario gremlins` → exit 2 at the parser naming the allowed value.
3. The summary line names the scenario and the evidence.
4. `zfa sync simulate --help` documents `--scenario`.

## Success criteria

- **SC-001**: The epic sub-issue-4 verb is wired: the sync strategy is
  chaos-driven by a first-party command with a per-key ledger.
- **SC-002**: The sync suites stay green.

## Assumptions

- v1 ships one scenario; the registry (`scenarios` list) is the
  extension point for future schedules.
