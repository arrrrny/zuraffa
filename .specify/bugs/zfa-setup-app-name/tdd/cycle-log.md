# TDD Cycle Log — zfa-setup-app-name

- **Engine**: LLM-guided fallback. `zfa tdd plan` drove the derivation
  (deterministic, 8 acceptance behaviors; the #1182 bug-dir bridge). `zfa
  tdd run` is NOT wired for bug dirs in zfa v6.2.2 — `run_command.dart`
  hardcodes `<root>/specs/<feature>` and rejects the `.specify/bugs/<slug>`
  reference (`zfa tdd run .specify/bugs/zfa-setup-app-name` → exit 2
  "expected a single spec directory name"; bare name → "no feature
  directory at specs/zfa-setup-app-name"). The #1182 fix routed only
  `plan_command.dart` through `TddFeaturePaths.resolve`. This is the
  run-side gap of #1182; recorded as a follow-up in fix.md. The loop below
  follows the extension's LLM-guided fallback contract (same precedent as
  `.specify/bugs/1060-route-verify-no-op-pass`).
- **Branch**: `fix/zfa-setup-app-name`
- **Toolchain**: Dart SDK on macOS (repo), zfa v6.2.2

## RED baseline — the bug, reproduced against base (master)

Test: `test/commands/setup_app_shell_naming_test.dart`

```
dart test test/commands/setup_app_shell_naming_test.dart
→ 00:12 +1 -6: Some tests failed.
```

Failing for the right reason (hardcoded identity, not a harness error):

- **A1** (setup dry-run): preview prints `lib/src/app/my_app.dart` for
  `zfa setup zik_zak` / `zfa setup xyx` — derived path never emitted.
- **A2/A5** (app shell e2e, project `zik_zak`): shell lands at
  `lib/src/app/my_app.dart` with `class MyApp`; `main.dart` imports
  `package:zik_zak/src/app/my_app.dart` and calls `runApp(const MyApp());`.
- **A3** (project `xyx`): same — `my_app.dart` / `MyApp` for an app named
  `xyx`.
- **A6** (legacy migration): a pre-existing `app/my_app.dart` in a project
  named `zik_zak` is regenerated/overwritten in place (old fixed path) and
  no informational notice is emitted.
- **A7** (--xray): `main.dart` keeps the #469 wiring contract but
  `runApp(const MyApp());` — the derived class name never appears.

Passing pre-fix by design (guard, not the bug):

- **A4**: the name `my_app` already collapses to `my_app.dart` / `MyApp`
  under the current hardcoded output; it pins the back-compat contract the
  derivation must preserve.

## GREEN target

All 7 behaviors green after the minimal change: parameterize the shell
identity through `AppShellBuilder.buildMyApp` / `buildMain`
(`widgetName` / `shellFileName`, defaults = legacy literals), derive at
both call sites (`SetupCommand._generateAppShell`,
`AppShellCommand`) via a `PascalCase(appName)` (+ `App` suffix unless
already suffixed) rule, and emit the legacy-file notice instead of
touching the old path.

## GREEN — after the fix (all commands actually executed)

```
dart test test/commands/setup_app_shell_naming_test.dart
→ 00:02 +7: All tests passed!

dart test test/commands/setup_app_shell_naming_test.dart \
          test/tdd/1444-setup-zuraffa-app/ test/commands/setup_command_test.dart
→ 00:05 +10: All tests passed!

dart test --preset=all test/commands/app_shell_command_test.dart \
          test/plugins/app_shell/
→ only failures: the 3 pre-existing coreImport-expectation tests
  (verified red on the stashed base commit — NOT introduced here;
  see fix.md Deviations)

dart test --preset=all test/regression/issue_469_app_shell_xray_stub_test.dart \
          test/regression/issue_512_pure_dart_flutter_import_guard_test.dart
→ All tests passed!

dart test --preset=all test/regression/issue_181_xray_release_mode_strip_test.dart
→ +5: All tests passed!

dart test --preset=all test/regression/docs_command_consistency_test.dart
→ +8: All tests passed!

dart test test/commands/app_shell_pubspec_deps_test.dart \
          test/package_sdk/package_mode_filter_test.dart test/plugins/skeleton/
→ +100: All tests passed!

dart analyze lib test  → 0 errors / 0 warnings (112 pre-existing infos,
all in unrelated lib/tdd fixture files)
dart format (touched files) → applied
```

Per-behavior evidence:
- A1: setup dry-run preview prints `lib/src/app/zik_zak.dart` / `xyx.dart` — RED→GREEN.
- A2/A5: `zik_zak` project → `app/zik_zak.dart` + `class ZikZakApp` + main import/`runApp(const ZikZakApp())` — RED→GREEN.
- A3: `xyx` project → `xyx.dart` / `XyxApp` wiring — RED→GREEN.
- A4: `my_app` → `my_app.dart` / `MyApp` byte-identical — GREEN pre and post (guard).
- A6: legacy `my_app.dart` content preserved byte-for-byte + notice naming it — RED→GREEN.
- A7: `--xray` on `zik_zak` → `runApp(const ZikZakApp())`, stub + conditional import + no direct go_router import intact — RED→GREEN.
- A8: covered by the suite run above; no new red anywhere except the 3 pre-existing master reds.

## Review fix round — PR #1473 findings

Follow-up to the automated review of PR #1473 (head `e2f24f79`, reviewed by
`zuraffa-review[bot]` + `coderabbitai`). Six findings, all resolved:

| Finding | Verdict | Resolution |
| --- | --- | --- |
| `app_shell_builder.dart:787-789` (🟡) — the derived class can shadow the import the emitted file builds with | applied | `shellWidgetNameFor` is collision-aware: a candidate in `shellWidgetReservedNames` (`MaterialApp`, `ZuraffaApp`) takes a `ShellApp` suffix — `material` → `MaterialShellApp`, `zuraffa` / `zuraffa_app` → `ZuraffaShellApp`. |
| `app_shell_builder.dart:112-113` (🔵) — three independently-defaulted identity parameters with two names | applied | One `AppShellNaming(stem, widgetClass)` value (`AppShellNaming.fromAppName`) is threaded through `buildMyApp` / `buildMain`; `AppShellNaming.legacy` keeps the old defaults so a call site cannot pass a stem and a class that disagree. |
| `app_shell_command.dart:562` (also `:656`, `:176`, `:266`) (🔵) — the sweep missed a user-visible message and two comments | applied | The `--xray` status line prints `$shellWidget`; the two comments name "the app shell" instead of the legacy `my_app.dart`. |
| `setup_app_shell_naming_test.dart:138` (🔵) — no test pins the stutter cases or the reserved-name collisions | applied | A derivation table pins the stutter cases (`app` → `App`, `app2` → `App2App`, `myapp` → `MyappApp`, `a` → `AApp`) and the collisions; a `material` end-to-end project pins `class MaterialShellApp` + `MaterialApp.router(`. |
| `analysis_options.yaml:58-62` (🟡) — unrelated `corpus/**` exclusion bundled | applied (scope note) | Kept — it is the same standalone-fixture shape as its neighbours — and disclosed in the PR description ("Scope note: bundled analyzer exclusion"). |
| `tdd/test-list.md` / `tdd/traceability.md` (🟡) — TDD evidence records stale | applied | A1-A8 marked DONE; AC-2..AC-8 line mappings regenerated from the current `spec.md`. |

Evidence (this round):

```
dart test test/commands/setup_app_shell_naming_test.dart
→ 00:06 +10: All tests passed!

dart test test/commands/setup_app_shell_naming_test.dart \
          test/commands/app_shell_command_test.dart \
          test/commands/setup_command_test.dart \
          test/commands/app_shell_pubspec_deps_test.dart \
          test/plugins/app_shell/ test/tdd/1444-setup-zuraffa-app/ \
          test/plugins/tdd/commands/bug_1260_zuraffaapp_widget_shell_test.dart \
          test/plugins/tdd/commands/spec_1256_zuraffa_ui_scaffold_test.dart
→ 01:06 +133: All tests passed!

dart analyze lib/src/plugins/app_shell/builders/app_shell_builder.dart \
             lib/src/commands/app_shell_command.dart \
             lib/src/commands/setup_command.dart \
             test/commands/setup_app_shell_naming_test.dart
→ No issues found!
dart format lib test → 1 file changed (the new test table), clean after

dart test --preset=all test/regression/issue_469_app_shell_xray_stub_test.dart \
          test/regression/issue_181_xray_release_mode_strip_test.dart \
          test/regression/docs_command_consistency_test.dart
→ All tests passed!
```

Pre-existing red (verified on the unmodified head with the fix stashed, NOT
introduced here): `test/regression/issue_512_pure_dart_flutter_import_guard_test.dart`
→ "route Flutter pubspec => emits route files (go_router)" — the route
generator no longer emits a direct `package:go_router/go_router.dart` import
(the #1284 rule), so the stale expectation fails on `master`/head too.
