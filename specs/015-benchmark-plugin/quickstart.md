# Quickstart: Internal Benchmark Plugin

This guide shows how to install, configure, and use the Internal Benchmark Plugin for Zuraffa.

## Installation

Add the benchmark plugin to your Zuraffa app:

```bash
# Add the plugin (once published)
zfa plugin add zuraffa_benchmark

# Or for local development
zfa plugin add --path ../zuraffa_benchmark
```

The plugin registers itself automatically via Zuraffa's plugin system.

## Defining a Custom Benchmark Scenario

Create a benchmark scenario by implementing the `BenchmarkContract` interface:

```dart
// my_benchmark.dart
import 'package:zuraffa_benchmark/benchmark_contract.dart';

class EntityCrudBenchmark implements BenchmarkContract {
  @override
  String get id => 'entity-crud-benchmark';

  @override
  String get name => 'Entity CRUD Operations';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Measures latency and throughput of entity CRUD operations';

  @override
  Map<String, dynamic> get configSchema => {
    'type': 'object',
    'properties': {
      'entityCount': { 'type': 'integer', 'minimum': 1, 'default': 100 },
      'iterations': { 'type': 'integer', 'minimum': 1, 'default': 1000 },
    },
  };

  @override
  Map<String, ThresholdConfig> get thresholds => {
    'latency_p99': ThresholdConfig(
      metric: 'latency_p99',
      operator: 'lte',
      value: 50,  // 50ms max
      severity: 'error',
    ),
    'throughput_ops_sec': ThresholdConfig(
      metric: 'throughput_ops_sec',
      operator: 'gte',
      value: 1000,  // 1000 ops/sec minimum
      severity: 'warn',
    ),
  };

  @override
  List<String> get tags => ['entity', 'crud', 'database'];

  late final EntityRepository _repository;

  @override
  Future<void> setup() async {
    // Initialize repository, create test data
    _repository = GetIt.instance<EntityRepository>();
    await _repository.clear();
    for (int i = 0; i < 1000; i++) {
      await _repository.create(Product(name: 'Product $i', price: 9.99));
    }
  }

  @override
  Future<BenchmarkResult> run(Map<String, dynamic> config) async {
    final entityCount = config['entityCount'] as int? ?? 100;
    final iterations = config['iterations'] as int? ?? 1000;
    
    final stopwatch = Stopwatch()..start();
    int successCount = 0;
    
    for (int i = 0; i < iterations; i++) {
      // Create
      final product = Product(name: 'Bench $i', price: i.toDouble());
      final created = await _repository.create(product);
      
      // Read
      final read = await _repository.getById(created.id);
      
      // Update
      read.price += 1;
      await _repository.update(read);
      
      // Delete
      await _repository.delete(read.id);
      
      successCount++;
    }
    
    stopwatch.stop();
    
    // Metrics will be collected automatically by StandardMetricCollector
    return BenchmarkResult(
      scenarioId: id,
      scenarioName: name,
      scenarioVersion: version,
      status: 'passed',  // Will be evaluated by runner
      metrics: {
        'latency_p50': 0,  // Filled by runner
        'latency_p95': 0,
        'latency_p99': 0,
        'throughput_ops_sec': (successCount * 4) / (stopwatch.elapsedMilliseconds / 1000),
        'memory_mb': 0,
        'cpu_percent': 0,
      },
      thresholdViolations: [],
      duration: stopwatch.elapsed,
      timestamp: DateTime.now(),
      gitCommit: 'unknown',  // Filled by runner
      metadata: {
        'config': config,
        'successCount': successCount,
      },
    );
  }

  @override
  Future<void> teardown() async {
    await _repository.clear();
  }

  @override
  Future<Map<String, num>> collectMetrics() async {
    // Custom metrics beyond standard ones
    return {
      'custom_db_queries': _repository.queryCount.toDouble(),
    };
  }
}
```

## Registering Your Benchmark

Register the scenario in your plugin's initialization:

```dart
// my_plugin.dart
import 'package:zuraffa/zuraffa.dart';
import 'package:zuraffa_benchmark/benchmark_contract.dart';
import 'my_benchmark.dart';

class MyPlugin extends ZuraffaPlugin {
  @override
  String get id => 'my-plugin';

  @override
  List<ZuraffaCapability> get capabilities => [
    BenchmarkScenarioProviderCapability(_provideScenarios),
    // ... other capabilities
  ];

  List<BenchmarkScenario> _provideScenarios() => [
    EntityCrudBenchmark(),
    // Add more scenarios here
  ];
}

// Register plugin
void main() {
  ZuraffaEngine.instance.registerPlugin(MyPlugin());
  runApp(MyApp());
}
```

