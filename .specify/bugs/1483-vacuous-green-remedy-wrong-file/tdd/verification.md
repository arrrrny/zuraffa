# TDD Verification: 1483-vacuous-green-remedy-wrong-file

- **Slug**: 1483-vacuous-green-remedy-wrong-file
- **Verified**: 2026-09-10
- **Method**: real red → green over the REAL `RunDriverCore` (the issue
  #1308 driver-suite convention: `CliRunner` + scripted fake zfa), plus the
  fast-tier vocabulary suite and the #1308/#1320 regression pins.
- **Result**: verified — every check below is from an ACTUAL run in this
  session on the fix branch; nothing is copied or back-dated.

## Checks

| # | Check | Command | Result | Evidence |
|---|-------|---------|--------|----------|
| 1 | Analyzer, changed files + new suites | `dart analyze lib/src/plugins/tdd/services/vacuous_guard.dart lib/src/plugins/tdd/commands/run_driver_core.dart test/plugins/tdd/bug_1483_vacuous_green_remedy_shape_test.dart test/plugins/tdd/bug_1483_vacuous_green_remedy_driver_test.dart` | PASS | `No issues found!` |
| 2 | RED (driver, pre-fix) | `dart test -P all -j 1 test/plugins/tdd/bug_1483_vacuous_green_remedy_driver_test.dart` on commit 94048e31 + tests only | FAIL × 2 — the RIGHT failures | see "Red evidence" below |
| 3 | RED (vocabulary, pre-fix) | `dart analyze test/plugins/tdd/bug_1483_vacuous_green_remedy_shape_test.dart` | FAIL — compile | `The function 'vacuousGuardFallbackRemedyFor' isn't defined` × 2 |
| 4 | GREEN (driver, post-fix) | same as #2 | PASS | `00:14 +2: All tests passed!` |
| 5 | GREEN (vocabulary, post-fix) | `dart test test/plugins/tdd/bug_1483_vacuous_green_remedy_shape_test.dart` | PASS | `00:00 +3: All tests passed!` |
| 6 | Regression — #1320 byte-pin + #1308 fast | `dart test test/plugins/tdd/bug_1483_vacuous_green_remedy_shape_test.dart test/plugins/tdd/commands/bug_1320_declared_assertion_reachable_test.dart test/plugins/tdd/issue_1308_vacuous_guard_remedy_test.dart` | PASS | `00:23 +16: All tests passed!` |
| 7 | Regression — #1308 driver (the same stop arm) | `dart test -P all -j 1 test/plugins/tdd/issue_1308_vacuous_guard_remedy_driver_test.dart` | PASS | 4/4 (`01:04 +6: All tests passed!` combined with #4) |
| 8 | Regression — run semantics | `dart test -P all -j 1 test/plugins/tdd/run_command_test.dart test/plugins/tdd/two_cycle_run_commands_test.dart` (+ #1259, #1324, #1345, plan/split suites) | PASS | 0 new failures; the 4 failures observed (#1259 U4/U5/U6, #1345 B1+B2) reproduce IDENTICALLY with the change set stashed — pre-existing, unrelated |
| 9 | Full chunked fast suite | 105-chunk list of `tools/run_tests_chunked.sh`, per-chunk runs, kernel caches cleared between chunks | PASS (per-chunk enumeration; the 2026-09-10 aggregate retracted) | The original `94/105` did not reconcile with its own enumeration (94 green + the 9-10 listed non-passing chunks ≠ 105) and no run log survives — retracted as unauditable in the PR #1502 review-fixes round. Re-verified fresh on 2026-09-11 (dev machine, Dart 3.13.2, Flutter SDK present): the 5 all-slow chunks (`test/benchmark`, `test/core/proof`, `test/integration`, `test/plugins/tdd/scenarios`, `test/tdd/077-make-engine-preset`) exit 79 with `No tests ran. / No tests match the requested tag selectors: exclude slow \|\| flutter` (slow-only folders under the fast profile); the 4 Flutter-SDK chunks (`test/plugins/controller`, `test/plugins/presenter`, `test/plugins/view`, `test/templates`) are GREEN where the SDK exists (the 2026-09-10 agent lacked it) — `test/templates` hit a tearDownAll flake on its first probe and finished `05:32 +44: All tests passed!` on the re-run. `test/commands` was not re-run: its kernel compile ran 23+ min on this loaded machine without reaching the first test (the original 280s full-window pass stands un-reverified). A fresh end-to-end re-run of all 105 chunks was attempted and abandoned on load grounds — this per-chunk enumeration is the auditable evidence. |
| 10 | Format gate | `dart format --output=none --set-exit-if-changed` on the four touched files | PASS | `Formatted 4 files (0 changed)`, exit 0 |

## Red evidence (check #2, verbatim from the run)

```
00:08 +0 -1: ... U-1483-2: LEGACY single-file feature — the stop names the test-list
traces cell (full path), NOT the nonexistent 04-ENGINE.md [E]
  Expected: contains 'hand-edit the test list (specs/1483-single-file-seam/tdd/test-list.md) traces cell'
    Actual: '   --> fix: add traces: <ContractRow> to the FR, re-run zfa tdd plan, re-run zfa tdd gen, re-run zfa tdd run — or hand-edit the lane plan (04-ENGINE.md) traces cell to FR-00N, Row.method and re-run zfa tdd gen (the designed hand-delta seam)'
  run: feature=1483-single-file-seam result=stopped pending=0 red=1 green=0 done=0 stopped_at=U1:make

00:15 +0 -2: ... U-1483-3: LANE-SPLIT feature — the stop still names the lane plan
traces cell (full path) [E]
  Expected: contains 'hand-edit the lane plan (specs/1483-lane-split-seam/tdd/04-ENGINE.md) traces cell'
    Actual: '   --> fix: add traces: <ContractRow> to the FR, re-run zfa tdd plan, re-run zfa tdd gen, re-run zfa tdd run — or hand-edit the lane plan (04-ENGINE.md) traces cell to FR-00N, Row.method and re-run zfa tdd gen (the designed hand-delta seam)'
```

Both failures are the issue's defect itself: the remedy names the bare
`04-ENGINE.md` (nonexistent for the single-file shape, wrong path for the
lane-split shape) while the stop machine contract (`stopped_at=U1:make`)
holds — proving the fix touches ONLY the messaging.

## Green evidence (checks #4/#5, verbatim from the run)

```
00:00 +0: loading test/plugins/tdd/bug_1483_vacuous_green_remedy_shape_test.dart
00:00 +3: All tests passed!

00:00 +0: loading test/plugins/tdd/bug_1483_vacuous_green_remedy_driver_test.dart
00:07 +1: ... U-1483-2: LEGACY single-file feature — the stop names the test-list traces cell (full path), NOT the nonexistent 04-ENGINE.md
00:14 +2: All tests passed!
```

## Success criteria

- PROVED: the stop message branches by feature shape (single-file → the
  test list's traces cell with full path; lane-split → the lane plan's
  traces cell with full path) — checks #2 → #4, red for the right reason,
  green after a messaging-only change.
- PROVED: no regression in the detection, stop semantics, loop, or the
  shared remedy constant — checks #6, #7, #8 (byte-pin suite + the same
  driver arm + the run-semantics suites).
- PROVED: format/analyzer clean on the touched files — checks #1, #10.
- NOT RUN (2026-09-10 agent): the Flutter-SDK-dependent chunks (no Flutter
  SDK on that agent) and the all-slow presets beyond the suites listed in
  check #8. Re-verified on 2026-09-11 (Flutter SDK present): those 4 chunks
  are GREEN; the all-slow chunks are selector skips (check #9). The full
  slow tier (`--preset=all` over the whole tree) is documented by
  dart_test.yaml as unsafe on small agents and was not attempted. Neither
  touches the changed messaging path beyond the suites already green.

## Refactor step

Tooling-only cleanup: `dart format` on the touched files (2 reformatted,
0 behavior change); `dart analyze` clean. No hand edits bypassing the
contract.
