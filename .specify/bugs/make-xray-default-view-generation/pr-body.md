## Summary

The xray-default test (`test/commands/make_command_xray_default_test.dart`, related to #360) created a **pure-Dart** temp project (no `flutter:` dependency in its pubspec) and then asserted that a `*_view.dart` was generated. Since the pure-Dart split (Constitution VII — Engine Purity), the view plugin intentionally skips Flutter widget generation in pure-Dart packages, so nothing was generated and all three subtests failed.

This change adds a `flutter:` SDK dependency to the test's temp pubspec so the view plugin generates the view, and the existing xray-resolution assertions (explicit `false` preserved / absent key falls back to config / `--xray` wins) validate correctly. Production behavior is unchanged — the source (xray resolution + view xray application) was already correct.

## Changes

| File | Change |
|------|--------|
| `test/commands/make_command_xray_default_test.dart` | Add `flutter:` SDK dependency to the test pubspec so the temp project is detected as a Flutter project |

## Local Verification

`dart test test/commands/make_command_xray_default_test.dart` → `All tests passed!` (3/3).

## Assessment

- Assessment: `.specify/bugs/make-xray-default-view-generation/assessment.md`
