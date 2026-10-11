# Chore Implementation: DI plugin should import zuraffa_flutter for Flutter apps

- **Slug**: di-import-flutter-app
- **Implemented**: 2026-09-10
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

The DI plugin and its companion builders now detect the target project's flavor via `detectProjectFlavor()` and switch the core barrel import accordingly: Flutter apps get `package:zuraffa_flutter/zuraffa_flutter.dart`, pure Dart and unknown-flavor projects keep `package:zuraffa/zuraffa.dart`. This aligns the DI plugin with the pattern already established by the view, presenter, controller, route, skin, and state plugins.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/di/di_plugin.dart` | modified | Added `project_flavor.dart` import, `_coreImport` field, `_resolveCoreImport()` static helper, flavor detection in `generate()`, and replaced all 13 hardcoded `'package:zuraffa/zuraffa.dart'` occurrences with `_coreImport` |
| `lib/src/plugins/di/builders/service_locator_builder.dart` | modified | `build()` gains optional `coreImport` parameter (default preserves backward compat) |
| `lib/src/plugins/di/builders/package_registrar_builder.dart` | modified | `build()` gains optional `coreImport` parameter (default preserves backward compat) |
| `lib/src/plugins/app_shell/builders/app_shell_builder.dart` | modified | `buildMain()` gains optional `coreImport` parameter; the `diTakesGetIt` branch now uses it instead of hardcoding `package:zuraffa/zuraffa.dart` |
| `lib/src/commands/app_shell_command.dart` | modified | Derives `coreImport` from detected `ProjectFlavor` and passes it to `buildMain()` |

## Diff Highlights

**di_plugin.dart** — flavor detection added at the top of `generate()`:
```dart
final flavor = await detectProjectFlavor(config.outputDir, fs);
_coreImport = _resolveCoreImport(flavor);
```

**di_plugin.dart** — static resolver:
```dart
static String _resolveCoreImport(ProjectFlavor flavor) {
  return switch (flavor) {
    ProjectFlavor.flutter => 'package:zuraffa_flutter/zuraffa_flutter.dart',
    ProjectFlavor.pureDart || ProjectFlavor.unknown =>
      'package:zuraffa/zuraffa.dart',
  };
}
```

**service_locator_builder.dart** — parameterized import:
```dart
String build({String coreImport = 'package:zuraffa/zuraffa.dart'}) {
  final directives = [
    Directive.import(coreImport),
    Directive.export(coreImport, show: ['GetIt']),
    ...
```

**app_shell_command.dart** — passes flavor-derived import:
```dart
final coreImport = flavor == ProjectFlavor.flutter
    ? 'package:zuraffa_flutter/zuraffa_flutter.dart'
    : 'package:zuraffa/zuraffa.dart';
final mainContent = _builder.buildMain(
  ...
  coreImport: coreImport,
);
```

## Verification

- `dart analyze lib/src/plugins/di/ lib/src/plugins/app_shell/ lib/src/commands/app_shell_command.dart` — No issues found
- `dart format lib test` — all files formatted (CI-enforced)
- `dart test test/plugins/di/` — 49/49 tests passed
- `dart test test/templates/self_hosting/di_template_self_hosting_test.dart` — 4/4 tests passed
- `dart test test/regression/issue_512_pure_dart_flutter_import_guard_test.dart` — 1 pre-existing failure (`route Flutter pubspec => emits route files (go_router)`) unrelated to this change (verified by stashing and re-running on clean branch)

## Deviations from Assessment

None. The implementation followed the proposed approach exactly.

## Follow-ups

- The pre-existing #512 regression test failure for the route builder (`route Flutter pubspec => emits route files (go_router)`) should be fixed separately — the test expects `package:go_router/go_router.dart` in the output, but the route builder now imports `package:zuraffa_flutter/zuraffa_flutter.dart` (which re-exports go_router). The test assertion needs updating.
- Consider adding DI-plugin-specific Flutter import tests to the #512 regression suite to guard against future regressions.
