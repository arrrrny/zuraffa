# Skin Plugin (`zfa skin`)

The skin plugin is the code-generation lane for the certified UI
vocabulary: **package:zuraffa_ui** — the identified, contract-carrying
repackaging of the upstream shad*cn-style Flutter engine. Spec 1276
renamed the plugin from the old engine-backed id to `skin` with **no
backward compatibility**: no alias, no deprecation window, no migration
shim.

## Command surface

```
zfa skin <layout> <Entity> [options]      # generation (layouts: list, form)
zfa skin ui.schema.export [options]      # MCP-discoverable capability CLI
zfa skin kit | verify | drive [options]  # runtime skin-contract auditor
                                         # (issue #1102/#1112)
```

- `zfa skin list Product` emits
  `lib/src/presentation/widgets/<domain>/product_list_widget.dart` — a
  `StatelessWidget` importing `package:flutter/material.dart` and
  `package:zuraffa_ui/zuraffa_ui.dart`, using the identified components
  `ZfaCard`, `ZfaInput`, `ZfaButton`.
- `zfa skin form Product` emits a form widget built from per-field
  `ZfaInput(placeholder: ..., onChanged: ...)` capture into a value map
  and a `ZfaButton` submit.
- `zfa skin grid|table` refuses loudly with exit 2 (issue #1149): they
  were advertised but never implemented — the generator must never
  silently emit a mislabeled widget.
- Unknown layouts are dispatch-level usage errors (exit 2 via
  CliRunner's `UsageException` mapping, #1139 sweep).
- Standalone invocations ship the standard capability receipt
  (`plugin: skin`, capability = layout — issue #996 envelope).

## Certified vocabulary contract

Skins import ONLY `package:zuraffa_ui/zuraffa_ui.dart`. The barrel
exports the identified surface: `ZuraffaApp`, `ZfaButton`, `ZfaCard`,
`ZfaDialog`, `ZfaInput`, `ZfaSheet`, `ZfaToaster`, `SkinContractKit`,
`ZfaContract`, `ZfaAuditBus`, `ZuraffaRouteObserver`, `ZfaTheme`,
`ZfaThemeData`. Each identified component carries the typed contract
protocol (`contractId`, `contractEnabled`); `ZuraffaApp`
(`contractId: 'zfa.app'`) audits the tree through the violation chrome.

Notable signature deltas versus the raw upstream engine:

- `ZfaInput.placeholder` is a `String?`, not a `Widget?`.
- `ZfaButton` exposes no variant constructors (`.outline` etc.).
- The published zuraffa_ui 0.1.0 barrel does not yet export identified
  form components (`ZfaForm`, `ZfaInputFormField` are reserved names);
  the `form` layout therefore composes from `ZfaInput` + `ZfaButton`.

## Capability: `ui.schema.export` (unchanged)

The MCP-discoverable capability keeps its id — only the owning plugin
id changed. CLI: `zfa skin ui.schema.export [--project-root <dir>]
[--schema-version <v>]` prints the versioned, diff-stable JSON Schema
of the component vocabulary (components, props, enums, children
constraints, structural rules, style tokens, action-ID grammar).
Project composites load from `.zfa/ui/components/*.json`.

The `zfa ui schema | validate | preview` commands remain the vocabulary
authority surfaces and name the skin plugin in their diagnostics.

## TDD skin lane integration

- Widget-lane behaviors boot generated widget tests in a `ZuraffaApp`
  shell (`WidgetAppShell.zuraffaapp`, config value `zuraffaapp` under
  `.zfa.json` `tdd.widgetShell`), importing
  `package:zuraffa_ui/zuraffa_ui.dart`.
- Issue #938 preflight (`WidgetSkinPreflight`): widget gen REFUSES with
  `--> fix: flutter pub add zuraffa_ui` when the target project's
  pubspec does not declare `zuraffa_ui`. The `materialapp` opt-out
  emits no zuraffa import and skips the preflight.
- `--skip-widget` (issue #992) records per-behavior skips
  (`zuraffa_ui not declared, issue #938`) instead of stopping the run.
- Theme-harness subjects assert `ZfaTheme`/`ZfaThemeData` installed by
  the production shell (issue #841 four-proof harness).

## Plugin registration

`SkinPlugin` (id `skin`, version 1.0.0) is a `FileGeneratorPlugin` +
`CliAwarePlugin` registered in `PluginLoader` and `CodeGenerator`.
Config: `.zfa.json` `pluginDefaults.skin`; the `--skin` make flag and
plan resolution mirror the previous engine-backed key (hard-cut — old
keys are dead). Gym exercises and test generation order after the skin
plugin so generated views exist before their tests.
