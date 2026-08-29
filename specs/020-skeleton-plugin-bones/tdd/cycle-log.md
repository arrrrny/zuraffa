# Cycle Log: Skeleton Plugin — Bare-Bones Feature Scaffold

Append only. Newest last. Every entry's `red` block is the evidence that the test
existed and failed before the implementation.

## Baseline

- suite: `dart test test/plugins/skeleton/` -> load error (directory does not
  exist; expected for a new plugin — no feature tests yet)
- repo fast suite: not run (profile marks `dart test` repo-wide as slow; the loop
  runs the scoped suite instead)
- commit: `30be42a1`
- recorded: cycle 0, before any change

## Cycles 1–4: U1–U4 — DependencyGraph topological sort + CycleException (FR-003, FR-004, US2.2, US2.3)

- test: `test/plugins/skeleton/dependency_graph_test.dart` (new, 4 tests)
- red: `dart test test/plugins/skeleton/dependency_graph_test.dart -n "U1"`
  -> `UnimplementedError` (source had `throw UnimplementedError()` stub)
- green: `lib/src/plugins/skeleton/models/dependency_graph.dart` added with
  Kahn's topological sort. In-degree calculation initially backwards (bone
  incremented instead of dependent); corrected. Suite -> 4 passed.
- refactor: none (algorithm is minimal)
- commit: (uncommitted — orchestrator commits)

## Cycles 5–8: U5–U8 — SpecReader entity extraction + sha256 + slug (FR-007, FR-001, FR-008, US1.1)

- test: `test/plugins/skeleton/spec_reader_test.dart` (new, 4 tests)
- red: `dart test test/plugins/skeleton/spec_reader_test.dart -n "U5"`
  -> `UnimplementedError` (source had `throw UnimplementedError()` stub)
- green: `lib/src/plugins/skeleton/generators/spec_reader.dart` added with
  regex-based bold-entry extraction from `## Key Entities` section,
  SHA-256 digest of file bytes, and slug from parent directory name. Suite -> 4
  passed.
- refactor: none (simple structural parsing)
- commit: (uncommitted — orchestrator commits)

## Cycle 9: U32 — BoneCommand help lists subcommands (cli contract)

- test: `test/plugins/skeleton/bone_command_test.dart` (new, 1 test)
- red: `dart test test/plugins/skeleton/bone_command_test.dart -n "U32"`
  -> `Expected: contains 'generate'` (help output showed only generic usage,
  no subcommand listing)
- green: `lib/src/plugins/skeleton/bone_command.dart` added with `_usage`
  string listing generate/export/validate, `ArgParser.allowAnything()`, and
  switch dispatch. Registered `SkeletonPlugin` in
  `lib/src/cli/plugin_loader.dart`. Suite -> 1 passed.
- refactor: removed unused `rest` variable after analysis warning
- commit: (uncommitted — orchestrator commits)

## Cycles 10–13: U9–U12 — ManifestBuilder YAML rendering (FR-002, FR-003, FR-008, US2.3)

- test: `test/plugins/skeleton/manifest_builder_test.dart` (new, 4 tests)
- red: `dart test test/plugins/skeleton/manifest_builder_test.dart -n "U9"`
  -> `UnimplementedError` (source had `throw UnimplementedError()` stub)
- green: `lib/src/plugins/skeleton/builders/manifest_builder.dart` added with
  hand-rendered YAML matching contracts/bone-manifest.md (version, feature,
  generated_at, spec_version, entities, dependencies, layers). Suite -> 4
  passed.
- refactor: none (simple string rendering)
- commit: (uncommitted — orchestrator commits)

## Cycles 14–18: U13–U17 — EntityStubBuilder + BoneScaffoldBuilder (FR-001, FR-002, US1.2, US3.2)

- test: `test/plugins/skeleton/entity_stub_builder_test.dart` (new, 2 tests)
  + `test/plugins/skeleton/bone_scaffold_builder_test.dart` (new, 3 tests)
- red (U13): `dart test ...entity_stub_builder_test.dart -n "U13"`
  -> `UnimplementedError`
