# Cycle Log: Slice Plugin — Context-Isolated Codebase Extraction

Append only. Newest last. Every entry's `red` block is the evidence that the test
existed and failed before the implementation.

## Baseline

- suite: `dart test` -> 2844 passed, 1 skipped, 8 failed
- commit: `ee0aa612`
- recorded: cycle 0, before any change (2026-08-29)
- suite_baseline: **red** — the loop must not start on top of this. All 8
  failures predate the feature and are unrelated to the slice plugin:
  - `test/commands/api_command_test.dart: ApiCommand zfa api <Entity> generates the bridge and does not throw`
  - `test/commands/initialize_dart_inplace_test.dart: InitializeCommand --dart in-place bootstrap (issue #393) --dart non-dry-run on repo without pubspec creates minimal pubspec in-place`
  - `test/commands/make_command_xray_default_test.dart: explicit xray:false in --from-json is preserved over the config default`
  - `test/commands/plugin_command_mcp_test.dart: PluginCommand.execute mcp mcp alias with --force writes the scaffolded files`
  - 4 further failures not enumerated in the reporter tail (it truncates); a
    full compact-reporter re-run is being captured to enumerate them and will
    be noted under Notes and deviations when it lands.

## Baseline (re-checked before cycle 1)

- Spot-check on this machine (2026-08-30, post-ee0aa612 branch state):
  `dart test test/commands/api_command_test.dart` -> 2 passed;
  `dart test test/regression/issue_495_core_commands_no_flutter_import_test.dart`
  -> 2 passed. The failures recorded in the original baseline did not
  reproduce here (they were perf-threshold, subprocess, and network-shaped
  tests). The original baseline record above still stands as the recorded
  pre-feature state; feature evidence remains scoped to
  `dart test test/plugins/slice/`.
- The full-repo suite could not be re-baselined before cycle 1: background
  runs are killed by the session harness and a foreground full run exceeds
  the tool timeout. It is run at verify time instead (see verification.md).

## Cycle 1: U65 + U66 — command shell validates usage (batch: component granularity)

- tests: `test/plugins/slice/slice_command_test.dart` (new)
  - `U65: an unknown subcommand fails with a usage error listing the valid subcommands`
  - `U66: cut without --entry fails with a usage error`
- red: `dart test test/plugins/slice/slice_command_test.dart` (after adding a
  minimal compilable `SliceCommand` stub with an empty `run()`)
  - U65 -> `Expected: contains 'Unknown slice subcommand: teleport' / Actual: ''`
  - U66 -> `Expected: contains '--entry' / Actual: ''`
  - (3 failed: both behaviors plus the no-args usage companion test)
- green: `lib/src/plugins/slice/slice_command.dart` — full command shell with
  `ArgParser.allowAnything()` dispatch (BoneCommand pattern), usage text
  listing all eight subcommands, per-subcommand arg parsers, and `_usageError`
  setting `exitCode = 64` (INV-1: usage text, never a stack trace).
  Suite `dart test test/plugins/slice/` -> 3 passed.
- refactor: none needed (first cycle, single file)
- commit: (see git log; recorded per commit below)

## Cycle 2: T002/T004/T005 — plugin class + dual registration (scaffolding, no behavior id)

- tests: `test/plugins/slice/slice_plugin_registration_test.dart` (new)
  - `PluginLoader registers the slice plugin (T004)`
  - `CodeGenerator registers the slice plugin (T005)`
  - `SlicePlugin exposes the zfa slice command (T002)`
- red: `dart test test/plugins/slice/slice_plugin_registration_test.dart`
  (after adding the minimal `SlicePlugin` stub)
  - T004 -> `Expected: contains 'slice'` (loader ids lacked it)
  - T005 -> `Expected: contains 'slice'` (registry ids lacked it)
- green: `SlicePlugin` extends `ZuraffaPlugin` implements `CliAwarePlugin`
  (research R-007), registered in `PluginLoader._plugins()` and the
  `CodeGenerator` constructor. Suite `dart test test/plugins/slice/` ->
  6 passed.
