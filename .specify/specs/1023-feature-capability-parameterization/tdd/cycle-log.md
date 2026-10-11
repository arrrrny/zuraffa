# Cycle Log: 1023-feature-capability-parameterization

Append-only. One entry per verification cycle. This spec is a pure
refactor, so the loop is baseline-green → refactor → green; the RED-first
discipline does not apply (the contract forbids new behavior — see
test-list.md's mutation-strength note).

## Cycle 1 — baseline (pre-refactor HEAD = a9329746, Dart 3.13.4 linux_x64)

- `dart pub get` clean (dependency_overrides section already removed from
  pubspec per spec 018; only an explanatory comment remains).
- `dart test --preset=all test/commands/feature_command_test.dart`
  (parity, slow-tagged): **2 / 2 passed**.
- `dart test test/plugins/feature test/fixes/kill_list_fix_list_test.dart
  test/commands/exit_code_sweep_1139_test.dart`: **36 / 36 passed**
  (capability contracts + kill-list fix-3 + exit-code sweep incl. the
  missing-name exit-2 pin).

## Cycle 2 — refactor applied (rename + layer matrix)

- Edits: `git mv plugin_feature_capability.dart
  feature_layer_capability.dart`; class/field rename
  (`PluginFeatureCapability(pluginId:)` → `FeatureLayerCapability(layer:)`);
  `FeaturePlugin._layerMatrix` const added; `capabilities` getter rebuilt
  from the matrix (order preserved); kill-list test identifiers updated
  (assertions untouched).
- `dart analyze` (changed files): **No issues found!**
- `dart test --preset=all test/commands/feature_command_test.dart`:
  **2 / 2 passed**.
- `dart test test/plugins/feature test/fixes/kill_list_fix_list_test.dart
  test/commands/exit_code_sweep_1139_test.dart`: **36 / 36 passed**.

## Cycle 3 — real CLI + byte-level manifest parity

- `dart run bin/zfa.dart feature state` → `--> fix: provide a feature
  name: ...` and **EXIT=2**.
- `dart run bin/zfa.dart feature` (empty rest) → **EXIT=2**.
- Manifest byte-diff: `zfa manifest` on the refactored tree vs HEAD
  (stashed/unstashed in one session) → `diff` empty,
  **MANIFEST BYTE-IDENTICAL**.

## Cycle 4 — format + post-format re-run

- `dart format` re-wrapped `_layerMatrix`'s type annotation in
  `feature_plugin.dart`; whole-repo `dart format --output=none
  --set-exit-if-changed .`: **0 files changed** (2943 formatted).
- Post-format `dart test test/plugins/feature
  test/fixes/kill_list_fix_list_test.dart`: **21 / 21 passed**.
