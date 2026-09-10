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
