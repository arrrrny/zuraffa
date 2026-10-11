# TDD Cycle Log — Spec 1356

## Baseline (2026-09-09)
- branch: 1356-simulate-replay-subcommand; list: B1–B5 all PENDING.

## RED (2026-09-09)
- `+0 -5` — replay unregistered: every behavior hit the exit-2 usage
  screen; help lacked `<init|run|replay`. Committed as certified red.

## GREEN (2026-09-09)
- `SimulateReplayCommand` (parser-only registration, #1354 pin
  resolution, recorded-seed re-execution, digest comparison, cycle-log
  kind world-replay, receipt never overwritten). Worlds file `+35`;
  scoped pin `+168`; analyze clean.
- Mutation sampling executed: M1 dispatch-removed → killed (B1–B4);
  M2 comparison-inverted → killed (B1/B4). 0 survivors.