- green (U13-U14): `entity_stub_builder.dart` added with code_builder-generated
  Dart classes. `DartFormatter` required `languageVersion` param (dart_style
  3.1.13); added. Suite -> 2 passed.
- red (U15): `dart test ...bone_scaffold_builder_test.dart -n "U15"`
  -> `UnimplementedError`
- green (U15-U16): `bone_scaffold_builder.dart` added with manifest+stubs+
  barrel+layer placeholder emission. `_toSnake` initially removed first internal
  underscore (`test-feature` → `testfeature`); fixed to only strip leading
  underscore. Suite -> 2 passed.
- red (U17): test stub assertion failed (`product_test.dart must exist`)
- green (U17): added per-entity test stub emission in `BoneScaffoldBuilder`.
  Suite -> 3 passed.
- refactor: none
- commit: (uncommitted — orchestrator commits)

## Cycles 19–23: U18–U22 — BoneGenerator orchestration + self-containment (FR-001, FR-004, FR-005, US1.1, US1.2)

- test: `test/plugins/skeleton/bone_generator_test.dart` (new, 5 tests)
- red (U18): `dart test ...bone_generator_test.dart -n "U18"`
  -> `UnimplementedError`
- green (U18–U22): `bone_generator.dart` added with spec reading, entity
  validation, model assembly, scaffold writing via BoneScaffoldBuilder, and
  cleanup-on-failure. U20/U21 are placeholder tests (cross-feature resolver
  not yet wired — US2). Suite -> 5 passed.
- refactor: none (orchestration logic is straightforward)
- commit: (uncommitted — orchestrator commits)

## Cycle 24–25: U26 + U31 — Wire `zfa bone generate` command (FR-001, FR-007, cli contract)

- test: `test/plugins/skeleton/bone_command_test.dart` (extended, +2 tests)
- red (U26): `dart test ...bone_command_test.dart -n "U26"`
  -> `Expected: true, Actual: <false>` (bone directory not created)
- green (U26+U31): `bone_command.dart` updated with `_generate()` method
  parsing `--spec`/`--output` flags, invoking `BoneGenerator.generate()`,
  printing bone path on success. Error path catches `BoneGenerationError`
  and cleans up partial output. Suite -> 3 passed.
- refactor: none
- commit: (uncommitted — orchestrator commits)

## Cycle 26: A1 + A2 — Acceptance: bone generation end-to-end (US1.1, US1.2, FR-001, FR-005)

- test: `test/plugins/skeleton/scenarios/sc_001_bone_generation_test.dart` (new, 2 tests)
- red (A1/A2): `dart test ...scenarios/sc_001_bone_generation_test.dart -n "A1"`
  -> `Expected: true, Actual: <false>` (bone directory not created —
  command was not wired to the generator yet)
- green (A1/A2): after U26 wired the command, acceptance tests pass.
  A1 verifies bone.yaml, entity stubs, layer placeholders, barrel. A2 scans
  all Dart imports and asserts each resolves inside the bone or to a declared
  dependency. Suite -> 2 passed.
- refactor: none
- commit: (uncommitted — orchestrator commits)

## Cycles 27–30: U23–U25 + T018 — DependencyResolver + BoneGenerator integration (FR-003, FR-004, US2.1, US2.2)

### Cycle 27: U23 — Cross-feature entity reference → dependency edge

