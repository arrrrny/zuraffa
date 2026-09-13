# TDD Test List — 1592-born-green-transition-never-converges

- **Slug**: 1592-born-green-transition-never-converges
- **Suite**: `test/plugins/tdd/commands/bug_1592_born_green_blocked_convergence_test.dart`
- **Harness**: driver-level (the scripted fake-zfa convention, `TddFixture`),
  tagged `slow` — run with `dart test --preset=all <file>`.

## Red → Green cycle

| Cycle | Commit | Result |
|-------|--------|--------|
| RED (reproduction) | `822b3733` (B1) / pre-reconcile session run | U-1592-1 fails with the loop signature: `verify-red -> unexpected-green` → `make -> not-certified-red` → `#1411` stop prescribing the already-run `--born-green`; `result=stopped ... stopped_at=contract:A1:hand` |
| GREEN (fix) | `cde7d368` (B1–B4) / `8eb6e3f9` (reconciled guard + merged suite) | all suite tests pass; `result=complete` |

## Behaviors (the reconciliation of the earlier B-drafts and the U-series)

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U-1592-1 | a born-green-certified BLOCKED contract converges — re-enters at refactor ONLY, `result=complete`, and the NEXT run re-enters at refactor only (the loop is dead) | issue #1592 SC-3 | DONE |
| U-1592-2 | regression: a NORMAL blocked resume (no green evidence) keeps the exact pre-#1592 window — verify-red re-drives, the #1007 verdict parks, `result=blocked` | issue #1592 constraint 2 | DONE |
| U-1592-3 | regression: green evidence WITHOUT its certified test file on disk keeps the exact pre-#1324 windows (the guard stays test-backed) | issue #1324 SC-4 | DONE |
| U-1592-4 | ported from B3: a normal blocked resume whose re-drive certifies red-first completes the full ladder (verify-red → make → refactor) | issue #1592 constraint 2 | DONE |
| U-1592-5 | ported from B4: unbacked green evidence against a drifting subject keeps the #1324 stale-artifacts stop and prescription, byte-for-byte | issue #1324 SC-4 | DONE |

## Pinned contracts the fix must not disturb

| Suite | Asserts |
|-------|---------|
| `test/plugins/tdd/bug_1542_born_green_contract_refactor_test.dart` | U-1542-1: a marker-less blocked contract with green-only evidence keeps the `verify-red → make → refactor` window; U-1542-4: the post-advancement `done` state re-enters at refactor only |
| `test/plugins/tdd/commands/bug_1411_born_green_hand_transition_test.dart` | the make `--born-green` transition (certification semantics untouched) |
| `test/plugins/tdd/commands/bug_1373_scaffolded_hand_off_driver_test.dart` | the not-certified-red stop arms (scaffolded / generic) |
| `test/plugins/tdd/bug_1324_resume_stale_artifacts_wedge_test.dart` | the #1324 guard (pending claims resume at make) |
| `test/plugins/tdd/commands/bug_1544_run_continue_after_blocked_test.dart` | the #1544 parked-blocked pass semantics |
