# Bug Assessment: [zfa tdd init] smoke test generated for pure Dart package uses Flutter imports

- **Slug**: tdd-init-smoke-test-flutter-imports
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/664
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

`zfa tdd init` generates a Flutter-specific `test/bootstrap_smoke_test.dart` even when run against a pure Dart package. The generated smoke test imports `package:flutter_test/flutter_test.dart` and `package:$appName/app.dart`, neither of which exist in a pure Dart project, so `dart test` fails immediately on the very first run after init ("Couldn't resolve the package 'flutter_test'").

## Symptom

Fresh pure-Dart packages fail `dart test` right after `zfa tdd init` because the generated smoke test uses Flutter-only imports.

## Reproduction

1. Create a fresh pure Dart package (no `flutter:` key in `pubspec.yaml`, no `lib/app.dart`)
2. Run `zfa tdd init`
3. Observe `test/bootstrap_smoke_test.dart` created with Flutter imports
4. Run `dart test` → fails

## Suspected Code Paths

- `lib/src/cli/writers/tdd/smoke_test_writer.dart` — `render()` always emits `package:flutter_test` and `package:$appName/app.dart`; no Flutter-vs-Dart check.
- `lib/src/cli/commands/init_command.dart:154–160` — `_isFlutterProject(String cwd)` already exists and detects Flutter vs Dart.
- `lib/src/utils/project_flavor.dart` + `DependencyWirer.isFlutterProject()` — canonical `ProjectFlavor` enum used elsewhere in the codebase, but never wired into `SmokeTestWriter`.

## Root Cause Hypothesis

`SmokeTestWriter` has no knowledge of whether the target project is Flutter or pure Dart; it unconditionally emits Flutter smoke-test content. The detection logic exists in `init_command.dart` and in `ProjectFlavor`/`DependencyWirer`, but is never passed to the writer. Confidence: **high** — the writer is unconditional and the detector already exists.

## Proposed Remediation

**Preferred**: Pass `isFlutter` (or `ProjectFlavor`) to `SmokeTestWriter` and gate the Flutter smoke-test content behind it. For pure Dart projects, either:
1. Skip writing `test/bootstrap_smoke_test.dart` entirely (already-existing sentinel), OR
2. Write a Dart-compatible smoke test (e.g., `import 'package:test/test.dart';` + `test('smoke', () {});`) matching the project's `dart_test.yaml` and `tdd-profile.md` runner (`package:test (^1.24.0)`).

**Files likely to change**:
- `lib/src/cli/writers/tdd/smoke_test_writer.dart`
- `lib/src/cli/commands/init_command.dart` (pass the flag)
- `lib/src/utils/project_flavor.dart` (use the canonical enum)

**Tests to add or update**:
- `zfa tdd init` on a pure Dart package → `dart test` passes (no Flutter imports in smoke test)
- `zfa tdd init` on a Flutter project → smoke test still uses `package:flutter_test` (no regression)

## Risks & Considerations

- Ensure the Dart-compatible smoke test matches the project's existing `package:test` version constraint.
- Skipping the file entirely must not break downstream tooling that expects `test/bootstrap_smoke_test.dart`.

## Open Questions

- None blocking.