# Quickstart: Internal Benchmark Plugin

This guide shows how to install, configure, and use the Internal Benchmark Plugin for Zuraffa.

## Installation

The benchmark framework is a **built-in** part of the core `zuraffa` package
(pure-Dart, no Flutter dependency). Apps already depending on `zuraffa` have
it; nothing extra to add:

```yaml
dependencies:
  zuraffa: ^6.0.0
```

The contract surface is exported from the package root, so scenarios depend
only on the contract — never on the benchmark plugin's wiring (FR-015):

```dart
import 'package:zuraffa/zuraffa.dart';
```

The `zfa benchmark` CLI command ships with the CLI (the plugin registers
itself with the plugin loader):

```bash
zfa benchmark          # usage
zfa plugin list        # shows: [✓] benchmark - Benchmark (1.0.0)
```

## Defining a Custom Benchmark Scenario

Create a benchmark scenario by implementing the `BenchmarkContract` interface
(a convenience base class, `BenchmarkScenario`, provides working defaults —
SC-001: a working scenario fits in under 50 lines):

```dart
// my_benchmark.dart
import 'package:zuraffa/zuraffa.dart';

class EntityCrudBenchmark extends BenchmarkScenario {
  @override
  String get id => 'entity-crud-benchmark';

  @override
  String get name => 'Entity CRUD Operations';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'Measures latency and throughput of entity CRUD operations';

  @override
  Map<String, dynamic> get configSchema => {
        'type': 'object',
        'properties': {
          'entityCount': {'type': 'integer', 'minimum': 1, 'default': 100},
          'iterations': {'type': 'integer', 'minimum': 1, 'default': 1000},
        },
      };

  @override
  Map<String, ThresholdConfig> get thresholds => {
        'latency_p99': ThresholdConfig(
          metric: 'latency_p99',
          operator: ThresholdOperator.lte,
          value: 50, // 50ms max
          severity: ThresholdSeverity.error,
        ),
        'throughput_ops_sec': ThresholdConfig(
          metric: 'throughput_ops_sec',
          operator: ThresholdOperator.gte,
          value: 1000, // 1000 ops/sec minimum
          severity: ThresholdSeverity.warn,
        ),
      };

  @override
  List<String> get tags => ['entity', 'crud', 'database'];

  late final EntityRepository _repository;

  @override
  Future<void> setup() async {
    _repository = GetIt.instance<EntityRepository>();
    await _repository.clear();
  }

  @override
  Future<BenchmarkResult> run(Map<String, dynamic> config) async {
    final iterations = (config['iterations'] as num?)?.toInt() ?? 1000;
    final stopwatch = Stopwatch()..start();
    var successCount = 0;

    for (var i = 0; i < iterations; i++) {
      final product = Product(name: 'Bench $i', price: i.toDouble());
      final created = await _repository.create(product);
      final read = await _repository.getById(created.id);
      read.price += 1;
      await _repository.update(read);
      await _repository.delete(read.id);
      successCount++;
    }

    stopwatch.stop();

    // Standard metrics (latency p50/p95/p99, throughput, memory, CPU) are
    // layered on by the runner's StandardMetricCollector. The scenario
    // returns only its own domain metrics.
    return BenchmarkResult(
      scenarioId: id,
      scenarioName: name,
      scenarioVersion: version,
      status: BenchmarkStatus.passed, // evaluated by the runner
      metrics: {
        'crud_cycles': successCount,
      },
      thresholdViolations: [],
      duration: stopwatch.elapsed,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<void> teardown() async {
    await _repository.clear();
  }

  @override
  Future<Map<String, num>> collectMetrics() async {
    // Custom metrics beyond the standard ones
    return {'custom_db_queries': _repository.queryCount.toDouble()};
  }
}
```

Plugins that prefer the pure interface (no base class) can `implements
BenchmarkContract` directly — every member of the contract surface must then
be provided (see `test/plugins/benchmark/scenarios/ac_001_contract_run_test.dart`).

## Registering Your Benchmark

Register scenarios through the plugin's provider mechanism (cross-plugin
registration, FR-003/FR-014). In your plugin or app bootstrap:

```dart
import 'package:zuraffa/zuraffa.dart';
import 'benchmark_plugin_scenario.dart'; // BenchmarkScenarioProvider
import 'my_benchmark.dart';

class MyPlugin {
  // Wire into the benchmark plugin wherever you have both handles:
  final benchmark = BenchmarkPlugin();
  benchmark.registerScenarioProvider(_MyProvider());
  await benchmark.discoverAndRegisterScenarios();
}

class _MyProvider implements BenchmarkScenarioProvider {
  @override
  List<BenchmarkContract> provideScenarios() => [
        EntityCrudBenchmark(),
        // more scenarios...
      ];
}
```

Duplicate scenario ids are rejected with a conflict error; invalid metadata
(bad id format, non-semver version) is rejected at registration without
executing anything.

## Running Benchmarks Programmatically