- refactor: none
- commit: (recorded in git history)


## Cycle 3: U1 + U2 + U3 — SliceManifest / ManifestWriter serialization

- tests: `test/plugins/slice/models/slice_manifest_test.dart` (new)
- red: `dart test test/plugins/slice/models/slice_manifest_test.dart` (after
  adding compilable model stubs whose toYaml/fromYaml/write/read threw
  UnimplementedError)
  - U1 -> `UnimplementedError` (write threw)
  - U2 -> `UnimplementedError` (write threw)
  - U3 -> `Expected: throws <Instance of 'SliceManifestError'> ... Actual:
    <Closure: () => Future<SliceManifest>>` (read threw UnimplementedError)
  - (5 failed: U1, U2, exportedTo companion, U3 x2)
- green: models (SliceDepth.parse, FileOwnership, SliceFile, SliceBoundary,
  SliceExportFormat, SliceManifest.toYaml/fromYaml with hand-rolled emission
  + package:yaml parsing) and ManifestWriter.write/read with
  SliceManifestError naming the slice directory. First implementation had a
  bug (self-package resolution dropped the `lib/` packageUri segment — see
  cycle 4); fixed within the cycle.
  Suite `dart test test/plugins/slice/models/` -> 5 passed.
- refactor: none
- commit: (recorded in git history)

## Cycle 4: U4-U8 — PackageResolver

- tests: `test/plugins/slice/engine/package_resolver_test.dart` (new)
- red: `dart test test/plugins/slice/engine/package_resolver_test.dart`
  (stub threw UnimplementedError)
  - U4-U6, U8 -> `UnimplementedError`
  - U7 -> `Expected: throws <Instance of 'PackageResolverError'> ... Actual:
    <Closure: () => Future<PackageResolver>>`
  - (6 failed)
- green: PackageResolver.load reads `.dart_tool/package_config.json`,
  classifies sdk/self/external/relative without filesystem access, resolves
  self-package URIs through rootUri+packageUri, resolves relative URIs
  against the importing file. First run had one real failure —
  U4: `Expected: '/tmp/.../lib/src/...' Actual: '/tmp/.../src/...'` — the
  packageUri (`lib/`) segment was ignored; fixed by joining
  root+packageUri+path. Suite -> 6 passed.
- refactor: extracted `_resolveRootUri` for file:///relative/SDK root URIs
  while green.
- commit: (recorded in git history)


## Cycle 5: U9-U12 — ServiceLocatorAnalyzer

- tests: `test/plugins/slice/engine/service_locator_analyzer_test.dart` (new)
- red: `dart test test/plugins/slice/engine/service_locator_analyzer_test.dart`
  (stub threw UnimplementedError; 6 failed across this and the two batches
  below — `dart test test/plugins/slice/engine/...` -> +0 -15)
  - U9/U10/U11 -> `UnimplementedError`
  - U12 -> `UnimplementedError`
