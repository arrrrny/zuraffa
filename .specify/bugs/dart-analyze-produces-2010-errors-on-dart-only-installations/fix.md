# Fix — `dart analyze` produces ~2010 errors on Dart-only installations

- **Slug**: dart-analyze-produces-2010-errors-on-dart-only-installations
- **Status**: resolved
- **Date**: 2026-08-28
- **Verdict**: valid
- **Triage**: issue #512

## Root cause

Several `zfa` generators unconditionally emit Flutter-only code into the
TARGET project without checking whether that target is a pure-Dart package:

- `RouteBuilder` emits `package:go_router/go_router.dart` routes that reference
  the generated `<Entity>View` Flutter widgets.
- `ShadcnBuilder` emits widgets importing `package:flutter/material.dart` and
  `package:shadcn_ui/shadcn_ui.dart`.
- `AppShellCommand` writes `lib/main.dart` / `my_app.dart` / `app_router.dart`
  that wire a Flutter `MaterialApp.router` entrypoint and depend on
  `zuraffa_flutter`.
- `XRayDeckBarrelWriter.update` writes an `xray_decks.dart` barrel importing
  `package:flutter/foundation.dart`.
- `CreateCommand._createPage` writes a Flutter `CleanView`/`Controller`/`Presenter`
  page.
- `ModuleCommand.run` scaffolds a Flutter feature package (its pubspec declares
  `flutter:` + `zuraffa_flutter`).

When a user creates a pure-Dart project (`pubspec.yaml` without a `flutter:`
dependency) and runs these generators, the generated code cannot resolve
Flutter symbols, so `dart analyze` reports ~2010 errors. This is the same class
of bug as issue #420 (presentation-layer generators), which was already fixed by
detecting the target project's flavor via `detectProjectFlavor` and skipping
Flutter-only generation for pure-Dart targets. Issue #512 extends that guard to
the remaining Flutter-emitters.

## Remediation

Mirrored the existing issue #420 pattern exactly: each generator detects the
target flavor from its `pubspec.yaml` (derived from the target dir) using
`detectProjectFlavor(outputDir, fs)` and, for a pure-Dart target, returns early
with a clear `⚠️` warning instead of emitting Flutter code. The `unknown` flavor
(no `pubspec.yaml` found) keeps generating Flutter code, preserving historical
behavior and tests that run without a pubspec.

1. `lib/src/plugins/route/builders/route_builder.dart` — `generate` now detects
   the flavor right after the `!config.generateRoute` early return and returns
   `[]` for a pure-Dart target.
2. `lib/src/plugins/shadcn/builders/shadcn_builder.dart` — `generate` detects the
   flavor at the top and returns `[]` for a pure-Dart target.
3. `lib/src/commands/app_shell_command.dart` — `run` detects the flavor after the
   pubspec-existence check and returns early (no `main.dart`/`my_app.dart`/
   `app_router.dart`) for a pure-Dart target. The guard is placed before the
   DI/routing pre-flight so a pure-Dart project skips cleanly.
4. `lib/src/plugins/xray/xray_deck_barrel_writer.dart` — `update` gains a sync
   `_isPureDartTarget()` helper (mirrors `DependencyWirer.isFlutterProject`) and
   returns a no-op `BarrelUpdateResult` for a pure-Dart target. The sync helper
   keeps the existing `update` API (used synchronously by tests and the CLI).
5. `lib/src/commands/create_command.dart` — `_createPage` now accepts a `root`
   (defaults to the current project) used for both flavor detection and file
   output; it returns early for a pure-Dart target. Exposed a testable
   `createPage(name, {root})` wrapper.
6. `lib/src/commands/module_command.dart` — `run` detects the flavor from the
   current project and returns early for a pure-Dart target.

## Files changed

- `lib/src/plugins/route/builders/route_builder.dart` — flavor guard.
- `lib/src/plugins/shadcn/builders/shadcn_builder.dart` — flavor guard.
- `lib/src/commands/app_shell_command.dart` — flavor guard at the call site.
- `lib/src/plugins/xray/xray_deck_barrel_writer.dart` — flavor guard.
- `lib/src/commands/create_command.dart` — flavor guard (+ testable `createPage`).
- `lib/src/commands/module_command.dart` — flavor guard.
- `test/regression/issue_512_pure_dart_flutter_import_guard_test.dart` — new
  regression test (route, shadcn, xray deck, create command, app shell).
- `test/commands/app_shell_command_test.dart` — fixture pubspec now declares
  `flutter:` so the app-shell generator still runs (it is a Flutter feature).
- `test/regression/issue_469_app_shell_xray_stub_test.dart` — fixture pubspec
  now declares `flutter:` (same reason).
- `.specify/bugs/dart-analyze-produces-2010-errors-on-dart-only-installations/fix.md`
  — this note.

## Additional Flutter-emitters identified but out of scope

A repo-wide grep for unconditional `package:flutter/*` / `package:zuraffa_flutter/`
emitters found a few more, all reached only via dedicated subcommands (not the
core `zfa make` / `zfa view` / `zfa route create` path, which is what produces
the reported ~2010 errors):

- `lib/src/plugins/route/builders/shell_routes_builder.dart` and
  `deep_link_routes_builder.dart` — reached via `zfa route shell` /
  `zfa route deep-link`.
- `lib/src/dda/plugins/route/route_generator.dart` — reached via `zfa dda`.
- `lib/src/plugins/xray/xray_mock_scaffolder.dart` — reached via `zfa xray mock`.

`lib/src/plugins/test/builders/test_builder_helpers.dart` already honors the
pure-Dart target on its own (issue #354). These subcommand-only emitters are
deferred to a follow-up so this change stays minimal and regression-free.

## Verification

- `dart analyze` clean on every touched source file and test (one pre-existing,
  unrelated `unused_element` warning in `route_builder.dart:1386` predates this
  change).
- `dart test test/regression/issue_512_pure_dart_flutter_import_guard_test.dart`
  — 10/10 pass (pure-Dart => skipped / no Flutter import; Flutter => generated).
- `dart test test/regression/issue_420_pure_dart_presentation_generation_test.dart`
  — 8/8 pass (no regression of the #420 fix).
- `dart test test/commands/app_shell_command_test.dart
  test/regression/issue_469_app_shell_xray_stub_test.dart
  test/plugins/xray/xray_deck_barrel_writer_test.dart
  test/commands/xray_deck_cli_test.dart` — all pass.

Closes #512.
