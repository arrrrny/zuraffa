/// Benchmark execution orchestration (FR-004, FR-005, FR-008, FR-012,
/// FR-013).
///
/// [BenchmarkRunner] is the contract; [DefaultBenchmarkRunner] is the
/// built-in implementation. It drives each scenario through its contract
/// lifecycle (`setup → run × iterations → collectMetrics → teardown`),
/// measures latency samples around every `run()` invocation, layers the
/// standard metrics on top of the scenario's own metrics plus any
/// [MetricCollector] contributions, evaluates thresholds, and aggregates
/// suite results.
///
/// Failure handling (FR-013): a scenario that throws, times out, or fails a
/// threshold never stops the suite — its result records the failure and the
/// next scenario runs.
///
/// Pure-Dart (no Flutter dependency) per spec 014-pure-dart-core-split.
library;

import 'dart:async';
import 'dart:io';

import 'benchmark_contract.dart';
import 'benchmark_result.dart';
import 'metric_collector.dart';

/// Runner-level configuration.
class BenchmarkRunnerConfig {
  /// Per-scenario timeout. A scenario exceeding it is marked failed with a
  /// synthetic `timeout` threshold violation (FR-013).
  final Duration timeout;

  /// Default configuration merged under every per-run config.
  final Map<String, dynamic> globalConfig;

  /// Default suite concurrency when [BenchmarkRunner.run] gets no explicit
  /// value. `1` executes scenarios sequentially.
  final int defaultConcurrency;

  /// Creates a runner configuration.
  const BenchmarkRunnerConfig({
    this.timeout = const Duration(minutes: 5),
    this.globalConfig = const {},
    this.defaultConcurrency = 1,
  });
}

/// The outcome of a dry run (FR-012): validation only, no execution.
class BenchmarkDryRunResult {
  /// The scenario that was validated.
  final String scenarioId;

  /// Whether the scenario metadata and configuration are valid.
  final bool valid;

  /// Validation problems found (empty when valid).
  final List<String> errors;

  /// The configuration that was validated.
  final Map<String, dynamic> config;

  /// Creates a dry-run result.
  const BenchmarkDryRunResult({
    required this.scenarioId,
    required this.valid,
    required this.errors,
    required this.config,
  });

  /// Serializes to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'scenarioId': scenarioId,
        'valid': valid,
        'errors': errors,
        'config': config,
      };
}

/// Orchestrates execution of benchmarks, collects metrics, evaluates
/// thresholds (FR-004).
abstract class BenchmarkRunner {
  /// Runs a single scenario and returns its structured result.
  ///
  /// [timeout] overrides the runner's configured per-scenario timeout (used by
  /// the CLI `--timeout` flag); when `null` the [config] timeout applies.
  Future<BenchmarkResult> runSingle(
    BenchmarkContract scenario, {
    Map<String, dynamic>? config,
    Duration? timeout,
  });

  /// Runs [scenarios] and aggregates their results into a suite report
  /// (FR-008). When [concurrency] is greater than 1 the scenarios are
  /// executed by a worker pool of that size. [timeout] overrides the
  /// per-scenario timeout for every scenario in the suite.
  Future<BenchmarkSuiteResult> run(
    List<BenchmarkContract> scenarios, {
    Map<String, dynamic>? globalConfig,
    int? concurrency,
    Duration? timeout,
  });

  /// Validates the scenario metadata and configuration without executing
  /// anything (FR-012).
  Future<BenchmarkDryRunResult> dryRun(
    BenchmarkContract scenario, {
    Map<String, dynamic>? config,
  });
}

/// The built-in [BenchmarkRunner].
class DefaultBenchmarkRunner implements BenchmarkRunner {
  /// Creates a runner.
  DefaultBenchmarkRunner({
    this.config = const BenchmarkRunnerConfig(),
    List<MetricCollector>? collectors,
  }) : _collectors = collectors ?? [];

  /// Runner-level configuration.
  final BenchmarkRunnerConfig config;

  final List<MetricCollector> _collectors;
  String? _cachedGitCommit;

  /// Registers an additional metric collector on a live runner.
  void registerMetricCollector(MetricCollector collector) {
    _collectors.add(collector);
  }

