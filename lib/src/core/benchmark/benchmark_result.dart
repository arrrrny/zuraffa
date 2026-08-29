/// Value types for the Zuraffa benchmark framework (feature 015).
///
/// [BenchmarkResult] is the structured outcome of a single benchmark scenario
/// execution: standardized metrics, threshold violations, and run metadata.
/// [BenchmarkSuiteResult] aggregates per-benchmark results into an overall
/// pass/fail verdict with summary statistics (FR-004, FR-008).
///
/// Pure-Dart (no Flutter dependency) per spec 014-pure-dart-core-split.
library;

/// Status of a single benchmark execution.
enum BenchmarkStatus {
  /// All threshold gates satisfied.
  passed,

  /// At least one error-severity threshold was violated.
  failed,

  /// The scenario itself threw, timed out, or could not complete.
  error,

  /// The scenario was excluded from execution (filter, dry-run, dependency).
  skipped;

  /// Parses a status name, throwing [FormatException] for unknown values.
  static BenchmarkStatus fromName(String name) {
    for (final value in BenchmarkStatus.values) {
      if (value.name == name) return value;
    }
    throw FormatException('Unknown benchmark status: $name');
  }
}

/// Severity of a threshold violation (FR-005).
enum ThresholdSeverity {
  /// Fails the benchmark / build.
  error,

  /// Logged only; the benchmark still passes.
  warn;

  /// Parses a severity name, throwing [FormatException] for unknown values.
  static ThresholdSeverity fromName(String name) {
    for (final value in ThresholdSeverity.values) {
      if (value.name == name) return value;
    }
    throw FormatException('Unknown threshold severity: $name');
  }
}

/// A threshold that was exceeded during benchmark execution (FR-005).
class ThresholdViolation {
  /// Name of the metric that violated its threshold.
  final String metric;

  /// Human-readable expectation, e.g. `latency_p99 lte 40`.
  final String expected;

  /// The value actually measured.
  final num actual;

  /// Whether this violation fails the benchmark (`error`) or only warns.
  final ThresholdSeverity severity;

  /// Human-readable description of the violation.
  final String message;

  /// Creates a violation record.
  const ThresholdViolation({
    required this.metric,
    required this.expected,
    required this.actual,
    required this.severity,
    required this.message,
  });

  /// Deserializes a violation from its JSON representation.
  factory ThresholdViolation.fromJson(Map<String, dynamic> json) {
    return ThresholdViolation(
      metric: json['metric'] as String,
      expected: json['expected'] as String,
      actual: json['actual'] as num,
      severity: ThresholdSeverity.fromName(json['severity'] as String),
      message: json['message'] as String,
    );
  }

  /// Serializes the violation to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'metric': metric,
    'expected': expected,
    'actual': actual,
    'severity': severity.name,
    'message': message,
  };

  @override
  bool operator ==(Object other) =>
      other is ThresholdViolation &&
      other.metric == metric &&
      other.expected == expected &&
      other.actual == actual &&
      other.severity == severity &&
      other.message == message;

  @override
  int get hashCode => Object.hash(metric, expected, actual, severity, message);

  @override
  String toString() => '$message ($expected, actual: $actual)';
}

/// Structured output of one benchmark scenario execution (FR-004).
class BenchmarkResult {
  /// ID of the executed scenario.
  final String scenarioId;

  /// Human-readable scenario name.
  final String scenarioName;

  /// Version of the scenario at execution time.
  final String scenarioVersion;

  /// Execution outcome.
  final BenchmarkStatus status;

  /// All collected metrics (standard + scenario + collector contributed).
  final Map<String, num> metrics;

  /// Thresholds violated by this run (empty when status is `passed`).
  final List<ThresholdViolation> thresholdViolations;

  /// Wall-clock execution time of the measured section.
  final Duration duration;

  /// When the benchmark ran.
  final DateTime timestamp;

  /// Git commit the benchmark ran against ('unknown' when not a git repo).
  final String gitCommit;

  /// Additional context (config used, iteration count, isolation info...).
  final Map<String, dynamic> metadata;

  /// Creates a benchmark result.
  const BenchmarkResult({
    required this.scenarioId,
    required this.scenarioName,
    required this.scenarioVersion,
    required this.status,
    required this.metrics,
    required this.thresholdViolations,
    required this.duration,
    required this.timestamp,
    this.gitCommit = 'unknown',
    this.metadata = const {},
  });

