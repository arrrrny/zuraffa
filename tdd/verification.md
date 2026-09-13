# tdd.verify — Bug #1551 acceptance compose no-green-units hard stop

- **Verified**: 2026-09-13, this session, on
  `fix/1551-acceptance-compose-deadlock` (working tree, pre-push)
- **Toolchain**: Dart 3.13.3 (stable) on linux_x64
- **Scope**: the changed grading in `make_command.dart`, the new bug
  suite, the repaired A10 pin, then the targeted + chunked regression
  sweeps and a REAL end-to-end `zfa tdd run` red/green pair below.

## Verdict: PASS

## 1. Static analysis

```
dart analyze lib/src/plugins/tdd/commands/make_command.dart \
             test/plugins/tdd/commands/bug_1551_no_green_units_defers_test.dart \
             test/plugins/tdd/make_command_test.dart
→ No issues found!
```

## 2. The bug suite + repaired pin (REAL runs in this session)

```
dart test -j 1 test/plugins/tdd/commands/bug_1551_no_green_units_defers_test.dart
→ 00:26 +4: All tests passed!

dart test --preset=all -j 1 -N "A10: acceptance make with zero composable anchors" \
    test/plugins/tdd/make_command_test.dart
→ 00:08 +1: All tests passed!
```

RED evidence (pre-fix working tree — the two grading pins fail for the
right reasons while the two must-not-disturb guards pass):

```
dart test -j 1 test/plugins/tdd/commands/bug_1551_no_green_units_defers_test.dart
→ 00:26 +2 -2: Some tests failed.
  (1) Expected: contains 'make: behavior=A1 outcome=unexpressible ...'
      Actual:   '... make: behavior=A1 outcome=generation-error ...'
  (2) Expected: 'make: behavior=A1 outcome=unexpressible feature=001-barcode-scan'
      Actual:   'make: behavior=A1 outcome=generation-error feature=001-barcode-scan'
```

Master-side witness: A10 was ALREADY red on pristine master (proven via
`git stash` — the failure is not introduced by this branch):

```
Expected: contains 'make: behavior=A-101 outcome=unexpressible ...'
Actual:   '... outcome=generation-error ...' (after running a 2-step
          composition plan against a fake compose that exited 0)
```

## 3. End-to-end — a REAL `zfa tdd run` on a fresh fixture (red/green pair)

The issue's reproduction shape, minimized: fixture `barcode_probe`,
`specs/001-barcode-scan/tdd/test-list.md` with A1 (acceptance prose, no
entity → spec-052 compose lane) + U1 (func-intent unit prose → func
lane). Real CLI (AOT-compiled `bin/zfa.dart` so the nested analyzer
children survive the 4 GB container — no `ZFA_TDD_STEP_MEMORY_KB`
override needed at the AOT sizes), real gen / verify-red (`dart test`
in the fixture) / make / compose / refactor steps.

### RED — pristine master (4d1dafc): the deadlock, exactly as reported

```
[run] A1 gen -> ok
[run] A1 verify-red -> certified
[run] A1 make -> generation-error
zfa tdd run: step failed — behavior=A1 step=make outcome=generation-error
   zfa tdd make: behavior A1
      feature: 001-barcode-scan
      test: test/tdd/001-barcode-scan/a1_test.dart
   resume: fix the failing step, then re-run `zfa tdd run 001-barcode-scan`
run: feature=001-barcode-scan result=stopped pending=1 red=1 green=0 done=0 stopped_at=A1:make
=== run exit code: 1 ===
```

Every resume re-stops identically: the units are never reached. (The
issue's own log shows the identical shape at `pending=30`.)

### GREEN — this branch: defer, then compose at phase 2, complete

```
[run] A1 gen -> ok
[run] A1 verify-red -> certified
[run] A1 make -> unexpressible
[run] A1 make -> deferred (phase 2)
[run] U1 gen -> ok
[run] U1 verify-red -> certified
[run] U1 make -> green
[run] U1 refactor -> deferred (phase 2)
[run] A1 make -> green (phase 2)
[run] A1 refactor -> refactored (phase 2)
[run] U1 refactor -> clean (phase 2)
run: feature=001-barcode-scan result=complete pending=0 red=0 green=0 done=2
=== run exit code: 0 ===
```

The phase-2 make re-attempt composes A1 against the now-green U1 anchor
(the compose child's `composed` path) and certifies green. Loop
complete, exit 0. The driver, state machine, and compose surface are
byte-identical to master — only the make's grading changed.

## 4. Regression sweep (targeted suites, REAL runs)

```
dart test -j 1 test/plugins/tdd/commands/compose_command_test.dart \
    test/plugins/tdd/services/composition_planner_test.dart \
    test/plugins/tdd/services/composition_targets_test.dart \
    test/plugins/tdd/services/composition_targets_widget_939_test.dart \
    test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart
→ 00:23 +51: All tests passed!

dart test --preset=all -j 1 test/plugins/tdd/run_command_test.dart
→ 05:24 +50: All tests passed!          (the bug #625/#826 deferral contract)

dart test --preset=all -j 1 test/plugins/tdd/make_command_test.dart
→ 05:13 +34 -4: Some tests failed.
```

The 4 make-suite failures (U-829g, U-829h, A11/U17, A15) are
PRE-EXISTING on pristine master — proven by stashing this branch's
changes and running the identical selection on master:

```
git stash push -u; dart test --preset=all -j 1 -n "(U-829g|U-829h|A11/U17|A15 \()" \
    test/plugins/tdd/make_command_test.dart
→ 00:38 +0 -4: Some tests failed.  (identical set); git stash pop
```

Net: **no new failures; one pre-existing failure repaired** (A10).

## 5. Environment caveats

- The container is 4 GB RAM; the default 2 GiB per-step address-space
  ceiling killed the analyzer-heavy make child (`resource-limit`) when
  the CLI was invoked via `dart run bin/zfa.dart` (nested kernel
  compiles). The e2e pair therefore runs an AOT-compiled binary
  (`dart compile exe bin/zfa.dart`), which fits comfortably. This is a
  host-environment fact, not a product behavior — the unit pins run
  in-process and are unaffected.
- Kernel-cache hygiene between suite chunks: `rm -rf .dart_tool/test/`
  (per the repo's small-disk guidance in `dart_test.yaml`).
