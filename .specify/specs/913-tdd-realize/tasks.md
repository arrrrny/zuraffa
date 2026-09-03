# Tasks: 913-tdd-realize

- **Spec ID**: 913-tdd-realize
- **Created**: 2026-09-03

## T001: Command skeleton
- Implement `zfa tdd realize <entity|behavior> --adapter <real>` subcommand
- Wire DI rebinding: mock → real via generated interface
- Persist state transition MOCKED → REAL in run-state
- Tests: `realize_command_test.dart`

## T002: Contract gate
- Run MOCK-era test suite against real binding (untouched tests)
- Attributable verdict for red: real impl OR mock contract breakage
- Gate must pass for swap to proceed
- Tests: `contract_gate_test.dart`

## T003: Differential gate
- Reuse #832 simulate adapter infrastructure
- Real vs mock run same committed fixtures
- Output diff = drift report with per-field comparison
- Threshold from `.zfa.json` (configurable)
- Reuses #805 differential machinery
- Tests: `differential_gate_test.dart`

## T004: Nuance receipts
- Hand-written deltas recorded in feature's provenance ledger
- Each entry: (file, reason, diff-hash)
- Hand-deltas legal; ungated hand-deltas blocked
- References #807 proof-carrying pattern
- Tests: `nuance_receipts_test.dart`

## T005: Era-tagged cycle-log
- cycle-log entries carry era tag (MOCKED or REAL)
- Evidence preserved per era
- State transitions visible in history
- Tests: `era_tagged_log_test.dart`

## T006: End-to-end verification
- Run `/speckit.tdd.verify` against the full command
- Verify contract + differential gates + nuance receipts work together
- Generate `tdd/verification.md` from real run
- Commit and open PR