- green: RecursiveAstVisitor over MethodInvocation type arguments.
  Two real bugs found by the red->green run and fixed in-cycle:
  (a) `getIt<T>()` parses with a NULL target (identifier invocation), so the
  first implementation requiring a getIt target found nothing —
  `Expected: contains 'GetProductUseCase' / Actual: []`;
  (b) snake_case mapping: the repo convention keeps `UseCase` as one word
  (`get_product_usecase_di.dart`), so the mapping now reuses
  StringUtils.camelToSnake after stripping the `UseCase` suffix (verified
  against the DI plugin's own emission in di_plugin.dart:963-973).
  Also adapted to analyzer 14.1.0 AST (SimpleIdentifier.token.lexeme,
  TypeArgumentList.arguments). Suite -> all slice tests passing.
- refactor: extracted `_targetIsGetItBinding` / `_targetIsGetItVariable`
- commit: (recorded in git history)

## Cycle 6: U13-U16 — BarrelResolver

- tests: `test/plugins/slice/engine/barrel_resolver_test.dart` (new)
- red: stub threw UnimplementedError (part of the +0 -15 batch above)
- green: barrel detection (exports only, no declarations), export-target
  expansion, show-clause filtering (U13), word-boundary reference matching
  for bare imports (U14), 120-registration DI barrel yielding exactly the
  two needed files (U15), non-barrel passthrough (U16). Adapted declaration
  name access to analyzer 14.1.0 (`namePart.typeName.lexeme` for
  class/enum, `name` for mixin/typedef/function/extension).
- refactor: none beyond the analyzer-shape fix
- commit: (recorded in git history)

## Cycle 7: U17-U19 — CompanionDetector

- tests: `test/plugins/slice/engine/companion_detector_test.dart` (new)
- red: stub threw UnimplementedError (part of the +0 -15 batch above)
- green: conventional sibling discovery (<name>.g.dart / <name>.freezed.dart
  on disk) unioned with declared part directives; missing declared
  companions record warnings naming the file (U18) without blocking the
  source. Suite `dart test test/plugins/slice/` -> 32 passed.
- refactor: none
- commit: (recorded in git history)


## Cycle 8: U20-U26 — ImportGraphWalker + FileGraph; U27-U28 — OwnershipClassifier

- tests: `test/plugins/slice/engine/import_graph_walker_test.dart` (new),
  `test/plugins/slice/engine/ownership_classifier_test.dart` (new)
- red: `dart test test/plugins/slice/engine/import_graph_walker_test.dart
  test/plugins/slice/engine/ownership_classifier_test.dart` -> +0 -17
  (stub threw UnimplementedError — deliberate not-implemented signal)
- green: dual-path traversal (imports + `getIt<T>()`), barrel expansion via
  the resolver, companion inclusion, depth-gated layer rules (view adds
  presenter at presentation, domain+di at feature, data at full), the DI
  cascade rule (a DI file whose imports cross an excluded layer is cut off
  with them — that is what makes feature-depth slices import-closed), cycle
  tolerance via a visited set, entry resolution with alternatives (U22), and
  boundary computation over the traversal edge (Rules A/B/C: declared types
  referenced by included files, super-interfaces of excluded files, and types
  registered by excluded DI wiring).
  Two in-cycle fixes:
  (a) the fixture-copy helper used `entity.uri.pathSegments.last`, which is
  EMPTY for directories (trailing slash) — `.dart_tool` never copied;
  replaced with `p.basename(entity.path)`;
  (b) the U26 test's own filter matched the shared usecase AND its DI file
  (`fetch_settings_usecase` is a prefix of both) — the assertion was
  imprecise; fixed the test filter to the exact file path (behavior was
  already correct).
  Suite `dart test test/plugins/slice/` -> 49 passed.
- refactor: made `BarrelResolver.declaredTopLevelNames` public and reused it
  for the walker's project-wide type index (single naming source of truth);
  cached the type index per walk instead of per lookup.
- commit: (recorded in git history)


## Cycle 9: U29-U31 — MockStubGenerator; U32-U34 — SandboxBootstrapper; U35-U36 — AgentReadmeGenerator

- tests: `test/plugins/slice/generators/mock_stub_generator_test.dart`,
  `test/plugins/slice/generators/sandbox_bootstrapper_test.dart`,
  `test/plugins/slice/generators/agent_readme_generator_test.dart` (new)
- red: `dart test test/plugins/slice/generators/` -> +0 -13 (stubs threw
  UnimplementedError)
- green: mock generation (`class Mock<T> implements T` with every public
  member stubbed by `throw UnimplementedError`, depth-aware, existing-strategy
  reuse), main_slice.dart/slice_di.dart emission (launcher home for
  multi-entry, real DI delegation + mock registrations), SLICE.md with
  owned/shared sections, boundary list, and the exact `-t` run path.
  In-cycle fix: the first bootstrapper draft leaked a Flutter type
  (`WidgetBuilder`) into pure-Dart code via a real launcher class — replaced
  with generated launcher TEXT emitted into main_slice.dart.
- refactor: none beyond that
- commit: (recorded in git history)

## Cycle 10: A1-A4 (gates T087-T090) — cut end-to-end (outer loop closed for US1)

- tests: `test/plugins/slice/slice_cut_integration_test.dart` (new, 8 tests)
- red: `dart test test/plugins/slice/slice_cut_integration_test.dart`
  -> +0 -8; decisive lines:
  - A1 -> `Expected: <0> ... Actual: 'slice cut is not wired yet'`
  - missing-entry -> `Expected: contains 'ghost' / Actual: 'slice cut is
    not wired yet'`
  (the placeholder cut path — the behavior did not exist)
- green: `CutSliceCapability` (walk -> ownership -> mirror copy -> mocks ->
  slice_di -> main_slice -> SLICE.md -> manifest) and the `cut` subcommand
  wiring. In-cycle fixes:
  (a) package import built as `package:zik_zak/lib/src/...` — package URIs
  address the package ROOT, so the `lib/` prefix is now stripped
  (`Expected: contains 'package:zik_zak/src/...'`);
  (b) two test-file interpolation bugs (`$sandbox` vs `${sandbox()}`) —
  fixed in the tests.
  Suite `dart test test/plugins/slice/` -> 70 passed.
- refactor: added `generatedFiles` to SliceManifest (round-trips; tells
  merge which sandbox files are harness, not agent work).
- commit: (recorded in git history)


## Cycle 11: U37-U40 — ConflictDetector; U41-U44 + U67/U68 — SliceMerger

- tests: `test/plugins/slice/merger/conflict_detector_test.dart`,
  `test/plugins/slice/merger/slice_merger_test.dart` (new)
- red: `dart test test/plugins/slice/merger/` -> +0 -8 (stubs threw
  UnimplementedError)
- green: 3-way hash decisions (skip/safeCopy/conflict/sandboxDeleted/
  agentCreated) + branch-mismatch warning; SliceMerger applies the
  decisions with shared-file confirmation gates (U42, U68), conflict
  preservation (U43), no-change cleanup (U44), agent-created copy-back
  (U67), and sandbox deletion on clean merges.
  In-cycle fix: the first test draft hashed contents with
  `hashCode.toRadixString` while the implementation hashes with sha256 —
  the test helper now uses crypto sha256 (same function as the cut).
  Also fixed two test-file type errors (Directory vs String).
- refactor: none
- commit: (recorded in git history)

## Cycle 12: A5-A8 (gates T091-T094) — merge end-to-end (outer loop closed for US2)

- tests: `test/plugins/slice/slice_merge_integration_test.dart` (new, 5 tests)
- red: `dart test test/plugins/slice/slice_merge_integration_test.dart`
  -> +0 -5; decisive: `Expected: <0> / Actual: ... 'slice merge is not
  wired yet'`
- green: MergeSliceCapability + the merge subcommand with --yes, terminal
  prompting (denies without a TTY — deterministic in tests/CI), and file
  listing in the merge output. In-cycle fixes:
  (a) cut now records `slice.yaml` in generatedFiles (otherwise merge
  treated the manifest as an agent-created file and copied it into the
  project);
  (b) merge output did not name the merged files (quickstart requires it);
  (c) `exitCode` persisted across invocations of one command instance —
  now reset at the start of every run().
  Suite `dart test test/plugins/slice/` -> 88 passed.
- refactor: none
- commit: (recorded in git history)


## Cycle 13: A9-A10 (gates T095-T096) — list and inspect

- tests: `test/plugins/slice/slice_list_inspect_test.dart` (new, 4 tests)
- red: `dart test test/plugins/slice/slice_list_inspect_test.dart` -> +0 -4;
  decisive: `Expected: <0> / ... 'slice list is not wired yet'`
- green: `list` scans `.zuraffa/slices/` for manifests (name, depth, file
  count, created date, entries) and `inspect` prints every file with
  ownership, layer, and modified-since-cut status (sha256 vs hashAtCut).
  In-cycle fixes: (a) dynamic dispatch on the enum `.name` getter throws
  NoSuchMethodError — the manifests map is now typed Map<String,
  SliceManifest> instead of dynamic; (b) inspect wraps manifest read errors
  (INV-1).
- refactor: none
- commit: (recorded in git history)

## Cycle 14: A11-A12 (gates T097-T098) — multi-entry (test-after note)

- tests: `test/plugins/slice/slice_multi_entry_test.dart` (new, 3 tests)
- red: none — the tests PASSED ON FIRST RUN. The multi-entry behavior was
  implemented and driven red-green at unit level during cycle 8 (U26:
  `dart test ... -> +0 -17` stub red; union dedup green in the same cycle),
  so the acceptance tests close an outer loop whose units were already
  green. Per the playbook's first-run rule, the deliberate-mutant check was
  applied instead of recording a red:
  - MUTANT-A11: cut passed only `[entries.first]` to the walker ->
    `dart test test/plugins/slice/slice_multi_entry_test.dart` -> +0 -3
    (all three tests caught the dropped entry). Restored exactly.
- green: mutant restored -> suite green.
- refactor: none
- commit: (recorded in git history)

## Cycle 15: A13-A15 (gates T099-T101) — depth levels (test-after note)

- tests: `test/plugins/slice/slice_depth_test.dart` (new, 4 tests)
- red: none — passed on first run. Depth gating was implemented and driven
  red-green at unit level in cycle 8 (U23/U24/U25 stub reds in the +0 -17
  batch; green same cycle) and depth-aware mocks in cycle 9 (U31).
  Deliberate-mutant check applied:
  - MUTANT-A13: `layerAllowedAtDepth` returned true unconditionally ->
    `dart test test/plugins/slice/slice_depth_test.dart` -> +2 -2 (A13 and
    A15 caught the flattened depth; A14 passes trivially under the mutant,
    as expected for the default depth). Restored exactly.
- green: mutant restored -> `dart test test/plugins/slice/` -> 99 passed.
- refactor: none
- commit: (recorded in git history)


## Cycle 16: U45-U47 - ImportVerifier; U48-U50 - AnalyzeRunner

- tests: `test/plugins/slice/verifier/import_verifier_test.dart`,
  `test/plugins/slice/verifier/analyze_runner_test.dart` (new)
- red: `dart test test/plugins/slice/verifier/` -> +0 -6 (stubs threw
  UnimplementedError)
- green: import resolution (dart: ok; self-package must exist in the
  sandbox tree; other packages must be declared in pubspec.yaml;
  relative imports must resolve to sandbox siblings; failures carry
  file:line:importPath) and the analyze wrapper through an injected
  ProcessLauncher seam (clean pass / structured error capture / missing
  toolchain -> environment message naming PATH).
  In-cycle test fixes: (a) Dart strips the leading newline of multiline
  string literals, so the U46 fixture's import sat on line 1 - a comment
  line now pins it to line 2 (the implementation was correct; verified
  with a scratch repro before touching the test); (b) the U47-dev fixture
  needed dev_dependencies in its pubspec.
- refactor: none
- commit: 01416b1e

## Cycle 17: A16-A19 (gates T102-T105) - verify end-to-end + cut --verify

- tests: `test/plugins/slice/slice_verify_integration_test.dart` (new, 4 tests)
- red: behavioral red via the `slice verify is not wired yet` placeholder
  (+0 -4; A18 additionally needed the analyzeLauncher seam parameter
  added for compilation - the language-requires-symbol case).
- green: VerifySliceCapability + the verify subcommand + `cut --verify`
  rollback. The first green run exposed a REAL design gap found by A16:
  the mirrored files' barrel imports dangled because the barrel itself
  was not in the sandbox:
  `unresolved: product_view.dart:7 "../../widgets/index.dart" - missing
  file (dangling import)`.
  Fix: the walker now records barrel expansions (WalkResult.barrels) and
  the cut mirrors each barrel FILTERED at its original path, exporting
  only the kept targets (FR-005 selective inclusion preserved; import
  closure restored). The A4 test was updated to assert the filtered
  barrel content instead of asserting the barrel's absence (the original
  assertion was an invention beyond the test-list - recorded here as a
  test correction with reason).
  One implementation bug in the fix: `addAll` on an unmodifiable const
  list (Cannot add to an unmodifiable list) - replaced with a spread.
  Suite `dart test test/plugins/slice/` -> 112 passed.
