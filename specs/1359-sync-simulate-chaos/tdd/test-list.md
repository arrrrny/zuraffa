# TDD Test List — Spec 1359 sync simulate chaos driver

Red pre-fix (capability unregistered): every invocation exits 2 —
"Could not find a subcommand" (the issue signature).

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | offline-flap drives the REAL strategy to GREEN: exit 0, verdict=GREEN, landed=5/5 | FR-1 | test/plugins/sync/simulate_sync_capability_test.dart |
| B2 | Unknown scenario refuses naming the allowed list (parser layer: exit 2 + allowed value) | FR-2 | test/plugins/sync/simulate_sync_capability_test.dart |
| B3 | Summary carries the chaos evidence: retries>0, sync-simulate line | FR-2 | test/plugins/sync/simulate_sync_capability_test.dart |
| B4 | --help documents --scenario + offline-flap | FR-3 | test/plugins/sync/simulate_sync_capability_test.dart |

## Red protocol

```
dart test test/plugins/sync/simulate_sync_capability_test.dart
```
Expected RED (pre-fix): +0 -4 (subcommand absent).