## Running Benchmarks

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
zfa benchmark run --output json

# Run only specific tags
zfa benchmark run --tags entity,crud
```

### Run Specific Scenario

```bash
zfa benchmark run --scenario entity-crud-benchmark
```

### Dry Run (Validate Configuration)

```bash
zfa benchmark run --scenario entity-crud-benchmark --dry-run
```

## Configuring Thresholds

Thresholds can be defined in the scenario code (as shown above) or in a separate config file:

```json
// thresholds.json
{
  "entity-crud-benchmark": {
    "latency_p99": { "metric": "latency_p99", "operator": "lte", "value": 100, "severity": "error" },
    "memory_mb": { "metric": "memory_mb", "operator": "lte", "value": 50, "severity": "warn" }
  }
}
```

Use with:
```bash
zfa benchmark run --threshold-config thresholds.json
```

## Baseline Management

### Save Baseline

```bash
# Save current run as baseline
zfa benchmark baseline save entity-crud-benchmark --label "v1.0-release"

# Save with auto-generated label (timestamp)
zfa benchmark baseline save entity-crud-benchmark
```

### Load and Compare Baselines

```bash
# Load latest baseline
zfa benchmark baseline load entity-crud-benchmark

# Load specific baseline
zfa benchmark baseline load entity-crud-benchmark --label "v1.0-release"

# Compare current results against baseline
zfa benchmark baseline compare entity-crud-benchmark

# Compare against specific baseline
zfa benchmark baseline compare entity-crud-benchmark --baseline "v1.0-release"
```

### List Baselines

```bash
zfa benchmark baseline list entity-crud-benchmark
zfa benchmark baseline list  # All baselines
```

## Adding Custom Metric Collectors

Create a custom metric collector:

```dart
// db_query_collector.dart
import 'package:zuraffa_benchmark/metric_collector.dart';

class DatabaseQueryCollector implements MetricCollector {
  @override
  String get id => 'db-query-collector';

  @override
  String get name => 'Database Query Counter';

  int _queryCount = 0;

  @override
  Future<void> initialize() async {
    _queryCount = 0;
    // Subscribe to database events if available
  }

  @override
  Future<void> beforeBenchmark(MetricContext context) async {
    _queryCount = 0;
  }

  @override
  Future<void> afterBenchmark(MetricContext context) async {
    if (context.result != null) {
      // Add custom metric to result
      context.result!.metadata['custom_db_queries'] = _queryCount;
    }
  }

  @override
  Future<void> finalize() async {
    // Cleanup
  }

  void incrementQueryCount() => _queryCount++;
}
```

Register the collector:

```dart
// In your plugin or app initialization
final runner = GetIt.instance<BenchmarkRunner>();
runner.registerMetricCollector(DatabaseQueryCollector());
```

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
        run: zfa benchmark run --output json > benchmark-results.json
      
      - name: Upload results
        uses: actions/upload-artifact@v4
        with:
          name: benchmark-results
          path: benchmark-results.json
      
      - name: Compare with baseline
        run: |
          zfa benchmark baseline compare --all --fail-on-regression
```

### Failing Build on Regression

```bash
# Exit with non-zero code if any regression detected
zfa benchmark baseline compare --all --fail-on-regression
```

## Viewing Reports

```bash
# Console report (default)
zfa benchmark report latest

# JSON report
zfa benchmark report latest --format json

# HTML report (opens in browser)
zfa benchmark report latest --format html --output benchmark-report.html
```

## Troubleshooting

### Benchmark Timeout

```bash
# Increase timeout (if supported in future versions)
zfa benchmark run --timeout 300s
```

### Isolation Issues

If benchmarks interfere with each other, ensure they run in separate isolates (default):

```bash
zfa benchmark run --isolate  # Default: true
```

### Missing Dependencies

If a benchmark requires external resources (database, network), ensure they're available in your CI environment or mock them in the scenario's `setup()` method.

---

## Next Steps

1. Run `/skill:speckit-tasks` to generate implementation tasks
2. Run `/skill:speckit-tdd-plan` to derive test list from spec
3. Begin TDD implementation with `/skill:speckit-tdd-run`