- refactor: barrel expansion recording moved into the walker's
  _expandImport (single source of truth for FR-005).
- commit: 01416b1e

## Notes and deviations

- Loop granularity: cycles are batched at component granularity (one commit
  per component group, per-behavior red evidence above). The playbook's
  one-behavior-per-cycle is impractical for 95 behaviors in this session; the
  evidence discipline (test first, observed red, recorded verbatim) is kept
  per behavior. Deviation recorded here per Hard Rule honesty requirements.
- The stack profile (`.specify/memory/tdd-profile.md`) predates frontmatter
  format and names the benchmark plugin in its scoped commands; feature-scoped
  commands in the test list are adapted from it. Consider
  `/speckit.tdd.setup refresh`.
- Baseline failure enumeration (second full run, compact reporter, same commit
  `ee0aa612`): 2845 passed, 1 skipped, 7 failed. Failing:
  - `test/commands/api_command_test.dart: ApiCommand zfa api <Entity> --domain <name> still generates the bridge`
  - `test/commands/make_command_xray_default_test.dart: absent xray key falls back to .zfa.json xrayByDefault:true`
  - `test/dda/route_build_stage_test.dart: build command wiring (subprocess) zfa build --dda-routes-only produces the router file`
  - `test/dda/route_perf_test.dart: 100 annotated Views compile into one config in under 2 seconds`
  - `test/package_sdk/package_e2e_test.dart: U30/SC-001: scaffold → pub get → analyze → entity → make → build, zero manual edits, under 5 minutes`
  - `test/plugins/benchmark/scenarios/sc_003_overhead_test.dart: overhead under 5 percent`
  - `test/regression/issue_495_core_commands_no_flutter_import_test.dart` (failed to load)
