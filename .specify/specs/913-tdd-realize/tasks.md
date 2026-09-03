# Tasks: 913-tdd-realize

- **Spec ID**: 913-tdd-realize
- **Created**: 2026-09-03

## T001: Command skeleton
- Implement `zfa tdd realize <entity|behavior> --adapter <real>` subcommand
- Wire DI rebinding: mock → real via generated interface
- Add independent `RunState.era` metadata, initially `MOCKED`; do not persist `REAL` until T002 and T003 both succeed
- Keep `BehaviorState` / `TestListReader._parseState` behavior values `PENDING`, `RED`, `GREEN`, and `DONE`, with `BASELINE`, `BLOCKED`, and `DROPPED` retained as non-era bookkeeping states
- Tests: `realize_command_test.dart`

## T002: Contract gate
- Validate a green mock baseline and the shared fixtures/test harness before assigning a real-or-mock verdict
- Run MOCK-era test suite against real binding (untouched tests)
- Deterministically classify failures as `mock-baseline`, `fixture`, `test-harness`, or (only after the other checks pass) `real-adapter`
- Gate must pass for swap to proceed
- Tests: `contract_gate_test.dart`

## T003: Differential gate
- Reuse #832 simulate adapter infrastructure
- Real vs mock run same committed fixtures
- Output diff = drift report with per-field comparison
- Threshold from `.zfa.json` (configurable)
- Reuses #805 differential machinery
- After T002 and T003 pass, atomically append successful REAL-era gate evidence and persist `RunState.era = REAL`; persist neither on failure
- Tests: `differential_gate_test.dart`

## T004: Nuance receipts
- Hand-written deltas recorded in feature's provenance ledger
- Each entry: (file, reason, diff-hash)
- Hand-deltas legal; ungated hand-deltas blocked
- References #807 proof-carrying pattern
- Tests: `nuance_receipts_test.dart`

## T005: Era-tagged cycle-log
- Newly appended cycle-log entries carry an additive era field (MOCKED or REAL); existing entries remain byte-for-byte unchanged
- Preserve each entry's command, failure output, green-making change/generation evidence, and refactor evidence for `/speckit.tdd.verify`
- Keep era metadata independent of behavior and bookkeeping states, with the run-era transition visible in append-only history
- Tests: `era_tagged_log_test.dart` covers append-only behavior, preservation of prior entries, and complete evidence retention in both eras

## T006: End-to-end verification
- Run `/speckit.tdd.verify` against the full command
- Verify contract + differential gates + nuance receipts work together
- Generate `tdd/verification.md` from real run
- Prove verification fails closed by removing contract evidence, differential evidence, each applicable nuance receipt, and era-tagged evidence one class at a time; every such run must return a non-passing verdict
- Retain the successful full-command verification and its generated `tdd/verification.md`
- Commit and open PR