  @override
  Future<BenchmarkResult> runSingle(
    BenchmarkContract scenario, {
    Map<String, dynamic>? config,
    Duration? timeout,
  }) async {
    final merged = {...this.config.globalConfig, ...?config};
    final startedAt = DateTime.now();
    final totalStopwatch = Stopwatch()..start();

    // Collector lifecycle for a single run (FR-006): initialize before,
    // finalize after. The suite path does this once for the whole suite, but
    // runSingle can be invoked standalone (e.g. baseline save/compare).
    for (final collector in _collectors) {
      await _guardCollector(
        collector,
        () => collector.initialize(),
        description: 'initialize ${collector.id}',
      );
    }
    try {
      return await _withTimeout(
        () => _executeScenario(scenario, merged, startedAt, totalStopwatch),
        timeout: timeout ?? this.config.timeout,
        scenario: scenario,
        startedAt: startedAt,
      );
    } finally {
      for (final collector in _collectors) {
        await _guardCollector(
          collector,
          () => collector.finalize(),
          description: 'finalize ${collector.id}',
        );
      }
    }
  }

  @override
  Future<BenchmarkSuiteResult> run(
    List<BenchmarkContract> scenarios, {
    Map<String, dynamic>? globalConfig,
    int? concurrency,
    Duration? timeout,
  }) async {
    final effectiveConcurrency =
        (concurrency ?? config.defaultConcurrency).clamp(1, scenarios.length);
    final startedAt = DateTime.now();
    final suiteStopwatch = Stopwatch()..start();

    // Collector suite lifecycle: initialize once (FR-006).
    for (final collector in _collectors) {
      await _guardCollector(
        collector,
        () => collector.initialize(),
        description: 'initialize ${collector.id}',
      );
    }

    final results = List<BenchmarkResult?>.filled(scenarios.length, null);
    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        final index = nextIndex++;
        if (index >= scenarios.length) return;
        final scenario = scenarios[index];
        final merged = {
          ...config.globalConfig,
          ...?globalConfig,
        };
        final scenarioStartedAt = DateTime.now();
        final stopwatch = Stopwatch()..start();
        results[index] = await _withTimeout(
          () => _executeScenario(
            scenario,
            merged,
            scenarioStartedAt,
            stopwatch,
            iteration: index,
          ),
          timeout: timeout ?? config.timeout,
          scenario: scenario,
          startedAt: scenarioStartedAt,
        );
      }
    }

    final workers = List.generate(
      effectiveConcurrency,
      (_) => worker(),
    );
    await Future.wait(workers);

    // Collector suite lifecycle: finalize once.
    for (final collector in _collectors) {
      await _guardCollector(
        collector,
        () => collector.finalize(),
        description: 'finalize ${collector.id}',
      );
    }

    suiteStopwatch.stop();
    return BenchmarkSuiteResult(
      results: results.cast<BenchmarkResult>(),
      totalDuration: suiteStopwatch.elapsed,
      startedAt: startedAt,
      completedAt: DateTime.now(),
    );
  }

  @override
  Future<BenchmarkDryRunResult> dryRun(
    BenchmarkContract scenario, {
    Map<String, dynamic>? config,
  }) async {
    final errors = [
      ...ScenarioValidation.validate(scenario),
      ..._validateConfigAgainstSchema(scenario.configSchema, config ?? const {}),
    ];
    return BenchmarkDryRunResult(
      scenarioId: scenario.id,
      valid: errors.isEmpty,
      errors: errors,
      config: config ?? const {},
    );
  }

  // --- Internals ---

  Future<BenchmarkResult> _executeScenario(
    BenchmarkContract scenario,
    Map<String, dynamic> merged,
    DateTime startedAt,
    Stopwatch totalStopwatch, {
    int iteration = 0,
  }) async {
    final warnings = <String>[];
    final samples = <Duration>[];
    var iterations = _asInt(merged['iterations']) ?? 1;
    // A non-positive iteration count would yield empty samples and zeroed
    // metrics; clamp to at least one measured iteration.
    if (iterations < 1) iterations = 1;
    BenchmarkResult? scenarioResult;
    Object? failure;
    StackTrace? failureStack;
    var setupCompleted = false;

    // beforeBenchmark collector hook — guarded, failures surface as
    // stderr diagnostics only (the result does not exist yet).
    try {
      await Future.wait([
        for (final collector in _collectors)
          collector.beforeBenchmark(
            MetricContext(
              scenarioId: scenario.id,
              scenarioName: scenario.name,
              config: merged,
              elapsed: Duration.zero,
              iteration: iteration,
            ),
          ),
      ]);
    } catch (error) {
      stderr.writeln(
        'benchmark collector beforeBenchmark failure (${scenario.id}): '
        '$error',
      );
    }

    // setup — when it throws, run and teardown are skipped (data-model
    // error contract).
    try {
      await scenario.setup();
      setupCompleted = true;
    } catch (error, stack) {
      failure = error;
      failureStack = stack;
    }

    if (setupCompleted) {
      try {
        // Warm-up iterations prime the JIT/caches; their timing samples are
        // discarded so they don't skew the latency percentiles (review
        // finding: no warm-up biased the percentiles toward cold-start cost).
        final warmup = _asInt(merged['warmup']) ?? 0;
        for (var i = 0; i < warmup; i++) {
          await scenario.run(merged);
        }
        for (var i = 0; i < iterations; i++) {
          final iterationStopwatch = Stopwatch()..start();
          scenarioResult = await scenario.run(merged);
          iterationStopwatch.stop();
          samples.add(iterationStopwatch.elapsed);
        }
      } catch (error, stack) {
        failure = error;
        failureStack = stack;
      }

      // collectMetrics — only when the measured section completed; a
      // failure here is a warning, not an error status.
      if (failure == null) {
        try {
          final custom = await scenario.collectMetrics();
          scenarioResult =
              (scenarioResult ?? _emptyResult(scenario, startedAt))
                  .copyWith(metrics: {
            ...?scenarioResult?.metrics,
            ...custom,
          });
        } catch (error) {
          warnings.add('collectMetrics failed for ${scenario.id}: $error');
        }
      }

      // teardown — always attempted after a successful setup; a failure is
      // a warning.
      try {
        await scenario.teardown();
      } catch (error) {
        warnings.add('teardown failed for ${scenario.id}: $error');
      }
    }

    totalStopwatch.stop();

    // Standard metrics from the measured samples.
    final standard = await const StandardMetricCollector().collect(
      MetricContext(
        scenarioId: scenario.id,
        scenarioName: scenario.name,
        config: merged,
        elapsed: totalStopwatch.elapsed,
        samples: samples,
        iteration: iteration,
      ),
    );

    final metrics = <String, num>{
      ...standard,
      ...?scenarioResult?.metrics,
    };

    // Collector-contributed metrics — each guarded (AC-9).
    for (final collector in _collectors) {
      try {
        final contributed = await collector.collect(
          MetricContext(
            scenarioId: scenario.id,
            scenarioName: scenario.name,
            config: merged,
            elapsed: totalStopwatch.elapsed,
            result: scenarioResult,
            samples: samples,
            iteration: iteration,
          ),
        );
        metrics.addAll(contributed);
      } catch (error) {
        // AC-9: a failing collector never fails the benchmark.
        warnings.add('collector ${collector.id} failed for ${scenario.id}: '
            '$error');
      }
    }

    // Evaluate thresholds (FR-005).
    final violations = <ThresholdViolation>[];
    for (final entry in scenario.thresholds.entries) {
      final threshold = entry.value;
      final actual = metrics[threshold.metric];
      if (actual == null) {
        warnings.add(
          'threshold metric ${threshold.metric} not present in results '
          'for ${scenario.id}',
        );
        continue;
      }
      if (threshold.isViolatedBy(actual)) {
        violations.add(
          ThresholdViolation(
            metric: threshold.metric,
            expected: threshold.expectation,
            actual: actual,
            severity: threshold.severity,
            message:
                '${threshold.metric} was $actual, expected '
                '${threshold.expectation}',
          ),
        );
      }
    }

    final status = failure != null
        ? BenchmarkStatus.error
        : violations.any((v) => v.severity == ThresholdSeverity.error)
            ? BenchmarkStatus.failed
            : BenchmarkStatus.passed;

    return BenchmarkResult(
      scenarioId: scenario.id,
      scenarioName: scenario.name,
      scenarioVersion: scenario.version,
      status: status,
      metrics: metrics,
      thresholdViolations: violations,
      duration: totalStopwatch.elapsed,
      timestamp: startedAt,
      gitCommit: _gitCommit(),
      metadata: {
        'config': merged,
        'iterations': iterations,
        'sampleCount': samples.length,
        if (failure != null) 'error': '$failure',
        if (failureStack != null && failure != null) 'stack': '$failureStack',
        if (warnings.isNotEmpty) 'warnings': warnings,
      },
    );
  }

  Future<BenchmarkResult> _withTimeout(
    Future<BenchmarkResult> Function() body, {
    required Duration timeout,
    required BenchmarkContract scenario,
    required DateTime startedAt,
  }) async {
    try {
      return await body().timeout(timeout);
    } on TimeoutException {
      return BenchmarkResult(
        scenarioId: scenario.id,
        scenarioName: scenario.name,
        scenarioVersion: scenario.version,
        status: BenchmarkStatus.failed,
        metrics: const {},
        thresholdViolations: [
          ThresholdViolation(
            metric: 'timeout',
            expected: 'complete within ${timeout.inMilliseconds}ms',
            actual: timeout.inMilliseconds,
            severity: ThresholdSeverity.error,
            message:
                '${scenario.id} timed out after ${timeout.inMilliseconds}ms',
          ),
        ],
        duration: timeout,
        timestamp: startedAt,
        gitCommit: _gitCommit(),
        metadata: {'timedOut': true, 'timeoutMs': timeout.inMilliseconds},
      );
    }
  }

  Future<Map<String, num>?> _guardCollector(
    MetricCollector? collector,
    Future<Object?> Function() action, {
    required String description,
  }) async {
    try {
      final result = await action();
      if (result is Map<String, num>) return result;
      return null;
    } catch (error) {
      // AC-9: a failing collector never fails the suite lifecycle hooks.
      stderr.writeln('benchmark collector failure ($description): $error');
      return null;
    }
  }

  BenchmarkResult _emptyResult(
    BenchmarkContract scenario,
    DateTime startedAt,
  ) =>
      BenchmarkResult(
        scenarioId: scenario.id,
        scenarioName: scenario.name,
        scenarioVersion: scenario.version,
        status: BenchmarkStatus.passed,
        metrics: const {},
        thresholdViolations: const [],
        duration: Duration.zero,
        timestamp: startedAt,
      );

  String _gitCommit() {
    if (_cachedGitCommit != null) return _cachedGitCommit!;
    try {
      final result = Process.runSync(
        'git',
        ['rev-parse', '--short', 'HEAD'],
      );
      if (result.exitCode == 0) {
        _cachedGitCommit = (result.stdout as String).trim();
      } else {
        _cachedGitCommit = 'unknown';
      }
    } catch (_) {
      _cachedGitCommit = 'unknown';
    }
    return _cachedGitCommit!;
  }
}

