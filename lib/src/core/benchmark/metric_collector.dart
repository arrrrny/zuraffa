/// Extensible metric collection for the benchmark framework (FR-006).
///
/// [MetricCollector] is the interface plugins implement to contribute custom
/// metrics (database query counts, network bytes, GC pauses, ...). The
/// runner drives a four-phase lifecycle per suite:
/// [initialize] once → per scenario [beforeBenchmark] → [collect] (returning
/// the metrics to merge into the result) → [finalize] once.
///
/// [StandardMetricCollector] is the built-in collector producing the six
/// standard metrics (latency percentiles, throughput, memory, CPU) from the
/// timing samples the runner measures around each `run()` invocation (FR-004).
///
/// Pure-Dart (no Flutter dependency) per spec 014-pure-dart-core-split.
library;

import 'dart:io';

import 'benchmark_result.dart';
import 'standard_metrics.dart';

/// The context handed to a [MetricCollector] at each lifecycle point.
class MetricContext {
  /// The scenario being measured.
  final String scenarioId;

  /// Human-readable scenario name.
  final String scenarioName;

  /// The merged configuration the scenario ran with.
  final Map<String, dynamic> config;

  /// The scenario's result once available; `null` in [MetricCollector
  /// .beforeBenchmark].
  final BenchmarkResult? result;

  /// Wall-clock time of the scenario's measured section.
  final Duration elapsed;

  /// Latency samples measured by the runner, one per executed iteration.
  final List<Duration> samples;

  /// Which execution of the scenario this is (0-based, within a suite run).
  final int iteration;

  /// Creates a metric context.
  const MetricContext({
    required this.scenarioId,
    required this.scenarioName,
    required this.config,
    required this.elapsed,
    this.result,
    this.samples = const [],
    this.iteration = 0,
  });
}

/// Extensible interface for capturing custom metrics during benchmark
/// execution (FR-006).
abstract class MetricCollector {
  /// Unique collector identifier (kebab-case).
  String get id;

  /// Human-readable collector name.
  String get name;

  /// Called once before the suite starts.
  Future<void> initialize();

  /// Called before each benchmark scenario.
  Future<void> beforeBenchmark(MetricContext context);

  /// Called after each benchmark scenario; the returned metrics are merged
  /// into the scenario's final [BenchmarkResult.metrics].
  Future<Map<String, num>> collect(MetricContext context);

  /// Called once after the suite ends.
  Future<void> finalize();
}

/// The built-in collector producing the six standard metrics (FR-004, AC-5).
///
/// Latency percentiles and throughput derive from the timing samples the
/// runner measured around each `run()` invocation. `memory_mb` is the
/// process's resident set size at collection time (best-effort VM metric,
/// megabytes). `cpu_percent` is a busy-ratio proxy: the share of the
/// scenario's total wall-clock time spent inside the measured `run()`
/// section, clamped to [0, 100]. Both degrade to sensible zero-values on
/// platforms where the underlying signal is unavailable.
class StandardMetricCollector implements MetricCollector {
  /// Creates the standard collector.
  const StandardMetricCollector();

  @override
  String get id => 'standard';

  @override
  String get name => 'Standard Metrics (latency, throughput, memory, CPU)';

  @override
  Future<void> initialize() async {}

  @override
  Future<void> beforeBenchmark(MetricContext context) async {}

  @override
  Future<Map<String, num>> collect(MetricContext context) async {
    final samplesMs = context.samples
        .map((s) => s.inMicroseconds / 1000)
        .toList();

    final totalSampleMicros = context.samples.fold<int>(
      0,
      (sum, sample) => sum + sample.inMicroseconds,
    );
    final busyRatio = context.elapsed.inMicroseconds == 0
        ? 0.0
        : totalSampleMicros / context.elapsed.inMicroseconds;

    return {
      StandardMetrics.latencyP50: StandardMetrics.percentile(samplesMs, 50),
      StandardMetrics.latencyP95: StandardMetrics.percentile(samplesMs, 95),
      StandardMetrics.latencyP99: StandardMetrics.percentile(samplesMs, 99),
      StandardMetrics.throughputOpsSec: StandardMetrics.throughput(
        context.samples.length,
        Duration(microseconds: totalSampleMicros),
      ),
      StandardMetrics.memoryMb: ProcessInfo.currentRss / (1024 * 1024),
      StandardMetrics.cpuPercent: (busyRatio * 100).clamp(0, 100),
    };
  }

  @override
  Future<void> finalize() async {}
}
