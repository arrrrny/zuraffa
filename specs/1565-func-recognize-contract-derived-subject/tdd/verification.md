# TDD Verification — SPEC 1565 (func recognizes the contract-derived subject)

**Feature:** 1565-func-recognize-contract-derived-subject
**Issue:** #1565
**Date:** 2026-09-13

## Red → Green evidence

### RED (recorded before implementation, tree at b621f38b + new tests only)

```
$ dart test test/plugins/tdd/services/subject_provenance_1565_test.dart \
            test/plugins/tdd/commands/func_command_1565_test.dart \
            test/plugins/tdd/services/generation_planner_1565_test.dart
  subject_provenance_1565_test.dart [E] — loading failed:
      Error: Undefined name 'SubjectProvenance' (the service does not exist yet)
  generation_planner_1565_test.dart [E] — loading failed:
      Error: No named parameter with the name 'skipFuncScaffold'
  func_command_1565_test.dart U-1565-1/-2/-6 — FAILED (the bug itself):
      Expected: exitCode 0
        Actual: 1
      out: zfa tdd func: subject at "lib/b_001_subject.dart" carries an
           UnimplementedError in an unrecognized shape — refusing to rewrite
           a file this command did not generate.
00:05 +4 -5: Some tests failed.

$ dart test --preset=all test/plugins/tdd/make_command_1565_test.dart
  U-1565-10 FAILED pre-fix:
     plan: 2 step(s)                      ← func scheduled for the
     ...                                     contract-derived subject
  make: behavior=U1 outcome=generation-error
```

The func-level reds reproduce the issue's symptom byte-for-byte; the
planner/make reds are the missing-API evidence of the absent scheduling fix.

### GREEN (after implementation)

```
$ dart test test/plugins/tdd/services/subject_provenance_1565_test.dart \
            test/plugins/tdd/commands/func_command_1565_test.dart \
            test/plugins/tdd/services/generation_planner_1565_test.dart
00:18 +22: All tests passed!

$ dart test --preset=all test/plugins/tdd/make_command_1565_test.dart
00:18 +2: All tests passed!
```

## Regression evidence

| Suite | Result |
| ----- | ------ |
| `test/plugins/tdd/commands/func_command_test.dart` (U-F1..F9 — legacy scaffolds + the U-F7 refusal pin) | All passed |
| `test/plugins/tdd/commands/func_convergent_test.dart` | All passed |
| `test/plugins/tdd/commands/func_declared_signature_test.dart` (declared-dummy path — SC-4) | All passed |
| `test/plugins/tdd/commands/bug_1517_func_stale_honest_red_header_test.dart` | All passed |
| `test/plugins/tdd/services/` (full fast tier, incl. all generation_planner_* suites) | +960 All passed |
| `test/plugins/tdd/commands/` (full fast tier) | +540 All passed |
| func + planner + provenance verification bundle | +46 / +21 All passed |

### Known pre-existing failures (NOT introduced by this change)

Slow-tier suites that drive the real `gen`/`make` subprocesses against
fixture entity trees fail identically on the CLEAN baseline (verified by
`git stash` → re-run → `git stash pop` at b621f38b):

```
bug_1259_vacuous_green_test.dart U4/U5/U6:
  PathNotFoundException: Cannot open file, path =
  'lib/tdd/090-tdd-fixture/u_100_subject.dart' (OS Error: No such file or
  directory)                      ← fails on the clean tree too

make_command_test.dart U-829g / U-829h / A10 / A11-U17 / A15:
  same fixture-environment class  ← fails on the clean tree too
```

The 147 "loading" failures from running the entire `test/plugins/tdd/`
directory in ONE invocation are the documented kernel-cache overflow
(`dart_test.yaml`: "Even the fast tier, run as one `dart test test`
invocation, compiles the whole tree's kernel into a ~6.5 GB cache that
overflows small disks. On cloud/disposable agents use the chunked runner
instead"). Spot-checked suites (bug_1045, bug_1159, bug_1483, bug_846) all
pass (+24) when run after a cache clear.

## Static analysis

```
$ dart analyze lib/src/plugins/tdd/services/subject_provenance.dart \
               lib/src/plugins/tdd/services/generation_planner.dart \
               lib/src/plugins/tdd/commands/func_command.dart \
               lib/src/plugins/tdd/commands/make_command.dart
Analyzing ... No issues found!

$ dart analyze <the four new test files>   → No issues found! (after one
  unused-import removal; the tree-wide analyzer is untouched by this change)
```

## Formatting

```
$ dart format --set-exit-if-changed <all changed files>
Formatted 8 files (0 changed) in 0.07 seconds.   → exit 0
```

## Constraint audit (FR-4)

- `gen_command.dart`, `subject_writer.dart` (gen lane + provenance header):
  UNTOUCHED (git diff confirms).
- `wire_command.dart`, the contract lane, the run state machine: UNTOUCHED.
- func for legacy plain-function stubs: unchanged (U-F1..F9 + U-1565-7 green).
- The scalar contract-derived declared-dummy path: unchanged
  (func_declared_signature_test + U-1565-11 green).
- The hand-authored refusal guard: unchanged (U-F7 + U-1565-3/-4 green).
