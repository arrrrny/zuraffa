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

    test('requeues the batch and survives an http failure', () async {
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
      // The failed batch is requeued, not dropped — that is the point of
      // this PR, and the old "does not retry" name never asserted it.
      expect(exporter.pendingCount, 1);
    });

    test('dispose() stops the exporter — no sends after disposal', () async {
      final bodies = <http.Request>[];
      final client = _ScriptedClient(bodies);

      exporter = OtelLogExporter(
        collectorBaseEndpoint: Uri.parse('http://localhost:4318/v1/traces'),
        serviceName: 'test_service',
        remoteLogLevel: ZuraffaLogLevel.warning,
        flushInterval: const Duration(milliseconds: 20),
        maxBackoffInterval: const Duration(milliseconds: 40),
        httpClient: client,
      );

      exporter.start();
      Logger.root.warning('queued during outage');

      // Two failed flushes arm the backoff so a missing dispose guard would
      // have a live timer to leak.
      await exporter.flush();
      await exporter.flush();
      expect(exporter.consecutiveFailures, greaterThan(0));

      // dispose()'s final flush also fails; it must not re-arm a timer that
      // keeps POSTing on the closed client.
      await exporter.dispose();
      final sendsAtDispose = bodies.length;
      expect(sendsAtDispose, greaterThan(0));

      await Future.delayed(const Duration(milliseconds: 120));
      // No timer survived disposal: the exporter is silent after dispose().
      expect(bodies.length, sendsAtDispose);
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

      // Collector recovers: the requeued batch ships, then the recovery
      // record ships in the SAME flush — before a dispose() could close the
      // client with the promised recovery signal still queued.
      client.fail = false;
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

    test('recovery summary reports only the current outage window drops, '
        'not the lifetime total', () async {
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

      // Pre-window drops: the queue overflows while filling, before any
      // flush has failed, so these belong to no outage window.
      for (var i = 0; i < 5; i++) {
        Logger.root.warning('pre $i');
      }
      expect(exporter.droppedCount, 3);
      expect(exporter.pendingCount, 2);

      // Open the window with a failing flush, then drop two more during the
      // outage - those two are this window's drops.
      await exporter.flush();
      Logger.root.warning('during a');
      Logger.root.warning('during b');
      // Lifetime is now 5 (3 pre-window + 2 during), but the window opened
      // at 3, so only the 2 during-window drops are this window's.
      expect(exporter.droppedCount, 5);

      client.fail = false;
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
      // Window-scoped: 2, not the lifetime 5.
      expect(message, contains('2 records dropped'));
      expect(message, isNot(contains('5 records dropped')));
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
