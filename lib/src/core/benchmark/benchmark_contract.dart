/// The benchmark contract library for the Zuraffa ecosystem (feature 015).
///
/// [BenchmarkContract] is the interface every benchmark scenario implements:
/// a lifecycle of `setup → run → collectMetrics → teardown` plus the metadata
/// the registry and runner need (id, name, version, config schema,
/// thresholds) — FR-001.
///
/// [BenchmarkScenario] is an optional convenience base class implementing the
/// contract with safe defaults, so a new plugin can contribute a scenario in
/// a handful of lines (SC-001). Scenarios depend ONLY on this contract
/// surface, never on a specific plugin implementation (FR-015): the contract
/// lives in `lib/src/core/benchmark/` and is exported from
/// `package:zuraffa/zuraffa.dart`.
///
/// Pure-Dart (no Flutter dependency) per spec 014-pure-dart-core-split.
library;

import 'benchmark_result.dart';

export 'benchmark_result.dart' show ThresholdSeverity;

/// Comparison operators supported by metric thresholds (FR-005).
enum ThresholdOperator {
  /// Actual must be strictly less than the threshold.
  lt,

  /// Actual must be less than or equal to the threshold.
  lte,

  /// Actual must be strictly greater than the threshold.
  gt,

  /// Actual must be greater than or equal to the threshold.
  gte;

  /// Parses an operator name, throwing [FormatException] for unknown values.
  static ThresholdOperator fromName(String name) {
    for (final value in ThresholdOperator.values) {
      if (value.name == name) return value;
    }
    throw FormatException('Unknown threshold operator: $name');
  }

  /// The symbolic form used in human-readable expectations.
  String get symbol => switch (this) {
        ThresholdOperator.lt => '<',
        ThresholdOperator.lte => '<=',
        ThresholdOperator.gt => '>',
        ThresholdOperator.gte => '>=',
      };
}

/// Whether a threshold violation fails the benchmark or only warns (FR-005).

/// Pass/fail criteria for a single metric (FR-005).
class ThresholdConfig {
  /// Name of the metric this threshold guards (e.g. `latency_p99`).
  final String metric;

  /// Comparison applied between the measured value and [value].
  final ThresholdOperator operator;

  /// The threshold value.
  final num value;

  /// Severity recorded when the threshold is violated.
  final ThresholdSeverity severity;

  /// Creates a threshold configuration.
  const ThresholdConfig({
    required this.metric,
    required this.operator,
    required this.value,
    this.severity = ThresholdSeverity.error,
  });

  /// Deserializes a threshold from its JSON representation, rejecting
  /// unknown operators and severities with a [FormatException].
  factory ThresholdConfig.fromJson(Map<String, dynamic> json) {
    final metric = json['metric'] as String?;
    if (metric == null || metric.isEmpty) {
      throw const FormatException('Threshold metric must be non-empty');
    }
    return ThresholdConfig(
      metric: metric,
      operator: ThresholdOperator.fromName(json['operator'] as String),
      value: json['value'] as num,
      severity: ThresholdSeverity.fromName(
        (json['severity'] as String?) ?? 'error',
      ),
    );
  }

  /// Serializes the threshold to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'metric': metric,
        'operator': operator.name,
        'value': value,
        'severity': severity.name,
      };

  /// Human-readable expectation, e.g. `latency_p99 <= 40`.
  String get expectation => '$metric ${operator.symbol} $value';

  /// Returns `true` when [actual] violates this threshold.
  bool isViolatedBy(num actual) => switch (operator) {
        ThresholdOperator.lt => actual >= value,
        ThresholdOperator.lte => actual > value,
        ThresholdOperator.gt => actual <= value,
        ThresholdOperator.gte => actual < value,
      };
}

/// The contract between benchmark scenarios and the benchmark framework
/// (FR-001, FR-015).
///
/// Lifecycle: [setup] → [run] → [collectMetrics] → [teardown].
///
/// Error contract (data-model.md): if [setup] throws, [run] and [teardown]
/// are skipped; if [run] throws, [teardown] is still invoked. Either way the
/// runner captures the error as a result with status `error`.
abstract class BenchmarkContract {
  /// Creates a benchmark contract.
  const BenchmarkContract();

  /// Unique, kebab-case identifier for this scenario.
  String get id;

  /// Human-readable name.
  String get name;

  /// Semantic version of the scenario.
  String get version;

  /// What this benchmark measures.
  String get description => '';

  /// JSON Schema (subset) describing the scenario's configuration.
  Map<String, dynamic> get configSchema => const {};

  /// Pass/fail thresholds keyed by metric name.
  Map<String, ThresholdConfig> get thresholds => const {};

  /// Categorization tags.
  List<String> get tags => const [];

  /// Called once before benchmark execution for setup.
  Future<void> setup() async {}

  /// Executes the benchmark with the given configuration and returns a
  /// partial result carrying the scenario's own metrics. Standard metrics
  /// (latency percentiles, throughput, memory, CPU) are layered on by the
  /// runner's measurement stage.
  Future<BenchmarkResult> run(Map<String, dynamic> config);

  /// Called after benchmark execution for cleanup.
  Future<void> teardown() async {}

  /// Returns custom metrics beyond the standard set, collected by the runner
  /// after [run] completes.
  Future<Map<String, num>> collectMetrics() async => const {};
}

/// Convenience base class for scenarios (SC-001 ergonomics).
///
/// Subclasses implement [id], [name], [version] and [run]; everything else
/// has working defaults. The base performs no behavior of its own — it only
/// removes boilerplate, keeping the contract itself implementable from
/// scratch by plugins that prefer the pure interface (FR-015).
abstract class BenchmarkScenario extends BenchmarkContract {
  /// Creates a scenario base.
  const BenchmarkScenario();
}

/// Metadata validation shared by the registry and the dry-run path (AC-2).
///
/// Validation is deliberately standalone and synchronous so it can gate
/// registration before any execution happens.
abstract final class ScenarioValidation {
  static final RegExp _kebabCase = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
  static final RegExp _semver = RegExp(
    r'^\d+\.\d+\.\d+(-[a-zA-Z0-9][a-zA-Z0-9._-]*)?$',
  );

  /// Validates a scenario id (non-empty kebab-case).
  static List<String> validateId(String id) {
    if (id.isEmpty || !_kebabCase.hasMatch(id)) {
      return [
        "scenario id must be non-empty kebab-case (got '$id')",
      ];
    }
    return const [];
  }

  /// Validates a semver version string.
  static List<String> validateVersion(String version) {
    if (!_semver.hasMatch(version)) {
      return [
        "scenario version must be semver X.Y.Z with optional prerelease "
            "(got '$version')",
      ];
    }
    return const [];
  }

  /// Validates all scenario metadata, returning every problem found.
  static List<String> validate(BenchmarkContract scenario) {
    return [
      ...validateId(scenario.id),
      ...validateVersion(scenario.version),
      if (scenario.name.trim().isEmpty) 'scenario name must be non-empty',
      for (final entry in scenario.thresholds.entries)
        if (entry.value.metric.isEmpty)
          "threshold for '${entry.key}' has an empty metric name",
    ];
  }
}
