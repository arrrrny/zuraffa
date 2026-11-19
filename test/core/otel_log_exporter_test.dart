import 'dart:convert';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:zuraffa/zuraffa.dart';

/// Native fake [http.Client] that records every request it is asked to send
/// (instead of using mocktail's `verify(...).captured`). When [failWith] is set,
/// [send] still records the attempt and then throws, mirroring a network failure
/// that the exporter is expected to swallow without crashing or retrying.
///
/// Extends [http.BaseClient] so the convenience methods (`get`/`post`/etc.) are
/// derived from [send]; only [send] and [close] need a concrete body.
class RecordingClient extends http.BaseClient {
  final List<http.Request> sent = [];
  Object? failWith;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sent.add(request as http.Request);
    if (failWith != null) {
      throw failWith!;
    }
    return http.StreamedResponse(Stream.value(<int>[]), 200);
  }

  @override
  void close() {}
}

void main() {
  late RecordingClient recordingClient;
  late OtelLogExporter exporter;

  setUp(() {
    recordingClient = RecordingClient();
  });

  tearDown(() async {
    await exporter.dispose();
    Logger.root.clearListeners();
  });

  group('OtelLogExporter', () {
    test('determines correct logs endpoint from traces endpoint', () {
      exporter = OtelLogExporter(
        collectorBaseEndpoint: Uri.parse('http://localhost:4318/v1/traces'),
        serviceName: 'test_service',
        httpClient: recordingClient,
      );

      // We expose logsEndpoint logic by making it send a log and asserting the URI
      exporter.start();
      Logger.root.warning('test');

      // Force flush
      return exporter.flush().then((_) {
        expect(
          recordingClient.sent.last.url.toString(),
          'http://localhost:4318/v1/logs',
        );
      });
    });

    test('determines correct logs endpoint from base endpoint', () {
      exporter = OtelLogExporter(
        collectorBaseEndpoint: Uri.parse('http://localhost:4318/'),
        serviceName: 'test_service',
        httpClient: recordingClient,
      );

      exporter.start();
      Logger.root.warning('test');

      return exporter.flush().then((_) {
        expect(
          recordingClient.sent.last.url.toString(),
          'http://localhost:4318/v1/logs',
        );
      });
    });

    test('filters logs below remoteLogLevel', () async {
      exporter = OtelLogExporter(
        collectorBaseEndpoint: Uri.parse('http://localhost:4318/v1/traces'),
        serviceName: 'test_service',
        remoteLogLevel: ZuraffaLogLevel.warning,
        httpClient: recordingClient,
      );

      exporter.start();

      // These should not be exported
      Logger.root.fine('fine log');
      Logger.root.info('info log');

      await exporter.flush();

      expect(recordingClient.sent, isEmpty);

      // This should be exported
      Logger.root.warning('warning log');

      await exporter.flush();

      expect(recordingClient.sent, hasLength(1));
    });

    test('batches logs and builds correct OTLP payload', () async {
      exporter = OtelLogExporter(
        collectorBaseEndpoint: Uri.parse('http://localhost:4318/v1/traces'),
        serviceName: 'test_service',
        remoteLogLevel: ZuraffaLogLevel.all,
        httpClient: recordingClient,
        maxBatchSize: 2, // Flush after 2 logs
      );

      exporter.start();

      Logger.root.info('first log');
      Logger.root.severe(
        'second log',
        FormatException('bad format'),
        StackTrace.fromString('stack_trace_here'),
      );

      // Because batch size is 2, it should have auto-flushed after the second log.
      // We yield to event loop to allow flush to complete.
      await Future.delayed(Duration.zero);

      final bodyStr = recordingClient.sent.last.body;
      final payload = jsonDecode(bodyStr) as Map<String, dynamic>;

      final resourceLogs = payload['resourceLogs'] as List;
      expect(resourceLogs, hasLength(1));

      final resource = resourceLogs[0]['resource'];
      expect(resource['attributes'][0]['key'], 'service.name');
      expect(resource['attributes'][0]['value']['stringValue'], 'test_service');

      final scopeLogs = resourceLogs[0]['scopeLogs'] as List;
      expect(scopeLogs, hasLength(1));

      final logRecords = scopeLogs[0]['logRecords'] as List;
      expect(logRecords, hasLength(2));

      // First log
      expect(logRecords[0]['severityNumber'], 9); // INFO
      expect(logRecords[0]['severityText'], 'INFO');
      expect(logRecords[0]['body']['stringValue'], 'first log');

      // Second log (with error and stack trace)
      expect(logRecords[1]['severityNumber'], 17); // SEVERE -> ERROR
      expect(logRecords[1]['severityText'], 'SEVERE');
      expect(logRecords[1]['body']['stringValue'], 'second log');

      final attrs = logRecords[1]['attributes'] as List;
      expect(
        attrs.any(
          (a) =>
              a['key'] == 'exception.message' &&
              a['value']['stringValue'] == 'FormatException: bad format',
        ),
        isTrue,
      );
      expect(
        attrs.any(
          (a) =>
              a['key'] == 'exception.stacktrace' &&
              a['value']['stringValue'] == 'stack_trace_here',
        ),
        isTrue,
      );
    });

    test('does not crash or retry on http failure', () async {
      recordingClient.failWith = Exception('Network error');

      exporter = OtelLogExporter(
        collectorBaseEndpoint: Uri.parse('http://localhost:4318/v1/traces'),
        serviceName: 'test_service',
        remoteLogLevel: ZuraffaLogLevel.all,
        httpClient: recordingClient,
      );

      exporter.start();
      Logger.root.info('test');

      // Flush should catch the error and complete normally
      await exporter.flush();

      // A single send attempt was made before the failure was swallowed.
      expect(recordingClient.sent, hasLength(1));
    });

    test('requeues the batch and emits one bounded recovery record on next '
        'successful flush', () async {
      final bodies = <http.Request>[];
      final client = _ScriptedClient(bodies);

      exporter = OtelLogExporter(
        collectorBaseEndpoint: Uri.parse('http://localhost:4318/v1/traces'),
        serviceName: 'test_service',
        remoteLogLevel: ZuraffaLogLevel.all,
        httpClient: client,
      );

      exporter.start();
      Logger.root.warning('lost during outage');

      // First flush fails; the batch must be requeued, not dropped.
      await exporter.flush();
      expect(exporter.pendingCount, 1);

      // Collector recovers: the requeued batch ships, then the recovery record.
      client.fail = false;
      await exporter.flush();

      // The recovery record itself ships on the next flush.
      await exporter.flush();
      expect(exporter.pendingCount, 0);
      final shipped = bodies.map((r) => jsonDecode(r.body) as Map).toList();
      final records = shipped
          .expand(
            (p) =>
                ((p['resourceLogs'][0]['scopeLogs'][0])['logRecords'] as List),
          )
          .toList();
      final recovery = records.where(
        (r) =>
            r['attributes'].length == 1 &&
            r['attributes'][0]['key'] == 'logger.name' &&
            r['attributes'][0]['value']['stringValue'] ==
                'OtelLogExporterHealth',
      );
      expect(recovery, hasLength(1));
      final message = recovery.single['body']['stringValue'] as String;
      expect(message, contains('recovered after 1 failed flush'));
      expect(message, contains('0 records dropped'));
    });

    test('drops oldest records and counts them when pending exceeds '
        'maxPendingRecords', () async {
      recordingClient.failWith = Exception('Network error');

      exporter = OtelLogExporter(
        collectorBaseEndpoint: Uri.parse('http://localhost:4318/v1/traces'),
        serviceName: 'test_service',
        remoteLogLevel: ZuraffaLogLevel.all,
        maxPendingRecords: 3,
        httpClient: recordingClient,
      );

      exporter.start();
      Logger.root.warning('one');
      Logger.root.warning('two');
      Logger.root.warning('three');
      Logger.root.warning('four');
      Logger.root.warning('five');

      // Only the newest three survive; the oldest two are dropped and counted.
      expect(exporter.pendingCount, 3);
      expect(exporter.droppedCount, 2);
    });

    test('recovery summary reports the actual dropped total across the '
        'whole outage window', () async {
      final bodies = <http.Request>[];
      final client = _ScriptedClient(bodies);

      exporter = OtelLogExporter(
        collectorBaseEndpoint: Uri.parse('http://localhost:4318/v1/traces'),
        serviceName: 'test_service',
        remoteLogLevel: ZuraffaLogLevel.warning,
        maxPendingRecords: 2,
        httpClient: client,
      );

      exporter.start();

      // An outage that overflows the queue several times, so the dropped
      // total exceeds the retained window.
      for (var i = 0; i < 5; i++) {
        Logger.root.warning('record $i');
      }
      await exporter.flush();
      expect(exporter.pendingCount, 2);
      final droppedSoFar = exporter.droppedCount;
      expect(droppedSoFar, greaterThanOrEqualTo(3));

      client.fail = false;
      await exporter.flush();
      await exporter.flush();

      final shipped = bodies.map((r) => jsonDecode(r.body) as Map).toList();
      final records = shipped
          .expand(
            (p) =>
                ((p['resourceLogs'][0]['scopeLogs'][0])['logRecords'] as List),
          )
          .toList();
      final message =
          records.firstWhere(
                (r) =>
                    r['attributes'].length == 1 &&
                    r['attributes'][0]['key'] == 'logger.name' &&
                    r['attributes'][0]['value']['stringValue'] ==
                        'OtelLogExporterHealth',
              )['body']['stringValue']
              as String;

      expect(message, contains('recovered after 1 failed flush'));
      expect(message, contains('$droppedSoFar records dropped'));
    });

    test('flush timer backs off during consecutive failures and recovers '
        'after success', () async {
      final bodies = <http.Request>[];
      final client = _ScriptedClient(bodies);

      exporter = OtelLogExporter(
        collectorBaseEndpoint: Uri.parse('http://localhost:4318/v1/traces'),
        serviceName: 'test_service',
        remoteLogLevel: ZuraffaLogLevel.warning,
        flushInterval: const Duration(milliseconds: 30),
        maxBackoffInterval: const Duration(milliseconds: 120),
        httpClient: client,
      );

      exporter.start();
      Logger.root.warning('queued during outage');

      // Two consecutive failed flushes drive the timer toward the cap.
      await exporter.flush();
      await exporter.flush();
      final backoffWhileFailing = exporter.currentFlushInterval;
      expect(
        backoffWhileFailing,
        greaterThan(const Duration(milliseconds: 30)),
      );
      expect(
        backoffWhileFailing,
        lessThanOrEqualTo(const Duration(milliseconds: 120)),
      );

      // Success returns the timer to its base interval.
      client.fail = false;
      await exporter.flush();
      expect(exporter.currentFlushInterval, const Duration(milliseconds: 30));
    });
  });
}

class _ScriptedClient extends http.BaseClient {
  _ScriptedClient(this._requests);

  /// Records every request handed to [send]; [fail] makes [send] throw.
  final List<http.Request> _requests;
  bool fail = true;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _requests.add(request as http.Request);
    if (fail) {
      throw Exception('Network error');
    }
    return http.StreamedResponse(Stream.value(<int>[]), 200);
  }

  @override
  void close() {}
}
