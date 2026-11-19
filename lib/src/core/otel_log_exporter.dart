import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../zuraffa.dart';

/// Exports [LogRecord]s to an OpenTelemetry collector via OTLP/HTTP.
///
/// Converts Dart [LogRecord]s to OTLP JSON format and batches them
/// for efficient delivery to the collector's `/v1/logs` endpoint.
class OtelLogExporter {
  static final Logger _logger = Logger('OtelLogExporter');

  /// Logger name for the recovery summary emitted after an outage.
  ///
  /// Deliberately different from [_logger]'s name so the self-recursion
  /// filter in [start] (which skips `OtelLogExporter` records) does not
  /// swallow the one record that makes an outage observable.
  static const String healthLoggerName = 'OtelLogExporterHealth';

  final Uri collectorBaseEndpoint;
  final String serviceName;
  final String? apiKey;
  final String instrumentationName;
  final ZuraffaLogLevel remoteLogLevel;
  final int maxBatchSize;
  final Duration flushInterval;

  /// Hard cap on the number of queued records kept while the collector is
  /// unreachable. When the queue grows past this, the OLDEST records are
  /// dropped and counted ([droppedCount]).
  final int maxPendingRecords;

  /// Upper bound for the flush-timer backoff applied during consecutive
  /// export failures.
  final Duration maxBackoffInterval;

  final List<LogRecord> _queue = [];
  Timer? _flushTimer;
  StreamSubscription<LogRecord>? _logSubscription;
  bool _isDisposed = false;

  /// Number of consecutive failed flushes since the last success.
  int _consecutiveFailures = 0;

  /// Timestamp of the first failed flush in the current outage window.
  DateTime? _firstFailureAt;

  /// Total number of records dropped because [maxPendingRecords] was
  /// exceeded, accumulated across outage windows.
  int _dropCount = 0;

  /// The interval the flush timer currently runs at.
  Duration _currentInterval;

  late final Uri _logsEndpoint;
  late final http.Client _httpClient;

  OtelLogExporter({
    required this.collectorBaseEndpoint,
    required this.serviceName,
    this.apiKey,
    this.remoteLogLevel = ZuraffaLogLevel.warning,
    this.instrumentationName = 'zuraffa-log-exporter',
    this.maxBatchSize = 100,
    this.flushInterval = const Duration(seconds: 5),
    this.maxPendingRecords = 5000,
    this.maxBackoffInterval = const Duration(seconds: 60),
    http.Client? httpClient,
  }) : _currentInterval = flushInterval,
       assert(maxPendingRecords > 0, 'maxPendingRecords must be positive'),
       assert(maxBatchSize > 0, 'maxBatchSize must be positive') {
    // Determine the base path for logs based on the provided collector endpoint.
    // If the collector base endpoint already ends in /v1/traces (as passed for failures),
    // we change it to /v1/logs. Otherwise, we just append /v1/logs to the base URL.
    final path = collectorBaseEndpoint.path;
    if (path.endsWith('/v1/traces')) {
      _logsEndpoint = collectorBaseEndpoint.replace(
        path: '${path.substring(0, path.length - '/v1/traces'.length)}/v1/logs',
      );
    } else {
      _logsEndpoint = collectorBaseEndpoint.replace(
        path: path.endsWith('/') ? '${path}v1/logs' : '$path/v1/logs',
      );
    }

    _httpClient = httpClient ?? http.Client();
  }

  /// Number of records currently queued for export (including requeued
  /// batches from failed flushes).
  int get pendingCount => _queue.length;

  /// Total number of records dropped because the queue exceeded
  /// [maxPendingRecords].
  int get droppedCount => _dropCount;

  /// Number of consecutive failed flushes since the last successful one.
  int get consecutiveFailures => _consecutiveFailures;

  /// The flush interval the timer currently uses (grows with backoff
  /// during failures, returns to [flushInterval] after a success).
  Duration get currentFlushInterval => _currentInterval;

  /// Start listening to logs and batching them.
  void start() {
    if (_isDisposed || _logSubscription != null) return;

    final minLevel = Zuraffa.toLevel(remoteLogLevel);

    _logSubscription = Logger.root.onRecord.listen((record) {
      // Filter out our own logs to prevent self-recursion
      if (record.loggerName == 'OtelLogExporter') return;

      if (record.level >= minLevel) {
        _enqueue(record);
      }
    });

    _scheduleFlush();
  }

  /// Stop listening and flush remaining logs.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    _flushTimer?.cancel();
    await _logSubscription?.cancel();

