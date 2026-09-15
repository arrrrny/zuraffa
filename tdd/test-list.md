# TDD test list — Bug #1655 the static first-build skip is unreachable for zfa setup-created apps

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| U-1655-b1 | test/plugins/tdd/services/build_relevance_test.dart | unit | a fresh app whose build.yaml is byte-identical to `DependencyWirer.buildYamlContent` (what `zfa setup`/`zfa init`/the `zfa build` guard write) with zero builder-facing files skips the first build statically — the issue's exact bug | issue #1655 criterion 1 | RED → GREEN |
| U-1655-b2 | test/plugins/tdd/services/build_relevance_test.dart | unit | the pristine setup build.yaml PLUS a builder-facing annotation still runs the first build — the provenance fall-through must not swallow the scan's run triggers | criterion 1 (fall-through soundness) | GREEN |
| U-1655-b3 | test/plugins/tdd/services/build_relevance_test.dart | unit | the pristine setup build.yaml PLUS a non-Dart source in a walked root still runs the first build | criterion 1 (fall-through soundness) | GREEN |
| U-1655-b4 | test/plugins/tdd/services/build_relevance_test.dart | unit | a MODIFIED setup-generated build.yaml (template + one user edit) runs the first build — exact-match catches a single-byte divergence, so user-edited still forces | issue #1655 criterion 2 | GREEN |
| U-1655-b5 | test/plugins/tdd/services/build_relevance_test.dart | unit | a USER-AUTHORED build.yaml (custom content, the pre-existing #1634 test) still runs the first build — re-commented as the criterion-2 shape it already pins | issue #1655 criterion 2 | GREEN |
| U-1655-p1 | test/core/dependencies/dependency_wirer_test.dart | unit | `buildYamlContent` carries the `# zfa:generated` provenance header — the writer/gate marker contract | criterion 2 (marker contract) | GREEN |
| U-1655-p2 | test/commands/build_yaml_guard_test.dart | unit | `BuildYamlGuard.scaffold` writes byte-identical `DependencyWirer.buildYamlContent` — guard-scaffolded pristine build.yaml is recognized the same as setup's (pre-existing suite, unchanged and green) | incremental-logic unchanged | GREEN |
| U-1655-p3 | test/plugins/tdd/services/refactor_passes_test.dart | unit | the build pass gate binding + the fresh-app static decision through `RefactorPasses.passSpecs` (pre-existing #1624/#1634 suite, unchanged and green against the updated note const) | criterion 4 | GREEN |

## Red evidence (pre-fix, this session)

Verbatim runs preserved in
`.specify/bugs/1655-setup-build-yaml-static-skip-unreachable/red-evidence.md`:

- Suite 1 (new, pre-fix): `dart test test/plugins/tdd/services/build_relevance_test.dart`
  → `00:00 +30 -1: Some tests failed.` — U-1655-b1 got `Actual: <null>` (the
  gate ran the first build on a pristine setup build.yaml): the issue's bug,
  reproduced at the gate level. U-1655-b2/b3/b4/b5 passed pre-fix as
  contract guards (they pin behavior that must survive the fix).

## Green evidence (post-fix, this session)

- `dart test test/plugins/tdd/services/build_relevance_test.dart`
  → `00:00 +31: All tests passed!`
- `dart test test/core/dependencies/dependency_wirer_test.dart
  test/commands/build_yaml_guard_test.dart
  test/commands/builder_dependency_preflight_test.dart
  test/plugins/tdd/services/refactor_passes_test.dart`
  → `00:05 +45: All tests passed!`
- `dart test test/commands/build_command_unit_test.dart --preset=all`
  (slow tier; writes the template through the guard paths)
  → `00:19 +48: All tests passed!`
- `dart test test/plugins/tdd/services/ test/core/dependencies/`
  → `01:40 +1151: All tests passed!`
- `dart test test/commands/`
  → `06:11 +401: All tests passed!`
