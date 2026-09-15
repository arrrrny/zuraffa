# Cycle Log: 1412-refactor-console-excerpt-tail

Append-only. One entry per TDD cycle (spec 046 / TDD extension v1.1.2).

## Cycle: T001 (red)

- behavior: R1, R2
- kind: red
- classification: assertionFailure (the intended reds — the console excerpt
  contract is the pre-fix head)
- criterion: SC-1, SC-2 (spec.md)
- test: `test/plugins/tdd/bug_1412_refactor_excerpt_tail_test.dart` —
  U-1412-1 (failing-pass tail visible, preflight head absent),
  U-1412-2 (honest `_outputTail` marker in the console)
- command: `dart test test/plugins/tdd/bug_1412_refactor_excerpt_tail_test.dart`
- exit: 1
- at: 2026-09-15T15:05:00Z
- output:
```
00:11 +0 -2: Some tests failed.
Failing tests:
  test/plugins/tdd/bug_1412_refactor_excerpt_tail_test.dart: U-1412-1: ...
  test/plugins/tdd/bug_1412_refactor_excerpt_tail_test.dart: U-1412-2: ...
```
- reading: the pre-fix console excerpt reproduced the issue's exact
  contradiction — the captured stdout around the failure shows the take(3)
  head as the excerpt:
```
[run] B-001 refactor -> failed
zfa tdd run: step failed — behavior=B-001 step=refactor outcome=failed
   zfa tdd refactor: preflight suite
      command: dart test {file} --plain-name "{name}"
      preflight exit: 0
   resume: fix the failing step, then re-run `zfa tdd run 1412-excerpt-tail`
```
  — the failing pass (`pass: build`, `exit: 1`, `pass "build" failed —
  misfire-stop.`) is nowhere in the run output. R2's marker wording is
  absent for the same reason (the head path never truncates honestly).
- fixture note: the fake zfa's refactor stanza gained an ADDITIVE `flood`
  outcome (mirroring gen's #1329 flood): 3 preflight head lines + 241 noise
  lines + the 7-line failing-pass block = 251 captured lines, exit 1, so
  head-vs-tail is observable on one transcript and the recorded 200-line
  tail boundary (U-1412-4) is provable on the SAME shape. One test-writing
  slip was caught mid-cycle (the boundary mapping ignored the 3-line head
  offset: transcript line 52 is noise line 49, not 52 — unlike gen's flood,
  which has no head offset) and fixed BEFORE recording this entry; the
  recorded reds are the intended excerpt-contract failures, no fixture noise.

## Cycle: T001-pins (green-before-write by design)

- behavior: R3, R4 (+ P1, P2 from the test list)
- kind: green
- classification: null (regression pins, expected green pre-fix)
- criterion: SC-3, SC-4 (spec.md)
- command: `dart test test/plugins/tdd/bug_1412_refactor_excerpt_tail_test.dart`
- exit: 1 (the FILE fails on R1/R2; R3/R4 themselves passed: `+2 -2`)
- at: 2026-09-15T15:05:00Z
- output:
```
00:11 +0 -2: U-1412-3: ... (passed)
00:18 +1 -2: U-1412-4: ... (passed)
00:24 +2 -2: Some tests failed.
```
- reading: U-1412-3 (short transcript prints verbatim, no marker) and
  U-1412-4 (the cycle-log error entry keeps `200 of 251` with the noise
  window 49..241, and the journal error object carries the tail) are green
  BEFORE the fix — they pin the unchanged-in-content cases and the hard
  constraint (recorded path byte-identical), so any post-fix drift on the
  recorded path fails loudly. The pre-existing #1329 suite (P1) and the
  #1472 gate suite (P2) stay green on master by design and are re-run at
  verification.

## Cycle: T002 (green)

- behavior: R1, R2
- kind: green
- classification: null
- criterion: SC-1, SC-2 (spec.md)
- test: `test/plugins/tdd/bug_1412_refactor_excerpt_tail_test.dart` — full file
- command: `dart test test/plugins/tdd/bug_1412_refactor_excerpt_tail_test.dart`
- exit: 0
- at: 2026-09-15T15:20:00Z
- output:
```
Analyzing run_driver_core.dart...
No issues found!
00:24 +4: All tests passed!
```
- reading: the console excerpt now routes through `_outputTail(maxLines: 10)`
  (the issue #1329 helper, reused verbatim — R2's marker wording proves the
  reuse) after compacting non-empty lines; `_outputTail` itself and its
  journal/cycle-log call sites are untouched (R4 stayed green on the same
  run — the hard constraint holds). The failing refactor's console now shows
  the failing-pass block (`pass: build`, `exit: 1`, `pass "build" failed —
  misfire-stop.`) with the honest `last 10 of 251 lines` marker, and the
  preflight head is gone.

## Cycle: T003 (red)

- behavior: R5, R6
- kind: red
- classification: compileError (the API under test does not exist yet)
- criterion: SC-5 (spec.md)
- test: `test/commands/build_command_unit_test.dart` — groups
  `analyzerOffendingPaths (issue #1412)` and
  `analyzeGateRemedyLines (issue #1412)` (7 tests)
- command: `dart test --preset=all test/commands/build_command_unit_test.dart`
- exit: 1
- at: 2026-09-15T15:35:00Z
- output:
```
test/commands/build_command_unit_test.dart:762:36: Error: Member not found:
  'BuildCommand.analyzerOffendingPaths'.
test/commands/build_command_unit_test.dart:787:36: Error: Member not found:
  'BuildCommand.analyzeGateRemedyLines'.
  ... (7 Member-not-found errors: 2x analyzerOffendingPaths,
   5x analyzeGateRemedyLines)
00:00 +0 -1: Some tests failed.
  (file failed to load)
```
- reading: the ownership extractor and the remedy builder do not exist at
  HEAD — `verifyAnalyzeOrFail` hardcodes the single "Fix the generator"
  remedy regardless of the offenders' ownership. A first green attempt
  slipped mechanically (`capped` declared `List<String>` while joining —
  caught by `dart analyze` as return_of_invalid_type, fixed before the
  green run below); the recorded red is the intended undefined-API load
  failure.

## Cycle: T003 (green)

- behavior: R5, R6
- kind: green
- classification: null
- criterion: SC-5 (spec.md)
- test: `test/commands/build_command_unit_test.dart` — full file
  (55 tests: 7 new + 48 pre-existing incl. the real-analyzer
  `verifyAnalyzeOrFail` integration test)
- command: `dart test --preset=all test/commands/build_command_unit_test.dart`
- exit: 0
- at: 2026-09-15T15:40:00Z
- output:
```
Analyzing build_command.dart...
No issues found!
106 issues found.
   dart analyze: 106 info lints (style) — info severity does not fail the
   analyze gate (issue #1035).
00:19 +55: All tests passed!
```
- reading: the verdict's count line is byte-identical (only the remedy lines
  under it changed — the `#1407`/`#1472` pattern readers are untouched), the
  generated-only and unparseable cases keep the existing "Fix the generator"
  wording, and the hand-authored case names the files with the matched
  remedy. The pre-existing #1035/#415 groups stay green on the same run.
