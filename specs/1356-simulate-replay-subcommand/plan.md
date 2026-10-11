# Plan — Spec 1356 simulate replay subcommand

**Branch**: `1356-simulate-replay-subcommand` | **Date**: 2026-09-09 | **Spec**: [spec.md](./spec.md)

## Approach

New `SimulateReplayCommand` in `lib/src/commands/simulate_command.dart`
(`name: 'replay'`), registered parser-only (`argParser.addCommand`, bug
#856 guard) and dispatched in `SimulateCommand.run()` like the other
scenario subcommands. Reuses `_resolveFeature` (#1354 pin resolution) and
`_loadManifest`. Semantics: load the recorded `WorldRunReceipt` for the
scenario via `WorldRunReceiptStore`; refuse (exit 1) on absent/RED receipt
or world-hash drift; otherwise re-execute via `WorldRuntime` with the
RECORDED seed and compare `runDigest` — `deterministic=true` + exit 0 on
match, `DIGEST MISMATCH` + exit 1 otherwise. Cycle-log evidence kind
`world-replay`; receipt is never overwritten. Docs: invocation string,
library header, help text (pinned-feature wording for consistency).

## Test strategy

New group in `simulate_worlds_command_test.dart` (B1–B5 per the test
list), reusing the temp-workspace + pin harness from the #1354/#1355
groups. Scoped verification only (worlds + simulate + skin files,
analyze on touched files).
