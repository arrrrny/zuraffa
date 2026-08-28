# Tasks: Internal Benchmark Plugin for Zuraffa (015-benchmark-plugin)

**Input**: Design documents from `/specs/015-benchmark-plugin/` — `spec.md`, `plan.md`, `research.md`, `data-model.md`, `quickstart.md`.

**Prerequisites**: `plan.md` (required), `spec.md` (required).

**Tests**: Required — mandatory. The TDD extension drives every behavioral task through the red-green-refactor loop; the test tasks below are the tasks the loop executes against (`tdd/test-list.md` is derived from this file by `/speckit.tdd.plan`).

**Organization**: MVP-first ordering per the SDD cycle instructions — contract interface + registry first, then runner + standard metrics + thresholds, then extensible collectors + isolation, then CLI `zfa benchmark`, then baseline store + regression detection + dry-run, then cross-plugin compatibility tests.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1…US5, matching spec.md; EDGE for edge cases)
- Exact file paths in descriptions

## Path Conventions

- Contract library: `lib/src/core/benchmark/`
- Plugin + CLI: `lib/src/plugins/benchmark/`
- Tests: `test/plugins/benchmark/` (mirrors source; acceptance scenarios in `test/plugins/benchmark/scenarios/`)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Environment + scaffolding done before any behavior.

- [x] T001 Verify token, clone repo, install Dart SDK (3.13.2, satisfies `^3.11.0`), `dart pub get` green (dependency_overrides already absent from pubspec.yaml)
- [x] T002 Install spec-kit + TDD extension (`specify init --here --integration zed --ignore-agent-tools`; `specify extension add tdd` → already installed, "✓ TDD Extension (v1.1.2)")
- [x] T003 Create branch `feat/015-benchmark-plugin` from master
- [x] T004 Record baseline: `dart analyze lib test bin` → 0 errors / 3 warnings / 81 infos (pre-existing); full `dart test` baseline running in background (recorded in cycle-log)

---

## Phase 2: MVP Core — Contract Interface + Registry (US1, US2)

**Purpose**: The decoupled contract surface every other story builds on (FR-001, FR-002, FR-003, FR-015).

- [ ] T005 [US1] RED→GREEN: `BenchmarkContract` interface + `ThresholdConfig` + scenario metadata validation — `lib/src/core/benchmark/benchmark_contract.dart`, test `test/plugins/benchmark/benchmark_contract_test.dart` (FR-001, AC-1, AC-2)
- [ ] T006 [US1] RED→GREEN: `BenchmarkResult` / `BenchmarkSuiteResult` / `ThresholdViolation` value types with JSON round-trip — `lib/src/core/benchmark/benchmark_result.dart`, test `test/plugins/benchmark/benchmark_result_test.dart` (FR-004, FR-008)
- [ ] T007 [US2] RED→GREEN: `BenchmarkRegistry` interface + `InMemoryBenchmarkRegistry` (register/unregister/getAll/getByTags/has/clear, duplicate-ID conflict, runtime registration) — `lib/src/core/benchmark/benchmark_registry.dart`, test `test/plugins/benchmark/benchmark_registry_test.dart` (FR-002, FR-003, AC-3, AC-4)
- [ ] T008 [US1] Export the contract library from `lib/zuraffa.dart` so third parties depend only on the contract (FR-014, FR-015)

---

## Phase 3: Runner + Standard Metrics + Thresholds (US3)

**Purpose**: Execution orchestration with standardized metrics and pass/fail gates (FR-004, FR-005, FR-008, FR-013).

- [ ] T009 [US3] RED→GREEN: `StandardMetrics` + percentile/throughput math — `lib/src/core/benchmark/standard_metrics.dart`, test `test/plugins/benchmark/standard_metrics_test.dart` (FR-004)
- [ ] T010 [US3] RED→GREEN: `DefaultBenchmarkRunner.runSingle` — lifecycle setup→run→collectMetrics→teardown, error capture as `status=error`, teardown-always-called, timeout → failed result — `lib/src/core/benchmark/benchmark_runner.dart`, test `test/plugins/benchmark/benchmark_runner_test.dart` (FR-004, FR-013, AC-5)
- [ ] T011 [US3] RED→GREEN: threshold evaluation — per-metric operators (lt/lte/gt/gte), severity error/warn, violations recorded in result, pass→fail transition — same runner test file (FR-005, AC-6)
- [ ] T012 [US3] RED→GREEN: `BenchmarkRunner.run` suite aggregation — per-benchmark results, overall status, summary map, one failing benchmark does not stop the suite — same runner test file (FR-008, FR-013, AC-7)
- [ ] T013 [US3] RED→GREEN: `dryRun` validation without execution — `BenchmarkRunner.dryRun`, runner test file (FR-012)

---

## Phase 4: Extensible Collectors + Isolation (US4, EDGE)

**Purpose**: Custom metrics and cross-contamination prevention (FR-006, FR-007).

