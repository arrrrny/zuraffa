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
  });
}
