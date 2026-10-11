# Assessment — tdd/app-shell: certified skin vocabulary (zuraffa_ui / ZuraffaApp) not emitted (issue #1260)

## Diagnosis

The certified vocabulary is unreachable from the toolchain at three
pipeline-owned surfaces:

| Surface | File | Today |
|---|---|---|
| widget shell enum | `lib/src/plugins/tdd/services/widget_scaffold.dart` | `WidgetAppShell { shadapp, materialapp }` only |
| widget gen flag + default | `lib/src/plugins/tdd/commands/gen_command.dart` | `--widget-shell` allowed `['shadapp','materialapp']`; default resolves to `shadapp` |
| widget test emission | `lib/src/plugins/tdd/services/behavior_test_writer.dart` | shell import is shadcn-only; `pumpWidget($shellName(...))` |
| gen dependency preflight | `gen_command.dart` + `widget_scaffold.dart` | #938 preflight covers `shadcn_ui` only |
| init dependency patch | `lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart` + `init_command.dart` | testing `dev_dependencies` only; no `zuraffa_ui` offer |
| app shell emission | `lib/src/commands/app_shell_command.dart` + `lib/src/plugins/app_shell/builders/app_shell_builder.dart` | `buildMyApp` → `MaterialApp.router` |

`grep -r zuraffa_ui lib/src` → zero hits.

## Remediation (all through the generation pipeline; no hand-edits to pipeline-owned surfaces)

1. **`--widget-shell` gains a `zuraffaapp` option** (and skin-lane projects
   default to it): `WidgetAppShell.zuraffaapp` emits `ZuraffaApp` and
   `import 'package:zuraffa_ui/zuraffa_ui.dart';`, pumping views through
   `ZuraffaApp` so the contract observer/audit bus/chrome are exercised by
   skin tests. Default resolution order: explicit flag > `.zfa.json`
   `tdd.widgetShell` > **skin-lane project default (pubspec declares
   `zuraffa_ui`) → `zuraffaapp`** > `shadapp`. A `zuraffaapp` gen on a
   project whose pubspec lacks `zuraffa_ui` refuses BEFORE writing
   (machine-parseable `--> fix:` line, the #938 discipline).
2. **`zfa tdd init` offers/adds `zuraffa_ui`** (as the skin lane's certified
   dependency) for projects that opt into skin lanes: `zfa tdd init --skin`
   adds `zuraffa_ui: ^0.1.0` under `dependencies:` (runtime, not dev) —
   idempotent, explicit opt-in, loud misfire on pure-Dart targets.
3. **`zfa app shell` emits `ZuraffaApp` (behind a flag)**:
   `zfa app shell --zuraffa-app` emits `my_app.dart` that mounts the
   certified shell and keeps the generated GoRouter tree functional beneath
   it (`Router.withConfig(config: appRouter)`); `--skin-audit` composes via
   the certified shell's `builder:`; `--xray` wraps the routed home;
   preflight requires the target pubspec to declare `zuraffa_ui`; without
   the flag the emission is byte-compatible with pre-#1260.

## Hard constraints

- Fix ONLY through the generation pipeline; never hand-edit source the
  assessment says must stay pipeline-owned.
- One PR per bug.
- The fix must make `zuraffa_ui` reachable from the toolchain and make
  `ZuraffaApp` the default/supported shell for skin-lane projects.
- API truth: `ZuraffaApp` (zuraffa_ui 0.1.0) is a `StatefulWidget with
  ZfaContract`, const-constructible, taking `home`, `routes`,
  `navigatorObservers`, `builder`, `showViolationChrome`, `auditBus`,
  `contractEnabled`; it wraps `ShadApp` and mounts `ZuraffaRouteObserver`,
  `ZfaAuditBus`, `ZfaViolationChrome`. It has NO `routerConfig` — the
  GoRouter composition path is `Router.withConfig`.
