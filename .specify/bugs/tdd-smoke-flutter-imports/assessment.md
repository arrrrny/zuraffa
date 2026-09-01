# Bug Assessment: [zfa tdd init] smoke test generated for pure Dart package uses Flutter imports

- **Slug**: tdd-smoke-flutter-imports
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/664
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

`zfa tdd init` generates a Flutter-specific `test/bootstrap_smoke_test.dart` even when run against a pure Dart package. The generated file imports `package:flutter_test/flutter_test.dart` and `package:$appName/app.dart`, neither of which exist in a pure Dart project. Running `dart test` immediately fails with "Couldn't resolve the package 'flutter_test'".

## Symptom

When `zfa tdd init` is run against a pure Dart package, the command silently writes `test/bootstrap_smoke_test.dart` that unconditionally imports `package:flutter_test` and `package:$appName/app.dart`. The first `dart test` run immediately fails because `flutter_test` is not a Dart SDK package — it is only available inside the Flutter SDK.

## Reproduction

1. Create a fresh pure Dart package (no `flutter:` key in `pubspec.yaml`, no `lib/app.dart`)
2. Run `zfa tdd init`
3. Observe that `test/bootstrap_smoke_test.dart` is created with `import 'package:flutter_test/flutter_test.dart'` and `import 'package:zuraffa_permissions/app.dart'`
4. Run `dart test` → fails with "Couldn't resolve the package 'flutter_test'"

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/init_command.dart:100` — `SmokeTestWriter` is invoked here **without** an `isFlutter` guard, unlike every other writer in the same command.
- `lib/src/cli/writers/tdd/smoke_test_writer.dart:12–36` — `render()` always emits `package:flutter_test` and `package:$appName/app.dart` unconditionally. The `SmokeTestWriter` class has no `isFlutter` field and no conditional logic.

## Root Cause Hypothesis

High confidence. In `init_command.dart`, `isFlutter` is correctly detected at line 61 via `_isFlutterProject()`. Every other writer in the same function receives the flag correctly: `TddProfileWriter` selects `TddProfile.flutter` vs `TddProfile.dart` (line 74), `AppModuleWriter` is gated by `if (isFlutter)` (line 115), and `PubspecDevDependenciesPatcher` receives `isFlutter` explicitly (line 133). The sole exception is `SmokeTestWriter().write()` at line 100, which runs unconditionally. Because `SmokeTestWriter` has no `isFlutter` parameter, it cannot adapt its output — it always emits Flutter-specific imports.

## Proposed Remediation

**Preferred**: Wrap the `SmokeTestWriter` call in `init_command.dart` with an `if (isFlutter)` guard, mirroring the existing `AppModuleWriter` pattern:

```dart
// lib/src/plugins/tdd/commands/init_command.dart
if (isFlutter) {
  final written = await const SmokeTestWriter().write(cwd, appName);
  // ...
}
```

This is consistent with the comment at lines 111–114, which already explains the Flutter-only rationale for `AppModuleWriter`. The same logic applies to `SmokeTestWriter` — it references `lib/app.dart` and `flutter_test`, both of which are Flutter-specific.

**Alternative 1**: Give `SmokeTestWriter` an `isFlutter` field and conditional `render()` logic that emits a Dart-compatible stub (e.g., `test('smoke', () {});`) for pure Dart packages. This allows the smoke test to always be written but with appropriate content per project type.

**Alternative 2**: Skip writing `test/bootstrap_smoke_test.dart` entirely for pure Dart packages (same outcome as preferred, no code change to `SmokeTestWriter` itself).

**Files likely to change**:
- `lib/src/plugins/tdd/commands/init_command.dart`

**Tests to add or update**:
- Integration test covering `zfa tdd init` against a pure Dart project confirming `test/bootstrap_smoke_test.dart` is NOT created (or is created with Dart-compatible content).

## Risks & Considerations

- Minimal: wrapping one writer call in an existing `if` guard mirrors established patterns in the same file.
- The skip-if-exists sentinel on `SmokeTestWriter.write()` means re-running `zfa tdd init` on an existing project is already safe; the guard only prevents creation in the wrong project type.
- No migration concern — this only affects new file creation.

## Open Questions

- None.
