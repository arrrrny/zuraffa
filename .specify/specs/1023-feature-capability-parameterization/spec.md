# 1023-feature-capability-parameterization

- **Spec ID**: 1023-feature-capability-parameterization
- **Created**: 2026-09-18
- **Source**: GitHub issue #1023 ([FLEET-ROT] Parameterize feature plugin 8 clone capabilities, priority medium)
- **Type**: pure refactor (behavior parity is the contract — zero emitted-output change for any layer)
- **Branch**: refactor/1023-feature-capability-parameterization
- **Related**: #1149 (kill list — the original collapse landed there as `PluginFeatureCapability(pluginId:)`), #1139 (exit-code sweep — the missing-name exit-0 fix), SPEC 917 (exit protocol), spec 1115 (xray capability is NOT one of the 8 clones), #771 (manifest `name` schema contract)

## Problem

Issue #1023: FeaturePlugin has 9 capabilities; 8 of them are ~110-line
copy-paste clones (`DiFeatureCapability`, `ViewFeatureCapability`,
`PresenterFeatureCapability`, `ControllerFeatureCapability`,
`RouteFeatureCapability`, `StateFeatureCapability`, `MockFeatureCapability`,
`TestFeatureCapability`) differing only in `explicitPluginIds` — ~900 LOC
duplication. Any change to the shared body had to be hand-replicated eight
times, and the layer set existed only as eight silent class registrations,
not as a declared matrix.

### State of the tree at spec time (honest triage record)

The spec file for 1023 was NOT pre-committed as the task brief assumed;
this file is authored from issue #1023 (sole input) plus a read of the
actual tree. Reading the tree shows two of the four deliverables already
landed on master under other issue numbers:

- The 8 clones were collapsed by the #1149 kill list (commit `34097329`)
  into ONE parameterized class — but named `PluginFeatureCapability` with a
  `pluginId:` parameter, not the issue-contract name
  `FeatureLayerCapability(layer:)`.
- The missing-name exit-0-on-error bug at `feature_command.dart:206-210`
  was fixed by the #1139 exit-code sweep (the site now sets
  `exitCode = ExitProtocol.usage`), pinned by
  `test/commands/exit_code_sweep_1139_test.dart` ("feature exits 2 when a
  mode is given without a name").

Residual scope this spec therefore owns:

1. Rename the parameterized capability to the issue-contract name
   `FeatureLayerCapability(layer:)` — pure rename, zero behavior change.
2. Register the layer matrix explicitly in the plugin manifest: one
   declared constant (`FeaturePlugin._layerMatrix`) whose rows drive the
   capability registrations, so the layer set, descriptions and order are
   declared in exactly one place.
3. Carry the already-fixed exit-code behavior through verification (real
   CLI run, not just the pinned test).
4. Prove parity with byte-level evidence, not assertion alone.

## Requirements (from issue #1023)

- **R-001**: The 8 clone capabilities MUST be one parameterized capability
  registered once per layer: `FeatureLayerCapability(layer: String)`.
- **R-002**: The layer matrix MUST be registered in the plugin manifest
  (the `capabilities` getter is built from the declared matrix).
- **R-003**: The existing `feature_command_test.dart` parity test MUST
  still pass.
- **R-004**: A missing feature name MUST exit non-zero (the pre-#1139 bug
  exited 0 on error at `feature_command.dart:206-210`).
- **R-005**: Per-layer plugin registration behavior MUST be identical —
  the MCP-visible capability names, descriptions, input/output schemas,
  and the manifest emission MUST NOT change (manifest output is
  byte-identical before/after).
- **R-006**: `lib/src/plugins/feature/capabilities/` MUST contain at most
  3 files.

## Exit criteria

- `lib/src/plugins/feature/capabilities/` has at most 3 files.
- `feature_command_test.dart` parity test passes.
- Missing feature name exits non-zero (proved by a real CLI run:
  `zfa feature state` → exit 2).
- `dart analyze` over the changed files: zero new issues.
- `dart format .`: no formatting diffs remain.

## Hard constraints

- Pure refactor — behavior parity is the contract; do NOT change emitted
  output for any layer.
- One PR per spec.
