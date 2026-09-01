# Benchmark Contract Interface

This document defines the contract interfaces for the Internal Benchmark Plugin. These interfaces form the public API that benchmark scenarios and metric collectors must implement, and that the benchmark runner uses to execute benchmarks.

## Core Contracts

### BenchmarkContract

The primary interface that all benchmark scenarios must implement.

```dart
abstract class BenchmarkContract {
  /// Unique identifier for this scenario (kebab-case, globally unique)
  String get id;

  /// Human-readable name
  String get name;

  /// Semantic version of this scenario
  String get version;

  /// Brief description of what this benchmark measures
  String get description;

  /// JSON Schema for validating scenario configuration
  Map<String, dynamic> get configSchema;

  /// Threshold configurations for pass/fail evaluation
  Map<String, ThresholdConfig> get thresholds;

  /// Categorization tags for discovery/filtering
  List<String> get tags;

  /// Called once before benchmark execution for setup
  Future<void> setup();

  /// Executes the benchmark with given configuration
  /// Returns structured result with metrics
  Future<BenchmarkResult> run(Map<String, dynamic> config);

  /// Called after benchmark execution for cleanup
  Future<void> teardown();

  /// Returns custom metrics (called by runner after run)
  Future<Map<String, num>> collectMetrics();
}
```

### ThresholdConfig

Pass/fail criteria for a specific metric.

```dart
class ThresholdConfig {
  final String metric;           // Metric name (e.g., "latency_p99")
  final String operator;         // Comparison: lt, lte, gt, gte
  final num value;               // Threshold value
  final String severity;         // error | warn
}
```

### MetricCollector

Extensible interface for capturing custom metrics during benchmark execution.

```dart
abstract class MetricCollector {
  /// Unique identifier for this collector
  String get id;

  /// Human-readable name
  String get name;

  /// Called once before suite starts
  Future<void> initialize();

  /// Called before each benchmark scenario
  Future<void> beforeBenchmark(MetricContext context);

  /// Called after each benchmark scenario
  Future<void> afterBenchmark(MetricContext context);

  /// Called once after suite ends
  Future<void> finalize();
}
```

### MetricContext

Context passed to metric collectors at each lifecycle point.

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

## Registry & Runner Contracts

### BenchmarkRegistry

Central registry for discovering and managing registered scenarios.

```dart
abstract class BenchmarkRegistry {
  /// Register a new benchmark scenario
  Future<Result<void>> register(BenchmarkScenario scenario);

  /// Unregister a scenario by ID
  Future<Result<void>> unregister(String id);

  /// Get all registered scenarios
  Future<List<BenchmarkScenario>> getAll();

  /// Get a specific scenario by ID
  Future<BenchmarkScenario?> get(String id);

  /// Get scenarios matching tags
  Future<List<BenchmarkScenario>> getByTags(List<String> tags);

  /// Check if a scenario is registered
  Future<bool> has(String id);

  /// Clear all scenarios (for testing)
  Future<void> clear();
}
```

### BenchmarkRunner

Orchestrates execution of benchmarks, collects metrics, evaluates thresholds.

```dart
abstract class BenchmarkRunner {
  /// Run a single benchmark scenario
  Future<BenchmarkResult> runSingle(
    BenchmarkScenario scenario, {
    Map<String, dynamic> config = const {},
  });

  /// Run multiple scenarios in sequence
  Future<BenchmarkSuiteResult> run(
    List<BenchmarkScenario> scenarios, {
    Map<String, dynamic> globalConfig = const {},
  });

  /// Run scenarios matching tags
  Future<BenchmarkSuiteResult> runByTags(
    List<String> tags, {
    Map<String, dynamic> globalConfig = const {},
  });

  /// Validate configuration without executing (dry-run)
  Future<ValidationResult> dryRun(
    BenchmarkScenario scenario,
    Map<String, dynamic> config,
  );
}
```

## Result Contracts

### BenchmarkResult

Structured output containing metrics, pass/fail status, and metadata.

```dart
class BenchmarkResult {
  final String scenarioId;
  final String scenarioName;
  final String scenarioVersion;
  final String status;           // passed, failed, error, skipped
  final Map<String, num> metrics;
  final List<ThresholdViolation> thresholdViolations;
  final Duration duration;
  final DateTime timestamp;
  final String gitCommit;
  final Map<String, dynamic> metadata;
}
```

### ThresholdViolation

A threshold that was exceeded during benchmark execution.

```dart
class ThresholdViolation {
  final String metric;
  final String expected;         // e.g., "latency_p99 <= 100"
  final num actual;
  final String severity;         // error | warn
  final String message;
}
```

### BenchmarkSuiteResult

Aggregate result of running multiple benchmarks.

```dart
class BenchmarkSuiteResult {
  final List<BenchmarkResult> results;
  final String overallStatus;    // passed, failed, error
  final Duration totalDuration;
  final DateTime startedAt;
  final DateTime completedAt;
  final Map<String, dynamic> summary;
}
```

## Baseline Contracts

### BaselineStore

Persistent storage for historical benchmark results.

```dart
abstract class BaselineStore {
  Future<void> save(Baseline baseline);
  Future<Baseline?> load(String scenarioId);
  Future<Baseline?> loadByLabel(String scenarioId, String label);
  Future<List<Baseline>> list(String scenarioId);
  Future<List<Baseline>> listAll();
  Future<void> delete(String scenarioId, String label);
}
```

### Baseline

Historical benchmark result for comparison.

```dart
class Baseline {
  final String scenarioId;
  final String scenarioVersion;
  final String label;
  final Map<String, num> metrics;
  final DateTime timestamp;
  final String gitCommit;
  final String gitBranch;
  final Map<String, String> environment;
}
```

### BenchmarkComparison

Result of comparing current results against a baseline.

```dart
class BenchmarkComparison {
  final String scenarioId;
  final Baseline baseline;
  final BenchmarkResult current;
  final Map<String, MetricChange> changes;
  final String overallStatus;    // improved, regressed, stable
}
```

### MetricChange

Change in a single metric between baseline and current.

```dart
class MetricChange {
  final String metric;
  final num baselineValue;
  final num currentValue;
  final num absoluteChange;
  final num percentChange;
  final String direction;        // improved, regressed, stable
  final bool isRegression;
  final num tolerance;
}
```

## External Plugin Integration

### BenchmarkScenarioProvider

Contract for external plugins to provide benchmark scenarios.

```dart
abstract class BenchmarkScenarioProvider {
  /// Returns all benchmark scenarios this plugin provides
  List<BenchmarkScenario> provideScenarios();
}
```

Plugins implement this interface and register it as a capability with the Zuraffa plugin system. The benchmark plugin discovers all `BenchmarkScenarioProvider` capabilities at startup and registers their scenarios automatically.

---

## Contract Versioning

- Contract interfaces follow semantic versioning
- Breaking changes require MAJOR version bump
- New optional methods can be added in MINOR versions
- Implementations should use `package:meta` `@required` and `@optional` annotations where applicable