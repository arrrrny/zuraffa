# Cycle Log: Feature-Flag System — enable/disable zuraffa features per build

Append only. Newest last. Every entry's `red` block is the evidence that the
test existed and failed before the implementation.

## Baseline

- suite: `tools/run_tests_chunked.sh` on `030-feature-flag-system` at branch point `11de4bfc` (pre-feature work)
  -> 1301 passed, 0 failed across 33 chunks (chunk-by-chunk last lines all "All tests passed!").
  Pre-existing runner quirk (NOT caused by this feature, flagged per protocol):
  chunks `test/benchmark`, `test/core/dependencies`, `test/integration` exit
  non-zero with "No tests match the requested tag selectors" because every test
  file in them is tagged `slow`/`benchmark`/`integration`, which the runner
  excludes — zero actual test failures. Reproduced manually: `dart test
  test/benchmark --exclude-tags flutter` -> "No tests ran." (exit 1).
- analyze: `dart analyze` -> "No issues found!"
- commit: `11de4bfc` (branch point, master)
- recorded: cycle 0, before any change

## Cycle 1: T002/T004/T007/T009/T011/T013/T015 — all test files written, observed RED

- test files (new): `test/feature_flags/feature_flag_config_test.dart`,
  `feature_flag_cli_test.dart`, `registry_emitter_test.dart`,
  `runtime_provider_test.dart`, `make_skip_test.dart`,
  `route_filter_test.dart`, `build_flavor_filter_test.dart`
- red: `dart test test/feature_flags/` ->
  - `feature_flag_cli_test.dart`: "Actual: '❌ Error: Cannot run `zfa make`
    for \"list\": no entity source file was found...'" — `zfa feature list`
    falls into the scaffold dispatch (the gap this feature closes)
  - `registry_emitter_test.dart` / `runtime_provider_test.dart` /
    `feature_flag_config_test.dart`: "Error: Error when reading
    'lib/src/feature_flags/feature_flag.dart': No such file or directory",
    "Method not found: 'emitRegistry'", "Type 'ResolvedFeatureSet' not found"
    — the module does not exist yet (canonical red for a new module)
- green: implementation cycles 2-8 below
- commit: pending (single feature commit per repo convention)

## Cycle 2: T003 — config/parse models implemented, config+gate tests GREEN

- test: `test/feature_flags/feature_flag_config_test.dart` (14 tests)
- red: cycle 1 (module absent)
- green: `lib/src/feature_flags/feature_flag.dart` (models, gate parser,
  name validation, `pascalToKebab`) + `feature_flag_config.dart`
  (list/map shapes, flavors, strict validation naming offenders,
  resolve()). `dart test test/feature_flags/feature_flag_config_test.dart`
  -> all passed
- refactor: none needed
- commit: pending

## Cycle 3: T005 — CLI service + FeatureCommand intercept, CLI tests GREEN

- test: `test/feature_flags/feature_flag_cli_test.dart` (7 tests)
- red: cycle 1 (`zfa feature list` fell into scaffold dispatch)
- green: `lib/src/feature_flags/feature_flag_cli.dart` +
  `_runFlagManagement` interception in
  `lib/src/commands/feature_command.dart`. All passed.
- deviation (recorded honestly): in-process assertions on the dart:io
  `exitCode` global RACE across concurrently-running test isolates
  (exitCode is process-global). Tests were converted to the repo's
  race-free subprocess pattern (`runZfaSource` + explicit
  workingDirectory); real exit codes are asserted in the subprocess e2e.
  Second deviation: `runCapturing` captures zone `print()`, not
  `stdout.writeln` — FeatureFlagCli switched to `print()`.
- commit: pending

## Cycle 4: T008 — registry emitter implemented, emitter tests GREEN

- test: `test/feature_flags/registry_emitter_test.dart` (8 tests)
- red: cycle 1 (emitRegistry/ResolvedFeatureSet absent)
- green: `lib/src/feature_flags/registry_emitter.dart` — pure
  config→source emitter delegating to FeatureFlagRuntime; disabled
  features absent; variant gate spec embedded. All passed.
- refactor: replaced placeholder-spread emission with direct const
  literal; A11 expectation updated to the sorted (stable) order.
- commit: pending

## Cycle 5: T010/T012 — make skip hook + route filter, GREEN

- test: `test/feature_flags/make_skip_test.dart` (3, subprocess),
  `test/feature_flags/route_filter_test.dart` (3)
- red: cycle 1 (no skip, no filter)
- green: `_disabledFeatureSkipReason` hook in
  `lib/src/commands/make_command.dart` (skips BEFORE planning and the
  entity-exists guard); `RouteBuildStage.featureSet` filter dropping
  @Route hits owned by disabled features (class-name Pascal-boundary or
  file-path segment match). All passed.
- commit: pending

## Cycle 6: T014 — build --flavor e2e, GREEN

- test: `test/feature_flags/build_flavor_filter_test.dart` (3, subprocess
  e2e with the precompiled AOT CLI)
- red: cycle 1 (no --flavor option)
- green: `--flavor <name>` in `lib/src/commands/build_command.dart`:
  strict validation (unknown flavor / invalid config exits non-zero
  naming the offender), feature-set plumbed into the route stage, and
  `lib/src/core/feature_flags.g.dart` emitted when features are declared
  (US2.AC4: no features section -> no registry, router unchanged). All
  passed.
- deviation: A7 initially resolved `--flavor pro` against a config with
  no `pro` flavor declared — test fixture corrected (explicit empty
  `pro` flavor), not the implementation.
- commit: pending

## Cycle 7: T016 — runtime gates + pluggable provider, GREEN

- test: `test/feature_flags/runtime_provider_test.dart` (17 tests)
- red: cycle 1 (runtime module absent)
- green: `lib/src/feature_flags/runtime/feature_flag_provider.dart` —
  FeatureFlagRuntime with provider short-circuit (answer wins; throw/null
  falls back to static default), ALL-gates-must-pass evaluation, closed
  gate on unavailable/throwing resolvers, variant resolution. All passed.
- refactor: variant gate uses the resolver's RAW pick (an undeclared pick
  fails the gate instead of being silently coerced to variant a).
- commit: pending

## Final verification runs

- `dart test test/feature_flags/` -> 62 passed, 0 failed (three
  consecutive runs, default concurrency)
- `dart analyze` -> "No issues found!"
- `dart format .` -> "Formatted 1361 files (0 changed)"
- `tools/run_tests_chunked.sh` -> 1369 passed, 0 failed; the ONLY
  non-green chunk exits are the 3 pre-existing tag-quirk chunks
  (`test/benchmark`, `test/core/dependencies`, `test/integration` — all
  their files are slow/benchmark/integration-tagged, so the runner's
  exclusion empties them: "No tests ran." exit 1). Identical to the
  pre-feature baseline; zero actual test failures; flagged per protocol.
