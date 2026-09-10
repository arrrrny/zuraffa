# Bug Fix: `zfa setup`/`zfa app shell` emit name-derived shell file and class

- **Slug**: zfa-setup-app-name
- **Fixed**: 2026-09-10
- **Assessment**: ./assessment.md
- **Status**: applied
- **TDD artifacts**: ./tdd/test-list.md, ./tdd/cycle-log.md, ./tdd/traceability.md

## Summary

Parameterized the app shell's identity end-to-end: `AppShellBuilder` now
accepts `widgetName` / `shellFileName`, both call sites (`SetupCommand`,
`AppShellCommand`) derive them from the target package name
(`zik_zak` → `zik_zak.dart` / `ZikZakApp`), and the derivation collapses to
the legacy `my_app.dart` / `MyApp` for a project named `my_app`. A legacy
`my_app.dart` left by older zfa runs is never deleted or silently
overwritten — `zfa app shell` names it in an informational notice instead.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/app_shell/builders/app_shell_builder.dart` | modified | `buildMyApp(widgetName: 'MyApp')`, `buildMain(shellWidgetName:/shellFileName:)`; new statics `shellWidgetNameFor` (PascalCase + `App` unless already suffixed) and `shellFileStemFor` (the package name); import path + `runApp(const <widgetName>())` parameterized; docs updated |
| `lib/src/commands/setup_command.dart` | modified | `_generateAppShell` derives stem/widget from `appName`, writes `app/<stem>.dart`, passes both to the builder |
| `lib/src/commands/app_shell_command.dart` | modified | same derivation from the parsed pubspec name; `FileUtils.writeFile` label uses the stem; legacy `my_app.dart` notice (never deletes/overwrites it); skip message + flag help texts updated |
| `lib/src/cli/cli_runner.dart` | modified | top-level help line for `app shell` no longer names `MyApp` |
| `test/commands/setup_app_shell_naming_test.dart` | added | behaviors A1–A7 of the test list (RED baseline −6, GREEN +7) |
| `test/commands/app_shell_command_test.dart` | updated | pinned expectations move to `my_test_app.dart` / `MyTestApp` |
| `test/plugins/app_shell/bug_1260_app_shell_zuraffa_app_test.dart` | updated | shell path + `runApp(const MyTestApp())` |
| `test/regression/issue_469_app_shell_xray_stub_test.dart` | updated | reads `stub_app.dart` (derived), same #469 contract |
| `test/regression/issue_512_pure_dart_flutter_import_guard_test.dart` | updated | pure-Dart guard reads `my_test_app.dart` / `MyTestApp` |
| `test/tdd/1444-setup-zuraffa-app/a1_test.dart` | updated | dry-run preview asserts `lib/src/app/demo_app.dart` |

## Diff Highlights

Derivation rule (the one place the convention lives):

```dart
static String shellWidgetNameFor(String appName) {
  final pascal = StringUtils.convertToPascalCase(appName);
  return pascal.endsWith('App') ? pascal : '${pascal}App';
}
static String shellFileStemFor(String appName) => appName;
```

`zik_zak` → `ZikZakApp`, `xyx` → `XyxApp`, `my_test_app` → `MyTestApp`
(no `AppApp` doubling), `my_app` → `MyApp` — the legacy collapse A4 pins.

## Tests Added or Updated

- `test/commands/setup_app_shell_naming_test.dart` — 7 behaviors: derived
  paths/classes for `zik_zak`/`xyx` (A1–A3, A5), back-compat collapse for
  `my_app` (A4), legacy-file preservation + notice (A6), `--xray` wiring
  under the derived name (A7).
- Five existing suites re-pinned to the derived names (see table).

## Local Verification

- `dart analyze lib test` → 0 errors / 0 warnings (112 pre-existing infos
  in unrelated `lib/tdd` fixture files).
- `dart format` applied to every touched file.
- `dart test test/commands/setup_app_shell_naming_test.dart` → +7 green
  (was +1 −6 RED on the base).
- `dart test` (fast tier) on `test/commands/setup_command_test.dart`,
  `test/tdd/1444-setup-zuraffa-app/` → green.
- `--preset=all` on `test/plugins/app_shell/`, `issue_469`, `issue_512`,
  `issue_181`, `docs_command_consistency`, and
  `app_shell_pubspec_deps`/`package_mode_filter`/`skeleton` → green.
- Full evidence: `./tdd/cycle-log.md`.

## Deviations from Assessment

1. **Class-name convention decided**: the assessment left `ZikZakApp` vs
   `ZikZak` open — implemented `ZikZakApp` (the assessment's own
   recommendation, mirroring `AppModuleWriter.containerSymbolFor`), with
   no doubling when the Pascal form already ends in `App`.
2. **Legacy migration decided**: `zfa app shell` never renames or deletes
   a legacy `my_app.dart`; it writes the new derived file and prints a
   notice naming both paths. `main.dart` regeneration keeps its existing
   skip-unless-`--force`/Hello-World-stub rules.
3. **Pre-existing red (not introduced here)**: 3 tests in
   `test/commands/app_shell_command_test.dart` (`#370 canonical/async GetIt
   DI`, `writes all three glue files`) fail because they assert
   `import 'package:zuraffa/zuraffa.dart';` while the command emits the
   flavor-derived `package:zuraffa_flutter/...`. Verified red on the
   stashed base commit — unrelated to this fix; left untouched.
4. **TDD engine gap (run side of #1182)**: `zfa tdd plan` accepts bug dirs
   but `zfa tdd run` still resolves only `<root>/specs/<feature>`
   (`run_command.dart` hardcodes the join and rejects the
   `.specify/bugs/<slug>` reference, exit 2). The loop ran through the
   extension's documented LLM-guided fallback (same precedent as
   `.specify/bugs/1060-route-verify-no-op-pass`); evidence is in
   `./tdd/cycle-log.md`. A failed dispatch also left a stray
   `specs/zfa-setup-app-name/tdd/journal.*` — removed.
5. A full `dart test test/commands test/cli` chunk was attempted and
   aborted at the 30-minute ceiling with no output (the whole-folder
   kernel-cache cost AGENTS.md warns about); every file in those folders
   that touches the shell was instead run individually and is green.

## Follow-ups

- **Issue (run-side of #1182)**: route `run_command.dart` through
  `TddFeaturePaths.resolve` so `zfa tdd run` can drive `.specify/bugs/<slug>`
  features — bug-whole cycles then get the deterministic engine instead of
  the fallback.
- Optionally sweep `doc/`/`docs/` prose that still shows `my_app.dart`
  examples (non-blocking; docs-consistency suite is green).
- The 3 pre-existing `app_shell_command_test` coreImport expectations are
  stale against the flavor-based `coreImport` shipped earlier — separate
  cleanup, deliberately untouched here.
