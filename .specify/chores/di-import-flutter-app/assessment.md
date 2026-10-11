# Chore Assessment: DI plugin should import zuraffa_flutter for Flutter apps

- **Slug**: di-import-flutter-app
- **Created**: 2026-09-10
- **Source**: pasted text
- **Verdict**: in scope
- **Size**: medium

## Report (verbatim or summarized)

When an app is created via `zfa setup`, the generated DI index file (`lib/src/di/index.dart`) imports from `package:zuraffa/zuraffa.dart`. For Flutter apps, it should import from `package:zuraffa_flutter/zuraffa_flutter.dart` instead. The `zuraffa_flutter` barrel re-exports the core, so switching is safe and semantically correct — Flutter apps depend on `zuraffa_flutter`, not `zuraffa` directly.

The user quoted the day-zero bootstrap DI index template that shows `import 'package:zuraffa/zuraffa.dart';` and noted it should be `import 'package:zuraffa_flutter/zuraffa_flutter.dart';` when the target project is a Flutter app.

## Summary

The DI plugin and its companion builders hardcode `package:zuraffa/zuraffa.dart` as the import in every generated DI file (index, registration files, service locator, package registrar, and the main.dart entrypoint when `diTakesGetIt` is true). For Flutter apps, this should be `package:zuraffa_flutter/zuraffa_flutter.dart`. This is a maintenance chore because the pattern for Flutter-vs-pure-Dart import switching already exists in six other plugins (view, presenter, controller, route, skin, state) via `detectProjectFlavor` — the DI plugin simply never adopted it.

## Constitution Check

No constitution constraints are violated. The constitution template is unfilled. The existing project pattern (issue #512) already mandates that generators detect project flavor and switch Flutter-only imports accordingly. This chore aligns with that pattern.

## Affected Paths

- `lib/src/plugins/di/di_plugin.dart` — 13 hardcoded `package:zuraffa/zuraffa.dart` imports across `_regenerateMainIndex` (line 1597), `_regenerateIndexFile` (line 1522), and individual DI registration generators (remote datasource, local datasource, sqlite datasource, mock datasource, repository, service, mock provider, provider, orchestrator usecase, entity usecases, custom usecase)
- `lib/src/plugins/di/builders/service_locator_builder.dart` — hardcoded import at line 12 (`Directive.import('package:zuraffa/zuraffa.dart')`) and export at line 13
- `lib/src/plugins/di/builders/package_registrar_builder.dart` — hardcoded import at line 34
- `lib/src/plugins/app_shell/builders/app_shell_builder.dart` — `buildMain` imports `package:zuraffa/zuraffa.dart` at line 142 when `diTakesGetIt` is true (the `GetIt` re-export import)
- `test/plugins/di/di_plugin_test.dart` — existing tests will need updating to verify Flutter-app import switching
- `test/templates/self_hosting/di_template_self_hosting_test.dart` — template self-hosting tests may need updates

## Proposed Approach

**Preferred**: Detect the project flavor once at the top of `DiPlugin.generate()` (using `detectProjectFlavor` from `utils/project_flavor.dart`) and thread a `zuraffaImport` string through to all generation methods. When `flutter` → `'package:zuraffa_flutter/zuraffa_flutter.dart'`; otherwise → `'package:zuraffa/zuraffa.dart'`.

Specifically:

1. In `DiPlugin.generate()`, call `detectProjectFlavor(outputDir, fs)` and derive a `coreImport` string (`zuraffa_flutter/zuraffa_flutter.dart` for Flutter, `zuraffa/zuraffa.dart` for pure Dart or unknown).

2. Pass `coreImport` to `_regenerateMainIndex`, `_regenerateIndexFile`, and every `_generate*DI` method. Each method replaces the hardcoded `'package:zuraffa/zuraffa.dart'` with the `coreImport` parameter.

3. `ServiceLocatorBuilder.build()` gains an optional `coreImport` parameter (defaulting to `'package:zuraffa/zuraffa.dart'` for backward compatibility). The DI plugin passes the detected import.

4. `PackageRegistrarBuilder.build()` similarly gains a `coreImport` parameter.

5. `AppShellBuilder.buildMain()` already receives `diTakesGetIt` — when true, it should switch the `GetIt` import to `package:zuraffa_flutter/zuraffa_flutter.dart` for Flutter apps. The command already detects flavor, so it can pass the resolved import name.

**Alternative**: Move the flavor detection into the `GeneratorConfig` so every plugin reads it from a shared source. This is cleaner long-term but a larger refactor.

**Paths likely to change**:
- `lib/src/plugins/di/di_plugin.dart`
- `lib/src/plugins/di/builders/service_locator_builder.dart`
- `lib/src/plugins/di/builders/package_registrar_builder.dart`
- `lib/src/plugins/app_shell/builders/app_shell_builder.dart`
- `test/plugins/di/di_plugin_test.dart` (and other DI-related test files)

**Verification to run**:
- `dart test test/plugins/di/` — all DI plugin tests
- `dart test test/templates/self_hosting/di_template_self_hosting_test.dart` — template self-hosting
- `dart test test/commands/app_shell_command_test.dart` — app shell command tests
- `dart test test/regression/issue_512_pure_dart_flutter_import_guard_test.dart` — regression guard
- `dart analyze lib/src/plugins/di/` — static analysis
- `dart format lib test` — formatting (CI-enforced)

## Risks & Considerations

- **Backward compatibility**: Pure Dart apps and unknown-flavor projects must keep importing `package:zuraffa/zuraffa.dart`. The `unknown` flavor (no pubspec found) should default to the current behavior (`zuraffa`) to avoid breaking existing tests that run without pubspecs.
- **Blast radius**: 13 hardcoded import sites in `di_plugin.dart` plus 2 builder files and 1 app shell file. All must be updated consistently.
- **Test coverage**: The existing issue #512 regression test does NOT cover the DI plugin — it only tests route, skin, xray deck barrel, create command, and app shell command. New test coverage is needed for the DI plugin specifically.
- **`GetIt` re-export**: `GetIt` is re-exported by both `zuraffa/zuraffa.dart` and `zuraffa_flutter/zuraffa_flutter.dart`, so the switch is transparent — no symbol resolution changes needed.

## Open Questions

- Should `GeneratorConfig` carry a `coreImport` field so flavor detection is done once and shared across all plugins? (Larger refactor, but eliminates per-plugin detection duplication.)
