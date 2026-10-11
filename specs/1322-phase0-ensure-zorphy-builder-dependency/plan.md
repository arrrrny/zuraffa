# Plan 1322 — phase-0 builder-dependency preflight + missing-dependency diagnosis

## Technical Context

- Toolchain: Dart 3.13.3 stable (SDK constraint `^3.11.0` respected);
  pure-Dart package — no Flutter SDK in the loop.
- The dependency-graph truth store: `.dart_tool/package_config.json`
  (`packages: [{name: …}, …]`). A package is "resolvable" iff its name
  appears there. An ABSENT file = UNVERIFIABLE state — every diagnosis
  in this spec refuses to fire there (no false positives; the issue is
  specifically "file exists but the builder package is not in it").
- The effective builder set for a project:
  - the builders registered in `<root>/build.yaml` when that file
    exists, UNION
  - the canonical builder set `DependencyWirer.buildYamlContent`
    scaffolds (`zorphy:zorphy`, `json_serializable`,
    `source_gen:combining_builder`) — because phase-0's `zfa build`
    step scaffolds exactly that file when missing (`ensureBuildYaml`).
  The union guarantees the preflight runs BEFORE both the entity write
  and any build.yaml write, per AC-1.
- Builder-key → package rule (build_runner semantics): a key containing
  `:` or `|` (`zorphy:zorphy`) names `package:builder`; a bare key
  (`json_serializable`) names the package itself. Parse via the `yaml`
  package (direct dep) with a regex fallback for non-YAML-parseable
  content — never a crash: unparseable content yields an empty set
  (fail-open, the #276 pre-flight guard still catches unregistered
  builders).
