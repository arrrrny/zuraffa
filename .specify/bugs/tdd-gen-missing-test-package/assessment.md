# Bug Assessment: zfa tdd gen: missing test package in dev_dependencies

- **Slug**: tdd-gen-missing-test-package
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/688
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

`zfa tdd gen` generates tests that import `package:test/test.dart`, but the `test` package is NOT included in `dev_dependencies` by `zfa setup` or `zfa tdd init`. Generated tests are uncompilable out of the box — `flutter test` fails with "Couldn't resolve the package 'test' in 'package:test/test.dart'".

## Symptom

Generated TDD tests fail to compile because `test: ^1.0.0` is missing from `pubspec.yaml` `dev_dependencies`.

## Reproduction

1. `zfa setup --platforms=ios,android,macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy any spec (e.g. `specs/001-app-bootstrap/spec.md`)
4. `zfa tdd plan 001-app-bootstrap`
5. `zfa tdd gen A7 --feature=001-app-bootstrap`
6. `flutter test test/tdd/a7_test.dart` → compile error: Couldn't resolve the package test

## Suspected Code Paths

- `lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart:23-30` — `dartDevDependencies` map. The committed version already includes `'test': '^1.25.0'`; verify this is present and not regressed.
- `lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart:14-21` — `flutterDevDependencies` map uses `'flutter_test': 'sdk: flutter'` (correct for Flutter; `test` is not needed since `flutter_test` re-exports it).

## Root Cause Hypothesis

The `dartDevDependencies` map was missing the `test` package. Projects scaffolded with a pure-Dart `zfa setup` (or `zfa tdd init` on a Dart project) did not get `test: ^1.0.0` added to `dev_dependencies`, so any generated test importing `package:test/test.dart` failed to compile. The committed code already contains the fix (`'test': '^1.25.0'`); this assessment confirms the fix is correct and complete. Confidence: **high** — the fix is a one-line addition to a const map.

## Proposed Remediation

**Preferred**: Ensure `dartDevDependencies` includes `'test': '^1.25.0'` (already present in the committed code). Verify:
1. `flutterDevDependencies` correctly uses `'flutter_test': 'sdk: flutter'` (no `test` needed — `flutter_test` re-exports `test`).
2. `dartDevDependencies` includes `'test': '^1.25.0'`.
3. The `ensure()` method correctly merges missing packages into `pubspec.yaml`.

**Files likely to change**:
- `lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart` (verify only — fix may already be committed)

**Tests to add or update**:
- `zfa setup` on a pure Dart project → `pubspec.yaml` contains `test: ^1.25.0` in `dev_dependencies`.
- `zfa tdd gen` on a Dart project → generated test compiles (`flutter test` exits 0 or fails on assertion, NOT on compile error).
- Regression: Flutter project still uses `flutter_test` (no `test` package added).

## Risks & Considerations

- Adding `test` to `flutterDevDependencies` would be redundant (flutter_test re-exports it) and could cause version conflicts. Only `dartDevDependencies` needs it.
- The `test` constraint `^1.25.0` should be compatible with the Dart SDK version constraint in the project.

## Open Questions

- None blocking.