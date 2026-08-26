# Data Model: Internal Benchmark Plugin

## Entities

### BenchmarkScenario

A named, versioned benchmark definition with configuration schema, thresholds, and execution logic.

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| id | String | Unique identifier (kebab-case) | Required, immutable, globally unique |
| name | String | Human-readable name | Required |
| version | String | Semantic version | Required, semver format |
| description | String | What this benchmark measures | Optional |
| configSchema | Map<String, dynamic> | JSON Schema for scenario configuration | Optional, defaults to empty object |
| thresholds | Map<String, ThresholdConfig> | Pass/fail thresholds per metric | Optional |
| tags | List<String> | Categorization tags | Optional |
| author | String | Plugin/author identifier | Optional |
| createdAt | DateTime | Creation timestamp | Auto-set |
| updatedAt | DateTime | Last modification timestamp | Auto-updated |

**Relationships**: 
- Has many `ThresholdConfig` (via thresholds map)
- Belongs to a plugin via `author` tag
- Produces `BenchmarkResult` when executed

---

### ThresholdConfig

Pass/fail criteria for a specific metric.

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| metric | String | Metric name (see StandardMetrics) | Required |
| operator | String | Comparison operator | Required, enum: lt, lte, gt, gte |
| value | num | Threshold value | Required |
| severity | String | Failure severity | Required, enum: error, warn |

**Standard Metrics** (built-in):
- `latency_p50` - Median latency (ms)
- `latency_p95` - 95th percentile latency (ms)
- `latency_p99` - 99th percentile latency (ms)
- `throughput_ops_sec` - Operations per second
- `memory_mb` - Peak memory usage (MB)
- `cpu_percent` - CPU utilization (%)

Custom metrics can use any string name (validated at runtime).

---

### BenchmarkContract (Interface)

The interface that all benchmark scenarios implement.

```dart
abstract class BenchmarkContract {
  /// Called once before benchmark execution for setup
  Future<void> setup();
  
  /// Executes the benchmark with given configuration
  Future<BenchmarkResult> run(Map<String, dynamic> config);
  
  /// Called after benchmark execution for cleanup
  Future<void> teardown();
  
  /// Returns custom metrics (called by runner after run)
  Future<Map<String, num>> collectMetrics();
  
  /// Unique identifier for this scenario
  String get id;
  
  /// Human-readable name
  String get name;
  
  /// Semantic version
  String get version;
  
  /// JSON Schema for configuration validation
  Map<String, dynamic> get configSchema;
  
  /// Threshold configurations
  Map<String, ThresholdConfig> get thresholds;
}
```

**Lifecycle**: `setup()` → `run(config)` → `collectMetrics()` → `teardown()`

**Error Handling**: 
- If `setup()` throws, `run()` and `teardown()` are skipped
- If `run()` throws, `teardown()` is still called
- Errors are captured in `BenchmarkResult.status = "error"`

---

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

**Behavior**:
- Duplicate ID registration returns error
- Thread-safe (async/await)
- Persists across hot reload in development

---

### BenchmarkRunner

Orchestrates execution of benchmarks, collects metrics, evaluates thresholds.

```dart
abstract class BenchmarkRunner {
  /// Run a single benchmark scenario
  Future<BenchmarkResult> runSingle(BenchmarkScenario scenario, {Map<String, dynamic> config = const {}});
  
  /// Run multiple scenarios in sequence
  Future<BenchmarkSuiteResult> run(List<BenchmarkScenario> scenarios, {Map<String, dynamic> globalConfig = const {}});
  
  /// Run scenarios matching tags
  Future<BenchmarkSuiteResult> runByTags(List<String> tags, {Map<String, dynamic> globalConfig = const {}});
  
  /// Validate configuration without executing (dry-run)
  Future<ValidationResult> dryRun(BenchmarkScenario scenario, Map<String, dynamic> config);
}
```

**Execution Model**:
- Each scenario runs in a separate isolate for isolation
- Global config merged with scenario-specific config
- Thresholds evaluated after each scenario
- Results aggregated into `BenchmarkSuiteResult`

---

### MetricCollector (Interface)

Extensible interface for capturing custom metrics during benchmark execution.

```dart
abstract class MetricCollector {
  /// Called once before suite starts
  Future<void> initialize();
  
  /// Called before each benchmark scenario
  Future<void> beforeBenchmark(MetricContext context);
  
  /// Called after each benchmark scenario
  Future<void> afterBenchmark(MetricContext context);
  
  /// Called once after suite ends
  Future<void> finalize();
  
  /// Unique identifier for this collector
  String get id;
  
  /// Human-readable name
  String get name;
}
```

**MetricContext**:
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

**Built-in Collectors**:
- `StandardMetricCollector` - Collects latency, throughput, memory, CPU
- `MemoryMetricCollector` - Detailed memory profiling (GC pauses, allocations)
- `CpuMetricCollector` - CPU profiling (time per isolate, contention)

---

### BenchmarkResult

Structured output containing metrics, pass/fail status, and metadata.