- The build_runner signal (issue #1322): build_runner prints
  `Ignoring options for unknown builder "zorphy:zorphy"` for a
  registered builder whose package is not loaded. The signal is
  CORROBORATING evidence — the primary diagnosis is the static
  package_config check, because the same warning also fires for a
  builder-NAME typo inside a resolvable package (that class keeps the
  generic remedy).
- `zfa build` already CAPTURES build_runner output (`_runBuild` →
  `_BuildOutput.output`, issue #1303 machinery) — the safety net needs
  no invocation change, only a pass-through of the captured text.
- Call chain (phase-0, unchanged):
  `RunDriverCore._runEntityPhaseZero` → spawns `zfa entity create -n …`
  per declared entity → spawns `zfa build --no-analyze` → on non-zero
  exit returns the `_Stop` record (`result: 'runner-error'` today).
- Call chain (make, unchanged): `PipelineRunner.runPlan` executes the
  plan steps (terminal `build` step spawns `zfa build`) →
  `firstFailureIndex` → the failure branch grades
  `MakeOutcome.generationError` today.
- Label vocabulary: `verdictForDriverResult` maps unknown result
  strings to verdict `error` — a new driver result label
  `missing-builder-dependency` needs no vocabulary change (receipts/
  envelopes keep green|red|error). `MakeOutcome` has direct precedent
  for additive values (`preflightRed`, issue #1303) and NO exhaustive
  switch outside `make_command.dart`.
- Hermeticity convention: the doctor/make auto-add
  (`PubspecProcessRunner` typedef, `lib/src/core/dependencies/
  pubspec_auto_add.dart`) is the repo's established injectable-spawner
  seam; the preflight reuses the typedef (no modification to the #1265
  module — a separate `--dev`-aware spawner lives in the new preflight
  file, because `PubspecAutoAdd.add` only adds REGULAR deps and AC-1
  prescribes `pub add --dev`).
- Existing tests that pin today's behavior (must stay green,
  unmodified): `test/commands/build_command_unit_test.dart`
  (`verifyOutputsOrFail` glob-remedy assertions — their sandboxes have
  NO package_config.json → unverifiable state → old message),
  `test/commands/build_yaml_guard_test.dart`,
  `test/plugins/tdd/run_command_test.dart` (bug-829 phase-0 group),
  `test/commands/entity_*_test.dart`.

## Approach

One new shared classifier + four thin call sites:

1. **NEW `lib/src/core/dependencies/builder_dependency_preflight.dart`**
   — `RegisteredBuilder` (package + key), `BuilderPreflightResult`
   (missing / added / failed / dryRun / commandLine), and
   `BuilderDependencyPreflight`:
   - `registeredBuilders(String contents)` — YAML-parse (regex
     fallback) of every target's `builders:` map → keys → packages.
   - `tryResolvablePackages(String projectRoot)` — package_config.json
     names, or `null` when the file is absent (unverifiable).
   - `unknownBuildersFromOutput(String buildOutput)` — extracts
     `Ignoring options for unknown builder <key>` keys.
   - `missingBuilderPackages({projectRoot, buildOutput})` — the ONE
     classifier every call site shares: static effective-set check +
     output-signal corroboration, empty when unverifiable.
   - `missingBuilderDependencyLines({missing, buildOutput})` — the
     safety-net message lines: names package(s), quotes the signal,
     prescribes `dart pub add --dev <pkg>`.
   - `ensureBuilderDependencies({projectRoot, dryRun, runner})` — the
     AC-1 auto-add: missing packages → one `dart|flutter pub add --dev
     <pkgs>` spawn (isFlutter detected from the pubspec `sdk: flutter`
     dependency, the DependencyWirer convention); injectable spawner;
     dry-run reports without spawning; failures → `failed` + the
     blocking prescription lines.
2. **`entity_command.dart` (AC-1)** — optional constructor seam
   `EntityCommand({PubspecProcessRunner? pubRunner})` (CLI dispatch
   unchanged — optional param); `_handleCreate` runs the preflight
   AFTER the annotation/type validation and BEFORE the convergent
   check / `EntityCreator.create` (i.e. before ANY file write): added →
   success lines; failed → blocking prescription + `_bail(failure)`;
   dry-run → would-add lines.
3. **`build_command.dart` (AC-2)** — `verifyOutputsOrFail` grows an
   OPTIONAL `String buildOutput = ''` param (back-compatible); the two
   `run()` call sites pass the already-captured `build.output` /
   `retry.output`; the zero-outputs branch consults the classifier
   FIRST — missing-builder message when it fires, the current glob
   message otherwise (byte-identical).
4. **`run_driver_core.dart` (AC-3 phase-0)** — in
   `_runEntityPhaseZero`'s build-failure path, classify the captured
   stdout+stderr through `missingBuildersForFailedBuild` (the
   evidence-requiring failed-build classifier: the output must carry the
   build_runner unknown-builder signal or the #276 safety-net marker,
   AND the static check must name missing packages — the U-991b class of
   generic build failures keeps `runner-error` verbatim); when the class
   fires return `result: 'missing-builder-dependency'`,
   `stoppedAt: 'phase-0:build'`, exit `_exitRunnerError`, message naming
   the package + exact fix. Every other path (entity spawn failures,
   timeouts, other build failures) keeps `runner-error` verbatim.
5. **`generation_plan.dart` + `make_command.dart` (AC-3 make)** —
   additive `MakeOutcome.missingBuilderDependency('missing-builder-
   dependency')`; a `@visibleForTesting` static
   `missingBuildersForBuildStep` (build step + non-zero exit + the same
   evidence-requiring classifier); in the generation-step-failure branch
   a classified failure prints the naming lines, keeps the
   subject-restore contract, summaries `outcome=missing-builder-
   dependency`, exits 1, no green entry. All other branches untouched.

## Risks / mitigations

- **False-positive diagnosis on unresolved projects** — mitigated by
  the unverifiable-state rule (`tryResolvablePackages` returns null →
  classifier empty); pinned by SC-5 and the existing
  `build_command_unit_test` sandboxes (no package_config.json).
- **Typo'd builder key in a resolvable package** — the output-only
  signal never fires the diagnosis alone; the static check must agree
  (pinned by a unit test).
- **Label vocabulary drift** — `missing-builder-dependency` flows
  through `verdictForDriverResult` → `error` and the make summary line;
  no consumer switches on the new string; the deferral check only
  matches `unexpressible`/`no-op` (verified in run_driver_core.dart).
- **Scope creep into shared modules** — `pubspec_auto_add.dart` is
  imported (typedef only), never modified; `DependencyWirer` read-only.
