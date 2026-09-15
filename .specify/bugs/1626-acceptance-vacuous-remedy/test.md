# Bug Test Audit: #1626 — acceptance vacuous-green refusal names the hand step

- **Slug**: 1626-acceptance-vacuous-remedy
- **Verified**: 2026-09-14, this session, REAL runs (no copied/stubbed
  transcripts) on `fix/1626-acceptance-vacuous-remedy`, post-fix working tree
- **Toolchain**: Dart 3.13.3 (stable) on linux_x64
- **Scope**: `lib/src/plugins/tdd/services/vacuous_guard.dart`,
  `lib/src/plugins/tdd/commands/make_command.dart`,
  `lib/src/plugins/tdd/commands/run_driver_core.dart`, the new suites
  `test/plugins/tdd/bug_1626_acceptance_vacuous_remedy_test.dart` +
  `test/plugins/tdd/bug_1626_acceptance_remedy_driver_test.dart`, and the
  re-pointed `test/plugins/tdd/bug_1488_acceptance_vacuous_green_test.dart`.

## Verdict: PASS

## 1. Static analysis (REAL run)

```
dart analyze <3 changed lib files + 3 test files>
→ No issues found!

dart analyze            (whole repo)
→ 111 issues found      (all `info`)
→ errors/warnings: 0
```

The changed/new files contribute ZERO analyzer findings (verified both before
and after `dart format`).

## 2. Format gate (CI contract)

```
dart format --output=none --set-exit-if-changed .
→ Formatted 2861 files (0 changed)   exit 0
```

`git diff --stat` carries no formatting churn — the only diffs are the fix,
the tests, and the bug/TDD artifacts.

## 3. The bug suites (REAL runs in this session)

```
dart test test/plugins/tdd/bug_1626_acceptance_vacuous_remedy_test.dart
→ 00:01 +4: All tests passed!

dart test --preset=all test/plugins/tdd/bug_1626_acceptance_remedy_driver_test.dart
→ 00:13 +2: All tests passed!

dart test --preset=all test/plugins/tdd/bug_1488_acceptance_vacuous_green_test.dart
→ 00:21 +5: All tests passed!
```

Pre-fix, the same suites produced the failures preserved verbatim in
`.specify/bugs/1626-acceptance-vacuous-remedy/red-evidence.md` (compile red on
the missing builder; A1/A4/D1 behavioral reds showing the looping traces
remedy).

## 4. The issue's acceptance criteria — PROVED by real runs

1. **`zfa tdd make` refusal distinguishes acceptance from unit rows** —
   PROVED: U-1626-a1 (acceptance → hand-step vocabulary) and U-1626-a3
   (unit → outcome-assertion vocabulary, no hand-step leakage) in the same
   session; A1 of the #1488 suite pins the acceptance branch.
2. **Acceptance refusal names the hand step** (outcome assertion OUTSIDE the
   capture, scenario runner implementation, attestation header,
   `zfa tdd make <id> --born-green`) — PROVED: the refusal output asserts all
   four elements, including the verbatim `handStepHeader(id)` line
   (`// zfa:tdd: A1:hand — hand step completed before first red certification
   (issue #1411)`), pinned at the make surface (U-1626-a1, #1488 A1/A4) AND on
   the real driver stop transcript (U-1626-d1).
3. **Unit/fallback rows keep the traces/re-plan/re-gen wording** — PROVED:
   U-1626-d2 (driver stop → the exact #1483 wording incl. the full test-list
   path), U-1626-a3 (make unit lane → unchanged wording); the pre-existing
   #1483 shape + driver suites, #1308, #1320 and #1518 suites pass UNCHANGED.
4. **The refusal includes the paths to both test and subject** — PROVED: the
   make surface asserts the registry-recorded project-relative posix paths
   (`test/a1_test.dart`, `lib/a1_subject.dart`; gen-recorded
   `lib/tdd/090-tdd-fixture/a_1488_subject.dart` in A4); the driver surface
   asserts both the namespaced test path and the conventional-layout subject
   fallback (`lib/tdd/<feature>/a1_subject.dart`).

## 5. Machine-contract preservation (real assertions, not inspection)

- `stopped_at=A1:make` preserved for the acceptance stop (U-1626-d1 asserts
  it AND `isNot(contains('stopped_at=A1:hand'))`).
- No green evidence is appended for a refused vacuous green (#1488 A1 asserts
  the cycle-log has no `## Cycle: A-1488 (green)`).
- The #1411 born-green catch-22 arms, the #1308 marker discrimination, the
  #1373 scaffolded arm and the #1323 hand-delta arm share the same
  `_driveBehavior` code path and are pinned green by the untouched
  `bug_1483_vacuous_green_remedy_driver_test.dart` (+3) and
  `bug_1518_gen_guard_warning_forward_driver_test.dart` suites.

## 6. Unrelated pre-existing failure (flagged, NOT introduced here)

`test/plugins/tdd/make_command_1036_test.dart` — A-1036a ("generation-error
after the func rewrite restores the throwing subject") fails `+4 -1` on the
CLEAN tree too (verified via `git stash` → same single failure → `git stash
pop`); the run ends `outcome=green` where the test expects a non-zero exit
through the #1587 build-skip path — a pipeline-behavior drift outside this
bug's surfaces (the test list is absent in that fixture, so the vacuous-green
arm this fix touches is never reached).

## 7. Disk housekeeping

Kernel caches cleaned before/after test phases (`rm -rf .dart_tool/test/`,
dart-test kernel temps); peak disk use stayed ~14% of the 9.9G volume.
