# Plan: 1023-feature-capability-parameterization

- **Spec ID**: 1023-feature-capability-parameterization
- **Created**: 2026-09-18

## Technical Context

- **The collapsed capability** (`lib/src/plugins/feature/capabilities/`):
  since the #1149 kill list, the shared body of the eight former clones
  lives in ONE class carrying the shared schema, `plan`/`execute`, and the
  `_generateFiles` flow that resolves
  `PluginManager.resolveActivePlugins(explicitPluginIds: [<one id>])`.
  Per-layer variation is three constructor parameters: the plugin id
  (also the MCP-visible capability name), the description, and a single
  behavioral flag `mapsMockArgToUseMock` (only the `di` clone mirrored the
  `mock` argument onto the `use-mock` context key — mock datasource
  selection inside DI registration).
- **The contract rename (R-001)**: spec 1023 fixes the class name to the
  issue contract `FeatureLayerCapability` and the parameter to `layer`.
  Mechanics: `git mv plugin_feature_capability.dart
  feature_layer_capability.dart` (history-preserving), then
  class/field/constructor/getter renames — `name => layer`,
  `explicitPluginIds: [layer]`. No behavioral expression changes.
- **The layer matrix (R-002)**: `FeaturePlugin._layerMatrix` — a
  `static const List<({String layer, String description, bool
  mapsMockArgToUseMock})>` with one row per generated-artifact layer, in
  the exact pre-parameterization registration order
  (`route, di, mock, test, view, presenter, controller, state` — order is
  part of the manifest parity contract). The `capabilities` getter builds
  the 8 registrations from the matrix with a collection-for, between the
  unchanged `ScaffoldFeatureCapability` (position 1) and
  `XrayFeatureCapability` (position 10 — spec 1115 keeps it a separate
  class because its `feature` argument is a TYPED FeatureId, not a layer).
- **The exit-code site (R-004)**: `feature_command.dart` run() — the
  missing-name branch (mode-given/no-name and empty-rest) already sets
  `exitCode = ExitProtocol.usage` (= 2) per the #1139 sweep; this spec
  re-verifies with a real subprocess run and carries no code change.
- **Test surface touched**: `test/fixes/kill_list_fix_list_test.dart`
  references the parameterized type by name (import + 3 `whereType` + 2
  field reads). The rename updates ONLY those identifiers; every
  assertion, count, set literal and reason string is untouched.

## Parity strategy (how R-005 is proven, not asserted)

1. **Byte-level manifest diff**: run `zfa manifest` on the refactored
   tree, `git stash`, run it on HEAD, `git stash pop`, `diff` the two
   JSON outputs — must be byte-identical (names, descriptions, schemas,
   and ORDER are all in that output).
2. **Parity test**: `feature_command_test.dart` pins
   `zfa feature scaffold Product --plan --format=json` ≡
   `zfa make Product --preset=feature ... --plan --format=json`. Slow-
   tagged; invoked honestly via `dart test --preset=all <file>`.
3. **Contract suites**: `test/plugins/feature` (capability + xray
   contracts), `test/fixes/kill_list_fix_list_test.dart` (8 registrations
   of the ONE parameterized class; di/mock mirror flag), 
   `test/commands/exit_code_sweep_1139_test.dart` (missing-name exit 2).
4. **Real CLI evidence**: `dart run bin/zfa.dart feature state` in the
   repo → stdout fix-line + exit 2; `dart run bin/zfa.dart feature` →
   exit 2.
5. **Baseline-first discipline**: all suites above were run GREEN on the
   pre-refactor tree BEFORE any edit (recorded in tdd/cycle-log.md).

## Files

| File | Change |
|---|---|
| `lib/src/plugins/feature/capabilities/plugin_feature_capability.dart` | git mv → `feature_layer_capability.dart`; class `PluginFeatureCapability` → `FeatureLayerCapability`; `pluginId` → `layer` |
| `lib/src/plugins/feature/feature_plugin.dart` | import updated; `_layerMatrix` const added; `capabilities` getter rebuilt from the matrix (order preserved) |
| `test/fixes/kill_list_fix_list_test.dart` | identifier-only updates to the renamed type/field (assertions unchanged) |

## Risks / notes

- `PluginFeatureCapability` is not exported from `lib/zuraffa.dart`
  (verified by grep) — the rename has no public-API blast radius beyond
  the one test file.
- The spec-kit scaffolding touched by `specify init` in the working clone
  is NOT part of this PR — only the four artifacts under
  `.specify/specs/1023-feature-capability-parameterization/` are committed.
- No Flutter SDK in this environment; `example/` is out of scope (the
  touched code is pure-Dart main-package surface).
