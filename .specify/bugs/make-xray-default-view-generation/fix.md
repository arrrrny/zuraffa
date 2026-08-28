# Bug Fix: `make --with=view` produces no view file in the xray default test

- **Slug**: make-xray-default-view-generation
- **Fixed**: 2026-08-23
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

The source behavior is correct: the view plugin deliberately skips Flutter widget
generation in pure-Dart packages (Constitution VII — Engine Purity). The bug was
that the xray-default test created a pure-Dart `pubspec.yaml` (no `flutter:`
dependency) and then asserted that a `*_view.dart` file was generated. With the
pure-Dart guard in place, nothing is generated, so all three subtests failed. The
fix makes the temp project a Flutter project by adding a `flutter:` SDK dependency,
so the view plugin generates the view and the existing xray-resolution assertions
validate correctly.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `test/commands/make_command_xray_default_test.dart` | modified | Added `dependencies: flutter: sdk: flutter` to the pubspec written in `setUp` so the temp project is detected as a Flutter project. |

## Diff Highlights (optional)

```diff
 environment:
   sdk: ^3.11.0
+dependencies:
+  flutter:
+    sdk: flutter
 ''');
```

## Tests Added or Updated

- `test/commands/make_command_xray_default_test.dart` — the three existing subtests
  (`explicit xray:false …`, `absent xray key …`, `--xray CLI flag wins …`) now pass
  because the view plugin generates the view file once `flutter:` is present.

## Local Verification

- Commands run: `dart test test/commands/make_command_xray_default_test.dart` →
  `All tests passed!` (3/3, ~69s).
- Manual checks: the view plugin's pure-Dart skip is preserved for genuine pure-Dart
  projects; only the test's pubspec flavor changed.

## Deviations from Assessment

None. The applied change matches the preferred remediation in `assessment.md` exactly.

## Follow-ups

- Optionally add a sibling assertion that a genuine pure-Dart `make --with=view`
  prints the Engine-Purity skip warning, to lock in that behavior (out of scope for
  getting green).
