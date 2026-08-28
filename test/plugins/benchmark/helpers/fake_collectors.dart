// Shared fake metric collectors for the benchmark plugin tests (feature 015).
import 'package:zuraffa/src/core/benchmark/metric_collector.dart';

/// A collector that records its lifecycle calls and contributes fixed metrics.
class RecordingCollector implements MetricCollector {
  RecordingCollector({
    this.id = 'recording-collector',
    this.metrics = const {'custom_metric': 123},
    this.throwInCollect = false,
  });

  @override
  final String id;

  final Map<String, num> metrics;
  final bool throwInCollect;

  /// Ordered lifecycle calls: 'initialize', 'beforeBenchmark:MYID',
  /// 'collect:MYID', 'finalize'.
  final List<String> calls = [];

  /// The contexts received by collect, keyed by scenario id.
  final Map<String, MetricContext> contexts = {};

  @override
  String get name => 'Recording Collector';

  @override
  Future<void> initialize() async {
    calls.add('initialize');
  }

  @override
  Future<void> beforeBenchmark(MetricContext context) async {
    calls.add('beforeBenchmark:${context.scenarioId}');
  }

  @override
  Future<Map<String, num>> collect(MetricContext context) async {
    calls.add('collect:${context.scenarioId}');
    contexts[context.scenarioId] = context;
    if (throwInCollect) {
      throw StateError('collector exploded');
    }
    return metrics;
  }

  @override
  Future<void> finalize() async {
    calls.add('finalize');
  }
}
