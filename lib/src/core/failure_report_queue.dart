import 'dart:async';

import 'package:logging/logging.dart';

import 'failure_reporter.dart';
import 'failure_report_store.dart';
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
/// ## Persistence
/// When a [FailureReportStore] is provided, reports survive app restarts:
/// - On creation: persisted reports are loaded and prepended to the queue
/// - On flush failure: remaining reports are saved to disk
/// - On successful flush: the persistence file is cleared
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

  /// Optional disk-backed store for persistence across app restarts.
  final FailureReportStore? store;

  final List<FailureReport> _queue = [];
  final List<FailureReporter> _reporters;
  Timer? _flushTimer;
  bool _isDisposed = false;
  bool _isFlushing = false;
  bool _isInitialized = false;

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
    this.store,
  }) : _reporters = reporters {
    _startFlushTimer();
    // Load persisted reports asynchronously
    if (store != null) {
      _loadPersisted();
    } else {
      _isInitialized = true;
    }
  }

  /// Load persisted reports from disk and prepend to queue.
  Future<void> _loadPersisted() async {
    try {
      final persisted = await store!.load();
      if (persisted.isNotEmpty) {
        // Prepend persisted reports (they're older, should flush first)
        _queue.insertAll(0, persisted);
        _logger.info('Restored ${persisted.length} failure reports from disk');
        // Trigger an immediate flush for restored reports
        _flushAsync();
      }
    } catch (e, stackTrace) {
      _logger.warning('Failed to load persisted reports', e, stackTrace);
    } finally {
      _isInitialized = true;
    }
  }

  /// Enqueue a failure report for batch delivery.
  ///
  /// If the queue is full, the oldest report is dropped.
  /// This method never throws.
  void enqueue(FailureReport report) {
    if (_isDisposed) return;

    // Filter: only enqueue if at least one reporter wants it
    final hasInterested = _reporters.any((r) => r.shouldReport(report.failure));
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
  /// If flush fails and a [store] is configured, remaining reports
  /// are persisted to disk.
  Future<void> flush() async {
    if (_isDisposed || _isFlushing || _queue.isEmpty) return;

    _isFlushing = true;
    bool hadFailures = false;

    try {
      while (_queue.isNotEmpty) {
        // Take a batch
        final batchSize = _queue.length < maxBatchSize
            ? _queue.length
            : maxBatchSize;
        final batch = _queue.sublist(0, batchSize);

        // Send to each reporter
        bool allSucceeded = true;
        for (final reporter in _reporters) {
          // Filter batch for this reporter
          final filteredBatch = batch
              .where((r) => reporter.shouldReport(r.failure))
              .toList();
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
          hadFailures = true;
          // Stop flushing — will retry on next cycle
          break;
        }
      }

      // Persist remaining reports on failure, clear on success
      if (store != null) {
        if (hadFailures && _queue.isNotEmpty) {
          await store!.save(_queue);
        } else if (_queue.isEmpty) {
          await store!.clear();
        }
      }
    } catch (e, stackTrace) {
      _logger.severe('Unexpected error during flush', e, stackTrace);
      // Best-effort persist on unexpected error
      if (store != null && _queue.isNotEmpty) {
        await store!.save(_queue);
      }
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
  /// If flush fails and a [store] is configured, remaining reports
  /// are persisted to disk for recovery on next app launch.
  Future<void> dispose() async {
    if (_isDisposed) return;

    _flushTimer?.cancel();
    _flushTimer = null;

    // Final flush attempt (before marking as disposed)
    _isFlushing = false; // Reset so flush() can run
    await flush();

    // If there are still unflushed reports, persist them
    if (store != null && _queue.isNotEmpty) {
      await store!.save(_queue);
      _logger.info('Persisted ${_queue.length} unflushed reports to disk');
    }

    _isDisposed = true;
    _queue.clear();
    _logger.info('FailureReportQueue disposed');
  }
}
