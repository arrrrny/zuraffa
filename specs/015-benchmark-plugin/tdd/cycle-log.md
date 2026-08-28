# Cycle Log: Internal Benchmark Plugin for Zuraffa (015-benchmark-plugin)

Append only. Newest last. Every entry's `red` block is the evidence that the
test existed and failed before the implementation.

**Loop discipline note (recorded honestly):** this feature ran the loop
grouped by component rather than one-behavior-per-commit: for each component,
the complete test file was written first, observed failing (compile error —
the source file did not exist), then implemented to green, then committed.
Red evidence below quotes the decisive compiler/test output of each
observation. The acceptance/SC scenarios (cycles 11–12) were written after
the units (inside-out), so they verified composition of already-green units
plus genuinely new measurable behaviors; where an acceptance test failed on
first run, the failure and fix are recorded.

## Baseline

- suite: `dart analyze lib test bin` -> 0 errors / 3 warnings / 81 infos
  (pre-existing); full `dart test` (background, `/tmp/baseline_test.log`)
  -> 1803+ passed with pre-existing subprocess-timeout failures in
  test/commands (initialize_dart_inplace, make_command, build_command —
  TimeoutException after 2:00 each; environment slowness, unrelated to this
  feature; they spawn zfa subprocesses)
- commit: `ab0d02fe` (master HEAD before this branch)
- recorded: cycle 0, before any change

## Cycle 1: U8–U12 — BenchmarkResult value types (FR-004, FR-008)

- test: `test/plugins/benchmark/benchmark_result_test.dart` (new, 6 tests)
- red: `dart test test/plugins/benchmark/benchmark_result_test.dart`
  -> `Error: Undefined name 'BenchmarkStatus'` (1 failed: loading) — source
  file `lib/src/core/benchmark/benchmark_result.dart` did not exist
- green: `lib/src/core/benchmark/benchmark_result.dart` added with
  `BenchmarkResult`, `BenchmarkSuiteResult`, `ThresholdViolation`,
  `BenchmarkStatus`, `ThresholdSeverity`. Suite -> 6 passed
- refactor: none needed (value types)
- commit: `feat(benchmark): benchmark result value types with JSON round-trip`

## Cycle 2: U1–U7 — BenchmarkContract + ThresholdConfig (FR-001, FR-005, FR-015)

- test: `test/plugins/benchmark/benchmark_contract_test.dart` (new, 10 tests)
- red: `dart test test/plugins/benchmark/benchmark_contract_test.dart`
  -> `Error: Error when reading 'lib/src/core/benchmark/benchmark_contract.dart':
  No such file or directory` (1 failed: loading)
- green: `benchmark_contract.dart` added. Fix iterations during green:
  (a) `export` directive moved before declarations (directive_after_declaration);
  (b) switch-expression cases qualified with the enum name; (c) `BenchmarkScenario`
  changed from `implements` to `extends BenchmarkContract` so defaults are
  inherited; (d) const super constructor added. Suite -> 16 passed
- correction before green: test asserted `expectation` in word form
  (`memory_mb lte 512`); data-model.md documents the symbol form
  (`latency_p99 <= 100`) — test corrected to `'memory_mb <= 512'` (aligning
  the assertion to the documented design, not weakening it)
- refactor: none
- commit: `feat(benchmark): benchmark contract interface + threshold config`

## Cycle 3: U13–U20 — BenchmarkRegistry (FR-002, FR-003, AC-3, AC-4)

- test: `test/plugins/benchmark/benchmark_registry_test.dart` (new, 11 tests)
- red: `dart test ...benchmark_registry_test.dart`
  -> `Error: Error when reading 'lib/src/core/benchmark/benchmark_registry.dart':
  No such file or directory` (1 failed: loading)
- green: `benchmark_registry.dart` added (registry interface,
  InMemoryBenchmarkRegistry, Result-based error codes). Two test-fixture
  corrections during green: `containsKey` matcher -> `containsPair` (matcher
  API), fixture name derivation simplified to an injected name. Suite -> 27
