# Bug Assessment: zfa tdd gen: missing test package in dev_dependencies

- **Slug**: zfa-tdd-missing-test-package
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/688
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

`zfa tdd gen` generates test files that contain `import 'package:test/test.dart'` (confirmed in `behavior_test_writer.dart:70`). However, neither `zfa setup` nor `zfa tdd init` adds the `test` package to `dev_dependencies` for Flutter projects. The `PubspecDevDependenciesPatcher` used by both commands has `flutterDevDependencies` which lists `flutter_test` (SDK-bundled), `mocktail`, `build_runner`, `json_serializable`, `coverage`, and `mutation_test` — but omits `test`. This makes every generated TDD test file uncompilable immediately after setup.

## Symptom

Running `flutter test` on a generated TDD test file fails at compile time with: `Couldn't resolve the package 'test' in 'package:test/test.dart'`. The `test` package is absent from `pubspec.yaml`'s `dev_dependencies` in a Flutter project.

## Reproduction

1. `zfa setup --platforms=ios,android,macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy any spec (e.g. `specs/001-app-bootstrap/spec.md`)
4. `zfa tdd plan 001-app-bootstrap`
5. `zfa tdd gen A7 --feature=001-app-bootstrap`
6. `flutter test test/tdd/a7_test.dart` → compile error: `Couldn't resolve the package 'test' in 'package:test/test.dart'`

## Suspected Code Paths

- `lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart:14-21` — `flutterDevDependencies` map is missing `'test'`. `dartDevDependencies` (line 23-30) correctly includes `'test': '^1.25.0'`.
- `lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart:132-134` — `zfa tdd init` calls `PubspecDevDependenciesPatcher(isFlutter: isFlutter).ensure()`, which uses the broken `flutterDevDependencies`.
- `lib/src/commands/setup_command.dart:454` — `zfa setup` also calls `PubspecDevDependenciesPatcher(isFlutter: true).ensure()`, same broken path.
- `lib/src/plugins/tdd/services/behavior_test_writer.dart:70` — generates `import 'package:test/test.dart'` in every TDD test, which requires the `test` package as a dev_dependency.

## Root Cause Hypothesis

**Confidence: high.** `PubspecDevDependenciesPatcher.flutterDevDependencies` intentionally excludes `test` under the (incorrect) assumption that `flutter_test` satisfies all test imports. However, `flutter_test` provides `package:flutter_test/flutter_test.dart`, not `package:test/test.dart`. The `package:test` package is the standalone Dart test runner, which `behavior_test_writer.dart` uses for its generated test scaffold. The omission exists in both `zfa setup` and `zfa tdd init` because they share the same patcher writer.

## Proposed Remediation

**Preferred**: Add `'test': '^1.25.0'` to `PubspecDevDependenciesPatcher.flutterDevDependencies` in `lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart`. This single-line addition fixes both `zfa setup` and `zfa tdd init` since they both delegate to this writer.

**Files likely to change**:
- `lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart`

**Tests to add or update**:
- Add a test case asserting that `flutterDevDependencies` includes `test` (e.g. in `pubspec_dev_dependencies_patcher_test.dart` or the relevant smoke test suite).
- Add a TDD smoke test that runs `zfa tdd gen` in a temp Flutter project and verifies `flutter pub get` succeeds without errors.

## Risks & Considerations

- Adding `test` to `flutterDevDependencies` introduces a second test runner (the standalone `test` package alongside `flutter_test`). Both are standard Flutter/Dart practice; the risk is low.
- Existing projects that already ran `zfa setup` will need `zfa tdd init` (or a manual `flutter pub add --dev test`) to pick up the new dependency. This is a one-time migration.
- No API or behavior change to generated test code — this is purely a dependency fix.

## Open Questions

- None remaining after code inspection.
