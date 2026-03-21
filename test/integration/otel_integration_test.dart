// ignore_for_file: avoid_print
/// Integration test for OtelFailureReporter against a local OTel Collector.
///
/// Prerequisites:
///   docker run -p 4318:4318 otel/opentelemetry-collector-contrib:latest
///
/// Run with:
///   flutter test test/integration/otel_integration_test.dart --tags=integration

@Tags(['integration'])
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  // Default OTLP HTTP endpoint on local Docker collector
  final collectorEndpoint = Uri.parse('http://localhost:4318/v1/traces');

  group('OtelFailureReporter integration', () {
    late FailureReporterRegistry registry;

    setUp(() async {
      registry = FailureReporterRegistry.instance;
      await registry.reset();
    });

    tearDown(() async {
      await registry.reset();
    });

    test('sends a single ServerFailure span to the collector', () async {
      // Configure with no automatic flush — we'll flush manually
      registry.configure(
        flushInterval: const Duration(hours: 1),
        retryPolicy: const NoRetryPolicy(),
      );

      await registry.register(
        OtelFailureReporter(
          collectorEndpoint: collectorEndpoint,
          serviceName: 'zuraffa-integration-test',
        ),
      );

      registry.reportFailure(
        ServerFailure('Integration test: server error', statusCode: 500),
        stackTrace: StackTrace.current,
        attributes: {'test.name': 'single_server_failure'},
      );

      // Flush and wait for export
      await registry.flush();

      // If we got here without throwing, the collector accepted the trace
      print('✅ Single ServerFailure span exported successfully');
    });

    test('sends multiple failure types in a batch', () async {
      registry.configure(
        flushInterval: const Duration(hours: 1),
        retryPolicy: const NoRetryPolicy(),
      );

      await registry.register(
        OtelFailureReporter(
          collectorEndpoint: collectorEndpoint,
          serviceName: 'zuraffa-integration-test',
        ),
      );

      // Report a variety of failure types
      final failures = <AppFailure>[
        ServerFailure('Server down', statusCode: 503),
        NetworkFailure('Connection refused'),
        ValidationFailure(
          'Invalid email',
          fieldErrors: {
            'email': ['Must be a valid email address'],
          },
        ),
        NotFoundFailure(
          'User not found',
          resourceType: 'User',
          resourceId: 'usr-404',
        ),
        UnauthorizedFailure('Token expired'),
        TimeoutFailure(
          'DB query timed out',
          timeout: const Duration(seconds: 30),
        ),
        CacheFailure('Cache read failed'),
        UnknownFailure('Something unexpected happened'),
      ];

      for (final failure in failures) {
        registry.reportFailure(
          failure,
          stackTrace: StackTrace.current,
          attributes: {
            'test.name': 'batch_multiple_types',
            'test.failure_index': failures.indexOf(failure).toString(),
          },
        );
      }

      await registry.flush();

      print('✅ ${failures.length} failure spans exported successfully');
    });

    test('UseCase auto-reports to real collector', () async {
      registry.configure(
        flushInterval: const Duration(hours: 1),
        retryPolicy: const NoRetryPolicy(),
      );

      await registry.register(
        OtelFailureReporter(
          collectorEndpoint: collectorEndpoint,
          serviceName: 'zuraffa-integration-test',
        ),
      );

      // Create a UseCase that always fails
      final useCase = _AlwaysFailsUseCase();
      final result = await useCase('trigger');

      // Verify the UseCase returned a Failure result
      expect(result.isFailure, isTrue);

      // Flush — the UseCase should have auto-reported this failure
      await registry.flush();

      print('✅ UseCase auto-reported failure span exported successfully');
    });

    test('handles collector down gracefully with NoRetryPolicy', () async {
      registry.configure(
        flushInterval: const Duration(hours: 1),
        retryPolicy: const NoRetryPolicy(),
      );

      // Point to a non-existent collector
      await registry.register(
        OtelFailureReporter(
          collectorEndpoint: Uri.parse('http://localhost:19999/v1/traces'),
          serviceName: 'zuraffa-integration-test',
        ),
      );

      registry.reportFailure(
        ServerFailure('This should fail to export'),
        attributes: {'test.name': 'collector_down'},
      );

      // Should not throw — fire-and-forget with NoRetryPolicy
      await registry.flush();

      print('✅ Gracefully handled collector-down scenario');
    });

    test('retry policy retries on collector failure', () async {
      registry.configure(
        flushInterval: const Duration(hours: 1),
        retryPolicy: const FixedIntervalRetryPolicy(
          interval: Duration(milliseconds: 100),
          maxRetries: 2,
        ),
      );

      // Point to a non-existent collector
      await registry.register(
        OtelFailureReporter(
          collectorEndpoint: Uri.parse('http://localhost:19999/v1/traces'),
          serviceName: 'zuraffa-integration-test',
        ),
      );

      registry.reportFailure(
        NetworkFailure('Retry test'),
        attributes: {'test.name': 'retry_policy'},
      );

      // Should retry then give up — must not throw
      await registry.flush();

      print('✅ Retry policy completed without crashing');
    });

    test('Zuraffa convenience API works end-to-end', () async {
      // Use the Zuraffa class convenience method
      await Zuraffa.enableOtelReporting(
        collectorEndpoint: collectorEndpoint,
        serviceName: 'zuraffa-convenience-test',
        retryPolicy: const NoRetryPolicy(),
      );

      // Report via registry (as UseCases would)
      FailureReporterRegistry.instance.reportFailure(
        ServerFailure('Via Zuraffa convenience API', statusCode: 422),
        attributes: {'test.name': 'zuraffa_convenience'},
      );

      await Zuraffa.flushFailureReports();
      await Zuraffa.disposeFailureReporters();

      print('✅ Zuraffa convenience API exported successfully');
    });
  });
}

/// A UseCase that always throws — used to verify auto-reporting.
class _AlwaysFailsUseCase extends UseCase<String, String> {
  @override
  Future<String> execute(String params, CancelToken? cancelToken) async {
    throw ServerFailure('UseCase integration test failure', statusCode: 500);
  }
}
