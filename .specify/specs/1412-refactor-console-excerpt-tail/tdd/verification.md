# Verification: 1412-refactor-console-excerpt-tail

- **Date**: 2026-09-15
- **Branch**: `feat/1412-refactor-failure-console-excerpt-tail`
- **Base**: origin/master 2ac6b9d7 (Merge PR #1639)
- **Scope audited**: spec.md (SC-1..SC-6), plan.md design, tasks.md,
  analysis.md, tdd/test-list.md, tdd/cycle-log.md, changed code, changed
  tests, the fixture change and all its consumer suites.
- **Provenance**: every number below is from a REAL run in this session on
  the recorded command — nothing copied, stubbed, or back-dated. The kernel
  cache was cleared before the verify battery (`rm -rf .dart_tool/test/`).

## Verdict: VERIFIED for the #1412 fix surface — all six SCs proved; no
unrelated pre-existing failures observed in any run suite. The out-of-scope
surfaces NOT exercised (full `--preset=all` tree, integration/regression
heavy lanes) are listed at the end.

## 1. Red evidence (recorded before implementation)

Source: `tdd/cycle-log.md` (append-only).

- T001 (console excerpt): `dart test
  test/plugins/tdd/bug_1412_refactor_excerpt_tail_test.dart` →
  `00:24 +2 -2: Some tests failed.` — U-1412-1 and U-1412-2 failed on the
  pre-fix head excerpt (the captured stdout reproduced the issue's exact
  contradiction: `zfa tdd run: step failed — behavior=B-001 step=refactor`
  followed by the passing preflight block as the excerpt and NO failing-pass
  lines). U-1412-3/U-1412-4 passed pre-fix by design (regression pins).
- T003 (ownership remedy): `dart test --preset=all
  test/commands/build_command_unit_test.dart` → `00:00 +0 -1` — the file
  failed to LOAD with exactly 7 `Member not found` errors (2x
  `analyzerOffendingPaths`, 5x `analyzeGateRemedyLines`): the API under test
  did not exist at HEAD. One mechanical slip in the first green attempt
  (`capped` declared `List<String>` while joining) was caught by
  `dart analyze` as `return_of_invalid_type` and fixed BEFORE the green run.

## 2. Green evidence (after implementation)

- change 1: `lib/src/plugins/tdd/commands/run_driver_core.dart` ONLY —
  `_printOutputExcerpt` compacts non-empty lines and routes them through the
  `_outputTail` helper at the new `_consoleExcerptLines` (10) depth;
  `_outputTail` itself and its journal/cycle-log call sites untouched.
  → cycle T002: `dart test
  test/plugins/tdd/bug_1412_refactor_excerpt_tail_test.dart` →
  `00:24 +4: All tests passed!`; `dart analyze
  lib/src/plugins/tdd/commands/run_driver_core.dart` → `No issues found!`
- change 2: `lib/src/commands/build_command.dart` ONLY — new pure statics
  `analyzerOffendingPaths` + `analyzeGateRemedyLines`; `verifyAnalyzeOrFail`
  prints them under the byte-identical verdict line.
  → cycle T003: `dart test --preset=all
  test/commands/build_command_unit_test.dart` → `00:19 +55: All tests
  passed!` (includes the pre-existing #1035/#415 groups and the real-analyzer
  `verifyAnalyzeOrFail` integration test over this repo's own lib —
  106 info lints, gate passes).
- change 3 (test fixture): ADDITIVE `flood` outcome in the fake zfa's
  refactor stanza (251-line realistic transcript); no existing outcome
  touched — every fixture consumer suite re-run green (§4).

## 3. Test inventory (exact, real counts)

| suite | tier | tests | result |
|---|---|---|---|
| `test/plugins/tdd/bug_1412_refactor_excerpt_tail_test.dart` (NEW) | fast | 4 | `+4: All tests passed!` |
| `test/commands/build_command_unit_test.dart` (+7 new, 55 total) | slow | 55 | `+55: All tests passed!` |
| `test/plugins/tdd/issue_1590_progress_liveness_test.dart` (adjacent driver surface) | fast | — | passed (combined run) |
| `test/plugins/tdd/bug_1472_refactor_gate_errors_only_test.dart` (#1472 gate readers) | fast | — | passed (combined run) |
| `test/plugins/tdd/bug_1329_step_failure_diagnostics_test.dart` (hard-constraint regression) | slow | 7 | passed (combined run) |

Combined verify runs (the recorded commands):
- fast tier: `dart test test/plugins/tdd/bug_1412_refactor_excerpt_tail_test.dart
  test/plugins/tdd/issue_1590_progress_liveness_test.dart
  test/plugins/tdd/bug_1472_refactor_gate_errors_only_test.dart` →
  `00:29 +34: All tests passed!`
- slow tier: `dart test --preset=all
  test/plugins/tdd/bug_1329_step_failure_diagnostics_test.dart
  test/commands/build_command_unit_test.dart` → `00:56 +62: All tests
  passed!` (7 + 55)
- fixture consumers (the fixture is changed code, so its consumers are in
  scope): `dart test --preset=all` over `bug_1333_refactor_reproof_retry_test.dart`,
  `bug_1483_vacuous_green_remedy_driver_test.dart`,
  `bug_1483_vacuous_green_remedy_shape_test.dart`,
  `bug_1626_acceptance_remedy_driver_test.dart`,
  `issue_1308_vacuous_guard_remedy_driver_test.dart`,
  `commands/bug_1551_no_green_units_defers_test.dart` →
  `01:58 +23: All tests passed!`
  (one invocation slip, not a test failure: the first battery named
  `bug_1551` without its `commands/` directory — the loader's honest
  `Does not exist.` — re-run with the correct path, same session.)

## 4. Format gate (CI contract)

- `dart format` on the five changed files → 3 reformatted (whitespace-only;
  `run_driver_core.dart` and `tdd_fixture.dart` were already clean).
- Full-repo gate: `dart format --output=none --set-exit-if-changed .` →
  `Formatted 2866 files (0 changed)` — zero remaining formatting diffs.
- Post-format re-confirmation: `bug_1412_refactor_excerpt_tail_test.dart` →
  `+4: All tests passed!`; `build_command_unit_test.dart` →
  `+55: All tests passed!` (identical counts, post-format runs).

## 5. Success criteria — proved vs not

| SC | verdict | evidence |
|---|---|---|
| SC-1 (tail visible, head absent) | PROVED | U-1412-1 red → green (§1, §2) |
| SC-2 (honest `_outputTail` marker in console) | PROVED | U-1412-2 red → green — asserts `last 10 of 251 lines`, the helper's own wording |
| SC-3 (short transcript content-unchanged) | PROVED | U-1412-3 green before AND after the fix |
| SC-4 (recorded path byte-identical) | PROVED | U-1412-4 green before AND after + full #1329 suite green post-change (`+62` combined) |
| SC-5 (ownership remedy units) | PROVED | 7 new unit tests red (load failure) → green (+55 file total) |
| SC-6 (analyze/test/format clean) | PROVED | `No issues found!` on the 5 changed files; §3/§4 counts |

## 6. Honest flags

- NOT exercised (out of the cloud-agent scope per the verify contract —
  only what changed): the full `--preset=all` tree, the
  integration/regression/benchmark heavy lanes, and the `e2e` suites. The
  changed lib surfaces' other consumers (e.g. `run-engine`/`run-skin`
  commands) share the exact `_printOutputExcerpt` method the driver suites
  exercise; no separate lane run was performed.
- No unrelated pre-existing failures were observed in ANY run suite in this
  session.
- The excerpt depth (10) and the remedy cap (3 named files) are design
  constants from plan.md, asserted through behavior (`last 10 of 251`,
  `(+2 more)`) rather than by reading the constants.