- The baseline is red AND partially non-deterministic: run 1 (2844/-8) and
  run 2 (2845/-7) failed on different tests. The varying entries are
  perf-threshold tests (`route_perf`, `sc_003_overhead`, `package_e2e`
  "under 5 minutes"), subprocess tests (`route_build_stage`), and xray-default
  tests that fail on different cases per run. All predate this feature and are
  unrelated to the slice plugin, but `/speckit.tdd.verify` must treat only
  `test/plugins/slice/` results as feature evidence, never the repo-wide count.
- Merge scope extended by user decision on 2026-08-29: merge handles
  agent-created and agent-deleted sandbox files, not only modified ones
  (extends FR-008 beyond its literal wording; spec.md untouched — bake in via
  `/speckit.clarify`). Recorded in test-list.md as U67/U68.

## Cycle 18: U51-U53 - SliceRunner; A20-A22 (gates T106-T108) - `slice run`

- tests: `test/plugins/slice/runner/slice_runner_test.dart` (new, 5 tests)
- red: behavioral red via the `slice run is not wired yet` placeholder
  (+0 -2 on the first two tests written; the remaining three were written
  in the same batch before any implementation existed, and failed red for
  the same reason — no `run` subcommand, no `SliceRunner` class:
  `Error: Method not found: 'SliceRunner'` during compilation).
