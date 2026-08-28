# Implementation Plan: Internal Benchmark Plugin

**Branch**: `015-benchmark-plugin` | **Date**: 2026-08-26 (refined 2026-08-28 during the SDD cycle) | **Spec**: specs/015-benchmark-plugin/spec.md

**Input**: Feature specification from specs/015-benchmark-plugin/spec.md

## Summary

Create an internal benchmark plugin for Zuraffa that provides an extensible contract interface for defining, registering, executing, and comparing benchmark scenarios. The plugin is decoupled from specific plugin implementations - scenarios depend only on the contract interface. It supports standardized metrics (latency percentiles, throughput, memory, CPU), custom metric collectors, historical baseline comparison, and CI/CD integration via `zfa benchmark` CLI.

## Technical Context

**Language/Version**: Dart 3.11+ (pure Dart; repo pins `sdk: ^3.11.0`, developed against 3.13.2)

**Primary Dependencies**: 
- Zuraffa core package itself (this repo — the benchmark plugin ships inside `zuraffa`)
- Zuraffa plugin infrastructure: `ZuraffaPlugin`, `ZuraffaCapability`, `CliAwarePlugin`, `PluginRegistry`, `PluginLoader` (lib/src/core/plugin_system/)
- ZuraffaDIContainer / GetIt (`lib/src/core/module/di_container.dart`) for cross-plugin registration of scenarios
- `package:args` (already a dependency) for the `zfa benchmark` CLI command
- `package:test` (test framework, already a dev dependency)
- **NO new dependencies.** `research.md` proposed `package:benchmark_harness`; that is a pub
  package, not part of the Dart SDK, and adding it would violate the TDD discipline rule
  ("never install or add a dependency to make a test writable") and bloat the core package.
  The runner therefore wraps `Stopwatch`-based timing with warmup + iteration control and
  statistical percentiles computed in pure Dart — the same measurement model
  `benchmark_harness` uses, without the dependency.

**Storage**: Local filesystem, JSON (per research.md decision): `benchmarks/baselines/<scenario-id>.json`
with an `index.json` manifest; extensible via the `BaselineStore` interface to remote storage.

**Testing**: package:test (unit + integration + regression tiers per dart_test.yaml presets);
new benchmark-plugin tests live under `test/plugins/benchmark/` mirroring the source layout, with
scenario-style acceptance tests under `test/plugins/benchmark/scenarios/` tracing 1:1 to the
spec's success criteria (same harness convention as the 018-cli-plugin feature).

**Target Platform**: Dart VM (JIT for development, AOT for release profiling), Linux/macOS/Windows

**Project Type**: Built-in Zuraffa plugin inside the pure-Dart root `zuraffa` package (runtime
library + `zfa benchmark` CLI command). "Installed" in an app via `zfa plugin add` convention:
the plugin is built-in, so apps import the contract from `package:zuraffa/zuraffa.dart` and
register scenarios through the DI container / plugin capabilities.

**Performance Goals**: 
- Framework overhead < 5% of measured operation (SC-003)
- 100+ concurrent benchmark scenarios (SC-002)
- < 5 min CI/CD suite for 20 scenarios (SC-004)
- Custom collector overhead < 1ms per collection point (SC-006)

**Constraints**: 
- Must be pure Dart (no Flutter SDK dependency) per 014-pure-dart-core-split
- Must integrate with the existing Zuraffa plugin system and DI container
- Contract interface must be usable without the benchmark runner as a runtime dependency
- No coupling between benchmark scenarios and specific plugin implementations (FR-015)
- Isolation via `Isolate.spawn` (per research.md) — process-level isolation is documented as a
  future extension; isolate-level satisfies FR-007's "separate processes or isolates"

**Scale/Scope**: 
- Core plugin + contract library
- Support for 100s of benchmark scenarios across the Zuraffa ecosystem
- Cross-plugin compatibility (3+ plugins in same suite, SC-007)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Based on CLAUDE.md project principles:

- ✅ **Library-First**: Benchmark contract is a standalone library; runner is separate plugin
- ✅ **CLI Interface**: `zfa benchmark` command exposes functionality via CLI
- ✅ **Test-First**: TDD mandatory - will generate test-list.md before implementation
- ✅ **Integration Testing**: Contract tests + plugin integration tests required
- ✅ **Observability**: Structured metrics output (JSON), regression detection
- ✅ **Simplicity**: YAGNI - start with core contract + runner, extend incrementally

No violations. The design follows all principles.

## Project Structure

### Documentation (this feature)

```
specs/015-benchmark-plugin/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (created by /skill:speckit-tasks)
```

### Source Code (repository root)

Final layout (refined 2026-08-28 to match the repo's actual conventions — single
contract library under `lib/src/core/benchmark/`, plugin + CLI under
`lib/src/plugins/benchmark/`, mirroring how the 017-tui / 018-cli features
split runtime library from plugin):

```
lib/src/
├── core/
│   └── benchmark/                          # Contract library (interface-only, FR-015)
│       ├── benchmark_contract.dart         # BenchmarkContract + BenchmarkScenario + ThresholdConfig
│       ├── benchmark_registry.dart         # BenchmarkRegistry interface + InMemoryBenchmarkRegistry
│       ├── benchmark_runner.dart           # BenchmarkRunner interface + DefaultBenchmarkRunner
│       ├── benchmark_result.dart           # BenchmarkResult, BenchmarkSuiteResult, ThresholdViolation
│       ├── metric_collector.dart           # MetricCollector + MetricContext + StandardMetricCollector
│       ├── baseline_store.dart             # BaselineStore + Baseline + JsonBaselineStore + comparisons
│       └── standard_metrics.dart           # StandardMetrics names + percentile math
│
├── plugins/
│   └── benchmark/
│       ├── benchmark_plugin.dart           # BenchmarkPlugin (ZuraffaPlugin + CliAwarePlugin)
│       ├── capabilities/
│       │   ├── run_benchmark_capability.dart
│       │   ├── list_benchmarks_capability.dart
│       │   └── register_benchmark_capability.dart
│       ├── cli/
│       │   └── benchmark_command.dart      # `zfa benchmark` command (+ subcommands)
│       └── scenario_provider.dart          # BenchmarkScenarioProvider capability contract

lib/zuraffa.dart                            # exports the benchmark contract library
lib/src/cli/plugin_loader.dart              # registers BenchmarkPlugin

test/plugins/benchmark/                     # mirrors source layout
├── scenarios/                              # acceptance tests, 1:1 with SC-001…SC-007
├── helpers/                                # fake scenarios/collectors/repositories
├── benchmark_contract_test.dart
├── benchmark_registry_test.dart
├── benchmark_runner_test.dart
├── benchmark_result_test.dart
├── metric_collector_test.dart
├── baseline_store_test.dart
└── benchmark_command_test.dart
```

**Structure Decision**: The contract surface (interfaces + value types) lives in
`lib/src/core/benchmark/` so third-party plugins/apps depend ONLY on the contract
(FR-015) and never on the plugin implementation. The `BenchmarkPlugin` wires the
contract into the Zuraffa plugin system, exposes capabilities, and registers the
`zfa benchmark` CLI command via `CliAwarePlugin`. The capability-based scenario
discovery (`BenchmarkScenarioProvider`) uses the existing DI/plugin infrastructure
per research.md's cross-plugin registration decision.

## Complexity Tracking

No Constitution Check violations - no tracking needed.

---

## Phase 0: Research

### Unknowns to Resolve

1. **Dart benchmark_harness integration**: How to properly use Dart's built-in benchmark harness for standardized measurements
2. **Isolate-based benchmark isolation**: Best practices for running benchmarks in separate isolates to prevent cross-contamination
3. **Baseline storage format**: JSON vs MessagePack for historical baseline persistence
4. **Metric collector lifecycle**: Exact lifecycle hooks (beforeSuite, beforeBenchmark, afterBenchmark, afterSuite)
5. **Threshold configuration schema**: JSON Schema for per-benchmark threshold definitions
6. **Cross-plugin scenario registration**: How external plugins register scenarios without direct dependency on benchmark runner

### Research Tasks

