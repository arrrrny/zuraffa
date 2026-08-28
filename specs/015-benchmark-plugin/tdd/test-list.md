---
feature: 015-benchmark-plugin
loop: inside-out
profile: .specify/memory/tdd-profile.md
spec_criteria: 18
planned_at: master
updated_at: feat/015-benchmark-plugin
suite_baseline: green
---

# Test List: Internal Benchmark Plugin for Zuraffa (015-benchmark-plugin)

The behaviors the feature must exhibit, traced to the criterion each one serves.
The companion `cycle-log.md` is the append-only evidence that each behavior went
red→green→refactor; this file is the plan.

Outer loop = 11 acceptance criteria (AC-1…AC-11, the spec's Given/When/Then
acceptance scenarios) + 7 measurable success criteria (SC-001…SC-007). Inner
loop = unit behaviors grouped by the owning component from `plan.md`.

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`. Each stays red until the feature
works end to end through its real entry point (the runner / registry API, or
the `zfa benchmark` CLI).

| id  | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| A1  | A plugin developer implements `BenchmarkContract`, runs it through the runner, and receives a structured `BenchmarkResult` with metrics | AC-1, FR-001, FR-004 | example | DONE | `test/plugins/benchmark/scenarios/ac_001_contract_run_test.dart::contract run returns structured result` |
| A2  | An invalid benchmark scenario (bad id/version/threshold) is rejected with a clear validation error and is never executed | AC-2, FR-001 | example | DONE | `test/plugins/benchmark/scenarios/ac_002_invalid_scenario_test.dart::invalid scenario rejected without execution` |
| A3  | Querying the registry after 3+ plugins register scenarios returns all of them with names, descriptions and config schemas | AC-3, FR-002, FR-003 | example | DONE | `test/plugins/benchmark/scenarios/ac_003_registry_discovery_test.dart::registry returns all scenarios with metadata` |
| A4  | Registering a duplicate scenario id returns a conflict error and leaves the original registration intact | AC-4, FR-002 | example | DONE | `test/plugins/benchmark/scenarios/ac_004_duplicate_conflict_test.dart::duplicate id conflicts` |
| A5  | A runner-executed scenario produces latency p50/p95/p99, throughput, memory and CPU metrics | AC-5, FR-004 | example | DONE | `test/plugins/benchmark/scenarios/ac_005_standard_metrics_test.dart::standard metrics produced` |
| A6  | A benchmark exceeding a configured threshold is marked failed with the specific violating metric named in the result | AC-6, FR-005 | example | DONE | `test/plugins/benchmark/scenarios/ac_006_threshold_failure_test.dart::threshold violation fails run` |
| A7  | Running multiple benchmarks in sequence produces an aggregate report with per-benchmark results and overall pass/fail status | AC-7, FR-008 | example | DONE | `test/plugins/benchmark/scenarios/ac_007_aggregate_report_test.dart::aggregate report has per-benchmark and overall status` |
| A8  | A registered custom metric collector's data appears in the final benchmark result, collected at the right lifecycle points | AC-8, FR-006 | example | DONE | `test/plugins/benchmark/scenarios/ac_008_custom_collector_test.dart::custom collector metrics appear in result` |
| A9  | A metric collector that throws is logged and does not fail the benchmark or the suite | AC-9, FR-006 | example | DONE | `test/plugins/benchmark/scenarios/ac_009_collector_error_test.dart::throwing collector is isolated` |
| A10 | Comparing a result set against a baseline yields per-metric percentage changes with regression/improvement flags | AC-10, FR-009, FR-010 | example | DONE | `test/plugins/benchmark/scenarios/ac_010_baseline_compare_test.dart::comparison reports percent changes` |
| A11 | A metric regressed beyond the configured tolerance is flagged with severity | AC-11, FR-010 | example | DONE | `test/plugins/benchmark/scenarios/ac_011_tolerance_severity_test.dart::regression beyond tolerance flagged with severity` |
| A12 | A new plugin implements a benchmark scenario in under 50 lines of code (SC-001, mechanically counted) | SC-001, FR-001, FR-015 | example | DONE | `test/plugins/benchmark/scenarios/sc_001_scenario_test.dart::scenario under 50 lines` |
| A13 | The runner executes 100+ concurrent scenarios without resource contention failures (SC-002) | SC-002, FR-004, FR-007 | example | DONE | `test/plugins/benchmark/scenarios/sc_002_concurrency_test.dart::100+ scenarios complete` |
| A14 | Framework overhead on a measured operation stays under 5% (SC-003) | SC-003 | example | DONE | `test/plugins/benchmark/scenarios/sc_003_overhead_test.dart::overhead under 5 percent` |
| A15 | A 20-scenario suite completes in under 5 minutes (SC-004, CI shape) | SC-004, FR-008 | example | DONE | `test/plugins/benchmark/scenarios/sc_004_ci_suite_test.dart::20-scenario suite under 5 min` |
| A16 | Synthetic regression detection has false-positive rate < 5% and false-negative rate < 1% (SC-005) | SC-005, FR-010 | example | DONE | `test/plugins/benchmark/scenarios/sc_005_regression_accuracy_test.dart::accuracy within bounds` |
| A17 | A custom metric collector adds < 1ms per collection point (SC-006) | SC-006, FR-006 | example | DONE | `test/plugins/benchmark/scenarios/sc_006_collector_overhead_test.dart::collector overhead under 1ms` |
| A18 | Benchmarks from 3+ different plugins run in the same suite without conflicts (SC-007) | SC-007, FR-014, FR-015 | example | DONE | `test/plugins/benchmark/scenarios/sc_007_cross_plugin_test.dart::3+ plugins coexist in one suite` |

## Inner loop: unit behaviors

Grouped by the component from `plan.md` that owns them. Each line names one
observable result.

### `lib/src/core/benchmark/benchmark_contract.dart`

| id  | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U1  | `ThresholdConfig` rejects an operator outside lt/lte/gt/gte with a validation error | AC-2, FR-005 | example | DONE | `benchmark_contract_test.dart::rejects invalid operator` |
| U2  | `ThresholdConfig` rejects a severity outside error/warn with a validation error | AC-2, FR-005 | example | DONE | `benchmark_contract_test.dart::rejects invalid severity` |
| U3  | `ThresholdConfig.evaluate` returns not-violated for `lte` when actual == value (boundary) | FR-005 | example | DONE | `benchmark_contract_test.dart::lte boundary not violated` |
| U4  | `ThresholdConfig.evaluate` returns violated for `lt` when actual == value (boundary) | FR-005 | example | DONE | `benchmark_contract_test.dart::lt boundary violated` |
| U5  | `BenchmarkScenario` base validates a non-empty kebab-case id and rejects others | AC-2 | example | DONE | `benchmark_contract_test.dart::validates scenario id` |
| U6  | `BenchmarkScenario` base rejects an invalid semver version | AC-2 | example | DONE | `benchmark_contract_test.dart::rejects invalid version` |
| U7  | `BenchmarkScenario` base exposes description/configSchema/thresholds/tags metadata defaults | FR-002 | example | DONE | `benchmark_contract_test.dart::metadata defaults` |

### `lib/src/core/benchmark/benchmark_result.dart`

| id  | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U8  | `BenchmarkResult` JSON round-trips every field (metrics, violations, duration, timestamp, metadata) | FR-004, FR-008 | example | DONE | `benchmark_result_test.dart::json round trip` |
| U9  | `BenchmarkResult` rejects a status outside passed/failed/error/skipped | FR-004 | example | DONE | `benchmark_result_test.dart::rejects invalid status` |
| U10 | `BenchmarkSuiteResult.overallStatus` is failed when any member result failed | FR-008 | example | DONE | `benchmark_result_test.dart::overall failed when any failed` |
| U11 | `BenchmarkSuiteResult.summary` counts passed/failed/error/skipped results | FR-008 | example | DONE | `benchmark_result_test.dart::summary counts statuses` |
| U12 | `ThresholdViolation` JSON round-trips metric/expected/actual/severity/message | FR-005 | example | DONE | `benchmark_result_test.dart::violation round trip` |

### `lib/src/core/benchmark/benchmark_registry.dart`

| id  | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U13 | `register` stores a scenario retrievable via `get(id)` with its metadata | AC-3, FR-002 | example | DONE | `benchmark_registry_test.dart::register then get` |
| U14 | `register` a duplicate id returns a conflict failure and keeps the original | AC-4, FR-002 | example | DONE | `benchmark_registry_test.dart::duplicate conflicts` |
| U15 | `unregister` removes the scenario; `get` returns null afterwards | FR-002 | example | DONE | `benchmark_registry_test.dart::unregister removes` |
| U16 | `getAll` returns every registered scenario | AC-3 | example | DONE | `benchmark_registry_test.dart::get all` |
| U17 | `getByTags` returns only scenarios matching any requested tag | FR-002 | example | DONE | `benchmark_registry_test.dart::get by tags` |
| U18 | `has` reports presence and absence correctly | FR-002 | example | DONE | `benchmark_registry_test.dart::has reports presence` |
| U19 | `clear` empties the registry (test support) | FR-002 | example | DONE | `benchmark_registry_test.dart::clear empties` |
| U20 | A scenario registered after suite start is discoverable without restart (runtime registration) | FR-003 | example | DONE | `benchmark_registry_test.dart::runtime registration` |

### `lib/src/core/benchmark/standard_metrics.dart`

| id  | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U21 | Percentile computation returns the exact p50 of a known odd-length sample | FR-004 | example | DONE | `standard_metrics_test.dart::p50 known sample` |
| U22 | Percentile computation returns the interpolated p95/p99 of a known sample | FR-004 | example | DONE | `standard_metrics_test.dart::p95 p99 known sample` |
| U23 | `StandardMetrics` exposes the six standard metric names | FR-004, AC-5 | example | DONE | `standard_metrics_test.dart::six standard names` |
| U24 | Throughput is computed as operations per elapsed second | FR-004 | example | DONE | `standard_metrics_test.dart::throughput formula` |

### `lib/src/core/benchmark/benchmark_runner.dart`

| id  | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U25 | `runSingle` executes the lifecycle in order: setup → run → collectMetrics → teardown | AC-1, FR-001, FR-004 | example | DONE | `benchmark_runner_test.dart::lifecycle order` |
| U26 | `runSingle` merges global config under scenario config | FR-004 | example | DONE | `benchmark_runner_test.dart::config merge` |
| U27 | A throwing `setup` produces status=error and skips both `run` and `teardown` (data-model contract) | FR-013, FR-001 | example | DONE | `benchmark_runner_test.dart::setup error skips run and teardown` |
| U28 | A throwing `run` produces status=error and still calls `teardown` | FR-013 | example | DONE | `benchmark_runner_test.dart::run error captured teardown called` |
| U29 | A metric exceeding an error-severity threshold yields status=failed with the metric named in `thresholdViolations` | AC-6, FR-005 | example | DONE | `benchmark_runner_test.dart::error threshold fails` |
| U30 | A warn-severity threshold violation is recorded but status stays passed | FR-005 | example | DONE | `benchmark_runner_test.dart::warn violation stays passed` |
| U31 | A scenario exceeding its timeout yields a failed result with a timeout violation and the suite continues | FR-013 | example | DONE | `benchmark_runner_test.dart::timeout fails gracefully` |
| U32 | `run` executes all scenarios in order and returns per-benchmark results | AC-7, FR-008 | example | DONE | `benchmark_runner_test.dart::run executes all` |
| U33 | `run` continues after a scenario errors and includes its error result | FR-013, AC-7 | example | DONE | `benchmark_runner_test.dart::continues after error` |
| U34 | `dryRun` validates config against the scenario's schema without invoking setup/run/teardown | FR-012 | example | DONE | `benchmark_runner_test.dart::dry run validates only` |
| U35 | `dryRun` rejects config violating required/typed schema properties with a clear message | FR-012, AC-2 | example | DONE | `benchmark_runner_test.dart::dry run rejects bad config` |
| U36 | `run` invokes collector lifecycle hooks: initialize once, before/after per benchmark, finalize once | AC-8, FR-006 | example | DONE | `benchmark_runner_test.dart::collector lifecycle hooks` |
| U37 | `runSingle` stamps metadata with the scenario config used | FR-004 | example | DONE | `benchmark_runner_test.dart::metadata records config` |
| U38 | `run` supports concurrent execution of scenarios (worker pool) producing identical per-scenario results | SC-002, FR-007 | example | DONE | `benchmark_runner_test.dart::concurrent run` |

### `lib/src/core/benchmark/metric_collector.dart`

| id  | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U39 | `StandardMetricCollector` produces latency_p50/p95/p99 from the scenario's measured samples | AC-5, FR-004 | example | DONE | `metric_collector_test.dart::latency percentiles produced` |
| U40 | `StandardMetricCollector` produces throughput_ops_sec | AC-5, FR-004 | example | DONE | `metric_collector_test.dart::throughput produced` |
| U41 | `StandardMetricCollector` produces memory_mb and cpu_percent (non-negative) | AC-5, FR-004 | example | DONE | `metric_collector_test.dart::memory and cpu produced` |
| U42 | A throwing collector is logged, its metrics skipped, and the benchmark still passes | AC-9, FR-006 | example | DONE | `metric_collector_test.dart::throwing collector isolated` |
| U43 | `MetricContext` carries scenarioId/name/config and the result after the benchmark | FR-006 | example | DONE | `metric_collector_test.dart::context carries scenario data` |

### `lib/src/core/benchmark/isolate_benchmark_runner.dart`

| id  | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U44 | A scenario executed through the isolate runner returns its result to the caller | FR-007 | example | DONE | `isolate_benchmark_runner_test.dart::result returns from isolate` |
| U45 | A scenario that throws inside the isolate yields an error result, and the host keeps running | FR-007, FR-013 | example | DONE | `isolate_benchmark_runner_test.dart::isolate crash contained` |
| U46 | Isolate execution records isolation metadata (isolate-executed flag) on the result | FR-007 | example | DONE | `isolate_benchmark_runner_test.dart::isolation metadata recorded` |

### `lib/src/core/benchmark/baseline_store.dart`

| id  | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U47 | `save` persists a baseline that `load` returns for the scenario id | FR-009 | example | DONE | `baseline_store_test.dart::save then load` |
| U48 | `load` returns the latest baseline when several exist | FR-009 | example | DONE | `baseline_store_test.dart::load latest` |
| U49 | `loadByLabel` returns the exact labeled baseline | FR-009 | example | DONE | `baseline_store_test.dart::load by label` |
| U50 | `list` returns all baselines of a scenario ordered by timestamp | FR-009 | example | DONE | `baseline_store_test.dart::list ordered` |
| U51 | `delete` removes the labeled baseline; later loads no longer see it | FR-009 | example | DONE | `baseline_store_test.dart::delete removes` |
| U52 | Baseline JSON round-trips metrics/timestamp/git/environment fields | FR-009 | example | DONE | `baseline_store_test.dart::json round trip` |
| U53 | `compare` reports per-metric percent change with direction flags | AC-10, FR-010 | example | DONE | `baseline_store_test.dart::compare percent changes` |
| U54 | `compare` marks a regression beyond tolerance as regressed with severity | AC-11, FR-010 | example | DONE | `baseline_store_test.dart::regression beyond tolerance` |
| U55 | `compare` marks a metric within tolerance as stable | FR-010 | example | DONE | `baseline_store_test.dart::within tolerance stable` |
| U56 | `compare` marks improvement direction for lower-is-better metrics | FR-010 | example | DONE | `baseline_store_test.dart::improvement direction` |

### `lib/src/plugins/benchmark/benchmark_plugin.dart`

| id  | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U57 | `BenchmarkPlugin` exposes id/name/version and three capabilities with input/output schemas | FR-011, FR-014 | example | DONE | `benchmark_plugin_test.dart::plugin surface` |
| U58 | `RegisterBenchmarkCapability` registers provider-supplied scenarios into the registry | FR-003, FR-014 | example | DONE | `benchmark_plugin_test.dart::provider registers scenarios` |
| U59 | `ListBenchmarksCapability` returns registered scenario metadata | FR-002, FR-011 | example | DONE | `benchmark_plugin_test.dart::list capability` |
| U60 | `RunBenchmarkCapability` executes scenarios and returns suite results | FR-004, FR-011 | example | DONE | `benchmark_plugin_test.dart::run capability` |

### `lib/src/plugins/benchmark/cli/benchmark_command.dart`

| id  | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U61 | `zfa benchmark list` prints every registered scenario with name/version/tags | FR-011 | example | DONE | `benchmark_command_test.dart::list prints scenarios` |
| U62 | `zfa benchmark run` executes scenarios, prints the aggregate report, exit code reflects overall status | FR-011, FR-008 | example | DONE | `benchmark_command_test.dart::run reports and exits` |
| U63 | `zfa benchmark run --scenario <id>` runs only that scenario | FR-011 | example | DONE | `benchmark_command_test.dart::scenario filter` |
| U64 | `zfa benchmark run --dry-run` validates configuration and executes nothing | FR-012 | example | DONE | `benchmark_command_test.dart::dry run validates only` |
| U65 | `zfa benchmark baseline save/load/compare` persists and compares baselines | FR-009, FR-011 | example | DONE | `benchmark_command_test.dart::baseline subcommands` |
| U66 | `zfa benchmark --json` emits machine-readable JSON output | FR-011 | example | DONE | `benchmark_command_test.dart::json output` |
| U67 | `zfa benchmark` with an unknown subcommand prints usage guidance | FR-011 | example | DONE | `benchmark_command_test.dart::unknown subcommand usage` |

## Invariants and edge cases still to place

- Scenario `collectMetrics` failures must not fail the benchmark (error-captured).
  → placed as U42's sibling: covered by A9 through the runner (collector errors isolated).
- Concurrent `run` invocations on the same registry must not double-register.
  → covered by U20 (runtime registration) + A13 (100+ concurrency).
- Plugin unload deregisters its benchmarks → `unregister` (U15) is the mechanism;
  automatic unload-hook wiring is out of scope (see below).

## Out of scope

- Process-level (OS process) isolation: FR-007 permits isolates; `Process.run`
  isolation is a documented future extension (research.md).
- Remote baseline storage (S3/MinIO): `BaselineStore` interface leaves the seam;
  only `JsonBaselineStore` ships (spec assumption: local filesystem default).
- HTML report rendering: `zfa benchmark report` ships console + JSON output only;
  HTML is a future format (quickstart.md documents the seam).
- Automatic scenario deregistration on plugin unload: manual `unregister` ships;
  no plugin-lifecycle unload hook exists in the current plugin system.
- AOT-specific GC-metric degradation: collectors degrade to zero-values when a
  metric is unavailable on the platform (edge case handled, not specialized).

## Verification commands

Copied verbatim from `.specify/memory/tdd-profile.md` at planning time:

- Single test: `dart test test/<path>.dart -P "<name>"`
- Full suite (feature scope): `dart test test/plugins/benchmark/`
- Static analysis (feature scope): `dart analyze lib/src/core/benchmark/ lib/src/plugins/benchmark/ test/plugins/benchmark/`
- Full suite (repo): `dart test`