- green: `SliceRunner` (resolve sandbox, fast-verify via `ImportVerifier`,
  then `flutter run -t <sandbox>/main_slice.dart` with
  `workingDirectory: projectRoot`, forwarding extra args verbatim) and the
  `run` subcommand in `SliceCommand` (name + passthrough flags via
  `argResults.rest`, `processLauncher` seam for tests). `dart test
  test/plugins/slice/runner/` -> 5 passed.
- refactor: none (thin wrapper per R-010; verification logic stays in
  `ImportVerifier`).
- commit: (this commit)
- notes: T085 (U65/U66 command validation tests) was implemented back in
  Cycle 1 but its tasks.md checkbox was never ticked; corrected here.

## Cycle 19: U54-U64 - PubspecFilter, TarballExporter, GithubExporter, SliceImporter, ExportSliceCapability; A23-A27 (gates T109-T113) - export/import

- tests: `test/plugins/slice/exporter/pubspec_filter_test.dart` (new, 4),
  `test/plugins/slice/exporter/tarball_exporter_test.dart` (new, 5),
  `test/plugins/slice/exporter/slice_importer_test.dart` (new, 3),
  `test/plugins/slice/capabilities/export_slice_capability_test.dart`
  (new, 1), `test/plugins/slice/slice_export_integration_test.dart`
  (new, 5).