- refactor: none
- commit: `feat(benchmark): scenario registry with validation + conflict handling`

## Cycle 4: U21–U24 — StandardMetrics math (FR-004)

- test: `test/plugins/benchmark/standard_metrics_test.dart` (new, 8 tests)
- red: `dart test ...standard_metrics_test.dart`
  -> `Error: Error when reading 'lib/src/core/benchmark/standard_metrics.dart':
  No such file or directory` (1 failed: loading)
- green: `standard_metrics.dart` added (six names, linear-interpolation
  percentiles, throughput, lower-is-better directions). Suite -> 35
- commit: `feat(benchmark): standard metric names + percentile/throughput math`

## Cycle 5+6: U25–U43 — DefaultBenchmarkRunner + MetricCollector (FR-004/005/006/008/012/013)

Written as one batch because the runner's lifecycle and the collector
interface are coupled (the runner drives the collector hooks): both test
files were written before either source file existed.

- test: `benchmark_runner_test.dart` (14 tests) + `metric_collector_test.dart`
  (5 tests) + shared helpers (`helpers/fake_scenarios.dart`,
  `helpers/fake_collectors.dart`)
- red: `dart test test/plugins/benchmark/benchmark_runner_test.dart`
  -> `Error: Error when reading 'lib/src/core/benchmark/benchmark_runner.dart':
  No such file or directory` AND `...metric_collector.dart: No such file or
  directory` (both failed: loading)
- green: `benchmark_runner.dart` + `metric_collector.dart` implemented.
  Genuine failures surfaced and fixed during green:
  1. `MetricContext.result` was never populated at collect time -> now the
     scenario's partial result is passed (test 'context carries scenario
     data' caught it)
  2. `collectMetrics` ran even after a failed `run` -> now skipped (test
     'run error captured, teardown called' caught it)
  3. dry-run message lacked the schema keyword -> message now contains
     'minimum' (test 'dry run rejects bad config' caught it)
  4. config-parameter shadowing broke `config.timeout` -> `this.config`
  5. throwing-collector warnings were logged to stderr only -> now also
     recorded in result.metadata['warnings'] (AC-9 evidence)
- refactor: `_guardCollector` simplified; beforeBenchmark hook inlined with
  its own guard; unused imports removed. Suite -> 57
- commit: `feat(benchmark): runner + metric collectors (015 cycles 5-6)`

## Cycle 7: U44–U46 — IsolateBenchmarkRunner (FR-007)

- test: `test/plugins/benchmark/isolate_benchmark_runner_test.dart` (new, 4 tests)
- red: `Error: Error when reading 'lib/src/core/benchmark/isolate_benchmark_runner.dart':
  No such file or directory` (1 failed: loading)
- green: isolate runner implemented (spawn per scenario, error marshalling,
  isolated:true metadata, contained crashes). Fixed: `dryRun` parameter
  shadowing (`config` -> `this.config`). Suite -> 61
- refactor: removed dead Completer-based cleanup; isolate.kill after reply
- commit: `feat(benchmark): isolate-based benchmark execution`

## Cycle 8: U47–U56 — BaselineStore + comparison (FR-009, FR-010, AC-10, AC-11)

- test: `test/plugins/benchmark/baseline_store_test.dart` (new, 12 tests)
- red: `Error: Error when reading 'lib/src/core/benchmark/baseline_store.dart':
  No such file or directory` (1 failed: loading)
- green: `baseline_store.dart` implemented (Baseline, JsonBaselineStore,
  compareBaselines with tolerance/direction/severity). Fixed: local variable
  shadowed the `list()` method. Suite -> 73
- commit: `feat(benchmark): baseline store + regression comparison`

## Cycle 9: U57–U60 — BenchmarkPlugin + capabilities (FR-002/003/011/014)

