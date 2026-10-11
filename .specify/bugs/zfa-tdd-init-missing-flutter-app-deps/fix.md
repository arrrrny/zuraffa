# Fix: zfa-tdd-init-missing-flutter-app-deps (bug #1349)

## Change surface (hard constraints honored)

- `lib/src/plugins/tdd/commands/init_command.dart` — ONLY production
  file touched (+178 lines).
- Generated `lib/app.dart` content: unchanged.
- `test/bootstrap_smoke_test.dart` content: unchanged.
- Non-Flutter (pure-Dart) init flow: unchanged — the self-heal lives
  inside the `if (isFlutter)` branch, after the app-module writer.
- One PR per bug.

## What was added

1. `_flutterAppDependencies` — the runtime deps the day-zero Flutter app
   module requires:
   - `zuraffa_flutter: ^6.0.0` (mirrors `DependencyWirer.standardSet`,
     the toolchain's canonical pin)
   - `get_it: ^9.2.1` (matches the repo's own resolution pin and test
     fixtures)
2. `_ensureFlutterAppDependencies(cwd)` — read-only YAML detection of
   missing entries under `dependencies:` (never `dev_dependencies:` —
   `lib/app.dart` is runtime source), then a textual patch. Idempotent;
   hand-edited pubspecs with both deps present are never rewritten;
   malformed/non-map `dependencies:` values and non-empty inline
   mappings fail loudly (`FormatException` / `UnsupportedError`).
3. `_patchDependenciesTextually(...)` — same textual-patching discipline
   as `PubspecSkinDependencyPatcher`/`PubspecDevDependenciesPatcher`:
   comments and formatting preserved, entries inserted at the END of the
   `dependencies:` block, empty inline `dependencies: {}` expanded.
4. Wiring in the Flutter branch after `AppModuleWriter`, with the house
   stdout receipts (`✓ pubspec.yaml dependencies (app module: added: …)`
   / `(app module: already declared)`) and the catch-and-fail structure
   that feeds the `failures` list (misfire naming:
   `pubspec_app_dependencies_patcher`), so the command exits non-zero
   instead of promising a green baseline it cannot deliver.

## Why not a separate patcher file

The bug's hard constraint pins the fix to `init_command.dart` only. The
self-heal is implemented as private members of `InitCommand`, reusing
the established patcher algorithm verbatim; extracting it into a
`Pubspec*Patcher` writer (the #1260 shape) is a mechanical follow-up if
the maintainer prefers it.