- red: `dart test test/plugins/slice/exporter/ ...` -> +0 -2 both files
  failed to load: `Error when reading
  'lib/src/plugins/slice/exporter/pubspec_filter.dart': No such file or
  directory`, `'PubspecFilter' isn't a type`, `Method not found:
  'GithubExporter'`; the importer test failed the same way
  (`Method not found: 'SliceImporter'`); U58 and A23-A27 failed red against
  the `slice export is not wired yet` placeholder (behavioral red).
- green: PubspecFilter (analyzer-based import scan; flutter/flutter_test
  always kept; git/path/hosted sources preserved; hand-rolled YAML emission
  with conservative quoting), TarballExporter (tar+gzip via the archive
  package, filtered pubspec embedded at the archive root), GithubExporter
  (gh auth gate -> SLICE.md promoted to README.md -> git init/add/commit
  with pinned identity -> `gh repo create --private --source --push` ->
  `gh repo view --json url`; auto repo name
  `<package>-slice-<slice>`), SliceImporter (manifest exportedTo gate, git
  clone through the seam, copy-over-sandbox), ExportSliceCapability
  (verify gate FIRST, then filter + delegate; exportedTo recorded in
  slice.yaml), and the `export`/`import` subcommands wired in SliceCommand
  with a `ghLauncher` seam. `dart test test/plugins/slice/` -> 135 passed.