- test: `test/plugins/benchmark/benchmark_plugin_test.dart` (new, 5 tests)
- red: `Error: Error when reading 'lib/src/plugins/benchmark/benchmark_plugin.dart':
  No such file or directory` (1 failed: loading)
- green: plugin + three capabilities + BenchmarkScenarioProvider + CLI stub.
  Design correction surfaced by test: ExecutionResult.success now reflects
  capability invocation success, NOT the benchmark verdict (the verdict
  lives in the suite payload; the CLI maps it to exit codes). Fixed import
  depth (capabilities are 3 levels deep) and non-const Effect lists.
  Suite -> 78
- refactor: lint-clean pass (unused imports, @override on non-overriding
  field, doc-comment brackets)
- commit: `feat(benchmark): benchmark plugin + capabilities + provider discovery`

## Cycle 10: U61–U67 — `zfa benchmark` CLI (FR-011, FR-012)

- test: `test/plugins/benchmark/benchmark_command_test.dart` (new, 7 tests)
- red: `Error: The getter 'exitCode' isn't defined for the type
  'BenchmarkCommand'` + missing subcommands (1 failed: loading)
- green: full BenchmarkCommand (run/list/baseline save/load/compare/list/
  report, --dry-run/--scenario/--config/--json/--concurrency/--store,
  exit-code contract). Suite -> 85
- refactor: string-interpolation lint pass
- commit: `feat(benchmark): zfa benchmark CLI with run/list/baseline/report`

## Cycle 11: A1–A11 — acceptance scenarios through real entry points

- test: `test/plugins/benchmark/scenarios/ac_001…ac_011_*.dart` (11 tests)
- red: units were already green (inside-out loop), so these verified
  composition. Compile errors found and fixed in the tests themselves
  (implements-requires-all-members on the pure-interface scenarios — which
  itself demonstrates the FR-015 interface surface)
- green: 11/11 — AC-1…AC-11 PROVED through DefaultBenchmarkRunner /
  InMemoryBenchmarkRegistry / compareBaselines / BenchmarkPlugin
- commit: `test(benchmark): acceptance + success-criteria scenarios`

## Cycle 12: A12–A18 — success criteria SC-001…SC-007

- test: `scenarios/sc_001…sc_007_*.dart` (7 tests) + fixture
  `scenarios/fixtures/line_count_scenario.dart`
- red: sc_003 (framework overhead < 5%) FAILED on first run:
  `Expected: a value less than <0.05> Actual: <0.0539>` (raw=16ms,
  framed=17ms — workload too small for timer resolution). Fixed by scaling
  the workload (3M harmonic-sum iterations, raw ~100ms) and switching both
  sides to min-of-five (least-noise microbenchmark practice). No assertion
  was weakened: the 5% bound is unchanged.
- green: all 7 SC tests pass, stable across 3 consecutive full-scope runs
  (+103 each)
- commit: `test(benchmark): acceptance + success-criteria scenarios`
  + `test(benchmark): stabilize overhead measurement with min-of-five`

## Implement-phase wiring (non-behavioral)

- lib/zuraffa.dart exports the contract library (FR-015 dependency floor)
- PluginLoader registers BenchmarkPlugin -> `zfa benchmark` live end-to-end
  (`dart run bin/zfa.dart benchmark` prints usage; `zfa plugin list` shows
  `[✓] benchmark - Benchmark (1.0.0)`; test/cli/ 123 tests still green)
- commit: `feat(benchmark): export contract library + register plugin in CLI`

## Notes and deviations

- Cycles were committed per component (batched behaviors), not per behavior;
  test-first evidence is per test file: every source file was nonexistent at
  its test's red observation. verification.md grades this as a process gap.
- The full-repo `dart test` baseline run recorded pre-existing failures in
  subprocess-spawning tests (TimeoutException, environment slowness) —
  unchanged by this feature; see Baseline entry.
- Disk pressure from the parallel baseline run (stale dart kernel temp dirs)
  caused one baseline-run abort; cleaned and re-run. Feature-scoped runs were
  never affected.
