# tdd.verify — Bug #1626 acceptance vacuous-green refusal names the hand step

- **Verified**: 2026-09-14, this session, on
  `fix/1626-acceptance-vacuous-remedy` (working tree, pre-push)
- **Toolchain**: Dart 3.13.3 (stable) on linux_x64
- **Scope**: `lib/src/plugins/tdd/services/vacuous_guard.dart`,
  `lib/src/plugins/tdd/commands/make_command.dart`,
  `lib/src/plugins/tdd/commands/run_driver_core.dart`, and the suites
  `test/plugins/tdd/bug_1626_acceptance_vacuous_remedy_test.dart` (new),
  `test/plugins/tdd/bug_1626_acceptance_remedy_driver_test.dart` (new),
  `test/plugins/tdd/bug_1488_acceptance_vacuous_green_test.dart` (re-pointed).

## Verdict: PASS

## 1. Static analysis

```
dart analyze <3 changed lib files + 3 test files>
→ No issues found!          (re-checked after dart format)

dart analyze            (whole repo)
→ 111 issues found      (all `info`)
→ errors/warnings: 0
```

Zero findings from the changed/new files; the whole-repo info count is the
pre-existing baseline drift, not this change.

## 2. The bug suites (REAL runs in this session)

```
dart test test/plugins/tdd/bug_1626_acceptance_vacuous_remedy_test.dart
→ 00:01 +4: All tests passed!

dart test --preset=all test/plugins/tdd/bug_1626_acceptance_remedy_driver_test.dart
→ 00:13 +2: All tests passed!

dart test --preset=all test/plugins/tdd/bug_1488_acceptance_vacuous_green_test.dart
→ 00:21 +5: All tests passed!
```

Total: 11 passed, 0 failed, across the fast tier and the slow driver tier.
Red evidence for the SAME suites (pre-fix) is preserved verbatim in
`.specify/bugs/1626-acceptance-vacuous-remedy/red-evidence.md`.

## 3. Format gate

```
dart format --output=none --set-exit-if-changed .
→ Formatted 2861 files (0 changed)   exit 0
```

## 4. REQUIRED checks — the issue's success criteria PROVED by real runs

- **Criterion 1 (the refusal distinguishes acceptance from unit rows)**:
  the acceptance refusal prints the hand-step vocabulary and the unit refusal
  prints the pre-existing lane wording in the SAME session (U-1626-a1 vs
  U-1626-a3), with `isNot` guards pinning no cross-lane leakage both ways.
- **Criterion 2 (the hand step is named)**: the refusal asserts all four
  elements — "write an assertion on the observable outcome OUTSIDE the
  capture", "implement the scenario runner in", the verbatim attestation
  header `// zfa:tdd: A1:hand — hand step completed before first red
  certification (issue #1411)` (via `handStepHeader(id)`), and
  "`zfa tdd make A1 --born-green`" — at the make surface (U-1626-a1;
  #1488 A1/A4) AND on the real RunDriverCore stop transcript (U-1626-d1,
  fake-zfa scripted `zfa tdd run`).
- **Criterion 3 (unit/fallback rows keep the traces wording)**: U-1626-d2
  pins the exact #1483 stop line (`hand-edit the test list
  (specs/<feature>/tdd/test-list.md) traces cell`); U-1626-a3 pins the make
  unit-lane wording; the untouched #1483 shape + driver suites, #1308,
  #1320 (U8) and #1518 (seam + forward-driver) suites all pass.
- **Criterion 4 (both paths in the refusal)**: the make surface asserts the
  registry-recorded paths (`test/a1_test.dart`, `lib/a1_subject.dart`,
  gen-recorded `lib/tdd/090-tdd-fixture/a_1488_subject.dart` in A4); the
  driver surface asserts the namespaced test path and the conventional
  subject fallback (`lib/tdd/<feature>/a1_subject.dart`) when no registry
  record exists. Both resolution modes are pinned by real runs.

## 5. Machine-contract preservation (real assertions, not inspection)

- `stopped_at=A1:make` preserved for the acceptance stop — asserted
  positively AND `isNot(stopped_at=A1:hand)` (U-1626-d1).
- No green evidence for a refused vacuous green (#1488 A1 asserts the
  cycle-log stays clean).
- The #1488 gate scope, the #1512 marker-absence discipline, the #1411
  born-green mechanics and the #1308 marker discrimination are untouched —
  pinned green by the UNMODIFIED assertions in the #1488 suite (A2/A3/U1),
  bug_1259_vacuous_green_test.dart, and the #1483/#1518 suites.

## 6. Unrelated pre-existing failure (flagged, NOT introduced here)

`test/plugins/tdd/make_command_1036_test.dart` — A-1036a fails `+4 -1`
identically on the CLEAN tree (verified via `git stash` round-trip); the
fixture has no test list, so the vacuous-green arm this fix touches is never
reached — pipeline-behavior drift outside this bug's surfaces.

## 7. Housekeeping

Dart-test kernel caches cleaned before/after phases; peak disk ~14% of a
9.9G volume.