- [ ] Research Dart benchmark_harness API and integration patterns
- [ ] Research isolate-based execution for benchmark isolation
- [ ] Compare JSON vs MessagePack for baseline storage performance
- [ ] Define metric collector lifecycle and API
- [ ] Design threshold configuration schema
- [ ] Design cross-plugin registration mechanism (DI-based)

---

## Phase 1: Design & Contracts

### Data Model (data-model.md)

**Entities from spec:**

1. **BenchmarkScenario**
   - id: String (unique identifier)
   - name: String (human-readable)
   - version: String (semver)
   - description: String
   - configSchema: Map<String, dynamic> (JSON Schema)
   - thresholds: Map<String, ThresholdConfig> (metric name → threshold)
   - scenarioFn: Function (the actual benchmark logic)

2. **ThresholdConfig**
   - metric: String (e.g., "latency_p99", "throughput_ops_sec")
   - operator: String ("lt", "lte", "gt", "gte")
   - value: num
   - severity: String ("error", "warn")

3. **BenchmarkContract** (interface)
   - setup(): Future<void>
   - run(config: Map<String, dynamic>): Future<BenchmarkResult>
   - teardown(): Future<void>
   - collectMetrics(): Future<Map<String, num>>

4. **BenchmarkRegistry**
   - register(scenario: BenchmarkScenario): Future<Result<void>>
   - unregister(id: String): Future<Result<void>>
   - getAll(): Future<List<BenchmarkScenario>>
   - get(id: String): Future<BenchmarkScenario?>

5. **BenchmarkRunner**
   - run(scenarios: List<BenchmarkScenario>): Future<BenchmarkSuiteResult>
   - runSingle(scenario: BenchmarkScenario): Future<BenchmarkResult>

6. **MetricCollector** (interface)
   - initialize(): Future<void>
   - collect(context: MetricContext): Future<Map<String, num>>
   - finalize(): Future<void>

7. **BenchmarkResult**
   - scenarioId: String
   - status: String ("passed", "failed", "error", "skipped")
   - metrics: Map<String, num> (latency_p50, latency_p95, latency_p99, throughput_ops_sec, memory_mb, cpu_percent, custom...)
   - thresholdViolations: List<ThresholdViolation>
   - duration: Duration
   - timestamp: DateTime
   - metadata: Map<String, dynamic>

8. **BenchmarkSuiteResult**
   - results: List<BenchmarkResult>
   - overallStatus: String ("passed", "failed")
   - totalDuration: Duration
   - summary: Map<String, dynamic>

9. **BaselineStore**
   - save(baseline: Baseline): Future<void>
   - load(scenarioId: String): Future<Baseline?>
   - list(): Future<List<Baseline>>

10. **Baseline**
    - scenarioId: String
    - scenarioVersion: String
    - metrics: Map<String, num>
    - timestamp: DateTime
    - gitCommit: String

### Contracts (contracts/)

- `contracts/benchmark_contract.md` - Interface definition for BenchmarkContract, MetricCollector, BenchmarkRegistry
- `contracts/benchmark_config_schema.json` - JSON Schema for scenario configuration
- `contracts/threshold_schema.json` - JSON Schema for threshold definitions
- `contracts/result_schema.json` - JSON Schema for BenchmarkResult and BenchmarkSuiteResult
- `contracts/cli_schema.json` - CLI command argument/option schema for `zfa benchmark`

### Quickstart (quickstart.md)

Documentation for:
- Installing the benchmark plugin (`zfa plugin add zuraffa_benchmark`)
- Defining a custom benchmark scenario (implementing BenchmarkContract)
- Registering a scenario
- Running benchmarks via CLI (`zfa benchmark run`, `zfa benchmark list`, `zfa benchmark report`)
- Configuring thresholds
- Adding custom metric collectors
- CI/CD integration examples
- Baseline management (`zfa benchmark baseline save/load/compare`)

---

## Next Steps

1. Execute Phase 0: Research unknowns and produce `research.md`
2. Execute Phase 1: Produce `data-model.md`, `contracts/`, `quickstart.md`
3. Run `/skill:speckit-tasks` to generate implementation tasks
4. Run `/skill:speckit-tdd-plan` to derive test list from spec