# Bug Assessment: `zfa setup <name>` always emits `my_app.dart` / `MyApp` instead of name-derived file and class names

- **Slug**: zfa-setup-app-name
- **Created**: 2026-09-10
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: low

## Report (verbatim or summarized)

> "Generated flutter app via zfa setup xyx should have xyx.dart not my_app.dart. also should not be MyApp it should be whatever the dart convention is so zfa setup zik_zak should create ZikZak or ZikZakApp not MyApp"

The report has two parts:

1. The generated shell file should be named after the app (`xyx.dart`, `zik_zak.dart`), not the fixed `my_app.dart`.
2. The shell widget class should follow the Dart convention derived from the app name (`ZikZak` or `ZikZakApp`), not the fixed `MyApp`.

## Symptom

Running `zfa setup <name>` (and `zfa app shell`) always generates the app shell at `lib/src/app/my_app.dart` with a hardcoded `class MyApp extends StatelessWidget`, regardless of the project name passed on the command line. Expected: `zfa setup zik_zak` should produce a file named after the app (`zik_zak.dart`) and a PascalCase class per Dart conventions (`ZikZak` or `ZikZakApp`) — `MyApp` is only correct when the app happens to be named `my_app`.

## Reproduction

1. Run `zfa setup xyx` (any Flutter app name other than `my_app`).
2. Inspect the generated project: `lib/src/app/my_app.dart` exists and `lib/main.dart` contains `import 'package:xyx/src/app/my_app.dart';` and `runApp(const MyApp());`.
3. Expected instead: `lib/src/app/xyx.dart` with `class XyxApp` (or `Xyx`), imported/constructed accordingly in `main.dart`.

Nothing is broken at compile/run time — the app works; the names are just wrong/app-agnostic. [NEEDS CLARIFICATION: none — behavior fully determined by code reading; no runtime repro needed.]

## Suspected Code Paths

- `lib/src/plugins/app_shell/builders/app_shell_builder.dart:405-407` — `buildMyApp()` hardcodes `Class(..name = 'MyApp')`; the widget class name is never parameterized.
- `lib/src/plugins/app_shell/builders/app_shell_builder.dart:113-115, 190-192` — `buildMain()` hardcodes the import path `.../app/my_app.dart` and the call `runApp(const MyApp())`.
- `lib/src/commands/setup_command.dart:610-613` — `_generateAppShell()` writes the shell to `app/my_app.dart` via `builder.buildMyApp(title: appName, zuraffaApp: true)`; `appName` (the `zfa setup <name>` argument, captured at `setup_command.dart:151`) is available at this call site but only used for the MaterialApp title.
- `lib/src/commands/app_shell_command.dart:378-391` — `zfa app shell` shares the same builder and the same hardcoded `my_app.dart` path; any fix must cover both commands.
- `lib/src/cli/writers/tdd/app_module_writer.dart:47-48` — precedent for the correct pattern: `containerSymbolFor(appName)` derives symbols via `StringUtils.convertToPascalCase(appName)`, proving the name-derived convention is already used elsewhere in generated output.

## Root Cause Hypothesis

`AppShellBuilder` predates the name-parameterization pass (the TDD app-module writer already derives symbols from `appName`), and the shell's class name + file name were left as fixed literals `MyApp` / `my_app.dart`. `buildMyApp()` and `buildMain()` agree with each other only because both hardcode the same constants, so nothing fails — the wrong names are simply consistent. Confidence: high (hardcoded literals confirmed at the cited lines; no conditional logic produces any other name).

## Proposed Remediation

**Preferred**: Parameterize the shell identity end-to-end.

1. Add optional parameters to `AppShellBuilder.buildMyApp()` and `buildMain()`:
   - `String widgetName` (default `'MyApp'` to preserve existing call sites) — used for the class declaration and the `runApp(const <widgetName>())` call.
   - `String shellFileName` (default `'my_app'`) — used for the file stem and the `package:<appName>/.../app/<shellFileName>.dart` import in `buildMain()`.
   - Derive both at the command layer from `appName` using the existing convention utility: `StringUtils.convertToPascalCase(appName)` → `ZikZak`; widget name `'${pascal}App'` (`ZikZakApp`, mirroring `containerSymbolFor`'s `...Container` suffix pattern) or plain `pascal` — pick one convention and document it.
2. Update the call sites:
   - `setup_command.dart` `_generateAppShell()` — pass the derived names and write to `app/<snakeName>.dart`.
   - `app_shell_command.dart` — same derivation (for `zfa app shell`, `appName` comes from the target project's pubspec name); also update the X-Ray wiring comments/strings that reference `MyApp`.
3. Update the generated-import scanners if they key on `my_app.dart` (check `lib/src/core/dependencies/generated_import_scanner.dart`).
4. Regenerate/update doc strings that mention the fixed names (e.g. `cli_runner.dart:817`, builder doc comments).

**Alternatives**:
- Keep `my_app.dart`/`MyApp` only when the name arg is absent, derive otherwise (lowest-risk default-preserving variant of the same change — effectively what the defaults above give).
- Add an explicit `--shell-name` flag instead of deriving from the app name. More flexible but more surface area; deriving from `appName` is what the report asks for and matches the container-symbol precedent.

**Files likely to change**:
- `lib/src/plugins/app_shell/builders/app_shell_builder.dart`
- `lib/src/commands/setup_command.dart`
- `lib/src/commands/app_shell_command.dart`
- `lib/src/cli/cli_runner.dart` (help text)
- `test/tdd/1444-setup-zuraffa-app/a1_test.dart`, `test/tdd/1444-setup-zuraffa-app/a2_test.dart`
- `test/commands/app_shell_command_test.dart`
- `test/regression/issue_469_app_shell_xray_stub_test.dart`, `test/regression/issue_512_pure_dart_flutter_import_guard_test.dart`

**Tests to add or update**:
- New assertions: `zfa setup <name>` with `name = zik_zak` emits `lib/src/app/zik_zak.dart` containing `class ZikZakApp`, and `main.dart` imports `package:zik_zak/src/app/zik_zak.dart` and calls `runApp(const ZikZakApp());`.
- Keep/extend a case where the name is exactly `my_app` (or defaults unchanged) to pin backward-compat behavior if defaults are preserved.
- Update existing hardcoded-path tests listed above.

## Risks & Considerations

- **Back-compat for `zfa app shell`**: re-running `zfa app shell` on an existing project previously matched the existing `my_app.dart` (skip-if-exists). If the derived name differs from a file already on disk, the command would write a *second* shell file and the old `MyApp` import in `main.dart` would still point at the stale one. Needs a migration note or an overwrite/rename rule.
- **Regression-test blast radius**: several regression tests and generated fixtures assert the literal `my_app.dart` path — they must be updated in lockstep or CI fails.
- **Name collisions**: derived class names must stay valid Dart identifiers for arbitrary valid package names (underscores are fine via PascalCase conversion; verify edge cases like leading digits are rejected by `flutter create` itself).
- Cosmetic only — no data, security, or runtime-behavior risk; the generated app compiles and runs either way.

## Open Questions

- Class-name convention: `ZikZakApp` (suffixed, mirrors `...Container` precedent) or plain `ZikZak` (as the reporter suggested first)? Recommend `ZikZakApp` for symmetry with existing name-derived symbols, but this is a maintainer call.
- Whether re-runs of `zfa app shell` on projects already carrying `my_app.dart` should rename it or leave it (migration path above).
