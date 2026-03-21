import 'dart:async';

import 'package:logging/logging.dart';

import 'failure_reporter.dart';
import 'retry_policy.dart';
import 'retry_policies.dart';

/// In-memory bounded queue that batches failure reports for delivery.
///
/// Follows the OpenTelemetry [BatchSpanProcessor] conventions:
/// - Failures are enqueued and flushed periodically in batches
/// - The queue has a maximum size; new reports are dropped when full
/// - On flush, reports are delivered to all registered reporters
/// - Failed deliveries are retried according to the [ReportRetryPolicy]
///
/// ## Key Behaviors
/// - **Fire-and-forget**: Enqueue never blocks the caller
/// - **Bounded**: Drops oldest reports when full (prevents memory leaks)
/// - **Batch flush**: Reduces network overhead by grouping reports
/// - **Never crashes**: Reporter errors are caught and logged
class FailureReportQueue {
  static final _logger = Logger('FailureReportQueue');

  /// Maximum number of reports to hold in the queue.
  /// Reports are dropped when this limit is reached.
  final int maxQueueSize;

  /// Maximum number of reports per batch export.
  final int maxBatchSize;

  /// Time between automatic flush cycles.
  final Duration flushInterval;

  /// Retry policy for failed deliveries.
  final ReportRetryPolicy retryPolicy;

  final List<FailureReport> _queue = [];
  final List<FailureReporter> _reporters;
  Timer? _flushTimer;
  bool _isDisposed = false;
  bool _isFlushing = false;

  /// Number of reports currently queued.
  int get length => _queue.length;

  /// Whether the queue has been disposed.
  bool get isDisposed => _isDisposed;

  FailureReportQueue({
    required List<FailureReporter> reporters,
    this.maxQueueSize = 256,
    this.maxBatchSize = 32,
    this.flushInterval = const Duration(seconds: 5),
    this.retryPolicy = const ExponentialBackoffRetryPolicy(),
  }) : _reporters = reporters {
    _startFlushTimer();
  }

  /// Enqueue a failure report for batch delivery.
  ///
  /// If the queue is full, the report is silently dropped.
  /// This method never throws.
  void enqueue(FailureReport report) {
    if (_isDisposed) return;

    // Filter: only enqueue if at least one reporter wants it
    final hasInterested = _reporters.any(
      (r) => r.shouldReport(report.failure),
    );
    if (!hasInterested) return;

    if (_queue.length >= maxQueueSize) {
      _logger.warning(
        'FailureReportQueue is full ($maxQueueSize). '
        'Dropping oldest report: ${_queue.first}',
      );
      _queue.removeAt(0);
    }

    _queue.add(report);

    // If queue is half full, flush immediately
    if (_queue.length >= maxQueueSize ~/ 2) {
      _flushAsync();
    }
  }

  /// Flush all queued reports to reporters.
  ///
  /// Reports are sent in batches of [maxBatchSize].
  /// Failed batches are retried according to [retryPolicy].
  Future<void> flush() async {
    if (_isDisposed || _isFlushing || _queue.isEmpty) return;

    _isFlushing = true;

    try {
      while (_queue.isNotEmpty) {
        // Take a batch
        final batchSize =
            _queue.length < maxBatchSize ? _queue.length : maxBatchSize;
        final batch = _queue.sublist(0, batchSize);

        // Send to each reporter
        bool allSucceeded = true;
        for (final reporter in _reporters) {
          // Filter batch for this reporter
          final filteredBatch =
              batch.where((r) => reporter.shouldReport(r.failure)).toList();
          if (filteredBatch.isEmpty) continue;

          final success = await _sendWithRetry(reporter, filteredBatch);
          if (!success) {
            allSucceeded = false;
          }
        }

        if (allSucceeded) {
          // Remove successfully sent reports
          _queue.removeRange(0, batchSize);
        } else {
          // Stop flushing — will retry on next cycle
          break;
        }
      }
    } catch (e, stackTrace) {
      _logger.severe(
        'Unexpected error during flush',
        e,
        stackTrace,
      );
    } finally {
      _isFlushing = false;
    }
  }

  /// Send a batch to a reporter with retry.
  Future<bool> _sendWithRetry(
    FailureReporter reporter,
    List<FailureReport> batch,
  ) async {
    var attemptNumber = 0;
    var lastDelay = Duration.zero;

    while (true) {
      try {
        await reporter.reportBatch(batch);
        return true;
      } catch (e, stackTrace) {
        _logger.warning(
          '${reporter.id} failed to report batch '
          '(attempt ${attemptNumber + 1}): $e',
          e,
          stackTrace,
        );

        final delay = retryPolicy.nextDelay(attemptNumber, lastDelay);
        if (delay == null) {
          _logger.warning(
            '${reporter.id}: giving up after ${attemptNumber + 1} attempts. '
            'Dropping ${batch.length} reports.',
          );
          return false;
        }

        lastDelay = delay;
        attemptNumber++;

        // Wait before retrying
        await Future<void>.delayed(delay);

        // Check if we were disposed while waiting
        if (_isDisposed) return false;
      }
    }
  }

  /// Non-blocking flush trigger.
  void _flushAsync() {
    if (_isFlushing) return;
    // Schedule flush as a microtask to avoid blocking
    scheduleMicrotask(() => flush());
  }

  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(flushInterval, (_) => flush());
  }

  /// Flush remaining reports and stop the timer.
  ///
  /// After dispose, no more reports will be accepted.
  Future<void> dispose() async {
    if (_isDisposed) return;

    _flushTimer?.cancel();
    _flushTimer = null;

    // Final flush attempt (before marking as disposed)
    _isFlushing = false; // Reset so flush() can run
    await flush();

    _isDisposed = true;
    _queue.clear();
    _logger.info('FailureReportQueue disposed');
  }
}
