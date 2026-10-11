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

## Verification

- `dart analyze` — No issues found
- `dart format` — all files formatted (CI-enforced)
- `dart test test/plugins/di/` — 49/49 tests passed
- `dart test test/templates/self_hosting/di_template_self_hosting_test.dart` — 4/4 tests passed

---

Assessment: .specify/chores/di-import-flutter-app/assessment.md

Closes #1454.
