# Assessment — Issue #1024 (compile-gate xray deck + delete dead di_command.dart)

**Note on provenance:** the task brief stated these records were already
committed; they were not present on `master` or any remote branch (latest
`.specify/bugs/` commits cover #995/#1025/#1022). This assessment was created
from the GitHub issue body (fetched via API) plus direct code verification on
branch `fix/1024-xray-deck-compile-gate-delete-di-command` (Dart SDK 3.13.3).

## Deliverable xray — verified root cause

Emitter: `lib/src/commands/xray_deck_command.dart`, method `_generateDeckFile`
(the issue's "322,327" drifted to lines 326/331 at HEAD `77e69f24`):

1. **Line 326** emits `import 'package:zuraffa/src/presentation/xray/xray_control_deck.dart';`
   — the directory `lib/src/presentation/xray/` does not exist in this package.
   The real file is `lib/src/plugins/xray/xray_control_deck.dart`.
2. **Line 331** emits `XRayControlDeckRegistry.registerEntries('$ucName', const [ ... ])`.
   `XRayControlDeckRegistry` is defined nowhere in the repo (verified by grep
   across `lib/`, `test/`, `tools/` — the only hit is the emitter itself).
   The real API is `XRayControlDeck.instance.registerEntries(List<XRayMockEntry>)`
   — one positional list argument, no usecase-name parameter
   (`lib/src/plugins/xray/xray_control_deck.dart:37,70`).

Additional compile breaks found in the same emitted template (would fail any
compile gate even after fixing 1+2):

3. The emitted file references `XRayMockEntry` and `XRayMockType` but imports
   neither (`xray_control_deck.dart` imports them without re-exporting).
4. **Line 341-343** emits `description: '...'` for YAML entries with a
   description — `XRayMockEntry` has no `description` parameter
   (`lib/src/plugins/xray/xray_mock_entry.dart:26-30`).
5. The emitted `import 'package:flutter/foundation.dart'` (for `kReleaseMode`)
   pulls Flutter into a deck that the compile gate must analyze in a pure-Dart
   sandbox. The package's own pure-Dart release flag is `kXrayReleaseMode`
   (`lib/src/core/xray_config.dart:28`), behaviorally identical
   (`bool.fromEnvironment('dart.vm.product')`).

Pinning test: `test/commands/xray_deck_cli_test.dart:69`
`expect(content, contains('XRayControlDeckRegistry.registerEntries'))` pins the
broken emitter; line 67 pins the invalid `description:` named argument.

## Deliverable di — verified root cause

`lib/src/commands/di_command.dart` is 427 LOC. `class DiCommand` (line 10) is
referenced nowhere: `rg "\bDiCommand\b" lib/ test/ bin/` (excluding
`ModularDiCommand`) yields only the class's own definition. `zfa di` is wired
through the plugin system: `plugin_loader.dart:132` registers
`DiPlugin` → `DiPlugin.createCommand()` → `ModularDiCommand`
(`lib/src/commands/modular_di_command.dart`, subcommands `create|register`).
Its usecase analyzer duplicates `SourceInterfaceGuard` logic divergently.

## Remediation plan

1. **Emitter fix** (`_generateDeckFile`):
   - import real paths: `package:zuraffa/src/plugins/xray/xray_control_deck.dart`,
     `.../xray_mock_entry.dart`, `.../xray_mock_type.dart`,
     `package:zuraffa/src/core/xray_config.dart`;
   - emit `XRayControlDeck.instance.registerEntries(const [ ... ])`;
   - guard with `kXrayReleaseMode` (drop the flutter import);
   - drop the `description:` named argument; preserve the data as a `///`
     doc comment above the entry.
2. **Compile gate** (test): replace the string-match pin in
   `test/commands/xray_deck_cli_test.dart` with a gate that generates a deck
   into a temp sandbox, creates a minimal package (pubspec with a path
   dependency on this repo), runs `dart pub get --offline` + `dart analyze`,
   and asserts zero errors. Keep corrected string pins for the fixed API.
3. **Proof receipt per deck generation**: after writing the deck, record a
   `proof.v1` receipt via `ReceiptStore(projectRoot: projectRoot)` (the
   `--root` sandbox, keeping tests hermetic) and print a proof line.
4. **Delete** `lib/src/commands/di_command.dart`; verify `zfa di create Foo`
   still succeeds and grep shows zero `DiCommand` references.

## Hard constraints

- xray deck output must pass `dart analyze` in temp sandbox.
- `lib/src/commands/di_command.dart` must not exist after fix.
- `zfa di create Foo` must still succeed.
- One PR for this bug only.

## Baseline (recorded before changes)

- `dart analyze` (repo root): 31 errors / 20 warnings / 294 infos — all 31
  errors pre-existing in `examples/todo_tdd/` (missing files, unrelated).
  Zero errors in `lib/` or `test/`.
- `dependency_overrides:` already removed from pubspec.yaml (commented note).