    await flush(); // Final flush
    _httpClient.close();
  }

  void _enqueue(LogRecord record) {
    if (_isDisposed) return;

    _queue.add(record);
    _dropCount += _enforceCap();
    if (_queue.length >= maxBatchSize) {
      flush();
    }
  }

  /// Trim the queue to [maxPendingRecords], dropping the oldest records
  /// first. Returns the number of records dropped.
  int _enforceCap() {
    if (_queue.length <= maxPendingRecords) return 0;
    final overflow = _queue.length - maxPendingRecords;
    _queue.removeRange(0, overflow);
    return overflow;
  }

  void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(_currentInterval, () {
      flush().catchError((_) {
        // flush() handles its own errors; this is a final safety net so a
        // rejected future never escalates to an uncaught async error.
      });
      // Re-arm while not disposed; flush() reschedules itself on the next
      // tick through _scheduleFlush when it decides the timer is still due.
      if (!_isDisposed) _scheduleFlush();
    });
  }

  /// Flush queued logs to the OTel collector.
  ///
  /// On failure the batch is put back at the FRONT of the queue (bounded by
  /// [maxPendingRecords], oldest dropped and counted), the flush timer backs
  /// off toward [maxBackoffInterval], and after the first successful flush
  /// following an outage a single synthetic recovery record is enqueued
  /// under `OtelLogExporterHealth` (and shipped by the same flush that
  /// observed the success).
  Future<void> flush() async {
    // A flush interrupted by an outage keeps trying until the queue drains:
    // after a failure the batch was requeued, so the next pass retries it.
    var attempts = 0;
    while (_queue.isNotEmpty) {
      if (++attempts > 1) {
        // One retry per manual/timer flush is enough — if the collector is
        // still down, the backoff timer will bring us back.
        break;
      }
      await _flushOnce();
    }
  }

  /// Perform a single flush pass over the currently queued batch.
  Future<void> _flushOnce() async {
    if (_queue.isEmpty) return;

    // Take current batch and clear queue
    final batch = List<LogRecord>.from(_queue);
    _queue.clear();

    bool ok = false;
    try {
      final payload = _buildOtlpPayload(batch);

      final headers = {
        'Content-Type': 'application/json',
        if (apiKey != null) 'Authorization': 'Bearer $apiKey',
      };

      final response = await _httpClient.post(
        _logsEndpoint,
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200 && response.statusCode != 202) {
        _logger.warning(
          'OTel log export failed: ${response.statusCode} - ${response.body}',
        );
      } else {
        ok = true;
      }
    } catch (e) {
      _logger.warning('OTel log export failed: $e');
    }

    if (ok) {
      _onFlushSuccess();
    } else {
      _onFlushFailure(batch);
    }
  }

  void _onFlushFailure(List<LogRecord> batch) {
    // Requeue the batch at the FRONT, preserving original record order.
    _queue.insertAll(0, batch);
    _dropCount += _enforceCap();

    _consecutiveFailures++;
    _firstFailureAt ??= DateTime.now();

    // Back off the flush timer: double the current interval up to the cap.
    _currentInterval = _currentInterval * 2;
    if (_currentInterval > maxBackoffInterval) {
      _currentInterval = maxBackoffInterval;
    }
    _scheduleFlush();
  }

  void _onFlushSuccess() {
    final hadFailures = _consecutiveFailures > 0;
    final failed = _consecutiveFailures;
    final firstFailureAt = _firstFailureAt;
    _consecutiveFailures = 0;
    _firstFailureAt = null;

    if (_currentInterval != flushInterval) {
      _currentInterval = flushInterval;
      _scheduleFlush();
    }

    if (hadFailures) {
      // Exactly ONE synthetic record per outage window, emitted only after
      // recovery — the failed-flush warning stays recursion-filtered, so
      // this is the only observable signal, and it is emitted when the pipe
      // is known to work again (no loop: nothing enqueues it while down).
      final now = DateTime.now();
      final window =
          '${firstFailureAt?.toIso8601String() ?? 'unknown'}→'
          '${now.toIso8601String()}';
      final drops = _dropCount;
      final record = LogRecord(
        Level.WARNING,
        'Log export recovered after $failed failed flush(es), '
            '$drops records dropped, window $window',
        healthLoggerName,
      );
      _queue.insert(0, record);
    }
  }

  Map<String, dynamic> _buildOtlpPayload(List<LogRecord> batch) {
    final logRecords = batch.map((record) {
      final logRecord = <String, dynamic>{
        'timeUnixNano': '${record.time.microsecondsSinceEpoch * 1000}',
        'severityNumber': _severityNumber(record.level),
        'severityText': record.level.name,
        'body': {'stringValue': record.message},
        'attributes': [
          {
            'key': 'logger.name',
            'value': {'stringValue': record.loggerName},
          },
        ],
      };

      if (record.error != null) {
        (logRecord['attributes'] as List).add({
          'key': 'exception.message',
          'value': {'stringValue': record.error.toString()},
        });
        (logRecord['attributes'] as List).add({
          'key': 'exception.type',
          'value': {'stringValue': record.error.runtimeType.toString()},
        });
      }

      if (record.stackTrace != null) {
        (logRecord['attributes'] as List).add({
          'key': 'exception.stacktrace',
          'value': {'stringValue': record.stackTrace.toString()},
        });
      }

      return logRecord;
    }).toList();

    return {
      'resourceLogs': [
        {
          'resource': {
            'attributes': [
              {
                'key': 'service.name',
                'value': {'stringValue': serviceName},
              },
            ],
          },
          'scopeLogs': [
            {
              'scope': {'name': instrumentationName},
              'logRecords': logRecords,
            },
          ],
        },
      ],
    };
  }

  /// Convert Dart logging Level to OTel SeverityNumber
  /// See: https://opentelemetry.io/docs/specs/otel/logs/data-model/#displaying-severity
  int _severityNumber(Level level) {
    if (level >= Level.SHOUT) return 21; // FATAL
    if (level >= Level.SEVERE) return 17; // ERROR
    if (level >= Level.WARNING) return 13; // WARN
    if (level >= Level.INFO) return 9; // INFO
    if (level >= Level.FINE) return 5; // DEBUG
    if (level >= Level.FINEST) return 1; // TRACE
    return 9; // Default to INFO
  }
}
