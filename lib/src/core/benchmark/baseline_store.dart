/// Historical baseline storage and regression comparison (FR-009, FR-010).
///
/// [Baseline] captures a scenario's metrics at a point in time with git and
/// environment context. [BaselineStore] persists baselines — the built-in
/// [JsonBaselineStore] writes one human-readable JSON file per scenario
/// under `benchmarks/baselines/` (research.md decision), and the interface
/// leaves the seam open for remote stores.
///
/// [compareBaselines] turns a baseline plus current metrics into per-metric
/// [MetricChange]s with direction flags and configurable tolerance (AC-10,
/// AC-11), powering regression detection (FR-010).
///
/// Pure-Dart (no Flutter dependency) per spec 014-pure-dart-core-split.
library;

import 'dart:convert';
import 'dart:io';

import 'standard_metrics.dart';

/// A historical benchmark result kept for comparison (FR-009).
class Baseline {
  /// Scenario the baseline belongs to.
  final String scenarioId;

  /// Scenario version at baseline time.
  final String scenarioVersion;

  /// Human-readable label (e.g. `v1.0-release`, `weekly-2026-08-26`).
  final String label;

  /// Baseline metric values.
  final Map<String, num> metrics;

  /// When the baseline was created.
  final DateTime timestamp;

  /// Git commit at baseline time.
  final String gitCommit;

  /// Git branch at baseline time.
  final String gitBranch;

  /// Environment info (OS, Dart version, architecture...).
  final Map<String, String> environment;

  /// Creates a baseline.
  const Baseline({
    required this.scenarioId,
    required this.scenarioVersion,
    required this.label,
    required this.metrics,
    required this.timestamp,
    this.gitCommit = 'unknown',
    this.gitBranch = 'unknown',
    this.environment = const {},
  });

  /// Deserializes a baseline from its JSON representation.
  factory Baseline.fromJson(Map<String, dynamic> json) {
    return Baseline(
      scenarioId: json['scenarioId'] as String,
      scenarioVersion: json['scenarioVersion'] as String,
      label: json['label'] as String,
      metrics: (json['metrics'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as num),
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      gitCommit: (json['gitCommit'] as String?) ?? 'unknown',
      gitBranch: (json['gitBranch'] as String?) ?? 'unknown',
      environment:
          (json['environment'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as String),
          ) ??
          const {},
    );
  }

  /// Serializes the baseline to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'scenarioId': scenarioId,
    'scenarioVersion': scenarioVersion,
    'label': label,
    'metrics': metrics,
    'timestamp': timestamp.toIso8601String(),
    'gitCommit': gitCommit,
    'gitBranch': gitBranch,
    'environment': environment,
  };
}

/// Persistent storage for historical benchmark results (FR-009).
abstract class BaselineStore {
  /// Saves [baseline] (upserts by scenario id + label).
  Future<void> save(Baseline baseline);

  /// Loads the newest baseline for [scenarioId], or `null`.
  Future<Baseline?> load(String scenarioId);

  /// Loads the baseline for [scenarioId] saved under [label], or `null`.
  Future<Baseline?> loadByLabel(String scenarioId, String label);

  /// Lists all baselines for [scenarioId], oldest first.
  Future<List<Baseline>> list(String scenarioId);

  /// Lists every baseline across all scenarios.
  Future<List<Baseline>> listAll();

  /// Deletes the baseline identified by [scenarioId] and [label].
  Future<void> delete(String scenarioId, String label);
}

/// Filesystem-backed [BaselineStore] using one JSON file per scenario
/// (research.md decision: human-readable, git-friendly).
class JsonBaselineStore implements BaselineStore {
  /// Creates a store rooted at [directory] (default `benchmarks/baselines`).
  JsonBaselineStore({this.directory = 'benchmarks/baselines'});

  /// Directory holding the per-scenario JSON files.
  final String directory;

  File _fileFor(String scenarioId) =>
      File('$directory/${_sanitize(scenarioId)}.json');

