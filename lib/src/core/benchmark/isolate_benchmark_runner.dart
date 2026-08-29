/// Isolate-based benchmark execution (FR-007).
///
/// [IsolateBenchmarkRunner] executes each scenario in a freshly spawned
/// isolate so benchmarks cannot cross-contaminate each other's heap or
/// in-flight state. The scenario object, its configuration, and the result
/// cross the isolate boundary as messages (same isolate group), and the
/// runner stamps `isolated: true` on the result metadata as evidence the
/// execution did not share the host isolate.
///
/// Errors thrown inside the isolate are marshalled back as `error` results;
/// an isolate that dies without replying is converted to an error result
/// rather than crashing the host (FR-013).
///
/// Pure-Dart (no Flutter dependency) per spec 014-pure-dart-core-split.
library;

import 'dart:async';
import 'dart:isolate';

import 'benchmark_contract.dart';
import 'benchmark_result.dart';
import 'benchmark_runner.dart';

/// A [BenchmarkRunner] that executes every scenario in its own isolate.
class IsolateBenchmarkRunner implements BenchmarkRunner {
  /// Creates an isolate runner.
  ///
  /// [config] mirrors [DefaultBenchmarkRunner]'s configuration and is
  /// honoured inside the spawned isolate.
  IsolateBenchmarkRunner({
    this.config = const BenchmarkRunnerConfig(),
  });

  /// Runner configuration applied inside each spawned isolate.
  final BenchmarkRunnerConfig config;

  @override
  Future<BenchmarkResult> runSingle(
    BenchmarkContract scenario, {
    Map<String, dynamic>? config,
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? this.config.timeout;
    final merged = {...this.config.globalConfig, ...?config};
    final port = ReceivePort();
    final errorPort = ReceivePort();

    Isolate? isolate;
    try {
      isolate = await Isolate.spawn(
        _isolateEntryPoint,
        _IsolateJob(
          scenario: scenario,
          config: merged,
          // Honor the (possibly overridden) per-scenario timeout inside the
          // isolate too, so the applied timeout is consistent end-to-end.
          runnerConfig: BenchmarkRunnerConfig(
            timeout: effectiveTimeout,
            globalConfig: this.config.globalConfig,
            defaultConcurrency: this.config.defaultConcurrency,
          ),
          replyTo: port.sendPort,
        ),
        onError: errorPort.sendPort,
        errorsAreFatal: false,
      );
    } catch (error) {
      port.close();
      errorPort.close();
      return _errorResult(scenario, 'failed to spawn isolate: $error');
    }

    errorPort.listen((message) {
      // Uncaught isolate errors are diagnostics only: the job's own reply
      // (or the outer timeout) decides the result.
      errorPort.close();
    });

    final result = await port.first
        .timeout(
          effectiveTimeout + const Duration(seconds: 5),
          onTimeout: () => <String, dynamic>{
            'kind': 'error',
            'error':
                'isolate for ${scenario.id} did not reply within the timeout',
          },
        )
        .then((reply) => _decodeReply(scenario, reply))
        .catchError((Object error) => _errorResult(scenario, '$error'));

    // Best-effort cleanup: reap the isolate, then close both ReceivePorts so
    // neither leaks (review finding: the receive port was never closed). The
    // entry point returns right after sending, so killing only shortens the
    // isolate's natural teardown.
    try {
      isolate.kill(priority: Isolate.immediate);
    } catch (_) {
      // Already dead — nothing to reap.
    }
    try {
      port.close();
    } catch (_) {
      // Already closed.
    }
    errorPort.close();

    return result;
  }

  @override
  Future<BenchmarkSuiteResult> run(
    List<BenchmarkContract> scenarios, {
    Map<String, dynamic>? globalConfig,
    int? concurrency,
    Duration? timeout,
  }) async {
    final startedAt = DateTime.now();
    final stopwatch = Stopwatch()..start();
    final results = <BenchmarkResult>[];

    // Sequential by default: each scenario gets a pristine isolate (FR-007).
    for (final scenario in scenarios) {
      results.add(
        await runSingle(scenario, config: globalConfig, timeout: timeout),
      );
    }

    stopwatch.stop();
    return BenchmarkSuiteResult(
      results: results,
      totalDuration: stopwatch.elapsed,
      startedAt: startedAt,
      completedAt: DateTime.now(),
    );
  }

  @override
  Future<BenchmarkDryRunResult> dryRun(
    BenchmarkContract scenario, {
    Map<String, dynamic>? config,
  }) {
    // Validation requires no execution, so no isolate is needed.
    return DefaultBenchmarkRunner(config: this.config).dryRun(
      scenario,
      config: config,
    );
  }

  BenchmarkResult _decodeReply(
    BenchmarkContract scenario,
    Object reply,
  ) {
    if (reply is Map<String, dynamic> && reply['kind'] == 'result') {
      final json = (reply['result'] as Map<String, dynamic>).cast<String, dynamic>();
      final result = BenchmarkResult.fromJson(json);
      return result.copyWith(
        metadata: {...result.metadata, 'isolated': true},
      );
    }
    final message = reply is Map<String, dynamic> && reply['error'] != null
        ? reply['error'].toString()
        : 'unexpected isolate reply: $reply';
    return _errorResult(scenario, message);
  }

  BenchmarkResult _errorResult(BenchmarkContract scenario, String message) {
    return BenchmarkResult(
      scenarioId: scenario.id,
      scenarioName: scenario.name,
      scenarioVersion: scenario.version,
      status: BenchmarkStatus.error,
      metrics: const {},
      thresholdViolations: const [],
      duration: Duration.zero,
      timestamp: DateTime.now(),
      metadata: {'error': message, 'isolated': true},
    );
  }
}

/// The message sent into the spawned isolate.
class _IsolateJob {
  const _IsolateJob({
    required this.scenario,
    required this.config,
    required this.runnerConfig,
    required this.replyTo,
  });

  final BenchmarkContract scenario;
  final Map<String, dynamic> config;
  final BenchmarkRunnerConfig runnerConfig;
  final SendPort replyTo;
}

/// Top-level entry point executed inside the spawned isolate.
///
/// Runs the scenario through a [DefaultBenchmarkRunner] confined to this
/// isolate and posts the serialized result (or error) back to the host.
Future<void> _isolateEntryPoint(_IsolateJob job) async {
  final runner = DefaultBenchmarkRunner(config: job.runnerConfig);
  try {
    final result = await runner.runSingle(
      job.scenario,
      config: job.config,
    );
    job.replyTo.send({'kind': 'result', 'result': result.toJson()});
  } catch (error, stack) {
    job.replyTo.send({
      'kind': 'error',
      'error': '$error\n$stack',
    });
  }
}
