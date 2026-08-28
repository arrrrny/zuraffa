# Bug Fix: `zfa controller/presenter/view create` skip Flutter generation in pure-Dart packages

- **Slug**: pure-dart-flutter-generation
- **Fixed**: 2026-08-22
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

The presentation-layer generators (`controller`, `presenter`, `view`) unconditionally emitted Flutter-dependent code (`package:zuraffa_flutter/...`, `package:flutter/material.dart`, and `Controller`/`Presenter` base classes) into the target project. In a pure-Dart target package this violated Constitution VII (Engine Purity) and produced 20+ `dart analyze` errors. The fix detects the target project's flavor from its `pubspec.yaml` (derived from `outputDir`) and **skips** Flutter-only generation with a clear warning when the target is pure-Dart, while preserving today's Flutter behavior when a `flutter:` dependency is declared.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/utils/project_flavor.dart` | added | New `ProjectFlavor` enum + `detectProjectFlavor(startDir, fs)` that walks up from `outputDir` to the nearest `pubspec.yaml` and reports `flutter` / `pureDart` / `unknown` (reuses `DependencyWirer.isFlutterProject`). |
| `lib/src/plugins/controller/controller_plugin.dart` | modified | `generate()` now returns `[]` with a warning when the target is `pureDart`. |
| `lib/src/plugins/presenter/presenter_plugin.dart` | modified | `generate()` now returns `[]` with a warning when the target is `pureDart`. |
| `lib/src/plugins/view/view_plugin.dart` | modified | `generate()` now returns `[]` with a warning when the target is `pureDart` (fixed the same hardcoded `zuraffa_flutter` import noted in the assessment). |
| `test/regression/issue_420_pure_dart_presentation_generation_test.dart` | added test | Regression suite mirroring `issue_354_test_plugin_flutter_vs_dart_imports_test.dart` for controller/presenter/view. |

## Diff Highlights (optional)

Detection helper (new):

```dart
enum ProjectFlavor { flutter, pureDart, unknown }

Future<ProjectFlavor> detectProjectFlavor(String startDir, FileSystem fs) async {
  var dir = p.canonicalize(startDir);
  while (true) {
    final pubspecPath = p.join(dir, 'pubspec.yaml');
    if (await fs.exists(pubspecPath)) {
      try {
        final content = await fs.read(pubspecPath);
        return DependencyWirer.isFlutterProject(content)
            ? ProjectFlavor.flutter
            : ProjectFlavor.pureDart;
      } catch (_) {
        return ProjectFlavor.unknown;
      }
    }
    final parent = p.dirname(dir);
    if (parent == dir) return ProjectFlavor.unknown;
    dir = parent;
  }
}
```

Guard in each generator's `generate()` (controller/presenter/view), e.g.:

```dart
final fs = context?.fileSystem ?? fileSystem;
final flavor = await detectProjectFlavor(outputDir, fs);
if (flavor == ProjectFlavor.pureDart) {
  print(
    '⚠️ Skipping controller generation: target project is a pure-Dart '
    'package (no `flutter:` in pubspec.yaml). Controllers depend on '
    'zuraffa_flutter (Constitution VII: Engine Purity). Run '
    '`zfa controller create` inside a Flutter project.',
  );
  return [];
}
```

## Tests Added or Updated

- `test/regression/issue_420_pure_dart_presentation_generation_test.dart` — for controller, presenter, and view:
  - `pure-Dart pubspec => skipped`: writes a `pubspec.yaml` without `flutter:` and asserts `generate()` returns an empty file list (no `zuraffa_flutter`/`flutter/material` emitted).
  - `Flutter pubspec => generates Flutter …`: writes a `pubspec.yaml` with `flutter:` and asserts the generator still emits the Flutter controller/presenter/view (e.g. `class ProductController extends Controller`, `package:zuraffa_flutter/zuraffa_flutter.dart`, `package:flutter/material.dart`).

## Local Verification

- Commands run:
  - `dart analyze lib/src/utils/project_flavor.dart lib/src/plugins/controller/controller_plugin.dart lib/src/plugins/presenter/presenter_plugin.dart lib/src/plugins/view/view_plugin.dart test/regression/issue_420_pure_dart_presentation_generation_test.dart` → **No issues found!**
  - `dart test test/regression/issue_420_pure_dart_presentation_generation_test.dart test/plugins/controller/controller_plugin_test.dart test/plugins/presenter/presenter_plugin_test.dart test/plugins/view/view_plugin_test.dart` → **All tests passed!** (new 6 + existing plugin suites green).
- Manual checks: Confirmed `dart pub get` (deps resolved, incl. `../zorphy` path override). The new regression test prints the expected `⚠️ Skipping …` warnings for the pure-Dart cases, proving the guard fires before any file is written.

## Deviations from Assessment

- The assessment's **preferred** path proposed generating a *pure-Dart presenter* by also landing a core `Presenter` base class in `zuraffa`. This fix implements the assessment's alternative **(a) "detect pure-Dart and skip Flutter generation"** for **all three** commands (controller, presenter, view) instead. Rationale: it is the minimal, lowest-risk change that fully resolves the reported symptom (no broken Flutter code emitted in pure-Dart packages) without introducing a new core API surface or touching the `zuraffa_flutter` consumer contract. Skipping is correct because all three constructs are inherently Flutter-bound (`Controller`/`StatefulController`/`View` need `StatefulWidget`/`GlobalKey`/`BuildContext`; `Presenter` currently ships only in `zuraffa_flutter`).
- `unknown` (no `pubspec.yaml` found while walking up) intentionally falls back to legacy Flutter generation rather than skipping. This preserves existing behavior and keeps the current controller/presenter/view plugin tests (which run without a pubspec) green; it matches the historical Flutter-first assumption for the anomalous "no pubspec" case.

## Follow-ups

- Consider an explicit `--no-flutter` / `--dart` flag on `zfa controller/presenter/view create` as an override on top of auto-detection (assessment Alternative A).
- If pure-Dart presenters are desired later, land a pure-Dart `Presenter` base in core `zuraffa` and switch the presenter generator to import `package:zuraffa/zuraffa.dart` (assessment preferred for presenter only) — then it can generate rather than skip in pure-Dart targets.
- Update CLI docs / `zfa` help to note that controller/presenter/view generation requires a Flutter project.
