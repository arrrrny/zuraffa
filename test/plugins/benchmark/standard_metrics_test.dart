// Tests for lib/src/core/benchmark/standard_metrics.dart — behaviors
// U21–U24 of specs/015-benchmark-plugin/tdd/test-list.md.
import 'package:test/test.dart';
import 'package:zuraffa/src/core/benchmark/standard_metrics.dart';

void main() {
  group('StandardMetrics.percentile', () {
    test('p50 known sample', () {
      final samples = [40, 10, 30, 50, 20]; // unsorted on purpose
      expect(StandardMetrics.percentile(samples, 50), closeTo(30, 1e-9));
    });

    test('p95 p99 known sample', () {
      final samples = List<int>.generate(100, (i) => i + 1); // 1..100
      // Linear interpolation: rank = p/100 * (n-1).
      // p95 -> 94.05 -> between 95 and 96 -> 95.05
      expect(StandardMetrics.percentile(samples, 95), closeTo(95.05, 1e-9));
      // p99 -> 98.01 -> between 99 and 100 -> 99.01
      expect(StandardMetrics.percentile(samples, 99), closeTo(99.01, 1e-9));
    });

    test('empty sample returns zero', () {
      expect(StandardMetrics.percentile(const [], 50), 0);
    });

    test('single sample returns itself for any percentile', () {
      expect(StandardMetrics.percentile(const [42], 95), 42);
    });
  });

  group('StandardMetrics names', () {
    test('six standard names', () {
      expect(StandardMetrics.allNames, [
        'latency_p50',
        'latency_p95',
        'latency_p99',
        'throughput_ops_sec',
        'memory_mb',
        'cpu_percent',
      ]);
    });

    test('lower-is-better directions for standard metrics', () {
      expect(StandardMetrics.isLowerBetter('latency_p99'), isTrue);
      expect(StandardMetrics.isLowerBetter('memory_mb'), isTrue);
      expect(StandardMetrics.isLowerBetter('cpu_percent'), isTrue);
      expect(StandardMetrics.isLowerBetter('throughput_ops_sec'), isFalse);
      // Unknown/custom metrics default to lower-is-better (conservative).
      expect(StandardMetrics.isLowerBetter('custom_cache_misses'), isTrue);
    });
  });

  group('StandardMetrics.throughput', () {
    test('throughput formula', () {
      expect(
        StandardMetrics.throughput(100, const Duration(seconds: 2)),
        closeTo(50, 1e-9),
      );
      expect(
        StandardMetrics.throughput(250, const Duration(milliseconds: 500)),
        closeTo(500, 1e-6),
      );
    });

    test('throughput of zero elapsed is zero, never infinite', () {
      expect(StandardMetrics.throughput(100, Duration.zero), 0);
    });
  });
}
