# Spec 1276 — refactor: rename shadcn plugin → skin; hard-cut to zuraffa_ui vocab; no backward compat

GitHub issue: arrrrny/zuraffa#1276
Locked decision: rename plugin id `shadcn` → `skin`. No backward
compatibility, no deprecation window, no alias, no migration shim.

## Problem

package:zuraffa_ui 0.1.0 is now published on pub.dev (2026-09-05). It is
the skin lane's certified vocabulary — the shadcn_ui Flutter port
repackaged end-to-end with typed contract protocols (`contractId`,
`contractEnabled`) and a `ZuraffaApp` shell. The barrel
`package:zuraffa_ui/zuraffa_ui.dart` exports ONLY identified `Zfa*`
names; raw `Shad*` engine names are internal (reachable through
`package:zuraffa_ui/shad.dart`, which skins must never import).

The internal `zfa` shadcn plugin contradicts the new identification
contract on three axes:

1. **Identification.** The plugin id is `shadcn` (`zfa shadcn <layout>
   <Entity>`, receipts keyed `plugin: shadcn`, config key `shadcn`,
   plan-resolver option `shadcn`, gym/test run-order keys `shadcn`),
   while the skin lane vocabulary the repo already ships
   (`lib/src/skin/` — contract kit, audit, driver) is named `skin`.
2. **Package import.** Generated widget templates and TDD widget-lane
   scaffolds emit `import 'package:shadcn_ui/shadcn_ui.dart';` and the
   #938 preflight demands the target project declare `shadcn_ui` — the
   raw upstream package, not the certified repackaging.
3. **Widget vocabulary.** Templates emit raw `Shad*` engine classes
   (`ShadInput`, `ShadButton.outline`, `ShadCard`, `ShadForm`,
   `ShadFormState`, `ShadInputFormField`, `ShadApp`, `ShadTheme`) that
   are unreachable through the certified barrel.

## Deliverables

1. **Plugin rename (hard cut).** `lib/src/plugins/skin/` mirrors the
   old layout: `skin_plugin.dart` (`SkinPlugin`, id `skin`, version
   1.0.0), `commands/skin_command.dart` (`SkinCommand`, CLI
   `zfa skin <layout> <Entity> | zfa skin ui.schema.export ...`),
   `builders/skin_builder.dart` (`SkinBuilder`), `capabilities/`,
   `vocabulary/`. `lib/src/plugins/shadcn/` and `test/plugins/shadcn/`
   are deleted outright.
2. **Capability id UNCHANGED.** `ui.schema.export` keeps its name —
   the MCP contract surface stays stable; only the owning plugin id
   changes to `skin`.
3. **Certified vocabulary swap.** Every emitted import becomes
   `package:zuraffa_ui/zuraffa_ui.dart`; emitted widget classes become
   `ZfaButton`, `ZfaCard`, `ZfaInput` (the identified components the
   published barrel exports); the TDD widget-lane shell becomes
   `ZuraffaApp` with `ZfaTheme`/`ZfaThemeData`. The #938 preflight
   demands `zuraffa_ui` in the target pubspec and its fix line becomes
   `flutter pub add zuraffa_ui`.
4. **Routing + receipts + config re-key.** `ZfaConfig` plugin defaults,
   `PlanResolver` option wiring, `generate_commands` presentation map,
   gym `runAfter` ordering, test plugin `runAfter`, receipt envelope
   `plugin: skin`, barrel exports, and the CLI loader all address the
   plugin as `skin`.
5. **Docs.** `docs/skin_plugin.md` documents the skin command, the
   unchanged `ui.schema.export` capability, and the certified
   vocabulary contract.

### Vocabulary constraint recorded (zuraffa_ui 0.1.0 audit)

The published 0.1.0 barrel exports: `ZuraffaApp`, `ZfaButton`,
`ZfaCard`, `ZfaDialog`, `ZfaInput`, `ZfaSheet`, `ZfaToaster`,
`SkinContractKit`, `ZfaContract`, `ZfaAuditBus`, `ZuraffaRouteObserver`,
`ZfaTheme`, `ZfaThemeData`. It does NOT export `ZfaForm`,
`ZfaFormState`, or `ZfaInputFormField` (the engine keeps
`ShadForm`/`ShadInputFormField` internal). Emitting `ZfaForm`/
`ZfaInputFormField` would generate uncompilable code against the only
published package version, so the `form` layout template emits the
certified equivalent: `ZfaInput` (String placeholder, per-field
`onChanged` capture) + `ZfaButton` submit. `ZfaForm`/`ZfaInputFormField`
are recorded as reserved names pending identified form components in a
future zuraffa_ui release.

## Success criteria (measurable)

- SC-1: `rg -i "shadcn" lib/ test/ docs/` returns zero matches after
  migration (committed historical artifacts under `specs/` and
  `REPORTS/` are out of scope — never rewritten).
- SC-2: `zfa skin list Product` (Flutter flavor) emits a widget whose
  imports are exactly `package:flutter/material.dart` +
  `package:zuraffa_ui/zuraffa_ui.dart`, and whose widget classes are
  `ZfaCard`/`ZfaInput`/`ZfaButton` only.
- SC-3: `zfa skin ui.schema.export` emits the same JSON schema payload
  as before (capability id, components, enums, constraints unchanged)
  — proven by the migrated vocabulary/registry/exporter test suite.
- SC-4: the receipt for a standalone `zfa skin <layout> <Entity>` run
  carries `plugin: skin`; the receipt store contract test proves it.
- SC-5: `zfa ui schema|validate|preview` error surfaces name the skin
  plugin (`skin plugin not found`), and `--no-plugin` diagnostics stay
  machine-parseable.
- SC-6: TDD widget-lane gen for a project whose pubspec declares
  `zuraffa_ui` proceeds; a project without it refuses with
  `--> fix: flutter pub add zuraffa_ui`; the `materialapp` opt-out
  emits no zuraffa_ui import.
- SC-7: `dart analyze` on every changed file is clean; every migrated
  test passes; unformatted-code count after `dart format .` is zero.
- SC-8: pure-Dart flavor refusal (issue #512 / Constitution VII) is
  preserved: `SkinBuilder` skips generation with the same guard
  semantics, naming the skin lane in the warning.

## Out of scope

- Historical spec artifacts (`specs/**`), `REPORTS/**`, and untracked
  test-output logs: never rewritten (append-only history).
- `lib/src/skin/` (the runtime audit/driver subsystem): untouched —
  it already uses the target vocabulary.
- Backward compatibility of any kind: the `shadcn` id, the `shadcn_ui`
  import, `Shad*` class names, and the `shadapp` widget-shell value are
  removed without alias (locked decision).