// --- Config schema validation (FR-012, dry-run path) ---

List<String> _validateConfigAgainstSchema(
  Map<String, dynamic> schema,
  Map<String, dynamic> config,
) {
  if (schema.isEmpty) return const [];

  final errors = <String>[];
  final properties =
      (schema['properties'] as Map<String, dynamic>?) ?? const {};

  for (final requiredName in (schema['required'] as List<dynamic>? ?? const [])) {
    if (!config.containsKey(requiredName)) {
      errors.add("missing required config property '$requiredName'");
    }
  }

  for (final entry in config.entries) {
    final property = properties[entry.key] as Map<String, dynamic>?;
    if (property == null) continue; // unknown keys are allowed
    final type = property['type'] as String?;
    final value = entry.value;
    if (type == null) continue;

    var matches = true;
    switch (type) {
      case 'integer':
        matches = value is int;
      case 'number':
        matches = value is num;
      case 'string':
        matches = value is String;
      case 'boolean':
        matches = value is bool;
      case 'object':
        matches = value is Map;
      case 'array':
        matches = value is List;
      default:
        matches = true;
    }
    if (!matches) {
      errors.add(
        "config property '${entry.key}' must be of type $type "
        '(got ${value.runtimeType})',
      );
      continue;
    }

    final minimum = property['minimum'] as num?;
    if (minimum != null && value is num && value < minimum) {
      errors.add(
        "config property '${entry.key}' violates minimum $minimum "
        '(got $value)',
      );
    }
  }

  return errors;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}
