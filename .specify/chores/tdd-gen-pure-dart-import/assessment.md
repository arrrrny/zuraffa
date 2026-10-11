# Chore Assessment: TDD gen emits flutter_test for pure Dart projects

- **Slug**: tdd-gen-pure-dart-import
- **Created**: 2026-09-10
- **Source**: pasted text
- **Verdict**: in scope
- **Size**: small

## Report (verbatim or summarized)

`zfa tdd gen` always emits `package:flutter_test/flutter_test.dart` imports for acceptance tests, but the root zuraffa package is pure Dart and cannot compile them. The generator should detect the project flavor correctly and use `package:test` for pure Dart projects. Widget-lane tests that genuinely need Flutter should be refused with a clear message rather than generated into a package that can't compile them.

## Summary

The `_isFlutterProject` method in `gen_command.dart` uses a naive `raw.contains('flutter')` substring match on the pubspec content. The root zuraffa pubspec mentions "flutter" in comments (e.g. "# Flutter consumer unresolvable"), which causes the detector to return `true` even though the package has no `flutter:` SDK dependency. This makes `zfa tdd gen` emit `flutter_test` imports that don't compile.

## Constitution Check

Constitution VII (Engine Purity) states that the root package must remain pure Dart. The naive flutter detection violates this by misclassifying the root package as Flutter, then emitting Flutter-only imports.

## Affected Paths

- `lib/src/plugins/tdd/commands/gen_command.dart:1470-1480` — `_isFlutterProject()` method uses `raw.contains('flutter')` which matches comments
- `lib/src/plugins/tdd/commands/init_command.dart` — has its own `_isFlutterProject()` that likely has the same issue
- `lib/src/plugins/tdd/services/behavior_test_writer.dart:88` — correctly switches between `flutter_test` and `package:test` based on the `flutterTest` flag (no change needed here)

## Proposed Approach

**Preferred**: Fix `_isFlutterProject()` to parse the pubspec as YAML and check for a `flutter:` key under `dependencies` (or `sdk: flutter`), instead of doing a raw substring match. This is the same pattern used by `DependencyWirer.isFlutterProject()` and `detectProjectFlavor()` elsewhere in the codebase.

```dart
static Future<bool> _isFlutterProject(String cwd) async {
  final pubspec = File(p.join(cwd, 'pubspec.yaml'));
  if (!await pubspec.exists()) return false;
  final raw = await pubspec.readAsString();
  final doc = loadYaml(raw);
  if (doc is! YamlMap) return false;
  final deps = doc['dependencies'];
  if (deps is! YamlMap) return false;
  return deps.containsKey('flutter');
}
```

**Paths likely to change**:
- `lib/src/plugins/tdd/commands/gen_command.dart` — fix `_isFlutterProject()`
- `lib/src/plugins/tdd/commands/init_command.dart` — fix its own `_isFlutterProject()` if it has the same pattern

**Verification to run**:
- `dart test test/tdd/1444-setup-zuraffa-app/` — acceptance tests should compile with `package:test` after fix
- `dart test test/plugins/tdd/` — existing TDD plugin tests
- `dart analyze lib/src/plugins/tdd/` — static analysis

## Risks & Considerations

- **Low risk**: The fix narrows the detection from "contains the word flutter anywhere" to "has flutter as a dependency". Pure Dart projects that mention flutter in comments will correctly be detected as non-Flutter.
- **Backward compatible**: Flutter projects (which have `flutter: sdk: flutter` in dependencies) will still be detected correctly.
- **Receipt chain**: After the fix, `zfa tdd gen --all` will produce tests with `package:test` imports for the root package, and the receipt chain will be intact (no manual edits needed).

## Open Questions

- None — the root cause is clear and the fix is straightforward.