  /// Deserializes a result from its JSON representation.
  factory BenchmarkResult.fromJson(Map<String, dynamic> json) {
    return BenchmarkResult(
      scenarioId: json['scenarioId'] as String,
      scenarioName: json['scenarioName'] as String,
      scenarioVersion: json['scenarioVersion'] as String,
      status: BenchmarkStatus.fromName(json['status'] as String),
      metrics: (json['metrics'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as num),
      ),
      thresholdViolations: (json['thresholdViolations'] as List<dynamic>)
          .map((v) => ThresholdViolation.fromJson(v as Map<String, dynamic>))
          .toList(),
      duration: Duration(milliseconds: json['durationMs'] as int),
      timestamp: DateTime.parse(json['timestamp'] as String),
      gitCommit: (json['gitCommit'] as String?) ?? 'unknown',
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }

  /// Serializes the result to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'scenarioId': scenarioId,
    'scenarioName': scenarioName,
    'scenarioVersion': scenarioVersion,
    'status': status.name,
    'metrics': metrics,
    'thresholdViolations': thresholdViolations.map((v) => v.toJson()).toList(),
    'durationMs': duration.inMilliseconds,
    'timestamp': timestamp.toIso8601String(),
    'gitCommit': gitCommit,
    'metadata': metadata,
  };

  /// Returns a copy with the provided fields replaced.
  BenchmarkResult copyWith({
    BenchmarkStatus? status,
    Map<String, num>? metrics,
    List<ThresholdViolation>? thresholdViolations,
    Duration? duration,
    Map<String, dynamic>? metadata,
    String? gitCommit,
  }) {
    return BenchmarkResult(
      scenarioId: scenarioId,
      scenarioName: scenarioName,
      scenarioVersion: scenarioVersion,
      status: status ?? this.status,
      metrics: metrics ?? this.metrics,
      thresholdViolations: thresholdViolations ?? this.thresholdViolations,
      duration: duration ?? this.duration,
      timestamp: timestamp,
      gitCommit: gitCommit ?? this.gitCommit,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Aggregate outcome of a benchmark suite run (FR-008).
class BenchmarkSuiteResult {
  /// Per-benchmark results, in execution order.
  final List<BenchmarkResult> results;

  /// Sum of all scenario durations.
  final Duration totalDuration;

  /// When the suite started.
  final DateTime startedAt;

  /// When the suite completed.
  final DateTime completedAt;

  /// Creates a suite result.
  const BenchmarkSuiteResult({
    required this.results,
    required this.totalDuration,
    required this.startedAt,
    required this.completedAt,
  });

  /// Overall verdict: `error` if any scenario errored, `failed` if any
  /// failed, otherwise `passed`. `skipped` scenarios never fail a suite.
  BenchmarkStatus get overallStatus {
    var sawFailed = false;
    for (final result in results) {
      if (result.status == BenchmarkStatus.error) {
        return BenchmarkStatus.error;
      }
      if (result.status == BenchmarkStatus.failed) sawFailed = true;
    }
    return sawFailed ? BenchmarkStatus.failed : BenchmarkStatus.passed;
  }

  /// Aggregate statistics: per-status counts plus total duration.
  Map<String, dynamic> get summary {
    final counts = <BenchmarkStatus, int>{
      for (final status in BenchmarkStatus.values) status: 0,
    };
    for (final result in results) {
      counts[result.status] = (counts[result.status] ?? 0) + 1;
    }
    return {
      'total': results.length,
      'passed': counts[BenchmarkStatus.passed] ?? 0,
      'failed': counts[BenchmarkStatus.failed] ?? 0,
      'error': counts[BenchmarkStatus.error] ?? 0,
      'skipped': counts[BenchmarkStatus.skipped] ?? 0,
      'totalDurationMs': totalDuration.inMilliseconds,
    };
  }

  /// Deserializes a suite result from its JSON representation.
  factory BenchmarkSuiteResult.fromJson(Map<String, dynamic> json) {
    return BenchmarkSuiteResult(
      results: (json['results'] as List<dynamic>)
          .map((v) => BenchmarkResult.fromJson(v as Map<String, dynamic>))
          .toList(),
      totalDuration: Duration(milliseconds: json['totalDurationMs'] as int),
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: DateTime.parse(json['completedAt'] as String),
    );
  }

  /// Serializes the suite result to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'results': results.map((r) => r.toJson()).toList(),
    'overallStatus': overallStatus.name,
    'totalDurationMs': totalDuration.inMilliseconds,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt.toIso8601String(),
    'summary': summary,
  };
}
