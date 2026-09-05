# Bug: Kill 3 lie-certifying test suites

**GitHub issue**: [#997 — [ZIKZAK-REBUILD] Kill 3 lie-certifying test suites](https://github.com/arrrrny/zuraffa/issues/997)
**Branch**: `spec/997-kill-lie-certifying-tests`
**Related**: #1022 (phantom write, fixed by #1033), #185 (xray release strip), 017-tui-plugin (FR-011/FR-012)

## Problem

Three test files certified output that cannot compile or does not exist:

1. `test/commands/xray_deck_cli_test.dart:69` asserted
   `contains('XRayControlDeckRegistry.registerEntries')` — a symbol that
   does not exist anywhere in the runtime — while the emitted deck file
   had **10 analyzer errors** (wrong import path `src/presentation/xray/`,
   unresolvable `package:flutter` import, undefined `kReleaseMode`,
   `XRayMockEntry` used as a function, and a fictional `description:`
   named argument).
2. `test/plugins/tui/generator/tui_screen_generator_test.dart` certified
   screens whose entity import was `package:zuraffa/domain/...` —
   unresolvable in every possible world (zuraffa has no `lib/domain`; the
   entity belongs to the *target* project) — and whose use-case class
   names (`GetListUseCase`, `GetUseCase`) are never emitted by the real
   usecase plugin (entity-qualified `GetProductListUseCase` /
   `GetProductUseCase` are).
3. `test/cli/standard/cli_plugin_generator_test.dart` contained a test
   *named* "generated file passes dart analyze" that never invoked the
   analyzer (the real onDisk gate had already landed via #1022/#1033).

A green suite manufacturing false confidence is worse than no test at all.

## Fix scope (honoring the issue's hard constraint)

Production generator changes are limited to exactly what the
lie-certifying assertions demanded:

- `lib/src/commands/xray_deck_command.dart` — emit the real runtime
  imports (`package:zuraffa/src/plugins/xray/…`), the real singleton API
  `XRayControlDeck.instance.registerEntries(const [...])`, drop the
  unresolvable flutter/kReleaseMode guard (the runtime singleton no-ops
  release mode — its documented mirror), emit scenario descriptions as
  comments (XRayMockEntry has no description parameter).
- `lib/src/plugins/tui/generator/tui_screen_generator.dart` — emit
  relative entity/use-case imports into the target project's real
  scaffold layout and entity-qualified use-case class names.

No other production behavior changed.