  static String _sanitize(String scenarioId) =>
      scenarioId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  Map<String, List<Map<String, dynamic>>> _readIndex() {
    final dir = Directory(directory);
    if (!dir.existsSync()) return {};
    final index = <String, List<Map<String, dynamic>>>{};
    for (final entity in dir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final json =
            jsonDecode(entity.readAsStringSync()) as Map<String, dynamic>;
        if (json['scenarioId'] is! String) continue;
        final scenarioId = json['scenarioId'] as String;
        final list = (json['baselines'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        // Migrate legacy single-baseline files.
        if (list.isEmpty && json['label'] is String) {
          list.add(json);
        }
        index[scenarioId] = list;
      } catch (_) {
        // Unreadable files are skipped, not fatal.
      }
    }
    return index;
  }

  Future<void> _write(String scenarioId, List<Baseline> baselines) async {
    final dir = Directory(directory);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final payload = jsonEncode({
      'scenarioId': scenarioId,
      'baselines': baselines.map((b) => b.toJson()).toList(),
    });
    await _fileFor(scenarioId).writeAsString('$payload\n');
  }

  @override
  Future<void> save(Baseline baseline) async {
    final index = _readIndex();
    final existing = index[baseline.scenarioId] ?? [];
    final baselines =
        existing
            .map(Baseline.fromJson)
            .where((b) => b.label != baseline.label)
            .toList()
          ..add(baseline)
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    await _write(baseline.scenarioId, baselines);
  }

  @override
  Future<Baseline?> load(String scenarioId) async {
    final baselines = await list(scenarioId);
    return baselines.isEmpty ? null : baselines.last;
  }

  @override
  Future<Baseline?> loadByLabel(String scenarioId, String label) async {
    final baselines = await list(scenarioId);
    for (final baseline in baselines) {
      if (baseline.label == label) return baseline;
    }
    return null;
  }

  @override
  Future<List<Baseline>> list(String scenarioId) async {
    final index = _readIndex();
    final raw = index[scenarioId] ?? const [];
    return raw.map(Baseline.fromJson).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  @override
  Future<List<Baseline>> listAll() async {
    final index = _readIndex();
    final all = <Baseline>[];
    for (final raw in index.values) {
      all.addAll(raw.map(Baseline.fromJson));
    }
    all.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return all;
  }

  @override
  Future<void> delete(String scenarioId, String label) async {
    final index = _readIndex();
    final raw = index[scenarioId] ?? const [];
    final remaining = raw
        .map(Baseline.fromJson)
        .where((b) => b.label != label)
        .toList();
    await _write(scenarioId, remaining);
  }
}

/// Direction of a metric change between baseline and current run.
enum MetricDirection { improved, regressed, stable }

/// Overall verdict of a baseline comparison.
enum ComparisonStatus { improved, regressed, stable }

/// The change of a single metric between baseline and current (FR-010).
class MetricChange {
  /// Metric name.
  final String metric;

  /// Baseline value.
  final num baselineValue;

  /// Current value.
  final num currentValue;

  /// `current - baseline`.
  final num absoluteChange;

  /// `(current - baseline) / baseline * 100`.
  final num percentChange;

  /// Whether the change is an improvement, regression, or within tolerance.
  final MetricDirection direction;

  /// Whether the regression exceeded the configured tolerance (AC-11).
  final bool isRegression;

  /// Severity of the regression: `warn` just beyond tolerance, `error`
  /// beyond twice the tolerance. `null` when not a regression.
  final String? severity;

  /// The tolerance percentage that was applied.
  final num tolerance;

  /// Creates a metric change record.
  const MetricChange({
    required this.metric,
    required this.baselineValue,
    required this.currentValue,
    required this.absoluteChange,
    required this.percentChange,
    required this.direction,
    required this.isRegression,
    required this.tolerance,
    this.severity,
  });
}

/// The result of comparing current metrics against a baseline (AC-10).
class BenchmarkComparison {
  /// Scenario that was compared.
  final String scenarioId;

  /// The baseline used for comparison.
  final Baseline baseline;

  /// Current metric values.
  final Map<String, num> current;

  /// Per-metric changes for metrics present in both baseline and current.
  final Map<String, MetricChange> changes;

  /// Aggregate verdict.
  final ComparisonStatus overallStatus;

  /// Creates a comparison.
  const BenchmarkComparison({
    required this.scenarioId,
    required this.baseline,
    required this.current,
    required this.changes,
    required this.overallStatus,
  });

  /// Serializes to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'scenarioId': scenarioId,
    'baseline': baseline.toJson(),
    'current': current,
    'overallStatus': overallStatus.name,
    'changes': {
      for (final entry in changes.entries)
        entry.key: {
          'metric': entry.value.metric,
          'baselineValue': entry.value.baselineValue,
          'currentValue': entry.value.currentValue,
          'absoluteChange': entry.value.absoluteChange,
          'percentChange': entry.value.percentChange,
          'direction': entry.value.direction.name,
          'isRegression': entry.value.isRegression,
          'severity': entry.value.severity,
          'tolerance': entry.value.tolerance,
        },
    },
  };
}

/// Compares [current] metrics against [baseline] (FR-010, AC-10, AC-11).
///
/// [tolerancePercent] is the band within which a change counts as stable.
/// Direction semantics come from [StandardMetrics.isLowerBetter]: latency,
/// memory and CPU regress upward, throughput regresses downward; custom
/// metrics default to lower-is-better. Metrics missing from either side are
/// skipped (reported through the absence from [BenchmarkComparison.changes])
/// rather than crashing the comparison.
BenchmarkComparison compareBaselines(
  Baseline baseline,
  Map<String, num> current, {
  num tolerancePercent = 10,
  Map<String, bool>? lowerIsBetterOverride,
}) {
  final changes = <String, MetricChange>{};
  var sawRegression = false;
  var sawImprovement = false;

  for (final entry in baseline.metrics.entries) {
    final metric = entry.key;
    final baselineValue = entry.value;
    final currentValue = current[metric];
    if (currentValue == null) continue;

    final absoluteChange = currentValue - baselineValue;
    final percentChange = baselineValue == 0
        ? (currentValue == 0 ? 0 : 100)
        : absoluteChange / baselineValue * 100;
    final magnitude = percentChange.abs();

    final lowerIsBetter =
        lowerIsBetterOverride?[metric] ?? StandardMetrics.isLowerBetter(metric);
    // worsening direction: value moved the wrong way.
    final worsened = lowerIsBetter
        ? currentValue > baselineValue
        : currentValue < baselineValue;

    final isRegression = worsened && magnitude > tolerancePercent;
    final improved = !worsened && magnitude > tolerancePercent;

    MetricDirection direction;
    if (isRegression) {
      direction = MetricDirection.regressed;
    } else if (improved) {
      direction = MetricDirection.improved;
    } else {
      direction = MetricDirection.stable;
    }

    String? severity;
    if (isRegression) {
      severity = magnitude > tolerancePercent * 2 ? 'error' : 'warn';
    }

    changes[metric] = MetricChange(
      metric: metric,
      baselineValue: baselineValue,
      currentValue: currentValue,
      absoluteChange: absoluteChange,
      percentChange: percentChange,
      direction: direction,
      isRegression: isRegression,
      tolerance: tolerancePercent,
      severity: severity,
    );

    if (isRegression) sawRegression = true;
    if (improved) sawImprovement = true;
  }

  final overallStatus = sawRegression
      ? ComparisonStatus.regressed
      : sawImprovement
      ? ComparisonStatus.improved
      : ComparisonStatus.stable;

  return BenchmarkComparison(
    scenarioId: baseline.scenarioId,
    baseline: baseline,
    current: current,
    changes: changes,
    overallStatus: overallStatus,
  );
}
