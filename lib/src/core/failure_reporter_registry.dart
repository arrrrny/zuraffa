import 'dart:async';

import 'package:logging/logging.dart';

import 'failure.dart';
import 'failure_report_queue.dart';
import 'failure_report_store.dart';
import 'failure_reporter.dart';
import 'retry_policies.dart';
import 'retry_policy.dart';

/// Global singleton registry for failure reporters.
///
/// Manages reporter registration, queue configuration, and the lifecycle
/// of failure reporting. All UseCases automatically report failures
/// through this registry — no per-UseCase configuration needed.
///
/// ## Usage
/// ```dart
/// // Register a reporter (typically in main())
/// await FailureReporterRegistry.instance.register(
///   OtelFailureReporter(
///     collectorEndpoint: Uri.parse('https://otel.mybackend.com/v1/traces'),
///     serviceName: 'my_app',
///   ),
/// );
///
/// // Failures are now automatically reported from all UseCases.
/// ```
class FailureReporterRegistry {
  static final FailureReporterRegistry instance = FailureReporterRegistry._();

  static final _logger = Logger('FailureReporterRegistry');

  FailureReportQueue? _queue;
  ReportRetryPolicy _retryPolicy = const ExponentialBackoffRetryPolicy();
  int _maxQueueSize = 256;
  int _maxBatchSize = 32;
  Duration _flushInterval = const Duration(seconds: 5);
  String? _storagePath;

  final Map<String, FailureReporter> _reporters = {};

  FailureReporterRegistry._();

  /// All registered reporters.
  List<FailureReporter> get reporters =>
      List.unmodifiable(_reporters.values.toList());

  /// Whether any reporters are registered.
  bool get hasReporters => _reporters.isNotEmpty;

  /// The current queue (null if no reporters are registered).
  FailureReportQueue? get queue => _queue;

  /// Configure queue parameters before registering reporters.
  ///
  /// Must be called before the first [register] call.
  void configure({
    ReportRetryPolicy? retryPolicy,
    int? maxQueueSize,
    int? maxBatchSize,
    Duration? flushInterval,
    String? storagePath,
  }) {
    if (_queue != null) {
      _logger.warning(
        'configure() called after reporters were registered. '
        'Queue parameters will apply on next restart.',
      );
    }

    if (retryPolicy != null) _retryPolicy = retryPolicy;
    if (maxQueueSize != null) _maxQueueSize = maxQueueSize;
    if (maxBatchSize != null) _maxBatchSize = maxBatchSize;
    if (flushInterval != null) _flushInterval = flushInterval;
    if (storagePath != null) _storagePath = storagePath;
  }

  /// Register a failure reporter.
  ///
  /// Initializes the reporter and creates the queue on first registration.
  /// Throws [StateError] if a reporter with the same [id] is already registered.
  Future<void> register(FailureReporter reporter) async {
    if (_reporters.containsKey(reporter.id)) {
      throw StateError(
        'FailureReporter already registered: ${reporter.id}. '
        'Unregister it first.',
      );
    }

    try {
      await reporter.initialize();
    } catch (e, stackTrace) {
      _logger.severe(
        'Failed to initialize reporter ${reporter.id}',
        e,
        stackTrace,
      );
      rethrow;
    }

    _reporters[reporter.id] = reporter;
    _ensureQueue();

    _logger.info('Registered failure reporter: ${reporter.id}');
  }

  /// Unregister a failure reporter by ID.
  ///
  /// Disposes the reporter. If no reporters remain, the queue is disposed.
  Future<void> unregister(String id) async {
    final reporter = _reporters.remove(id);
    if (reporter == null) return;

    try {
      await reporter.dispose();
    } catch (e, stackTrace) {
      _logger.warning(
        'Error disposing reporter $id',
        e,
        stackTrace,
      );
    }

    if (_reporters.isEmpty) {
      await _disposeQueue();
    }

    _logger.info('Unregistered failure reporter: $id');
  }

  /// Report a failure.
  ///
  /// This is **fire-and-forget** — it enqueues the failure in the
  /// batch queue and returns immediately. Never throws.
  ///
  /// Called automatically by [UseCase.call()], [StreamUseCase.call()],
  /// [BackgroundUseCase.call()], [SyncUseCase.call()], and
  /// [FailureHandler.logAndHandleError()].
  void reportFailure(
    AppFailure failure, {
    StackTrace? stackTrace,
    Map<String, String>? attributes,
  }) {
    if (!hasReporters || _queue == null) return;

    final report = FailureReport(
      failure: failure,
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
      attributes: attributes,
    );

    _queue!.enqueue(report);
  }

  /// Flush all pending reports immediately.
  Future<void> flush() async {
    await _queue?.flush();
  }

  /// Dispose all reporters and the queue.
  ///
  /// Call this on app shutdown to ensure pending reports are flushed.
  Future<void> dispose() async {
    await _disposeQueue();

    for (final reporter in _reporters.values) {
      try {
        await reporter.dispose();
      } catch (e, stackTrace) {
        _logger.warning(
          'Error disposing reporter ${reporter.id}',
          e,
          stackTrace,
        );
      }
    }
    _reporters.clear();

    _logger.info('FailureReporterRegistry disposed');
  }

  /// Reset the registry (primarily for testing).
  Future<void> reset() async {
    await dispose();
    _retryPolicy = const ExponentialBackoffRetryPolicy();
    _maxQueueSize = 256;
    _maxBatchSize = 32;
    _flushInterval = const Duration(seconds: 5);
    _storagePath = null;
  }

  void _ensureQueue() {
    if (_queue != null) return;

    _queue = FailureReportQueue(
      reporters: _reporters.values.toList(),
      maxQueueSize: _maxQueueSize,
      maxBatchSize: _maxBatchSize,
      flushInterval: _flushInterval,
      retryPolicy: _retryPolicy,
      store: _storagePath != null
          ? FailureReportStore(filePath: _storagePath!)
          : null,
    );
  }

  Future<void> _disposeQueue() async {
    await _queue?.dispose();
    _queue = null;
  }
}