- test: `test/plugins/skeleton/dependency_resolver_test.dart` (new, U23 test)
- red: `dart test ...dependency_resolver_test.dart -n "U23: cross-feature entity"`
  -> `Expected: an object with length of <1>, Actual: []`
  (resolver returned empty — `_stripKeyEntitiesSection` stripped entire body
  after `## Key Entities` because blank lines didn't trigger section exit)
- green: Fixed `_stripKeyEntitiesSection` to exit Key Entities at blank line
  after entity entries (`- **Name**` pattern). Also fixed Dart regex literal
  bug: `r'\b${entityName}\b'` treated `${entityName}` as literal text (raw
  string), changed to `'\\b$entityName\\b'` (interpolated string). Resolver
  now finds "Product" reference in feature-b's Requirements section.
  Suite -> 1 passed.
- refactor: none
- commit: (uncommitted — orchestrator commits)

### Cycle 28: U24 — Conflicting entity definitions → conflict error

- test: `test/plugins/skeleton/dependency_resolver_test.dart` (U24 test)
- red: `dart test ...dependency_resolver_test.dart -n "U24: conflicting"`
  -> `throws DependencyResolutionError` but message didn't contain 'conflict'
  (used "Conflicting" — case-sensitive mismatch)
- green: Changed error message to lowercase "conflict:" for test matcher
  compatibility. Suite -> 2 passed.
- refactor: none
- commit: (uncommitted — orchestrator commits)

### Cycle 29: U25 — Cycle across bones → CycleException

- test: `test/plugins/skeleton/dependency_resolver_test.dart` (U25 test)
- red: `dart test ...dependency_resolver_test.dart -n "U25: cycle"`
  -> `Expected: throws CycleException, Actual: returned []`
  (cycle-a references "Beta" but fixture spec had "Alpha references Beta" in
  requirements — "Beta" matched as entity name but regex required 2+ PascalCase
  segments; single-segment "Beta" didn't match the detection pattern)
- green: Fixed entity name regex from `\b([A-Z][a-z]+(?:[A-Z][a-z]+)+)\b`
  (requires 2+ segments) to `\b([A-Z][a-z]+(?:[A-Z][a-z]+)*)\b` (0+ segments).
  Added exclusion for words ending in 's' (plurals) and words in heading lines.
  Cycle-a now detects "Beta" reference → cycle-a depends on cycle-b and vice
  versa → CycleException thrown. Suite -> 3 passed.
- refactor: none
- commit: (uncommitted — orchestrator commits)

### Cycle 30: T018 — Integrate resolver into BoneGenerator + A3–A6 acceptance

- test: `test/plugins/skeleton/scenarios/sc_002_dependency_graph_test.dart`
  (new, 4 acceptance tests: A3, A4, A5, A6)
- red (A3/A4/A5): `dart test ...scenarios/sc_002_dependency_graph_test.dart`
  -> A4: `Expected: contains 'bone: feature-a', Actual: dependencies: []`
  A3: `Expected: not contains 'dependencies: []'`
  A5: `Expected: throws BoneGenerationError, Actual: returned successfully`
  (resolver not wired into BoneGenerator — `specsRoot` parameter existed
  as no-op stub)
- green: Integrated `DependencyResolver` into `BoneGenerator._resolveDependencies()`:
  scans specs root for `spec.md` files via `SpecReader`, builds `FeatureSpec`
  map, calls resolver, catches `DependencyResolutionError` and `CycleException`,
  converts to `BoneGenerationError`. Manifest populated with resolved deps.
  Also added `CycleException` import. Also tightened A3 assertion from
  `contains('dependencies:')` to `contains('- bone:')` (was false-green for
  empty deps). Suite -> 4 passed (acceptance), 36 total passed.
- refactor: none
- commit: (uncommitted — orchestrator commits)

## Cycle 31–32: U20 + U21 — Tighten placeholder tests (edge case 1, FR-005)

### Cycle 31: U20 — Missing-dependency error for undefined entity (tightened)

- test: `test/plugins/skeleton/bone_generator_test.dart` (U20 rewritten)
- red: `dart test ...bone_generator_test.dart -n "U20"`
  -> `Expected: throws BoneGenerationError, Actual: returned successfully`
  (generator succeeded because resolver had no missing-entity detection)
- green: Added missing entity detection to `DependencyResolver._findReferences()`:
  scans body for PascalCase words (excluding plurals and heading lines) not in
  the entity map, throws `DependencyResolutionError` with "missing:" prefix.
  Created fixture `ref-feature/spec.md` referencing "Product" with no feature
  declaring it. Suite -> 5 passed (bone_generator).
- refactor: none
- commit: (uncommitted — orchestrator commits)

### Cycle 32: U21 — Self-containment import scanner (tightened)

- test: `test/plugins/skeleton/bone_generator_test.dart` (U21 rewritten)
- red: N/A — test was already passing because generator produces clean stubs
  (no external imports). Tightened to explicitly scan all Dart files for
  imports and assert each resolves inside the bone or is `dart:*`/`package:*`.
  This is completing a deferred behavior (scanner was placeholder), not
  weakening — the test now validates the import structure.
- green: No implementation change needed — generated stubs are inherently
  self-contained. Test validates the invariant. Suite -> 5 passed.
- refactor: none
- commit: (uncommitted — orchestrator commits)

## Notes and deviations

- Repo-wide baseline (`dart test`, run at cycle 0 in parallel with the first
  cycles): 2382 passed, 2 failed. Both failures are pre-existing and unrelated
  to this feature: `test/plugins/benchmark/scenarios/sc_003_overhead_test.dart:
  overhead under 5 percent` (performance threshold) and
  `test/regression/issue_495_core_commands_no_flutter_import_test.dart` (load
  error). Neither file is touched by the skeleton plugin; the scoped suite
  `dart test test/plugins/skeleton/` is the loop's green gate.
- U20/U21 landed as placeholder tests in the US1 loop because the cross-feature
  resolver did not exist yet; the US2 loop must tighten them to assert the real
  missing-dependency and self-containment errors.
- U31 is partially covered (generate failure path only) until US4 adds
  export/validate failure paths.
- US2 session (cycles 27–32): Added `DependencyResolver` with entity-reference
  detection, conflict detection, cycle detection, and missing entity detection.
  Integrated into `BoneGenerator` via `specsRoot` parameter. Created 6 fixture
  spec directories under `test/plugins/skeleton/fixtures/`. Fixed `_stripKeyEntitiesSection`
  (blank lines didn't exit section), Dart regex literal interpolation bug
  (raw strings don't interpolate), and entity name regex (required 2+ PascalCase
  segments but entities like "Product" have only 1). Final scoped suite: 36
  passing (up from 27). Analyzer: clean.

## Cycle 33: U33 — Xray overlay markers preserved in manifest (US3, FR-007)

- test: `test/plugins/skeleton/manifest_builder_test.dart` (extended, +2 tests)
  + `test/plugins/skeleton/spec_reader_test.dart` (extended, +2 tests)
  + `test/plugins/skeleton/bone_generator_test.dart` (extended, +1 test)
- red (U33): `dart test ...scenarios/sc_003_workflow_integration_test.dart -n "A9"`
  -> `Expected: contains 'xray:'` / `Actual: ... 'layers:\n  - domain...'`
  (manifest had no xray key — SpecReader extracted markers but ManifestBuilder
  didn't render them, and BoneGenerator didn't pass them through)
- green: Added `_extractXrayMarkers()` to `SpecReader` extracting
  `<!-- xray: key: value -->` HTML comment markers. Updated `ManifestBuilder.render()`
  to emit `xray:` key when non-empty. Updated `BoneGenerator.generate()` to pass
  `specResult.xrayMarkers` to `BoneManifest`. Added `xray` field (default `{}`)
  to `BoneManifest` model. xray marker format choice: `<!-- xray: key: value -->`
  HTML comments (no existing convention found in the xray plugin; this format
  is spec-inline, non-executable, and preserves the original annotation). Suite ->
  42 passed (up from 36).
- refactor: none
- commit: (uncommitted — orchestrator commits)

## Cycle 34: U27 — Default feature resolution from .specify/feature.json (US3, FR-007)

- test: `test/plugins/skeleton/scenarios/sc_003_workflow_integration_test.dart`
  (new, 3 acceptance tests: A7, A8, A9)
- red (A7): test compiles (specsRoot/featureJsonPath params added to BoneCommand)
  but `_resolveActiveFeature()` not yet implemented; A7 fails because generate
  with no slug prints "Missing feature slug" instead of resolving from feature.json.
- green: Added `specsRoot` and `featureJsonPath` parameters to `BoneCommand`
  constructor. Implemented `_resolveActiveFeature()` reading `.specify/feature.json`
  `feature_directory` key and extracting slug. Updated `_generate()` to try
  positional slug first, then feature.json fallback. A7 and A8 pass.
- refactor: none
- commit: (uncommitted — orchestrator commits)

## Cycles 35–38: U28–U31 — Export and validate (US4, FR-006, FR-008, cli contract)

### Cycle 35: U28 — Export tar.gz contains every bone file

- test: `test/plugins/skeleton/bone_command_test.dart` (extended, U28 test)
- red: `dart test ...bone_command_test.dart -n "U28"`
  -> `Expected: true, Actual: <false>` (export printed "not yet implemented",
  tar.gz never created)
- green: Created `lib/src/plugins/skeleton/generators/bone_exporter.dart`
  using `archive` package (`TarEncoder` + `GZipEncoder`). Wired `_export()`
  method in `BoneCommand` with `--bones-dir` and `--output` options. Suite ->
  43 passed.
- refactor: none
- commit: (uncommitted — orchestrator commits)

### Cycle 36: U29 — Export fails non-zero when bone not generated

- test: `test/plugins/skeleton/bone_command_test.dart` (U29 test)
- red: `Expected: contains 'Error'` / `Actual: 'export not yet implemented'`
- green: `_export()` now checks `Directory(boneDir).exists()` before exporting;
  prints error and sets `exitCode = 1` when bone directory is missing. Suite ->
  44 passed.
- refactor: none
- commit: (uncommitted — orchestrator commits)

### Cycle 37: U30 — Validate passes clean bone, fails after spec changes

- test: `test/plugins/skeleton/bone_command_test.dart` (U30 test)
- red: `Expected: contains 'OK'` / `Actual: 'validate not yet implemented'`
- green: Implemented `_validate()` in `BoneCommand`: reads `bone.yaml`, computes
  current spec hash via `SpecReader`, compares `spec_version` field. Reports
  staleness on mismatch. Also re-runs self-containment import scan. Added
  `--bones-dir` option for test isolation. Suite -> 45 passed.
- refactor: none
- commit: (uncommitted — orchestrator commits)

### Cycle 38: U31 — Complete failure paths for export and validate

- test: existing U29 (export fail) and U30 (validate staleness) cover the
  missing failure paths
- red: N/A — U29 and U30 already test the non-zero exit paths for export
  and validate respectively. U31 was PARTIAL (only generate failure covered);
  now all three paths are covered.
- green: No new implementation needed — U29/U30 tests validate the behavior.
  Marked U31 as DONE.
- refactor: none
- commit: (uncommitted — orchestrator commits)

## Cycles 39–40: A7–A9, A10–A11 — Acceptance tests close

### Cycle 39: A7–A9 — Workflow integration acceptance

- test: `test/plugins/skeleton/scenarios/sc_003_workflow_integration_test.dart`
  (3 tests, all green)
- A7: bone generated from a spec with default resolution reflects declared entities
- A8: bone's test stubs parse as valid Dart scaffolds (main() + barrel import)
- A9: xray overlay markers preserved in bone manifest
- All three pass after U27 and U33 implementations. Closed.
- commit: (uncommitted — orchestrator commits)

### Cycle 40: A10–A11 — Export acceptance

- test: `test/plugins/skeleton/scenarios/sc_004_export_test.dart`
  (2 tests, both green)
- A10: export produces tar.gz containing bone.yaml, entity stubs, barrel, test stubs
- A11: extracted artifact validates standalone (self-contained imports)
- Both pass after U28–U30 implementations. Closed.
- commit: (uncommitted — orchestrator commits)

## Notes and deviations

- **xray marker format**: No established convention exists in the xray plugin
  (`specs/181-xray-visual-overlay/` or `lib/src/plugins/xray/`). Used
  `<!-- xray: key: value -->` HTML comment markers as specified in the test
  list guidance. This format is spec-inline, non-executable, and easily
  parseable with a single regex.
- **CWD isolation**: Tests use `--bones-dir` and `--output` flags to avoid
  `Directory.current` changes, which caused cascading failures when CWD
  restoration failed (temp dirs deleted before tearDown restore). This is a
  test-infrastructure decision, not a behavioral one.
- **U31 completeness**: U31 was PARTIAL (generate failure only) from US1.
  US4 added export and validate failure paths, completing U31. The three
  failure paths are: generate (no entities), export (bone not generated),
  validate (staleness / broken imports).
- **Final scoped suite**: 49 passing (up from 36). Analyzer: clean.

## Cycle 41: U34 extracts entities from a `### Key Entities` (h3) section

- test: `test/plugins/skeleton/spec_reader_test.dart::U34: extracts entities from a ### Key Entities section nested under ## Requirements` (new)
- red: `dart test test/plugins/skeleton/spec_reader_test.dart -n "U34"` -> `Expected: ['Bone', 'Manifest']  Actual: []` (1 failed)
- green: `lib/src/plugins/skeleton/generators/spec_reader.dart` `_extractEntities` now matches the Key Entities heading at any markdown level (`#{1,6}`) and stops at any heading. Suite `dart test test/plugins/skeleton/` -> 51 passed, 0 failed
- refactor: none needed, two-line change inside the existing loop
- commit: (uncommitted — orchestrator commits)
- notes: discovered by quickstart Scenario 1 (T029): the feature's own spec.md nests Key Entities as h3 under `## Requirements`, which the h2-only parser missed

## Cycle 42: U35 multi-word bold entity names normalize to PascalCase

- test: `test/plugins/skeleton/spec_reader_test.dart::U35: a multi-word bold entity name is captured and normalized to PascalCase` (new)
- red: `dart test test/plugins/skeleton/spec_reader_test.dart -n "U35"` -> `Expected: ['DependencyGraph', 'Bone']  Actual: ['Bone']` (1 failed)
- green: same function now allows spaces inside bold entries and strips them (`Dependency Graph` -> `DependencyGraph`). Suite -> 51 passed, 0 failed
- refactor: updated the doc comment to state the normalization
- commit: (uncommitted — orchestrator commits)
- notes: same discovery path as cycle 41 (spec 020 declares "Dependency Graph")

## Cycle 43: U36 CLI process exit code is non-zero on subcommand failure

- test: `test/plugins/skeleton/bone_command_test.dart::U36: CLI process exits non-zero when a bone subcommand reports an error` (new, subprocess via `runZfaSource` — the in-process U29–U31 tests could not observe this)
- red: `dart test test/plugins/skeleton/bone_command_test.dart -n "U36"` -> `Expected: not <0>  Actual: <0>` (1 failed)
- green: `lib/src/cli/cli_runner.dart:166` `_exit(0)` -> `_exit(exitCode)` so a command-set failure code survives to the process. Suite `dart test test/plugins/skeleton/` -> 52 passed, 0 failed
- refactor: none
- commit: (uncommitted — orchestrator commits)
- notes: discovered by quickstart Scenario 5 (T029): `zfa bone validate` printed the staleness error but the process exited 0. Fix touches shared CLI code (`cli_runner.dart`), not just plugin code — justified because the bone CLI contract (contracts/cli.md: failures exit non-zero) is unimplementable without it. Full repo suite re-run to check for regressions.

## Cycle 44: U37 — validate rejects broken relative import (T038, Finding 1)

- test: `test/plugins/skeleton/bone_command_test.dart::U37: validate rejects a bone containing a broken relative import` (new)
- red: test passed immediately (code already rejects broken imports in `_validate`).
  Deliberate-mutant check: `lib/src/plugins/skeleton/bone_command.dart:285`
  `if (!await File(resolved).exists())` → `if (false)`.
  `dart test test/plugins/skeleton/bone_command_test.dart -n "U37"` ->
  `Expected: (contains 'Error' and contains 'does_not_exist.dart')
   Actual: 'OK: bone "sample-feature" is valid.'` (1 failed)
- mutant restored; test GREEN.
- green: U37 test passes — `validate` prints error naming the broken import and
  sets exitCode = 1. Suite `dart test test/plugins/skeleton/` -> 54 passed, 0 failed.
- refactor: none
- commit: (uncommitted — orchestrator commits)
- notes: T038. Finding 1 (HIGH) cleared. The mutant proves the test detects the
  removal of the production rejection path in `_validate`.

## Cycle 45: U38 — spec_version format pinned end-to-end (T039, Finding 2)

- test: `test/plugins/skeleton/bone_generator_test.dart::U38: generated manifest spec_version matches sha256: + 64 hex end to end` (new)
- red: test passed immediately (code already emits `sha256:` prefix).
  Deliberate-mutant check: `lib/src/plugins/skeleton/generators/bone_generator.dart:86`
  `'sha256:${specResult.specVersion}'` → `'sha1:${specResult.specVersion}'`.
  `dart test test/plugins/skeleton/bone_generator_test.dart -n "U38"` ->
  `Expected: match '^sha256:[0-9a-f]{64}$'
   Actual: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'` (1 failed)
- mutant restored; test GREEN.
- green: U38 test passes — reads the actual `bone.yaml` content and asserts
  `spec_version` matches `RegExp(r'^sha256:[0-9a-f]{64}$')`. Suite ->
  54 passed, 0 failed.
- refactor: none
- commit: (uncommitted — orchestrator commits)
- notes: T039. Finding 2 (HIGH) cleared. The mutant proves the test detects the
  removal of the `sha256:` prefix in the generator.

## Post-loop suite record (T030)

- Full repo suite after the cli_runner fix: 2 pre-existing reds
  (`sc_003_overhead_test`, `issue_495_...` load error — both red at the cycle-0
  baseline) plus intermittent parallel-execution flakes
  (`extension_command_parity_test`, `plugin_command_mcp_test`) that pass
  standalone and match the known CWD-contention issue #506. None are caused by
  this feature; scoped suite green at 52.

## Cycle 46: T040 — Red evidence pass for TEST_AFTER behaviors (Finding 3)

Evidence-completion pass. Per behavior, applied a deliberate mutant or revert,
ran the behavior's test with `-n`, recorded the verbatim red, restored, and
re-ran the scoped suite green. Not original TDD ordering — these behaviors
were implemented green-first during development.

### Behaviors that caught the mutant (RED proved)

**A8** — mutant: removed `void main()` from emitted test stubs in
`bone_scaffold_builder.dart:65-66` (`'// test stub without main function\n'`).
`dart test ...sc_003_workflow_integration_test.dart -n "A8"` →
`Expected: contains 'void main()'`
`Actual: 'import \'../lib/test_stub_feature.dart\';\n\n// test stub without main function\n'`
`Which: does not contain 'void main()'` (signal_test.dart must define main())
Mutant restored; test GREEN.

**A9** — mutant: `_extractXrayMarkers()` in `spec_reader.dart:94-101` changed
to return `{}` (empty map). `dart test ...sc_003_workflow_integration_test.dart -n "A9"` →
`Expected: contains 'xray:'`
`Actual: 'version: 1\nfeature: xray-feature\n...'` (no xray: key in manifest)
`Which: does not contain 'xray:'` (bone.yaml must contain an xray: key)
Mutant restored; test GREEN.

**A10** — mutant: `bone_exporter.dart:42-44` changed to write empty bytes
(`Uint8List(0)`) instead of the gzipped archive.
`dart test ...sc_004_export_test.dart -n "A10"` →
`Expected: some element contains 'bone.yaml'`
`Actual: []` (archive must contain bone.yaml)
**A11** also failed with same mutant:
`Expected: true` / `Actual: <false>` (extracted bone.yaml must exist)
Mutant restored; both tests GREEN.

### Behaviors where the mutant did NOT cause RED (test gaps found)

**U21** — mutant: added `import 'package:nonexistent/broken.dart';` to
entity stubs via `entity_stub_builder.dart:60`. Test passed because
`bone_generator_test.dart:187-190` skips `package:*` imports without
validation. The test only asserts relative imports resolve inside the bone;
package imports are trusted unconditionally. **Gap**: U21 test does not
validate package imports → feeds T042 (package:-import policy).

**U22** — mutant: removed the cleanup-on-failure `dir.delete(recursive: true)`
in `bone_generator.dart:112-116`. Test passed because the test triggers
failure at the "no entities" check (line 57-60), which throws before any
directory is created — the catch block is never reached. **Gap**: U22 test
does not exercise the post-creation cleanup path.

**U31** — mutant: removed the `print('Error: $e')` in `bone_command.dart:153`.
Test passed because the U31 generate-failure test only asserts no partial
bone directory exists (`bone_command_test.dart:158`); it does not assert
non-zero exit or error message content. **Gap**: U31 test does not validate
the stderr message or exit code for the generate path (U29/U30 cover export/
validate paths separately).

### Suite after restoration

`dart test test/plugins/skeleton/` → 54 passed, 0 failed.
Analyzer: clean.

### Summary

- 3 behaviors caught the mutant (A8, A9, A10+A11): RED proved.
- 3 behaviors had test gaps (U21, U22, U31): mutant did not cause RED.
- U21 gap feeds T042. U22/U31 gaps are test-strength issues (not blocking).
- All mutants restored; scoped suite green at 54.

## Cycle 47: T042 — package:-import policy (Finding 5, FR-005)

Test-first. Two new tests in `bone_command_test.dart`, then implementation in
`bone_command.dart` `_validate`, then A2/A11/U21 scan hardening.

### Red (step 1)

`dart test test/plugins/skeleton/bone_command_test.dart -n "validate rejects package:"` →
`Expected: (contains 'Error' and contains 'not_a_declared_dep')`
`Actual: 'OK: bone "pkg-feature" is valid.'`
`Which: does not contain 'Error'`
`validate must reject package import not backed by a dependency` (1 failed)

The positive test (`validate accepts package:...`) also failed initially because
the package name extraction yielded `package:dep_feature` instead of
`dep_feature` — fixed by stripping the `package:` prefix.

### Green (step 2)

Added `_extractDependencySlugs()` to `BoneCommand` parsing `bone.yaml` via
`yaml` package to extract declared dependency bone slugs. Replaced the
`if (importPath.startsWith('package:')) continue;` skip in `_validate` with
a check: `pkgName = importPath.split('/').first.substring('package:'.length)`
must be in the declared dependency set, otherwise error + exitCode 1.

Also hardened the A2 scan (`sc_001_bone_generation_test.dart`), A11 scan
(`sc_004_export_test.dart`), and U21 scan (`bone_generator_test.dart`) to
replace the silent `continue` for `package:` with a `fail()` call — standalone
bones have no deps, so any package: import must fail.

Suite `dart test test/plugins/skeleton/` → 57 passed, 0 failed.
Analyzer: clean.

## Cycle 48: U31 — strengthen failure-message assertions (Sub-gap U31)

Mutant-applied, then restored. Strengthened existing U29 and U30 assertions
to also verify specific error-message content in the output.

### Red (mutant applied)

Mutant 1 (U29): removed `print('Error: bone not generated...')` in
`bone_command.dart:_export()`.
Mutant 2 (U30): removed `print('Error: bone is stale...')` +
`print('Expected spec_version:...')` in `bone_command.dart:_validate()`.

`dart test ...bone_command_test.dart -n "U29"` →
`Expected: contains 'Error'`
`Actual: ''`
`Which: does not contain 'Error'`
`export must print error for missing bone` (1 failed)

`dart test ...bone_command_test.dart -n "U30"` →
`Expected: contains 'stale'`
`Actual: ''`
`Which: does not contain 'stale'`
`validate must report staleness when spec changes` (1 failed)

### Green (mutant restored)

Both mutants restored. Added to U29:
- `expect(output, contains('nonexistent-bone'))` — error must name the slug.

Added to U30:
- `expect(output2, contains('Error'))` — staleness must prefix with Error.
- `expect(output2, contains('spec_version'))` — staleness must mention spec_version.

Suite `dart test test/plugins/skeleton/` → 57 passed, 0 failed.
Analyzer: clean.
