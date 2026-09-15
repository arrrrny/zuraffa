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
