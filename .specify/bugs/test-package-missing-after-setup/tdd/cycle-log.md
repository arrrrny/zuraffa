# Cycle Log: test package missing from dev_dependencies after zfa setup (bug #716)

Append only. Newest last. Every entry's `red` block is the evidence that the
test existed and failed before the implementation.

## Baseline

- suite: `dart test --preset=all test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart`
  -> 8 passed, 0 failed (pre-change file state; bug #688 contract pinned the
  buggy behavior — `flutterDevDependencies` NOT containing `test`)
- e2e baseline toolchain: Dart SDK 3.13.3 (standalone), Flutter 3.47.2 stable
  (bundles Dart 3.13.2)
- commit: `029f6785`
- recorded: cycle 0, before any change

## Cycle 1: U1 + U2 — the Flutter dev_dependencies template omits `test`

- test: `test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart`,
  new group `bug #716 — Flutter projects get the test package` (new) and the
  stale bug #688 contract test relaxed to pin the corrected behavior
- red (unit):
  `dart test --preset=all test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart --plain-name "bug #716"`
  ->
  ```
  Expected: '^1.0.0'
    Actual: <null>
  00:00 +0 -2: Some tests failed.
  ```
  (2 failed: `flutterDevDependencies includes test ^1.0.0`,
  `flutter-mode ensure adds test to a fresh Flutter pubspec`; the
  does-not-duplicate test passed trivially — nothing to duplicate yet)
- red (e2e, same commit state, scratch project `/home/z/my-project/repro716`):
  `zfa setup --platforms=android --no-git repro716` from source at `029f6785`;
  generated pubspec had NO `test:` entry (matches the issue's YAML verbatim);
  `zfa tdd init` + `zfa tdd plan 001-app-bootstrap` + `zfa tdd gen A1`;
  `flutter test test/tdd/a1_test.dart` ->
  ```
  Error: Couldn't resolve the package 'test' in 'package:test/test.dart'.
  test/tdd/a1_test.dart:16:8: Error: Not found: 'package:test/test.dart'
  test/tdd/a1_test.dart:30:7: Error: Method not found: 'expect'.
  ```
  Full capture: `evidence/red-e2e.md`
- green: `lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart` —
  added `'test': '^1.0.0'` to `flutterDevDependencies` (the template consumed
  by BOTH `setup_command.dart:478` and tdd `init_command.dart:138`);
  updated the stale counts/contract in the test file (6→7, 4→5, #688 group)
- green (unit): same file command -> `00:00 +11: All tests passed!`
- green (e2e): fresh project re-setup from the fixed source ->
  `[6/7] ... (added: test: ^1.0.0, mocktail: ^1.0.0, coverage: ^1.6.0,
  mutation_test: ^1.0.0)`; `flutter pub get` resolves `test 1.31.1` sharing
  `test_api 0.7.12` with `flutter_test` (no conflict);
  `flutter test test/tdd/a1_test.dart` COMPILES and runs to the designed
  honest-red (`UnimplementedError: subject_a1 not implemented` assertion);
  `flutter test` day-zero baseline: smoke test green (+1), a1 honest-red (-1).
  Full capture: `evidence/green-e2e.md`
- refactor: none required (one map entry + comment)
- commit: `fffd50ad`

## Notes and deviations

- The issue's `zfa tdd gen A7` used the reporter's own spec which planned an
  A7 behavior; the in-session reproduction used the repo spec
  `specs/002-add-toggle-method` copied to `specs/001-app-bootstrap`, which
  plans A1–A6/U1–U8, so the generated acceptance test is `a1_test.dart`.
  Identical template, identical `package:test/test.dart` import, identical
  failure mode.
- The reproduction scratch project lives outside the repo clone
  (`/home/z/my-project/repro716`) and is disposable; its captured outputs are
  committed under `evidence/`.
- `pubspec.lock` churn from a local pub mirror was reverted to keep the PR
  minimal (unrelated to the bug).