| Field | Type | Description |
|-------|------|-------------|
| scenarioId | String | ID of executed scenario |
| scenarioName | String | Name of scenario |
| scenarioVersion | String | Version of scenario |
| status | String | `passed`, `failed`, `error`, `skipped` |
| metrics | Map<String, num> | All collected metrics |
| thresholdViolations | List<ThresholdViolation> | Thresholds that were exceeded |
| duration | Duration | Wall-clock execution time |
| timestamp | DateTime | When the benchmark ran |
| gitCommit | String | Current git commit SHA |
| metadata | Map<String, dynamic> | Additional context (isolate info, config used, etc.) |

---

### ThresholdViolation

A threshold that was exceeded during benchmark execution.

| Field | Type | Description |
|-------|------|-------------|
| metric | String | Name of the metric |
| expected | String | Expected condition (e.g., "latency_p99 <= 100") |
| actual | num | Actual measured value |
| severity | String | `error` or `warn` |
| message | String | Human-readable description |

---

### BenchmarkSuiteResult

Aggregate result of running multiple benchmarks.

| Field | Type | Description |
|-------|------|-------------|
| results | List<BenchmarkResult> | Individual scenario results |
| overallStatus | String | `passed`, `failed`, `error` |
| totalDuration | Duration | Sum of all scenario durations |
| startedAt | DateTime | Suite start time |
| completedAt | DateTime | Suite completion time |
| summary | Map<String, dynamic> | Aggregate statistics (pass count, fail count, etc.) |

---

### BaselineStore

Persistent storage for historical benchmark results for trend comparison.

```dart
abstract class BaselineStore {
  /// Save a baseline for a scenario
  Future<void> save(Baseline baseline);
  
  /// Load the latest baseline for a scenario
  Future<Baseline?> load(String scenarioId);
  
  /// Load a specific baseline by label
  Future<Baseline?> loadByLabel(String scenarioId, String label);
  
  /// List all baselines for a scenario
  Future<List<Baseline>> list(String scenarioId);
  
  /// List all baselines across all scenarios
  Future<List<Baseline>> listAll();
  
  /// Delete a baseline
  Future<void> delete(String scenarioId, String label);
}
```

---

### Baseline

Historical benchmark result for comparison.

| Field | Type | Description |
|-------|------|-------------|
| scenarioId | String | Scenario identifier |
| scenarioVersion | String | Scenario version at baseline time |
| label | String | Human-readable label (e.g., "v1.0-release", "weekly-2026-08-26") |
| metrics | Map<String, num> | Baseline metric values |
| timestamp | DateTime | When baseline was created |
| gitCommit | String | Git commit at baseline time |
| gitBranch | String | Git branch at baseline time |
| environment | Map<String, String> | Environment info (OS, Dart version, etc.) |

---

### BenchmarkComparison

Result of comparing current results against a baseline.

| Field | Type | Description |
|-------|------|-------------|
| scenarioId | String | Scenario identifier |
| baseline | Baseline | The baseline used for comparison |
| current | BenchmarkResult | Current execution result |
| changes | Map<String, MetricChange> | Per-metric changes |
| overallStatus | String | `improved`, `regressed`, `stable` |

---

### MetricChange

Change in a single metric between baseline and current.

| Field | Type | Description |
|-------|------|-------------|
| metric | String | Metric name |
| baselineValue | num | Baseline value |
| currentValue | num | Current value |
| absoluteChange | num | current - baseline |
| percentChange | num | (current - baseline) / baseline * 100 |
| direction | String | `improved`, `regressed`, `stable` |
| isRegression | bool | True if regressed beyond tolerance |
| tolerance | num | Configured tolerance percentage |

---

## Validation Rules

### BenchmarkScenario Validation
- `id` must be non-empty, kebab-case, globally unique
- `version` must be valid semver
- `configSchema` must be valid JSON Schema (if provided)
- Each threshold metric must be known or allowed custom
- Threshold operator must be valid enum
- Threshold severity must be `error` or `warn`

### BenchmarkResult Validation
- `status` must be one of: `passed`, `failed`, `error`, `skipped`
- `metrics` must contain at least standard metrics if status != `skipped`
- `thresholdViolations` only present when status = `failed` or `error`
- `duration` must be non-negative

### Baseline Validation
- `scenarioVersion` must match scenario's current version (warn if not)
- `metrics` must contain same keys as current result schema
- `environment` must include: OS, Dart version, architecture

---

## State Transitions

### BenchmarkScenario
```
[Created] → [Registered] → [Validated] → [Executable]
                ↓              ↓
           [Unregistered]  [Failed Validation]
```

### BenchmarkExecution
```
[Pending] → [Setup] → [Running] → [Collecting] → [Teardown] → [Completed]
                          ↓              ↓
                      [Error]        [Timeout]
                          ↓              ↓
                       [Failed]      [Failed]
```

### Baseline
```
[Created] → [Saved] → [Compared] → [Archived/Deleted]
```

---

## Serialization

All entities use JSON serialization with the following conventions:
- Dates: ISO 8601 strings (e.g., "2026-08-26T14:30:00Z")
- Durations: Milliseconds as integer (e.g., 1500 for 1.5s)
- Enums: String values (e.g., "passed", "error")
- Maps: Standard JSON objects
- Lists: Standard JSON arrays

Custom `toJson()` / `fromJson()` methods on each entity class.