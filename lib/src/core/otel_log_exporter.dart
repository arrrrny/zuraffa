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
  final Uri collectorBaseEndpoint;
  final String serviceName;
  final String instrumentationName;
  final ZuraffaLogLevel remoteLogLevel;
  final int maxBatchSize;
  final Duration flushInterval;

  final List<LogRecord> _queue = [];
  Timer? _flushTimer;
  StreamSubscription<LogRecord>? _logSubscription;
  bool _isDisposed = false;

  late final Uri _logsEndpoint;
  late final http.Client _httpClient;

  OtelLogExporter({
    required this.collectorBaseEndpoint,
    required this.serviceName,
    this.remoteLogLevel = ZuraffaLogLevel.warning,
    this.instrumentationName = 'zuraffa-log-exporter',
    this.maxBatchSize = 100,
    this.flushInterval = const Duration(seconds: 5),
    http.Client? httpClient,
  }) {
    // Determine the base path for logs based on the provided collector endpoint.
    // If the collector base endpoint already ends in /v1/traces (as passed for failures),
    // we change it to /v1/logs. Otherwise, we just append /v1/logs to the base URL.
    final path = collectorBaseEndpoint.path;
    if (path.endsWith('/v1/traces')) {
      _logsEndpoint = collectorBaseEndpoint.replace(
        path: path.substring(0, path.length - '/v1/traces'.length) + '/v1/logs',
      );
    } else {
      _logsEndpoint = collectorBaseEndpoint.replace(
        path: path.endsWith('/') ? '${path}v1/logs' : '$path/v1/logs',
      );
    }

    _httpClient = httpClient ?? http.Client();
  }

  /// Start listening to logs and batching them.
  void start() {
    if (_isDisposed || _logSubscription != null) return;

    final minLevel = Zuraffa.toLevel(remoteLogLevel);

    _logSubscription = Logger.root.onRecord.listen((record) {
      if (record.level >= minLevel) {
        _enqueue(record);
      }
    });

    _flushTimer = Timer.periodic(flushInterval, (_) => flush());
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
    if (_queue.length >= maxBatchSize) {
      flush();
    }
  }

  /// Flush queued logs to the OTel collector.
  Future<void> flush() async {
    if (_queue.isEmpty) return;

    // Take current batch and clear queue
    final batch = List<LogRecord>.from(_queue);
    _queue.clear();

    try {
      final payload = _buildOtlpPayload(batch);

      final response = await _httpClient.post(
        _logsEndpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200 && response.statusCode != 202) {
        // We log locally via print so we don't trigger recursive OTel logging
        // ignore: avoid_print
        print(
          'OTel log export failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('OTel log export failed: $e');
      // On failure, we don't requeue right now as logs are typically point-in-time
      // and we don't want to exhaust memory with failing connectivity.
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
