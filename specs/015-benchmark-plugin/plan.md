# Implementation Plan: Internal Benchmark Plugin

**Branch**: `015-benchmark-plugin` | **Date**: 2026-08-26 | **Spec**: specs/015-benchmark-plugin/spec.md

**Input**: Feature specification from specs/015-benchmark-plugin/spec.md

## Summary

Create an internal benchmark plugin for Zuraffa that provides an extensible contract interface for defining, registering, executing, and comparing benchmark scenarios. The plugin is decoupled from specific plugin implementations - scenarios depend only on the contract interface. It supports standardized metrics (latency percentiles, throughput, memory, CPU), custom metric collectors, historical baseline comparison, and CI/CD integration via `zfa benchmark` CLI.

## Technical Context

**Language/Version**: Dart 3.11+ (pure Dart)

**Primary Dependencies**: 
- Zuraffa framework (DI container, plugin system)
- Zorphy (entity generation)
- GetIt (dependency injection)
- package:benchmark_harness (Dart benchmarking primitives)
- package:test (test framework)

**Storage**: Local filesystem (JSON/MessagePack for baseline storage), extensible to remote

**Testing**: package:test (unit, integration, regression tiers per dart_test.yaml presets)

**Target Platform**: Dart VM (JIT for development, AOT for release profiling), Linux/macOS/Windows

**Project Type**: Zuraffa plugin (pure Dart library with CLI command)

**Performance Goals**: 
- Framework overhead < 5% of measured operation
- 100+ concurrent benchmark scenarios
- < 5 min CI/CD suite for 20 scenarios

**Constraints**: 
- Must be pure Dart (no Flutter SDK dependency) per 014-pure-dart-core-split
- Must integrate with existing Zuraffa plugin system and DI container
- Contract interface must be usable without benchmark runner as runtime dependency
- No coupling between benchmark scenarios and specific plugin implementations

**Scale/Scope**: 
- Core plugin + contract library
- Support for 100s of benchmark scenarios across Zuraffa ecosystem
- Cross-plugin compatibility (3+ plugins in same suite)

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

Based on existing Zuraffa plugin structure:

```
lib/src/
├── plugins/
│   └── benchmark/
│       ├── benchmark_plugin.dart           # ZuraffaPlugin implementation
│       ├── benchmark_contract.dart         # Contract interface (exported separately)
│       ├── benchmark_registry.dart         # Scenario registration/discovery
│       ├── benchmark_runner.dart           # Execution orchestration
│       ├── benchmark_result.dart           # Result data structures
│       ├── metric_collector.dart           # Extensible collector interface
│       ├── baseline_store.dart             # Historical baseline persistence
│       ├── cli/
│       │   └── benchmark_command.dart      # `zfa benchmark` command
│       ├── capabilities/
│       │   ├── run_benchmark_capability.dart
│       │   ├── list_benchmarks_capability.dart
│       │   └── register_benchmark_capability.dart
│       └── builders/
│           └── benchmark_builder.dart      # Code generation if needed
├── core/
│   └── benchmark/                          # Contract library (exportable)
│       ├── contract.dart
│       ├── registry.dart
│       ├── runner.dart
│       ├── collector.dart
│       └── result.dart

test/
├── plugins/
│   └── benchmark/
│       ├── benchmark_plugin_test.dart
│       ├── benchmark_contract_test.dart
│       ├── benchmark_registry_test.dart
│       ├── benchmark_runner_test.dart
│       ├── benchmark_result_test.dart
│       ├── metric_collector_test.dart
│       ├── baseline_store_test.dart
│       └── benchmark_command_test.dart
├── integration/
│   └── benchmark_integration_test.dart     # Full suite execution
└── regression/
    └── benchmark_regression_test.dart      # Performance regression detection
```

**Structure Decision**: Follows existing Zuraffa plugin pattern (lib/src/plugins/benchmark/) with contract library extracted to lib/src/core/benchmark/ for independent use by other plugins/apps.

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