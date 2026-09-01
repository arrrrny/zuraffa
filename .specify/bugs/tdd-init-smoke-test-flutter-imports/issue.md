# Bug Issue: [zfa tdd init] smoke test generated for pure Dart package uses Flutter imports

- **Slug**: tdd-init-smoke-test-flutter-imports
- **Fetched**: 2026-09-01
- **Issue**: 664
- **URL**: https://github.com/arrrrny/zuraffa/issues/664
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: (none)

## Body

`zfa tdd init` generates a **Flutter-specific** `test/bootstrap_smoke_test.dart` even when run against a **pure Dart** package. The generated smoke test imports `package:flutter_test/flutter_test.dart` and `package:$appName/app.dart`, neither of which exist in a pure Dart project. This causes `dart test` to fail immediately on the very first run after init.

## Steps to Reproduce

1. Create a fresh pure Dart package (no `flutter:` key in `pubspec.yaml`, no `lib/app.dart`)
2. Run `zfa tdd init`
3. Observe that `test/bootstrap_smoke_test.dart` is created with `import 'package:flutter_test/flutter_test.dart'` and `import 'package:zuraffa_permissions/app.dart'`
4. Run `dart test` → fails with "Couldn't resolve the package 'flutter_test'"

## Expected Behavior

For pure Dart projects, `SmokeTestWriter` should either:
- Not generate a Flutter smoke test, OR
- Generate a Dart-compatible smoke test that uses `package:test` (matching the project's `dart_test.yaml` and `tdd-profile.md` runner: `package:test (^1.24.0)`)

## Root Cause

**File**: `lib/src/cli/writers/tdd/smoke_test_writer.dart`

`SmokeTestWriter.render()` always emits `package:flutter_test` and `package:$appName/app.dart` with no conditional logic. It has no Flutter-vs-Dart check.

The detection mechanism **already exists** in `init_command.dart:154–160`:
```dart
Future<bool> _isFlutterProject(String cwd) async {
  final pubspec = File('$cwd/pubspec.yaml');
  if (!await pubspec.exists()) return false;
  final raw = await pubspec.readAsString();
  return raw.contains('environment:') &&
      (raw.contains('flutter') || raw.contains('sdk: flutter'));
}
```

And there's also a canonical `ProjectFlavor` enum in `lib/src/utils/project_flavor.dart` + `DependencyWirer.isFlutterProject()` used elsewhere in the codebase.

But `SmokeTestWriter` never receives or checks this flag.

## Suggested Fix

Pass `isFlutter` (or `ProjectFlavor`) to `SmokeTestWriter` and gate the Flutter smoke test content behind it. For pure Dart projects, either:
1. Skip writing `test/bootstrap_smoke_test.dart` entirely (already-existing sentinel), OR
2. Write a Dart-compatible smoke test (e.g., `import 'package:test/test.dart';` + `test('smoke', () {});` or check the package's main export)

## Affected Project

`zuraffa_permissions` (pure Dart package) — `zfa tdd init` was run and `dart test` immediately fails on the generated smoke test.