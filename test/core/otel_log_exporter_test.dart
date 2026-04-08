import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zuraffa/zuraffa.dart';

class MockHttpClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeUri());
  });

  group('OtelLogExporter', () {
    late MockHttpClient mockHttpClient;
    late OtelLogExporter exporter;

    setUp(() {
      mockHttpClient = MockHttpClient();

      when(
        () => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 200));
    });

    tearDown(() async {
      await exporter.dispose();
      Logger.root.clearListeners();
    });

    test('determines correct logs endpoint from traces endpoint', () {
      exporter = OtelLogExporter(
        collectorBaseEndpoint: Uri.parse('http://localhost:4318/v1/traces'),
        serviceName: 'test_service',
        httpClient: mockHttpClient,
      );

      // We expose logsEndpoint logic by making it send a log and asserting the URI
      exporter.start();
      Logger.root.warning('test');

      // Force flush
      return exporter.flush().then((_) {
        final captured = verify(
          () => mockHttpClient.post(
            captureAny(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.toString(), 'http://localhost:4318/v1/logs');
      });
    });

    test('determines correct logs endpoint from base endpoint', () {
      exporter = OtelLogExporter(
        collectorBaseEndpoint: Uri.parse('http://localhost:4318/'),
        serviceName: 'test_service',
        httpClient: mockHttpClient,
      );

      exporter.start();
      Logger.root.warning('test');

      return exporter.flush().then((_) {
        final captured = verify(
          () => mockHttpClient.post(
            captureAny(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.toString(), 'http://localhost:4318/v1/logs');
      });
    });

    test('filters logs below remoteLogLevel', () async {
      exporter = OtelLogExporter(
        collectorBaseEndpoint: Uri.parse('http://localhost:4318/v1/traces'),
        serviceName: 'test_service',
        remoteLogLevel: ZuraffaLogLevel.warning,
        httpClient: mockHttpClient,
      );

      exporter.start();

      // These should not be exported
      Logger.root.fine('fine log');
      Logger.root.info('info log');

      await exporter.flush();

      verifyNever(
        () => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      );

      // This should be exported
      Logger.root.warning('warning log');

      await exporter.flush();

      verify(
        () => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).called(1);
    });

    test('batches logs and builds correct OTLP payload', () async {
      exporter = OtelLogExporter(
        collectorBaseEndpoint: Uri.parse('http://localhost:4318/v1/traces'),
        serviceName: 'test_service',
        remoteLogLevel: ZuraffaLogLevel.all,
        httpClient: mockHttpClient,
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

      final captured = verify(
        () => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: captureAny(named: 'body'),
        ),
      ).captured;

      final bodyStr = captured.first as String;
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
      // Clear logger listeners so the warning from the exporter doesn't print
      Logger.root.clearListeners();

      when(
        () => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenThrow(Exception('Network error'));

      exporter = OtelLogExporter(
        collectorBaseEndpoint: Uri.parse('http://localhost:4318/v1/traces'),
        serviceName: 'test_service',
        remoteLogLevel: ZuraffaLogLevel.all,
        httpClient: mockHttpClient,
      );

      exporter.start();
      Logger.root.info('test');

      // Flush should catch the error and complete normally
      await exporter.flush();

      verify(
        () => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).called(1);
    });
  });
}
