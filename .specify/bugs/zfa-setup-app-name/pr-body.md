Fixes #1465 — `zfa setup <name>` and `zfa app shell` always emitted the app shell at `my_app.dart` with a hardcoded `class MyApp`, no matter what the project is called. Both commands now derive the shell file name and widget class from the package name.

## What changed

- **`AppShellBuilder`** (`buildMyApp` / `buildMain`): new `widgetName` / `shellFileName` parameters (defaults keep the legacy `MyApp` / `my_app` literals), plus the two derivation helpers:
  - `shellWidgetNameFor`: `zik_zak` → `ZikZakApp`, `xyx` → `XyxApp`, `my_test_app` → `MyTestApp` (PascalCase + `App`, no doubling when the Pascal form already ends in `App`), `my_app` → `MyApp` (byte-identical back-compat).
  - `shellFileStemFor`: the package name itself (`zik_zak` → `zik_zak.dart`).
- **`SetupCommand._generateAppShell`** and **`AppShellCommand`**: pass the derived identity and write `app/<stem>.dart`; the shell skip message, flag help texts, and top-level help no longer name `MyApp`.
- **Legacy migration (issue #1465 risk)**: `zfa app shell` never deletes or silently overwrites an older zfa's `my_app.dart` — it writes the new derived file and prints an informational notice naming both paths.
- Tests: new behavior suite `test/commands/setup_app_shell_naming_test.dart` (A1–A7: derived paths/classes for `zik_zak`/`xyx`, back-compat collapse for `my_app`, legacy-file preservation + notice, `--xray` wiring under the derived class). Five pinned suites re-based to the derived names (`app_shell_command_test`, `bug_1260`, `issue_469`, `issue_512`, `1444/a1`).

## Verification

- RED baseline on base commit: `+1 -6` (the bug, reproduced); after the fix: `+7 All tests passed!`
- Real end-to-end: `zfa setup zik_zak` (with `flutter create` behind it) → `lib/src/app/zik_zak.dart` + `runApp(const ZikZakApp())`; `flutter analyze` on the generated app → exit 0, 0 errors/warnings.
- `dart analyze lib test` → 0 errors/warnings; `dart format --set-exit-if-changed lib test` clean.
- Green: fast tier (setup, 1444, pubspec-deps, package-mode, skeleton), slow tier (`test/plugins/app_shell/`, issue #469/#512/#181 regressions, docs-command-consistency). The 3 remaining failures in `app_shell_command_test` were verified red on the base commit (stale coreImport expectations, unrelated — noted as a follow-up).

Assessment: `.specify/bugs/zfa-setup-app-name/assessment.md` · TDD evidence: `.specify/bugs/zfa-setup-app-name/tdd/` (cycle-log, verification)

Closes #1465.