- [ ] T014 [US4] RED→GREEN: `MetricCollector` interface + `MetricContext` + 4-phase lifecycle (initialize/beforeBenchmark/afterBenchmark/finalize) — `lib/src/core/benchmark/metric_collector.dart`, test `test/plugins/benchmark/metric_collector_test.dart` (FR-006, AC-8)
- [ ] T015 [US4] RED→GREEN: `StandardMetricCollector` built-in (latency p50/p95/p99, throughput, memory, CPU) — same collector test file (FR-004, AC-5)
- [ ] T016 [US4] RED→GREEN: collector error isolation — a throwing collector is logged, benchmark continues — same collector test file (AC-9)
- [ ] T017 [EDGE] RED→GREEN: isolate isolation — `IsolateBenchmarkRunner` runs a scenario in a spawned isolate, results marshalled back; runner-level flag to switch in-process/isolate — `lib/src/core/benchmark/isolate_benchmark_runner.dart`, test `test/plugins/benchmark/isolate_benchmark_runner_test.dart` (FR-007)

---

## Phase 5: CLI `zfa benchmark` (US3)

**Purpose**: Developer-facing surface (FR-011, FR-012).

- [ ] T018 [US3] RED→GREEN: `BenchmarkPlugin` (ZuraffaPlugin + CliAwarePlugin) with capabilities (run/list/register) — `lib/src/plugins/benchmark/benchmark_plugin.dart` + `capabilities/`, test `test/plugins/benchmark/benchmark_plugin_test.dart` (FR-011, FR-014)
- [ ] T019 [US3] RED→GREEN: `zfa benchmark run|list|baseline|report` command + `--dry-run`, `--scenario`, `--tags`, `--json`, `--timeout` options — `lib/src/plugins/benchmark/cli/benchmark_command.dart`, test `test/plugins/benchmark/benchmark_command_test.dart` (FR-011, FR-012)
- [ ] T020 [US3] Register `BenchmarkPlugin` in `PluginLoader._plugins()` so `zfa benchmark` is available (non-behavioral wiring; covered by command test through the loader path)

---

## Phase 6: Baseline Store + Regression Detection (US5)

**Purpose**: Historical comparison (FR-009, FR-010).

- [ ] T021 [US5] RED→GREEN: `Baseline` + `BaselineStore` interface + `JsonBaselineStore` (save/load/loadByLabel/list/listAll/delete, JSON persistence) — `lib/src/core/benchmark/baseline_store.dart`, test `test/plugins/benchmark/baseline_store_test.dart` (FR-009)
- [ ] T022 [US5] RED→GREEN: `BenchmarkComparison` + `MetricChange` + tolerance-based regression/improvement detection — same baseline store test file (FR-010, AC-10, AC-11)

---

## Phase 7: Acceptance Scenarios + Cross-Plugin Compatibility (all)

**Purpose**: The outer loop — SC-001…SC-007 proven through the real entry points.

- [ ] T023 [EDGE] RED→GREEN: SC-001 — a new plugin implements a scenario in < 50 lines (mechanically counted) — `test/plugins/benchmark/scenarios/sc_001_scenario_test.dart`
- [ ] T024 [EDGE] RED→GREEN: SC-002 — 100+ concurrent scenarios without contention — `test/plugins/benchmark/scenarios/sc_002_concurrency_test.dart`
- [ ] T025 [EDGE] RED→GREEN: SC-003 — framework overhead < 5% on a measured operation — `test/plugins/benchmark/scenarios/sc_003_overhead_test.dart`
- [ ] T026 [EDGE] RED→GREEN: SC-004 — 20-scenario suite completes < 5 min (CI integration shape) — `test/plugins/benchmark/scenarios/sc_004_ci_suite_test.dart`
- [ ] T027 [EDGE] RED→GREEN: SC-005 — regression detection accuracy on synthetic regressions (FP < 5%, FN < 1%) — `test/plugins/benchmark/scenarios/sc_005_regression_accuracy_test.dart`
- [ ] T028 [EDGE] RED→GREEN: SC-006 — custom collector overhead < 1ms per collection point — `test/plugins/benchmark/scenarios/sc_006_collector_overhead_test.dart`
- [ ] T029 [EDGE] RED→GREEN: SC-007 — 3+ plugins' benchmarks in the same suite without conflicts — `test/plugins/benchmark/scenarios/sc_007_cross_plugin_test.dart`

---

## Phase 8: Non-behavioral (implement-phase)

**Purpose**: Docs + hygiene that carries no behavior of its own.

- [ ] T030 Docs: update `specs/015-benchmark-plugin/quickstart.md` examples to the shipped API surface
- [ ] T031 Hygiene: `dart analyze` clean on all new paths; confirm NO `package:flutter` import anywhere under `lib/src/core/benchmark/` and `lib/src/plugins/benchmark/` (014-pure-dart-core-split)
- [ ] T032 Verify full-suite green: `dart analyze` + `dart test`; report actual pass/fail counts and PROVED vs unproved success criteria

---

## Notes

- Every T0xx task marked RED→GREEN is driven through the TDD loop (`/speckit.tdd.run`): the failing test is written first, its red output recorded in `tdd/cycle-log.md`, then the implementation turns it green.
- Non-behavioral tasks (T008, T020, T030–T032) are `/speckit.implement` scope.
