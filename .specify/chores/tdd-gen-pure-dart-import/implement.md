# Chore Implementation: TDD gen emits flutter_test for pure Dart projects

- **Slug**: tdd-gen-pure-dart-import
- **Implemented**: 2026-09-10
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Fixed `_isFlutterProject()` in both `gen_command.dart` and `init_command.dart` to parse the pubspec as YAML and check for `flutter:` under `dependencies`, instead of doing a naive `raw.contains('flutter')` substring match that matched comments.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/commands/gen_command.dart` | modified | Added `yaml` import; rewrote `_isFlutterProject()` to parse YAML and check `dependencies.containsKey('flutter')` |
| `lib/src/plugins/tdd/commands/init_command.dart` | modified | Rewrote `_isFlutterProject()` with same YAML-parsing logic (yaml already imported) |

## Diff Highlights

**Before** (both files):
```dart
static Future<bool> _isFlutterProject(String cwd) async {
  final raw = await pubspec.readAsString();
  return raw.contains('environment:') &&
      (raw.contains('flutter') || raw.contains('sdk: flutter'));
}
```

**After** (both files):
```dart
static Future<bool> _isFlutterProject(String cwd) async {
  final pubspec = File(p.join(cwd, 'pubspec.yaml'));
  if (!await pubspec.exists()) return false;
  try {
    final raw = await pubspec.readAsString();
    final doc = loadYaml(raw);
    if (doc is! YamlMap) return false;
    final deps = doc['dependencies'];
    if (deps is! YamlMap) return false;
    return deps.containsKey('flutter');
  } catch (_) {
    return false;
  }
}
```

## Verification

- `dart analyze lib/src/plugins/tdd/commands/gen_command.dart lib/src/plugins/tdd/commands/init_command.dart` — No issues found
- `dart format` — no changes needed (already formatted)
- `dart test test/plugins/tdd/commands/` — pre-existing failures only (bug_1320, bug_1388, compose_command); no new regressions

## Deviations from Assessment

None. The implementation followed the proposed approach exactly, matching the pattern from `DependencyWirer.isFlutterProject()`.

## Follow-ups

- After merging, re-run `zfa tdd gen --all --feature 1444-setup-zuraffa-app` to verify the receipt chain is intact (tests should now use `package:test` imports)
- The TDD verify step should then pass for the 3 driven acceptance behaviors
