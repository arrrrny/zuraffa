# Cycle Log: zfa tdd realize — Mock→Real Swap (bug #915 slice: differential harness)

Append only. Newest last. This log covers the bug #915 fix
(`fix/915-differential-harness`): fixture parity between mock and real
adapters. The feature's broader realize work has no prior cycles here.

## Baseline

- suite: fast tier via `tools/run_tests_chunked.sh` (cloud protocol) —
  run on the fix branch after the change landed: 2,506 passed, 0 failed
  (67 chunks: 62 executed, 5 skipped — no fast-tier tests). Pre-change
  master baseline was not re-run on this agent; `dart analyze` findings
  (47, all in `examples/todo_tdd/`, Flutter SDK absent) were verified
  identical on stashed-clean master.
- commit: `ba7b45c`
- recorded: 2026-09-03, before the fix commit (tree clean at ba7b45c
  except the #915 change itself)

## Cycle 1: 915-R1..R4 — the differential harness (fixture contract, schema-parity checker, fault-injection parity, corpus rollup)

- test: `test/simulation/adapter_parity_checker_test.dart` (new; 21
  tests in the first red/green loop, +2 corpus-surface tests after the
  rollup surface landed)
- red: `dart test test/simulation/adapter_parity_checker_test.dart` ->
  loading failure, the harness did not exist:
  ```
  test/simulation/adapter_parity_checker_test.dart:386:22: Error: Undefined name 'AdapterParityChecker'.
  00:00 +0 -1: Some tests failed.
  Failing tests:
    test/simulation/adapter_parity_checker_test.dart: loading test/simulation/adapter_parity_checker_test.dart
  ```
  (26 compile errors, all `Undefined name` / `Undefined class` for the
  missing `adapter_parity_checker.dart` API — the RED evidence that the
  tests were written before the implementation.)
- green: `lib/src/plugins/tdd/services/adapter_parity_checker.dart`
  (fixture contract loader, structural shape comparison, fault parity,
  rollup), `lib/src/plugins/tdd/commands/diff_check_command.dart`
  (`zfa tdd diff-check`), registration in `tdd_command.dart`, parity
  rollup lines in `corpus_status_command.dart` /
  `corpus_audit_command.dart`, committed fixture pair
  `specs/892-tdd-realize-mock-swap/tdd/fixtures/rest-quotes/{mock,real}.json`.
  Suite -> 23 passed, 0 failed (~2s). Full fast tier -> 2,506 passed,
  0 failed.
- refactor: `dart format` on the changed files (0 changed on re-run);
  analyzer clean on all changed files; no hand-edits after green except
  formatting and one lint fix (`unnecessary_brace_in_string_interps`)
  caught by `dart analyze` before the suite re-run.
- verification: deliberate mutants M1-M3 (below) each caught, restored,
  suite re-run green; `/speckit.tdd.verify` wrote `tdd/verification.md`.
- commit: the fix commit lands immediately after this audit, carrying
  the test and implementation together (repo convention, tdd-profile
  Conventions).
