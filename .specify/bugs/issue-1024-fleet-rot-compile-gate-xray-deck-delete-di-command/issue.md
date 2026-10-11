# Issue #1024 — [FLEET-ROT] Compile-gate xray deck + delete dead di_command.dart

- **Repo**: arrrrny/zuraffa
- **State**: open
- **Severity**: medium
- **Source**: https://github.com/arrrrny/zuraffa/issues/1024

## Context - xray deck

xray_deck_command.dart:322,327 emits `XRayControlDeckRegistry.registerEntries(...)`
and an import to a non-existent path. The test at xray_deck_cli_test.dart:69 pins
the broken output. Real API: `XRayControlDeck.instance.registerEntries` at
xray_control_deck.dart:35.

## Context - di_command.dart

427 LOC dead code (nothing imports it). Contains a divergent usecase analyzer
duplicating SourceInterfaceGuard.

## Deliverable xray

1. Fix xray_deck_command.dart:322,327 to emit `XRayControlDeck.instance.registerEntries`
   with the real path.
2. Replace string-match assertion with compile gate: `dart analyze` in temp sandbox.
3. Proof receipt per deck generation.

## Deliverable di

1. Delete `lib/src/commands/di_command.dart`.
2. Verify `zfa di create Foo` still works (uses ModularDiCommand).
3. Grep confirms zero references to `DiCommand` class remain.

## Exit criterion

- `zfa xray deck` output passes `dart analyze` in a temp sandbox.
- `lib/src/commands/di_command.dart` does not exist.
- `zfa di create Foo` succeeds (unchanged).
