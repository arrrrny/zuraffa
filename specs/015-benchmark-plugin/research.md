# Research: Internal Benchmark Plugin

## Decision: Dart benchmark_harness Integration

**Chosen**: Use `package:benchmark_harness` as the underlying measurement engine, wrapped by our `BenchmarkRunner` to provide standardized metrics.

**Rationale**: 
- Built into Dart SDK, no external dependencies
- Provides `BenchmarkBase` class with `measure()` method for consistent timing
- Supports warmup runs, iteration control, and statistical reporting
- Already used by Dart/Flutter teams for performance testing

**Alternatives Considered**:
- Custom timing with `Stopwatch` - more flexible but less statistical rigor
- `package:perf` - more features but adds dependency
- Manual `dart:developer` timeline events - too low-level for our needs

**Integration Pattern**:
```dart
class ZuraffaBenchmark extends BenchmarkBase {
  final BenchmarkScenario scenario;
  final Map<String, dynamic> config;
  
  ZuraffaBenchmark(this.scenario, this.config) : super(scenario.name);
  
  @override
  void run() {
    // Execute scenario logic here
    scenario.scenarioFn(config);
  }
  
  @override
  void report() {
    // Extract metrics from benchmark_harness and convert to our format
  }
}
```

---

## Decision: Isolate-Based Benchmark Isolation

**Chosen**: Run each benchmark scenario in a separate `Isolate` using `Isolate.spawn()` with message passing for configuration and results.

**Rationale**:
- True memory isolation prevents cross-benchmark contamination
- CPU scheduling isolation prevents resource contention
- Dart isolates are lightweight compared to processes
- Native support for message passing (no shared memory)

**Alternatives Considered**:
- Separate processes (`Process.run`) - heavier, slower startup, IPC complexity
- Single isolate with sequential execution - no isolation, cross-contamination risk
- Worker pool pattern - complex, still shares isolate memory

**Implementation Pattern**:
```dart
Future<BenchmarkResult> runInIsolate(BenchmarkScenario scenario, Map config) async {
  final receivePort = ReceivePort();
  await Isolate.spawn(_benchmarkEntryPoint, {
    'scenario': scenario.toJson(),
    'config': config,
    'sendPort': receivePort.sendPort,
  });
  
  final result = await receivePort.first as Map<String, dynamic>;
  return BenchmarkResult.fromJson(result);
}

void _benchmarkEntryPoint(Map<String, dynamic> message) {
  // Run benchmark in isolated context
  // Send result back via message['sendPort']
}
```

**Trade-offs**: 
- Isolate startup overhead (~1-5ms) - acceptable for benchmarks
- Cannot share mutable state - scenarios must be self-contained
- Serialization overhead for config/results - use efficient encoding

---

## Decision: Baseline Storage Format - JSON

**Chosen**: JSON for baseline storage with optional gzip compression.

**Rationale**:
- Human-readable for debugging and manual inspection
- Native Dart support (`dart:convert`)
- Sufficient performance for baseline sizes (few KB per scenario)
- Easy to extend with new fields
- Git-friendly for version-controlled baselines

**Alternatives Considered**:
- MessagePack - more compact but requires dependency, not human-readable
- Protocol Buffers - schema evolution but adds complexity
- SQLite - overkill for simple key-value baseline storage

**Storage Structure**:
```
benchmarks/
└── baselines/
    ├── <scenario-id>.json
    └── index.json          # Lists all baselines with metadata
```

---

## Decision: Metric Collector Lifecycle

**Chosen**: Four-phase lifecycle matching benchmark execution:

1. **initialize()** - Called once before suite starts (setup collectors)
2. **beforeBenchmark(scenario, config)** - Called before each scenario
3. **afterBenchmark(scenario, result)** - Called after each scenario
4. **finalize()** - Called once after suite ends (cleanup, aggregate)

**Rationale**:
- Matches standard benchmark runner patterns
- Allows collectors to track per-scenario and aggregate metrics
- Enables collectors that need setup/teardown (e.g., memory profilers)
- Simple enough for custom collectors to implement

**MetricContext passed to collectors**:
```dart
class MetricContext {
  final String scenarioId;
  final String scenarioName;
  final Map<String, dynamic> config;
  final BenchmarkResult? result;  // null in beforeBenchmark
  final Duration elapsed;
  final int iteration;
}
```

---

## Decision: Threshold Configuration Schema (JSON Schema)

**Chosen**: JSON Schema Draft 2020-12 for threshold definitions.

**Schema**:
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "metric": { "type": "string", "enum": ["latency_p50", "latency_p95", "latency_p99", "throughput_ops_sec", "memory_mb", "cpu_percent"] },
    "operator": { "type": "string", "enum": ["lt", "lte", "gt", "gte"] },
    "value": { "type": "number" },
    "severity": { "type": "string", "enum": ["error", "warn"] }
  },
  "required": ["metric", "operator", "value", "severity"],
  "additionalProperties": false
}
```

**Rationale**: 
- JSON Schema is standard, toolable, and self-documenting
- Supports validation at registration time
- Extensible for custom metrics (allow additional metric names via pattern)
- Clear severity separation (error=fail build, warn=log only)

---

## Decision: Cross-Plugin Registration Mechanism

**Chosen**: DI-based registration using Zuraffa's plugin system and DI container.

**Mechanism**:
1. Benchmark plugin registers a `BenchmarkRegistry` in the DI container at startup
2. Other plugins declare a `BenchmarkScenarioProvider` capability
3. During plugin initialization, the benchmark plugin discovers all `BenchmarkScenarioProvider` capabilities and calls their `provideScenarios()` method
4. Scenarios are registered in the `BenchmarkRegistry`

**Contract for external plugins**:
```dart
abstract class BenchmarkScenarioProvider {
  List<BenchmarkScenario> provideScenarios();
}
```

**Rationale**:
- Uses existing Zuraffa plugin/di infrastructure
- No direct coupling - plugins depend only on contract interface
- Automatic discovery at runtime
- Supports lazy registration (scenarios provided on-demand)

**Alternatives Considered**:
- Manual registration via CLI - not automated
- File-based discovery - fragile, not dynamic
- Event bus - adds dependency, less integrated with DI

---

## Decision: CLI Command Structure

**Chosen**: Subcommand-based CLI following Zuraffa conventions:

```
zfa benchmark run [--scenario <id>] [--dry-run] [--output <format>] [--threshold-config <file>]
zfa benchmark list [--json]
zfa benchmark baseline save <scenario-id> [--name <label>]
zfa benchmark baseline load <scenario-id>
zfa benchmark baseline compare <scenario-id> [--baseline <label>]
zfa benchmark report <run-id> [--format html|json|console]
```

**Rationale**: Consistent with existing `zfa` command patterns, supports all user stories.

---

## Summary of Resolved Unknowns

| Unknown | Decision |
|---------|----------|
| benchmark_harness integration | Wrap BenchmarkBase, use measure() for timing |
| Isolation | Separate isolates per scenario |
| Baseline storage | JSON (human-readable, git-friendly) |
| Collector lifecycle | 4-phase: init, beforeBenchmark, afterBenchmark, finalize |
| Threshold schema | JSON Schema with metric/operator/value/severity |
| Cross-plugin registration | DI-based via BenchmarkScenarioProvider capability |
| CLI structure | Subcommands (run, list, baseline, report) |

All NEEDS CLARIFICATION items from spec resolved. Ready for Phase 1 design.