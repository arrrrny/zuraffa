/// Standardized metric names and measurement math (FR-004).
///
/// The six standard metrics every benchmark result carries, plus the pure
/// statistics the framework needs: linear-interpolation percentiles and
/// throughput. Kept dependency-free so both the runner and collectors can
/// share the exact same math.
///
/// Pure-Dart (no Flutter dependency) per spec 014-pure-dart-core-split.
library;

/// The standard metric vocabulary and shared statistics.
abstract final class StandardMetrics {
  /// Median latency, in milliseconds.
  static const String latencyP50 = 'latency_p50';

  /// 95th percentile latency, in milliseconds.
  static const String latencyP95 = 'latency_p95';

  /// 99th percentile latency, in milliseconds.
  static const String latencyP99 = 'latency_p99';

  /// Operations per second.
  static const String throughputOpsSec = 'throughput_ops_sec';

  /// Peak memory usage, in megabytes.
  static const String memoryMb = 'memory_mb';

  /// CPU utilization proxy, in percent.
  static const String cpuPercent = 'cpu_percent';

  /// All six standard metric names, in canonical order.
  static const List<String> allNames = [
    latencyP50,
    latencyP95,
    latencyP99,
    throughputOpsSec,
    memoryMb,
    cpuPercent,
  ];

  /// Whether a metric is "lower is better" for regression comparison.
  ///
  /// Latency, memory and CPU regress upward; throughput regresses downward.
  /// Custom metrics default to lower-is-better — the conservative reading
  /// for unknown domains (a rise is flagged rather than silently praised).
  static bool isLowerBetter(String metric) {
    if (metric.startsWith('latency_') ||
        metric == memoryMb ||
        metric == cpuPercent) {
      return true;
    }
    if (metric.startsWith('throughput_')) return false;
    return true;
  }

  /// Computes the [p]-th percentile of [samples] with linear interpolation.
  ///
  /// An empty sample yields `0`; a single sample yields itself. [samples] is
  /// not modified.
  static num percentile(List<num> samples, num p) {
    if (samples.isEmpty) return 0;
    if (samples.length == 1) return samples.first;
    final sorted = List<num>.of(samples)..sort();
    final rank = (p / 100) * (sorted.length - 1);
    final lower = rank.floor().clamp(0, sorted.length - 1);
    final upper = rank.ceil().clamp(0, sorted.length - 1);
    if (lower == upper) return sorted[lower];
    final fraction = rank - lower;
    return sorted[lower] + (sorted[upper] - sorted[lower]) * fraction;
  }

  /// Computes operations per second: [operations] over [elapsed].
  ///
  /// Zero elapsed time yields `0` rather than infinity — a benchmark that
  /// completes without measurable time reports no throughput.
  static num throughput(int operations, Duration elapsed) {
    final micros = elapsed.inMicroseconds;
    if (micros == 0) return 0;
    return operations / (micros / 1e6);
  }
}
