## Summary

Fixed `_isFlutterProject()` in `gen_command.dart` and `init_command.dart` to parse the pubspec as YAML and check for `flutter:` under `dependencies`, instead of doing a naive `raw.contains('flutter')` substring match that matched comments.

The root zuraffa pubspec mentions "flutter" in comments (e.g. `# Flutter consumer unresolvable`), which caused `zfa tdd gen` to emit `flutter_test` imports that don't compile in the pure-Dart root package.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/commands/gen_command.dart` | modified | Added `yaml` import; rewrote `_isFlutterProject()` to parse YAML |
| `lib/src/plugins/tdd/commands/init_command.dart` | modified | Rewrote `_isFlutterProject()` with same YAML-parsing logic |

## Verification

- `dart analyze` — No issues found
- `dart test test/plugins/tdd/commands/` — pre-existing failures only, no new regressions

---

Assessment: .specify/chores/tdd-gen-pure-dart-import/assessment.md

Closes #1458.
