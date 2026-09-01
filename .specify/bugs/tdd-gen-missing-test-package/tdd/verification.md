# TDD Verification — tdd-gen-missing-test-package (#688)

- **Bug**: https://github.com/arrrrny/zuraffa/issues/688
- **Branch**: fix/688-tdd-gen-missing-test-package
- **Date**: 2026-09-01
- **Verdict**: PASS — the committed `dartDevDependencies` fix is correct and complete; verified end-to-end on a real pure-Dart project and pinned by regression tests.

## Counts

| Fact | Value |
|------|-------|
| Remediation checks (per the bug task) | 3/3 proved |
| New regression tests | 3 (map pins, dart-mode merge, no-duplicate) |
| Patcher suite | 8/8 passed |
| E2E reproduction | PASS (pure Dart project, real CLI) |
| Mutation sampling | 1 mutant (remove `test` from map) — killed |

## Remediation checklist (all PROVED, not assumed)

1. **`dartDevDependencies` includes `'test': '^1.25.0'`** — PROVED by
   `lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart:24` and
   pinned by the test `dartDevDependencies includes test ^1.25.0 and
   flutterDevDependencies does not`.
2. **`flutterDevDependencies` does NOT include `test`** (uses
   `flutter_test`, which re-exports it) — PROVED by the same test
   (`containsKey('test') is false`, `flutter_test: sdk: flutter` pinned).
3. **`ensure()` correctly merges missing packages** — PROVED for the
   Dart mode by `dart-mode ensure adds test (and no flutter_test) to a
   Dart project` (existing `lints` preserved, no `flutter_test` leak)
   and by `dart-mode ensure does not duplicate an existing test entry`.

## Red/green evidence

The production fix was already committed on master (commit 5babde82 added
the assessment; the `'test': '^1.25.0'` entry predates this branch), so the
TDD cycle for this bug is verify-the-fix:

- **Mutant (deliberate RED)**: commenting out `'test': '^1.25.0'` in
  `dartDevDependencies` makes the new regression tests FAIL
  (`dartDevDependencies includes test ^1.25.0 ...` fails) — the tests
  genuinely guard the fix. Restoring the entry returns the suite to
  8/8 green.
- **E2E (issue's literal reproduction path, pure Dart)**:
  1. temp project with a bare `pubspec.yaml` (no deps)
  2. `dart bin/zuraffa.dart tdd init --project <tmp>` → pubspec gains
     `test: ^1.25.0`; **no** `flutter_test` (Dart mode detected correctly)
  3. seed `specs/001-demo/` spec + 4-column test-list; `dart pub get`
  4. `dart bin/zuraffa.dart tdd gen --project <tmp> B-001 --feature 001-demo`
     → exit 0, test + subject written
  5. `dart test test/tdd/b_001_test.dart` → **compiles**; fails with an
     assertion-level `Expected: <42> / Actual: UnimplementedError`
     (honest red) — NOT `Couldn't resolve the package 'test'`.

## Traceability

| Issue criterion | Evidence |
|-----------------|----------|
| "generated tests were uncompilable out of the box" | E2E step 5: compiles, assertion failure only |
| "zfa setup / tdd init must include test for pure Dart" | `zfa tdd init` E2E step 2 (setup's baseline is Flutter-only by design and defers pure Dart to `tdd init`, which detects the mode via `_isFlutterProject`) |
| "Flutter projects unaffected" | `flutterDevDependencies` pinned without `test`; setup hardcodes the Flutter baseline only where it is correct |

## What was not audited

- `zfa setup` full scaffold was not run (it requires the Flutter SDK for
  `flutter create`; the environment is Dart-only). The Flutter-project
  behavior is covered at the patcher level (isFlutter: true path) and the
  pure-Dart setup path skips the baseline by design (`setup_command.dart`
  prints "Skipping TDD baseline (pure-Dart project; use zfa tdd init
  separately)"), so the issue's pure-Dart symptom is fully covered by the
  `tdd init` E2E.
- `flutter test` on a Flutter project was not executed (no Flutter SDK);
  the `flutter_test` re-export claim is verified structurally
  (`flutter_test` in the Flutter map, `test` absent), not by running
  Flutter.
- Mutation testing via `mutation_test` was not run for this surface; a
  deliberate single-mutant sample was used as recorded above.
