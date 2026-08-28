// Shared test fixtures for the benchmark plugin tests (feature 015).
//
// Deterministic fakes: no I/O, no real timing dependence beyond explicit
// delays, full call recording for lifecycle assertions.
import 'package:zuraffa/src/core/benchmark/benchmark_contract.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_result.dart';

/// A scenario that records every lifecycle call into [calls].
class RecordingScenario extends BenchmarkScenario {
  RecordingScenario(
    this._id, {
    String? name,
    List<String> tags = const [],
    Map<String, ThresholdConfig> thresholds = const {},
    Map<String, num> metrics = const {'ops': 1},
    this.onRun,
  })  : _name = name ?? 'Scenario for $_id',
        _tags = tags,
        _thresholds = thresholds,
        _metrics = metrics;

  final String _id;
  final String _name;
  final List<String> _tags;
  final Map<String, ThresholdConfig> _thresholds;
  final Map<String, num> _metrics;

  /// Ordered lifecycle calls: 'setup', 'run', 'collectMetrics', 'teardown'.
  final List<String> calls = [];

  /// The config received by the last `run` call.
  Map<String, dynamic>? lastConfig;

  /// Optional hook invoked inside run.
  void Function(Map<String, dynamic> config)? onRun;

  @override
  String get id => _id;

  @override
  String get name => _name;

  @override
  String get version => '1.0.0';

  @override
  List<String> get tags => _tags;

  @override
  Map<String, ThresholdConfig> get thresholds => _thresholds;

  @override
  Future<void> setup() async {
    calls.add('setup');
  }

  @override
  Future<BenchmarkResult> run(Map<String, dynamic> config) async {
    calls.add('run');
    lastConfig = config;
    onRun?.call(config);
    return BenchmarkResult(
      scenarioId: id,
      scenarioName: name,
      scenarioVersion: version,
      status: BenchmarkStatus.passed,
      metrics: _metrics,
      thresholdViolations: const [],
      duration: const Duration(milliseconds: 1),
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<void> teardown() async {
    calls.add('teardown');
  }

  @override
  Future<Map<String, num>> collectMetrics() async {
    calls.add('collectMetrics');
    return {'${id}_custom': 7};
  }
}

/// Which lifecycle stage a [ThrowingScenario] throws from.
enum LifecycleStage { setup, run, collectMetrics, teardown }

/// A scenario that throws from a configurable lifecycle stage.
class ThrowingScenario extends BenchmarkScenario {
  ThrowingScenario(this._id, {this.throwIn = LifecycleStage.run});

  final String _id;
  final LifecycleStage throwIn;

  final List<String> calls = [];

  @override
  String get id => _id;

  @override
  String get name => 'Throwing $_id';

  @override
  String get version => '1.0.0';

  @override
  Future<void> setup() async {
    calls.add('setup');
    if (throwIn == LifecycleStage.setup) {
      throw StateError('setup exploded');
    }
  }

  @override
  Future<BenchmarkResult> run(Map<String, dynamic> config) async {
    calls.add('run');
    if (throwIn == LifecycleStage.run) {
      throw StateError('run exploded');
    }
    return BenchmarkResult(
      scenarioId: id,
      scenarioName: name,
      scenarioVersion: version,
      status: BenchmarkStatus.passed,
      metrics: const {'ops': 1},
      thresholdViolations: const [],
      duration: const Duration(milliseconds: 1),
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<void> teardown() async {
    calls.add('teardown');
    if (throwIn == LifecycleStage.teardown) {
      throw StateError('teardown exploded');
    }
  }

  @override
  Future<Map<String, num>> collectMetrics() async {
    calls.add('collectMetrics');
    if (throwIn == LifecycleStage.collectMetrics) {
      throw StateError('collectMetrics exploded');
    }
    return const {};
  }
}

/// A scenario whose run awaits [delay] before returning (timeout tests).
class SlowScenario extends BenchmarkScenario {
  SlowScenario(this._id, this.delay);

  final String _id;
  final Duration delay;

  @override
  String get id => _id;

  @override
  String get name => 'Slow $_id';

  @override
  String get version => '1.0.0';

  @override
  Future<BenchmarkResult> run(Map<String, dynamic> config) async {
    await Future<void>.delayed(delay);
    return BenchmarkResult(
      scenarioId: id,
      scenarioName: name,
      scenarioVersion: version,
      status: BenchmarkStatus.passed,
      metrics: const {'ops': 1},
      thresholdViolations: const [],
      duration: delay,
      timestamp: DateTime.now(),
    );
  }
}

/// A scenario with fixed metrics and thresholds (threshold evaluation tests).
class FixedMetricScenario extends BenchmarkScenario {
  FixedMetricScenario(
    this._id,
    this.metrics, {
    Map<String, ThresholdConfig> thresholds = const {},
  }) : _thresholds = thresholds;

  final String _id;
  final Map<String, num> metrics;
  final Map<String, ThresholdConfig> _thresholds;

  @override
  String get id => _id;

  @override
  String get name => 'Fixed $_id';

  @override
  String get version => '1.0.0';

  @override
  Map<String, ThresholdConfig> get thresholds => _thresholds;

  @override
  Future<BenchmarkResult> run(Map<String, dynamic> config) async =>
      BenchmarkResult(
        scenarioId: id,
        scenarioName: name,
        scenarioVersion: version,
        status: BenchmarkStatus.passed,
        metrics: metrics,
        thresholdViolations: const [],
        duration: const Duration(milliseconds: 1),
        timestamp: DateTime.now(),
      );
}

/// A scenario with a config schema that exercises dry-run validation.
class SchemaScenario extends BenchmarkScenario {
  SchemaScenario(this._id);

  final String _id;

  @override
  String get id => _id;

  @override
  String get name => 'Schema $_id';

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> get configSchema => const {
        'type': 'object',
        'required': ['entityCount'],
        'properties': {
          'entityCount': {
            'type': 'integer',
            'minimum': 1,
          },
          'label': {'type': 'string'},
        },
      };

  final List<String> calls = [];

  @override
  Future<BenchmarkResult> run(Map<String, dynamic> config) async {
    calls.add('run');
    return BenchmarkResult(
      scenarioId: id,
      scenarioName: name,
      scenarioVersion: version,
      status: BenchmarkStatus.passed,
      metrics: const {'ops': 1},
      thresholdViolations: const [],
      duration: const Duration(milliseconds: 1),
      timestamp: DateTime.now(),
    );
  }
}
