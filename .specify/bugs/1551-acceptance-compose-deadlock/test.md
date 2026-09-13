# Test — #1551 compose no-green-units precondition defers (red → green)

## Suite

`test/plugins/tdd/commands/bug_1551_no_green_units_defers_test.dart`
(fast tier — drives the public CLI surface in-process via `CliRunner`
against a real temp fixture; the compose child transcript is the
production bytes, the argv/exit dispatch is the established fake-bin
pattern). Four pins:

| id | pin | assertion |
| -- | --- | --------- |
| A-1551-1 | the #1551 mapping | an acceptance make whose compose step reports `no-green-units` grades `unexpressible` — never `generation-error`; the stop names `#1551` + `phase 2`; exits non-zero (the unexpressible honesty class); the certified-red subject survives byte-identically (#1036); no green evidence |
| A-1551-2 | the loop contract feed | the FINAL `make: behavior=...` summary line — the kv contract the run driver's StepRunner parses — carries exactly `outcome=unexpressible` (the bug #625/#826 deferral token) |
| A-1551-3 | the must-not-break guard | the SAME make composes and certifies green once the unit IS green (the #1512 surface unbroken; compose + build both executed, green evidence appended) |
| A-1551-4 | the surface guard | a direct `zfa tdd compose` on the fresh-project shape keeps its honest `no-green-units` stop: exit 1, summary line, no subject rewrite |

## RED (pre-fix working tree, i.e. the master grading)

```
dart test -j 1 test/plugins/tdd/commands/bug_1551_no_green_units_defers_test.dart
→ 00:26 +2 -2: Some tests failed.
Failing:
  bug #1551 (1) ... grades `unexpressible` — not `generation-error`
      Expected: contains 'make: behavior=A1 outcome=unexpressible ...'
      Actual:   '... make: behavior=A1 outcome=generation-error ...'
  bug #1551 (2) ... the bug #625 deferral token ...
      Expected: 'make: behavior=A1 outcome=unexpressible feature=001-barcode-scan'
      Actual:   'make: behavior=A1 outcome=generation-error feature=001-barcode-scan'
```

Pins 3 and 4 passed pre-fix (they guard the surfaces the fix must NOT
disturb — red for the right reasons, exactly the two grading pins).

Additional master-side red evidence:

- `make_command_test.dart` **A10** ("acceptance make with zero composable
  anchors honest-stops unexpressible") was ALREADY FAILING on pristine
  master (proven via `git stash`): the #1512 grading turned its
  `outcome=unexpressible` expectation into an observed
  `outcome=generation-error`. The slow tier excludes it by default,
  which is why the regression shipped unnoticed.
- End-to-end RED run on a fresh fixture (pristine master CLI, real
  `zfa tdd run 001-barcode-scan`): `A1 make -> generation-error` →
  `result=stopped pending=1 red=1 green=0 done=0 stopped_at=A1:make`,
  exit 1 (§3 of `tdd/verification.md`).

## GREEN (post-fix)

```
dart test -j 1 test/plugins/tdd/commands/bug_1551_no_green_units_defers_test.dart
→ 00:26 +4: All tests passed!
```

A10 re-faithed (the fake compose step now emits the REAL production
transcript — `no green unit subjects ...` + the `outcome=no-green-units`
summary line — and exit 1; the assertions updated to the corrected
#1551 deferral contract):

```
dart test --preset=all -j 1 -N "A10: acceptance make with zero composable anchors" \
    test/plugins/tdd/make_command_test.dart
→ 00:08 +1: All tests passed!
```

End-to-end GREEN run on a fresh fixture (this branch's CLI, real
`zfa tdd run 001-barcode-scan`): A1 defers, U1 goes green, A1 composes
green at phase 2, refactors clean, `result=complete ... done=2`, exit 0
(§3 of `tdd/verification.md`).

## Regression sweep

- compose surface + composition services + bug_1512 pins: 51/51 pass.
- `run_command_test.dart` (the driver deferral contract, bug 625/826):
  50/50 pass.
- `make_command_test.dart` (slow tier): 34 pass + the 4 pre-existing
  master failures (U-829g, U-829h, A11/U17, A15 — proven pre-existing by
  running them on a stashed pristine master: identical `+0 -4`), A10 now
  repaired. NO new failures.
- `dart analyze` on the three changed files: No issues found.