```dart
final runner = DefaultBenchmarkRunner();
final suite = await runner.run([
  EntityCrudBenchmark(),
  AnotherBenchmark(),
], globalConfig: {'iterations': 100});

print(suite.overallStatus);   // passed | failed | error
print(suite.summary);         // {total: 2, passed: 2, ...}

// Isolation: run a scenario in its own isolate (FR-007)
final isolateRunner = IsolateBenchmarkRunner();
final result = await isolateRunner.runSingle(EntityCrudBenchmark());
print(result.metadata['isolated']); // true
```

## Running Benchmarks via CLI

### List Available Benchmarks

```bash
# Human-readable output
zfa benchmark list

# JSON output for scripting
zfa benchmark list --json
```

### Run All Benchmarks

```bash
# Run all registered scenarios
zfa benchmark run

# Run with JSON output
zfa benchmark run --json

# Run only specific tags
zfa benchmark run --tags entity,crud

# Worker-pool concurrency
zfa benchmark run --concurrency 4
```

### Run Specific Scenario

```bash
zfa benchmark run --scenario entity-crud-benchmark
```

### Dry Run (Validate Configuration)

```bash
zfa benchmark run --scenario entity-crud-benchmark --dry-run
zfa benchmark run --dry-run --config '{"entityCount": 10}'
```

## Configuring Thresholds

Thresholds are declared on the scenario (as shown above) — per metric,
operator (`lt`/`lte`/`gt`/`gte`), value, and severity (`error` fails the run,
`warn` only records a violation). The runner evaluates them against the final
metrics and records `ThresholdViolation`s naming the exact metric, expected
condition, and actual value.

## Baseline Management

```bash
# Save current run as baseline
zfa benchmark baseline save entity-crud-benchmark --label "v1.0-release"

# Load latest baseline
zfa benchmark baseline load entity-crud-benchmark

# Compare current results against a baseline (regression detection)
zfa benchmark baseline compare entity-crud-benchmark --baseline "v1.0-release"

# List all baselines
zfa benchmark baseline list
```

Baselines persist as human-readable JSON under `benchmarks/baselines/`
(one file per scenario; override the location with `--store <dir>`).
Comparison flags per-metric regressions/improvements with configurable
tolerance (`--tolerance 10` = 10 percent) and severity (`warn` just beyond
tolerance, `error` beyond twice the tolerance).

## Adding Custom Metric Collectors

```dart
// db_query_collector.dart
import 'package:zuraffa/zuraffa.dart';

class DatabaseQueryCollector implements MetricCollector {
  @override
  String get id => 'db-query-collector';

  @override
  String get name => 'Database Query Counter';

  int _queryCount = 0;

  @override
  Future<void> initialize() async {
    _queryCount = 0;
  }

  @override
  Future<void> beforeBenchmark(MetricContext context) async {
    _queryCount = 0;
  }

  @override
  Future<Map<String, num>> collect(MetricContext context) async {
    // Returned metrics are merged into the scenario's final result.
    return {'custom_db_queries': _queryCount};
  }

  @override
  Future<void> finalize() async {}

  void incrementQueryCount() => _queryCount++;
}
```

Register the collector:

```dart
final runner = DefaultBenchmarkRunner();
runner.registerMetricCollector(DatabaseQueryCollector());
```

A collector that throws is logged and skipped — it never fails the benchmark
or the suite (AC-9).

## CI/CD Integration

### GitHub Actions Example

```yaml
# .github/workflows/benchmark.yml
name: Benchmark

on: [push, pull_request]

jobs:
  benchmark:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Dart
        uses: dart-lang/setup-dart@v1
        with:
          sdk: 'stable'

      - name: Install dependencies
        run: dart pub get

      - name: Run benchmarks
        run: dart run bin/benchmark.dart --json > benchmark-results.json

      - name: Upload results
        uses: actions/upload-artifact@v4
        with:
          name: benchmark-results
          path: benchmark-results.json
```

The CLI exits non-zero when a suite fails its thresholds or a comparison
detects a regression, so plain `zfa benchmark run` (or a small
`bin/benchmark.dart` that registers your providers and invokes the command)
works directly as a CI quality gate.

## Viewing Reports

```bash
# Console report of the last run (persisted to the store directory)
zfa benchmark report
```

Console and JSON output are shipped; HTML report rendering is a future
format (the `report` command's output layer is the seam).

## Troubleshooting

### Benchmark Timeout

Per-scenario timeouts default to 5 minutes; the runner marks timed-out
scenarios failed (with a synthetic `timeout` violation) and continues the
suite. Configure via `BenchmarkRunnerConfig(timeout: ...)`.

### Isolation Issues

Use `IsolateBenchmarkRunner` to run each scenario in a pristine isolate —
crashes inside a scenario are contained and reported as error results.
Process-level isolation is a documented future extension.

### Missing Dependencies

If a benchmark requires external resources (database, network), ensure
they're available in your CI environment or mock them in the scenario's
`setup()`.

---

## Status

Implemented (feature 015-benchmark-plugin). API surface:
`lib/src/core/benchmark/` (contract library, exported from
`package:zuraffa/zuraffa.dart`) and `lib/src/plugins/benchmark/` (plugin,
capabilities, `zfa benchmark` CLI).