- design gap found while writing A24 (same class as cycle 17's barrel gap):
  the pushed repo needs a working pubspec.yaml (FR-018), but writing one
  into the sandbox would make merge treat it as an agent-created file and
  overwrite the project's real pubspec. Fix: GithubExporter embeds the
  filtered pubspec in the sandbox, and the merger's agent-created scan now
  skips export artifacts (pubspec.yaml, README.md) — generated files, not
  agent work, never merged back. No existing behavior changed (U67/U68
  still pass).
- in-cycle corrections: two compile-only test bugs (wrong relative import
  path for the helpers; a cascade/precedence error in captureOutput) and
  one missing constructor argument (`boundaries`) in the importer test's
  manifest fixture — all fixed before the first meaningful red run; the
  red evidence above is from the loaded-suite runs.
- refactor: none.
- commit: (this commit)
- notes: also marked A1-A9 and U1-U9 as DONE in test-list.md — those rows
  were implemented in cycles 7-13 but the earlier cycles only ticked
  tasks.md, never the test-list rows (bookkeeping debt, not new work).

## Cycle 20: T071-T076 - config integration, subcommand help, verbose, progress, e2e

- tests: `test/plugins/slice/slice_polish_test.dart` (new, 9),
  `test/plugins/slice/slice_e2e_test.dart` (new, 1), plus the configKey/
  configSchema assertions in `slice_plugin_registration_test.dart` style
  (inside slice_polish_test.dart).
- red: `dart test test/plugins/slice/slice_polish_test.dart
  test/plugins/slice/slice_e2e_test.dart` -> +0 -10 (configKey null, no
  per-subcommand help, no --verbose, no progress markers; the e2e test
  additionally tripped a test bug of its own — `singleWhere` over entity
  files that are legitimately multiple — fixed by asserting every entity
  file is shared instead of exactly one).
- green: SlicePlugin configKey 'sliceByDefault' + config schema
  (sliceByDefault, default-depth); focused `--help` per subcommand with
  examples (central dispatch before the switch, _subcommandHelp map);
  `--verbose` on cut (manifest files with ownership, boundaries, generated
  harness) and merge (per-file decisions); ProgressReporter (started /
  phase updates / completed / failed) wired through cut, merge, and export
  via an injectable `progressReporter` argument on the capabilities;
  e2e lifecycle test mirroring quickstart scenarios 1 and 2 (cut → verify →
  agent edit → merge, asserting the edit lands, exactly one file merged,
  and the sandbox is cleaned up). `dart test test/plugins/slice/` ->
  145 passed.
- refactor: fixed 8 analyzer warnings/infos in the slice tree accumulated
  over cycles 16-19 (unused import/field, unnecessary non-null assertion
  and interpolation braces, dartdoc angle brackets) — the slice tree now
  analyzes clean.
- deviation: T073 names ImportGraphWalker/CutSliceCapability/SliceMerger
  internals; verbose logging is implemented at the command layer from
  capability result data + manifests (the walk's phase-level progress IS
  reported through the capability). Per-node traversal logging was judged
  too noisy to be useful; recorded here per the honesty rule.
- T076 mapping: quickstart scenario 1+2 -> slice_e2e_test.dart; scenario 3
  -> slice_list_inspect_test.dart; scenario 4 -> service_locator_analyzer
  _test.dart + slice_cut_integration_test.dart; scenario 5 ->
  slice_export_integration_test.dart. All five scenarios have automated
  coverage; no manual run performed (no Flutter SDK in this environment —
  scenario steps that shell out to `zfa` are exercised through the command
  API with the fixture copy helper, as every other integration test in the
  repo does).
- commit: (this commit)

## Cycle 21: T114-T125 — TDD remediation (post-verify)

- trigger: `/speckit.tdd.verify` (commit de99a6b5) returned FAIL with 12
  findings; this cycle clears them. The audit report is committed unchanged
  in git history (de99a6b5) — this cycle is separate, explicit remediation
  work, not edits folded into the audit.
- fixes:
  - T114 (HIGH, repo-wide regression): the slice plugin's `cut_slice`
    capability is now registered in the speckit zuraffa extension
    (`.specify/extensions/zuraffa/extension.yml` +
    `commands/slice/cut_slice.md`), clearing the command-parity gate in
    `test/cli/standard/extension_command_parity_test.dart`. The failing
    parity test WAS the red; the registration is the green.
  - T115 (HIGH): A10 now pins the edited file's full status line
    (`'$viewRel — modified'`) and an untouched file's `— unmodified`.
    Proof: deliberate mutant M2 (never report modified) now fails the test
    (was surviving).
  - T116 (HIGH): A9 now pins the actual per-slice file count from the
    manifest. Proof: mutant M5 (always '0 files') now fails (was surviving).
  - T117 (HIGH): U20/U21/U26 now pin exact expected closure sets instead of
    Map/Set-uniqueness tautologies (missing OR extra files fail the test).
  - T118 (MED): A9's date expectation reads the manifest's createdAt — no
    real clock in the expectation.
  - T119 (MED): the e2e merge count is anchored
    (`(^|\s)1 file\(s\) copied back`) so '11 file(s)' cannot false-pass.
  - T120 (LOW): the progress test asserts the step marker
    (`RegExp(r'\[=+> *\] \d+/\d+')`), not just started/completed.
  - T121 (LOW): U9 asserts the exact extracted-type list.
  - T122 (LOW): registration test asserts values ('Slice', '1.0.0') and
    cleans its temp dirs.
  - T123 (LOW): the fixture setUp/tearDown pair moved to
    `helpers/slice_test_harness.dart` (freshSliceProject /
    disposeSliceProject) across the 10 fixture-backed files.
  - T124 (MED): A26/U58 documented as intentional distinct-negative
    coverage (no gh call pre-verify vs. no tarball on disk).
  - T125 (MED): A11-A15 test-after deviation recorded in the test list's
    Accepted deviations section.
  - also: 4 pre-existing analyzer warnings in the feature's test tree fixed
    (two unused imports, one dead local, one dartdoc escape).
- green: `dart analyze lib/src/plugins/slice/ test/plugins/slice/` clean;
  `dart test test/plugins/slice/` -> 145 passed;
  `dart test test/cli/standard/extension_command_parity_test.dart` -> 2
  passed.
- commit: (this commit)
